import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { validateStoreReviewAccess } from '../../tool/validate_store_review_access.mjs';

const repositoryRoot = fileURLToPath(new URL('../../', import.meta.url));
const baseReview = JSON.parse(readFileSync(resolve(repositoryRoot, 'store/review-access.json')));
const baseDevice = JSON.parse(readFileSync(resolve(repositoryRoot, 'store/device-validation.json')));
const baseSubmission = JSON.parse(readFileSync(resolve(repositoryRoot, 'store/submission.json')));
const currentEvidence = JSON.parse(readFileSync(resolve(
  repositoryRoot,
  'docs/evidence/b11/store-review-access-readiness-20260811.json',
)));
const passedEvidence = {
  schemaVersion: 1,
  kind: 'store-review-access-diagnostic',
  status: 'technical-review-access-passed-store-fields-pending',
  capturedAt: '2026-08-11T01:00:00.000Z',
  candidate: structuredClone(baseReview.candidate),
  roles: ['owner', 'renter'],
  checks: {
    isolatedStagingFixture: true,
    ownerPasswordLoginWithoutOtp: true,
    renterPasswordLoginWithoutOtp: true,
    ownerActiveVerifiedAndConsented: true,
    renterActiveVerifiedAndConsented: true,
    ownerListingVisible: true,
    acceptedBookingVisibleToBothRoles: true,
    sharedChatVisibleToBothRoles: true,
    sharedChatReadableByBothRoles: true,
  },
  environment: {
    apiBaseUrl: 'https://staging.shareittoo.com/api/v1',
    paymentMode: 'memory',
    stripeLivemode: false,
    paymentEndpointCalled: false,
  },
  boundaries: {
    productDataReadOnly: true,
    businessDataMutations: false,
    authenticationSessionsCreated: true,
    containsSecrets: false,
    containsEmailAddresses: false,
    containsTokens: false,
    containsAccountIdentifiers: false,
    containsFixtureIdentifiers: false,
    syntheticAccountsOnly: true,
    publicStoreChanged: false,
    productionChanged: false,
  },
};

function clone(value) { return structuredClone(value); }
function validate({
  review = clone(baseReview),
  device = clone(baseDevice),
  submission = clone(baseSubmission),
  evidence = clone(currentEvidence),
  technicalPass = false,
  requireReady = false,
} = {}) {
  if (technicalPass) {
    review.technicalAccess.status = 'passed';
    for (const role of review.roles) role.status = 'verified';
    for (const key of ['ownerLogin', 'renterLogin', 'activeListing', 'acceptedBooking', 'sharedChat']) {
      review.reviewScenarios[key] = 'passed';
    }
  }
  return validateStoreReviewAccess({ root: repositoryRoot, reviewManifest: review, deviceManifest: device, submissionManifest: submission, evidenceOverride: evidence, requireReady });
}

test('accepts the honest fail-closed testing state', () => {
  const result = validate();
  assert.equal(result.state, 'testing');
  assert.equal(result.readyForStore, false);
  assert.equal(result.passedScenarios, 0);
  assert.equal(result.storeGate, 'open');
});

test('strict readiness rejects the current testing state', () => {
  assert.throws(() => validate({ requireReady: true }), /not fully ready/);
});

test('rejects a candidate or Store-gate mismatch', () => {
  const review = clone(baseReview);
  review.candidate.buildNumber = '2026081199';
  assert.throws(() => validate({ review }), /must match the device candidate/);
  const submission = clone(baseSubmission);
  submission.blockingGates.reviewAccounts = 'closed';
  assert.throws(() => validate({ submission }), /store gate must match/);
});

test('rejects credential fields and email values', () => {
  const review = clone(baseReview);
  review.reviewPassword = 'must-not-exist';
  assert.throws(() => validate({ review }), /sensitive account or credential data/);
  const evidence = clone(currentEvidence);
  evidence.note = 'reviewer@example.test';
  assert.throws(() => validate({ evidence }), /must not contain an email address/);
});

test('rejects incomplete technical evidence', () => {
  const evidence = clone(passedEvidence);
  evidence.checks.sharedChatReadableByBothRoles = false;
  assert.throws(() => validate({ evidence, technicalPass: true }), /must be true/);
});

test('accepts a complete internally consistent ready fixture', () => {
  const review = clone(baseReview);
  const submission = clone(baseSubmission);
  review.state = 'passed';
  review.readyForStore = true;
  for (const key of Object.keys(review.reviewScenarios)) review.reviewScenarios[key] = 'passed';
  review.protectedStoreFields.googlePlay = 'passed';
  review.protectedStoreFields.appStoreConnect = 'passed';
  review.storeGate.status = 'closed';
  submission.blockingGates.reviewAccounts = 'closed';
  const result = validate({ review, submission, evidence: clone(passedEvidence), technicalPass: true, requireReady: true });
  assert.equal(result.readyForStore, true);
});
