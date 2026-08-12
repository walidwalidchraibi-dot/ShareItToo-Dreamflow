#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { lstatSync, readFileSync, realpathSync } from 'node:fs';
import { homedir } from 'node:os';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const expectedHardStops = [
  'productionRelease',
  'openTestingRelease',
  'closedTestingRelease',
  'sendForReview',
  'publicRollout',
  'differentArtifact',
  'credentialsInRepository',
];

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
  if (actual !== expected) fail(`${label} does not match the bound candidate.`);
}

function assertNoCredentials(value, path = 'handoff') {
  if (Array.isArray(value)) {
    value.forEach((entry, index) => assertNoCredentials(entry, `${path}[${index}]`));
    return;
  }
  if (value === null || typeof value !== 'object') return;
  for (const [key, entry] of Object.entries(value)) {
    if (forbiddenKey.test(key)) fail(`${path}.${key} is a forbidden credential-shaped field.`);
    assertNoCredentials(entry, `${path}.${key}`);
  }
}

function readJson(path, label) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (error) {
    fail(`${label} could not be read as JSON: ${error.message}`);
  }
}

function sha256File(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

export function validateGooglePlayInternalHandoff({
  repositoryRoot,
  archiveRoot = resolve(homedir(), 'Library', 'Application Support', 'ShareItToo', 'release', 'android'),
  handoffPath = resolve(repositoryRoot, 'store', 'google-play', 'internal-upload-handoff.json'),
  evidencePath = resolve(repositoryRoot, 'docs', 'evidence', 'b11', 'android-candidate-2026081116.json'),
}) {
  const handoff = object(readJson(handoffPath, 'Google Play handoff'), 'handoff');
  const evidence = object(readJson(evidencePath, 'candidate evidence'), 'candidate evidence');
  assertNoCredentials(handoff);

  same(handoff.schemaVersion, 1, 'schemaVersion');
  same(handoff.status, 'verified-artifact-ready-account-gates-pending', 'status');
  same(handoff.submissionAllowed, false, 'submissionAllowed');
  same(handoff.track, 'internal', 'track');
  same(handoff.containsSecrets, false, 'containsSecrets');
  same(handoff.containsReviewCredentials, false, 'containsReviewCredentials');

  const candidate = object(handoff.candidate, 'candidate');
  const evidenceCandidate = object(evidence.candidate, 'candidate evidence.candidate');
  const evidenceAndroid = object(evidence.android, 'candidate evidence.android');
  same(candidate.applicationId, evidenceCandidate.applicationId, 'applicationId');
  same(candidate.versionName, evidenceCandidate.versionName, 'versionName');
  same(candidate.buildNumber, evidenceCandidate.buildNumber, 'buildNumber');
  same(candidate.commit, evidenceCandidate.commit, 'commit');
  same(candidate.apiBaseUrl, evidenceCandidate.apiBaseUrl, 'apiBaseUrl');
  same(candidate.firebaseConfigured, true, 'firebaseConfigured');
  same(candidate.aabSha256, evidenceAndroid.aabSha256, 'aabSha256');
  same(candidate.uploadCertificateSha256, evidenceAndroid.signingCertificateSha256,
    'uploadCertificateSha256');

  const artifact = object(handoff.artifact, 'artifact');
  if (!/^[a-zA-Z0-9._-]+$/.test(artifact.archiveDirectoryName) ||
      !/^[a-zA-Z0-9._-]+\.aab$/.test(artifact.fileName)) {
    fail('Artifact location must use safe fixed names.');
  }
  same(artifact.ownerOnlyPermissionsRequired, true, 'ownerOnlyPermissionsRequired');
  const artifactPath = resolve(archiveRoot, artifact.archiveDirectoryName, artifact.fileName);
  const archiveReal = realpathSync(archiveRoot);
  let metadata;
  try {
    metadata = lstatSync(artifactPath);
  } catch {
    fail('The bound AAB is unavailable in the private release archive.');
  }
  if (!metadata.isFile() || metadata.isSymbolicLink()) fail('The bound AAB must be a normal file.');
  if ((metadata.mode & 0o077) !== 0) fail('The bound AAB must have owner-only permissions.');
  if (!realpathSync(artifactPath).startsWith(`${archiveReal}/`)) fail('The bound AAB left the private archive.');
  same(sha256File(artifactPath), candidate.aabSha256, 'archived AAB SHA-256');

  const preUpload = object(handoff.preUploadGates, 'preUploadGates');
  same(preUpload.personalIdentityVerification, 'verified', 'personalIdentityVerification');
  same(preUpload.deviceVerification, 'verified', 'deviceVerification');
  same(preUpload.phoneVerification, 'verified', 'phoneVerification');
  same(preUpload.developerProgramPoliciesDeclaration, 'pending-owner-approval',
    'developerProgramPoliciesDeclaration');
  same(preUpload.playAppSigningTerms, 'pending-owner-approval', 'playAppSigningTerms');
  same(preUpload.usExportLawsDeclaration, 'pending-owner-approval', 'usExportLawsDeclaration');
  same(preUpload.playAppRecordCreated, false, 'playAppRecordCreated');
  same(preUpload.immediateArtifactReverification, false, 'immediateArtifactReverification');

  for (const [key, value] of Object.entries(object(handoff.postUploadChecks, 'postUploadChecks'))) {
    same(value, 'pending', `postUploadChecks.${key}`);
  }
  const hardStops = object(handoff.hardStops, 'hardStops');
  for (const key of expectedHardStops) same(hardStops[key], true, `hardStops.${key}`);

  return { artifactPath, aabSha256: candidate.aabSha256, buildNumber: candidate.buildNumber };
}

function runCli() {
  const repositoryRoot = resolve(fileURLToPath(new URL('..', import.meta.url)));
  const result = validateGooglePlayInternalHandoff({ repositoryRoot });
  process.stdout.write(`Google Play internal handoff: PASS (build ${result.buildNumber})\n`);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  try {
    runCli();
  } catch (error) {
    process.stderr.write(`${error?.message ?? 'Google Play internal handoff failed.'}\n`);
    process.exitCode = 1;
  }
}
