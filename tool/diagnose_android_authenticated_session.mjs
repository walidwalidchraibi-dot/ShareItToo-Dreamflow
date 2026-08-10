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

const applicationId = 'com.shareittoo.app';
const remoteUiDump = '/sdcard/sit-authenticated-session-diagnostic.xml';

function fail(message) {
  throw new Error(message);
}

function nonEmptyString(value, label) {
  if (typeof value !== 'string' || value.trim() === '') fail(`${label} must be a non-empty string.`);
  return value.trim();
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
    fail('ADB authenticated-session command failed without exposing the device identifier.');
  }
}

function sha256Bytes(value) {
  return createHash('sha256').update(value).digest('hex');
}

function parseInstalledPackage(output) {
  const versionName = /^\s*versionName=([^\s]+)\s*$/m.exec(output)?.[1] ?? null;
  const buildNumber = /^\s*versionCode=(\d+)\b/m.exec(output)?.[1] ?? null;
  if (versionName === null || buildNumber === null) fail('Installed ShareItToo version could not be verified.');
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
  const installedSha256 = sha256Bytes(adb(
    commandRunner,
    adbPath,
    device,
    ['exec-out', 'cat', packagePaths[0]],
    { binary: true },
  ));
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

function dumpUi(commandRunner, adbPath, device) {
  adb(commandRunner, adbPath, device, ['shell', 'uiautomator', 'dump', remoteUiDump]);
  try {
    return adb(commandRunner, adbPath, device, ['exec-out', 'cat', remoteUiDump]);
  } finally {
    try {
      adb(commandRunner, adbPath, device, ['shell', 'rm', '-f', remoteUiDump]);
    } catch {
      // Never mask the diagnostic result. The fixed remote file is overwritten
      // and its raw UI content is never copied into evidence or console output.
    }
  }
}

function xmlValue(value) {
  return String(value)
    .replace(/&#(\d+);/g, (_match, decimal) => String.fromCodePoint(Number(decimal)))
    .replace(/&#x([0-9a-f]+);/gi, (_match, hexadecimal) => String.fromCodePoint(Number.parseInt(hexadecimal, 16)))
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');
}

function attribute(tag, name) {
  const value = new RegExp(`(?:^|\\s)${name}="([^"]*)"`).exec(tag)?.[1];
  return value === undefined ? null : xmlValue(value);
}

function namedNodes(hierarchy, label) {
  const matchesLabel = (value) => value?.split('\n').some((line) => line === label
    || line.startsWith(`${label},`)
    || line.startsWith(`${label} `)) === true;
  return (String(hierarchy).match(/<node[^>]*>/g) ?? []).filter((tag) => (
    matchesLabel(attribute(tag, 'text')) || matchesLabel(attribute(tag, 'content-desc'))
  ));
}

function nodeCenter(tag, label) {
  const bounds = /^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/.exec(attribute(tag, 'bounds') ?? '');
  if (!bounds) fail(`The sanitized ${label} action has invalid bounds.`);
  const values = bounds.slice(1).map(Number);
  return {
    x: Math.round((values[0] + values[2]) / 2),
    y: Math.round((values[1] + values[3]) / 2),
  };
}

async function waitForHierarchy({ commandRunner, adbPath, device, predicate, wait }) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    await wait(750);
    const hierarchy = dumpUi(commandRunner, adbPath, device);
    if (predicate(hierarchy)) return hierarchy;
  }
  fail('The expected sanitized authenticated ShareItToo surface did not appear.');
}

function hasMainNavigation(hierarchy) {
  return ['Erkunden', 'Nachrichten', 'Profil'].every((label) => namedNodes(hierarchy, label).length >= 1);
}

function hasAuthenticatedProfile(hierarchy) {
  return ['Meine Anzeigen', 'Mietanfragen', 'Abmelden'].every((label) => namedNodes(hierarchy, label).length >= 1)
    && namedNodes(hierarchy, 'Anmelden').length === 0
    && namedNodes(hierarchy, 'Konto erstellen').length === 0;
}

function tapSingleNamedNode(commandRunner, adbPath, device, hierarchy, label) {
  const enabled = namedNodes(hierarchy, label).filter((tag) => attribute(tag, 'enabled') !== 'false');
  const clickable = enabled.filter((tag) => attribute(tag, 'clickable') === 'true');
  const matches = clickable.length ? clickable : enabled;
  if (matches.length !== 1) fail(`The sanitized ${label} action is missing or ambiguous.`);
  const center = nodeCenter(matches[0], label);
  adb(commandRunner, adbPath, device, ['shell', 'input', 'tap', String(center.x), String(center.y)]);
}

function launchCandidate(commandRunner, adbPath, device) {
  adb(commandRunner, adbPath, device, ['shell', 'am', 'force-stop', applicationId]);
  const result = adb(commandRunner, adbPath, device, [
    'shell',
    'monkey',
    '-p',
    applicationId,
    '-c',
    'android.intent.category.LAUNCHER',
    '1',
  ]);
  if (!/Events injected:\s*1/.test(result)) fail('Android did not confirm the ShareItToo launch event.');
}

async function verifyAuthenticatedProfileCycle({ commandRunner, adbPath, device, wait }) {
  launchCandidate(commandRunner, adbPath, device);
  const main = await waitForHierarchy({
    commandRunner,
    adbPath,
    device,
    predicate: hasMainNavigation,
    wait,
  });
  tapSingleNamedNode(commandRunner, adbPath, device, main, 'Profil');
  await waitForHierarchy({
    commandRunner,
    adbPath,
    device,
    predicate: hasAuthenticatedProfile,
    wait,
  });
}

function restoreExplore(commandRunner, adbPath, device) {
  try {
    const hierarchy = dumpUi(commandRunner, adbPath, device);
    tapSingleNamedNode(commandRunner, adbPath, device, hierarchy, 'Erkunden');
  } catch {
    // The verification is already complete. A final convenience navigation
    // failure must not turn a passed session diagnostic into a false failure.
  }
}

export async function diagnoseAndroidAuthenticatedSession({
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
  await verifyAuthenticatedProfileCycle({ commandRunner, adbPath, device, wait });
  await verifyAuthenticatedProfileCycle({ commandRunner, adbPath, device, wait });
  restoreExplore(commandRunner, adbPath, device);

  return {
    schemaVersion: 1,
    kind: 'android-authenticated-session-diagnostic',
    status: 'passed-bounded-authenticated-session-diagnostic',
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
      authenticatedProfileAccess: { status: 'passed', result: 'authenticated-actions-present' },
      coldStartSessionRestore: { status: 'passed', result: 'authenticated-profile-restored-after-force-stop' },
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
  };
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
  return { candidateDirectory, adbPath };
}

async function run() {
  const root = fileURLToPath(new URL('../', import.meta.url));
  const args = parseArguments(process.argv.slice(2));
  const manifest = JSON.parse(readFileSync(resolve(root, 'store/device-validation.json'), 'utf8'));
  const candidate = manifest.candidate;
  const candidateDirectory = resolve(
    args.candidateDirectory
      ?? resolve(
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
  const evidence = await diagnoseAndroidAuthenticatedSession({
    adbPath: args.adbPath,
    device,
    deviceSummary,
    candidate,
    archive,
  });
  console.log(JSON.stringify(evidence, null, 2));
}

if (typeof process !== 'undefined'
    && process.argv?.[1]
    && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    await run();
  } catch (error) {
    console.error(`ERROR: ${error.message}`);
    process.exitCode = 1;
  }
}
