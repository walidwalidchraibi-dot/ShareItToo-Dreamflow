#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const sourcePaths = [
  'pubspec.yaml',
  'android/app/src/main/AndroidManifest.xml',
  'ios/Runner/Info.plist',
  'lib/screens/legal_privacy_screen.dart',
  'lib/screens/privacy_info_screen.dart',
  'backend/src/privacy_export.js',
  'backend/src/security.js',
  'lib/services/firebase_runtime.dart',
  'lib/openai/openai_config.dart',
  'lib/services/maps_service.dart',
];

const dataTypeIds = [
  'name',
  'emailAddress',
  'phoneNumber',
  'physicalAddress',
  'userId',
  'approximateLocation',
  'preciseLocation',
  'photos',
  'filesAndDocuments',
  'inAppMessages',
  'otherUserContent',
  'purchaseHistory',
  'paymentInfo',
  'otherFinancialInfo',
  'deviceOrOtherIds',
  'crashData',
  'otherDiagnostics',
];

const decisionKeys = [
  'googlePlayDataSafetyQuestionnaire',
  'appleAppPrivacyQuestionnaire',
  'processorSharingClassification',
  'googleMapsCredentialRestrictions',
  'retentionAndDeletionSchedule',
  'stripeFinalDataFlow',
];

const serviceKeys = [
  'firstPartyBackend',
  'firebaseCloudMessaging',
  'firebaseCrashlytics',
  'googleMapsPlatform',
  'stripe',
  'openAiHelpers',
  'analytics',
  'advertising',
];

const purposeValues = new Set([
  'accountManagement',
  'appFunctionality',
  'developerCommunications',
  'fraudPreventionSecurityCompliance',
  'personalization',
]);

const forbiddenSensitiveKeys = /^(password|secret|token|apiKey|privateKey|serviceAccount|credential|reviewAccount|email)$/i;
const emailPattern = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i;

function fail(message) {
  throw new Error(message);
}

function object(value, label) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${label} must be an object.`);
  }
  return value;
}

function nonEmptyString(value, label) {
  if (typeof value !== 'string' || value.trim() === '') fail(`${label} must be a non-empty string.`);
  return value.trim();
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function assertSha256(value, label) {
  if (typeof value !== 'string' || !/^[a-f0-9]{64}$/.test(value)) {
    fail(`${label} must be a lowercase SHA-256 value.`);
  }
}

function assertExactKeys(value, expected, label) {
  if (Object.keys(value).sort().join(',') !== expected.slice().sort().join(',')) {
    fail(`${label} must contain exactly: ${expected.join(', ')}.`);
  }
}

function assertNoSensitiveData(value, label = 'privacy disclosures') {
  if (Array.isArray(value)) {
    value.forEach((entry, index) => assertNoSensitiveData(entry, `${label}[${index}]`));
    return;
  }
  if (value === null || typeof value !== 'object') {
    if (typeof value === 'string' && emailPattern.test(value)) {
      fail(`${label} must not contain an email address.`);
    }
    return;
  }
  for (const [key, entry] of Object.entries(value)) {
    if (forbiddenSensitiveKeys.test(key)) fail(`${label}.${key} must not contain secrets or account data.`);
    assertNoSensitiveData(entry, `${label}.${key}`);
  }
}

function sourceText(root, sourceTexts, path) {
  return Object.hasOwn(sourceTexts, path)
    ? sourceTexts[path]
    : readFileSync(resolve(root, path), 'utf8');
}

function evidenceJson(root, evidenceTexts, path) {
  const raw = Object.hasOwn(evidenceTexts, path)
    ? evidenceTexts[path]
    : readFileSync(resolve(root, path), 'utf8');
  try {
    return JSON.parse(raw);
  } catch {
    fail(`${path} must contain valid JSON evidence.`);
  }
}

function assertApproval(value, label) {
  const approval = object(value, label);
  assertExactKeys(approval, ['status', 'evidenceRef'], label);
  if (!['open', 'closed'].includes(approval.status)) fail(`${label}.status must be open or closed.`);
  if (approval.status === 'open') {
    if (approval.evidenceRef !== null) fail(`${label} open must not reference evidence.`);
    return;
  }
  const ref = nonEmptyString(approval.evidenceRef, `${label}.evidenceRef`);
  if (!ref.startsWith('docs/evidence/b11/') || ref.includes('..') || !ref.endsWith('.json')) {
    fail(`${label}.evidenceRef must stay under docs/evidence/b11.`);
  }
}

function assertSourceContracts({ root, sourceTexts }) {
  const pubspec = sourceText(root, sourceTexts, 'pubspec.yaml');
  for (const dependency of ['firebase_messaging:', 'firebase_crashlytics:', 'geolocator:', 'image_picker:', 'file_picker:']) {
    if (!pubspec.includes(dependency)) fail(`pubspec.yaml is missing ${dependency}`);
  }
  for (const forbidden of ['firebase_analytics:', 'firebase_performance:', 'google_mobile_ads:']) {
    if (pubspec.includes(forbidden)) fail(`Undisclosed SDK is forbidden: ${forbidden}`);
  }

  const android = sourceText(root, sourceTexts, 'android/app/src/main/AndroidManifest.xml');
  for (const permission of [
    'android.permission.CAMERA',
    'android.permission.READ_MEDIA_IMAGES',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.POST_NOTIFICATIONS',
  ]) {
    if (!android.includes(permission)) fail(`Android disclosure inventory is missing permission ${permission}.`);
  }

  const ios = sourceText(root, sourceTexts, 'ios/Runner/Info.plist');
  for (const usage of [
    'NSPhotoLibraryUsageDescription',
    'NSCameraUsageDescription',
    'NSLocationWhenInUseUsageDescription',
    'remote-notification',
  ]) {
    if (!ios.includes(usage)) fail(`iOS disclosure inventory is missing ${usage}.`);
  }

  const exportSource = sourceText(root, sourceTexts, 'backend/src/privacy_export.js');
  for (const marker of ['pushDevices', 'listings', 'bookings', 'messages', 'uploads', 'payments', 'refunds', 'payouts', 'disputes']) {
    if (!exportSource.includes(marker)) fail(`Backend privacy export is missing ${marker}.`);
  }

  const firebase = sourceText(root, sourceTexts, 'lib/services/firebase_runtime.dart');
  for (const marker of ['FirebaseMessaging', 'FirebaseCrashlytics']) {
    if (!firebase.includes(marker)) fail(`Firebase runtime is missing ${marker}.`);
  }

  const maps = sourceText(root, sourceTexts, 'lib/services/maps_service.dart');
  if (!maps.includes("Uri.https('maps.googleapis.com'")) fail('Google Maps external service is not inventoried.');

  const ai = sourceText(root, sourceTexts, 'lib/openai/openai_config.dart');
  if (!/aiHelpersEnabled\s*=\s*false/.test(ai)) fail('OpenAI helpers must remain disabled in this candidate.');

  const legalPrivacy = sourceText(root, sourceTexts, 'lib/screens/legal_privacy_screen.dart');
  const privacyInfo = sourceText(root, sourceTexts, 'lib/screens/privacy_info_screen.dart');
  for (const [label, source] of [
    ['legal privacy notice', legalPrivacy],
    ['in-app privacy information', privacyInfo],
  ]) {
    for (const marker of [
      'genaue Standortkoordinaten',
      'Standort prüfen',
      'dauerhafte Hintergrund- oder Live‑Ortung findet nicht statt',
      'Google Maps Platform',
      'Firebase Cloud Messaging',
      'Firebase Crashlytics',
    ]) {
      if (!source.includes(marker)) fail(`The ${label} is missing the truthful disclosure marker: ${marker}.`);
    }
  }
}

export function validatePrivacyDisclosures({
  root,
  privacyManifest,
  submissionManifest,
  deviceManifest,
  sourceTexts = {},
  evidenceTexts = {},
  requireApproved = false,
}) {
  const privacy = object(privacyManifest, 'store/privacy-disclosures.json');
  const submission = object(submissionManifest, 'store/submission.json');
  const device = object(deviceManifest, 'store/device-validation.json');
  assertNoSensitiveData(privacy);

  if (privacy.schemaVersion !== 1) fail('privacy disclosure schemaVersion must be 1.');
  if (!['draft', 'approved'].includes(privacy.state)) fail('privacy disclosure state must be draft or approved.');
  if (typeof privacy.approvalAllowed !== 'boolean') fail('approvalAllowed must be boolean.');

  const candidate = object(privacy.candidate, 'candidate');
  const deviceCandidate = object(device.candidate, 'store/device-validation.json candidate');
  for (const key of ['applicationId', 'bundleId', 'versionName', 'buildNumber', 'commit']) {
    if (candidate[key] !== deviceCandidate[key]) fail(`candidate.${key} must match store/device-validation.json.`);
  }
  if (candidate.applicationId !== submission.identity?.applicationId || candidate.bundleId !== submission.identity?.bundleId) {
    fail('Privacy candidate package identity must match store/submission.json.');
  }

  if (!Array.isArray(privacy.sourceInventory) || privacy.sourceInventory.length !== sourcePaths.length) {
    fail('sourceInventory must contain every required privacy source exactly once.');
  }
  const sourceMap = new Map();
  for (const entryValue of privacy.sourceInventory) {
    const entry = object(entryValue, 'sourceInventory entry');
    assertExactKeys(entry, ['path', 'sha256'], `sourceInventory.${entry.path ?? 'unknown'}`);
    if (sourceMap.has(entry.path)) fail(`sourceInventory contains duplicate path ${entry.path}.`);
    assertSha256(entry.sha256, `sourceInventory.${entry.path}.sha256`);
    sourceMap.set(entry.path, entry.sha256);
  }
  if (sourcePaths.some((path) => !sourceMap.has(path))) fail('sourceInventory paths do not match the required contract.');
  for (const path of sourcePaths) {
    const actual = sha256(sourceText(root, sourceTexts, path));
    if (actual !== sourceMap.get(path)) fail(`sourceInventory hash is stale: ${path}.`);
  }
  assertSourceContracts({ root, sourceTexts });

  const binary = object(privacy.binaryEvidence, 'binaryEvidence');
  if (binary.candidateEvidenceRef !== 'docs/evidence/b11/android-candidate-2026081101.json') {
    fail('binaryEvidence must reference the current sanitized Android candidate evidence.');
  }
  if (binary.binaryScan !== 'passed') fail('The bound Android binary privacy scan must pass.');
  assertSha256(binary.binaryScanReportSha256, 'binaryEvidence.binaryScanReportSha256');
  const candidateEvidence = evidenceJson(root, evidenceTexts, binary.candidateEvidenceRef);
  if (candidateEvidence.candidate?.commit !== candidate.commit || candidateEvidence.candidate?.buildNumber !== candidate.buildNumber) {
    fail('Binary evidence must be bound to the same candidate.');
  }
  if (candidateEvidence.privacyAndNetwork?.binaryScan !== 'passed'
      || candidateEvidence.privacyAndNetwork?.binaryScanReportSha256 !== binary.binaryScanReportSha256) {
    fail('Binary evidence scan status and report hash must match the privacy manifest.');
  }
  if (binary.releaseCheckStatus !== device.releaseChecks?.binaryPrivacyAndNetwork?.status) {
    fail('binaryEvidence.releaseCheckStatus must match the device release check.');
  }

  const services = object(privacy.externalServices, 'externalServices');
  assertExactKeys(services, serviceKeys, 'externalServices');
  if (services.firebaseCloudMessaging?.enabled !== true || services.firebaseCrashlytics?.enabled !== true) {
    fail('Firebase Messaging and Crashlytics must remain disclosed as enabled.');
  }
  const maps = object(services.googleMapsPlatform, 'externalServices.googleMapsPlatform');
  if (maps.enabled !== true || maps.clientCredentialEmbedded !== true) {
    fail('The signed candidate must disclose its enabled Google Maps client integration.');
  }
  if (maps.applicationRestrictionVerified !== false && privacy.state === 'draft') {
    fail('The draft must not claim Google Maps credential restrictions were verified.');
  }
  if (services.stripe?.enabledInCandidate !== false || services.stripe?.configuredMode !== 'memory') {
    fail('Stripe must remain disabled in this payment-memory candidate.');
  }
  if (services.openAiHelpers?.enabledInCandidate !== false || services.openAiHelpers?.endpointEmbedded !== false) {
    fail('OpenAI helpers must remain disabled and absent from this candidate.');
  }
  if (services.analytics?.enabled !== false || services.advertising?.enabled !== false) {
    fail('Analytics and advertising must remain disabled.');
  }

  if (!Array.isArray(privacy.dataTypes) || privacy.dataTypes.length !== dataTypeIds.length) {
    fail('dataTypes must contain the complete cross-platform inventory.');
  }
  const observedIds = [];
  for (const itemValue of privacy.dataTypes) {
    const item = object(itemValue, 'dataTypes entry');
    assertExactKeys(item, ['id', 'google', 'apple', 'collected', 'optional', 'linkedToUser', 'tracking', 'purposes'], `dataTypes.${item.id ?? 'unknown'}`);
    observedIds.push(nonEmptyString(item.id, 'dataTypes.id'));
    nonEmptyString(item.google, `dataTypes.${item.id}.google`);
    nonEmptyString(item.apple, `dataTypes.${item.id}.apple`);
    for (const key of ['collected', 'optional', 'linkedToUser', 'tracking']) {
      if (typeof item[key] !== 'boolean') fail(`dataTypes.${item.id}.${key} must be boolean.`);
    }
    if (item.tracking !== false) fail(`dataTypes.${item.id} must not claim tracking.`);
    if (!Array.isArray(item.purposes) || item.purposes.length === 0
        || item.purposes.some((purpose) => !purposeValues.has(purpose))) {
      fail(`dataTypes.${item.id}.purposes contains an invalid or empty purpose list.`);
    }
  }
  if (observedIds.join(',') !== dataTypeIds.join(',')) fail('dataTypes must use the required IDs and order.');
  if (privacy.dataTypes.find((item) => item.id === 'preciseLocation')?.collected !== true) {
    fail('Fine-location and booking flows require preciseLocation disclosure.');
  }
  if (privacy.dataTypes.find((item) => item.id === 'paymentInfo')?.collected !== false) {
    fail('The payment-memory candidate must not claim collection of user payment credentials.');
  }

  const decisions = object(privacy.requiredDecisions, 'requiredDecisions');
  assertExactKeys(decisions, decisionKeys, 'requiredDecisions');
  decisionKeys.forEach((key) => assertApproval(decisions[key], `requiredDecisions.${key}`));

  const forms = object(privacy.platformForms, 'platformForms');
  assertExactKeys(forms, ['googlePlay', 'apple'], 'platformForms');
  for (const platform of ['googlePlay', 'apple']) {
    const form = object(forms[platform], `platformForms.${platform}`);
    assertExactKeys(form, ['status', 'evidenceRef'], `platformForms.${platform}`);
    if (!['draft', 'verified'].includes(form.status)) fail(`platformForms.${platform}.status must be draft or verified.`);
    if (form.status === 'draft' && form.evidenceRef !== null) fail(`platformForms.${platform} draft must not reference evidence.`);
    if (form.status === 'verified') assertApproval({ status: 'closed', evidenceRef: form.evidenceRef }, `platformForms.${platform}`);
  }

  const storeGate = object(privacy.storeGate, 'storeGate');
  if (storeGate.field !== 'blockingGates.finalBinaryPrivacyScan') {
    fail('storeGate.field must reference blockingGates.finalBinaryPrivacyScan.');
  }
  if (storeGate.status !== submission.blockingGates?.finalBinaryPrivacyScan) {
    fail('Privacy store gate must match store/submission.json.');
  }

  const boundaries = object(privacy.boundaries, 'boundaries');
  for (const key of ['legalApproval', 'storeSubmissionChanged', 'publicRoutesChanged', 'productionChanged', 'containsSecrets', 'containsAccountData']) {
    if (boundaries[key] !== false) fail(`boundaries.${key} must be false.`);
  }

  const allDecisionsClosed = decisionKeys.every((key) => decisions[key].status === 'closed');
  const allDecisionsOpen = decisionKeys.every((key) => decisions[key].status === 'open');
  const formsVerified = ['googlePlay', 'apple'].every((platform) => forms[platform].status === 'verified');
  const approved = privacy.state === 'approved'
    && privacy.approvalAllowed === true
    && allDecisionsClosed
    && formsVerified
    && maps.applicationRestrictionVerified === true
    && binary.releaseCheckStatus === 'passed'
    && storeGate.status === 'closed';

  if (privacy.state === 'draft') {
    if (privacy.approvalAllowed !== false || !allDecisionsOpen || formsVerified || storeGate.status !== 'open') {
      fail('Draft privacy disclosures must remain fail closed with every owner decision and Store gate open.');
    }
  } else if (!approved) {
    fail('Approved privacy disclosures are internally incomplete.');
  }
  if (requireApproved && !approved) fail('Approved privacy disclosures are required, but the manifest remains draft.');

  return {
    state: privacy.state,
    approvalAllowed: privacy.approvalAllowed,
    dataTypeCount: privacy.dataTypes.length,
    externalServiceCount: serviceKeys.length,
    storeGate: storeGate.status,
    binaryReleaseCheck: binary.releaseCheckStatus,
  };
}

function main() {
  const args = process.argv.slice(2);
  if (args.some((arg) => arg !== '--require-approved')) fail(`Unknown argument: ${args.find((arg) => arg !== '--require-approved')}`);
  const root = fileURLToPath(new URL('../', import.meta.url));
  const result = validatePrivacyDisclosures({
    root,
    privacyManifest: JSON.parse(readFileSync(resolve(root, 'store/privacy-disclosures.json'), 'utf8')),
    submissionManifest: JSON.parse(readFileSync(resolve(root, 'store/submission.json'), 'utf8')),
    deviceManifest: JSON.parse(readFileSync(resolve(root, 'store/device-validation.json'), 'utf8')),
    requireApproved: args.includes('--require-approved'),
  });
  console.log(
    `Privacy disclosures valid: state=${result.state}, approvalAllowed=${result.approvalAllowed}, `
    + `dataTypes=${result.dataTypeCount}, services=${result.externalServiceCount}, `
    + `binaryReleaseCheck=${result.binaryReleaseCheck}, finalBinaryPrivacyScan=${result.storeGate}.`,
  );
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
