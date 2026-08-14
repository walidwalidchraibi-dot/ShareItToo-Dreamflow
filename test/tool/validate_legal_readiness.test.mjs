import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { validateLegalReadiness } from '../../tool/validate_legal_readiness.mjs';

const repositoryRoot = fileURLToPath(new URL('../../', import.meta.url));
const baseLegalManifest = JSON.parse(
  readFileSync(resolve(repositoryRoot, 'store/legal-readiness.json'), 'utf8'),
);
const baseSubmissionManifest = JSON.parse(
  readFileSync(resolve(repositoryRoot, 'store/submission.json'), 'utf8'),
);

function clone(value) {
  return structuredClone(value);
}

function validate({
  legalManifest = clone(baseLegalManifest),
  submissionManifest = clone(baseSubmissionManifest),
  sourceTexts = {},
  requireApproved = false,
} = {}) {
  return validateLegalReadiness({
    root: repositoryRoot,
    legalManifest,
    submissionManifest,
    sourceTexts,
    requireApproved,
  });
}

test('accepts the honest fail-closed legal draft', () => {
  const result = validate();
  assert.equal(result.state, 'draft');
  assert.equal(result.approvalAllowed, false);
  assert.equal(result.storeGate, 'open');
  assert.equal(result.documentCount, 6);
  assert.equal(result.explicitConfirmations, 3);
});

test('strict approval rejects the current draft', () => {
  assert.throws(
    () => validate({ requireApproved: true }),
    /Legal approval is required/,
  );
});

test('rejects a stale legal source hash', () => {
  const legalManifest = clone(baseLegalManifest);
  legalManifest.documents.terms.currentContentSha256 = '0'.repeat(64);
  assert.throws(
    () => validate({ legalManifest }),
    /currentContentSha256 is stale/,
  );
});

test('rejects hardcoded client consent', () => {
  const authPath = baseLegalManifest.consentContract.authServiceSource;
  const authSource = readFileSync(resolve(repositoryRoot, authPath), 'utf8')
    .replace("'termsAccepted': termsAccepted", "'termsAccepted': true");
  assert.throws(
    () => validate({ sourceTexts: { [authPath]: authSource } }),
    /Auth consent contract is missing|hardcoded to true/,
  );
});

test('rejects closing the provider identity Store gate without legal evidence', () => {
  const submissionManifest = clone(baseSubmissionManifest);
  submissionManifest.blockingGates.legalProviderIdentity = 'closed';
  assert.throws(
    () => validate({ submissionManifest }),
    /legalProviderIdentity must match blockingGates.legalProviderIdentity/,
  );
});

test('rejects closing copyright approval without evidence', () => {
  const legalManifest = clone(baseLegalManifest);
  const submissionManifest = clone(baseSubmissionManifest);
  legalManifest.requiredApprovals.copyrightOwner.status = 'closed';
  submissionManifest.blockingGates.copyrightOwner = 'closed';
  assert.throws(
    () => validate({ legalManifest, submissionManifest }),
    /copyrightOwner.evidenceRef must be a non-empty string/,
  );
});

test('accepts a complete internally consistent approved fixture', () => {
  const legalManifest = clone(baseLegalManifest);
  const submissionManifest = clone(baseSubmissionManifest);
  legalManifest.state = 'approved';
  legalManifest.approvalAllowed = true;
  legalManifest.consentContract.technicalStatus = 'explicit-versioned-approved';
  for (const [key, item] of Object.entries(legalManifest.documents)) {
    item.status = 'approved';
    item.approvedContentSha256 = item.currentContentSha256;
    item.publicUrl = `https://shareittoo.com/${{
      terms: 'terms',
      communityRules: 'community-rules',
      cancellationPolicy: 'cancellation-policy',
      feesAndPayments: 'fees-and-payments',
      privacy: 'privacy',
      imprint: 'imprint',
    }[key]}`;
    item.approvalEvidenceRef = `docs/evidence/b11/legal-${key}-approval.json`;
  }
  for (const key of Object.keys(legalManifest.requiredApprovals)) {
    legalManifest.requiredApprovals[key].status = 'closed';
    legalManifest.requiredApprovals[key].evidenceRef =
      `docs/evidence/b11/legal-${key}-approval.json`;
  }
  legalManifest.storeGate.status = 'closed';
  submissionManifest.blockingGates.legalProviderIdentity = 'closed';
  submissionManifest.blockingGates.copyrightOwner = 'closed';
  submissionManifest.blockingGates.termsAndUserContentRules = 'closed';

  const result = validate({
    legalManifest,
    submissionManifest,
    requireApproved: true,
  });
  assert.equal(result.state, 'approved');
  assert.equal(result.approvalAllowed, true);
  assert.equal(result.storeGate, 'closed');
});
