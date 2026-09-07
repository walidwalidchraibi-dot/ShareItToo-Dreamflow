#!/usr/bin/env node

import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

import {
  inspectPhysicalDevice,
  parseAdbDevices,
  selectSinglePhysicalDevice,
} from './prepare_android_device_test.mjs';
import {
  assertCurrentHeadAndroidDeviceAlreadyUnlocked,
  currentHeadAndroidAdb,
  currentHeadAndroidNamedNodes,
  currentHeadAndroidNodeAttribute,
  defaultCurrentHeadAndroidCommandRunner,
  dumpCurrentHeadAndroidUi,
  launchCurrentHeadAndroidCandidate,
  restoreCurrentHeadAndroidExplore,
  verifyCurrentHeadAndroidInstalledCandidate,
  waitForCurrentHeadAndroidMainNavigation,
} from './diagnose_current_head_android_main_navigation.mjs';
import {
  loadCurrentHeadAndroidDeviceCandidate,
} from './validate_current_head_android_candidate.mjs';

const legalChecks = Object.freeze([
  Object.freeze({ label: 'Impressum', marker: 'Anbieter' }),
  Object.freeze({ label: 'Datenschutz', marker: 'Welche Daten Nutzer angeben' }),
  Object.freeze({ label: 'AGB', marker: 'Geltungsbereich und Dokumentenstand' }),
  Object.freeze({ label: 'Community‑Regeln', marker: 'Erlaubte Inhalte' }),
  Object.freeze({ label: 'Gebühren & Zahlungsbedingungen', marker: 'Plattformgebühr' }),
  Object.freeze({ label: 'Stornierungsbedingungen', marker: 'Wann kann storniert werden?' }),
  Object.freeze({ label: 'Haftungsausschluss', marker: 'Rolle der Plattform' }),
]);

function fail(message) {
  throw new Error(message);
}

function centerOfNode(node, label) {
  const bounds = /^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/u.exec(
    currentHeadAndroidNodeAttribute(node, 'bounds') ?? '',
  );
  if (bounds === null) fail(`The sanitized ${label} action has invalid bounds.`);
  const [, x1, y1, x2, y2] = bounds.map(Number);
  return {
    x: Math.floor((x1 + x2) / 2),
    y: Math.floor((y1 + y2) / 2),
  };
}

function tapSingleNamedNode(commandRunner, adbPath, device, hierarchy, label) {
  const enabled = currentHeadAndroidNamedNodes(hierarchy, label)
    .filter((node) => currentHeadAndroidNodeAttribute(node, 'enabled') !== 'false');
  const clickable = enabled
    .filter((node) => currentHeadAndroidNodeAttribute(node, 'clickable') === 'true');
  const candidates = clickable.length > 0 ? clickable : enabled;
  if (candidates.length !== 1) {
    fail(`The sanitized ${label} action is missing or ambiguous.`);
  }
  const center = centerOfNode(candidates[0], label);
  currentHeadAndroidAdb(commandRunner, adbPath, device, [
    'shell',
    'input',
    'tap',
    String(center.x),
    String(center.y),
  ]);
}

async function waitForNamedSurface({
  commandRunner,
  adbPath,
  device,
  labels,
  failure,
  wait,
}) {
  for (let attempt = 0; attempt < 12; attempt += 1) {
    await wait(600);
    const hierarchy = dumpCurrentHeadAndroidUi(commandRunner, adbPath, device);
    const complete = labels.every((label) => (
      currentHeadAndroidNamedNodes(hierarchy, label).length >= 1
    ));
    if (complete
        && currentHeadAndroidNamedNodes(hierarchy, 'Bitte zuerst anmelden').length === 0) {
      return hierarchy;
    }
  }
  fail(failure);
}

async function openAuthenticatedLegalRoot({ commandRunner, adbPath, device, wait }) {
  launchCurrentHeadAndroidCandidate(commandRunner, adbPath, device);
  const main = await waitForCurrentHeadAndroidMainNavigation({
    commandRunner,
    adbPath,
    device,
    wait,
  });
  tapSingleNamedNode(commandRunner, adbPath, device, main, 'Mein SIT');
  const profile = await waitForNamedSurface({
    commandRunner,
    adbPath,
    device,
    labels: ['Meine Anzeigen', 'Mietanfragen', 'Abmelden', 'Suchen'],
    failure: 'The authenticated profile surface did not appear.',
    wait,
  });
  tapSingleNamedNode(commandRunner, adbPath, device, profile, 'Suchen');
  const search = await waitForNamedSurface({
    commandRunner,
    adbPath,
    device,
    labels: ['Suche schließen'],
    failure: 'The profile search surface did not appear.',
    wait,
  });
  if (currentHeadAndroidNamedNodes(search, 'Suchen').length >= 1) {
    fail('The profile search did not enter its focused open state.');
  }
  currentHeadAndroidAdb(
    commandRunner,
    adbPath,
    device,
    ['shell', 'input', 'text', 'Rechtliches'],
  );
  currentHeadAndroidAdb(
    commandRunner,
    adbPath,
    device,
    ['shell', 'input', 'keyevent', '66'],
  );
  return waitForNamedSurface({
    commandRunner,
    adbPath,
    device,
    labels: ['Rechtliches', 'Impressum', 'Datenschutz', 'AGB'],
    failure: 'The read-only legal root did not appear.',
    wait,
  });
}

async function findAndOpenLegalDocument({
  commandRunner,
  adbPath,
  device,
  check,
  wait,
}) {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const hierarchy = dumpCurrentHeadAndroidUi(commandRunner, adbPath, device);
    if (currentHeadAndroidNamedNodes(hierarchy, check.label).length >= 1) {
      tapSingleNamedNode(commandRunner, adbPath, device, hierarchy, check.label);
      await waitForNamedSurface({
        commandRunner,
        adbPath,
        device,
        labels: [check.label, check.marker],
        failure: `The read-only ${check.label} document did not appear.`,
        wait,
      });
      currentHeadAndroidAdb(
        commandRunner,
        adbPath,
        device,
        ['shell', 'input', 'keyevent', '4'],
      );
      await waitForNamedSurface({
        commandRunner,
        adbPath,
        device,
        labels: ['Rechtliches'],
        failure: 'The legal root did not return after a read-only document.',
        wait,
      });
      return;
    }
    currentHeadAndroidAdb(commandRunner, adbPath, device, [
      'shell',
      'input',
      'swipe',
      '500',
      '1800',
      '500',
      '700',
      '300',
    ]);
    await wait(350);
  }
  fail(`The read-only ${check.label} legal entry is unavailable.`);
}

export async function diagnoseCurrentHeadAndroidLegalRoutes({
  commandRunner = defaultCurrentHeadAndroidCommandRunner,
  adbPath = 'adb',
  device,
  deviceSummary,
  candidate,
  capturedAt = new Date().toISOString(),
  wait = (milliseconds) => new Promise((resolvePromise) => setTimeout(resolvePromise, milliseconds)),
}) {
  assertCurrentHeadAndroidDeviceAlreadyUnlocked(commandRunner, adbPath, device);
  const installed = verifyCurrentHeadAndroidInstalledCandidate(
    commandRunner,
    adbPath,
    device,
    candidate,
  );
  try {
    await openAuthenticatedLegalRoot({ commandRunner, adbPath, device, wait });
    for (const check of legalChecks) {
      await findAndOpenLegalDocument({ commandRunner, adbPath, device, check, wait });
    }
    currentHeadAndroidAdb(
      commandRunner,
      adbPath,
      device,
      ['shell', 'input', 'keyevent', '4'],
    );
  } finally {
    restoreCurrentHeadAndroidExplore(commandRunner, adbPath, device);
  }
  return {
    schemaVersion: 1,
    kind: 'android-current-head-authenticated-legal-route-diagnostic',
    status: 'passed-bounded-authenticated-legal-route-diagnostic',
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
      delivery: installed.delivery,
      apkSha256: installed.apkSha256,
    },
    device: deviceSummary,
    tests: Object.fromEntries(legalChecks.map((check) => [
      check.label,
      { status: 'passed', result: 'read-only-document-reachable' },
    ])),
    boundaries: {
      directDiagnosticOnly: true,
      storeInstallationGateSatisfied: false,
      authenticatedLegalRoutesPassed: true,
      professionalLegalApprovalPassed: false,
      platformWithdrawalOpened: false,
      platformWithdrawalSubmitted: false,
      supportSubmitted: false,
      contactActionPerformed: false,
      accountMutationPerformed: false,
      loginPerformed: false,
      logoutPerformed: false,
      accountIdentityRecorded: false,
      lockCodeUsed: false,
      containsLegalContactValues: false,
      containsPersonalAccountData: false,
      containsSecrets: false,
      containsRawDeviceIdentifiers: false,
      containsReviewCredentials: false,
    },
  };
}

export function parseLegalRouteArguments(values) {
  let currentHead = false;
  let adbPath = 'adb';
  for (let index = 0; index < values.length; index += 1) {
    if (values[index] === '--current-head') {
      currentHead = true;
    } else if (values[index] === '--adb') {
      adbPath = values[index + 1] ?? fail('--adb requires a path.');
      index += 1;
    } else {
      fail(`Unknown argument: ${values[index]}`);
    }
  }
  if (!currentHead) fail('The legal-route diagnostic requires --current-head.');
  return { currentHead, adbPath };
}

async function run() {
  const args = parseLegalRouteArguments(process.argv.slice(2));
  const candidate = await loadCurrentHeadAndroidDeviceCandidate();
  const devices = parseAdbDevices(
    defaultCurrentHeadAndroidCommandRunner(args.adbPath, ['devices', '-l']),
  );
  const device = selectSinglePhysicalDevice(devices);
  const deviceSummary = inspectPhysicalDevice({ adbPath: args.adbPath, device });
  const evidence = await diagnoseCurrentHeadAndroidLegalRoutes({
    adbPath: args.adbPath,
    device,
    deviceSummary,
    candidate,
  });
  process.stdout.write(`${JSON.stringify(evidence, null, 2)}\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    await run();
  } catch (error) {
    process.stderr.write(
      `${error?.message ?? 'Current-head Android legal-route diagnostic failed.'}\n`,
    );
    process.exitCode = 1;
  }
}
