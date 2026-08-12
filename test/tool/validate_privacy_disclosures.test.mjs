import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { validatePrivacyDisclosures } from '../../tool/validate_privacy_disclosures.mjs';

const repositoryRoot = fileURLToPath(new URL('../../', import.meta.url));
const basePrivacyManifest = JSON.parse(
  readFileSync(resolve(repositoryRoot, 'store/privacy-disclosures.json'), 'utf8'),
);
const baseSubmissionManifest = JSON.parse(
  readFileSync(resolve(repositoryRoot, 'store/submission.json'), 'utf8'),
);
const baseDeviceManifest = JSON.parse(
  readFileSync(resolve(repositoryRoot, 'store/device-validation.json'), 'utf8'),
);

function clone(value) {
  return structuredClone(value);
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function validate({
  privacyManifest = clone(basePrivacyManifest),
  submissionManifest = clone(baseSubmissionManifest),
  deviceManifest = clone(baseDeviceManifest),
  sourceTexts = {},
  evidenceTexts = {},
  requireApproved = false,
} = {}) {
  return validatePrivacyDisclosures({
    root: repositoryRoot,
    privacyManifest,
    submissionManifest,
    deviceManifest,
    sourceTexts,
    evidenceTexts,
    requireApproved,
  });
}

test('accepts the honest fail-closed privacy disclosure draft', () => {
  const result = validate();
  assert.equal(result.state, 'draft');
  assert.equal(result.approvalAllowed, false);
  assert.equal(result.dataTypeCount, 18);
  assert.equal(result.externalServiceCount, 8);
  assert.equal(result.binaryReleaseCheck, 'passed');
  assert.equal(result.storeGate, 'open');
});

test('strict approval rejects the current privacy draft', () => {
  assert.throws(
    () => validate({ requireApproved: true }),
    /Approved privacy disclosures are required/,
  );
});

test('rejects source drift after the inventory was reviewed', () => {
  const path = 'lib/services/maps_service.dart';
  const changed = `${readFileSync(resolve(repositoryRoot, path), 'utf8')}\n// drift\n`;
  assert.throws(
    () => validate({ sourceTexts: { [path]: changed } }),
    /sourceInventory hash is stale: lib\/services\/maps_service.dart/,
  );
});

test('rejects omitting precise location while fine-location flows exist', () => {
  const privacyManifest = clone(basePrivacyManifest);
  privacyManifest.dataTypes.find((item) => item.id === 'preciseLocation').collected = false;
  assert.throws(
    () => validate({ privacyManifest }),
    /require preciseLocation disclosure/,
  );
});

test('rejects treating the automatic Firebase installation ID as optional', () => {
  const privacyManifest = clone(basePrivacyManifest);
  privacyManifest.dataTypes.find((item) => item.id === 'deviceOrOtherIds').optional = true;
  assert.throws(
    () => validate({ privacyManifest }),
    /requires non-optional device or installation ID disclosure/,
  );
});

test('rejects omitting automatic Firebase session interactions', () => {
  const privacyManifest = clone(basePrivacyManifest);
  privacyManifest.dataTypes.find((item) => item.id === 'appInteractions').collected = false;
  assert.throws(
    () => validate({ privacyManifest }),
    /requires non-optional, non-linked app interaction disclosure/,
  );
});

test('rejects privacy copy that hides the precise on-demand location flow', () => {
  const path = 'lib/screens/legal_privacy_screen.dart';
  const privacyManifest = clone(basePrivacyManifest);
  const changed = readFileSync(resolve(repositoryRoot, path), 'utf8')
    .replace('genaue Standortkoordinaten', 'ungefähre Standortangaben');
  privacyManifest.sourceInventory.find((entry) => entry.path === path).sha256 = sha256(changed);
  assert.throws(
    () => validate({ privacyManifest, sourceTexts: { [path]: changed } }),
    /missing the truthful disclosure marker: genaue Standortkoordinaten/,
  );
});

test('rejects hiding the Google Maps integration found in the candidate', () => {
  const privacyManifest = clone(basePrivacyManifest);
  privacyManifest.externalServices.googleMapsPlatform.enabled = false;
  assert.throws(
    () => validate({ privacyManifest }),
    /must disclose its enabled Google Maps client integration/,
  );
});

test('rejects closing the Store privacy gate without owner decisions', () => {
  const submissionManifest = clone(baseSubmissionManifest);
  submissionManifest.blockingGates.finalBinaryPrivacyScan = 'closed';
  assert.throws(
    () => validate({ submissionManifest }),
    /Privacy store gate must match store\/submission.json/,
  );
});

test('rejects account data in the privacy manifest', () => {
  const privacyManifest = clone(basePrivacyManifest);
  privacyManifest.dataTypes[0].google = 'owner@example.com';
  assert.throws(
    () => validate({ privacyManifest }),
    /must not contain an email address/,
  );
});

test('accepts a complete internally consistent approved fixture', () => {
  const privacyManifest = clone(basePrivacyManifest);
  const submissionManifest = clone(baseSubmissionManifest);
  const deviceManifest = clone(baseDeviceManifest);

  delete privacyManifest.candidate.status;
  delete privacyManifest.candidate.replacementBuildNumber;
  privacyManifest.binaryEvidence.binaryScan = 'passed';
  delete privacyManifest.binaryEvidence.supersessionEvidenceRef;

  privacyManifest.state = 'approved';
  privacyManifest.approvalAllowed = true;
  privacyManifest.externalServices.googleMapsPlatform.applicationRestrictionVerified = true;
  privacyManifest.binaryEvidence.releaseCheckStatus = 'passed';
  deviceManifest.releaseChecks.binaryPrivacyAndNetwork.status = 'passed';
  submissionManifest.blockingGates.finalBinaryPrivacyScan = 'closed';
  privacyManifest.storeGate.status = 'closed';
  for (const [key, decision] of Object.entries(privacyManifest.requiredDecisions)) {
    decision.status = 'closed';
    decision.evidenceRef = `docs/evidence/b11/privacy-${key}.json`;
  }
  for (const [platform, form] of Object.entries(privacyManifest.platformForms)) {
    form.status = 'verified';
    form.evidenceRef = `docs/evidence/b11/privacy-${platform}-form.json`;
  }

  const result = validate({
    privacyManifest,
    submissionManifest,
    deviceManifest,
    requireApproved: true,
  });
  assert.equal(result.state, 'approved');
  assert.equal(result.approvalAllowed, true);
  assert.equal(result.storeGate, 'closed');
});
