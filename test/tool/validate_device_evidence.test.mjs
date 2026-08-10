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
  delete deviceManifest.candidate.android.directAppLinks;
  delete deviceManifest.candidate.android.authenticatedSession;
  delete deviceManifest.candidate.android.syntheticRoleBooking;
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
  delete deviceManifest.candidate.android.directAppLinks;
  delete deviceManifest.candidate.android.authenticatedSession;
  delete deviceManifest.candidate.android.syntheticRoleBooking;
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

function appLinkFixture() {
  const fixture = progressFixture();
  const { root, deviceManifest } = fixture;
  const ref = 'docs/evidence/b11/android-app-link-progress-fixture.json';
  const capturedAt = '2026-08-10T06:00:00.000Z';
  deviceManifest.candidate.android.directAppLinks = {
    status: 'passed',
    capturedAt,
    installMethod: 'direct-apk-diagnostic',
    manufacturer: 'Sanitized Android',
    deviceModel: 'Physical test device',
    osVersion: 'Android test version',
    evidenceRef: ref,
  };
  writeEvidence(root, ref, {
    schemaVersion: 1,
    kind: 'android-direct-app-link-diagnostic',
    status: 'passed-bounded-app-link-diagnostic',
    capturedAt,
    candidate: evidenceCandidate(deviceManifest.candidate),
    installed: {
      packageIdentityVerified: true,
      versionName: deviceManifest.candidate.versionName,
      buildNumber: deviceManifest.candidate.buildNumber,
      apkSha256: deviceManifest.candidate.android.apkSha256,
    },
    device: {
      platform: 'android',
      physical: true,
      manufacturer: 'Sanitized Android',
      model: 'Physical test device',
      osVersion: 'Android test version',
      containsRawDeviceIdentifier: false,
    },
    tests: {
      verifiedHttpsMissingListing: { status: 'passed', result: 'safe-listing-unavailable-surface' },
      customSchemeGuestChat: { status: 'passed', result: 'authentication-required-surface' },
      unsafeIdentifierRejected: { status: 'passed', result: 'guest-start-preserved' },
      foreignHostNotAssociated: { status: 'passed', result: 'shareittoo-package-absent' },
    },
    boundaries: {
      ...safeBoundaries(),
      directDiagnosticOnly: true,
      storeInstallationGateSatisfied: false,
      manualFunctionalMatrixPassed: false,
      authenticatedDeepLinksPassed: false,
      realPushPassed: false,
      lockCodeUsed: false,
    },
  });
  return fixture;
}

function authenticatedSessionFixture() {
  const fixture = progressFixture();
  const { root, deviceManifest } = fixture;
  const ref = 'docs/evidence/b11/android-authenticated-session-progress-fixture.json';
  const capturedAt = '2026-08-10T07:11:48.605Z';
  deviceManifest.candidate.android.authenticatedSession = {
    status: 'passed',
    capturedAt,
    installMethod: 'direct-apk-diagnostic',
    manufacturer: 'Sanitized Android',
    deviceModel: 'Physical test device',
    osVersion: 'Android test version',
    evidenceRef: ref,
  };
  writeEvidence(root, ref, {
    schemaVersion: 1,
    kind: 'android-authenticated-session-diagnostic',
    status: 'passed-bounded-authenticated-session-diagnostic',
    capturedAt,
    candidate: evidenceCandidate(deviceManifest.candidate),
    installed: {
      packageIdentityVerified: true,
      versionName: deviceManifest.candidate.versionName,
      buildNumber: deviceManifest.candidate.buildNumber,
      apkSha256: deviceManifest.candidate.android.apkSha256,
    },
    device: {
      platform: 'android',
      physical: true,
      manufacturer: 'Sanitized Android',
      model: 'Physical test device',
      osVersion: 'Android test version',
      apiLevel: 36,
      securityPatch: '2026-04-05',
      containsRawDeviceIdentifier: false,
    },
    tests: {
      authenticatedProfileAccess: { status: 'passed', result: 'authenticated-actions-present' },
      coldStartSessionRestore: {
        status: 'passed',
        result: 'authenticated-profile-restored-after-force-stop',
      },
    },
    boundaries: {
      directDiagnosticOnly: true,
      storeInstallationGateSatisfied: false,
      syntheticRoleMatrixPassed: false,
      bookingFlowPassed: false,
      authenticatedDeepLinksPassed: false,
      realPushPassed: false,
      manualTalkBackTraversalPassed: false,
      lockCodeUsed: false,
      accountIdentityRecorded: false,
      containsPersonalAccountData: false,
      containsSecrets: false,
      containsRawDeviceIdentifiers: false,
      containsReviewCredentials: false,
    },
  });
  return fixture;
}

function syntheticRoleBookingFixture() {
  const fixture = progressFixture();
  const { root, deviceManifest } = fixture;
  const ref = 'docs/evidence/b11/android-synthetic-role-booking-progress-fixture.json';
  const capturedAt = '2026-08-10T07:50:42.053Z';
  deviceManifest.candidate.android.syntheticRoleBooking = {
    status: 'passed',
    capturedAt,
    installMethod: 'direct-apk-diagnostic',
    manufacturer: 'Sanitized Android',
    deviceModel: 'Physical test device',
    osVersion: 'Android test version',
    evidenceRef: ref,
  };
  writeEvidence(root, ref, {
    schemaVersion: 1,
    kind: 'android-synthetic-role-booking-diagnostic',
    status: 'passed-bounded-synthetic-role-booking-diagnostic',
    capturedAt,
    candidate: evidenceCandidate(deviceManifest.candidate),
    installed: {
      packageIdentityVerified: true,
      versionName: deviceManifest.candidate.versionName,
      buildNumber: deviceManifest.candidate.buildNumber,
      apkSha256: deviceManifest.candidate.android.apkSha256,
    },
    device: {
      platform: 'android',
      physical: true,
      manufacturer: 'Sanitized Android',
      model: 'Physical test device',
      osVersion: 'Android test version',
      apiLevel: 36,
      securityPatch: '2026-04-05',
      containsRawDeviceIdentifier: false,
    },
    backendFixture: {
      accountCount: 2,
      roles: ['owner', 'renter'],
      registration: 'public-staging-accepted',
      verification: 'isolated-staging-fixture',
      listingStatus: 'active',
      workflow: ['requested', 'accepted', 'active', 'completed'],
      paymentMode: 'memory',
      stripeLivemode: false,
      paymentEndpointCalled: false,
    },
    tests: {
      ownerRequestVisibility: { status: 'passed', result: 'requested-visible-to-owner' },
      renterUpcomingVisibility: { status: 'passed', result: 'accepted-visible-to-renter' },
      renterRunningVisibility: { status: 'passed', result: 'active-visible-to-renter' },
      renterCompletedVisibility: { status: 'passed', result: 'completed-visible-to-renter' },
    },
    boundaries: {
      ...safeBoundaries(),
      directDiagnosticOnly: true,
      storeInstallationGateSatisfied: false,
      fullDeviceMatrixPassed: false,
      wifiOnlyDiagnostic: true,
      hotspotPassed: false,
      authenticatedDeepLinksPassed: false,
      realPushPassed: false,
      manualTalkBackTraversalPassed: false,
      iosTestFlightPassed: false,
      paymentEndpointCalled: false,
      stripeLivemode: false,
      lockCodeUsed: false,
      accountIdentityRecorded: false,
      containsPersonalAccountData: false,
    },
  });
  return fixture;
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

test('accepts exact, bounded direct app-link evidence without closing device gates', () => {
  const fixture = appLinkFixture();
  const summary = validate(fixture);
  assert.equal(summary.state, 'testing');
  assert.equal(summary.matrixPassed, 0);
});

test('direct app-link evidence cannot claim an authenticated or store-install pass', () => {
  const fixture = appLinkFixture();
  const ref = fixture.deviceManifest.candidate.android.directAppLinks.evidenceRef;
  const evidence = JSON.parse(readFileSync(resolve(fixture.root, ref), 'utf8'));
  evidence.boundaries.authenticatedDeepLinksPassed = true;
  writeEvidence(fixture.root, ref, evidence);
  assert.throws(
    () => validate(fixture),
    /must keep store, manual, authenticated, push, and lock-code gates open/,
  );
});

test('direct app-link evidence rejects a different installed candidate APK', () => {
  const fixture = appLinkFixture();
  const ref = fixture.deviceManifest.candidate.android.directAppLinks.evidenceRef;
  const evidence = JSON.parse(readFileSync(resolve(fixture.root, ref), 'utf8'));
  evidence.installed.apkSha256 = 'f'.repeat(64);
  writeEvidence(fixture.root, ref, evidence);
  assert.throws(
    () => validate(fixture),
    /must prove the exact installed candidate APK and package identity/,
  );
});

test('accepts exact, bounded authenticated-session evidence without closing device gates', () => {
  const fixture = authenticatedSessionFixture();
  const summary = validate(fixture);
  assert.equal(summary.state, 'testing');
  assert.equal(summary.matrixPassed, 0);
});

test('authenticated-session evidence rejects a different installed candidate APK', () => {
  const fixture = authenticatedSessionFixture();
  const ref = fixture.deviceManifest.candidate.android.authenticatedSession.evidenceRef;
  const evidence = JSON.parse(readFileSync(resolve(fixture.root, ref), 'utf8'));
  evidence.installed.apkSha256 = 'f'.repeat(64);
  writeEvidence(fixture.root, ref, evidence);
  assert.throws(
    () => validate(fixture),
    /must prove the exact installed candidate APK and package identity/,
  );
});

test('authenticated-session evidence cannot record identity or close the synthetic role matrix', () => {
  const fixture = authenticatedSessionFixture();
  const ref = fixture.deviceManifest.candidate.android.authenticatedSession.evidenceRef;
  const evidence = JSON.parse(readFileSync(resolve(fixture.root, ref), 'utf8'));
  evidence.boundaries.accountIdentityRecorded = true;
  evidence.boundaries.syntheticRoleMatrixPassed = true;
  writeEvidence(fixture.root, ref, evidence);
  assert.throws(
    () => validate(fixture),
    /must remain identity-free and keep store, role, booking, link, push, TalkBack, and lock-code gates open/,
  );
});

test('accepts exact, bounded synthetic-role booking evidence without closing the device matrix', () => {
  const fixture = syntheticRoleBookingFixture();
  const summary = validate(fixture);
  assert.equal(summary.state, 'testing');
  assert.equal(summary.matrixPassed, 0);
});

test('synthetic-role booking evidence rejects a different candidate APK', () => {
  const fixture = syntheticRoleBookingFixture();
  const ref = fixture.deviceManifest.candidate.android.syntheticRoleBooking.evidenceRef;
  const evidence = JSON.parse(readFileSync(resolve(fixture.root, ref), 'utf8'));
  evidence.installed.apkSha256 = 'f'.repeat(64);
  writeEvidence(fixture.root, ref, evidence);
  assert.throws(
    () => validate(fixture),
    /must prove the exact installed candidate APK and package identity/,
  );
});

test('synthetic-role booking evidence cannot claim payment, hotspot, or the full matrix', () => {
  const fixture = syntheticRoleBookingFixture();
  const ref = fixture.deviceManifest.candidate.android.syntheticRoleBooking.evidenceRef;
  const evidence = JSON.parse(readFileSync(resolve(fixture.root, ref), 'utf8'));
  evidence.boundaries.paymentEndpointCalled = true;
  evidence.boundaries.hotspotPassed = true;
  evidence.boundaries.fullDeviceMatrixPassed = true;
  writeEvidence(fixture.root, ref, evidence);
  assert.throws(
    () => validate(fixture),
    /must keep store, matrix, hotspot, link, push, TalkBack, iOS, payment, identity, and lock-code gates open/,
  );
});
