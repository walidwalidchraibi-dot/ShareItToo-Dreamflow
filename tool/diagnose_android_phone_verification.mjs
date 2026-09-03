#!/usr/bin/env node

import { createHash } from 'node:crypto';
import {
  chmodSync,
  mkdirSync,
  readFileSync,
  realpathSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { homedir } from 'node:os';
import { isAbsolute, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import {
  ensureAndroidGuestSession,
  restoreSyntheticSession,
} from './diagnose_android_logout_lifecycle.mjs';
import {
  assertCurrentHeadAndroidDeviceAlreadyUnlocked,
  currentHeadAndroidAdb,
  currentHeadAndroidNamedNodes,
  currentHeadAndroidNodeAttribute,
  defaultCurrentHeadAndroidCommandRunner,
  dumpCurrentHeadAndroidUi,
  launchCurrentHeadAndroidCandidate,
  verifyCurrentHeadAndroidInstalledCandidate,
  waitForCurrentHeadAndroidMainNavigation,
} from './diagnose_current_head_android_main_navigation.mjs';
import {
  inspectPhysicalDevice,
  parseAdbDevices,
  selectSinglePhysicalDevice,
} from './prepare_android_device_test.mjs';
import {
  readEmailVerifiedJourneyVault,
} from './run_staging_email_verified_two_role_journey.mjs';
import {
  validateCurrentHeadAndroidReleaseArchive,
} from './validate_current_head_android_release_archive.mjs';

const repositoryRoot = realpathSync(resolve(fileURLToPath(new URL('..', import.meta.url))));
const applicationId = 'com.shareittoo.app';
const apiBaseUrl = 'https://staging.shareittoo.com/api/v1';

function fail(message) {
  throw new Error(message);
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function outsideRepository(path, label) {
  const absolute = resolve(path);
  if (absolute === repositoryRoot || absolute.startsWith(`${repositoryRoot}${sep}`)) {
    fail(`${label} must remain outside the repository.`);
  }
  return absolute;
}

function ownerOnlyFile(path, label) {
  if (typeof path !== 'string' || !isAbsolute(path)) fail(`${label} must be absolute.`);
  const canonical = realpathSync(path);
  outsideRepository(canonical, label);
  const stat = statSync(canonical);
  if (!stat.isFile() || stat.size === 0 || (stat.mode & 0o077) !== 0) {
    fail(`${label} must be a non-empty owner-only file.`);
  }
  return canonical;
}

export function normalizePrivatePhoneInput(value) {
  const normalized = String(value)
    .trim()
    .replace(/[\s().-]/gu, '')
    .replace(/^00/u, '+');
  if (!/^\+49[1-9][0-9]{6,12}$/u.test(normalized)) {
    fail('The private phone input is not one valid German E.164 number.');
  }
  return normalized;
}

function readPrivatePhone(path) {
  return normalizePrivatePhoneInput(
    readFileSync(ownerOnlyFile(path, 'Private phone input'), 'utf8'),
  );
}

export function sanitizePhoneVerificationFailure(error) {
  const message = typeof error?.message === 'string' ? error.message.trim() : '';
  if (message.length === 0
      || message.length > 240
      || /(?:@|https?:\/\/|\/Users\/|\+49|sms.?code|password|passcode|secret|token|credential|private.?key|api.?key|otp|pin|serial)/iu.test(message)
      || !/^[A-Za-z0-9_ .,:;()[\]'/-]+$/u.test(message)) {
    return 'safe diagnostic reason unavailable';
  }
  return message;
}

function pointForNode(node, label) {
  const bounds = /\[(\d+),(\d+)\]\[(\d+),(\d+)\]/u.exec(
    currentHeadAndroidNodeAttribute(node, 'bounds') ?? '',
  );
  if (bounds === null) fail(`The sanitized ${label} action has invalid bounds.`);
  return {
    x: Math.floor((Number(bounds[1]) + Number(bounds[3])) / 2),
    y: Math.floor((Number(bounds[2]) + Number(bounds[4])) / 2),
  };
}

function tapNamedNode(commandRunner, adbPath, device, hierarchy, label, { chooseLast = false } = {}) {
  const nodes = currentHeadAndroidNamedNodes(hierarchy, label)
    .filter((node) => currentHeadAndroidNodeAttribute(node, 'enabled') !== 'false');
  if (nodes.length === 0) fail(`The sanitized ${label} action is unavailable.`);
  const point = pointForNode(chooseLast ? nodes.at(-1) : nodes[0], label);
  currentHeadAndroidAdb(commandRunner, adbPath, device, [
    'shell', 'input', 'tap', String(point.x), String(point.y),
  ]);
}

async function waitForHierarchy({
  commandRunner,
  adbPath,
  device,
  wait,
  predicate,
  attempts = 32,
  label,
}) {
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    await wait(500);
    const hierarchy = dumpCurrentHeadAndroidUi(commandRunner, adbPath, device);
    if (predicate(hierarchy)) return hierarchy;
  }
  fail(`The sanitized ${label} surface did not appear.`);
}

async function findOrScroll({ commandRunner, adbPath, device, wait, label }) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const hierarchy = dumpCurrentHeadAndroidUi(commandRunner, adbPath, device);
    if (currentHeadAndroidNamedNodes(hierarchy, label).length > 0) return hierarchy;
    currentHeadAndroidAdb(commandRunner, adbPath, device, [
      'shell', 'input', 'swipe', '540', '1650', '540', '450', '350',
    ]);
    await wait(350);
  }
  fail(`The sanitized ${label} action is unavailable after bounded scrolling.`);
}

function replaceInput(commandRunner, adbPath, device, hierarchy, label, value, deleteCount) {
  if (!/^[+0-9]{1,16}$/u.test(value)) fail(`The private ${label} input is invalid.`);
  tapNamedNode(commandRunner, adbPath, device, hierarchy, label);
  currentHeadAndroidAdb(commandRunner, adbPath, device, ['shell', 'input', 'keyevent', '123']);
  for (let index = 0; index < deleteCount; index += 1) {
    currentHeadAndroidAdb(commandRunner, adbPath, device, ['shell', 'input', 'keyevent', '67']);
  }
  currentHeadAndroidAdb(commandRunner, adbPath, device, [
    'shell', 'input', 'text', value,
  ]);
}

async function stagingPhoneStatus(fetchImpl, account) {
  const login = await fetchImpl(`${apiBaseUrl}/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: account.email, password: account.password }),
    signal: AbortSignal.timeout(20_000),
  });
  const loginValue = await login.json();
  if (login.status !== 200 || typeof loginValue?.accessToken !== 'string') {
    fail('The protected Staging owner login is unavailable.');
  }
  const status = await fetchImpl(`${apiBaseUrl}/auth/phone-verification/status`, {
    headers: { authorization: `Bearer ${loginValue.accessToken}` },
    signal: AbortSignal.timeout(20_000),
  });
  const statusValue = await status.json();
  if (status.status !== 200
      || statusValue?.available !== true
      || statusValue?.provider !== 'firebase-phone') {
    fail('The Staging phone-verification provider is unavailable.');
  }
  return true;
}

async function openContactInformation({ commandRunner, adbPath, device, wait }) {
  launchCurrentHeadAndroidCandidate(commandRunner, adbPath, device);
  const main = await waitForCurrentHeadAndroidMainNavigation({
    commandRunner,
    adbPath,
    device,
    wait,
  });
  tapNamedNode(commandRunner, adbPath, device, main, 'Mein SIT', { chooseLast: true });
  let hierarchy = await waitForHierarchy({
    commandRunner,
    adbPath,
    device,
    wait,
    label: 'authenticated profile',
    predicate: (value) => currentHeadAndroidNamedNodes(value, 'Abmelden').length > 0,
  });
  hierarchy = await findOrScroll({
    commandRunner,
    adbPath,
    device,
    wait,
    label: 'Kontoeinstellungen',
  });
  tapNamedNode(commandRunner, adbPath, device, hierarchy, 'Kontoeinstellungen');
  hierarchy = await waitForHierarchy({
    commandRunner,
    adbPath,
    device,
    wait,
    label: 'account settings',
    predicate: (value) => currentHeadAndroidNamedNodes(value, 'Kontaktinformationen').length > 0,
  });
  tapNamedNode(commandRunner, adbPath, device, hierarchy, 'Kontaktinformationen');
  return waitForHierarchy({
    commandRunner,
    adbPath,
    device,
    wait,
    label: 'contact information',
    predicate: (value) => currentHeadAndroidNamedNodes(value, 'Telefonnummer verifizieren').length > 0
      || (value.includes('Telefonnummer') && value.includes('Verifiziert')),
  });
}

function writePrivateState(directory, state) {
  const absolute = outsideRepository(directory, 'Private phone evidence directory');
  mkdirSync(absolute, { recursive: true, mode: 0o700 });
  chmodSync(absolute, 0o700);
  const path = resolve(absolute, 'state.json');
  writeFileSync(path, `${JSON.stringify(state, null, 2)}\n`, { mode: 0o600 });
  chmodSync(path, 0o600);
  return sha256(JSON.stringify(state));
}

export async function diagnoseAndroidPhoneVerification({
  phase,
  protectedOwnerVaultFile,
  phoneFile,
  privateEvidenceDirectory,
  commandRunner = defaultCurrentHeadAndroidCommandRunner,
  adbPath = 'adb',
  device,
  deviceSummary,
  candidate,
  fetchImpl = globalThis.fetch,
  capturedAt = new Date().toISOString(),
  wait = (milliseconds) => new Promise((resolvePromise) => setTimeout(resolvePromise, milliseconds)),
}) {
  if (!['request', 'observe'].includes(phase)) fail('N24 phase must be request or observe.');
  assertCurrentHeadAndroidDeviceAlreadyUnlocked(commandRunner, adbPath, device);
  const installed = verifyCurrentHeadAndroidInstalledCandidate(
    commandRunner,
    adbPath,
    device,
    candidate,
  );
  const { vault } = readEmailVerifiedJourneyVault(protectedOwnerVaultFile);
  const owner = vault.accounts.find((entry) => entry.role === 'owner');
  if (!owner) fail('The protected synthetic owner role is unavailable.');
  const phoneNumber = readPrivatePhone(phoneFile);
  await stagingPhoneStatus(fetchImpl, owner);

  await ensureAndroidGuestSession({ commandRunner, adbPath, device, wait });
  const restored = await restoreSyntheticSession({
    commandRunner,
    adbPath,
    device,
    wait,
    account: owner,
  });
  if (!restored) fail('The protected synthetic owner session could not be restored.');
  let hierarchy = await openContactInformation({ commandRunner, adbPath, device, wait });
  let status;
  let invalidCodeRejected = false;

  if (phase === 'request') {
    if (hierarchy.includes('Verifiziert')
        && currentHeadAndroidNamedNodes(hierarchy, 'Telefonnummer verifizieren').length === 0) {
      status = 'already-verified-current-candidate';
    } else {
      replaceInput(
        commandRunner,
        adbPath,
        device,
        hierarchy,
        'Telefonnummer',
        phoneNumber,
        24,
      );
      hierarchy = await findOrScroll({
        commandRunner,
        adbPath,
        device,
        wait,
        label: 'Telefonnummer verifizieren',
      });
      tapNamedNode(commandRunner, adbPath, device, hierarchy, 'Telefonnummer verifizieren');
      hierarchy = await waitForHierarchy({
        commandRunner,
        adbPath,
        device,
        wait,
        label: 'SMS consent',
        predicate: (value) => value.includes('SMS-Code anfordern?')
          && currentHeadAndroidNamedNodes(value, 'Code senden').length > 0,
      });
      tapNamedNode(commandRunner, adbPath, device, hierarchy, 'Code senden');
      hierarchy = await waitForHierarchy({
        commandRunner,
        adbPath,
        device,
        wait,
        attempts: 150,
        label: 'phone verification result',
        predicate: (value) => value.includes('Telefonnummer verifiziert')
          || currentHeadAndroidNamedNodes(value, 'SMS-Code').length > 0
          || value.includes('Telefonprüfung nicht')
          || value.includes('Ergebnisstatus unklar'),
      });
      if (hierarchy.includes('Telefonnummer verifiziert')) {
        status = 'automatically-verified-current-candidate';
      } else if (currentHeadAndroidNamedNodes(hierarchy, 'SMS-Code').length > 0) {
        replaceInput(
          commandRunner,
          adbPath,
          device,
          hierarchy,
          'SMS-Code',
          '000000',
          8,
        );
        hierarchy = dumpCurrentHeadAndroidUi(commandRunner, adbPath, device);
        tapNamedNode(commandRunner, adbPath, device, hierarchy, 'Bestätigen');
        hierarchy = await waitForHierarchy({
          commandRunner,
          adbPath,
          device,
          wait,
          attempts: 60,
          label: 'invalid SMS rejection',
          predicate: (value) => value.includes('SMS-Code prüfen'),
        });
        invalidCodeRejected = true;
        status = 'awaiting-owner-sms-code';
      } else {
        fail('The current candidate did not reach a safe phone-verification state.');
      }
    }
  } else {
    const successVisible = hierarchy.includes('Telefonnummer verifiziert')
      || (hierarchy.includes('Telefonnummer')
        && hierarchy.includes('Verifiziert')
        && currentHeadAndroidNamedNodes(hierarchy, 'Telefonnummer verifizieren').length === 0);
    if (!successVisible) fail('Current-candidate phone verification is not yet confirmed.');
    currentHeadAndroidAdb(commandRunner, adbPath, device, [
      'shell', 'am', 'force-stop', applicationId,
    ]);
    const coldHierarchy = await openContactInformation({ commandRunner, adbPath, device, wait });
    if (!coldHierarchy.includes('Verifiziert')
        || currentHeadAndroidNamedNodes(coldHierarchy, 'Telefonnummer verifizieren').length > 0) {
      fail('Verified phone state did not persist across a cold restart.');
    }
    status = 'passed-valid-code-and-cold-restart';
  }

  const stateSha256 = writePrivateState(privateEvidenceDirectory, {
    schemaVersion: 1,
    kind: 'n24-private-phone-verification-state',
    status,
    capturedAt,
    candidateCommit: candidate.commit,
    candidateBuildNumber: candidate.buildNumber,
    phoneSha256: sha256(phoneNumber),
    invalidCodeRejected,
    containsPhoneNumber: false,
    containsSmsCode: false,
  });

  return {
    schemaVersion: 1,
    kind: 'android-current-candidate-phone-verification-diagnostic',
    status,
    capturedAt,
    candidate: {
      applicationId: candidate.applicationId,
      versionName: candidate.versionName,
      buildNumber: candidate.buildNumber,
      commit: candidate.commit,
      apkSha256: candidate.apkSha256,
      signingCertificateSha256: candidate.signingCertificateSha256,
      apiBaseUrl: candidate.apiBaseUrl,
    },
    installed: {
      physicalDevice: true,
      exactCandidateHashMatched: true,
      versionName: installed.versionName,
      buildNumber: installed.buildNumber,
      delivery: installed.delivery,
    },
    device: deviceSummary,
    results: {
      stagingProviderAvailable: true,
      provider: 'firebase-phone',
      germanyOnlyInput: true,
      smsConsentPresented: phase === 'request',
      invalidCodeRejected,
      validCodeAccepted: status === 'passed-valid-code-and-cold-restart'
        || status === 'automatically-verified-current-candidate'
        || status === 'already-verified-current-candidate',
      verifiedStatePersistedAfterColdRestart: status === 'passed-valid-code-and-cold-restart',
      ownerActionRequired: status === 'awaiting-owner-sms-code',
      privateStateSha256: stateSha256,
      protectedSyntheticOwnerRetained: true,
    },
    boundaries: {
      stagingOnly: true,
      productionChanged: false,
      googlePlayChanged: false,
      firebaseConfigurationChanged: false,
      paymentCalled: false,
      realMoneyUsed: false,
      kycCalled: false,
      containsPhoneNumber: false,
      containsSmsCode: false,
      containsCredential: false,
      containsToken: false,
      containsRawDeviceIdentifiers: false,
      containsPrivateFilesystemPaths: false,
    },
  };
}

function requiredEnvironment(name) {
  const value = process.env[name]?.trim();
  if (!value) fail(`${name} is required.`);
  return value;
}

async function run() {
  const phase = process.env.SIT_N24_PHASE?.trim() || 'request';
  const protectedOwnerVaultFile = requiredEnvironment('SIT_N24_PROTECTED_OWNER_VAULT_FILE');
  const phoneFile = requiredEnvironment('SIT_N24_PHONE_FILE');
  const privateEvidenceDirectory = process.env.SIT_N24_PRIVATE_EVIDENCE_DIR?.trim()
    || resolve(homedir(), 'Library', 'Application Support', 'ShareItToo', 'qa', 'n24-phone-verification');
  const candidate = await validateCurrentHeadAndroidReleaseArchive();
  const devices = parseAdbDevices(
    defaultCurrentHeadAndroidCommandRunner('adb', ['devices', '-l']),
  );
  const device = selectSinglePhysicalDevice(devices);
  const deviceSummary = inspectPhysicalDevice({ adbPath: 'adb', device });
  try {
    const result = await diagnoseAndroidPhoneVerification({
      phase,
      protectedOwnerVaultFile,
      phoneFile,
      privateEvidenceDirectory,
      candidate,
      device,
      deviceSummary,
    });
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } catch (error) {
    process.stderr.write(`ERROR: ${sanitizePhoneVerificationFailure(error)}\n`);
    process.exitCode = 1;
  }
}

if (process.argv[1]
    && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  await run();
}
