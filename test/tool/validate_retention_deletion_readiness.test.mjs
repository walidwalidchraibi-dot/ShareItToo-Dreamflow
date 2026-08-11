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

function validate({ retentionManifest = clone(baseRetention), privacyManifest = clone(basePrivacy), sourceTexts = {}, requireApproved = false } = {}) {
  return validateRetentionDeletionReadiness({ root, retentionManifest, privacyManifest, sourceTexts, requireApproved });
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
  }
  assert.equal(validate({ retentionManifest, privacyManifest, requireApproved: true }).state, 'approved');
});
