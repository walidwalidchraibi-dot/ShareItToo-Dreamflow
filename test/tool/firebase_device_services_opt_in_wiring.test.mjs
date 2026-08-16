import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const read = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const runtime = read('lib/services/firebase_runtime.dart');
const android = read('android/app/src/main/AndroidManifest.xml');
const ios = read('ios/Runner/Info.plist');
const settings = read('lib/screens/notification_settings_screen.dart');
const deletion = read('lib/services/account_deletion_service.dart');
const backend = read('backend/src/app.js');

test('native Firebase auto collection is fail-closed on Android and iOS', () => {
  assert.match(android, /firebase_messaging_auto_init_enabled[\s\S]*android:value="false"/);
  assert.match(android, /firebase_analytics_collection_enabled[\s\S]*android:value="false"/);
  assert.match(android, /firebase_crashlytics_collection_enabled[\s\S]*android:value="false"/);
  assert.match(ios, /<key>FirebaseMessagingAutoInitEnabled<\/key>\s*<false\/>/);
  assert.match(ios, /<key>FirebaseCrashlyticsCollectionEnabled<\/key>\s*<false\/>/);
});

test('runtime gates push and crash collection on persisted user decisions', () => {
  assert.match(runtime, /FirebaseServicePreferencesStore\.read\(\)/);
  assert.match(runtime, /setAutoInitEnabled\(_pushEnabled\)/);
  assert.match(runtime, /kReleaseMode && _crashDiagnosticsEnabled/);
  assert.match(runtime, /!_crashDiagnosticsEnabled\) return/);
  assert.match(runtime, /setPushEnabled\(bool enabled\)/);
  assert.match(runtime, /setCrashDiagnosticsEnabled\(bool enabled\)/);
  assert.match(runtime, /deleteUnsentReports\(\)/);
});

test('account deletion removes the Firebase installation best effort', () => {
  assert.match(deletion, /FirebaseRuntime\.deleteInstallationForAccountDeletion\(\)/);
  assert.match(runtime, /FirebaseInstallations\.instance\.delete\(\)/);
  assert.match(runtime, /FirebaseMessaging\.instance\.deleteToken\(\)/);
  assert.match(runtime, /setInstallationCleanupPending\(true\)/);
  assert.match(runtime, /preferences\.installationCleanupPending/);
  assert.match(runtime, /setInstallationCleanupPending\(\s*false,?\s*\)/);
  assert.match(runtime, /setPushLocalCleanupPending\(true\)/);
  assert.match(runtime, /preferences\.pushLocalCleanupPending/);
  assert.match(runtime, /setPushLocalCleanupPending\(false\)/);
});

test('settings distinguish real device services from feed filters', () => {
  assert.match(settings, /Push-Mitteilungen auf diesem Gerät/);
  assert.match(settings, /Freiwillige Crashdiagnose/);
  assert.match(settings, /Firebase Cloud Messaging von Google/);
  assert.match(settings, /Firebase Crashlytics von Google/);
  assert.doesNotMatch(settings, /Push- und E-Mail-Benachrichtigungen folgen später/);
});

test('backend cleanup is current-session scoped and does not expose tokens', () => {
  const route = backend.match(/app\.delete\('\/v1\/auth\/devices\/push\/current'[\s\S]*?\n  \}\)\);/u)?.[0] ?? '';
  assert.match(route, /deletePushDevicesForSession/);
  assert.match(route, /sessionId: req\.auth\.sessionId/);
  assert.match(route, /userId: req\.auth\.userId/);
  assert.match(route, /deletedCount/);
  assert.doesNotMatch(route, /token|token_hash/);
});
