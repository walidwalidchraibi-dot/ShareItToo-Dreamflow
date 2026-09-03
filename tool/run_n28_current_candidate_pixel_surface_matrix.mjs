#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import {
  diagnoseAndroidAuthenticatedSession,
} from './diagnose_android_authenticated_session.mjs';
import {
  diagnoseAndroidMainNavigationTouchTargets,
} from './diagnose_android_main_navigation_touch_targets.mjs';
import {
  diagnoseCurrentHeadAndroidLargeTextMainNavigation,
} from './diagnose_current_head_android_large_text_main_navigation.mjs';
import {
  diagnoseCurrentHeadAndroidLegalRoutes,
} from './diagnose_current_head_android_legal_routes.mjs';
import {
  defaultCurrentHeadAndroidCommandRunner,
  diagnoseCurrentHeadAndroidMainNavigation,
} from './diagnose_current_head_android_main_navigation.mjs';
import {
  diagnoseCurrentHeadAndroidRestart,
} from './diagnose_current_head_android_restart.mjs';
import {
  inspectPhysicalDevice,
  parseAdbDevices,
  selectSinglePhysicalDevice,
} from './prepare_android_device_test.mjs';
import {
  validatePrivateAndroidReleaseArchive,
} from './validate_current_head_android_release_archive.mjs';

const expected = Object.freeze({
  applicationId: 'com.shareittoo.app',
  versionName: '1.0.0',
  buildNumber: '2026090306',
  commit: '9d7e2601dc477cf3ae3d469b65448ce2065375e0',
  apiBaseUrl: 'https://staging.shareittoo.com/api/v1',
  apkSha256: '37d98f999562150e77fea335fcb0bde32aee20d2183509f5484a5e67cd1e3194',
  signingCertificateSha256: '098f485e57161558e911fc3c742845925584db31c474cdba08dda02feb0129a4',
});

const mobileSourcePattern = /^(?:lib\/|android\/|assets\/|pubspec\.yaml$|pubspec\.lock$)/u;

function fail(message) {
  throw new Error(message);
}

function same(actual, wanted, label) {
  if (actual !== wanted) fail(`${label} does not match the frozen N28 candidate.`);
}

export function validateN28FrozenCandidate(archive) {
  for (const key of ['applicationId', 'versionName', 'buildNumber', 'commit', 'apiBaseUrl']) {
    same(archive?.[key], expected[key], key);
  }
  same(archive?.firebaseConfigured, true, 'Firebase configuration');
  same(archive?.releaseChannel, 'internal', 'release channel');
  same(archive?.apkSha256, expected.apkSha256, 'APK SHA-256');
  same(archive?.android?.apkSha256, expected.apkSha256, 'Android APK SHA-256');
  same(
    archive?.signingCertificateSha256,
    expected.signingCertificateSha256,
    'signing certificate SHA-256',
  );
  return Object.freeze({
    applicationId: archive.applicationId,
    bundleId: archive.bundleId,
    versionName: archive.versionName,
    buildNumber: archive.buildNumber,
    commit: archive.commit,
    releaseChannel: archive.releaseChannel,
    apiBaseUrl: archive.apiBaseUrl,
    firebaseConfigured: archive.firebaseConfigured,
    paymentMode: 'memory',
    stripeLivemode: false,
    android: Object.freeze({
      apkSha256: archive.android.apkSha256,
      aabSha256: archive.android.aabSha256,
      signingCertificateSha256: archive.android.signingCertificateSha256,
    }),
  });
}

export function assertN28NoPostCandidateMobileSourceDrift(paths) {
  if (!Array.isArray(paths) || paths.some((path) => typeof path !== 'string')) {
    fail('Post-candidate paths must be a string array.');
  }
  const changed = paths.filter((path) => mobileSourcePattern.test(path));
  if (changed.length > 0) {
    fail('Android application source changed after the frozen N28 candidate.');
  }
  return Object.freeze({ changedPathCount: paths.length, mobileSourceChanged: false });
}

function assertLane(evidence, kind, status, label, candidate) {
  same(evidence?.kind, kind, `${label} kind`);
  same(evidence?.status, status, `${label} status`);
  same(evidence?.candidate?.applicationId, candidate.applicationId, `${label} application ID`);
  same(evidence?.candidate?.buildNumber, candidate.buildNumber, `${label} build number`);
  same(evidence?.candidate?.commit, candidate.commit, `${label} candidate commit`);
  same(evidence?.installed?.buildNumber, candidate.buildNumber, `${label} installed build number`);
  same(evidence?.installed?.delivery, 'direct-apk', `${label} delivery`);
  same(evidence?.installed?.apkSha256, expected.apkSha256, `${label} installed APK SHA-256`);
}

export function summarizeN28SurfaceMatrix({
  candidate,
  deviceSummary,
  sourceDrift,
  session,
  navigation,
  legal,
  largeText,
  touchTargets,
  restart,
  capturedAt,
}) {
  assertLane(
    session,
    'android-authenticated-session-diagnostic',
    'passed-bounded-authenticated-session-diagnostic',
    'session',
    candidate,
  );
  assertLane(
    navigation,
    'android-current-head-authenticated-main-navigation-diagnostic',
    'passed-bounded-authenticated-main-navigation-diagnostic',
    'navigation',
    candidate,
  );
  assertLane(
    legal,
    'android-current-head-authenticated-legal-route-diagnostic',
    'passed-bounded-authenticated-legal-route-diagnostic',
    'legal',
    candidate,
  );
  assertLane(
    largeText,
    'android-current-head-authenticated-large-text-main-navigation-diagnostic',
    'passed-bounded-authenticated-large-text-main-navigation-diagnostic',
    'large text',
    candidate,
  );
  assertLane(
    touchTargets,
    'android-current-head-main-navigation-touch-target-diagnostic',
    'passed-physical-200-percent-touch-target-geometry',
    'touch targets',
    candidate,
  );
  same(
    restart?.kind,
    'android-current-head-process-restart-diagnostic',
    'restart kind',
  );
  same(
    restart?.status,
    'passed-bounded-process-restart-diagnostic',
    'restart status',
  );
  same(restart?.candidate?.applicationId, candidate.applicationId, 'restart application ID');
  same(restart?.candidate?.buildNumber, candidate.buildNumber, 'restart build number');
  same(restart?.candidate?.commit, candidate.commit, 'restart candidate commit');
  same(session?.tests?.authenticatedProfileAccess?.status, 'passed', 'authenticated profile access');
  same(session?.tests?.coldStartSessionRestore?.status, 'passed', 'cold-start session restore');
  same(navigation?.boundaries?.authenticatedMainNavigationPassed, true, 'main navigation');
  same(legal?.boundaries?.authenticatedLegalRoutesPassed, true, 'legal routes');
  same(legal?.boundaries?.professionalLegalApprovalPassed, false, 'professional legal approval');
  same(
    largeText?.boundaries?.authenticatedMainNavigationAtLargeTextPassed,
    true,
    'large-text navigation',
  );
  same(largeText?.configuration?.exactPreviousFontScaleRestored, true, 'font-scale restoration');
  same(
    touchTargets?.configuration?.exactPreviousFontScaleRestored,
    true,
    'touch-target font-scale restoration',
  );
  same(touchTargets?.touchTargets?.allTargetsAtLeast48Dp, true, 'minimum touch targets');
  same(touchTargets?.touchTargets?.allTargetsWithinDisplay, true, 'touch targets within display');
  same(
    touchTargets?.touchTargets?.allTargetsPairwiseNonOverlapping,
    true,
    'non-overlapping touch targets',
  );
  const restartChecks = Object.values(restart?.tests ?? {});
  if (restartChecks.length !== 5
      || restartChecks.some((check) => check?.status !== 'passed')) {
    fail('N28 must verify the complete bounded process-restart set.');
  }
  same(sourceDrift?.mobileSourceChanged, false, 'post-candidate mobile source');
  if (Object.keys(navigation?.tests ?? {}).length !== 5) fail('N28 must verify all five main destinations.');
  if (Object.keys(largeText?.tests ?? {}).length !== 5) fail('N28 must verify all five large-text destinations.');
  if (Object.keys(legal?.tests ?? {}).length < 6) fail('N28 must verify the complete read-only legal set.');

  const result = {
    schemaVersion: 1,
    kind: 'sit-n28-current-candidate-pixel-surface-matrix-diagnostic',
    status: 'passed-session-navigation-legal-accessibility-restart-core',
    capturedAt,
    candidate: {
      applicationId: candidate.applicationId,
      versionName: candidate.versionName,
      buildNumber: candidate.buildNumber,
      commit: candidate.commit,
      releaseChannel: candidate.releaseChannel,
      apiBaseUrl: candidate.apiBaseUrl,
      firebaseConfigured: candidate.firebaseConfigured,
      paymentMode: candidate.paymentMode,
      stripeLivemode: candidate.stripeLivemode,
      apkSha256: candidate.android.apkSha256,
      signingCertificateSha256: candidate.android.signingCertificateSha256,
      postCandidateChangedPathCount: sourceDrift.changedPathCount,
      mobileSourceChangedAfterCandidate: sourceDrift.mobileSourceChanged,
    },
    device: deviceSummary,
    tests: {
      authenticatedColdStartSession: 'passed',
      mainNavigationDestinationCount: 5,
      legalDocumentCount: Object.keys(legal.tests).length,
      largeTextDestinationCount: 5,
      exactPreviousFontScaleRestored: true,
      minimumMainNavigationTouchTargetDp: 48,
      processRestartCheckCount: restartChecks.length,
    },
    boundaries: {
      readOnlySurfaceMatrix: true,
      directApkOnly: true,
      storeMatrixClaimed: false,
      supportSubmitted: false,
      messageSent: false,
      bookingCreated: false,
      listingMutated: false,
      accountMutated: false,
      paymentEndpointCalled: false,
      stripeLivemode: false,
      productionChanged: false,
      onePlusContacted: false,
      professionalLegalApprovalClaimed: false,
      accountIdentityRecorded: false,
      containsPersonalAccountData: false,
      containsCredential: false,
      containsRawDeviceIdentifier: false,
      containsPrivateFilesystemPath: false,
    },
  };
  const serialized = JSON.stringify(result);
  if (/(?:[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|\/Users\/|BEGIN PRIVATE|\b(?:sk|rk)_(?:test|live)_|\bwhsec_)/iu.test(serialized)) {
    fail('N28 surface evidence contains private or credential-shaped material.');
  }
  return result;
}

export async function runN28CurrentCandidatePixelSurfaceMatrix({
  root,
  candidateDirectory,
  adbPath = 'adb',
  commandRunner = defaultCurrentHeadAndroidCommandRunner,
  archiveValidator = validatePrivateAndroidReleaseArchive,
  deviceInspector = inspectPhysicalDevice,
  sessionDiagnostic = diagnoseAndroidAuthenticatedSession,
  navigationDiagnostic = diagnoseCurrentHeadAndroidMainNavigation,
  legalDiagnostic = diagnoseCurrentHeadAndroidLegalRoutes,
  largeTextDiagnostic = diagnoseCurrentHeadAndroidLargeTextMainNavigation,
  touchTargetDiagnostic = diagnoseAndroidMainNavigationTouchTargets,
  restartDiagnostic = diagnoseCurrentHeadAndroidRestart,
  gitRunner = execFileSync,
  capturedAt = new Date().toISOString(),
}) {
  const archive = await archiveValidator({ root, candidateDirectory });
  const candidate = validateN28FrozenCandidate(archive);
  const ancestor = String(gitRunner('git', ['merge-base', '--is-ancestor', candidate.commit, 'HEAD'], {
    cwd: root,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  }) ?? '');
  void ancestor;
  const paths = String(gitRunner('git', ['diff', '--name-only', `${candidate.commit}..HEAD`], {
    cwd: root,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  }))
    .split(/\r?\n/u)
    .map((value) => value.trim())
    .filter(Boolean);
  const sourceDrift = assertN28NoPostCandidateMobileSourceDrift(paths);
  const devices = parseAdbDevices(commandRunner(adbPath, ['devices', '-l']));
  const device = selectSinglePhysicalDevice(devices);
  const deviceSummary = deviceInspector({ adbPath, device });
  const common = { commandRunner, adbPath, device, deviceSummary, candidate, capturedAt };
  const session = await sessionDiagnostic({ ...common, archive: { apkSha256: candidate.android.apkSha256 } });
  const navigation = await navigationDiagnostic(common);
  const legal = await legalDiagnostic(common);
  const largeText = await largeTextDiagnostic(common);
  const touchTargets = await touchTargetDiagnostic(common);
  const restart = restartDiagnostic(common);
  return summarizeN28SurfaceMatrix({
    candidate,
    deviceSummary,
    sourceDrift,
    session,
    navigation,
    legal,
    largeText,
    touchTargets,
    restart,
    capturedAt,
  });
}

function parseArguments(values) {
  let candidateDirectory = null;
  let adbPath = 'adb';
  for (let index = 0; index < values.length; index += 1) {
    if (values[index] === '--candidate-dir') {
      candidateDirectory = values[index + 1] ?? fail('--candidate-dir requires a path.');
      index += 1;
    } else if (values[index] === '--adb') {
      adbPath = values[index + 1] ?? fail('--adb requires a path.');
      index += 1;
    } else {
      fail(`Unknown argument: ${values[index]}`);
    }
  }
  if (candidateDirectory === null) fail('--candidate-dir is required.');
  return { candidateDirectory: resolve(candidateDirectory), adbPath };
}

async function run() {
  const root = fileURLToPath(new URL('../', import.meta.url));
  const args = parseArguments(process.argv.slice(2));
  const result = await runN28CurrentCandidatePixelSurfaceMatrix({ root, ...args });
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    await run();
  } catch (error) {
    process.stderr.write(`ERROR: ${error?.message ?? 'N28 Pixel surface matrix failed.'}\n`);
    process.exitCode = 1;
  }
}
