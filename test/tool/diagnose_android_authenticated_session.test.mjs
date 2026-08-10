import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import test from 'node:test';

import { diagnoseAndroidAuthenticatedSession } from '../../tool/diagnose_android_authenticated_session.mjs';

const apkBytes = Buffer.from('verified authenticated candidate bytes');
const apkSha256 = createHash('sha256').update(apkBytes).digest('hex');
const device = { serial: 'private-device-id', state: 'device', attributes: {} };
const deviceSummary = {
  platform: 'android',
  physical: true,
  manufacturer: 'Google',
  model: 'Pixel 7 Pro',
  osVersion: '16',
  apiLevel: 36,
  securityPatch: '2026-04-05',
  containsRawDeviceIdentifier: false,
};
const candidate = {
  applicationId: 'com.shareittoo.app',
  bundleId: 'com.shareittoo.app',
  versionName: '1.0.0',
  buildNumber: '2026081018',
  commit: '555946e64e583e5b6ee3321de2c1f74f35fbf238',
  releaseChannel: 'internal',
  apiBaseUrl: 'https://staging.shareittoo.com/api/v1',
  firebaseConfigured: true,
  paymentMode: 'memory',
  stripeLivemode: false,
  android: { apkSha256 },
};
const archive = { apkSha256 };

function node(label, bounds, extra = '') {
  return `<node text="" content-desc="${label}" enabled="true" clickable="true" bounds="${bounds}" ${extra}/>`;
}

const mainHierarchy = `<hierarchy>${node('Erkunden&#10;Tab 1 of 5', '[0,100][200,200]')}${node('Nachrichten&#10;Tab 4 of 5', '[400,100][600,200]')}${node('Profil&#10;Tab 5 of 5', '[800,100][1000,200]')}</hierarchy>`;
const authenticatedHierarchy = `<hierarchy>${node('Meine Anzeigen', '[10,10][300,80]')}${node('Offene Box mit runder Sprechblase&#10;Mietanfragen', '[10,90][300,160]')}${node('Abmelden', '[10,170][300,240]')}${node('Erkunden', '[0,100][200,200]')}${node('Profil', '[800,100][1000,200]')}<node text="private@example.com" content-desc=""/></hierarchy>`;
const guestHierarchy = `<hierarchy>${node('Anmelden', '[10,10][300,80]')}${node('Konto erstellen', '[10,90][300,160]')}${node('Erkunden', '[0,100][200,200]')}${node('Profil', '[800,100][1000,200]')}</hierarchy>`;

function fakeRunner({ locked = false, guest = false, bytes = apkBytes } = {}) {
  let surface = 'main';
  let launches = 0;
  const calls = [];
  const runner = (_file, args, options = {}) => {
    calls.push(args);
    const command = args.slice(2);
    if (command.join(' ') === 'shell dumpsys window policy') {
      return locked ? 'keyguardShowing=true' : 'keyguardShowing=false';
    }
    if (command.join(' ') === 'shell pm path com.shareittoo.app') return 'package:/data/app/base.apk';
    if (command.join(' ') === 'exec-out cat /data/app/base.apk') return options.binary ? bytes : bytes.toString();
    if (command.join(' ') === 'shell dumpsys package com.shareittoo.app') {
      return '  versionName=1.0.0\n  versionCode=2026081018 minSdk=23 targetSdk=36';
    }
    if (command[0] === 'shell' && command[1] === 'am' && command[2] === 'force-stop') {
      surface = 'main';
      return '';
    }
    if (command[0] === 'shell' && command[1] === 'monkey') {
      launches += 1;
      surface = 'main';
      return 'Events injected: 1';
    }
    if (command[0] === 'shell' && command[1] === 'uiautomator') return 'UI hierarchy dumped';
    if (command.join(' ') === 'exec-out cat /sdcard/sit-authenticated-session-diagnostic.xml') {
      if (surface === 'profile') return guest ? guestHierarchy : authenticatedHierarchy;
      return mainHierarchy;
    }
    if (command[0] === 'shell' && command[1] === 'input' && command[2] === 'tap') {
      const x = Number(command[3]);
      surface = x >= 700 ? 'profile' : 'main';
      return '';
    }
    if (command[0] === 'shell' && command[1] === 'rm') return '';
    throw new Error(`unexpected command: ${command.join(' ')}`);
  };
  return { runner, calls, get launches() { return launches; } };
}

test('proves a bounded authenticated cold-start session without emitting identity data', async () => {
  const fake = fakeRunner();
  const evidence = await diagnoseAndroidAuthenticatedSession({
    commandRunner: fake.runner,
    adbPath: 'adb',
    device,
    deviceSummary,
    candidate,
    archive,
    capturedAt: '2026-08-10T09:45:00.000Z',
    wait: async () => {},
  });
  assert.equal(evidence.status, 'passed-bounded-authenticated-session-diagnostic');
  assert.equal(evidence.tests.authenticatedProfileAccess.status, 'passed');
  assert.equal(evidence.tests.coldStartSessionRestore.status, 'passed');
  assert.equal(evidence.boundaries.syntheticRoleMatrixPassed, false);
  assert.equal(evidence.boundaries.accountIdentityRecorded, false);
  assert.equal(evidence.boundaries.containsPersonalAccountData, false);
  assert.equal(JSON.stringify(evidence).includes('private@example.com'), false);
  assert.equal(JSON.stringify(evidence).includes(device.serial), false);
  assert.equal(fake.launches, 2);
});

test('refuses a locked phone without entering a passcode', async () => {
  const fake = fakeRunner({ locked: true });
  await assert.rejects(
    diagnoseAndroidAuthenticatedSession({
      commandRunner: fake.runner,
      adbPath: 'adb',
      device,
      deviceSummary,
      candidate,
      archive,
      wait: async () => {},
    }),
    /locked.*never enters a passcode/,
  );
  assert.equal(fake.calls.some((args) => args.includes('input')), false);
});

test('does not misclassify the guest profile as an authenticated session', async () => {
  const fake = fakeRunner({ guest: true });
  await assert.rejects(
    diagnoseAndroidAuthenticatedSession({
      commandRunner: fake.runner,
      adbPath: 'adb',
      device,
      deviceSummary,
      candidate,
      archive,
      wait: async () => {},
    }),
    /authenticated ShareItToo surface did not appear/,
  );
});

test('rejects an installed APK that differs from the candidate', async () => {
  const fake = fakeRunner({ bytes: Buffer.from('different bytes') });
  await assert.rejects(
    diagnoseAndroidAuthenticatedSession({
      commandRunner: fake.runner,
      adbPath: 'adb',
      device,
      deviceSummary,
      candidate,
      archive,
      wait: async () => {},
    }),
    /APK does not match/,
  );
});
