import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { validateRetentionDeletionReadiness } from '../../tool/validate_retention_deletion_readiness.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const baseRetention = JSON.parse(readFileSync(resolve(root, 'store/retention-deletion-readiness.json'), 'utf8'));
const basePrivacy = JSON.parse(readFileSync(resolve(root, 'store/privacy-disclosures.json'), 'utf8'));
const clone = (value) => structuredClone(value);
const sha256 = (value) => createHash('sha256').update(value).digest('hex');

function validate({ retentionManifest = clone(baseRetention), privacyManifest = clone(basePrivacy), sourceTexts = {}, evidenceTexts = {}, requireApproved = false } = {}) {
  return validateRetentionDeletionReadiness({ root, retentionManifest, privacyManifest, sourceTexts, evidenceTexts, requireApproved });
}

test('accepts the honest fail-closed retention draft', () => {
  assert.deepEqual(validate(), {state: 'draft', approvalAllowed: false, openDecisionCount: 9, storeGate: 'open'});
});

test('strict approval rejects the current retention draft', () => {
  assert.throws(() => validate({ requireApproved: true }), /Approved retention and deletion readiness is required/);
});

test('rejects source drift after retention review', () => {
  assert.throws(() => validate({ sourceTexts: {'backend/ops/backup.sh': '# changed\n'} }), /sourceInventory hash is stale/);
});

test('rejects account erasure that leaves notification payloads behind', () => {
  const path = 'backend/src/app.js';
  const retentionManifest = clone(baseRetention);
  const changed = readFileSync(resolve(root, path), 'utf8').replace("payload = '{}'::jsonb", 'payload = payload');
  retentionManifest.sourceInventory.find((entry) => entry.path === path).sha256 = sha256(changed);
  assert.throws(() => validate({ retentionManifest, sourceTexts: {[path]: changed} }), /residual-data control/);
});

test('rejects expired credential cleanup that leaves booking confirmation digests behind', () => {
  const path = 'backend/src/credential_cleanup.js';
  const retentionManifest = clone(baseRetention);
  const changed = readFileSync(resolve(root, path), 'utf8')
    .replace("code_digest = repeat('0', 64)", 'code_digest = code_digest');
  retentionManifest.sourceInventory.find((entry) => entry.path === path).sha256 = sha256(changed);
  assert.throws(
    () => validate({ retentionManifest, sourceTexts: {[path]: changed} }),
    /Expired credential cleanup is missing the contract/u,
  );
});

test('rejects claiming automatic credential purge when the API worker is disconnected', () => {
  const path = 'backend/src/server.js';
  const retentionManifest = clone(baseRetention);
  const changed = readFileSync(resolve(root, path), 'utf8')
    .replace('startCredentialCleanupWorker({ client: pool })', 'null');
  retentionManifest.sourceInventory.find((entry) => entry.path === path).sha256 = sha256(changed);
  assert.throws(
    () => validate({ retentionManifest, sourceTexts: {[path]: changed} }),
    /cleanup worker must start and stop/u,
  );
});

test('rejects invented legal periods in an open decision', () => {
  const retentionManifest = clone(baseRetention);
  retentionManifest.requiredDecisions.transactionalRecordPeriod.value = 'ten years';
  assert.throws(() => validate({ retentionManifest }), /must not claim a value or evidence/);
});

test('rejects Store-gate drift from the privacy manifest', () => {
  const privacyManifest = clone(basePrivacy);
  privacyManifest.requiredDecisions.retentionAndDeletionSchedule.status = 'closed';
  assert.throws(() => validate({ privacyManifest }), /must match the privacy retentionAndDeletionSchedule decision/);
});

test('rejects account data in the retention manifest', () => {
  const retentionManifest = clone(baseRetention);
  retentionManifest.requiredDecisions.inactiveAccountPeriod.value = 'owner@example.com';
  assert.throws(() => validate({ retentionManifest }), /must not contain an email address/);
});

test('rejects a provider evidence reference whose official facts are incomplete', () => {
  const path = 'docs/evidence/b11/privacy-provider-retention-sources-20260812.json';
  const changed = readFileSync(resolve(root, path), 'utf8').replace('within 180 days', 'after an unspecified period');
  assert.throws(
    () => validate({ evidenceTexts: { [path]: changed } }),
    /Firebase Cloud Messaging source contract: within 180 days/,
  );
});

test('rejects provider evidence that prematurely claims owner approval', () => {
  const path = 'docs/evidence/b11/privacy-provider-retention-sources-20260812.json';
  const evidence = JSON.parse(readFileSync(resolve(root, path), 'utf8'));
  evidence.boundaries.providerContractAcceptedByOwner = true;
  assert.throws(
    () => validate({ evidenceTexts: { [path]: JSON.stringify(evidence) } }),
    /reviewed-but-unapproved release boundary/,
  );
});

test('rejects credential cleanup evidence that claims deployment without proof', () => {
  const path = 'docs/evidence/b11/expired-credential-cleanup-20260815.json';
  const evidence = JSON.parse(readFileSync(resolve(root, path), 'utf8'));
  evidence.status = 'staging-runtime-verified';
  evidence.verification.stagingRuntime = 'passed';
  evidence.deployment.status = 'verified';
  evidence.deployment.commit = null;
  evidence.deployment.evidenceRef = null;
  assert.throws(
    () => validate({ evidenceTexts: { [path]: JSON.stringify(evidence) } }),
    /exact Staging deployment proof/u,
  );
});

test('rejects omitting Firebase Authentication retention and deletion evidence', () => {
  const path = 'docs/evidence/b11/privacy-provider-retention-sources-20260812.json';
  const evidence = JSON.parse(readFileSync(resolve(root, path), 'utf8'));
  evidence.sources = evidence.sources.filter(
    (source) => source.provider !== 'Firebase Authentication',
  );
  assert.throws(
    () => validate({ evidenceTexts: { [path]: JSON.stringify(evidence) } }),
    /Firebase Authentication source contract/,
  );
});

test('rejects owner verification without a separate owner evidence reference', () => {
  const retentionManifest = clone(baseRetention);
  const privacyManifest = clone(basePrivacy);
  privacyManifest.requiredDecisions.retentionAndDeletionSchedule.status = 'closed';
  const externalDecision = retentionManifest.requiredDecisions.externalProcessorRetention;
  externalDecision.status = 'closed';
  externalDecision.value = 'approved-external-retention';
  externalDecision.evidenceRef = 'docs/evidence/b11/retention-external-owner.json';
  for (const processor of Object.values(retentionManifest.externalProcessors)) {
    processor.retentionOwnerVerified = true;
    processor.deletionProcedureVerified = true;
  }
  retentionManifest.storeGate.status = 'closed';
  assert.throws(
    () => validate({ retentionManifest, privacyManifest }),
    /requires separate owner evidence/,
  );
});

test('accepts a fully evidence-backed approved fixture', () => {
  const retentionManifest = clone(baseRetention);
  const privacyManifest = clone(basePrivacy);
  retentionManifest.state = 'approved';
  retentionManifest.approvalAllowed = true;
  retentionManifest.boundaries.legalApproval = true;
  retentionManifest.storeGate.status = 'closed';
  privacyManifest.requiredDecisions.retentionAndDeletionSchedule.status = 'closed';
  for (const [key, decision] of Object.entries(retentionManifest.requiredDecisions)) {
    decision.status = 'closed';
    decision.value = `approved-${key}`;
    decision.evidenceRef = `docs/evidence/b11/retention-${key}.json`;
  }
  for (const processor of Object.values(retentionManifest.externalProcessors)) {
    processor.retentionOwnerVerified = true;
    processor.deletionProcedureVerified = true;
    processor.ownerEvidenceRef = 'docs/evidence/b11/retention-external-owner.json';
  }
  assert.equal(validate({ retentionManifest, privacyManifest, requireApproved: true }).state, 'approved');
});
