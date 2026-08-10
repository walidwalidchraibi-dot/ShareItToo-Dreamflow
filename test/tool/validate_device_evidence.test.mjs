import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, symlinkSync, writeFileSync } from 'node:fs';
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

function writeEvidence(root, ref, contents) {
  const target = resolve(root, ref);
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, `${JSON.stringify(contents, null, 2)}\n`);
}

function evidenceCandidate(candidate) {
  return {
    applicationId: candidate.applicationId,
    bundleId: candidate.bundleId,
    versionName: candidate.versionName,
    buildNumber: candidate.buildNumber,
    commit: candidate.commit,
    releaseChannel: candidate.releaseChannel,
    apiBaseUrl: candidate.apiBaseUrl,
    firebaseConfigured: candidate.firebaseConfigured,
    paymentMode: candidate.paymentMode,
    stripeLivemode: candidate.stripeLivemode,
  };
}

function safeBoundaries() {
  return {
    containsSecrets: false,
    containsRawDeviceIdentifiers: false,
    containsReviewCredentials: false,
    syntheticAccountsOnly: true,
  };
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
  delete deviceManifest.candidate.android.directDiagnostic;
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
    cell.evidenceRef = `docs/evidence/b11/${cell.id}.json`;
    const checkedAt = '2026-08-09T18:00:00+02:00';
    writeEvidence(root, cell.evidenceRef, {
      schemaVersion: 1,
      kind: 'device-matrix-cell',
      status: 'passed',
      capturedAt: checkedAt,
      candidate: evidenceCandidate(deviceManifest.candidate),
      cell: {
        id: cell.id,
        platform: cell.platform,
        network: cell.network,
        role: cell.role,
        deviceType: cell.deviceType,
        deviceModel: cell.deviceModel,
        osVersion: cell.osVersion,
        storeInstall: cell.storeInstall,
        screenReader: cell.screenReader,
        tests: Object.fromEntries(Object.keys(cell.tests).map((id) => [id, {
          status: 'passed',
          checkedAt,
          summary: `Sanitized ${id} verification`,
        }])),
      },
      boundaries: safeBoundaries(),
    });
  }

  for (const [key, check] of Object.entries(deviceManifest.releaseChecks)) {
    check.status = 'passed';
    check.evidenceRef = `docs/evidence/b11/release-${key}.json`;
    writeEvidence(root, check.evidenceRef, {
      schemaVersion: 1,
      kind: 'release-check',
      status: 'passed',
      capturedAt: '2026-08-09T18:00:00+02:00',
      candidate: evidenceCandidate(deviceManifest.candidate),
      releaseCheck: {
        id: key,
        status: 'passed',
        verifications: [{
          id: `${key}-verification`,
          status: 'passed',
          checkedAt: '2026-08-09T18:00:00+02:00',
          summary: `Sanitized ${key} verification`,
        }],
      },
      boundaries: safeBoundaries(),
    });
  }

  for (const [key, approval] of Object.entries(deviceManifest.approvals)) {
    approval.status = 'passed';
    approval.approvedAt = '2026-08-09T18:00:00+02:00';
    approval.evidenceRef = `docs/evidence/b11/approval-${key}.json`;
    writeEvidence(root, approval.evidenceRef, {
      schemaVersion: 1,
      kind: 'approval',
      status: 'passed',
      candidate: evidenceCandidate(deviceManifest.candidate),
      approval: {
        type: key,
        decision: 'approved',
        approvedAt: approval.approvedAt,
        statement: `Sanitized ${key} approval`,
      },
      boundaries: safeBoundaries(),
    });
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

function progressFixture() {
  const root = mkdtempSync(resolve(tmpdir(), 'sit-device-progress-'));
  const deviceManifest = clone(baseDeviceManifest);
  const diagnosticRef = 'docs/evidence/b11/android-direct-smoke-progress-fixture.json';
  const capturedAt = '2026-08-09T18:00:00+02:00';
  deviceManifest.candidate.android.directDiagnostic = {
    status: 'passed',
    capturedAt,
    installMethod: 'direct-apk-diagnostic',
    manufacturer: 'Sanitized Android',
    deviceModel: 'Physical test device',
    osVersion: 'Android test version',
    evidenceRef: diagnosticRef,
  };
  writeEvidence(root, diagnosticRef, {
    schemaVersion: 1,
    kind: 'android-direct-device-smoke',
    status: 'installed-launched-pending-manual-matrix',
    capturedAt,
    candidate: {
      ...evidenceCandidate(deviceManifest.candidate),
      apkSha256: deviceManifest.candidate.android.apkSha256,
      signingCertificateSha256:
        deviceManifest.candidate.android.signingCertificateSha256,
      privacyScan: 'passed',
    },
    installation: {
      method: 'direct-apk-diagnostic',
      installed: true,
      installedVersionVerified: true,
      installedBuildVerified: true,
      firstLaunchEvent: 'passed',
      foregroundActivityVerified: true,
      storeInstallationGateSatisfied: false,
    },
    boundaries: {
      ...safeBoundaries(),
      manualFunctionalMatrixPassed: false,
      playInternalInstallPassed: false,
      realPushPassed: false,
    },
    device: {
      platform: 'android',
      physical: true,
      manufacturer: 'Sanitized Android',
      model: 'Physical test device',
      osVersion: 'Android test version',
      containsRawDeviceIdentifier: false,
    },
  });
  const refs = new Set(
    Object.values(deviceManifest.releaseChecks)
      .map((check) => check.evidenceRef)
      .filter((ref) => ref !== null),
  );
  for (const ref of refs) {
    const source = resolve(repositoryRoot, ref);
    const target = resolve(root, ref);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, readFileSync(source));
  }
  return {
    root,
    deviceManifest,
    submissionManifest: clone(baseSubmissionManifest),
    pubspecText: basePubspec,
  };
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

test('a non-empty but unstructured device evidence file cannot satisfy a passed cell', () => {
  const fixture = passedFixture();
  const ref = fixture.deviceManifest.deviceMatrix[0].evidenceRef;
  writeFileSync(resolve(fixture.root, ref), 'sanitized but unstructured evidence\n');
  assert.throws(
    () => validate({ ...fixture, requirePassed: true }),
    /must contain valid JSON evidence/,
  );
});

test('device evidence must be bound to the same candidate commit', () => {
  const fixture = passedFixture();
  const ref = fixture.deviceManifest.deviceMatrix[0].evidenceRef;
  const evidence = JSON.parse(readFileSync(resolve(fixture.root, ref), 'utf8'));
  evidence.candidate.commit = 'f'.repeat(40);
  writeEvidence(fixture.root, ref, evidence);
  assert.throws(
    () => validate({ ...fixture, requirePassed: true }),
    /candidate.commit must match store\/device-validation.json/,
  );
});

test('device evidence rejects raw device identifier fields', () => {
  const fixture = passedFixture();
  const ref = fixture.deviceManifest.deviceMatrix[0].evidenceRef;
  const evidence = JSON.parse(readFileSync(resolve(fixture.root, ref), 'utf8'));
  evidence.cell.serialNumber = 'PRIVATE-SERIAL';
  writeEvidence(fixture.root, ref, evidence);
  assert.throws(
    () => validate({ ...fixture, requirePassed: true }),
    /must never contain a raw device identifier/,
  );
});

test('release-check evidence cannot prove a different release check', () => {
  const fixture = passedFixture();
  const ref = fixture.deviceManifest.releaseChecks.firebaseFcmAndApns.evidenceRef;
  const evidence = JSON.parse(readFileSync(resolve(fixture.root, ref), 'utf8'));
  evidence.releaseCheck.id = 'binaryPrivacyAndNetwork';
  writeEvidence(fixture.root, ref, evidence);
  assert.throws(
    () => validate({ ...fixture, requirePassed: true }),
    /must identify firebaseFcmAndApns as passed/,
  );
});

test('passed evidence cannot be supplied through a symbolic link', () => {
  const fixture = passedFixture();
  const cell = fixture.deviceManifest.deviceMatrix[0];
  const originalRef = cell.evidenceRef;
  const linkedRef = 'docs/evidence/b11/linked-device-evidence.json';
  symlinkSync(resolve(fixture.root, originalRef), resolve(fixture.root, linkedRef));
  cell.evidenceRef = linkedRef;
  assert.throws(
    () => validate({ ...fixture, requirePassed: true }),
    /must not reference a symbolic link/,
  );
});

test('passed evidence cannot escape through a linked parent directory', () => {
  const fixture = passedFixture();
  const cell = fixture.deviceManifest.deviceMatrix[0];
  const outside = resolve(fixture.root, 'outside-evidence');
  mkdirSync(outside, { recursive: true });
  const outsideFile = resolve(outside, 'device.json');
  writeFileSync(outsideFile, readFileSync(resolve(fixture.root, cell.evidenceRef)));
  const linkedDirectory = resolve(fixture.root, 'docs/evidence/b11/linked-parent');
  symlinkSync(outside, linkedDirectory, 'dir');
  cell.evidenceRef = 'docs/evidence/b11/linked-parent/device.json';
  assert.throws(
    () => validate({ ...fixture, requirePassed: true }),
    /must not escape the B11 evidence directory through a linked path/,
  );
});

test('direct diagnostic evidence must stay bound to the same candidate commit', () => {
  const fixture = progressFixture();
  const ref = fixture.deviceManifest.candidate.android.directDiagnostic.evidenceRef;
  const evidence = JSON.parse(readFileSync(resolve(fixture.root, ref), 'utf8'));
  evidence.candidate.commit = 'f'.repeat(40);
  writeEvidence(fixture.root, ref, evidence);
  assert.throws(
    () => validate(fixture),
    /candidate.commit must match store\/device-validation.json/,
  );
});

test('direct diagnostic evidence cannot claim Play Internal or real push', () => {
  const fixture = progressFixture();
  const ref = fixture.deviceManifest.candidate.android.directDiagnostic.evidenceRef;
  const evidence = JSON.parse(readFileSync(resolve(fixture.root, ref), 'utf8'));
  evidence.boundaries.playInternalInstallPassed = true;
  writeEvidence(fixture.root, ref, evidence);
  assert.throws(
    () => validate(fixture),
    /must keep manual, Play Internal, and real-push gates open/,
  );
});
