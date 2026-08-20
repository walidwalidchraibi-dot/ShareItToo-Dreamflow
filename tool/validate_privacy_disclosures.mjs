#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const sourcePaths = [
  'pubspec.yaml',
  'android/app/src/main/AndroidManifest.xml',
  'ios/Runner/Info.plist',
  'ios/Runner/PrivacyInfo.xcprivacy',
  'lib/screens/legal_privacy_screen.dart',
  'assets/legal/de/privacy_v5.html',
  'assets/legal/de/legal_manifest_v5.json',
  'lib/screens/privacy_info_screen.dart',
  'backend/src/account_actions.js',
  'backend/src/privacy_export.js',
  'backend/src/booking_workflow.js',
  'backend/src/private_pilot_domain.js',
  'backend/src/v51_contract_workflow.js',
  'backend/src/v51_contract_receipt.js',
  'backend/src/v52_contract_workflow.js',
  'backend/src/v51_termination_domain.js',
  'backend/src/v51_withdrawal_workflow.js',
  'backend/src/v52_actual_loss_workflow.js',
  'backend/sql/migrations/015_v51_contract_persistence.up.sql',
  'backend/sql/migrations/016_v51_booking_quotes.up.sql',
  'backend/sql/migrations/017_v51_contract_receipts.up.sql',
  'backend/sql/migrations/018_v51_withdrawal_and_refund_obligations.up.sql',
  'backend/sql/migrations/019_v51_condition_evidence.up.sql',
  'backend/sql/migrations/023_v52_contract_binding.up.sql',
  'backend/sql/migrations/024_v52_actual_loss_resolution.up.sql',
  'backend/sql/migrations/025_v52_handover_return_evidence.up.sql',
  'backend/src/booking_condition_evidence_workflow.js',
  'backend/src/booking_confirmation_workflow.js',
  'backend/src/message_workflow.js',
  'backend/src/v52_handover_return_workflow.js',
  'backend/src/retention_inventory.js',
  'backend/src/financial_documents.js',
  'backend/sql/migrations/020_v51_financial_documents.up.sql',
  'backend/src/security.js',
  'backend/src/maps_proxy.js',
  'backend/src/config.js',
  'backend/src/notifications.js',
  'backend/src/transactional_mail_templates.js',
  'backend/src/return_lifecycle_workflow.js',
  'backend/src/firebase_phone_verification.js',
  'backend/src/firebase_social_auth.js',
  'backend/src/firebase_identity_cleanup.js',
  'backend/src/crashlytics_cleanup.js',
  'backend/sql/migrations/021_firebase_identity_deletion_outbox.up.sql',
  'backend/sql/migrations/022_crashlytics_subject_deletion.up.sql',
  'backend/sql/migrations/010_phone_verification.up.sql',
  'lib/services/backend_config.dart',
  'lib/services/firebase_runtime.dart',
  'lib/services/firebase_service_preferences.dart',
  'lib/widgets/app_image.dart',
  'lib/services/data_service.dart',
  'lib/services/backend_repository.dart',
  'lib/config/private_pilot_config.dart',
  'lib/models/rental_request.dart',
  'lib/screens/private_pilot_checkout_screen.dart',
  'lib/screens/v52_legal_document_screen.dart',
  'lib/screens/bookings_screen.dart',
  'lib/screens/payment_methods_screen.dart',
  'lib/screens/stripe_payout_account_screen.dart',
  'lib/screens/payment_checkout_screen.dart',
  'lib/models/invoice.dart',
  'lib/services/invoices_service.dart',
  'lib/services/invoice_pdf_service.dart',
  'lib/screens/invoices_screen.dart',
  'lib/screens/invoice_detail_screen.dart',
  'lib/screens/booking_detail_screen.dart',
  'lib/screens/ongoing_owner_detail_screen.dart',
  'lib/screens/platform_withdrawal_screen.dart',
  'lib/services/account_deletion_service.dart',
  'lib/services/auth_service.dart',
  'lib/screens/notification_settings_screen.dart',
  'lib/screens/contact_data_screen.dart',
  'lib/openai/openai_config.dart',
  'lib/services/maps_service.dart',
  'backend/src/app.js',
  'tool/run_staging_synthetic_booking.mjs',
  'lib/screens/create_listing_screen.dart',
  'lib/screens/message_thread_screen.dart',
  'lib/widgets/return_handover_stepper_sheet.dart',
  'lib/screens/report_issue_screen.dart',
  'lib/screens/report_user_screen.dart',
  'store/phone-verification-readiness.json',
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
  'inAppMessages',
  'otherUserContent',
  'purchaseHistory',
  'paymentInfo',
  'otherFinancialInfo',
  'deviceOrOtherIds',
  'crashData',
  'otherDiagnostics',
  'appInteractions',
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
  'firebaseAuthentication',
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
  'analytics',
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
  for (const dependency of [
    'firebase_messaging:',
    'firebase_crashlytics:',
    'firebase_app_installations:',
    'firebase_auth:',
    'google_sign_in:',
    'flutter_facebook_auth:',
    'geolocator:',
    'image_picker:',
    'file_picker:',
  ]) {
    if (!pubspec.includes(dependency)) fail(`pubspec.yaml is missing ${dependency}`);
  }
  for (const forbidden of ['firebase_analytics:', 'firebase_performance:', 'google_mobile_ads:']) {
    if (pubspec.includes(forbidden)) fail(`Undisclosed SDK is forbidden: ${forbidden}`);
  }

  const android = sourceText(root, sourceTexts, 'android/app/src/main/AndroidManifest.xml');
  for (const permission of [
    'android.permission.CAMERA',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.POST_NOTIFICATIONS',
  ]) {
    if (!android.includes(permission)) fail(`Android disclosure inventory is missing permission ${permission}.`);
  }
  for (const broadMediaPermission of [
    'android.permission.READ_MEDIA_IMAGES',
    'android.permission.READ_MEDIA_VIDEO',
  ]) {
    if (android.includes(broadMediaPermission)) {
      fail(`Android must use the system photo picker instead of broad media permission ${broadMediaPermission}.`);
    }
  }
  for (const marker of [
    'firebase_messaging_auto_init_enabled',
    'firebase_analytics_collection_enabled',
    'firebase_crashlytics_collection_enabled',
  ]) {
    if (!new RegExp(`${marker}[\\s\\S]{0,120}android:value="false"`).test(android)) {
      fail(`Android Firebase opt-in default is missing ${marker}=false.`);
    }
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
  for (const marker of [
    'FirebaseMessagingAutoInitEnabled',
    'FirebaseCrashlyticsCollectionEnabled',
  ]) {
    if (!new RegExp(`<key>${marker}<\\/key>\\s*<false\\/>`).test(ios)) {
      fail(`iOS Firebase opt-in default is missing ${marker}=false.`);
    }
  }

  const applePrivacy = sourceText(root, sourceTexts, 'ios/Runner/PrivacyInfo.xcprivacy');
  for (const marker of [
    'NSPrivacyCollectedDataTypeDeviceID',
    'NSPrivacyCollectedDataTypeCrashData',
    'NSPrivacyCollectedDataTypeOtherDiagnosticData',
    'NSPrivacyCollectedDataTypeProductInteraction',
    'NSPrivacyCollectedDataTypePurposeAnalytics',
  ]) {
    if (!applePrivacy.includes(marker)) fail(`Apple privacy manifest is missing ${marker}.`);
  }

  const exportSource = sourceText(root, sourceTexts, 'backend/src/privacy_export.js');
  for (const marker of [
    'pushDevices', 'listings', 'bookings', 'messages', 'uploads',
    'payments', 'refunds', 'payouts', 'financialDocuments',
    'financialDocumentEvents', 'disputes',
  ]) {
    if (!exportSource.includes(marker)) fail(`Backend privacy export is missing ${marker}.`);
  }

  const financialDocuments = sourceText(root, sourceTexts, 'backend/src/financial_documents.js');
  for (const marker of [
    'booking_payment_receipt',
    'sit_fee_receipt',
    'owner_payout_statement',
    'refund_receipt',
    'financial_document_live_issuance_not_approved',
    'private_rent_no_sit_vat',
    'observedHash !== row.artifact_sha256',
  ]) {
    if (!financialDocuments.includes(marker)) {
      fail(`Immutable financial documents are missing ${marker}.`);
    }
  }
  const financialMigration = sourceText(
    root,
    sourceTexts,
    'backend/sql/migrations/020_v51_financial_documents.up.sql',
  );
  for (const marker of [
    'CREATE TABLE IF NOT EXISTS financial_documents',
    'CREATE TABLE IF NOT EXISTS financial_document_events',
    'financial_documents_append_only',
    'financial_document_events_append_only',
  ]) {
    if (!financialMigration.includes(marker)) {
      fail(`Financial-document persistence is missing ${marker}.`);
    }
  }
  const invoiceService = sourceText(root, sourceTexts, 'lib/services/invoices_service.dart');
  if (!invoiceService.includes('BackendRepository.getFinancialDocuments()')
      || invoiceService.includes('quoteForItem')
      || invoiceService.includes('platformFeeMinor(')) {
    fail('Release financial documents must come from server snapshots without client repricing.');
  }

  const firebase = sourceText(root, sourceTexts, 'lib/services/firebase_runtime.dart');
  for (const marker of [
    'FirebaseMessaging',
    'FirebaseCrashlytics',
    'FirebaseInstallations.instance.delete()',
    'FirebaseServicePreferencesStore.read()',
  ]) {
    if (!firebase.includes(marker)) fail(`Firebase runtime is missing ${marker}.`);
  }
  const auth = sourceText(root, sourceTexts, 'lib/services/auth_service.dart');
  for (const marker of [
    'GoogleAuthProvider',
    'AppleAuthProvider',
    'FacebookAuthProvider',
    "path: '/auth/social'",
  ]) {
    if (!auth.includes(marker)) fail(`Social authentication is missing ${marker}.`);
  }
  for (const marker of [
    'FirebaseAuth.instance.verifyPhoneNumber(',
    "path: '/auth/phone-verification/status'",
    "path: '/auth/phone-verification/confirm'",
  ]) {
    if (!auth.includes(marker)) fail(`Phone authentication is missing ${marker}.`);
  }
  const phoneConfig = sourceText(root, sourceTexts, 'backend/src/config.js');
  if (!phoneConfig.includes("process.env.FIREBASE_PHONE_VERIFICATION_ENABLED ?? 'false'")) {
    fail('Phone authentication must remain separately disabled by default.');
  }
  const phoneVerifier = sourceText(root, sourceTexts, 'backend/src/firebase_phone_verification.js');
  for (const marker of ["sign_in_provider, 40) !== 'phone'", 'await verify(token, true)']) {
    if (!phoneVerifier.includes(marker)) fail(`Phone token verification is missing ${marker}.`);
  }
  if (!phoneVerifier.includes("providers[0]?.providerId !== 'phone'")
      || !phoneVerifier.includes('await remove(firebaseUserId)')) {
    fail('Temporary Firebase phone identities must be removed after ownership proof.');
  }
  const firebaseIdentityCleanup = sourceText(
    root,
    sourceTexts,
    'backend/src/firebase_identity_cleanup.js',
  );
  const firebaseIdentityMigration = sourceText(
    root,
    sourceTexts,
    'backend/sql/migrations/021_firebase_identity_deletion_outbox.up.sql',
  );
  for (const marker of [
    'enqueueFirebaseIdentityDeletions',
    'drainFirebaseIdentityDeletionOutbox',
    'FOR UPDATE SKIP LOCKED',
    "userNotFoundCodes.has(code)",
    "SET status = 'retry'",
  ]) {
    if (!firebaseIdentityCleanup.includes(marker)) {
      fail(`Persistent Firebase identity deletion is missing ${marker}.`);
    }
  }
  if (!firebaseIdentityMigration.includes(
    'CREATE TABLE IF NOT EXISTS firebase_identity_deletion_outbox',
  ) || !firebaseIdentityMigration.includes(
    "provider IN ('google', 'apple', 'facebook')",
  )) {
    fail('Persistent Firebase identity deletion requires its bounded durable outbox.');
  }
  const phoneMigration = sourceText(
    root,
    sourceTexts,
    'backend/sql/migrations/010_phone_verification.up.sql',
  );
  if (!phoneMigration.includes('users_verified_phone_unique_idx')) {
    fail('Verified phone numbers must remain unique at the database layer.');
  }
  const phoneConsent = sourceText(root, sourceTexts, 'lib/screens/contact_data_screen.dart');
  for (const marker of ['Firebase Authentication (Google)', 'ShareItToo speichert keinen SMS-Code']) {
    if (!phoneConsent.includes(marker)) fail(`Phone verification consent is missing ${marker}.`);
  }
  const phoneReadiness = JSON.parse(sourceText(
    root,
    sourceTexts,
    'store/phone-verification-readiness.json',
  ));
  const phoneReadinessStates = new Map([
    ['implementation-complete-external-gates-open', {
      activationAllowed: false,
      privacy: 'pending-successor-candidate-reclassification',
    }],
    ['firebase-console-activated-staging-test-pending', {
      activationAllowed: false,
      privacy: 'successor-candidate-copy-updated-play-form-pending',
    }],
    ['android-real-device-sms-passed', {
      activationAllowed: true,
      privacy: 'successor-candidate-copy-updated-play-form-pending',
    }],
  ]);
  const expectedPhoneReadiness = phoneReadinessStates.get(phoneReadiness.state);
  if (!expectedPhoneReadiness
      || phoneReadiness.activationAllowed !== expectedPhoneReadiness.activationAllowed
      || phoneReadiness.storeSubmissionAllowed !== false
      || phoneReadiness.externalGates?.privacyAndProviderClassification !==
        expectedPhoneReadiness.privacy) {
    fail('Phone verification privacy and activation gates must remain open.');
  }

  const maps = sourceText(root, sourceTexts, 'lib/services/maps_service.dart');
  const mapsProxy = sourceText(root, sourceTexts, 'backend/src/maps_proxy.js');
  if (!maps.includes('BackendRepository.autocompleteAddresses')
      || !mapsProxy.includes("const GOOGLE_PLACES_ORIGIN = 'https://maps.googleapis.com'")) {
    fail('Google Maps must be inventoried through the authenticated backend proxy.');
  }
  for (const directClientMarker of ['maps.googleapis.com', 'GOOGLE_MAPS_API_KEY']) {
    if (maps.includes(directClientMarker)) fail(`Google Maps client integration is forbidden: ${directClientMarker}`);
  }

  const ai = sourceText(root, sourceTexts, 'lib/openai/openai_config.dart');
  if (!/aiHelpersEnabled\s*=\s*false/.test(ai)) fail('OpenAI helpers must remain disabled in this candidate.');

  const backendApp = sourceText(root, sourceTexts, 'backend/src/app.js');
  for (const marker of [
    "new Set(['image/jpeg', 'image/png', 'image/webp'])",
    "throw new HttpError(415, 'unsupported_image_type')",
  ]) {
    if (!backendApp.includes(marker)) fail(`Backend image-only upload boundary is missing ${marker}.`);
  }
  const listingUpload = sourceText(root, sourceTexts, 'lib/screens/create_listing_screen.dart');
  const chatUpload = sourceText(root, sourceTexts, 'lib/screens/message_thread_screen.dart');
  const handoverUpload = sourceText(root, sourceTexts, 'lib/widgets/return_handover_stepper_sheet.dart');
  const reportUpload = sourceText(root, sourceTexts, 'lib/screens/report_user_screen.dart');
  if (!listingUpload.includes('type: FileType.image')
      || !chatUpload.includes("allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp']")
      || !handoverUpload.includes('type: FileType.image')
      || !reportUpload.includes('ImagePicker().pickImage')) {
    fail('All launch upload surfaces must remain image-only.');
  }

  const legalPrivacy = sourceText(root, sourceTexts, 'lib/screens/legal_privacy_screen.dart');
  const v51Privacy = sourceText(root, sourceTexts, 'assets/legal/de/privacy_v5.html');
  const v51LegalManifest = JSON.parse(sourceText(
    root,
    sourceTexts,
    'assets/legal/de/legal_manifest_v5.json',
  ));
  if (v51LegalManifest.status !== 'draft-blocked'
      || v51LegalManifest.activationAllowed !== false
      || v51LegalManifest.productDecisions?.firebaseCloudMessaging?.decision !== 'retained'
      || v51LegalManifest.productDecisions?.firebaseCloudMessaging
        ?.requiresSeparateVoluntaryOptIn !== true
      || v51LegalManifest.productDecisions?.firebaseCrashlytics?.decision !== 'retained'
      || v51LegalManifest.productDecisions?.firebaseCrashlytics
        ?.requiresSeparateVoluntaryOptIn !== true
      || !v51LegalManifest.knownConflicts?.some(
        (entry) => entry?.id === 'firebase-push-crash-retained-after-v51-source'
          && entry?.status === 'source-superseded-activation-blocked'
          && entry?.successorDecisionDate === '2026-08-17'
          && entry?.successorDecisionPath === 'assets/legal/de/privacy_v5.html',
      )) {
    fail('The V5.1 legal bundle must preserve retained, independently opted-in Push and Crashlytics while keeping activation blocked.');
  }
  for (const marker of [
    'Externe Push-Benachrichtigungen sind im Startbetrieb nicht aktiviert.',
    'Im Startbetrieb sind keine externen Crashanalyse-',
    'data-successor-decision="2026-08-17"',
    'data-supersedes-source-page="38"',
    'Die Aktivierung von Push aktiviert Crashlytics nicht.',
    'Der Nachtrag ist keine Live- oder Datenschutzfreigabe.',
  ]) {
    if (!v51Privacy.includes(marker)) {
      fail(`The source-bound V5.1 privacy draft is missing its source or successor marker: ${marker}`);
    }
  }
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
      'Firebase Authentication',
      'freigegebenen externen Anbieter',
      'technische Installationskennung',
      'App-Sitzungsdaten',
      'keine Ausweisprüfung',
      'SMS-Verifizierung',
      'Firebase-Authentifizierungsidentität',
    ]) {
      if (!source.includes(marker)) fail(`The ${label} is missing the truthful disclosure marker: ${marker}.`);
    }
  }

  const publicPrivacy = sourceText(root, sourceTexts, 'backend/src/account_actions.js');
  for (const marker of [
    'Google Maps Platform',
    'Firebase Cloud Messaging',
    'Firebase Crashlytics',
    'Anmeldung mit Google, Apple oder Facebook',
    'dauerhaft zur Anbieterlöschung vorgemerkt',
    'bis zu 180 Tagen',
    '90 Tage',
    'keine dauerhafte Hintergrund- oder Live-Ortung',
    'keine aktivierte Echtgeld-Zahlungsübertragung an Stripe',
    'https://shareittoo.com/account-deletion',
  ]) {
    if (!publicPrivacy.includes(marker)) {
      fail(`Public privacy draft is missing the evidenced disclosure marker: ${marker}.`);
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
  const superseded = candidate.status === 'superseded';
  if (superseded && !/^\d{10}$/.test(candidate.replacementBuildNumber ?? '')) {
    fail('A superseded candidate must name its replacement build number.');
  }
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
  const expectedCandidateEvidenceRef = `docs/evidence/b11/android-candidate-${candidate.buildNumber}.json`;
  if (binary.candidateEvidenceRef !== expectedCandidateEvidenceRef) {
    fail('binaryEvidence must reference the current sanitized Android candidate evidence.');
  }
  if (!superseded && binary.binaryScan !== 'passed') fail('The bound Android binary privacy scan must pass.');
  assertSha256(binary.binaryScanReportSha256, 'binaryEvidence.binaryScanReportSha256');
  const candidateEvidence = evidenceJson(root, evidenceTexts, binary.candidateEvidenceRef);
  if (candidateEvidence.candidate?.commit !== candidate.commit || candidateEvidence.candidate?.buildNumber !== candidate.buildNumber) {
    fail('Binary evidence must be bound to the same candidate.');
  }
  if (superseded) {
    if (binary.binaryScan !== 'failed-extended-runtime-origin-scan'
        || binary.releaseCheckStatus !== 'blocked-replacement-pending') {
      fail('A superseded candidate must remain blocked by the extended privacy rescan.');
    }
    const supersessionRef = nonEmptyString(
      binary.supersessionEvidenceRef,
      'binaryEvidence.supersessionEvidenceRef',
    );
    if (supersessionRef !== `docs/evidence/b11/android-candidate-${candidate.buildNumber}-superseded-privacy-rescan-20260812.json`) {
      fail('Supersession evidence must bind the exact old candidate.');
    }
    const supersessionEvidence = evidenceJson(root, evidenceTexts, supersessionRef);
    if (supersessionEvidence.status !== 'superseded-privacy-rescan-failed'
        || supersessionEvidence.extendedPrivacyRescan?.status !== 'failed'
        || supersessionEvidence.remediation?.replacementBuildNumber !== candidate.replacementBuildNumber
        || supersessionEvidence.boundaries?.uploadedToStore !== false
        || supersessionEvidence.boundaries?.submissionAllowed !== false) {
      fail('Supersession evidence is incomplete or no longer fail closed.');
    }
  } else {
    if (candidateEvidence.privacyAndNetwork?.binaryScan !== 'passed'
        || candidateEvidence.privacyAndNetwork?.binaryScanReportSha256 !== binary.binaryScanReportSha256) {
      fail('Binary evidence scan status and report hash must match the privacy manifest.');
    }
    if (binary.releaseCheckStatus !== device.releaseChecks?.binaryPrivacyAndNetwork?.status) {
      fail('binaryEvidence.releaseCheckStatus must match the device release check.');
    }
  }

  const services = object(privacy.externalServices, 'externalServices');
  assertExactKeys(services, serviceKeys, 'externalServices');
  if (services.firebaseCloudMessaging?.enabled !== true || services.firebaseCrashlytics?.enabled !== true) {
    fail('Firebase Messaging and Crashlytics must remain disclosed as enabled.');
  }
  for (const serviceKey of ['firebaseCloudMessaging', 'firebaseCrashlytics']) {
    const service = object(services[serviceKey], `externalServices.${serviceKey}`);
    if (service.candidateCollectionMode !== 'automatic-in-bound-candidate'
        || service.nextCandidateCollectionMode !== 'user-opt-in-default-off'
        || service.replacementCandidateRequired !== true) {
      fail(`${serviceKey} must separate the automatic bound candidate from the opt-in replacement source.`);
    }
  }
  const crashlytics = object(
    services.firebaseCrashlytics,
    'externalServices.firebaseCrashlytics',
  );
  if (crashlytics.serverDeletionQueueFoundationImplemented !== true
      || crashlytics.pseudonymousSubjectTransmissionImplemented !== false
      || crashlytics.providerDeletionExecutionEnabled !== false) {
    fail('Crashlytics deletion foundation must remain default-off until pseudonymous subject transfer is approved.');
  }
  const socialAuth = object(services.firebaseAuthentication, 'externalServices.firebaseAuthentication');
  if (socialAuth.enabled !== true
      || socialAuth.enabledInBoundEnvironment !== true
      || socialAuth.role !==
        'processor-for-firebase-authentication-phone-active-social-provider-review-if-enabled'
      || socialAuth.socialProvidersActivated !== false
      || socialAuth.persistentIdentityDeletionImplemented !== true
      || !Array.isArray(socialAuth.providers)
      || socialAuth.providers.join(',') !== 'google,apple,facebook,phone'
      || !Array.isArray(socialAuth.dataTypes)
      || !socialAuth.dataTypes.includes('phoneNumber')) {
    fail('Firebase Authentication must disclose Google, Apple, Facebook, and phone verification.');
  }
  const maps = object(services.googleMapsPlatform, 'externalServices.googleMapsPlatform');
  if (maps.enabled !== true) {
    fail('The candidate must disclose its Google Maps integration.');
  }
  if (maps.activeTransferProven !== false
      || maps.role !== 'independent-controller-if-activated') {
    fail('Google Maps must remain an unproven independent-controller transfer until activation.');
  }
  if (!superseded && (maps.clientCredentialEmbedded !== false || maps.serverProxied !== true)) {
    fail('The signed candidate must disclose the server-proxied Google Maps integration without a client credential.');
  }
  if (superseded && maps.clientCredentialEmbedded !== true) {
    fail('The superseded candidate must retain its truthful embedded Maps credential disclosure.');
  }
  if (maps.serverCredentialRestrictionVerified !== false && privacy.state === 'draft') {
    fail('The draft must not claim Google Maps server credential restrictions were verified.');
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
  const deviceId = privacy.dataTypes.find((item) => item.id === 'deviceOrOtherIds');
  if (deviceId?.collected !== true || deviceId.optional !== false) {
    fail('The automatic bound candidate requires non-optional device or installation ID disclosure.');
  }
  const interactions = privacy.dataTypes.find((item) => item.id === 'appInteractions');
  if (interactions?.collected !== true || interactions.optional !== false
      || interactions.linkedToUser !== false || !interactions.purposes.includes('analytics')) {
    fail('The automatic bound candidate requires non-optional, non-linked app interaction disclosure for analytics.');
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
    && maps.serverCredentialRestrictionVerified === true
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
