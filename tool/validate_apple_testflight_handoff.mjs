#!/usr/bin/env node

import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const forbiddenKey = /(password|passcode|secret|token|credential|private.?key|api.?key|otp|pin)$/i;

function fail(message) {
  throw new Error(message);
}

function object(value, label) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${label} must be an object.`);
  }
  return value;
}

function same(actual, expected, label) {
  if (actual !== expected) fail(`${label} does not match the fail-closed Apple handoff.`);
}

function includes(source, needle, label) {
  if (!source.includes(needle)) fail(`${label} is missing ${needle}.`);
}

function count(source, needle) {
  return source.split(needle).length - 1;
}

function noCredentials(value, path = 'handoff') {
  if (Array.isArray(value)) {
    value.forEach((entry, index) => noCredentials(entry, `${path}[${index}]`));
    return;
  }
  if (value === null || typeof value !== 'object') return;
  for (const [key, entry] of Object.entries(value)) {
    if (forbiddenKey.test(key)) fail(`${path}.${key} is a forbidden credential-shaped field.`);
    noCredentials(entry, `${path}.${key}`);
  }
}

function source(root, relativePath, overrides) {
  if (Object.hasOwn(overrides, relativePath)) return overrides[relativePath];
  return readFileSync(resolve(root, relativePath), 'utf8');
}

function plistScalar(xml, key) {
  const match = new RegExp(`<key>${key}</key>\\s*<string>([^<]+)</string>`).exec(xml);
  return match?.[1] ?? null;
}

function privacyDataType(xml, type) {
  return xml.includes(`<string>${type}</string>`);
}

export function validateAppleTestFlightHandoff({ root, handoffOverride, sourceOverrides = {} }) {
  const handoff = object(handoffOverride ?? JSON.parse(source(
    root, 'store/apple/testflight-handoff.json', sourceOverrides)), 'handoff');
  noCredentials(handoff);
  same(handoff.schemaVersion, 1, 'schemaVersion');
  same(handoff.status, 'static-config-ready-tooling-and-account-gates-pending', 'status');
  same(handoff.submissionAllowed, false, 'submissionAllowed');
  same(handoff.distribution, 'testflight-internal', 'distribution');
  same(handoff.containsSecrets, false, 'containsSecrets');
  same(handoff.containsAccountIdentifiers, false, 'containsAccountIdentifiers');

  const candidate = object(handoff.candidate, 'candidate');
  same(candidate.bundleId, 'com.shareittoo.app', 'candidate.bundleId');
  same(candidate.versionName, '1.0.0', 'candidate.versionName');
  same(candidate.buildNumber, '2026081116', 'candidate.buildNumber');
  same(candidate.apiBaseUrl, 'https://staging.shareittoo.com/api/v1', 'candidate.apiBaseUrl');
  same(candidate.firebaseConfigured, true, 'candidate.firebaseConfigured');
  same(candidate.firebaseAnalyticsEnabled, false, 'candidate.firebaseAnalyticsEnabled');
  same(candidate.advertisingEnabled, false, 'candidate.advertisingEnabled');

  const pubspec = source(root, 'pubspec.yaml', sourceOverrides);
  includes(pubspec, `version: ${candidate.versionName}+${candidate.buildNumber}`, 'pubspec.yaml');
  const infoPlist = source(root, 'ios/Runner/Info.plist', sourceOverrides);
  for (const value of [
    '<string>ShareItToo</string>',
    '<string>shareittoo</string>',
    '<key>NSCameraUsageDescription</key>',
    '<key>NSLocationWhenInUseUsageDescription</key>',
    '<key>NSPhotoLibraryUsageDescription</key>',
    '<key>NSPhotoLibraryAddUsageDescription</key>',
    '<string>remote-notification</string>',
  ]) includes(infoPlist, value, 'ios/Runner/Info.plist');

  const entitlements = source(root, 'ios/Runner/Runner.entitlements', sourceOverrides);
  includes(entitlements, '<string>$(APS_ENVIRONMENT)</string>', 'Runner.entitlements');
  for (const domain of handoff.verifiedStaticConfiguration.associatedDomains) {
    includes(entitlements, `<string>${domain}</string>`, 'Runner.entitlements');
  }

  const project = source(root, 'ios/Runner.xcodeproj/project.pbxproj', sourceOverrides);
  if (count(project, 'PRODUCT_BUNDLE_IDENTIFIER = com.shareittoo.app;') !== 3) {
    fail('Runner Debug, Profile and Release must use the ShareItToo bundle ID.');
  }
  includes(project, 'APS_ENVIRONMENT = development;', 'Xcode project');
  if (count(project, 'APS_ENVIRONMENT = production;') !== 2) {
    fail('Profile and Release must use production APNs entitlements.');
  }
  includes(project, 'scripts/upload_ios_crashlytics_symbols.sh', 'Xcode project');

  const privacyManifest = source(root, 'ios/Runner/PrivacyInfo.xcprivacy', sourceOverrides);
  includes(privacyManifest, '<key>NSPrivacyTracking</key>\n\t<false/>', 'Runner privacy manifest');
  includes(privacyManifest, '<key>NSPrivacyTrackingDomains</key>\n\t<array/>', 'Runner privacy manifest');
  includes(privacyManifest, '<key>NSPrivacyAccessedAPITypes</key>\n\t<array/>', 'Runner privacy manifest');
  for (const type of [
    'NSPrivacyCollectedDataTypeName',
    'NSPrivacyCollectedDataTypeEmailAddress',
    'NSPrivacyCollectedDataTypePhoneNumber',
    'NSPrivacyCollectedDataTypePhysicalAddress',
    'NSPrivacyCollectedDataTypeUserID',
    'NSPrivacyCollectedDataTypeCoarseLocation',
    'NSPrivacyCollectedDataTypePreciseLocation',
    'NSPrivacyCollectedDataTypePhotosorVideos',
    'NSPrivacyCollectedDataTypeEmailsOrTextMessages',
    'NSPrivacyCollectedDataTypeOtherUserContent',
    'NSPrivacyCollectedDataTypePurchaseHistory',
    'NSPrivacyCollectedDataTypeOtherFinancialInfo',
    'NSPrivacyCollectedDataTypeDeviceID',
    'NSPrivacyCollectedDataTypeCrashData',
    'NSPrivacyCollectedDataTypeOtherDiagnosticData',
  ]) {
    if (!privacyDataType(privacyManifest, type)) fail(`Runner privacy manifest is missing ${type}.`);
  }
  if (count(project, 'PrivacyInfo.xcprivacy in Resources') !== 2 ||
      count(project, '/* PrivacyInfo.xcprivacy */') !== 3) {
    fail('Runner privacy manifest must be referenced once and bound once to Runner resources.');
  }
  same(
    handoff.verifiedStaticConfiguration.runnerPrivacyManifestPresent,
    true,
    'verifiedStaticConfiguration.runnerPrivacyManifestPresent',
  );
  same(
    handoff.verifiedStaticConfiguration.runnerPrivacyManifestTracking,
    false,
    'verifiedStaticConfiguration.runnerPrivacyManifestTracking',
  );
  same(
    handoff.verifiedStaticConfiguration.runnerPrivacyManifestBoundToTarget,
    true,
    'verifiedStaticConfiguration.runnerPrivacyManifestBoundToTarget',
  );

  const firebaseRelativePath = 'ios/Runner/GoogleService-Info.plist';
  const firebasePath = resolve(root, firebaseRelativePath);
  const firebaseOverridePresent = Object.hasOwn(sourceOverrides, firebaseRelativePath);
  const firebaseOverridden = typeof sourceOverrides[firebaseRelativePath] === 'string';
  const firebasePresent = firebaseOverridden ||
    (!firebaseOverridePresent && existsSync(firebasePath));
  const gitignore = source(root, '.gitignore', sourceOverrides);
  if (!gitignore.includes('/ios/Runner/GoogleService-Info.plist')) {
    fail('Apple Firebase configuration must remain outside version control.');
  }
  if (firebasePresent) {
    const firebase = source(root, firebaseRelativePath, sourceOverrides);
    same(plistScalar(firebase, 'BUNDLE_ID'), candidate.bundleId, 'Firebase BUNDLE_ID');
    if (!/<key>IS_ANALYTICS_ENABLED<\/key>\s*<false\s*\/>/.test(firebase) ||
        !/<key>IS_ADS_ENABLED<\/key>\s*<false\s*\/>/.test(firebase)) {
      fail('Apple Firebase Analytics and ads must remain disabled.');
    }
  }

  const accountGates = object(handoff.accountGates, 'accountGates');
  for (const key of [
    'enrollmentTypeDecision', 'appleAccountWithTwoFactor',
    'developerProgramMembership', 'latestAgreementAccepted',
  ]) same(accountGates[key], 'pending-user', `accountGates.${key}`);
  for (const key of [
    'appRecordCreated', 'bundleIdentifierRegistered', 'signingTeamAvailable',
    'apnsCredentialConfiguredInFirebase',
  ]) same(accountGates[key], false, `accountGates.${key}`);

  const tooling = object(handoff.toolingGates, 'toolingGates');
  for (const [key, value] of Object.entries(tooling)) {
    same(value, key === 'runnerPrivacyManifestValidated', `toolingGates.${key}`);
  }
  for (const [key, value] of Object.entries(object(handoff.postUploadChecks, 'postUploadChecks'))) {
    same(value, 'pending', `postUploadChecks.${key}`);
  }
  for (const [key, value] of Object.entries(object(handoff.hardStops, 'hardStops'))) {
    same(value, true, `hardStops.${key}`);
  }

  const worksheetPath = handoff.worksheetRef;
  if (typeof worksheetPath !== 'string' || !existsSync(resolve(root, worksheetPath))) {
    fail('Apple worksheet reference is unavailable.');
  }
  return { bundleId: candidate.bundleId, buildNumber: candidate.buildNumber };
}

function runCli() {
  const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
  const result = validateAppleTestFlightHandoff({ root });
  process.stdout.write(`Apple TestFlight handoff: PASS (build ${result.buildNumber}, account/tooling pending)\n`);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  try {
    runCli();
  } catch (error) {
    process.stderr.write(`${error?.message ?? 'Apple TestFlight handoff failed.'}\n`);
    process.exitCode = 1;
  }
}
