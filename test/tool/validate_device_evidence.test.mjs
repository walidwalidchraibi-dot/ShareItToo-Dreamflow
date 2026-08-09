import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { validateDeviceEvidence } from '../../tool/validate_device_evidence.mjs';

const repositoryRoot = fileURLToPath(new URL('../../', import.meta.url));
const baseDeviceManifest = JSON.parse(
  readFileSync(resolve(repositoryRoot, 'store/device-validation.json'), 'utf8'),
);
const baseSubmissionManifest = JSON.parse(
  readFileSync(resolve(repositoryRoot, 'store/submission.json'), 'utf8'),
);
const basePubspec = readFileSync(resolve(repositoryRoot, 'pubspec.yaml'), 'utf8');

function clone(value) {
  return structuredClone(value);
}

function validate({
  root = repositoryRoot,
  deviceManifest = clone(baseDeviceManifest),
  submissionManifest = clone(baseSubmissionManifest),
  pubspecText = basePubspec,
  requirePassed = false,
} = {}) {
  return validateDeviceEvidence({
    root,
    deviceManifest,
    submissionManifest,
    pubspecText,
    requirePassed,
  });
}

function writeEvidence(root, ref, contents = 'sanitized B11 evidence\n') {
  const target = resolve(root, ref);
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, contents);
}

function passedFixture() {
  const root = mkdtempSync(resolve(tmpdir(), 'sit-device-evidence-'));
  const deviceManifest = clone(baseDeviceManifest);
  const submissionManifest = clone(baseSubmissionManifest);
  const pubspecText = basePubspec.replace(
    /^version:\s*\d+\.\d+\.\d+\+\d{10}\s*$/m,
    'version: 1.0.0+2026080903',
  );

  deviceManifest.state = 'passed';
  deviceManifest.goNoGo = 'go';
  Object.assign(deviceManifest.candidate, {
    buildNumber: '2026080903',
    commit: 'a'.repeat(40),
    firebaseConfigured: true,
    paymentMode: 'stripe-test',
  });
  Object.assign(deviceManifest.candidate.android, {
    delivery: 'play-internal',
    aabSha256: 'b'.repeat(64),
    apkSha256: 'c'.repeat(64),
    signingCertificateSha256: 'd'.repeat(64),
  });
  Object.assign(deviceManifest.candidate.ios, {
    delivery: 'testflight-internal',
    ipaSha256: 'e'.repeat(64),
    teamIdentifier: 'ABCDE12345',
    privacyManifestScanned: true,
  });

  for (const cell of deviceManifest.deviceMatrix) {
    cell.deviceModel = `${cell.platform} test device`;
    cell.osVersion = cell.platform === 'android' ? 'Android 16' : 'iOS 19';
    cell.storeInstall = cell.platform === 'android' ? 'play-internal' : 'testflight-internal';
    cell.status = 'passed';
    for (const key of Object.keys(cell.tests)) cell.tests[key] = 'passed';
    cell.evidenceRef = `docs/evidence/b11/${cell.id}.md`;
    writeEvidence(root, cell.evidenceRef);
  }

  for (const [key, check] of Object.entries(deviceManifest.releaseChecks)) {
    check.status = 'passed';
    check.evidenceRef = `docs/evidence/b11/release-${key}.md`;
    writeEvidence(root, check.evidenceRef);
  }

  for (const [key, approval] of Object.entries(deviceManifest.approvals)) {
    approval.status = 'passed';
    approval.approvedAt = '2026-08-09T18:00:00+02:00';
    approval.evidenceRef = `docs/evidence/b11/approval-${key}.md`;
    writeEvidence(root, approval.evidenceRef);
  }

  for (const key of [
    'realAndroidAndIosDevices',
    'finalBinaryPrivacyScan',
    'closedStoreAndAccessibilityMatrix',
  ]) {
    submissionManifest.blockingGates[key] = 'closed';
  }

  return { root, deviceManifest, submissionManifest, pubspecText };
}

test('accepts the honest in-progress B11 evidence state', () => {
  const summary = validate();
  assert.deepEqual(summary, {
    state: 'testing',
    goNoGo: 'hold',
    matrixPassed: 0,
    matrixTotal: 4,
    releaseChecksPassed: 3,
    releaseChecksTotal: 7,
    minimumBuild: '2026080903',
  });
});

test('strict mode rejects the in-progress evidence state', () => {
  assert.throws(
    () => validate({ requirePassed: true }),
    /remains testing: matrix=0\/4, releaseChecks=3\/7/,
  );
});

test('rejects a premature go decision', () => {
  const deviceManifest = clone(baseDeviceManifest);
  deviceManifest.goNoGo = 'go';
  assert.throws(() => validate({ deviceManifest }), /forbidden before the full device validation passes/);
});

test('rejects a missing required platform, network, and role cell', () => {
  const deviceManifest = clone(baseDeviceManifest);
  deviceManifest.deviceMatrix = deviceManifest.deviceMatrix.slice(1);
  assert.throws(() => validate({ deviceManifest }), /Missing required device matrix cell/);
});

test('rejects additional cells that could dilute the required matrix', () => {
  const deviceManifest = clone(baseDeviceManifest);
  const extra = clone(deviceManifest.deviceMatrix[0]);
  extra.id = 'android-extra';
  deviceManifest.deviceMatrix.push(extra);
  assert.throws(() => validate({ deviceManifest }), /must contain exactly 4 required cells/);
});

test('rejects credential-shaped fields anywhere in the evidence manifest', () => {
  const deviceManifest = clone(baseDeviceManifest);
  deviceManifest.reviewPassword = null;
  assert.throws(() => validate({ deviceManifest }), /must never contain credentials or secrets/);
});

test('rejects a referenced progress artifact that does not exist', () => {
  const deviceManifest = clone(baseDeviceManifest);
  deviceManifest.releaseChecks.candidateIdentityAndSignatures.evidenceRef =
    'docs/evidence/b11/missing-progress-evidence.md';
  assert.throws(
    () => validate({ deviceManifest }),
    /does not exist: docs\/evidence\/b11\/missing-progress-evidence.md/,
  );
});

test('accepts a complete, evidence-backed B11 pass', () => {
  const fixture = passedFixture();
  const summary = validate({ ...fixture, requirePassed: true });
  assert.equal(summary.state, 'passed');
  assert.equal(summary.goNoGo, 'go');
  assert.equal(summary.matrixPassed, 4);
  assert.equal(summary.releaseChecksPassed, 7);
});

test('a passed state fails closed when an evidence file is missing', () => {
  const fixture = passedFixture();
  fixture.deviceManifest.deviceMatrix[0].evidenceRef =
    'docs/evidence/b11/missing-device-evidence.md';
  assert.throws(
    () => validate({ ...fixture, requirePassed: true }),
    /does not exist: docs\/evidence\/b11\/missing-device-evidence.md/,
  );
});
