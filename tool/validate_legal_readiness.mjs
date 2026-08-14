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
    'Ich bin 18 Jahre oder älter.',
    'Ich akzeptiere die AGB.',
    'Ich akzeptiere die Datenschutzbestimmungen.',
    'termsAccepted: _termsAccepted',
    'privacyAccepted: _privacyAccepted',
    'minimumAgeConfirmed: _minimumAgeConfirmed',
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
    'if (!termsAccepted || !privacyAccepted || !minimumAgeConfirmed)',
    "'termsAccepted': termsAccepted",
    "'privacyAccepted': privacyAccepted",
    "'minimumAgeConfirmed': minimumAgeConfirmed",
  ]) {
    if (!authService.includes(marker)) {
      fail(`Auth consent contract is missing: ${marker}`);
    }
  }
  for (const forbidden of [
    /['\"]termsAccepted['\"]\s*:\s*true/,
    /['\"]privacyAccepted['\"]\s*:\s*true/,
    /['\"]minimumAgeConfirmed['\"]\s*:\s*true/,
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
  if (!Array.isArray(confirmations) || confirmations.join(',') !== 'minimumAge,terms,privacy') {
    fail('consentContract.explicitConfirmations must contain minimumAge, terms, and privacy in order.');
  }
  const expectedTechnicalStatus = legal.state === 'approved'
    ? 'explicit-versioned-approved'
    : 'explicit-unversioned-draft';
  if (consent.technicalStatus !== expectedTechnicalStatus) {
    fail(`consentContract.technicalStatus must be ${expectedTechnicalStatus} for state=${legal.state}.`);
  }
  assertExplicitConsentContract({ root, sourceTexts, consent });
  assertProviderIdentityFailsClosed({ root, sourceTexts });

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
      + `termsAndUserContentRules=${result.storeGate}.`,
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
