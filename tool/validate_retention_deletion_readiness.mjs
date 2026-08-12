#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const sourcePaths = [
  'backend/src/app.js',
  'backend/src/privacy_export.js',
  'backend/src/account_actions.js',
  'backend/src/config.js',
  'backend/sql/schema.sql',
  'backend/sql/migrations/006_b7_communications.up.sql',
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

const requiredOfficialSources = [
  ['Firebase Cloud Messaging', 'https://firebase.google.com/support/privacy/', 'within 180 days'],
  ['Firebase Crashlytics', 'https://firebase.google.com/support/privacy/', 'retained for 90 days'],
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

  const controls = object(retention.implementedControls, 'implementedControls');
  if (controls.accountErasure?.status !== 'implemented-integration-covered'
      || controls.accountErasure?.notificationResidue !== 'deleted-or-scrubbed') {
    fail('Account erasure residual-data coverage must be recorded.');
  }
  if (controls.credentialExpiry?.automaticExpiredRowPurge !== false
      || controls.categoryPurge?.status !== 'not-implemented'
      || controls.legalHold?.status !== 'not-implemented') {
    fail('Unimplemented retention controls must stay fail-closed.');
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
  for (const processor of ['firebaseCloudMessaging', 'firebaseCrashlytics', 'googleMapsPlatform']) {
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
