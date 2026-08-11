#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { homedir } from 'node:os';
import { resolve } from 'node:path';
import { readFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';

import {
  inspectPhysicalDevice,
  parseAdbDevices,
  selectSinglePhysicalDevice,
  validateCandidateArchive,
} from './prepare_android_device_test.mjs';
import {
  ensureAndroidGuestSession,
  restoreSyntheticSession,
} from './diagnose_android_logout_lifecycle.mjs';

const applicationId = 'com.shareittoo.app';
const remoteUiDump = '/sdcard/sit-app-link-diagnostic.xml';

function fail(message) {
  throw new Error(message);
}

function nonEmptyString(value, label) {
  if (typeof value !== 'string' || value.trim() === '') {
    fail(`${label} must be a non-empty string.`);
  }
  return value.trim();
}

function sha256Bytes(value) {
  return createHash('sha256').update(value).digest('hex');
}

function defaultCommandRunner(file, args, { binary = false } = {}) {
  return execFileSync(file, args, {
    encoding: binary ? null : 'utf8',
    maxBuffer: 512 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function adb(commandRunner, adbPath, device, args, { binary = false } = {}) {
  try {
    const result = commandRunner(adbPath, ['-s', device.serial, ...args], { binary });
    return binary ? Buffer.from(result) : String(result).trim();
  } catch {
    fail('ADB app-link diagnostic command failed without exposing the device identifier.');
  }
}

function parseInstalledPackage(output) {
  const versionName = /^\s*versionName=([^\s]+)\s*$/m.exec(output)?.[1] ?? null;
  const buildNumber = /^\s*versionCode=(\d+)\b/m.exec(output)?.[1] ?? null;
  if (versionName === null || buildNumber === null) {
    fail('Installed ShareItToo version could not be verified.');
  }
  return { versionName, buildNumber };
}

function assertDeviceAlreadyUnlocked(commandRunner, adbPath, device) {
  const policy = adb(commandRunner, adbPath, device, ['shell', 'dumpsys', 'window', 'policy']);
  if (/keyguardShowing=true|isStatusBarKeyguard=true/.test(policy)) {
    fail('The Android phone is locked. Unlock it manually; this diagnostic never enters a passcode.');
  }
}

function verifyInstalledCandidate(commandRunner, adbPath, device, candidate, archive) {
  const packagePaths = adb(commandRunner, adbPath, device, ['shell', 'pm', 'path', applicationId])
    .split(/\r?\n/)
    .map((line) => line.replace(/^package:/, '').trim())
    .filter(Boolean);
  if (packagePaths.length !== 1 || !packagePaths[0].startsWith('/data/app/')) {
    fail('Installed ShareItToo package path is missing or ambiguous.');
  }
  const installedBytes = adb(
    commandRunner,
    adbPath,
    device,
    ['exec-out', 'cat', packagePaths[0]],
    { binary: true },
  );
  const installedSha256 = sha256Bytes(installedBytes);
  if (installedSha256 !== archive.apkSha256 || installedSha256 !== candidate.android.apkSha256) {
    fail('Installed ShareItToo APK does not match the verified candidate.');
  }
  const installed = parseInstalledPackage(
    adb(commandRunner, adbPath, device, ['shell', 'dumpsys', 'package', applicationId]),
  );
  if (installed.versionName !== candidate.versionName || installed.buildNumber !== candidate.buildNumber) {
    fail('Installed ShareItToo version does not match the verified candidate.');
  }
  return { ...installed, apkSha256: installedSha256 };
}

function startLink(commandRunner, adbPath, device, uri) {
  adb(commandRunner, adbPath, device, ['shell', 'am', 'force-stop', applicationId]);
  const result = adb(commandRunner, adbPath, device, [
    'shell',
    'am',
    'start',
    '-W',
    '-a',
    'android.intent.action.VIEW',
    '-c',
    'android.intent.category.BROWSABLE',
    '-p',
    applicationId,
    '-d',
    uri,
  ]);
  if (!/Status:\s*ok/.test(result) || !result.includes(applicationId)) {
    fail('Android did not route the expected ShareItToo link to the app.');
  }
}

function dumpUi(commandRunner, adbPath, device) {
  adb(commandRunner, adbPath, device, ['shell', 'uiautomator', 'dump', remoteUiDump]);
  try {
    return adb(commandRunner, adbPath, device, ['exec-out', 'cat', remoteUiDump]).trim();
  } finally {
    try {
      adb(commandRunner, adbPath, device, ['shell', 'rm', '-f', remoteUiDump]);
    } catch {
      // The diagnostic output never depends on cleanup success. The fixed file
      // contains only the guest UI hierarchy and is overwritten on the next run.
    }
  }
}

async function waitForUi({
  commandRunner,
  adbPath,
  device,
  requiredAll = [],
  requiredAny = [],
  forbidden = [],
  wait,
}) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    await wait(900);
    const hierarchy = dumpUi(commandRunner, adbPath, device);
    const allPresent = requiredAll.every((value) => hierarchy.includes(value));
    const anyPresent = requiredAny.length === 0 || requiredAny.some((value) => hierarchy.includes(value));
    const forbiddenAbsent = forbidden.every((value) => !hierarchy.includes(value));
    if (allPresent && anyPresent && forbiddenAbsent) return;
  }
  fail('The expected sanitized ShareItToo app-link surface did not appear.');
}

function queryForeignHost(commandRunner, adbPath, device) {
  const result = adb(commandRunner, adbPath, device, [
    'shell',
    'cmd',
    'package',
    'query-activities',
    '--brief',
    '--components',
    '-a',
    'android.intent.action.VIEW',
    '-c',
    'android.intent.category.BROWSABLE',
    '-d',
    'https://attacker.invalid/api/v1/open/listing/sit-link-diagnostic',
  ]);
  if (result.includes(applicationId)) {
    fail('ShareItToo must not be associated with a foreign web host.');
  }
}

function restoreGuestStart(commandRunner, adbPath, device) {
  try {
    adb(commandRunner, adbPath, device, ['shell', 'am', 'force-stop', applicationId]);
    adb(commandRunner, adbPath, device, [
      'shell',
      'monkey',
      '-p',
      applicationId,
      '-c',
      'android.intent.category.LAUNCHER',
      '1',
    ]);
  } catch {
    // Do not mask an already completed diagnostic if the final convenience
    // launch fails. The app remains safely stopped or on its last guest page.
  }
}

export async function diagnoseAndroidAppLinks({
  vaultFile = null,
  commandRunner = defaultCommandRunner,
  adbPath = 'adb',
  device,
  deviceSummary,
  candidate,
  archive,
  capturedAt = new Date().toISOString(),
  wait = (milliseconds) => new Promise((resolvePromise) => setTimeout(resolvePromise, milliseconds)),
}) {
  assertDeviceAlreadyUnlocked(commandRunner, adbPath, device);
  const installed = verifyInstalledCandidate(commandRunner, adbPath, device, candidate, archive);
  const account = vaultFile === null
    ? null
    : JSON.parse(readFileSync(vaultFile, 'utf8')).accounts?.[0] ?? fail('The private synthetic account fixture is unavailable.');
  if (account !== null) {
    await ensureAndroidGuestSession({ commandRunner, adbPath, device, wait });
  }

  try {
    startLink(
      commandRunner,
      adbPath,
      device,
      'https://staging.shareittoo.com/api/v1/open/listing/sit-link-diagnostic-missing',
    );
    await waitForUi({
      commandRunner,
      adbPath,
      device,
      requiredAll: [
        'Anzeige nicht verfügbar',
        'Die Anzeige wurde entfernt, pausiert oder ist nicht mehr öffentlich.',
        'Erneut prüfen',
      ],
      wait,
    });

    startLink(commandRunner, adbPath, device, 'shareittoo://chat/sit-link-diagnostic');
    await waitForUi({
      commandRunner,
      adbPath,
      device,
      requiredAll: [
        'Bitte zuerst anmelden',
        'Nach der Anmeldung öffnen wir den sicheren Chat-Kontext.',
        'Anmelden',
      ],
      wait,
    });

    startLink(
      commandRunner,
      adbPath,
      device,
      'https://staging.shareittoo.com/api/v1/open/listing/not%2Fsafe',
    );
    await waitForUi({
      commandRunner,
      adbPath,
      device,
      requiredAny: ['ShareItToo', 'Erkunden', 'Jetzt suchen'],
      forbidden: ['Anzeige nicht verfügbar', 'Bitte zuerst anmelden', 'sicheren Chat-Kontext'],
      wait,
    });

    queryForeignHost(commandRunner, adbPath, device);
  } finally {
    restoreGuestStart(commandRunner, adbPath, device);
    if (account !== null) {
      const restored = await restoreSyntheticSession({ commandRunner, adbPath, device, wait, account });
      if (!restored) fail('The private synthetic Staging session could not be restored after the app-link diagnostic.');
    }
  }

  return {
    schemaVersion: 1,
    kind: 'android-direct-app-link-diagnostic',
    status: 'passed-bounded-app-link-diagnostic',
    capturedAt,
    candidate: {
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
    },
    installed: {
      packageIdentityVerified: true,
      versionName: installed.versionName,
      buildNumber: installed.buildNumber,
      apkSha256: installed.apkSha256,
    },
    device: deviceSummary,
    tests: {
      verifiedHttpsMissingListing: { status: 'passed', result: 'safe-listing-unavailable-surface' },
      customSchemeGuestChat: { status: 'passed', result: 'authentication-required-surface' },
      unsafeIdentifierRejected: { status: 'passed', result: 'guest-start-preserved' },
      foreignHostNotAssociated: { status: 'passed', result: 'shareittoo-package-absent' },
    },
    boundaries: {
      directDiagnosticOnly: true,
      storeInstallationGateSatisfied: false,
      manualFunctionalMatrixPassed: false,
      authenticatedDeepLinksPassed: false,
      realPushPassed: false,
      lockCodeUsed: false,
      containsSecrets: false,
      containsRawDeviceIdentifiers: false,
      containsReviewCredentials: false,
      syntheticAccountsOnly: true,
    },
  };
}

function parseArguments(values) {
  let candidateDirectory = null;
  let vaultFile = null;
  let adbPath = 'adb';
  for (let index = 0; index < values.length; index += 1) {
    if (values[index] === '--candidate-dir') {
      candidateDirectory = values[index + 1] ?? fail('--candidate-dir requires a path.');
      index += 1;
    } else if (values[index] === '--adb') {
      adbPath = values[index + 1] ?? fail('--adb requires a path.');
      index += 1;
    } else if (values[index] === '--vault-file') {
      vaultFile = values[index + 1] ?? fail('--vault-file requires a path.');
      index += 1;
    } else {
      fail(`Unknown argument: ${values[index]}`);
    }
  }
  return { candidateDirectory, vaultFile, adbPath };
}

async function run() {
  const root = fileURLToPath(new URL('../', import.meta.url));
  const args = parseArguments(process.argv.slice(2));
  const manifest = JSON.parse(readFileSync(resolve(root, 'store/device-validation.json'), 'utf8'));
  const candidate = manifest.candidate;
  const candidateDirectory = resolve(
    args.candidateDirectory ??
      resolve(
        homedir(),
        'Library',
        'Application Support',
        'ShareItToo',
        'release',
        'android',
        `${nonEmptyString(candidate.buildNumber, 'candidate.buildNumber')}-${nonEmptyString(candidate.commit, 'candidate.commit')}`,
      ),
  );
  const archive = await validateCandidateArchive({ root, candidateDirectory });
  const devices = parseAdbDevices(defaultCommandRunner(args.adbPath, ['devices', '-l']));
  const device = selectSinglePhysicalDevice(devices);
  const deviceSummary = inspectPhysicalDevice({ adbPath: args.adbPath, device });
  const evidence = await diagnoseAndroidAppLinks({
    vaultFile: args.vaultFile === null ? null : resolve(args.vaultFile),
    adbPath: args.adbPath,
    device,
    deviceSummary,
    candidate,
    archive,
  });
  console.log(JSON.stringify(evidence, null, 2));
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    await run();
  } catch (error) {
    console.error(`ERROR: ${error.message}`);
    process.exitCode = 1;
  }
}
