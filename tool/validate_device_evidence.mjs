#!/usr/bin/env node

import { lstatSync, readFileSync, realpathSync } from 'node:fs';
import { isAbsolute, relative, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const requiredCells = new Map([
  ['android-wifi-owner', { platform: 'android', network: 'wifi', role: 'owner' }],
  ['android-hotspot-renter', { platform: 'android', network: 'hotspot', role: 'renter' }],
  ['ios-wifi-owner', { platform: 'ios', network: 'wifi', role: 'owner' }],
  ['ios-hotspot-renter', { platform: 'ios', network: 'hotspot', role: 'renter' }],
]);

const requiredDeviceTests = [
  'installAndFirstStart',
  'authenticationAndSession',
  'listingAndBooking',
  'chatAndDeepLink',
  'pushForeground',
  'pushBackground',
  'pushTerminated',
  'handoverAndReturn',
  'moderationAndAccount',
  'offlineRecovery',
  'largeTextAndScreenReader',
];

const requiredReleaseChecks = [
  'candidateIdentityAndSignatures',
  'firebaseFcmAndApns',
  'binaryPrivacyAndNetwork',
  'crashReleaseMapping',
  'storeWarningsLinksAndSigning',
  'stagingCleanupAndHealth',
  'productionInvariant',
];

const deviceGateKeys = [
  'realAndroidAndIosDevices',
  'finalBinaryPrivacyScan',
  'closedStoreAndAccessibilityMatrix',
];

const allowedProgressStates = new Set(['open', 'testing', 'passed', 'failed', 'blocked']);
const forbiddenSecretKeys = /^(password|secret|token|apiKey|privateKey|serviceAccount|reviewCredentials|reviewPassword|reviewUsername)$/i;
const forbiddenDeviceIdentifierKeys = /^(serial|serialNumber|androidId|advertisingId|imei|meid|idfa|udid)$/i;

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

function nullableString(value, label) {
  if (value === null) return null;
  return nonEmptyString(value, label);
}

function assertNoSensitiveFields(value, label = 'device validation') {
  if (Array.isArray(value)) {
    value.forEach((entry, index) => assertNoSensitiveFields(entry, `${label}[${index}]`));
    return;
  }
  if (value === null || typeof value !== 'object') return;
  for (const [key, entry] of Object.entries(value)) {
    if (forbiddenSecretKeys.test(key)) {
      fail(`${label}.${key} must never contain credentials or secrets.`);
    }
    if (forbiddenDeviceIdentifierKeys.test(key)) {
      fail(`${label}.${key} must never contain a raw device identifier.`);
    }
    assertNoSensitiveFields(entry, `${label}.${key}`);
  }
}

function assertSha256(value, label, { required }) {
  if (value === null && !required) return;
  if (typeof value !== 'string' || !/^[a-f0-9]{64}$/i.test(value)) {
    fail(`${label} must be a 64-character SHA-256 value.`);
  }
}

function evidenceRef(root, value, label, { required }) {
  if (value === null && !required) return null;
  const ref = nonEmptyString(value, label);
  if (isAbsolute(ref) || ref.includes('..') || !ref.startsWith('docs/evidence/b11/')) {
    fail(`${label} must stay below docs/evidence/b11/.`);
  }
  if (required || value !== null) {
    const fullPath = resolve(root, ref);
    const allowedRoot = resolve(root, 'docs/evidence/b11');
    const rel = relative(allowedRoot, fullPath);
    if (rel.startsWith('..') || isAbsolute(rel)) {
      fail(`${label} escapes the B11 evidence directory.`);
    }
    let stat;
    try {
      stat = lstatSync(fullPath);
    } catch {
      fail(`${label} does not exist: ${ref}`);
    }
    if (stat.isSymbolicLink()) {
      fail(`${label} must not reference a symbolic link.`);
    }
    if (!stat.isFile() || stat.size === 0 || stat.size > 1024 * 1024) {
      fail(`${label} must reference a non-empty evidence file.`);
    }
    const canonicalRoot = realpathSync(allowedRoot);
    const canonicalFile = realpathSync(fullPath);
    const canonicalRelative = relative(canonicalRoot, canonicalFile);
    if (canonicalRelative.startsWith('..') || isAbsolute(canonicalRelative)) {
      fail(`${label} must not escape the B11 evidence directory through a linked path.`);
    }
  }
  return ref;
}

function readEvidenceJson(root, ref, label) {
  if (!ref.endsWith('.json')) {
    fail(`${label} must reference a structured JSON evidence file.`);
  }
  let evidence;
  try {
    evidence = JSON.parse(readFileSync(resolve(root, ref), 'utf8'));
  } catch {
    fail(`${label} must contain valid JSON evidence.`);
  }
  object(evidence, label);
  assertNoSensitiveFields(evidence, label);
  return evidence;
}

function assertEvidenceCandidate(evidence, candidate, label) {
  const identity = object(evidence.candidate, `${label}.candidate`);
  for (const key of [
    'applicationId',
    'bundleId',
    'versionName',
    'buildNumber',
    'commit',
    'releaseChannel',
    'apiBaseUrl',
    'firebaseConfigured',
    'paymentMode',
    'stripeLivemode',
  ]) {
    if (identity[key] !== candidate[key]) {
      fail(`${label}.candidate.${key} must match store/device-validation.json.`);
    }
  }
}

function assertEvidenceBoundaries(evidence, label) {
  const boundaries = object(evidence.boundaries, `${label}.boundaries`);
  if (boundaries.containsSecrets !== false ||
      boundaries.containsRawDeviceIdentifiers !== false ||
      boundaries.containsReviewCredentials !== false ||
      boundaries.syntheticAccountsOnly !== true) {
    fail(`${label}.boundaries must prove sanitized, secret-free, synthetic-only evidence.`);
  }
}

function validateDeviceCellEvidence(root, ref, cell, candidate, label) {
  const evidence = readEvidenceJson(root, ref, label);
  if (evidence.schemaVersion !== 1 || evidence.kind !== 'device-matrix-cell' || evidence.status !== 'passed') {
    fail(`${label} must be a passed device-matrix-cell evidence document.`);
  }
  isoTimestamp(evidence.capturedAt, `${label}.capturedAt`, { required: true });
  assertEvidenceCandidate(evidence, candidate, label);
  assertEvidenceBoundaries(evidence, label);

  const recordedCell = object(evidence.cell, `${label}.cell`);
  for (const key of [
    'id',
    'platform',
    'network',
    'role',
    'deviceType',
    'deviceModel',
    'osVersion',
    'storeInstall',
    'screenReader',
  ]) {
    if (recordedCell[key] !== cell[key]) {
      fail(`${label}.cell.${key} must match its device matrix entry.`);
    }
  }
  const tests = object(recordedCell.tests, `${label}.cell.tests`);
  if (Object.keys(tests).length !== requiredDeviceTests.length) {
    fail(`${label}.cell.tests must contain exactly the required B11 device checks.`);
  }
  for (const key of requiredDeviceTests) {
    const result = object(tests[key], `${label}.cell.tests.${key}`);
    if (result.status !== 'passed') {
      fail(`${label}.cell.tests.${key}.status must be passed.`);
    }
    isoTimestamp(result.checkedAt, `${label}.cell.tests.${key}.checkedAt`, { required: true });
    nonEmptyString(result.summary, `${label}.cell.tests.${key}.summary`);
  }
}

function validateLegacyCandidateReleaseEvidence(evidence, candidate, checkId, label) {
  if (evidence.schemaVersion !== 1 || evidence.kind !== 'android-release-candidate') return false;
  assertEvidenceCandidate(evidence, candidate, label);
  const android = object(evidence.android, `${label}.android`);
  const expectedAndroid = object(candidate.android, 'candidate.android');
  for (const key of ['aabSha256', 'apkSha256', 'signingCertificateSha256']) {
    if (android[key] !== expectedAndroid[key]) {
      fail(`${label}.android.${key} must match the candidate manifest.`);
    }
  }
  assertEvidenceBoundaries(evidence, label);

  if (checkId === 'candidateIdentityAndSignatures') {
    if (android.signatureVerified !== true || android.packageIdentityVerified !== true) {
      fail(`${label} does not prove candidate identity and signatures.`);
    }
    return true;
  }
  if (checkId === 'stagingCleanupAndHealth') {
    const staging = object(evidence.staging, `${label}.staging`);
    if (staging.liveHttpStatus !== 200 || staging.readyHttpStatus !== 200) {
      fail(`${label} does not prove healthy staging.`);
    }
    return true;
  }
  if (checkId === 'productionInvariant') {
    if (evidence.staging?.productionInvariant !== 'passed') {
      fail(`${label} does not prove the production invariant.`);
    }
    return true;
  }
  return false;
}

function validateReleaseCheckEvidence(root, ref, checkId, candidate, label) {
  const evidence = readEvidenceJson(root, ref, label);
  if (validateLegacyCandidateReleaseEvidence(evidence, candidate, checkId, label)) return;
  if (evidence.schemaVersion !== 1 || evidence.kind !== 'release-check' || evidence.status !== 'passed') {
    fail(`${label} must be a passed release-check evidence document for ${checkId}.`);
  }
  isoTimestamp(evidence.capturedAt, `${label}.capturedAt`, { required: true });
  assertEvidenceCandidate(evidence, candidate, label);
  assertEvidenceBoundaries(evidence, label);
  const releaseCheck = object(evidence.releaseCheck, `${label}.releaseCheck`);
  if (releaseCheck.id !== checkId || releaseCheck.status !== 'passed') {
    fail(`${label}.releaseCheck must identify ${checkId} as passed.`);
  }
  if (!Array.isArray(releaseCheck.verifications) || releaseCheck.verifications.length === 0) {
    fail(`${label}.releaseCheck.verifications must contain at least one passed verification.`);
  }
  for (const [index, verification] of releaseCheck.verifications.entries()) {
    const item = object(verification, `${label}.releaseCheck.verifications[${index}]`);
    nonEmptyString(item.id, `${label}.releaseCheck.verifications[${index}].id`);
    if (item.status !== 'passed') {
      fail(`${label}.releaseCheck.verifications[${index}].status must be passed.`);
    }
    isoTimestamp(item.checkedAt, `${label}.releaseCheck.verifications[${index}].checkedAt`, { required: true });
    nonEmptyString(item.summary, `${label}.releaseCheck.verifications[${index}].summary`);
  }
}

function validateApprovalEvidence(root, ref, approvalType, approval, candidate, label) {
  const evidence = readEvidenceJson(root, ref, label);
  if (evidence.schemaVersion !== 1 || evidence.kind !== 'approval' || evidence.status !== 'passed') {
    fail(`${label} must be a passed approval evidence document.`);
  }
  assertEvidenceCandidate(evidence, candidate, label);
  assertEvidenceBoundaries(evidence, label);
  const recorded = object(evidence.approval, `${label}.approval`);
  if (recorded.type !== approvalType || recorded.decision !== 'approved' || recorded.approvedAt !== approval.approvedAt) {
    fail(`${label}.approval must match the recorded ${approvalType} approval.`);
  }
  isoTimestamp(recorded.approvedAt, `${label}.approval.approvedAt`, { required: true });
  nonEmptyString(recorded.statement, `${label}.approval.statement`);
}

function parsePubspecVersion(pubspecText) {
  const match = /^version:\s*(\d+\.\d+\.\d+)\+(\d{10})\s*$/m.exec(pubspecText);
  if (!match) fail('pubspec.yaml must use semantic+YYYYMMDDNN versioning.');
  return { versionName: match[1], buildNumber: BigInt(match[2]) };
}

function isoTimestamp(value, label, { required }) {
  if (value === null && !required) return;
  const timestamp = nonEmptyString(value, label);
  if (Number.isNaN(Date.parse(timestamp)) || !/^\d{4}-\d{2}-\d{2}T/.test(timestamp)) {
    fail(`${label} must be an ISO-8601 timestamp.`);
  }
}

export function validateDeviceEvidence({
  root,
  deviceManifest,
  submissionManifest,
  pubspecText,
  requirePassed = false,
}) {
  const manifest = object(deviceManifest, 'store/device-validation.json');
  const submission = object(submissionManifest, 'store/submission.json');
  assertNoSensitiveFields(manifest);

  if (manifest.schemaVersion !== 1) fail('Unsupported device evidence schemaVersion.');
  const state = manifest.state;
  const goNoGo = manifest.goNoGo;
  if (!['planned', 'testing', 'passed'].includes(state)) {
    fail('state must be planned, testing, or passed.');
  }
  if (!['no-go', 'hold', 'go'].includes(goNoGo)) {
    fail('goNoGo must be no-go, hold, or go.');
  }
  if (state === 'passed' && goNoGo !== 'go') {
    fail('A passed device validation must have goNoGo=go.');
  }
  if (state !== 'passed' && goNoGo === 'go') {
    fail('goNoGo=go is forbidden before the full device validation passes.');
  }

  const identity = object(submission.identity, 'submission.identity');
  const gates = object(submission.blockingGates, 'submission.blockingGates');
  const candidate = object(manifest.candidate, 'candidate');
  const pubspec = parsePubspecVersion(pubspecText);
  const expectedId = 'com.shareittoo.app';
  if (candidate.applicationId !== expectedId || candidate.bundleId !== expectedId) {
    fail(`candidate Android and iOS identifiers must both be ${expectedId}.`);
  }
  if (candidate.applicationId !== identity.applicationId || candidate.bundleId !== identity.bundleId) {
    fail('candidate identifiers must match store/submission.json.');
  }
  if (candidate.versionName !== pubspec.versionName || candidate.versionName !== identity.versionName) {
    fail('candidate versionName must match pubspec.yaml and store/submission.json.');
  }
  const minimumBuild = BigInt(nonEmptyString(candidate.minimumBuildNumber, 'candidate.minimumBuildNumber'));
  if (minimumBuild !== BigInt(nonEmptyString(identity.minimumStoreBuildNumber, 'submission.identity.minimumStoreBuildNumber')) || minimumBuild < 2026080903n) {
    fail('candidate minimumBuildNumber must match the store gate and be at least 2026080903.');
  }
  if (candidate.releaseChannel !== 'internal' || candidate.releaseChannel !== identity.releaseChannel) {
    fail('candidate releaseChannel must remain internal.');
  }
  if (candidate.apiBaseUrl !== 'https://staging.shareittoo.com/api/v1' || candidate.apiBaseUrl !== identity.apiBaseUrl) {
    fail('candidate must target only the isolated staging API.');
  }
  if (candidate.stripeLivemode !== false) {
    fail('candidate.stripeLivemode must remain false for B11.');
  }
  if (!['memory', 'stripe-test'].includes(candidate.paymentMode)) {
    fail('candidate.paymentMode must be memory or stripe-test.');
  }

  const strict = state === 'passed';
  const buildNumber = nullableString(candidate.buildNumber, 'candidate.buildNumber');
  const commit = nullableString(candidate.commit, 'candidate.commit');
  if (buildNumber !== null && !/^\d{10}$/.test(buildNumber)) {
    fail('candidate.buildNumber must use YYYYMMDDNN.');
  }
  if (commit !== null && !/^[a-f0-9]{40}$/i.test(commit)) {
    fail('candidate.commit must be a full 40-character Git commit.');
  }
  if (strict) {
    if (buildNumber === null || BigInt(buildNumber) < minimumBuild || BigInt(buildNumber) !== pubspec.buildNumber) {
      fail('A passed candidate build must match pubspec.yaml and meet the minimum store build.');
    }
    if (commit === null) fail('A passed candidate requires a full Git commit.');
    if (candidate.firebaseConfigured !== true) {
      fail('A passed B11 candidate requires complete Firebase configuration.');
    }
  } else if (candidate.firebaseConfigured !== false && candidate.firebaseConfigured !== true) {
    fail('candidate.firebaseConfigured must be boolean.');
  }

  const android = object(candidate.android, 'candidate.android');
  const ios = object(candidate.ios, 'candidate.ios');
  if (!['pending', 'play-internal'].includes(android.delivery)) {
    fail('candidate.android.delivery must be pending or play-internal.');
  }
  if (!['pending', 'testflight-internal'].includes(ios.delivery)) {
    fail('candidate.ios.delivery must be pending or testflight-internal.');
  }
  for (const [key, value] of Object.entries({
    'candidate.android.aabSha256': android.aabSha256,
    'candidate.android.apkSha256': android.apkSha256,
    'candidate.android.signingCertificateSha256': android.signingCertificateSha256,
    'candidate.ios.ipaSha256': ios.ipaSha256,
  })) {
    assertSha256(value, key, { required: strict });
  }
  const teamIdentifier = nullableString(ios.teamIdentifier, 'candidate.ios.teamIdentifier');
  if (teamIdentifier !== null && !/^[A-Z0-9]{10}$/.test(teamIdentifier)) {
    fail('candidate.ios.teamIdentifier must be a 10-character Apple Team ID.');
  }
  if (strict) {
    if (android.delivery !== 'play-internal' || ios.delivery !== 'testflight-internal') {
      fail('A passed candidate must be installed through Play Internal and TestFlight Internal.');
    }
    if (teamIdentifier === null || ios.privacyManifestScanned !== true) {
      fail('A passed iOS candidate requires Team ID and Privacy Manifest scan.');
    }
  } else if (ios.privacyManifestScanned !== false && ios.privacyManifestScanned !== true) {
    fail('candidate.ios.privacyManifestScanned must be boolean.');
  }

  if (!Array.isArray(manifest.deviceMatrix)) fail('deviceMatrix must be an array.');
  const cells = new Map();
  for (const raw of manifest.deviceMatrix) {
    const cell = object(raw, 'deviceMatrix entry');
    const id = nonEmptyString(cell.id, 'deviceMatrix.id');
    if (cells.has(id)) fail(`Duplicate device matrix id: ${id}.`);
    cells.set(id, cell);
  }
  for (const [id, expected] of requiredCells) {
    const cell = cells.get(id);
    if (!cell) fail(`Missing required device matrix cell: ${id}.`);
    if (cell.platform !== expected.platform || cell.network !== expected.network || cell.role !== expected.role) {
      fail(`${id} does not match its required platform/network/role.`);
    }
    if (cell.deviceType !== 'physical') fail(`${id} must use a physical device.`);
    const expectedReader = cell.platform === 'android' ? 'talkback' : 'voiceover';
    if (cell.screenReader !== expectedReader) fail(`${id} must use ${expectedReader}.`);
    if (!allowedProgressStates.has(cell.status)) fail(`${id}.status is invalid.`);
    const tests = object(cell.tests, `${id}.tests`);
    if (Object.keys(tests).length !== requiredDeviceTests.length) {
      fail(`${id}.tests must contain exactly the required B11 device checks.`);
    }
    for (const test of requiredDeviceTests) {
      if (!allowedProgressStates.has(tests[test])) fail(`${id}.tests.${test} is invalid.`);
    }
    const cellPassed = cell.status === 'passed';
    if (cellPassed || strict) {
      nonEmptyString(cell.deviceModel, `${id}.deviceModel`);
      nonEmptyString(cell.osVersion, `${id}.osVersion`);
      const expectedInstall = cell.platform === 'android' ? 'play-internal' : 'testflight-internal';
      if (cell.storeInstall !== expectedInstall) fail(`${id}.storeInstall must be ${expectedInstall}.`);
      if (cell.status !== 'passed' || requiredDeviceTests.some((test) => tests[test] !== 'passed')) {
        fail(`${id} and every required device check must be passed.`);
      }
      const ref = evidenceRef(root, cell.evidenceRef, `${id}.evidenceRef`, { required: true });
      validateDeviceCellEvidence(root, ref, cell, candidate, `${id}.evidence`);
    } else {
      if (!['pending', 'play-internal', 'testflight-internal'].includes(cell.storeInstall)) {
        fail(`${id}.storeInstall is invalid.`);
      }
      evidenceRef(root, cell.evidenceRef, `${id}.evidenceRef`, { required: false });
    }
  }
  if (cells.size !== requiredCells.size) {
    fail(`deviceMatrix must contain exactly ${requiredCells.size} required cells.`);
  }

  const releaseChecks = object(manifest.releaseChecks, 'releaseChecks');
  if (Object.keys(releaseChecks).length !== requiredReleaseChecks.length) {
    fail('releaseChecks must contain exactly the required B11 release checks.');
  }
  let releaseChecksPassed = 0;
  for (const key of requiredReleaseChecks) {
    const check = object(releaseChecks[key], `releaseChecks.${key}`);
    if (!allowedProgressStates.has(check.status)) fail(`releaseChecks.${key}.status is invalid.`);
    if (check.status === 'passed') releaseChecksPassed += 1;
    const ref = evidenceRef(root, check.evidenceRef, `releaseChecks.${key}.evidenceRef`, {
      required: strict || check.status === 'passed',
    });
    if (check.status === 'passed') {
      validateReleaseCheckEvidence(root, ref, key, candidate, `releaseChecks.${key}.evidence`);
    }
    if (strict && check.status !== 'passed') fail(`releaseChecks.${key} must be passed.`);
  }

  const approvals = object(manifest.approvals, 'approvals');
  for (const key of ['technical', 'productOwner']) {
    const approval = object(approvals[key], `approvals.${key}`);
    if (!['open', 'passed'].includes(approval.status)) fail(`approvals.${key}.status is invalid.`);
    const approved = strict || approval.status === 'passed';
    if (approved && approval.status !== 'passed') fail(`approvals.${key} must be passed.`);
    isoTimestamp(approval.approvedAt, `approvals.${key}.approvedAt`, { required: approved });
    const ref = evidenceRef(root, approval.evidenceRef, `approvals.${key}.evidenceRef`, { required: approved });
    if (approved) {
      validateApprovalEvidence(root, ref, key, approval, candidate, `approvals.${key}.evidence`);
    }
  }

  const policy = object(manifest.evidencePolicy, 'evidencePolicy');
  if (policy.root !== 'docs/evidence/b11' ||
      policy.containsSecrets !== false ||
      policy.containsRawDeviceIdentifiers !== false ||
      policy.containsReviewCredentials !== false ||
      policy.syntheticAccountsOnly !== true) {
    fail('evidencePolicy must keep B11 evidence secret-free, sanitized, and synthetic-only.');
  }

  const gateValues = deviceGateKeys.map((key) => gates[key]);
  if (gateValues.some((value) => value !== 'open' && value !== 'closed')) {
    fail('B11 device-related store gates must be open or closed.');
  }
  if (state === 'passed' && gateValues.some((value) => value !== 'closed')) {
    fail('A passed device validation requires all three related store gates closed.');
  }
  if (state !== 'passed' && gateValues.every((value) => value === 'closed')) {
    fail('Device-related store gates cannot all close before device validation passes.');
  }
  if (requirePassed && state !== 'passed') {
    const passedCells = [...requiredCells.keys()].filter((id) => cells.get(id)?.status === 'passed').length;
    fail(`B11 device validation remains ${state}: matrix=${passedCells}/${requiredCells.size}, releaseChecks=${releaseChecksPassed}/${requiredReleaseChecks.length}.`);
  }

  return {
    state,
    goNoGo,
    matrixPassed: [...requiredCells.keys()].filter((id) => cells.get(id)?.status === 'passed').length,
    matrixTotal: requiredCells.size,
    releaseChecksPassed,
    releaseChecksTotal: requiredReleaseChecks.length,
    minimumBuild: minimumBuild.toString(),
  };
}

function parseArguments(arguments_) {
  let requirePassed = false;
  let manifestPath = null;
  for (let index = 0; index < arguments_.length; index += 1) {
    const value = arguments_[index];
    if (value === '--require-passed') {
      requirePassed = true;
    } else if (value === '--manifest') {
      manifestPath = arguments_[index + 1] ?? fail('--manifest requires a path.');
      index += 1;
    } else {
      fail(`Unknown argument: ${value}`);
    }
  }
  return { requirePassed, manifestPath };
}

function run() {
  const root = fileURLToPath(new URL('../', import.meta.url));
  const { requirePassed, manifestPath } = parseArguments(process.argv.slice(2));
  const devicePath = manifestPath === null ? resolve(root, 'store/device-validation.json') : resolve(manifestPath);
  const summary = validateDeviceEvidence({
    root,
    deviceManifest: JSON.parse(readFileSync(devicePath, 'utf8')),
    submissionManifest: JSON.parse(readFileSync(resolve(root, 'store/submission.json'), 'utf8')),
    pubspecText: readFileSync(resolve(root, 'pubspec.yaml'), 'utf8'),
    requirePassed,
  });
  console.log(
    `Device evidence valid: state=${summary.state}, goNoGo=${summary.goNoGo}, ` +
      `matrix=${summary.matrixPassed}/${summary.matrixTotal}, ` +
      `releaseChecks=${summary.releaseChecksPassed}/${summary.releaseChecksTotal}, ` +
      `minimumBuild=${summary.minimumBuild}.`,
  );
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    run();
  } catch (error) {
    console.error(`ERROR: ${error.message}`);
    process.exitCode = 1;
  }
}
