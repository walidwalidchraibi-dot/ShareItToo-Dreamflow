#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const sourcePaths = [
  'backend/src/app.js',
  'backend/src/server.js',
  'backend/src/credential_cleanup.js',
  'backend/src/moderation_workflow.js',
  'backend/src/moderation_domain.js',
  'backend/src/moderation_decision_workflow.js',
  'backend/src/compliance_review.js',
  'backend/src/operator_readiness.js',
  'backend/src/retention_inventory.js',
  'backend/src/privacy_export.js',
  'backend/src/support_case_domain.js',
  'backend/src/support_case_workflow.js',
  'backend/src/support_appeal_domain.js',
  'backend/src/support_appeal_workflow.js',
  'backend/src/support_decision_domain.js',
  'backend/src/support_decision_workflow.js',
  'backend/src/support_break_glass_domain.js',
  'backend/src/support_break_glass_workflow.js',
  'backend/src/support_message_domain.js',
  'backend/src/support_message_workflow.js',
  'backend/src/support_message_templates_v1.json',
  'backend/src/support_deadline_watchdog.js',
  'backend/src/rental_cart_workflow.js',
  'backend/src/planner_inventory_workflow.js',
  'backend/src/listing_supply_enrichment.js',
  'backend/src/listing_set_workflow.js',
  'backend/src/account_actions.js',
  'backend/src/config.js',
  'backend/src/notifications.js',
  'backend/src/push_sender.js',
  'backend/src/transactional_mail_templates.js',
  'backend/src/return_lifecycle_workflow.js',
  'backend/src/v51_contract_workflow.js',
  'backend/src/v51_contract_receipt.js',
  'backend/src/v51_withdrawal_workflow.js',
  'backend/src/booking_workflow.js',
  'backend/src/v51_termination_domain.js',
  'backend/src/v52_actual_loss_workflow.js',
  'backend/src/v52_handover_return_workflow.js',
  'backend/src/booking_condition_evidence_workflow.js',
  'backend/src/financial_documents.js',
  'backend/src/firebase_social_auth.js',
  'backend/src/firebase_phone_verification.js',
  'backend/src/firebase_identity_cleanup.js',
  'backend/src/crashlytics_cleanup.js',
  'backend/src/maps_proxy.js',
  'backend/src/google_maps_activation.js',
  'backend/sql/schema.sql',
  'backend/sql/migrations/006_b7_communications.up.sql',
  'backend/sql/migrations/014_account_legal_holds.up.sql',
  'backend/sql/migrations/015_v51_contract_persistence.up.sql',
  'backend/sql/migrations/016_v51_booking_quotes.up.sql',
  'backend/sql/migrations/017_v51_contract_receipts.up.sql',
  'backend/sql/migrations/018_v51_withdrawal_and_refund_obligations.up.sql',
  'backend/sql/migrations/019_v51_condition_evidence.up.sql',
  'backend/sql/migrations/020_v51_financial_documents.up.sql',
  'backend/sql/migrations/021_firebase_identity_deletion_outbox.up.sql',
  'backend/sql/migrations/022_crashlytics_subject_deletion.up.sql',
  'backend/sql/migrations/024_v52_actual_loss_resolution.up.sql',
  'backend/sql/migrations/025_v52_handover_return_evidence.up.sql',
  'backend/sql/migrations/026_v52_categories_moderation_operator.up.sql',
  'backend/sql/migrations/027_g2_persistent_rental_cart.up.sql',
  'backend/sql/migrations/031_g5b_listing_sets.up.sql',
  'backend/sql/migrations/032_support_case_foundation.up.sql',
  'backend/sql/migrations/033_support_decision_approval_guard.up.sql',
  'backend/sql/migrations/034_support_user_action_deadline.up.sql',
  'backend/sql/migrations/035_support_final_decision_publication.up.sql',
  'backend/sql/migrations/036_support_closed_case_appeal_submission.up.sql',
  'backend/sql/migrations/037_support_break_glass_access.up.sql',
  'backend/sql/migrations/038_support_message_template_guard.up.sql',
  'backend/sql/migrations/039_support_deadline_watchdog.up.sql',
  'backend/sql/migrations/040_support_single_issue_intake.up.sql',
  'backend/ops/backup.sh',
  'android/app/src/main/AndroidManifest.xml',
  'ios/Runner/Info.plist',
  'lib/services/firebase_runtime.dart',
  'lib/services/firebase_service_preferences.dart',
  'lib/services/app_link_service.dart',
  'lib/screens/app_link_destination_screen.dart',
  'android/app/src/main/kotlin/com/shareittoo/app/MainActivity.kt',
  'lib/services/account_deletion_service.dart',
  'lib/services/data_service.dart',
  'lib/services/maps_service.dart',
  'lib/services/backend_repository.dart',
  'lib/screens/support_cases_screen.dart',
  'lib/config/supply_enrichment_technical_config.dart',
  'lib/models/supply_enrichment.dart',
  'lib/screens/create_listing_screen.dart',
  'lib/screens/explore_screen.dart',
  'lib/widgets/supply_enrichment_dialog.dart',
  'lib/config/listing_sets_technical_config.dart',
  'lib/models/listing_set.dart',
  'lib/models/rental_cart.dart',
  'lib/screens/payment_methods_screen.dart',
  'lib/screens/stripe_payout_account_screen.dart',
  'lib/screens/payment_checkout_screen.dart',
  'lib/screens/legal_privacy_screen.dart',
  'lib/screens/privacy_info_screen.dart',
  'store/g2-data-lifecycle.json',
];

const decisionKeys = [
  'inactiveAccountPeriod',
  'transactionalRecordPeriod',
  'communicationPeriod',
  'moderationEvidencePeriod',
  'auditSecurityLogPeriod',
  'expiredCredentialPurgePeriod',
  'backupErasureWindow',
  'externalProcessorRetention',
  'legalHoldProcess',
];

const externalProcessorKeys = [
  'firebaseCloudMessaging',
  'firebaseCrashlytics',
  'firebaseAuthentication',
  'googleMapsPlatform',
];

const providerEvidencePath = 'docs/evidence/b11/privacy-provider-retention-sources-20260812.json';
const firebaseServiceReadinessPaths = {
  firebaseCloudMessaging:
    'docs/evidence/b11/firebase-cloud-messaging-retention-deletion-readiness-20260817.json',
  firebaseCrashlytics:
    'docs/evidence/b11/firebase-crashlytics-retention-deletion-readiness-20260817.json',
  firebaseAuthentication:
    'docs/evidence/b11/firebase-authentication-retention-deletion-readiness-20260817.json',
  googleMapsPlatform:
    'docs/evidence/b11/google-maps-platform-retention-deletion-readiness-20260817.json',
};
const credentialCleanupEvidencePath = 'docs/evidence/b11/expired-credential-cleanup-20260815.json';
const legalHoldEvidencePath = 'docs/evidence/b11/account-legal-hold-20260815.json';
const retentionInventoryEvidencePath = 'docs/evidence/b11/retention-inventory-20260815.json';
const retentionExecutionPreflightEvidencePath =
  'docs/evidence/b11/v51-retention-execution-preflight-20260817T130000Z.json';
const decisionPreparationEvidencePath =
  'docs/evidence/b11/retention-deletion-decision-preparation-20260817.json';
const decisionPreparationMatrixPath =
  'docs/compliance/retention-deletion-decision-matrix.md';

const requiredOfficialSources = [
  ['Firebase Cloud Messaging', 'https://firebase.google.com/support/privacy/', 'within 180 days'],
  ['Firebase Crashlytics', 'https://firebase.google.com/support/privacy/', 'retained for 90 days'],
  ['Firebase Authentication', 'https://firebase.google.com/support/privacy/', 'removed from live and backup systems within 180 days'],
  ['Firebase Authentication Admin SDK', 'https://firebase.google.com/docs/auth/admin/manage-users', 'deleting a user by UID'],
  ['Google Maps Platform', 'https://developers.google.com/maps/security/compliance/security-compliance', 'no single fixed retention period'],
  ['Google Play', 'https://support.google.com/googleplay/android-developer/answer/10787469?hl=en', 'Data safety form'],
  ['Google Play', 'https://support.google.com/googleplay/android-developer/answer/13327111?hl=en', 'public web resource'],
];

function fail(message) {
  throw new Error(message);
}

function object(value, label) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) fail(`${label} must be an object.`);
  return value;
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function text(root, sourceTexts, path) {
  return Object.hasOwn(sourceTexts, path) ? sourceTexts[path] : readFileSync(resolve(root, path), 'utf8');
}

function exactKeys(value, expected, label) {
  if (Object.keys(value).sort().join(',') !== expected.slice().sort().join(',')) {
    fail(`${label} must contain exactly: ${expected.join(', ')}.`);
  }
}

function exactScalarValues(value, expected, label) {
  const source = object(value, label);
  exactKeys(source, Object.keys(expected), label);
  for (const [key, expectedValue] of Object.entries(expected)) {
    if (source[key] !== expectedValue) {
      fail(`${label}.${key} must remain ${JSON.stringify(expectedValue)}.`);
    }
  }
}

function assertNoSensitiveData(value, label = 'retention readiness') {
  if (Array.isArray(value)) {
    value.forEach((entry, index) => assertNoSensitiveData(entry, `${label}[${index}]`));
    return;
  }
  if (value === null || typeof value !== 'object') {
    if (typeof value === 'string' && /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i.test(value)) {
      fail(`${label} must not contain an email address.`);
    }
    return;
  }
  for (const [key, entry] of Object.entries(value)) {
    if (/^(password|secret|token|apiKey|privateKey|credential|email)$/i.test(key)) {
      fail(`${label}.${key} must not contain secrets or account data.`);
    }
    assertNoSensitiveData(entry, `${label}.${key}`);
  }
}

export function assessRetentionExecutionReadiness({ retentionManifest, privacyManifest }) {
  const retention = object(retentionManifest, 'retention execution preflight.retentionManifest');
  const privacy = object(privacyManifest, 'retention execution preflight.privacyManifest');
  const blockers = [];

  if (retention.state !== 'approved'
      || retention.approvalAllowed !== true
      || retention.boundaries?.legalApproval !== true) {
    blockers.push('retention-policy-approval-open');
  }

  const decisions = object(
    retention.requiredDecisions,
    'retention execution preflight.requiredDecisions',
  );
  for (const key of decisionKeys) {
    const decision = decisions[key];
    if (decision?.status !== 'closed'
        || typeof decision?.value !== 'string'
        || !decision.value.trim()
        || typeof decision?.evidenceRef !== 'string'
        || !decision.evidenceRef.startsWith('docs/evidence/b11/')) {
      blockers.push(`decision-open:${key}`);
    }
  }

  const controls = object(
    retention.implementedControls,
    'retention execution preflight.implementedControls',
  );
  if (controls.categoryPurge?.status !== 'implemented-staging-dry-run-verified') {
    blockers.push('category-purge-not-staging-verified');
  }
  if (controls.retentionInventory?.retentionPeriodsApplied !== true) {
    blockers.push('retention-periods-not-applied');
  }
  if (controls.retentionInventory?.eligibleRowsCalculated !== true) {
    blockers.push('eligible-rows-not-calculated');
  }
  if (controls.retentionInventory?.executionEnabled !== true) {
    blockers.push('retention-execution-disabled');
  }

  const processors = object(
    retention.externalProcessors,
    'retention execution preflight.externalProcessors',
  );
  for (const key of externalProcessorKeys) {
    const processor = processors[key];
    if (processor?.retentionOwnerVerified !== true
        || processor?.deletionProcedureVerified !== true
        || typeof processor?.ownerEvidenceRef !== 'string'
        || !processor.ownerEvidenceRef.startsWith('docs/evidence/b11/')) {
      blockers.push(`external-processor-open:${key}`);
    }
  }

  if (retention.storeGate?.status !== 'closed') blockers.push('retention-store-gate-open');
  if (privacy.requiredDecisions?.retentionAndDeletionSchedule?.status !== 'closed') {
    blockers.push('privacy-retention-schedule-open');
  }

  return {
    status: blockers.length === 0 ? 'executable' : 'blocked',
    executionAllowed: blockers.length === 0,
    destructiveRouteExposed: false,
    blockerCount: blockers.length,
    blockers,
  };
}

function assertDecisionPreparation(root, evidenceTexts) {
  let evidence;
  try {
    evidence = JSON.parse(text(root, evidenceTexts, decisionPreparationEvidencePath));
  } catch (error) {
    fail(`Retention decision-preparation evidence must be valid JSON: ${error.message}`);
  }
  assertNoSensitiveData(evidence, 'retention decision-preparation evidence');
  if (evidence.schemaVersion !== 1
      || evidence.kind !== 'retention-deletion-decision-preparation'
      || evidence.status !== 'recommendations-prepared-owner-and-legal-approval-open'
      || evidence.scope?.decisionCount !== decisionKeys.length
      || evidence.scope?.closedDecisionCount !== 0
      || evidence.scope?.categoryPurgeEnabled !== false
      || evidence.scope?.productionChanged !== false
      || evidence.scope?.storeSubmissionChanged !== false) {
    fail('Retention decision-preparation evidence must remain complete and fail closed.');
  }
  const prepared = object(evidence.decisions, 'retention decision-preparation evidence.decisions');
  exactKeys(prepared, decisionKeys, 'retention decision-preparation evidence.decisions');
  for (const key of decisionKeys) {
    const entry = object(prepared[key], `retention decision-preparation evidence.decisions.${key}`);
    exactKeys(entry, [
      'classification',
      'recommendation',
      'implementationState',
      'authorityRefs',
    ], `retention decision-preparation evidence.decisions.${key}`);
    if (typeof entry.classification !== 'string' || !entry.classification.trim()
        || typeof entry.recommendation !== 'string' || !entry.recommendation.trim()
        || typeof entry.implementationState !== 'string' || !entry.implementationState.trim()
        || !Array.isArray(entry.authorityRefs) || entry.authorityRefs.length === 0
        || entry.authorityRefs.some((ref) => typeof ref !== 'string' || !ref.trim())) {
      fail(`Retention decision-preparation entry ${key} is incomplete.`);
    }
  }
  if (evidence.decisions.expiredCredentialPurgePeriod.classification
        !== 'technically-ready-for-owner-approval'
      || evidence.decisions.backupErasureWindow.classification
        !== 'operationally-ready-for-owner-approval'
      || evidence.decisions.externalProcessorRetention.classification
        !== 'owner-contract-and-deletion-procedure-approval-required') {
    fail('Retention decision-preparation classifications drifted from the reviewed boundary.');
  }
  const externalProcessorDecision = evidence.decisions.externalProcessorRetention;
  for (const ref of [
    providerEvidencePath,
    firebaseServiceReadinessPaths.firebaseCloudMessaging,
    firebaseServiceReadinessPaths.firebaseCrashlytics,
    firebaseServiceReadinessPaths.firebaseAuthentication,
    firebaseServiceReadinessPaths.googleMapsPlatform,
  ]) {
    if (!externalProcessorDecision.authorityRefs.includes(ref)) {
      fail(`External-processor decision preparation is missing separate authority: ${ref}.`);
    }
  }
  if (evidence.boundaries?.recommendationsAreApproval !== false
      || evidence.boundaries?.legalPeriodsInvented !== false
      || evidence.boundaries?.allNineDecisionsRemainOpen !== true
      || evidence.boundaries?.categoryPurgeEnabled !== false
      || evidence.boundaries?.productionChanged !== false
      || evidence.boundaries?.storeSubmissionChanged !== false
      || evidence.boundaries?.containsSecrets !== false
      || evidence.boundaries?.containsAccountData !== false) {
    fail('Retention decision preparation must not claim approval or enable deletion.');
  }
  const matrix = text(root, evidenceTexts, decisionPreparationMatrixPath);
  for (const marker of [
    'Status: **Entscheidungsvorbereitung; nicht freigegeben**',
    'Alle neun Entscheidungen bleiben formal offen.',
    'Firebase Cloud Messaging bleibt Bestandteil von SIT',
    'Firebase Crashlytics bleibt Bestandteil von SIT',
    'Push darf Crashdiagnose niemals automatisch aktivieren.',
    'Ein FCM-Nachweis darf niemals die Crashlytics-Freigabe schließen',
    'Eine standardmäßig ausgeschaltete serverseitige Löschwarteschlange mit Wiederholung und ohne SIT-Konto-ID ist vorbereitet.',
    'Die dafür nötige pseudonyme SDK-Zuordnung wird jedoch noch nicht an Firebase übermittelt',
    'schaltet keine Löschroutine frei',
  ]) {
    if (!matrix.includes(marker)) fail(`Retention decision matrix is missing boundary: ${marker}`);
  }
}

function assertSourceContracts(root, sourceTexts) {
  const app = text(root, sourceTexts, 'backend/src/app.js');
  for (const marker of [
    'DELETE FROM notification_preferences WHERE user_id = $1',
    'DELETE FROM notifications WHERE user_id = $1',
    'DELETE FROM message_reads WHERE user_id = $1',
    'DELETE FROM rental_carts WHERE user_id = $1',
    'DELETE FROM listing_sets WHERE owner_id = $1',
    'DELETE FROM user_blocks WHERE blocker_id = $1 OR blocked_id = $1',
    "payload = '{}'::jsonb",
    "'account_deleted'",
    'pseudonymous_notification_delivery_audit',
  ]) {
    if (!app.includes(marker)) fail(`Account erasure is missing the residual-data control: ${marker}.`);
  }
  const rentalCartRetention = text(root, sourceTexts, 'backend/src/retention_inventory.js');
  for (const dataset of [
    'rental_carts',
    'rental_cart_projects',
    'rental_cart_items',
    'listing_supply_enrichment',
    'listing_sets',
    'listing_set_versions',
    'listing_set_version_members',
  ]) {
    if (!rentalCartRetention.includes(`'userIntent', '${dataset}'`)) {
      fail(`Retention inventory is missing the rental-cart dataset: ${dataset}.`);
    }
  }
  const rentalCartWorkflow = text(root, sourceTexts, 'backend/src/rental_cart_workflow.js');
  if (!rentalCartWorkflow.includes('persist: false')
      || !rentalCartWorkflow.includes('reservationCreated: false')) {
    fail('Rental-cart quote previews must remain non-transactional and non-reserving.');
  }
  const communications = text(root, sourceTexts, 'backend/sql/migrations/006_b7_communications.up.sql');
  if (!communications.includes('notification_delivery_attempts_append_only')) {
    fail('Notification delivery audit must remain append-only.');
  }
  const cleanup = text(root, sourceTexts, 'backend/src/credential_cleanup.js');
  for (const marker of [
    'DELETE FROM auth_action_tokens',
    'DELETE FROM refresh_tokens',
    'DELETE FROM staff_elevations',
    'UPDATE booking_confirmation_challenges',
    "code_digest = repeat('0', 64)",
    'credentialCleanupIntervalMs = 6 * 60 * 60 * 1000',
  ]) {
    if (!cleanup.includes(marker)) fail(`Expired credential cleanup is missing the contract: ${marker}.`);
  }
  const server = text(root, sourceTexts, 'backend/src/server.js');
  if (!server.includes('startCredentialCleanupWorker({ client: pool })')
      || !server.includes('stopCredentialCleanup()')) {
    fail('The expired credential cleanup worker must start and stop with the API process.');
  }
  const moderation = text(root, sourceTexts, 'backend/src/moderation_workflow.js');
  for (const marker of [
    'createAccountLegalHold',
    'releaseAccountLegalHold',
    'listAccountLegalHolds',
    "actor.role !== 'admin'",
    'privacy.account_legal_hold_created',
    'privacy.account_legal_hold_released',
  ]) {
    if (!moderation.includes(marker)) fail(`Account legal-hold enforcement is missing the contract: ${marker}.`);
  }
  const legalHoldMigration = text(root, sourceTexts, 'backend/sql/migrations/014_account_legal_holds.up.sql');
  for (const marker of [
    'CREATE TABLE IF NOT EXISTS account_legal_holds',
    'account_legal_holds_one_active_per_user_idx',
    'WHERE released_at IS NULL',
    'release_idempotency_key TEXT UNIQUE',
  ]) {
    if (!legalHoldMigration.includes(marker)) fail(`Account legal-hold migration is missing the contract: ${marker}.`);
  }
  for (const marker of [
    'active_legal_holds',
    '/v1/admin/users/:id/legal-holds',
    '/v1/admin/legal-holds/:id/release',
  ]) {
    if (!app.includes(marker)) fail(`Account deletion or admin routing is missing the legal-hold contract: ${marker}.`);
  }
  const inventory = text(root, sourceTexts, 'backend/src/retention_inventory.js');
  for (const marker of [
    "accounts: 'inactiveAccountPeriod'",
    "transactions: 'transactionalRecordPeriod'",
    "communications: 'communicationPeriod'",
    "moderation: 'moderationEvidencePeriod'",
    "securityAudit: 'auditSecurityLogPeriod'",
    "legalHold: 'legalHoldProcess'",
    "status: 'policy-open-inventory-only'",
    'containsIdentifiers: false',
    'executionEnabled: false',
    'retentionPeriodsApplied: false',
    'eligibleRowsCalculated: false',
  ]) {
    if (!inventory.includes(marker)) fail(`Retention inventory is missing the fail-closed contract: ${marker}.`);
  }
  for (const dataset of ['financial_documents', 'financial_document_events']) {
    if (!inventory.includes(`'transactions', '${dataset}'`)) {
      fail(`Retention inventory is missing immutable dataset ${dataset}.`);
    }
  }
  if (!inventory.includes("'securityAudit', 'support_break_glass_grants'")) {
    fail('Retention inventory is missing immutable dataset support_break_glass_grants.');
  }
  if (!inventory.includes("'securityAudit', 'support_deadline_watchdog_state'")) {
    fail('Retention inventory is missing operational dataset support_deadline_watchdog_state.');
  }
  if (!inventory.includes("'communications', 'support_messages'")) {
    fail('Retention inventory is missing immutable dataset support_messages.');
  }
  const supportMessageMigration = text(
    root,
    sourceTexts,
    'backend/sql/migrations/038_support_message_template_guard.up.sql',
  );
  for (const marker of [
    'support_message_delete_guard',
    'Support message history is append-only',
    'Support message payload is immutable',
    'rendered_content_sha256',
    'corrects_message_id',
  ]) {
    if (!supportMessageMigration.includes(marker)) {
      fail(`Support-message retention boundary is missing ${marker}.`);
    }
  }
  if (/DELETE\s+FROM|UPDATE\s+[a-z_]+\s+SET/iu.test(inventory)) {
    fail('Retention inventory must remain read-only.');
  }
  if (!app.includes('/v1/admin/privacy/retention-inventory')
      || !app.includes('inspectRetentionInventory(client, { actor: req.actor })')) {
    fail('The admin retention-inventory route is missing.');
  }
  const backup = text(root, sourceTexts, 'backend/ops/backup.sh');
  if (!backup.includes('-mtime +14 -delete')) fail('The observed 14-day backup rotation contract is missing.');
  const android = text(root, sourceTexts, 'android/app/src/main/AndroidManifest.xml');
  for (const marker of [
    'firebase_messaging_auto_init_enabled',
    'firebase_crashlytics_collection_enabled',
  ]) {
    if (!new RegExp(`${marker}[\\s\\S]{0,120}android:value="false"`).test(android)) {
      fail(`Android Firebase service readiness requires ${marker}=false.`);
    }
  }
  const ios = text(root, sourceTexts, 'ios/Runner/Info.plist');
  for (const marker of [
    'FirebaseMessagingAutoInitEnabled',
    'FirebaseCrashlyticsCollectionEnabled',
  ]) {
    if (!new RegExp(`<key>${marker}<\\/key>\\s*<false\\/>`).test(ios)) {
      fail(`iOS Firebase service readiness requires ${marker}=false.`);
    }
  }
  const firebaseRuntime = text(root, sourceTexts, 'lib/services/firebase_runtime.dart');
  for (const marker of [
    'setAutoInitEnabled(_pushEnabled)',
    'kReleaseMode && _crashDiagnosticsEnabled',
    'FirebaseMessaging.instance.deleteToken()',
    'FirebaseCrashlytics.instance.deleteUnsentReports()',
    'FirebaseInstallations.instance.delete()',
    'deleteCurrentSessionPushDevices()',
    'setDeliveryMetricsExportToBigQuery(false)',
  ]) {
    if (!firebaseRuntime.includes(marker)) {
      fail(`Firebase service readiness is missing runtime control: ${marker}.`);
    }
  }
  const firebasePreferences = text(
    root,
    sourceTexts,
    'lib/services/firebase_service_preferences.dart',
  );
  for (const marker of [
    'installationCleanupPending',
    'pushLocalCleanupPending',
    'pushBackendCleanupPending',
  ]) {
    if (!firebasePreferences.includes(marker)) {
      fail(`Firebase service readiness is missing persisted retry state: ${marker}.`);
    }
  }
  const accountDeletion = text(root, sourceTexts, 'lib/services/account_deletion_service.dart');
  if (!accountDeletion.includes('FirebaseRuntime.deleteInstallationForAccountDeletion()')) {
    fail('Account deletion must invoke Firebase installation cleanup.');
  }
  const firebaseSocial = text(root, sourceTexts, 'backend/src/firebase_social_auth.js');
  for (const marker of [
    'await verify(token, true)',
    'firebaseUserId',
    "'google.com': 'google'",
    "'apple.com': 'apple'",
    "'facebook.com': 'facebook'",
  ]) {
    if (!firebaseSocial.includes(marker)) {
      fail(`Firebase Authentication readiness is missing social-auth control: ${marker}.`);
    }
  }
  const firebasePhone = text(root, sourceTexts, 'backend/src/firebase_phone_verification.js');
  for (const marker of [
    'deleteFirebasePhoneIdentity',
    'providers.length !== 1',
    "providers[0]?.providerId !== 'phone'",
    'await remove(firebaseUserId)',
  ]) {
    if (!firebasePhone.includes(marker)) {
      fail(`Firebase Authentication readiness is missing temporary-identity cleanup: ${marker}.`);
    }
  }
  const firebaseIdentityCleanup = text(
    root,
    sourceTexts,
    'backend/src/firebase_identity_cleanup.js',
  );
  for (const marker of [
    'enqueueFirebaseIdentityDeletions',
    'drainFirebaseIdentityDeletionOutbox',
    'FOR UPDATE SKIP LOCKED',
    "userNotFoundCodes.has(code)",
    "SET status = 'retry'",
    'startFirebaseIdentityCleanupWorker',
  ]) {
    if (!firebaseIdentityCleanup.includes(marker)) {
      fail(`Firebase Authentication readiness is missing durable provider deletion: ${marker}.`);
    }
  }
  const firebaseIdentityMigration = text(
    root,
    sourceTexts,
    'backend/sql/migrations/021_firebase_identity_deletion_outbox.up.sql',
  );
  for (const marker of [
    'CREATE TABLE IF NOT EXISTS firebase_identity_deletion_outbox',
    "provider IN ('google', 'apple', 'facebook')",
    "status IN ('pending', 'processing', 'retry')",
    'firebase_identity_deletion_outbox_due_idx',
  ]) {
    if (!firebaseIdentityMigration.includes(marker)) {
      fail(`Firebase Authentication readiness is missing deletion-outbox schema: ${marker}.`);
    }
  }
  if (!app.includes('enqueueFirebaseIdentityDeletions(client,')
      || !app.includes("await client.query('DELETE FROM auth_identities WHERE user_id = $1'")
      || app.indexOf('enqueueFirebaseIdentityDeletions(client,')
        > app.indexOf("await client.query('DELETE FROM auth_identities WHERE user_id = $1'")) {
    fail('Firebase identity deletion must be queued transactionally before local identity erasure.');
  }
  const runtimeServer = text(root, sourceTexts, 'backend/src/server.js');
  if (!runtimeServer.includes('startFirebaseIdentityCleanupWorker({')
      || !runtimeServer.includes('stopFirebaseIdentityCleanup()')) {
    fail('Firebase identity deletion retry worker must start and stop with the API process.');
  }
  const mapsProxy = text(root, sourceTexts, 'backend/src/maps_proxy.js');
  for (const marker of [
    "throw new MapsProxyError(503, 'maps_unavailable')",
    "'/maps/api/place/autocomplete/json'",
    "'/maps/api/place/details/json'",
    "fields: 'formatted_address,geometry'",
  ]) {
    if (!mapsProxy.includes(marker)) {
      fail(`Google Maps readiness is missing server-proxy control: ${marker}.`);
    }
  }
  const mapsActivation = text(
    root,
    sourceTexts,
    'backend/src/google_maps_activation.js',
  );
  for (const marker of [
    'GOOGLE_MAPS_ACTIVATION_APPROVED',
    'GOOGLE_MAPS_TRANSFER_MECHANISM',
    "serverApiKey: enabled ? serverApiKey : ''",
  ]) {
    if (!mapsActivation.includes(marker)) {
      fail(`Google Maps readiness is missing provider activation gate: ${marker}.`);
    }
  }
  const pushSender = text(root, sourceTexts, 'backend/src/push_sender.js');
  for (const marker of [
    "V52_PUSH_CONTRACT_VERSION = 'v52'",
    "route: 'notifications'",
    'ttl: payload.ttlSeconds * 1000',
    "'apns-expiration': String(expiration)",
  ]) {
    if (!pushSender.includes(marker)) {
      fail(`FCM readiness is missing the neutral TTL contract: ${marker}.`);
    }
  }
  for (const marker of [
    "app.get('/v1/maps/places/autocomplete', requireAuth, requireActiveAccount, mapsLimiter",
    "app.get('/v1/maps/places/:placeId', requireAuth, requireActiveAccount, mapsLimiter",
  ]) {
    if (!app.includes(marker)) fail(`Google Maps readiness is missing authenticated routing: ${marker}.`);
  }
  const mapsService = text(root, sourceTexts, 'lib/services/maps_service.dart');
  const backendRepository = text(root, sourceTexts, 'lib/services/backend_repository.dart');
  if (!mapsService.includes('BackendRepository.autocompleteAddresses(')
      || !mapsService.includes('BackendRepository.getAddressPlaceDetails(')
      || !backendRepository.includes("path: '/maps/places/autocomplete?$query'")
      || !backendRepository.includes("path: '/maps/places/${Uri.encodeComponent(placeId)}?$query'")) {
    fail('Google Maps client flow must remain routed through the authenticated SIT backend.');
  }
  const privacy = `${text(root, sourceTexts, 'lib/screens/legal_privacy_screen.dart')}\n${text(root, sourceTexts, 'lib/screens/privacy_info_screen.dart')}`;
  if (!privacy.includes('Löschung')) fail('In-app privacy information must disclose deletion.');
}

function assertProviderEvidence(root, evidenceTexts) {
  let evidence;
  try {
    evidence = JSON.parse(text(root, evidenceTexts, providerEvidencePath));
  } catch (error) {
    fail(`Provider-retention evidence must be valid JSON: ${error.message}`);
  }
  assertNoSensitiveData(evidence, 'provider-retention evidence');
  if (evidence.schemaVersion !== 1
      || evidence.kind !== 'privacy-provider-retention-source-review'
      || evidence.status !== 'official-sources-reviewed-owner-and-legal-approval-open') {
    fail('Provider-retention evidence must remain an official-source review with owner and legal approval open.');
  }
  if (!Array.isArray(evidence.sources)) fail('Provider-retention evidence must contain official sources.');
  for (const [provider, url, marker] of requiredOfficialSources) {
    const source = evidence.sources.find((entry) => entry?.provider === provider && entry?.url === url);
    if (!source || typeof source.officialFact !== 'string' || !source.officialFact.includes(marker)) {
      fail(`Provider-retention evidence is missing the official ${provider} source contract: ${marker}.`);
    }
  }
  const boundaries = object(evidence.boundaries, 'provider-retention evidence.boundaries');
  if (boundaries.officialDocumentationReviewed !== true
      || boundaries.providerContractAcceptedByOwner !== false
      || boundaries.legalApproval !== false
      || boundaries.storeFormSubmitted !== false
      || boundaries.publicRoutesChanged !== false
      || boundaries.productionChanged !== false
      || boundaries.containsSecrets !== false
      || boundaries.containsAccountData !== false) {
    fail('Provider-retention evidence must preserve the reviewed-but-unapproved release boundary.');
  }
}

function assertRetentionExecutionPreflightEvidence(root, evidenceTexts) {
  let evidence;
  try {
    evidence = JSON.parse(text(root, evidenceTexts, retentionExecutionPreflightEvidencePath));
  } catch (error) {
    fail(`Retention execution-preflight evidence must be valid JSON: ${error.message}`);
  }
  assertNoSensitiveData(evidence, 'retention execution-preflight evidence');
  if (evidence.schemaVersion !== 1
      || evidence.kind !== 'v51-retention-execution-preflight'
      || evidence.status !== 'implemented-full-regression-passed-execution-blocked'
      || evidence.sourceBaseCommit !== '61b570ba6629a88eb0e3be24def23b2718351d6e'
      || evidence.result?.executionStatus !== 'blocked'
      || evidence.result?.executionAllowed !== false
      || evidence.result?.destructiveRouteExposed !== false
      || evidence.result?.currentBlockerCount !== 20
      || evidence.result?.openRetentionDecisions !== decisionKeys.length
      || evidence.result?.processorVerificationGatesOpen !== externalProcessorKeys.length
      || evidence.result?.unsafeDecisionValuesReflected !== false
      || !Array.isArray(evidence.requiredCombinedGates)
      || evidence.requiredCombinedGates.length !== 9
      || evidence.verification?.targetedRetentionTests !== 'passed-36'
      || evidence.verification?.retentionValidator
        !== 'passed-draft-open-nine-decisions-execution-blocked-20'
      || evidence.verification?.fullTechnicalRegression !== 'passed-candidate-rollover-mode'
      || evidence.verification?.flutterTests !== 'passed-282-with-1-intentional-skip'
      || evidence.verification?.flutterAnalyzer !== '229-findings-0-errors-baseline-accepted'
      || evidence.verification?.webDebugBuild
        !== 'passed-existing-wasm-dry-run-warnings-only'
      || evidence.verification?.androidDebugBuild !== 'passed'
      || evidence.boundaries?.retentionPeriodsInvented !== false
      || evidence.boundaries?.decisionStatusChanged !== false
      || evidence.boundaries?.eligibleRowsCalculated !== false
      || evidence.boundaries?.databaseRowsReadForThisMilestone !== false
      || evidence.boundaries?.databaseRowsChanged !== false
      || evidence.boundaries?.deletionRouteAdded !== false
      || evidence.boundaries?.stagingChanged !== false
      || evidence.boundaries?.productionChanged !== false
      || evidence.boundaries?.storeSubmissionChanged !== false
      || evidence.boundaries?.candidateBuiltOrRelabeled !== false
      || evidence.boundaries?.containsSecrets !== false
      || evidence.boundaries?.containsAccountData !== false) {
    fail('Retention execution-preflight evidence is incomplete or exceeds its non-destructive boundary.');
  }
  for (const requiredGate of [
    'owner-and-legal-policy-approval',
    'all-nine-decisions-evidence-closed',
    'category-purge-staging-dry-run-verified',
    'retention-periods-applied',
    'eligible-rows-calculated',
    'retention-execution-explicitly-enabled',
    'all-four-external-processor-retention-and-deletion-procedures-verified',
    'retention-store-gate-closed',
    'privacy-retention-schedule-closed',
  ]) {
    if (!evidence.requiredCombinedGates.includes(requiredGate)) {
      fail(`Retention execution-preflight evidence is missing gate: ${requiredGate}.`);
    }
  }
}

function assertFirebaseServiceReadiness(root, evidenceTexts) {
  const contracts = {
    firebaseCloudMessaging: {
      path: firebaseServiceReadinessPaths.firebaseCloudMessaging,
      sources: [
        ['retention', 'https://firebase.google.com/support/privacy/', 'within 180 days'],
        ['deletion-control', 'https://firebase.google.com/docs/projects/manage-installations', 'new unrelated installation ID'],
        ['processor-role-and-transfer-framework', 'https://firebase.google.com/terms/data-processing-terms/', 'Google as processor'],
      ],
      controls: {
        nativeAutoInitDefaultOffInCurrentSource: true,
        runtimeEnablementRequiresPushChoice: true,
        runtimeEnablementCanEnableCrashlytics: false,
        backendSessionRegistrationDeletionImplemented: true,
        messagingTokenDeletionImplemented: true,
        firebaseInstallationDeletionImplemented: true,
        pendingDeletionRetryImplemented: true,
      },
      retention: {
        providerCompletionWindow: 'within-180-days-after-installation-deletion-request',
        sitCanPromiseImmediateProviderErasure: false,
        localAndBackendDisableProcedureImplemented: true,
        providerDeletionRequestImplemented: true,
        currentAccountContractAcceptanceVerified: false,
        currentProcessingLocationsVerified: false,
        internationalTransferMechanismApprovedForSIT: false,
        retentionAcceptedByOwner: false,
        deletionProcedureVerifiedByOwner: false,
        ownerEvidenceRef: null,
      },
      activation: {
        storeDisclosureApproved: false,
        replacementCandidateBuilt: false,
        replacementCandidateDeviceVerified: false,
        productionChanged: false,
        storeFormChanged: false,
        providerConsoleChanged: false,
        containsSecrets: false,
        containsAccountData: false,
      },
    },
    firebaseCrashlytics: {
      path: firebaseServiceReadinessPaths.firebaseCrashlytics,
      sources: [
        ['retention', 'https://firebase.google.com/support/privacy/', 'for 90 days'],
        ['opt-in-control', 'https://firebase.google.com/docs/crashlytics/android/customize-crash-reports', 'unsent reports on the device'],
        ['stored-report-deletion-control', 'https://firebase.google.com/docs/reference/crashlytics/rest/v1alpha/projects.apps.users/deleteCrashReports', 'typically within 24 hours'],
        ['processor-role-and-transfer-framework', 'https://firebase.google.com/terms/data-processing-terms/', 'Google as processor'],
      ],
      controls: {
        nativeAutomaticCollectionDefaultOffInCurrentSource: true,
        runtimeEnablementRequiresCrashDiagnosticsChoice: true,
        pushChoiceCanEnableCrashlytics: false,
        disableCollectionImplemented: true,
        deleteUnsentDeviceReportsImplemented: true,
        firebaseInstallationDeletionImplemented: true,
        serverDeletionQueueFoundationImplemented: true,
        providerDeletionExecutionDefaultOff: true,
        pseudonymousSdkSubjectTransmissionImplemented: false,
        stableCrashSubjectCorrelationImplemented: false,
        storedCrashReportDeletionInvocationImplemented: false,
      },
      retention: {
        providerRetentionWindow: '90-days-before-provider-removal-process-starts',
        sitCanPromiseImmediateProviderErasure: false,
        localUnsentReportDeletionImplemented: true,
        providerStoredReportDeletionProcedureImplemented: false,
        additionalPseudonymousIdentifierApprovalOpen: true,
        currentAccountContractAcceptanceVerified: false,
        currentProcessingLocationsVerified: false,
        internationalTransferMechanismApprovedForSIT: false,
        retentionAcceptedByOwner: false,
        deletionProcedureVerifiedByOwner: false,
        ownerEvidenceRef: null,
      },
      activation: {
        storeDisclosureApproved: false,
        replacementCandidateBuilt: false,
        replacementCandidateDeviceVerified: false,
        crashEventEmittedForThisMilestone: false,
        productionChanged: false,
        storeFormChanged: false,
        providerConsoleChanged: false,
        pseudonymousIdentifierSentForThisMilestone: false,
        providerDeletionRequestSentForThisMilestone: false,
        containsSecrets: false,
        containsAccountData: false,
      },
    },
    firebaseAuthentication: {
      path: firebaseServiceReadinessPaths.firebaseAuthentication,
      kind: 'firebase-authentication-retention-deletion-readiness',
      provider: 'Google Firebase',
      sources: [
        ['retention', 'https://firebase.google.com/support/privacy/', 'within 180 days'],
        ['deletion-control', 'https://firebase.google.com/docs/auth/admin/manage-users', 'delete users by UID'],
        ['processor-role-and-transfer-framework', 'https://firebase.google.com/terms/data-processing-terms/', 'Google as processor'],
      ],
      productDecision: {
        retainedForLaunch: true,
        phoneVerificationInLaunchScope: true,
        socialLoginActivationApproved: false,
        temporaryPhoneIdentityRequired: true,
        futureSocialActivationRequiresExternalApprovals: true,
      },
      controls: {
        phoneProviderEnabledInBoundEnvironment: true,
        temporaryPhoneIdentityDeletionImplemented: true,
        temporaryIdentitySafetyCheckImplemented: true,
        firebaseUserIdStoredForLinkedSocialIdentity: true,
        persistentSocialIdentityDeletionOnAccountErasureImplemented: true,
        providerPasswordOrAccessTokenStoredBySit: false,
      },
      retention: {
        loggedIpRetention: 'a-few-weeks',
        otherAuthenticationInformationRemoval:
          'within-180-days-after-customer-initiated-associated-user-deletion',
        temporaryPhoneIdentityProviderDeletionImplemented: true,
        persistentSocialIdentityProviderDeletionImplemented: true,
        sitCanPromiseImmediateProviderErasure: false,
        currentAccountContractAcceptanceVerified: false,
        currentProcessingLocationsVerified: false,
        internationalTransferMechanismApprovedForSIT: false,
        retentionAcceptedByOwner: false,
        deletionProcedureVerifiedByOwner: false,
        ownerEvidenceRef: null,
      },
      activation: {
        socialProvidersRemainDisabled: true,
        storeDisclosureApproved: false,
        replacementCandidateBuilt: false,
        replacementCandidateDeviceVerified: false,
        productionChanged: false,
        providerConsoleChanged: false,
        containsSecrets: false,
        containsAccountData: false,
      },
    },
    googleMapsPlatform: {
      path: firebaseServiceReadinessPaths.googleMapsPlatform,
      kind: 'google-maps-platform-retention-deletion-readiness',
      provider: 'Google Maps Platform',
      sources: [
        ['logged-data-and-retention', 'https://developers.google.com/maps/security/compliance/security-compliance', 'no single fixed retention period'],
        ['controller-role-and-terms', 'https://cloud.google.com/maps-platform/terms?sign=1', 'controller-controller data protection terms'],
      ],
      productDecision: {
        retainedForLaunch: true,
        addressAutocompleteAndPlaceDetailsInLaunchScope: true,
        preciseDeviceLocationRequiresExplicitUserAction: true,
        backgroundOrLiveTrackingAllowed: false,
        serverProxyRequired: true,
      },
      controls: {
        serverSideProxyImplemented: true,
        clientCredentialEmbedded: false,
        authenticatedActiveAccountRequired: true,
        requestRateLimitImplemented: true,
        inputAndPlaceIdBounded: true,
        directMapsSdkTransferImplemented: false,
        typedAddressOrPlaceIdTransferredOnUse: true,
      },
      retention: {
        singleFixedProviderRetentionPeriodAvailable: false,
        accountScopedProviderDeletionProcedureImplemented: false,
        sitCanPromiseImmediateProviderErasure: false,
        currentAccountContractAcceptanceVerified: false,
        currentEnabledApisAndLoggingVerified: false,
        currentProcessingLocationsVerified: false,
        internationalTransferMechanismApprovedForSIT: false,
        retentionAcceptedByOwner: false,
        deletionProcedureVerifiedByOwner: false,
        ownerEvidenceRef: null,
      },
      activation: {
        serverCredentialRestrictionVerified: false,
        storeDisclosureApproved: false,
        productionChanged: false,
        providerConsoleChanged: false,
        containsSecrets: false,
        containsAccountData: false,
      },
    },
  };

  for (const [serviceId, contract] of Object.entries(contracts)) {
    let evidence;
    try {
      evidence = JSON.parse(text(root, evidenceTexts, contract.path));
    } catch (error) {
      fail(`${serviceId} readiness evidence must be valid JSON: ${error.message}`);
    }
    assertNoSensitiveData(evidence, `${serviceId} readiness evidence`);
    exactKeys(evidence, [
      'schemaVersion',
      'kind',
      'serviceId',
      'provider',
      'reviewedAt',
      'status',
      'productDecision',
      'officialSources',
      'currentTechnicalControls',
      'retentionAndDeletionReality',
      'activationBoundary',
    ], `${serviceId} readiness evidence`);
    if (evidence.schemaVersion !== 1
        || evidence.kind !== (contract.kind ?? 'firebase-service-retention-deletion-readiness')
        || evidence.serviceId !== serviceId
        || evidence.provider !== (contract.provider ?? 'Google Firebase')
        || evidence.reviewedAt !== '2026-08-17T00:00:00Z'
        || evidence.status !== 'official-controls-structured-owner-contract-and-deletion-approval-open') {
      fail(`${serviceId} readiness evidence identity or status is invalid.`);
    }
    exactScalarValues(evidence.productDecision, contract.productDecision ?? {
      retainedForLaunch: true,
      voluntaryOptIn: true,
      nextCandidateDefaultOff: true,
      independentFromOtherFirebaseDeviceServices: true,
      boundCandidateCollectionMode: 'automatic-in-bound-candidate',
      replacementCandidateRequired: true,
    }, `${serviceId} readiness evidence.productDecision`);
    if (!Array.isArray(evidence.officialSources)
        || evidence.officialSources.length !== contract.sources.length) {
      fail(`${serviceId} readiness evidence must bind every separate official source exactly once.`);
    }
    for (const [purpose, url, marker] of contract.sources) {
      const source = evidence.officialSources.find(
        (entry) => entry?.purpose === purpose && entry?.url === url,
      );
      if (!source || typeof source.finding !== 'string' || !source.finding.includes(marker)) {
        fail(`${serviceId} readiness evidence is missing ${purpose}: ${marker}.`);
      }
    }
    exactScalarValues(
      evidence.currentTechnicalControls,
      contract.controls,
      `${serviceId} readiness evidence.currentTechnicalControls`,
    );
    exactScalarValues(
      evidence.retentionAndDeletionReality,
      contract.retention,
      `${serviceId} readiness evidence.retentionAndDeletionReality`,
    );
    exactScalarValues(
      evidence.activationBoundary,
      contract.activation,
      `${serviceId} readiness evidence.activationBoundary`,
    );
  }
}

function assertCredentialCleanupEvidence(root, evidenceTexts) {
  let evidence;
  try {
    evidence = JSON.parse(text(root, evidenceTexts, credentialCleanupEvidencePath));
  } catch (error) {
    fail(`Expired credential cleanup evidence must be valid JSON: ${error.message}`);
  }
  assertNoSensitiveData(evidence, 'expired credential cleanup evidence');
  if (evidence.schemaVersion !== 1
      || evidence.kind !== 'expired-credential-cleanup'
      || ![
        'implemented-full-regression-passed-staging-deployment-pending',
        'staging-runtime-verified',
      ].includes(evidence.status)
      || evidence.scope?.expiredOrConsumedActionTokensDeleted !== true
      || evidence.scope?.expiredRefreshTokensDeleted !== true
      || evidence.scope?.expiredOrRevokedStaffElevationsDeleted !== true
      || evidence.scope?.expiredConsumedOrRevokedBookingChallengeDigestsScrubbed !== true
      || evidence.scope?.bookingAndAuditRowsRetained !== true
      || evidence.scope?.startupRun !== true
      || evidence.scope?.workerIntervalHours !== 6
      || evidence.scope?.maximumAllowedWorkerIntervalHours !== 24
      || evidence.verification?.syntaxCheck !== 'passed'
      || evidence.verification?.unitTests !== 'passed'
      || !String(evidence.verification?.fullBackendSuite ?? '').startsWith('passed-')
      || evidence.verification?.fullTechnicalRegression !== 'passed-candidate-rollover-mode'
      || evidence.policyBoundary?.legalRetentionPeriodsInvented !== false
      || evidence.policyBoundary?.requiredRetentionDecisionsClosed !== false
      || evidence.policyBoundary?.categoryPurgeEnabled !== false
      || evidence.policyBoundary?.legalHoldEnabled !== false
      || evidence.policyBoundary?.backupPolicyChanged !== false
      || evidence.boundaries?.productionChanged !== false
      || evidence.boundaries?.storeSubmissionChanged !== false
      || evidence.boundaries?.containsSecrets !== false
      || evidence.boundaries?.containsAccountData !== false) {
    fail('Expired credential cleanup evidence is incomplete or exceeds its technical boundary.');
  }
  const deployment = object(evidence.deployment, 'expired credential cleanup deployment');
  if (evidence.status === 'implemented-full-regression-passed-staging-deployment-pending') {
    if (evidence.verification.stagingRuntime !== 'pending'
        || deployment.status !== 'pending'
        || deployment.commit !== null
        || deployment.evidenceRef !== null) {
      fail('Pending credential cleanup evidence must not claim a Staging deployment.');
    }
  } else if (evidence.verification.stagingRuntime !== 'passed'
      || deployment.status !== 'verified'
      || !/^[a-f0-9]{40}$/.test(deployment.commit ?? '')
      || typeof deployment.evidenceRef !== 'string'
      || !deployment.evidenceRef.startsWith('/docker/shareittoo/releases/staging-')) {
    fail('Verified credential cleanup evidence requires the exact Staging deployment proof.');
  }
}

function assertLegalHoldEvidence(root, evidenceTexts) {
  let evidence;
  try {
    evidence = JSON.parse(text(root, evidenceTexts, legalHoldEvidencePath));
  } catch (error) {
    fail(`Account legal-hold evidence must be valid JSON: ${error.message}`);
  }
  assertNoSensitiveData(evidence, 'account legal-hold evidence');
  if (evidence.schemaVersion !== 1
      || evidence.kind !== 'account-legal-hold-enforcement'
      || ![
        'implemented-tests-passed-staging-deployment-pending',
        'staging-runtime-verified',
      ].includes(evidence.status)
      || evidence.scope?.oneActiveHoldPerAccount !== true
      || evidence.scope?.accountDeletionPreflightBlocked !== true
      || evidence.scope?.appAndWebDeletionBlocked !== true
      || evidence.scope?.adminStepUpRequired !== true
      || evidence.scope?.supportRoleDenied !== true
      || evidence.scope?.createAndReleaseIdempotent !== true
      || evidence.scope?.createAndReleaseAudited !== true
      || evidence.scope?.privateNoteExcludedFromResponseAndAudit !== true
      || evidence.verification?.syntaxCheck !== 'passed'
      || evidence.verification?.unitTests !== 'passed'
      || evidence.policyBoundary?.legalHoldProcessApproved !== false
      || evidence.policyBoundary?.legalRetentionPeriodsInvented !== false
      || evidence.policyBoundary?.automaticHoldCreationEnabled !== false
      || evidence.policyBoundary?.existingAccountPlacedOnHold !== false
      || evidence.boundaries?.productionChanged !== false
      || evidence.boundaries?.storeSubmissionChanged !== false
      || evidence.boundaries?.containsSecrets !== false
      || evidence.boundaries?.containsAccountData !== false) {
    fail('Account legal-hold evidence is incomplete or exceeds its technical boundary.');
  }
  const deployment = object(evidence.deployment, 'account legal-hold deployment');
  if (evidence.status === 'implemented-tests-passed-staging-deployment-pending') {
    if (!String(evidence.verification.fullBackendSuite ?? '').startsWith('passed-')
        || evidence.verification.fullTechnicalRegression !== 'passed-candidate-rollover-mode'
        || evidence.verification.stagingRuntime !== 'pending'
        || deployment.status !== 'pending'
        || deployment.commit !== null
        || deployment.evidenceRef !== null) {
      fail('Pending legal-hold evidence requires full tests without claiming a Staging deployment.');
    }
  } else if (!String(evidence.verification.fullBackendSuite ?? '').startsWith('passed-')
      || evidence.verification.fullTechnicalRegression !== 'passed-candidate-rollover-mode'
      || evidence.verification.stagingRuntime !== 'passed'
      || deployment.status !== 'verified'
      || !/^[a-f0-9]{40}$/.test(deployment.commit ?? '')
      || typeof deployment.evidenceRef !== 'string'
      || !deployment.evidenceRef.startsWith('/docker/shareittoo/releases/staging-')) {
    fail('Verified legal-hold evidence requires full tests and the exact Staging deployment proof.');
  }
}

function assertRetentionInventoryEvidence(root, evidenceTexts) {
  let evidence;
  try {
    evidence = JSON.parse(text(root, evidenceTexts, retentionInventoryEvidencePath));
  } catch (error) {
    fail(`Retention-inventory evidence must be valid JSON: ${error.message}`);
  }
  assertNoSensitiveData(evidence, 'retention-inventory evidence');
  if (evidence.schemaVersion !== 1
      || evidence.kind !== 'retention-inventory'
      || ![
        'implemented-targeted-tests-passed-full-regression-pending',
        'implemented-full-regression-passed-staging-deployment-pending',
        'staging-runtime-verified',
      ].includes(evidence.status)
      || evidence.scope?.aggregatedCountsOnly !== true
      || evidence.scope?.identifiersExcluded !== true
      || evidence.scope?.adminStepUpRequired !== true
      || evidence.scope?.supportRoleDenied !== true
      || evidence.scope?.readOnly !== true
      || evidence.scope?.categoryCount !== 7
      || evidence.scope?.datasetCount !== 21
      || evidence.scope?.localPolicyDecisionKeysCovered !== 6
      || evidence.scope?.retentionPeriodsApplied !== false
      || evidence.scope?.eligibleRowsCalculated !== false
      || evidence.scope?.executionEnabled !== false
      || evidence.verification?.syntaxCheck !== 'passed'
      || evidence.verification?.unitTests !== 'passed-3'
      || evidence.policyBoundary?.legalRetentionPeriodsInvented !== false
      || evidence.policyBoundary?.requiredRetentionDecisionsClosed !== false
      || evidence.policyBoundary?.categoryPurgeEnabled !== false
      || evidence.policyBoundary?.existingRowsDeletedOrChanged !== false
      || evidence.boundaries?.productionChanged !== false
      || evidence.boundaries?.storeSubmissionChanged !== false
      || evidence.boundaries?.appCandidateChanged !== false
      || evidence.boundaries?.containsSecrets !== false
      || evidence.boundaries?.containsAccountData !== false) {
    fail('Retention-inventory evidence is incomplete or exceeds its read-only policy boundary.');
  }
  const deployment = object(evidence.deployment, 'retention-inventory deployment');
  if (evidence.status === 'implemented-targeted-tests-passed-full-regression-pending') {
    if (evidence.verification.fullBackendSuite !== 'pending'
        || evidence.verification.fullTechnicalRegression !== 'pending'
        || evidence.verification.stagingRuntime !== 'pending'
        || deployment.status !== 'pending'
        || deployment.commit !== null
        || deployment.evidenceRef !== null) {
      fail('Targeted retention-inventory evidence must keep full regression and deployment pending.');
    }
  } else if (evidence.status === 'implemented-full-regression-passed-staging-deployment-pending') {
    if (!String(evidence.verification.fullBackendSuite ?? '').startsWith('passed-')
        || evidence.verification.fullTechnicalRegression !== 'passed-candidate-rollover-mode'
        || evidence.verification.stagingRuntime !== 'pending'
        || deployment.status !== 'pending'
        || deployment.commit !== null
        || deployment.evidenceRef !== null) {
      fail('Full-regression retention-inventory evidence must keep Staging deployment pending.');
    }
  } else if (!String(evidence.verification.fullBackendSuite ?? '').startsWith('passed-')
      || evidence.verification.fullTechnicalRegression !== 'passed-candidate-rollover-mode'
      || evidence.verification.stagingRuntime !== 'passed'
      || deployment.status !== 'verified'
      || !/^[a-f0-9]{40}$/.test(deployment.commit ?? '')
      || typeof deployment.evidenceRef !== 'string'
      || !deployment.evidenceRef.startsWith('/docker/shareittoo/releases/staging-')) {
    fail('Verified retention-inventory evidence requires full tests and exact Staging deployment proof.');
  }
}

export function validateRetentionDeletionReadiness({
  root,
  retentionManifest,
  privacyManifest,
  sourceTexts = {},
  evidenceTexts = {},
  requireApproved = false,
}) {
  const retention = object(retentionManifest, 'store/retention-deletion-readiness.json');
  const privacy = object(privacyManifest, 'store/privacy-disclosures.json');
  assertNoSensitiveData(retention);
  if (retention.schemaVersion !== 1) fail('retention schemaVersion must be 1.');
  if (!['draft', 'approved'].includes(retention.state)) fail('retention state must be draft or approved.');
  if (typeof retention.approvalAllowed !== 'boolean') fail('approvalAllowed must be boolean.');

  if (!Array.isArray(retention.sourceInventory) || retention.sourceInventory.length !== sourcePaths.length) {
    fail('sourceInventory must contain every required retention source exactly once.');
  }
  const sourceMap = new Map();
  for (const entryValue of retention.sourceInventory) {
    const entry = object(entryValue, 'sourceInventory entry');
    exactKeys(entry, ['path', 'sha256'], `sourceInventory.${entry.path ?? 'unknown'}`);
    if (!sourcePaths.includes(entry.path) || sourceMap.has(entry.path)) fail(`Unexpected or duplicate source path: ${entry.path}.`);
    if (!/^[a-f0-9]{64}$/.test(entry.sha256)) fail(`Invalid source hash: ${entry.path}.`);
    sourceMap.set(entry.path, entry.sha256);
  }
  for (const path of sourcePaths) {
    if (sha256(text(root, sourceTexts, path)) !== sourceMap.get(path)) fail(`sourceInventory hash is stale: ${path}.`);
  }
  assertSourceContracts(root, sourceTexts);
  assertProviderEvidence(root, evidenceTexts);
  assertRetentionExecutionPreflightEvidence(root, evidenceTexts);
  assertFirebaseServiceReadiness(root, evidenceTexts);
  assertCredentialCleanupEvidence(root, evidenceTexts);
  assertLegalHoldEvidence(root, evidenceTexts);
  assertRetentionInventoryEvidence(root, evidenceTexts);
  assertDecisionPreparation(root, evidenceTexts);

  const controls = object(retention.implementedControls, 'implementedControls');
  if (controls.accountErasure?.status !== 'implemented-integration-covered'
      || controls.accountErasure?.notificationResidue !== 'deleted-or-scrubbed') {
    fail('Account erasure residual-data coverage must be recorded.');
  }
  if (controls.credentialExpiry?.status !== 'lifetime-enforced-and-automatic-purge'
      || controls.credentialExpiry?.automaticExpiredRowPurge !== true
      || controls.credentialExpiry?.startupPurge !== true
      || controls.credentialExpiry?.workerIntervalHours !== 6
      || controls.credentialExpiry?.maximumAllowedWorkerIntervalHours !== 24
      || controls.credentialExpiry?.bookingChallengeDigestScrubbed !== true
      || controls.credentialExpiry?.technicalEvidenceRef !==
        'docs/evidence/b11/expired-credential-cleanup-20260815.json'
      || controls.categoryPurge?.status !== 'not-implemented'
      || controls.retentionInventory?.status !== 'read-only-counts-implemented-policy-open'
      || controls.retentionInventory?.aggregatedCountsOnly !== true
      || controls.retentionInventory?.identifiersExcluded !== true
      || controls.retentionInventory?.adminStepUpRequired !== true
      || controls.retentionInventory?.supportRoleDenied !== true
      || controls.retentionInventory?.retentionPeriodsApplied !== false
      || controls.retentionInventory?.eligibleRowsCalculated !== false
      || controls.retentionInventory?.executionEnabled !== false
      || controls.retentionInventory?.technicalEvidenceRef !== retentionInventoryEvidencePath
      || controls.retentionExecutionPreflight?.status
        !== 'implemented-fail-closed-policy-and-staging-gates-open'
      || controls.retentionExecutionPreflight?.executionAllowed !== false
      || controls.retentionExecutionPreflight?.destructiveRouteExposed !== false
      || controls.retentionExecutionPreflight?.technicalEvidenceRef
        !== retentionExecutionPreflightEvidencePath
      || controls.legalHold?.status !== 'technical-enforcement-implemented-policy-process-open'
      || controls.legalHold?.accountDeletionPreflightBlocked !== true
      || controls.legalHold?.adminStepUpRequired !== true
      || controls.legalHold?.supportRoleDenied !== true
      || controls.legalHold?.idempotentLifecycle !== true
      || controls.legalHold?.technicalEvidenceRef !== legalHoldEvidencePath) {
    fail('Credential cleanup and retention controls must stay technically enforced and policy-fail-closed.');
  }
  const executionPreflight = assessRetentionExecutionReadiness({
    retentionManifest: retention,
    privacyManifest: privacy,
  });
  if (executionPreflight.status !== 'blocked'
      || executionPreflight.executionAllowed !== false
      || executionPreflight.destructiveRouteExposed !== false
      || (retention.state === 'draft' && executionPreflight.blockerCount < 1)) {
    fail('Retention execution preflight must expose all current blockers and remain non-destructive.');
  }
  if (controls.backups?.observedRotationDays !== 14
      || controls.backups?.accountSpecificEraseFromExistingBackups !== false) {
    fail('Backup readiness must match the observed operational boundary.');
  }

  const decisions = object(retention.requiredDecisions, 'requiredDecisions');
  exactKeys(decisions, decisionKeys, 'requiredDecisions');
  for (const key of decisionKeys) {
    const decision = object(decisions[key], `requiredDecisions.${key}`);
    exactKeys(decision, ['status', 'value', 'evidenceRef'], `requiredDecisions.${key}`);
    if (!['open', 'closed'].includes(decision.status)) fail(`requiredDecisions.${key}.status must be open or closed.`);
    if (decision.status === 'open' && (decision.value !== null || decision.evidenceRef !== null)) {
      fail(`Open decision ${key} must not claim a value or evidence.`);
    }
    if (decision.status === 'closed' && (typeof decision.value !== 'string' || !decision.value.trim()
        || typeof decision.evidenceRef !== 'string' || !decision.evidenceRef.startsWith('docs/evidence/b11/'))) {
      fail(`Closed decision ${key} requires an evidence-backed value.`);
    }
  }

  const preparation = object(retention.decisionPreparation, 'decisionPreparation');
  exactKeys(preparation, [
    'status',
    'matrixRef',
    'evidenceRef',
    'preparedDecisionCount',
    'closedDecisionCount',
    'categoryPurgeEnabled',
  ], 'decisionPreparation');
  if (preparation.status !== 'recommendations-prepared-owner-and-legal-approval-open'
      || preparation.matrixRef !== decisionPreparationMatrixPath
      || preparation.evidenceRef !== decisionPreparationEvidencePath
      || preparation.preparedDecisionCount !== decisionKeys.length
      || preparation.closedDecisionCount !== 0
      || preparation.categoryPurgeEnabled !== false) {
    fail('Retention decision preparation must bind all nine open decisions and remain fail closed.');
  }

  const processors = object(retention.externalProcessors, 'externalProcessors');
  for (const processor of externalProcessorKeys) {
    const processorState = object(processors[processor], `externalProcessors.${processor}`);
    exactKeys(processorState, [
      'retentionOwnerVerified',
      'deletionProcedureVerified',
      'officialDocumentationReviewed',
      'officialEvidenceRef',
      'serviceReadinessRef',
      'ownerEvidenceRef',
    ], `externalProcessors.${processor}`);
    if (typeof processorState.retentionOwnerVerified !== 'boolean'
        || typeof processorState.deletionProcedureVerified !== 'boolean'
        || processorState.officialDocumentationReviewed !== true
        || processorState.officialEvidenceRef !== providerEvidencePath) {
      fail(`${processor} must keep boolean verification flags and reference the reviewed official-source evidence.`);
    }
    const expectedServiceReadinessRef = firebaseServiceReadinessPaths[processor] ?? null;
    if (processorState.serviceReadinessRef !== expectedServiceReadinessRef) {
      fail(`${processor} must reference only its own service-specific readiness evidence.`);
    }
    const verified = processorState.retentionOwnerVerified
      && processorState.deletionProcedureVerified;
    if (decisions.externalProcessorRetention.status === 'open'
        && (verified || processorState.ownerEvidenceRef !== null)) {
      fail(`${processor} must remain unverified and without owner evidence while the owner decision is open.`);
    }
    if (decisions.externalProcessorRetention.status === 'closed'
        && (!verified
          || typeof processorState.ownerEvidenceRef !== 'string'
          || !processorState.ownerEvidenceRef.startsWith('docs/evidence/b11/')
          || processorState.ownerEvidenceRef === providerEvidencePath
          || processorState.ownerEvidenceRef === processorState.serviceReadinessRef)) {
      fail(`${processor} requires separate owner evidence when external processor retention is closed.`);
    }
  }
  if (retention.storeGate?.privacyDecision !== 'retentionAndDeletionSchedule'
      || retention.storeGate?.status !== privacy.requiredDecisions?.retentionAndDeletionSchedule?.status) {
    fail('Retention store gate must match the privacy retentionAndDeletionSchedule decision.');
  }
  if (retention.boundaries?.legalPeriodsInvented !== false
      || typeof retention.boundaries?.legalApproval !== 'boolean') {
    fail('Retention readiness must not invent legal periods and must record legal approval explicitly.');
  }

  const allClosed = decisionKeys.every((key) => decisions[key].status === 'closed');
  if (retention.state === 'draft' && (retention.approvalAllowed || retention.boundaries.legalApproval)) {
    fail('Draft retention readiness must remain unapproved.');
  }
  if (retention.state === 'approved' && (!retention.approvalAllowed || !allClosed
      || !retention.boundaries.legalApproval || retention.storeGate.status !== 'closed')) {
    fail('Approved retention readiness requires all decisions and the Store gate to be closed.');
  }
  if (requireApproved && retention.state !== 'approved') fail('Approved retention and deletion readiness is required.');
  return {
    state: retention.state,
    approvalAllowed: retention.approvalAllowed,
    openDecisionCount: decisionKeys.filter((key) => decisions[key].status === 'open').length,
    storeGate: retention.storeGate.status,
  };
}

function runCli() {
  const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
  const retentionManifest = JSON.parse(readFileSync(resolve(root, 'store/retention-deletion-readiness.json'), 'utf8'));
  const privacyManifest = JSON.parse(readFileSync(resolve(root, 'store/privacy-disclosures.json'), 'utf8'));
  const result = validateRetentionDeletionReadiness({
    root,
    retentionManifest,
    privacyManifest,
    requireApproved: process.argv.includes('--require-approved'),
  });
  const execution = assessRetentionExecutionReadiness({
    retentionManifest,
    privacyManifest,
  });
  console.log(`Retention/deletion readiness valid: state=${result.state}, openDecisions=${result.openDecisionCount}, storeGate=${result.storeGate}, executionPreflight=${execution.status}, executionBlockers=${execution.blockerCount}`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  try {
    runCli();
  } catch (error) {
    console.error(`ERROR: ${error.message}`);
    process.exitCode = 1;
  }
}
