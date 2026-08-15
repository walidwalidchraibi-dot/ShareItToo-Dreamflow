#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const documentContract = {
  terms: {
    sourceFile: 'lib/screens/legal_terms_screen.dart',
    publicPath: '/terms',
  },
  communityRules: {
    sourceFile: 'lib/screens/legal_community_rules_screen.dart',
    publicPath: '/community-rules',
  },
  cancellationPolicy: {
    sourceFile: 'lib/screens/legal_cancellation_policy_screen.dart',
    publicPath: '/cancellation-policy',
  },
  feesAndPayments: {
    sourceFile: 'lib/screens/legal_fees_payments_screen.dart',
    publicPath: '/fees-and-payments',
  },
  privacy: {
    sourceFile: 'lib/screens/legal_privacy_screen.dart',
    publicPath: '/privacy',
  },
  imprint: {
    sourceFile: 'lib/screens/legal_imprint_screen.dart',
    publicPath: '/imprint',
  },
};

const consentSourceContract = {
  registrationSource: 'lib/screens/register_screen.dart',
  authServiceSource: 'lib/services/auth_service.dart',
  backendSource: 'backend/src/app.js',
};

const requiredApprovalKeys = [
  'legalProviderIdentity',
  'copyrightOwner',
  'legalReview',
  'userContentModerationPolicy',
  'cancellationRefundNoDepositConsistency',
];

const interimPilotDecisionContract = [
  {
    manifestKey: 'platformContractAndWithdrawalTiming',
    sourceId: 'platform_contract_and_withdrawal_timing',
    interimRule: 'versioned-separate-declarations-at-booking-request',
    blocksLiveActivation: true,
  },
  {
    manifestKey: 'withdrawalEffectOnPrivateRental',
    sourceId: 'withdrawal_effect_on_private_rental',
    interimRule: 'record-and-confirm-without-automatic-booking-or-money-effect',
    blocksLiveActivation: true,
  },
  {
    manifestKey: 'cancellationParameters',
    sourceId: 'cancellation_50_100_or_30_50',
    interimRule: '50-percent-retained-under-24h-and-100-percent-after-start',
    blocksLiveActivation: true,
  },
  {
    manifestKey: 'marketplacePspMechanics',
    sourceId: 'marketplace_psp_mechanics',
    interimRule: 'test-and-mock-only-no-real-money-movement',
    blocksLiveActivation: true,
  },
  {
    manifestKey: 'missingReturnConfirmationWindow',
    sourceId: 'missing_return_confirmation_window',
    interimRule: 'awaiting-return-confirmation-until-t0-plus-5-calendar-days',
    blocksLiveActivation: false,
  },
  {
    manifestKey: 'handoverPhotoWorkflow',
    sourceId: 'handover_photo_workflow',
    interimRule: 'four-photos-each-direction-with-counter-confirmation-or-deviation-photo',
    blocksLiveActivation: false,
  },
];

const forbiddenSensitiveKeys = /^(password|secret|token|apiKey|privateKey|serviceAccount|credential|reviewAccount)$/i;

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
  if (typeof value !== 'string' || value.trim() === '') {
    fail(`${label} must be a non-empty string.`);
  }
  return value.trim();
}

function sha256(contents) {
  return createHash('sha256').update(contents).digest('hex');
}

function assertSha256(value, label) {
  if (typeof value !== 'string' || !/^[a-f0-9]{64}$/.test(value)) {
    fail(`${label} must be a lowercase SHA-256 value.`);
  }
}

function assertNoSensitiveFields(value, label = 'legal readiness') {
  if (Array.isArray(value)) {
    value.forEach((entry, index) => assertNoSensitiveFields(entry, `${label}[${index}]`));
    return;
  }
  if (value === null || typeof value !== 'object') return;
  for (const [key, entry] of Object.entries(value)) {
    if (forbiddenSensitiveKeys.test(key)) {
      fail(`${label}.${key} must never contain credentials or secrets.`);
    }
    assertNoSensitiveFields(entry, `${label}.${key}`);
  }
}

function sourceText(root, sourceTexts, path) {
  if (Object.hasOwn(sourceTexts, path)) return sourceTexts[path];
  return readFileSync(resolve(root, path), 'utf8');
}

function assertExplicitConsentContract({ root, sourceTexts, consent }) {
  for (const [key, expectedPath] of Object.entries(consentSourceContract)) {
    if (consent[key] !== expectedPath) {
      fail(`consentContract.${key} must be ${expectedPath}.`);
    }
  }

  const registration = sourceText(root, sourceTexts, consent.registrationSource);
  for (const marker of [
    '_minimumAgeConfirmed',
    '_termsAccepted',
    '_privacyAccepted',
    '_privateUseConfirmed',
    'Ich bin 18 Jahre oder älter.',
    'Ich akzeptiere die AGB.',
    'Ich akzeptiere die Datenschutzbestimmungen.',
    'termsAccepted: _termsAccepted',
    'privacyAccepted: _privacyAccepted',
    'minimumAgeConfirmed: _minimumAgeConfirmed',
    'privateUseConfirmed: _privateUseConfirmed',
  ]) {
    if (!registration.includes(marker)) {
      fail(`Registration consent contract is missing: ${marker}`);
    }
  }

  const authService = sourceText(root, sourceTexts, consent.authServiceSource);
  for (const marker of [
    'required bool termsAccepted',
    'required bool privacyAccepted',
    'required bool minimumAgeConfirmed',
    'required bool privateUseConfirmed',
    '!termsAccepted',
    '!privacyAccepted',
    '!minimumAgeConfirmed',
    '!privateUseConfirmed',
    "'termsAccepted': termsAccepted",
    "'privacyAccepted': privacyAccepted",
    "'minimumAgeConfirmed': minimumAgeConfirmed",
    "'privateUseConfirmed': privateUseConfirmed",
  ]) {
    if (!authService.includes(marker)) {
      fail(`Auth consent contract is missing: ${marker}`);
    }
  }
  for (const forbidden of [
    /['\"]termsAccepted['\"]\s*:\s*true/,
    /['\"]privacyAccepted['\"]\s*:\s*true/,
    /['\"]minimumAgeConfirmed['\"]\s*:\s*true/,
    /['\"]privateUseConfirmed['\"]\s*:\s*true/,
  ]) {
    if (forbidden.test(authService)) {
      fail('Auth consent values must never be hardcoded to true.');
    }
  }

  const backend = sourceText(root, sourceTexts, consent.backendSource);
  for (const marker of [
    'req.body?.termsAccepted !== true',
    'req.body?.privacyAccepted !== true',
    'req.body?.minimumAgeConfirmed !== true',
    'req.body?.privateUseConfirmed !== true',
    'registration_consents_required',
    'terms_accepted_at, privacy_accepted_at, minimum_age_confirmed_at',
  ]) {
    if (!backend.includes(marker)) {
      fail(`Backend consent contract is missing: ${marker}`);
    }
  }
}

function assertProviderIdentityFailsClosed({ root, sourceTexts }) {
  const config = sourceText(
    root,
    sourceTexts,
    'lib/config/legal_provider_config.dart',
  );
  const imprint = sourceText(
    root,
    sourceTexts,
    'lib/screens/legal_imprint_screen.dart',
  );
  for (const marker of [
    'SIT_LEGAL_PROVIDER_APPROVED',
    'defaultValue: false',
    'SIT_LEGAL_PROVIDER_NAME',
    'SIT_LEGAL_PROVIDER_ADDRESS',
    'SIT_LEGAL_REPRESENTATIVE',
    'SIT_LEGAL_CONTENT_RESPONSIBLE',
    'hasCompleteApprovedIdentity',
  ]) {
    if (!config.includes(marker)) {
      fail(`Legal provider configuration is missing: ${marker}`);
    }
  }
  if (!imprint.includes('LegalProviderConfig.hasCompleteApprovedIdentity')) {
    fail('Imprint must be gated by a complete approved provider identity.');
  }
  for (const forbidden of ['ShareItToo GmbH', '+49 176 47105994']) {
    if (imprint.includes(forbidden)) {
      fail(`Imprint must not hardcode an unapproved provider value: ${forbidden}`);
    }
  }
}

function assertInterimPilotContract({ root, sourceTexts, legal }) {
  const policy = object(legal.interimPilotRules, 'interimPilotRules');
  const expectedPolicyKeys = [
    'realPaymentsEnabled',
    'replaceOnUserInstruction',
    'status',
    'version',
  ];
  if (Object.keys(policy).sort().join(',') !== expectedPolicyKeys.sort().join(',')) {
    fail('interimPilotRules must contain exactly the versioned active test policy.');
  }
  if (policy.version !== 'V4-INTERIM-2026-08-15') {
    fail('interimPilotRules.version must remain V4-INTERIM-2026-08-15 until the user supplies an update.');
  }
  if (policy.status !== 'active-for-internal-and-closed-testing') {
    fail('interimPilotRules.status must remain active for internal and closed testing.');
  }
  if (policy.realPaymentsEnabled !== false) {
    fail('interimPilotRules.realPaymentsEnabled must remain false.');
  }
  if (policy.replaceOnUserInstruction !== true) {
    fail('interimPilotRules.replaceOnUserInstruction must remain true.');
  }

  const decisions = object(legal.openPilotDecisions, 'openPilotDecisions');
  const expectedKeys = interimPilotDecisionContract.map(({ manifestKey }) => manifestKey);
  if (Object.keys(decisions).sort().join(',') !== expectedKeys.sort().join(',')) {
    fail('openPilotDecisions must contain exactly all six V4 interim decisions.');
  }
  for (const expected of interimPilotDecisionContract) {
    const decision = object(
      decisions[expected.manifestKey],
      `openPilotDecisions.${expected.manifestKey}`,
    );
    if (decision.status !== 'open') {
      fail(`openPilotDecisions.${expected.manifestKey}.status must remain open until the user supplies an update.`);
    }
    if (decision.interimRule !== expected.interimRule) {
      fail(`openPilotDecisions.${expected.manifestKey}.interimRule does not match the active V4 rule.`);
    }
    nonEmptyString(
      decision.decisionBy,
      `openPilotDecisions.${expected.manifestKey}.decisionBy`,
    );
    if (decision.activeForInternalTesting !== true) {
      fail(`openPilotDecisions.${expected.manifestKey} must remain active for internal testing.`);
    }
    if (decision.blocksLiveActivation !== expected.blocksLiveActivation) {
      fail(`openPilotDecisions.${expected.manifestKey}.blocksLiveActivation is inconsistent.`);
    }
  }

  const dartConfig = sourceText(
    root,
    sourceTexts,
    'lib/config/private_pilot_config.dart',
  );
  const backendDomain = sourceText(
    root,
    sourceTexts,
    'backend/src/private_pilot_domain.js',
  );
  for (const marker of [
    "interimPolicyVersion = 'V4-INTERIM-2026-08-15'",
    "interimPolicyScope = 'internal-and-closed-testing-only'",
    'interimLegalModelEnabled = true',
    'replaceInterimRulesOnUserInstruction = true',
    'realPaymentsEnabled = false',
  ]) {
    if (!dartConfig.includes(marker)) {
      fail(`Flutter interim policy is missing or inactive: ${marker}`);
    }
  }
  for (const marker of [
    "version: 'V4-INTERIM-2026-08-15'",
    "scope: 'internal-and-closed-testing-only'",
    'active: true',
    'realPaymentsEnabled: false',
    'replaceOnUserInstruction: true',
  ]) {
    if (!backendDomain.includes(marker)) {
      fail(`Backend interim policy is missing or inactive: ${marker}`);
    }
  }
  for (const { sourceId } of interimPilotDecisionContract) {
    const marker = `id: '${sourceId}'`;
    if (!dartConfig.includes(marker)) {
      fail(`Flutter open decision is missing: ${sourceId}`);
    }
    if (!backendDomain.includes(marker)) {
      fail(`Backend open decision is missing: ${sourceId}`);
    }
  }
}

function assertApprovedDocument(item, contract, label) {
  if (item.status !== 'approved') fail(`${label}.status must be approved.`);
  assertSha256(item.approvedContentSha256, `${label}.approvedContentSha256`);
  if (item.approvedContentSha256 !== item.currentContentSha256) {
    fail(`${label}.approvedContentSha256 must match the current reviewed content.`);
  }
  const url = new URL(nonEmptyString(item.publicUrl, `${label}.publicUrl`));
  if (url.protocol !== 'https:' || url.hostname !== 'shareittoo.com' || url.pathname !== contract.publicPath) {
    fail(`${label}.publicUrl must be the canonical HTTPS ShareItToo legal page.`);
  }
  nonEmptyString(item.approvalEvidenceRef, `${label}.approvalEvidenceRef`);
}

export function validateLegalReadiness({
  root,
  legalManifest,
  submissionManifest,
  sourceTexts = {},
  requireApproved = false,
}) {
  const legal = object(legalManifest, 'store/legal-readiness.json');
  const submission = object(submissionManifest, 'store/submission.json');
  assertNoSensitiveFields(legal);

  if (legal.schemaVersion !== 1) fail('legal readiness schemaVersion must be 1.');
  if (!['draft', 'approved'].includes(legal.state)) {
    fail('legal readiness state must be draft or approved.');
  }
  if (typeof legal.approvalAllowed !== 'boolean') {
    fail('legal readiness approvalAllowed must be boolean.');
  }

  const consent = object(legal.consentContract, 'consentContract');
  if (consent.minimumUserAge !== 18 || submission.product?.minimumUserAge !== 18) {
    fail('The registration and store minimum age must both remain 18.');
  }
  const confirmations = consent.explicitConfirmations;
  if (!Array.isArray(confirmations)
      || confirmations.join(',') !== 'minimumAge,terms,privacy,privateUse') {
    fail('consentContract.explicitConfirmations must contain minimumAge, terms, privacy, and privateUse in order.');
  }
  const expectedTechnicalStatus = legal.state === 'approved'
    ? 'explicit-versioned-approved'
    : 'explicit-unversioned-draft';
  if (consent.technicalStatus !== expectedTechnicalStatus) {
    fail(`consentContract.technicalStatus must be ${expectedTechnicalStatus} for state=${legal.state}.`);
  }
  assertExplicitConsentContract({ root, sourceTexts, consent });
  assertProviderIdentityFailsClosed({ root, sourceTexts });
  assertInterimPilotContract({ root, sourceTexts, legal });

  const documents = object(legal.documents, 'documents');
  if (Object.keys(documents).sort().join(',') !== Object.keys(documentContract).sort().join(',')) {
    fail('documents must contain exactly the required legal documents.');
  }
  for (const [key, contract] of Object.entries(documentContract)) {
    const item = object(documents[key], `documents.${key}`);
    if (item.sourceFile !== contract.sourceFile) {
      fail(`documents.${key}.sourceFile must be ${contract.sourceFile}.`);
    }
    assertSha256(item.currentContentSha256, `documents.${key}.currentContentSha256`);
    const actualHash = sha256(sourceText(root, sourceTexts, item.sourceFile));
    if (actualHash !== item.currentContentSha256) {
      fail(`documents.${key}.currentContentSha256 is stale.`);
    }
    if (!['draft', 'approved'].includes(item.status)) {
      fail(`documents.${key}.status must be draft or approved.`);
    }
    if (item.status === 'draft') {
      if (item.approvedContentSha256 !== null || item.publicUrl !== null || item.approvalEvidenceRef !== null) {
        fail(`documents.${key} draft must not claim an approved hash, URL, or approval evidence.`);
      }
    } else {
      assertApprovedDocument(item, contract, `documents.${key}`);
    }
  }

  const approvals = object(legal.requiredApprovals, 'requiredApprovals');
  if (Object.keys(approvals).sort().join(',') !== requiredApprovalKeys.slice().sort().join(',')) {
    fail('requiredApprovals must contain exactly the required legal approvals.');
  }
  for (const key of requiredApprovalKeys) {
    const approval = object(approvals[key], `requiredApprovals.${key}`);
    if (Object.keys(approval).sort().join(',') !== 'evidenceRef,status') {
      fail(`requiredApprovals.${key} must contain exactly status and evidenceRef.`);
    }
    if (!['open', 'closed'].includes(approval.status)) {
      fail(`requiredApprovals.${key}.status must be open or closed.`);
    }
    if (approval.status === 'open') {
      if (approval.evidenceRef !== null) {
        fail(`requiredApprovals.${key} open must not reference approval evidence.`);
      }
    } else {
      const ref = nonEmptyString(
        approval.evidenceRef,
        `requiredApprovals.${key}.evidenceRef`,
      );
      if (!ref.startsWith('docs/evidence/b11/') || ref.includes('..') || !ref.endsWith('.json')) {
        fail(`requiredApprovals.${key}.evidenceRef must stay under docs/evidence/b11.`);
      }
    }
  }

  const linkedApprovalGates = {
    legalProviderIdentity: 'legalProviderIdentity',
    copyrightOwner: 'copyrightOwner',
  };
  for (const [approvalKey, gateKey] of Object.entries(linkedApprovalGates)) {
    if (approvals[approvalKey].status !== submission.blockingGates?.[gateKey]) {
      fail(`requiredApprovals.${approvalKey} must match blockingGates.${gateKey}.`);
    }
  }

  const storeGate = object(legal.storeGate, 'storeGate');
  if (storeGate.field !== 'blockingGates.termsAndUserContentRules') {
    fail('storeGate.field must reference blockingGates.termsAndUserContentRules.');
  }
  if (storeGate.status !== submission.blockingGates?.termsAndUserContentRules) {
    fail('The legal readiness store gate must match store/submission.json.');
  }

  const boundaries = object(legal.boundaries, 'boundaries');
  for (const key of [
    'legalApproval',
    'storeSubmissionChanged',
    'publicRoutesChanged',
    'containsSecrets',
    'containsAccountData',
  ]) {
    if (boundaries[key] !== false) fail(`boundaries.${key} must be false.`);
  }

  const allDocumentsApproved = Object.values(documents).every((item) => item.status === 'approved');
  const allApprovalsClosed = requiredApprovalKeys.every(
    (key) => approvals[key].status === 'closed',
  );
  const allApprovalsOpen = requiredApprovalKeys.every(
    (key) => approvals[key].status === 'open',
  );
  const approved = legal.state === 'approved'
    && legal.approvalAllowed === true
    && allDocumentsApproved
    && allApprovalsClosed
    && storeGate.status === 'closed';

  if (legal.state === 'draft') {
    if (legal.approvalAllowed !== false || storeGate.status !== 'open' || !allApprovalsOpen) {
      fail('Draft legal readiness must fail closed with approvalAllowed=false and every legal approval open.');
    }
  } else if (!approved) {
    fail('Approved legal readiness is internally incomplete.');
  }

  if (requireApproved && !approved) {
    fail('Legal approval is required, but the repository remains in an honest draft state.');
  }

  return {
    state: legal.state,
    approvalAllowed: legal.approvalAllowed,
    storeGate: storeGate.status,
    documentCount: Object.keys(documents).length,
    explicitConfirmations: confirmations.length,
    interimPolicyVersion: legal.interimPilotRules.version,
    activeOpenPilotDecisions: interimPilotDecisionContract.length,
  };
}

function parseArgs(argv) {
  let requireApproved = false;
  for (const arg of argv) {
    if (arg === '--require-approved') requireApproved = true;
    else fail(`Unknown argument: ${arg}`);
  }
  return { requireApproved };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const root = fileURLToPath(new URL('../', import.meta.url));
  const result = validateLegalReadiness({
    root,
    legalManifest: JSON.parse(readFileSync(resolve(root, 'store/legal-readiness.json'), 'utf8')),
    submissionManifest: JSON.parse(readFileSync(resolve(root, 'store/submission.json'), 'utf8')),
    requireApproved: args.requireApproved,
  });
  console.log(
    `Legal readiness valid: state=${result.state}, approvalAllowed=${result.approvalAllowed}, `
      + `termsAndUserContentRules=${result.storeGate}, interimPolicy=${result.interimPolicyVersion}, `
      + `activeOpenPilotDecisions=${result.activeOpenPilotDecisions}.`,
  );
}

const isDirectRun = process.argv[1]
  && import.meta.url === pathToFileURL(resolve(process.argv[1])).href;
if (isDirectRun) {
  try {
    main();
  } catch (error) {
    console.error(`ERROR: ${error.message}`);
    process.exitCode = 1;
  }
}
