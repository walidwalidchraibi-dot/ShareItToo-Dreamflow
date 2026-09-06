#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { createHash, randomBytes } from 'node:crypto';
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { homedir } from 'node:os';
import { dirname, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import {
  assertCurrentHeadAndroidDeviceAlreadyUnlocked,
  currentHeadAndroidAdb,
  currentHeadAndroidNamedNodes,
  currentHeadAndroidNodeAttribute,
  defaultCurrentHeadAndroidCommandRunner,
  dumpCurrentHeadAndroidUi,
  restoreCurrentHeadAndroidExplore,
  verifyCurrentHeadAndroidInstalledCandidate,
} from './diagnose_current_head_android_main_navigation.mjs';
import {
  bindExactRole,
  openMainDestination,
  tapLabel,
  waitForHierarchy,
} from './diagnose_android_email_verified_two_role_product_journey.mjs';
import {
  inspectPhysicalDevice,
  parseAdbDevices,
  selectSinglePhysicalDevice,
} from './prepare_android_device_test.mjs';
import {
  readEmailVerifiedJourneyVault,
} from './run_staging_email_verified_two_role_journey.mjs';
import {
  validatePrivateAndroidReleaseArchive,
} from './validate_current_head_android_release_archive.mjs';
import {
  assertCurrentCandidateNoPostCandidateMobileSourceDrift,
  collectCurrentCandidateDriftPaths,
  validateCurrentPrivateAndroidCandidate,
} from './run_n28_current_candidate_pixel_surface_matrix.mjs';

const repositoryRoot = realpathSync(resolve(fileURLToPath(new URL('..', import.meta.url))));
const stagingApiBaseUrl = 'https://staging.shareittoo.com/api/v1';
const applicationId = 'com.shareittoo.app';
const sinkApplicationId = 'com.shareittoo.dev.privacyexportsink';
const sinkActivity = `${sinkApplicationId}/.ExportReceiverActivity`;
const sinkLabel = 'SIT Export Test';
const exportFileName = 'shareittoo-data-export.json';
const expectedLocalSections = Object.freeze([
  'accountProfile',
  'operationalRecords',
  'ownedListings',
  'reviews',
  'safetyPrivacy',
  'savedItems',
]);
const forbiddenKeyPattern = /(?:password|passcode|credential|access.?token|refresh.?token|session.?token|cookie|private.?key|api.?key|authorization)/iu;

function fail(message) {
  throw new Error(message);
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function sameJson(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function safeString(value, label) {
  if (typeof value !== 'string' || value.trim() === '') fail(`${label} must be a non-empty string.`);
  return value.trim();
}

function withinRepository(path) {
  const exact = resolve(path);
  return exact === repositoryRoot || exact.startsWith(`${repositoryRoot}${sep}`);
}

function privateDirectory(path) {
  const exact = resolve(path);
  if (withinRepository(exact)) fail('The private export evidence directory must be outside Git.');
  mkdirSync(exact, { recursive: true, mode: 0o700 });
  chmodSync(exact, 0o700);
  const stat = statSync(exact);
  if (!stat.isDirectory() || (stat.mode & 0o077) !== 0) {
    fail('The private export evidence directory must be owner-only.');
  }
  return realpathSync(exact);
}

function recursiveKeys(value, result = []) {
  if (Array.isArray(value)) {
    for (const entry of value) recursiveKeys(entry, result);
  } else if (value !== null && typeof value === 'object') {
    for (const [key, entry] of Object.entries(value)) {
      result.push(key);
      recursiveKeys(entry, result);
    }
  }
  return result;
}

function identityAppears(serialized, identity) {
  if (typeof identity !== 'string' || identity.length < 3) return false;
  return serialized.toLowerCase().includes(identity.toLowerCase());
}

export function validatePrivacyExportPayload({
  bytes,
  ownerUserId,
  ownerEmail,
  foreignUserId,
  foreignEmail,
}) {
  if (!Buffer.isBuffer(bytes) || bytes.length === 0 || bytes.length > 32 * 1024 * 1024) {
    fail('The received privacy export has an invalid byte length.');
  }
  let value;
  try {
    value = JSON.parse(bytes.toString('utf8'));
  } catch {
    fail('The received privacy export is not valid JSON.');
  }
  if (value === null || Array.isArray(value) || typeof value !== 'object'
      || value.schemaVersion !== '1.0'
      || value.accountId !== ownerUserId
      || typeof value.generatedAt !== 'string'
      || !Number.isFinite(Date.parse(value.generatedAt))
      || value.data === null || Array.isArray(value.data) || typeof value.data !== 'object'
      || value.localDevice === null || Array.isArray(value.localDevice)
      || typeof value.localDevice !== 'object') {
    fail('The privacy export root contract or exact owner binding is invalid.');
  }
  const sections = Object.keys(value.localDevice).toSorted();
  if (!sameJson(sections, expectedLocalSections)) {
    fail('The privacy export does not contain the exact six local sections.');
  }
  for (const [name, section] of Object.entries(value.localDevice)) {
    if (section === null || Array.isArray(section) || typeof section !== 'object') {
      fail(`The ${name} privacy export section is invalid.`);
    }
    if (Object.hasOwn(section, 'accountId') && section.accountId !== ownerUserId) {
      fail(`The ${name} privacy export section belongs to another principal.`);
    }
  }
  const serialized = bytes.toString('utf8');
  if (!identityAppears(serialized, ownerEmail)) {
    fail('The privacy export does not contain the expected owner identity.');
  }
  if (identityAppears(serialized, foreignEmail)
      || identityAppears(serialized, foreignUserId)) {
    fail('The privacy export contains the foreign test principal.');
  }
  const forbiddenKeys = recursiveKeys(value).filter((key) => forbiddenKeyPattern.test(key));
  if (forbiddenKeys.length > 0) {
    fail('The privacy export contains a credential- or session-shaped key.');
  }
  return Object.freeze({
    schemaVersion: value.schemaVersion,
    exactOwnerBound: true,
    ownerIdentityPresent: true,
    foreignIdentityAbsent: true,
    localSections: sections,
    forbiddenCredentialKeyCount: 0,
    bytes: bytes.length,
    sha256: sha256(bytes),
  });
}

export const privacyExportSinkManifest = `<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="${sinkApplicationId}">
  <application
      android:allowBackup="false"
      android:debuggable="true"
      android:label="${sinkLabel}"
      android:usesCleartextTraffic="false">
    <activity
        android:name=".ExportReceiverActivity"
        android:excludeFromRecents="true"
        android:exported="true"
        android:grantUriPermissions="true"
        android:noHistory="true"
        android:taskAffinity="">
      <intent-filter>
        <action android:name="android.intent.action.SEND" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:mimeType="application/json" />
      </intent-filter>
    </activity>
  </application>
</manifest>
`;

export const privacyExportSinkJava = `package ${sinkApplicationId};

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import java.io.ByteArrayOutputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.security.MessageDigest;
import org.json.JSONObject;

public final class ExportReceiverActivity extends Activity {
  private static final int MAX_BYTES = 32 * 1024 * 1024;

  private static String hex(byte[] value) {
    StringBuilder result = new StringBuilder(value.length * 2);
    for (byte entry : value) result.append(String.format("%02x", entry & 0xff));
    return result.toString();
  }

  private void reject() {
    deleteFile("${exportFileName}");
    deleteFile("receipt.json");
    setResult(RESULT_CANCELED);
    finishAndRemoveTask();
  }

  @Override protected void onCreate(Bundle state) {
    super.onCreate(state);
    Intent intent = getIntent();
    if (!Intent.ACTION_SEND.equals(intent.getAction())
        || !"application/json".equals(intent.getType())) {
      reject();
      return;
    }
    Uri uri = intent.getParcelableExtra(Intent.EXTRA_STREAM);
    if (uri == null) {
      reject();
      return;
    }
    try (InputStream input = getContentResolver().openInputStream(uri);
         ByteArrayOutputStream buffer = new ByteArrayOutputStream()) {
      if (input == null) throw new IllegalStateException("missing stream");
      byte[] chunk = new byte[8192];
      int total = 0;
      for (int read = input.read(chunk); read >= 0; read = input.read(chunk)) {
        total += read;
        if (total > MAX_BYTES) throw new IllegalStateException("oversize");
        buffer.write(chunk, 0, read);
      }
      byte[] bytes = buffer.toByteArray();
      if (bytes.length == 0) throw new IllegalStateException("empty");
      try (FileOutputStream output = openFileOutput("${exportFileName}", MODE_PRIVATE)) {
        output.write(bytes);
        output.getFD().sync();
      }
      JSONObject receipt = new JSONObject();
      receipt.put("status", "received");
      receipt.put("bytes", bytes.length);
      receipt.put("sha256", hex(MessageDigest.getInstance("SHA-256").digest(bytes)));
      try (FileOutputStream output = openFileOutput("receipt.json", MODE_PRIVATE)) {
        output.write(receipt.toString().getBytes("UTF-8"));
        output.getFD().sync();
      }
      setResult(RESULT_OK);
      finishAndRemoveTask();
    } catch (Exception ignored) {
      reject();
    }
  }
}
`;

export function validatePrivacyExportSinkSources({
  manifest = privacyExportSinkManifest,
  java = privacyExportSinkJava,
} = {}) {
  if (manifest.includes('<uses-permission')
      || /INTERNET|ACCESS_NETWORK_STATE|READ_CONTACTS|READ_MEDIA|WRITE_EXTERNAL_STORAGE/u.test(manifest)
      || !manifest.includes('android:allowBackup="false"')
      || !manifest.includes('android:usesCleartextTraffic="false"')
      || !manifest.includes('android:debuggable="true"')
      || !manifest.includes('android.intent.action.SEND')
      || !manifest.includes('android:mimeType="application/json"')
      || !manifest.includes(`package="${sinkApplicationId}"`)) {
    fail('The temporary export sink manifest is not fail-closed.');
  }
  for (const marker of [
    'MAX_BYTES = 32 * 1024 * 1024',
    'deleteFile("shareittoo-data-export.json")',
    'MessageDigest.getInstance("SHA-256")',
    'openFileOutput("shareittoo-data-export.json", MODE_PRIVATE)',
  ]) {
    if (!java.includes(marker)) fail('The temporary export sink implementation is incomplete.');
  }
  if (/https?:|Socket|URLConnection|HttpClient|WebView/u.test(java)) {
    fail('The temporary export sink contains a network-capable code path.');
  }
  return Object.freeze({
    applicationId: sinkApplicationId,
    activity: sinkActivity,
    label: sinkLabel,
    internetPermission: false,
    externalStoragePermission: false,
    backupEnabled: false,
    cleartextEnabled: false,
    privateFileOnly: true,
    maxBytes: 32 * 1024 * 1024,
  });
}

function hostRun(command, args, options = {}) {
  return String(execFileSync(command, args, {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    ...options,
  }));
}

function latestBuildTools(sdkRoot) {
  const candidates = ['36.0.0', '35.0.1', '35.0.0', '34.0.0'];
  for (const version of candidates) {
    const directory = resolve(sdkRoot, 'build-tools', version);
    try {
      if (statSync(resolve(directory, 'aapt2')).isFile()
          && statSync(resolve(directory, 'd8')).isFile()
          && statSync(resolve(directory, 'apksigner')).isFile()
          && statSync(resolve(directory, 'zipalign')).isFile()) return directory;
    } catch {
      // Continue to the next exact supported build-tools directory.
    }
  }
  fail('A complete supported Android build-tools directory is unavailable.');
}

function androidJar(sdkRoot) {
  for (const api of ['android-36', 'android-35']) {
    const path = resolve(sdkRoot, 'platforms', api, 'android.jar');
    try {
      if (statSync(path).isFile()) return path;
    } catch {
      // Continue to the next supported platform.
    }
  }
  fail('A supported Android platform jar is unavailable.');
}

export function buildPrivacyExportSink({
  sdkRoot,
  temporaryRoot,
  runner = hostRun,
  random = randomBytes,
} = {}) {
  validatePrivacyExportSinkSources();
  const exactSdkRoot = realpathSync(resolve(safeString(sdkRoot, 'sdkRoot')));
  const parent = privateDirectory(safeString(temporaryRoot, 'temporaryRoot'));
  const directory = mkdtempSync(resolve(parent, 'sink-'));
  chmodSync(directory, 0o700);
  const sourceDirectory = resolve(directory, 'src', ...sinkApplicationId.split('.'));
  const classesDirectory = resolve(directory, 'classes');
  const dexDirectory = resolve(directory, 'dex');
  mkdirSync(sourceDirectory, { recursive: true, mode: 0o700 });
  mkdirSync(classesDirectory, { mode: 0o700 });
  mkdirSync(dexDirectory, { mode: 0o700 });
  const manifestPath = resolve(directory, 'AndroidManifest.xml');
  const javaPath = resolve(sourceDirectory, 'ExportReceiverActivity.java');
  writeFileSync(manifestPath, privacyExportSinkManifest, { mode: 0o600 });
  writeFileSync(javaPath, privacyExportSinkJava, { mode: 0o600 });
  try {
    const tools = latestBuildTools(exactSdkRoot);
    const platform = androidJar(exactSdkRoot);
    const unsigned = resolve(directory, 'sink-unsigned.apk');
    const withDex = resolve(directory, 'sink-with-dex.apk');
    const aligned = resolve(directory, 'sink-aligned.apk');
    const signed = resolve(directory, 'sink.apk');
    const keystore = resolve(directory, 'ephemeral.p12');
    const password = random(24).toString('base64url');
    if (!/^[A-Za-z0-9_-]{32}$/u.test(password)) {
      fail('The ephemeral sink signing secret is invalid.');
    }
    runner('javac', [
      '-source', '8', '-target', '8', '-Xlint:-options',
      '-classpath', platform, '-d', classesDirectory, javaPath,
    ]);
    runner(resolve(tools, 'd8'), [
      '--min-api', '24', '--lib', platform, '--output', dexDirectory,
      resolve(classesDirectory, ...sinkApplicationId.split('.'), 'ExportReceiverActivity.class'),
    ]);
    runner(resolve(tools, 'aapt2'), [
      'link', '-o', unsigned, '-I', platform, '--manifest', manifestPath,
      '--min-sdk-version', '24', '--target-sdk-version', '35',
    ]);
    runner('cp', [unsigned, withDex]);
    runner('zip', ['-q', '-j', withDex, resolve(dexDirectory, 'classes.dex')]);
    runner(resolve(tools, 'zipalign'), ['-f', '-p', '4', withDex, aligned]);
    runner('keytool', [
      '-genkeypair', '-noprompt', '-storetype', 'PKCS12', '-keystore', keystore,
      '-storepass', password, '-keypass', password, '-alias', 'ephemeral',
      '-dname', 'CN=SIT Local Privacy Export Test', '-keyalg', 'RSA',
      '-keysize', '2048', '-validity', '1',
    ]);
    runner(resolve(tools, 'apksigner'), [
      'sign', '--ks', keystore, '--ks-key-alias', 'ephemeral',
      '--ks-pass', `pass:${password}`, '--key-pass', `pass:${password}`,
      '--out', signed, aligned,
    ]);
    runner(resolve(tools, 'apksigner'), ['verify', '--verbose', signed]);
    const xml = runner(resolve(tools, 'aapt2'), [
      'dump', 'xmltree', '--file', 'AndroidManifest.xml', signed,
    ]);
    if (!xml.includes(sinkApplicationId)
        || !xml.includes('android.intent.action.SEND')
        || xml.includes('android.permission.INTERNET')
        || xml.includes('uses-permission')) {
      fail('The built export sink APK does not match its no-network contract.');
    }
    return Object.freeze({
      directory,
      apkPath: signed,
      apkSha256: sha256(readFileSync(signed)),
      contract: validatePrivacyExportSinkSources(),
    });
  } catch (error) {
    rmSync(directory, { recursive: true, force: true });
    throw error;
  }
}

function nodeCenter(node, label) {
  const bounds = /^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/u.exec(
    currentHeadAndroidNodeAttribute(node, 'bounds') ?? '',
  );
  if (bounds === null) fail(`The ${label} action has invalid Android bounds.`);
  return Object.freeze({
    x: Math.floor((Number(bounds[1]) + Number(bounds[3])) / 2),
    y: Math.floor((Number(bounds[2]) + Number(bounds[4])) / 2),
  });
}

function tapNamed(commandRunner, adbPath, device, hierarchy, label, { last = false } = {}) {
  const enabled = currentHeadAndroidNamedNodes(hierarchy, label)
    .filter((node) => currentHeadAndroidNodeAttribute(node, 'enabled') !== 'false');
  const clickable = enabled.filter(
    (node) => currentHeadAndroidNodeAttribute(node, 'clickable') === 'true',
  );
  const matches = clickable.length > 0 ? clickable : enabled;
  if (matches.length === 0) fail(`The ${label} action is unavailable.`);
  const point = nodeCenter(last ? matches.at(-1) : matches[0], label);
  currentHeadAndroidAdb(commandRunner, adbPath, device, [
    'shell', 'input', 'tap', String(point.x), String(point.y),
  ]);
}

function inputPrivateText(commandRunner, adbPath, device, hierarchy, label, value) {
  if (!/^[A-Za-z0-9._+@-]{1,200}$/u.test(value)) {
    fail(`The private ${label} input is not safe for bounded Android entry.`);
  }
  tapNamed(commandRunner, adbPath, device, hierarchy, label);
  currentHeadAndroidAdb(commandRunner, adbPath, device, [
    'shell', 'input', 'text', value,
  ]);
}

async function scrollUntil({ commandRunner, adbPath, device, wait, label }) {
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const hierarchy = dumpCurrentHeadAndroidUi(commandRunner, adbPath, device);
    if (currentHeadAndroidNamedNodes(hierarchy, label).length > 0) return hierarchy;
    currentHeadAndroidAdb(commandRunner, adbPath, device, [
      'shell', 'input', 'swipe', '720', '2450', '720', '700', '450',
    ]);
    await wait(450);
  }
  fail(`The ${label} surface is not reachable.`);
}

async function openPrivacyExport({ commandRunner, adbPath, device, wait }) {
  let hierarchy = await openMainDestination({
    commandRunner, adbPath, device, wait, label: 'Mein SIT',
  });
  tapLabel(commandRunner, adbPath, device, hierarchy, 'Suchen');
  hierarchy = await waitForHierarchy({
    commandRunner,
    adbPath,
    device,
    wait,
    label: 'profile search',
    predicate: (value) => currentHeadAndroidNamedNodes(value, 'Suche schließen').length > 0,
  });
  currentHeadAndroidAdb(commandRunner, adbPath, device, [
    'shell', 'input', 'text', 'Kontoeinstellungen',
  ]);
  currentHeadAndroidAdb(commandRunner, adbPath, device, ['shell', 'input', 'keyevent', '66']);
  hierarchy = await waitForHierarchy({
    commandRunner,
    adbPath,
    device,
    wait,
    label: 'account settings',
    predicate: (value) => currentHeadAndroidNamedNodes(value, 'Kontoeinstellungen').length > 0
      && currentHeadAndroidNamedNodes(value, 'SICHERHEIT').length > 0,
  });
  hierarchy = await scrollUntil({
    commandRunner, adbPath, device, wait, label: 'Datenschutz-Infos',
  });
  tapNamed(commandRunner, adbPath, device, hierarchy, 'Datenschutz-Infos');
  await waitForHierarchy({
    commandRunner,
    adbPath,
    device,
    wait,
    label: 'privacy information',
    predicate: (value) => currentHeadAndroidNamedNodes(value, 'Datenschutz-Infos').length > 0,
  });
  return scrollUntil({
    commandRunner, adbPath, device, wait, label: 'Meine Daten exportieren',
  });
}

async function openExportPasswordDialog({ commandRunner, adbPath, device, wait }) {
  const privacy = await openPrivacyExport({ commandRunner, adbPath, device, wait });
  tapNamed(commandRunner, adbPath, device, privacy, 'Meine Daten exportieren');
  return waitForHierarchy({
    commandRunner,
    adbPath,
    device,
    wait,
    label: 'privacy export password dialog',
    predicate: (value) => currentHeadAndroidNamedNodes(value, 'Datenexport bestätigen').length > 0
      && currentHeadAndroidNamedNodes(value, 'Aktuelles Passwort').length > 0
      && currentHeadAndroidNamedNodes(value, 'Export erstellen').length > 0,
  });
}

async function submitExportPassword({
  commandRunner, adbPath, device, wait, password,
}) {
  let hierarchy = await openExportPasswordDialog({ commandRunner, adbPath, device, wait });
  inputPrivateText(commandRunner, adbPath, device, hierarchy, 'Aktuelles Passwort', password);
  hierarchy = dumpCurrentHeadAndroidUi(commandRunner, adbPath, device);
  tapNamed(commandRunner, adbPath, device, hierarchy, 'Export erstellen');
}

function packagePresent(commandRunner, adbPath, device, packageName) {
  const packages = currentHeadAndroidAdb(commandRunner, adbPath, device, [
    'shell', 'pm', 'list', 'packages', packageName,
  ]);
  return packages.split(/\r?\n/u).some((line) => line === `package:${packageName}`);
}

function installSink(commandRunner, adbPath, device, apkPath) {
  if (packagePresent(commandRunner, adbPath, device, sinkApplicationId)) {
    fail('The temporary privacy export sink was already installed.');
  }
  const installed = currentHeadAndroidAdb(commandRunner, adbPath, device, [
    'install', '--no-streaming', apkPath,
  ]);
  if (!installed.includes('Success') || !packagePresent(
    commandRunner, adbPath, device, sinkApplicationId,
  )) {
    fail('The temporary privacy export sink did not install exactly once.');
  }
  const packageState = currentHeadAndroidAdb(commandRunner, adbPath, device, [
    'shell', 'dumpsys', 'package', sinkApplicationId,
  ]);
  if (packageState.includes('android.permission.INTERNET')
      || !packageState.includes('android.intent.action.SEND')
      || !packageState.includes('application/json')) {
    fail('The installed privacy export sink does not match its no-network contract.');
  }
}

function removeSink(commandRunner, adbPath, device) {
  if (!packagePresent(commandRunner, adbPath, device, sinkApplicationId)) return false;
  currentHeadAndroidAdb(commandRunner, adbPath, device, [
    'shell', 'pm', 'clear', sinkApplicationId,
  ]);
  currentHeadAndroidAdb(commandRunner, adbPath, device, [
    'uninstall', sinkApplicationId,
  ]);
  if (packagePresent(commandRunner, adbPath, device, sinkApplicationId)) {
    fail('The temporary privacy export sink remained installed after cleanup.');
  }
  return true;
}

function pullSinkFile(commandRunner, adbPath, device, name) {
  const output = execFileSync(adbPath, [
    '-s', device.serial, 'exec-out', 'run-as', sinkApplicationId,
    'cat', `files/${name}`,
  ], { stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 40 * 1024 * 1024 });
  if (!Buffer.isBuffer(output) || output.length === 0) {
    fail(`The temporary sink ${name} file is unavailable.`);
  }
  return output;
}

async function waitForSinkReceipt({ commandRunner, adbPath, device, wait }) {
  for (let attempt = 0; attempt < 30; attempt += 1) {
    try {
      const receipt = JSON.parse(pullSinkFile(
        commandRunner, adbPath, device, 'receipt.json',
      ).toString('utf8'));
      if (receipt.status === 'received'
          && Number.isInteger(receipt.bytes) && receipt.bytes > 0
          && /^[a-f0-9]{64}$/u.test(receipt.sha256)) return receipt;
    } catch {
      // The exact local receipt is not durable yet.
    }
    await wait(500);
  }
  fail('The temporary privacy export sink did not receive an exact payload.');
}

async function selectSinkFromChooser({ commandRunner, adbPath, device, wait }) {
  let hierarchy = await waitForHierarchy({
    commandRunner,
    adbPath,
    device,
    wait,
    label: 'Android privacy export chooser',
    predicate: (value) => value.includes('com.android.intentresolver')
      || currentHeadAndroidNamedNodes(value, sinkLabel).length > 0,
  });
  if (currentHeadAndroidNamedNodes(hierarchy, sinkLabel).length === 0) {
    const moreLabels = ['Mehr', 'Weitere', 'More'];
    const more = moreLabels.find(
      (label) => currentHeadAndroidNamedNodes(hierarchy, label).length > 0,
    );
    if (more !== undefined) {
      tapNamed(commandRunner, adbPath, device, hierarchy, more);
      hierarchy = await waitForHierarchy({
        commandRunner,
        adbPath,
        device,
        wait,
        label: 'expanded Android privacy export chooser',
        predicate: (value) => currentHeadAndroidNamedNodes(value, sinkLabel).length > 0,
      });
    }
  }
  tapNamed(commandRunner, adbPath, device, hierarchy, sinkLabel);
}

async function stagingPrincipal(fetchImpl, account) {
  const login = await fetchImpl(`${stagingApiBaseUrl}/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
    body: JSON.stringify({ email: account.email, password: account.password }),
    signal: AbortSignal.timeout(20_000),
  });
  const session = await login.json().catch(() => null);
  if (login.status !== 200
      || typeof session?.accessToken !== 'string' || session.accessToken.length < 20
      || typeof session?.refreshToken !== 'string' || session.refreshToken.length < 20) {
    fail(`The ${account.role} Staging fixture could not establish an exact probe session.`);
  }
  const me = await fetchImpl(`${stagingApiBaseUrl}/auth/me`, {
    headers: { authorization: `Bearer ${session.accessToken}`, 'cache-control': 'no-store' },
    signal: AbortSignal.timeout(20_000),
  });
  const value = await me.json().catch(() => null);
  if (me.status !== 200
      || typeof value?.user?.id !== 'string' || value.user.id.length === 0
      || String(value.user.email ?? '').toLowerCase() !== account.email.toLowerCase()) {
    fail(`The ${account.role} Staging probe session is not bound to the exact principal.`);
  }
  return { userId: value.user.id, accessToken: session.accessToken, refreshToken: session.refreshToken };
}

async function revokeProbeSession(fetchImpl, session) {
  if (session === null) return true;
  try {
    const response = await fetchImpl(`${stagingApiBaseUrl}/auth/logout`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ refreshToken: session.refreshToken }),
      signal: AbortSignal.timeout(20_000),
    });
    return response.status === 204;
  } catch {
    return false;
  }
}

export async function runAndroidPrivacyExportPayload({
  root = repositoryRoot,
  candidateDirectory,
  vaultFile,
  adbPath = 'adb',
  sdkRoot = resolve(dirname(adbPath), '..'),
  privateEvidenceRoot = resolve(
    homedir(), 'Library', 'Application Support', 'ShareItToo', 'qa', 'privacy-export',
  ),
  commandRunner = defaultCurrentHeadAndroidCommandRunner,
  fetchImpl = globalThis.fetch,
  wait = (milliseconds) => new Promise((resolvePromise) => setTimeout(resolvePromise, milliseconds)),
  capturedAt = new Date().toISOString(),
} = {}) {
  const archive = await validatePrivateAndroidReleaseArchive({ root, candidateDirectory });
  const candidate = validateCurrentPrivateAndroidCandidate(archive);
  const sourceDrift = assertCurrentCandidateNoPostCandidateMobileSourceDrift(
    collectCurrentCandidateDriftPaths({ root, candidateCommit: candidate.commit }),
  );
  const device = selectSinglePhysicalDevice(parseAdbDevices(
    commandRunner(adbPath, ['devices', '-l']),
  ));
  const deviceSummary = inspectPhysicalDevice({ adbPath, device });
  assertCurrentHeadAndroidDeviceAlreadyUnlocked(commandRunner, adbPath, device);
  verifyCurrentHeadAndroidInstalledCandidate(commandRunner, adbPath, device, candidate);
  if (packagePresent(commandRunner, adbPath, device, sinkApplicationId)) {
    fail('A previous temporary privacy export sink is still installed; cleanup is required.');
  }

  const sourceVaultBytes = readFileSync(vaultFile);
  const sourceVaultSha256 = sha256(sourceVaultBytes);
  const { vault } = readEmailVerifiedJourneyVault(vaultFile);
  if (vault.apiBaseUrl !== stagingApiBaseUrl || vault.stripeLivemode !== false
      || !['fixture-verified-ready-for-login', 'email-link-verified-ready-for-login']
        .includes(vault.status)) {
    fail('The protected two-role vault is not eligible for the privacy export diagnostic.');
  }
  const owner = vault.accounts.find((entry) => entry.role === 'owner');
  const foreign = vault.accounts.find((entry) => entry.role === 'renter');
  if (owner === undefined || foreign === undefined) fail('The protected two-role roles are incomplete.');

  const privateRoot = privateDirectory(privateEvidenceRoot);
  const buildRoot = privateDirectory(resolve(privateRoot, 'temporary-builds'));
  let sink = null;
  let ownerSession = null;
  let foreignSession = null;
  let installed = false;
  let ownerRestored = false;
  let cleanupError = null;
  try {
    ownerSession = await stagingPrincipal(fetchImpl, owner);
    foreignSession = await stagingPrincipal(fetchImpl, foreign);
    sink = buildPrivacyExportSink({ sdkRoot, temporaryRoot: buildRoot });
    installSink(commandRunner, adbPath, device, sink.apkPath);
    installed = true;
    await bindExactRole({
      vault, role: 'owner', commandRunner, adbPath, device, wait,
    });

    await submitExportPassword({
      commandRunner,
      adbPath,
      device,
      wait,
      password: 'SITWrong9xyz',
    });
    let hierarchy = await waitForHierarchy({
      commandRunner,
      adbPath,
      device,
      wait,
      label: 'definite wrong-password export rejection',
      predicate: (value) => currentHeadAndroidNamedNodes(
        value, 'Datenexport fehlgeschlagen',
      ).length > 0,
    });
    if (packagePresent(commandRunner, adbPath, device, sinkApplicationId)) {
      try {
        pullSinkFile(commandRunner, adbPath, device, 'receipt.json');
        fail('The rejected export unexpectedly reached the temporary sink.');
      } catch (error) {
        if (error?.message === 'The rejected export unexpectedly reached the temporary sink.') {
          throw error;
        }
      }
    }
    tapNamed(commandRunner, adbPath, device, hierarchy, 'OK');

    await submitExportPassword({
      commandRunner,
      adbPath,
      device,
      wait,
      password: owner.password,
    });
    await selectSinkFromChooser({ commandRunner, adbPath, device, wait });
    const receipt = await waitForSinkReceipt({ commandRunner, adbPath, device, wait });
    const bytes = pullSinkFile(commandRunner, adbPath, device, exportFileName);
    const payload = validatePrivacyExportPayload({
      bytes,
      ownerUserId: ownerSession.userId,
      ownerEmail: owner.email,
      foreignUserId: foreignSession.userId,
      foreignEmail: foreign.email,
    });
    if (receipt.bytes !== payload.bytes || receipt.sha256 !== payload.sha256) {
      fail('The temporary sink receipt does not match the exact received export bytes.');
    }
    return Object.freeze({
      schemaVersion: 1,
      kind: 'sit-wp33-pixel-privacy-export-payload',
      status: 'passed-exact-current-principal-export-and-cleanup-pending',
      capturedAt,
      candidate: {
        applicationId: candidate.applicationId,
        versionName: candidate.versionName,
        buildNumber: candidate.buildNumber,
        commit: candidate.commit,
        apkSha256: candidate.android.apkSha256,
        sourceDrift,
      },
      device: deviceSummary,
      tests: {
        wrongPasswordRejectedBeforeShare: true,
        correctPasswordAccepted: true,
        androidShareReceiverInvokedOnce: true,
        exactOwnerBound: payload.exactOwnerBound,
        ownerIdentityPresent: payload.ownerIdentityPresent,
        foreignIdentityAbsent: payload.foreignIdentityAbsent,
        localSections: payload.localSections,
        forbiddenCredentialKeyCount: payload.forbiddenCredentialKeyCount,
        exportBytes: payload.bytes,
        exportSha256: payload.sha256,
      },
      sink: {
        applicationId: sinkApplicationId,
        apkSha256: sink.apkSha256,
        internetPermission: false,
        externalStoragePermission: false,
        backupEnabled: false,
        privateFileOnly: true,
      },
      boundaries: {
        rawExportRetained: false,
        rawExportPrinted: false,
        accountIdentityRecorded: false,
        credentialsRecorded: false,
        cloudShareTargetUsed: false,
        networkCapableReceiverUsed: false,
        shareItTooCandidateChanged: false,
        accountMutationPerformed: false,
        paymentEndpointCalled: false,
        stripeLivemode: false,
        productionChanged: false,
        googlePlayChanged: false,
        onePlusContacted: false,
        pullRequestMerged: false,
      },
    });
  } finally {
    try {
      restoreCurrentHeadAndroidExplore(commandRunner, adbPath, device);
    } catch (error) {
      cleanupError = error;
    }
    if (installed) {
      try {
        removeSink(commandRunner, adbPath, device);
      } catch (error) {
        cleanupError ??= error;
      }
    }
    try {
      await bindExactRole({
        vault, role: 'owner', commandRunner, adbPath, device, wait,
      });
      ownerRestored = true;
    } catch (error) {
      cleanupError ??= error;
    }
    if (sink !== null) rmSync(sink.directory, { recursive: true, force: true });
    const ownerRevoked = await revokeProbeSession(fetchImpl, ownerSession);
    const foreignRevoked = await revokeProbeSession(fetchImpl, foreignSession);
    if (!ownerRevoked || !foreignRevoked) {
      cleanupError ??= new Error('The temporary exact-principal probe sessions were not revoked.');
    }
    if (sha256(readFileSync(vaultFile)) !== sourceVaultSha256) {
      cleanupError ??= new Error('The protected two-role vault changed during the export diagnostic.');
    }
    if (packagePresent(commandRunner, adbPath, device, sinkApplicationId)) {
      cleanupError ??= new Error('The temporary privacy export sink remains installed.');
    }
    if (!ownerRestored) {
      cleanupError ??= new Error('The exact protected owner session was not restored.');
    }
    if (cleanupError !== null) throw cleanupError;
  }
}

function parseArguments(values) {
  let candidateDirectory = null;
  let vaultFile = null;
  let adbPath = 'adb';
  let sdkRoot = null;
  for (let index = 0; index < values.length; index += 1) {
    if (values[index] === '--candidate-dir') {
      candidateDirectory = values[index + 1] ?? fail('--candidate-dir requires a path.');
      index += 1;
    } else if (values[index] === '--vault-file') {
      vaultFile = values[index + 1] ?? fail('--vault-file requires a path.');
      index += 1;
    } else if (values[index] === '--adb') {
      adbPath = values[index + 1] ?? fail('--adb requires a path.');
      index += 1;
    } else if (values[index] === '--sdk-root') {
      sdkRoot = values[index + 1] ?? fail('--sdk-root requires a path.');
      index += 1;
    } else {
      fail(`Unknown argument: ${values[index]}`);
    }
  }
  if (candidateDirectory === null) fail('--candidate-dir is required.');
  if (vaultFile === null) fail('--vault-file is required.');
  return {
    candidateDirectory: resolve(candidateDirectory),
    vaultFile: resolve(vaultFile),
    adbPath,
    sdkRoot: sdkRoot === null ? resolve(dirname(adbPath), '..') : resolve(sdkRoot),
  };
}

async function run() {
  const result = await runAndroidPrivacyExportPayload(parseArguments(process.argv.slice(2)));
  const completed = {
    ...result,
    status: 'passed-exact-current-principal-export-and-complete-cleanup',
    cleanup: {
      temporarySinkRemoved: true,
      temporarySinkDataRemoved: true,
      temporaryBuildRemoved: true,
      temporaryProbeSessionsRevoked: true,
      protectedVaultUnchanged: true,
      exactOwnerRemainsSignedIn: true,
    },
  };
  process.stdout.write(`${JSON.stringify(completed, null, 2)}\n`);
}

if (process.argv[1]
    && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    await run();
  } catch (error) {
    process.stderr.write(`ERROR: ${error?.message ?? 'Pixel privacy export diagnostic failed.'}\n`);
    process.exitCode = 1;
  }
}
