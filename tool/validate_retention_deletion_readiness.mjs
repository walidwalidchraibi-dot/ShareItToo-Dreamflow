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
  'backend/src/retention_inventory.js',
  'backend/src/privacy_export.js',
  'backend/src/account_actions.js',
  'backend/src/config.js',
  'backend/src/v51_contract_workflow.js',
  'backend/src/v51_contract_receipt.js',
  'backend/src/v51_withdrawal_workflow.js',
  'backend/src/booking_condition_evidence_workflow.js',
  'backend/sql/schema.sql',
  'backend/sql/migrations/006_b7_communications.up.sql',
  'backend/sql/migrations/014_account_legal_holds.up.sql',
  'backend/sql/migrations/015_v51_contract_persistence.up.sql',
  'backend/sql/migrations/016_v51_booking_quotes.up.sql',
  'backend/sql/migrations/017_v51_contract_receipts.up.sql',
  'backend/sql/migrations/018_v51_withdrawal_and_refund_obligations.up.sql',
  'backend/sql/migrations/019_v51_condition_evidence.up.sql',
  'backend/ops/backup.sh',
  'lib/screens/legal_privacy_screen.dart',
  'lib/screens/privacy_info_screen.dart',
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

const providerEvidencePath = 'docs/evidence/b11/privacy-provider-retention-sources-20260812.json';
const credentialCleanupEvidencePath = 'docs/evidence/b11/expired-credential-cleanup-20260815.json';
const legalHoldEvidencePath = 'docs/evidence/b11/account-legal-hold-20260815.json';
const retentionInventoryEvidencePath = 'docs/evidence/b11/retention-inventory-20260815.json';

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

function assertSourceContracts(root, sourceTexts) {
  const app = text(root, sourceTexts, 'backend/src/app.js');
  for (const marker of [
    'DELETE FROM notification_preferences WHERE user_id = $1',
    'DELETE FROM notifications WHERE user_id = $1',
    'DELETE FROM message_reads WHERE user_id = $1',
    'DELETE FROM user_blocks WHERE blocker_id = $1 OR blocked_id = $1',
    "payload = '{}'::jsonb",
    "'account_deleted'",
    'pseudonymous_notification_delivery_audit',
  ]) {
    if (!app.includes(marker)) fail(`Account erasure is missing the residual-data control: ${marker}.`);
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
  if (/DELETE\s+FROM|UPDATE\s+[a-z_]+\s+SET/iu.test(inventory)) {
    fail('Retention inventory must remain read-only.');
  }
  if (!app.includes('/v1/admin/privacy/retention-inventory')
      || !app.includes('inspectRetentionInventory(client, { actor: req.actor })')) {
    fail('The admin retention-inventory route is missing.');
  }
  const backup = text(root, sourceTexts, 'backend/ops/backup.sh');
  if (!backup.includes('-mtime +14 -delete')) fail('The observed 14-day backup rotation contract is missing.');
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
  assertCredentialCleanupEvidence(root, evidenceTexts);
  assertLegalHoldEvidence(root, evidenceTexts);
  assertRetentionInventoryEvidence(root, evidenceTexts);

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
      || controls.legalHold?.status !== 'technical-enforcement-implemented-policy-process-open'
      || controls.legalHold?.accountDeletionPreflightBlocked !== true
      || controls.legalHold?.adminStepUpRequired !== true
      || controls.legalHold?.supportRoleDenied !== true
      || controls.legalHold?.idempotentLifecycle !== true
      || controls.legalHold?.technicalEvidenceRef !== legalHoldEvidencePath) {
    fail('Credential cleanup and retention controls must stay technically enforced and policy-fail-closed.');
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

  const processors = object(retention.externalProcessors, 'externalProcessors');
  for (const processor of [
    'firebaseCloudMessaging',
    'firebaseCrashlytics',
    'firebaseAuthentication',
    'googleMapsPlatform',
  ]) {
    const processorState = object(processors[processor], `externalProcessors.${processor}`);
    exactKeys(processorState, [
      'retentionOwnerVerified',
      'deletionProcedureVerified',
      'officialDocumentationReviewed',
      'officialEvidenceRef',
      'ownerEvidenceRef',
    ], `externalProcessors.${processor}`);
    if (typeof processorState.retentionOwnerVerified !== 'boolean'
        || typeof processorState.deletionProcedureVerified !== 'boolean'
        || processorState.officialDocumentationReviewed !== true
        || processorState.officialEvidenceRef !== providerEvidencePath) {
      fail(`${processor} must keep boolean verification flags and reference the reviewed official-source evidence.`);
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
          || processorState.ownerEvidenceRef === providerEvidencePath)) {
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
  console.log(`Retention/deletion readiness valid: state=${result.state}, openDecisions=${result.openDecisionCount}, storeGate=${result.storeGate}`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  try {
    runCli();
  } catch (error) {
    console.error(`ERROR: ${error.message}`);
    process.exitCode = 1;
  }
}
