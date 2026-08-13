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
  if (value === null || typeof value !== 'object') {
    if (typeof value === 'string' && /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i.test(value)) {
      fail(`${path} must not contain email addresses.`);
    }
    return;
  }
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
  evidencePath = null,
  liveReadinessPath = null,
}) {
  const handoff = object(readJson(handoffPath, 'Google Play handoff'), 'handoff');
  const resolvedEvidencePath = evidencePath ?? resolve(repositoryRoot, handoff.evidenceRef ?? '');
  const evidence = object(readJson(resolvedEvidencePath, 'candidate evidence'), 'candidate evidence');
  assertNoCredentials(handoff);

  same(handoff.schemaVersion, 1, 'schemaVersion');
  const superseded = handoff.status === 'superseded-privacy-rescan-failed-replacement-pending';
  if (!superseded && handoff.status !== 'verified-artifact-ready-immediate-reverification-pending') {
    fail('status must describe either the verified artifact or its fail-closed supersession.');
  }
  same(handoff.submissionAllowed, false, 'submissionAllowed');
  same(handoff.track, 'internal', 'track');
  same(handoff.containsSecrets, false, 'containsSecrets');
  same(handoff.containsReviewCredentials, false, 'containsReviewCredentials');
  if (superseded) {
    if (!/^\d{10}$/u.test(handoff.replacementBuildNumber ?? '')
        || BigInt(handoff.replacementBuildNumber) <= BigInt(handoff.candidate?.buildNumber ?? '0')) {
      fail('replacementBuildNumber must be a newer ten-digit candidate build.');
    }
    const supersessionPath = resolve(repositoryRoot, handoff.supersessionEvidenceRef ?? '');
    const supersession = object(readJson(supersessionPath, 'supersession evidence'), 'supersession evidence');
    same(supersession.status, 'superseded-privacy-rescan-failed', 'supersession status');
    same(supersession.remediation?.replacementBuildNumber, handoff.replacementBuildNumber,
      'supersession replacement build number');
    same(supersession.boundaries?.uploadedToStore, false, 'supersession uploadedToStore');
    same(supersession.boundaries?.submissionAllowed, false, 'supersession submissionAllowed');
  }

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

  const releaseDraft = object(handoff.releaseDraft, 'releaseDraft');
  same(releaseDraft.name, `1.0.0-internal-${candidate.buildNumber}`, 'releaseDraft.name');
  same(releaseDraft.notesPath, 'store/google-play/de-DE/internal_release_notes.txt',
    'releaseDraft.notesPath');
  same(releaseDraft.language, 'de-DE', 'releaseDraft.language');
  same(releaseDraft.saveOnly, true, 'releaseDraft.saveOnly');
  same(releaseDraft.rolloutAllowed, false, 'releaseDraft.rolloutAllowed');
  const notesPath = resolve(repositoryRoot, releaseDraft.notesPath);
  if (!notesPath.startsWith(`${realpathSync(repositoryRoot)}/`)) {
    fail('Release notes left the repository.');
  }
  const notes = readFileSync(notesPath, 'utf8').trim();
  if (!notes.startsWith('Erster interner ShareItToo-Test:') ||
      !notes.includes('ausschließlich Staging und Testzahlungen')) {
    fail('Release notes must describe the bounded internal Staging build.');
  }

  const preUpload = object(handoff.preUploadGates, 'preUploadGates');
  same(preUpload.personalIdentityVerification, 'verified', 'personalIdentityVerification');
  same(preUpload.deviceVerification, 'verified', 'deviceVerification');
  same(preUpload.phoneVerification, 'verified', 'phoneVerification');
  same(preUpload.developerProgramPoliciesDeclaration, 'accepted-with-owner-approval',
    'developerProgramPoliciesDeclaration');
  same(preUpload.playAppSigningTerms, 'accepted-with-owner-approval', 'playAppSigningTerms');
  same(preUpload.usExportLawsDeclaration, 'accepted-with-owner-approval',
    'usExportLawsDeclaration');
  same(preUpload.playAppRecordCreated, true, 'playAppRecordCreated');
  same(preUpload.immediateArtifactReverification, false, 'immediateArtifactReverification');

  const expectedPostUploadChecks = {
    uploadedArtifactHashRecorded: 'pending',
    playAppSigningFingerprintRecorded: 'passed-pre-upload-console',
    uploadWarningsReviewed: 'pending',
    crashlyticsCandidateAssignmentVerified: 'pending',
    internalStoreInstallCompleted: 'pending',
  };
  const postUploadChecks = object(handoff.postUploadChecks, 'postUploadChecks');
  for (const [key, value] of Object.entries(expectedPostUploadChecks)) {
    same(postUploadChecks[key], value, `postUploadChecks.${key}`);
  }
  const hardStops = object(handoff.hardStops, 'hardStops');
  for (const key of expectedHardStops) same(hardStops[key], true, `hardStops.${key}`);

  same(
    handoff.preUploadLiveReadinessEvidenceRef,
    'docs/evidence/b11/google-play-pre-upload-live-readiness-20260813.json',
    'preUploadLiveReadinessEvidenceRef',
  );
  const resolvedLiveReadinessPath = liveReadinessPath ?? resolve(
    repositoryRoot,
    handoff.preUploadLiveReadinessEvidenceRef,
  );
  const live = object(readJson(resolvedLiveReadinessPath, 'pre-upload live readiness'),
    'pre-upload live readiness');
  assertNoCredentials(live, 'pre-upload live readiness');
  same(live.schemaVersion, 1, 'pre-upload live readiness.schemaVersion');
  same(live.kind, 'google-play-pre-upload-live-readiness', 'pre-upload live readiness.kind');
  same(
    live.status,
    'ready-awaiting-explicit-internal-upload-approval',
    'pre-upload live readiness.status',
  );
  if (typeof live.capturedAt !== 'string' ||
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/u.test(live.capturedAt) ||
      !Number.isFinite(Date.parse(live.capturedAt))) {
    fail('pre-upload live readiness.capturedAt must be a UTC RFC 3339 timestamp.');
  }
  const liveCandidate = object(live.candidate, 'pre-upload live readiness.candidate');
  for (const key of [
    'applicationId',
    'versionName',
    'buildNumber',
    'commit',
    'aabSha256',
    'uploadCertificateSha256',
  ]) {
    same(liveCandidate[key], candidate[key], `pre-upload live readiness.candidate.${key}`);
  }
  same(
    liveCandidate.playAppSigningCertificateSha256,
    '36488abf86c51da07ab2258f31b00e2f1ba8a36d076107b9f006376ade80b956',
    'pre-upload live readiness.candidate.playAppSigningCertificateSha256',
  );

  const consoleState = object(live.googlePlayConsole, 'pre-upload live readiness.googlePlayConsole');
  same(consoleState.appStatus, 'draft', 'pre-upload live readiness.googlePlayConsole.appStatus');
  const internal = object(consoleState.internalTesting,
    'pre-upload live readiness.googlePlayConsole.internalTesting');
  const expectedInternal = {
    status: 'inactive-draft-release',
    draftReleaseShellPresent: true,
    completedTaskCount: 1,
    totalTaskCount: 3,
    maximumTesterCount: 100,
    emailListCreated: false,
    publishedJoinLinkAvailable: false,
    uploadedBundleCount: 0,
  };
  for (const [key, value] of Object.entries(expectedInternal)) {
    same(internal[key], value, `pre-upload live readiness.googlePlayConsole.internalTesting.${key}`);
  }
  const closed = object(consoleState.closedTesting,
    'pre-upload live readiness.googlePlayConsole.closedTesting');
  const expectedClosed = {
    status: 'locked-app-setup-incomplete',
    minimumContinuousTesterCount: 12,
    minimumConsecutiveDays: 14,
    currentOptedInTesterCount: 0,
    productionAccessAllowed: false,
  };
  for (const [key, value] of Object.entries(expectedClosed)) {
    same(closed[key], value, `pre-upload live readiness.googlePlayConsole.closedTesting.${key}`);
  }
  const appContent = object(consoleState.appContent,
    'pre-upload live readiness.googlePlayConsole.appContent');
  same(appContent.completedTaskCount, 8,
    'pre-upload live readiness.googlePlayConsole.appContent.completedTaskCount');
  same(appContent.totalTaskCount, 11,
    'pre-upload live readiness.googlePlayConsole.appContent.totalTaskCount');
  same(
    [...(appContent.openTasks ?? [])].sort().join(','),
    ['privacy-policy', 'data-safety', 'store-listing'].sort().join(','),
    'pre-upload live readiness.googlePlayConsole.appContent.openTasks',
  );
  const signing = object(consoleState.appSigning,
    'pre-upload live readiness.googlePlayConsole.appSigning');
  const expectedSigning = {
    releasesSignedByPlay: true,
    playAppSigningFingerprintObserved: true,
    uploadCertificateFingerprintVisibleAfterFirstBundle: false,
    automaticProtectionActive: true,
    playIntegrityApiIntegrated: false,
    storeListingDeviceChecksEnabled: false,
  };
  for (const [key, value] of Object.entries(expectedSigning)) {
    same(signing[key], value, `pre-upload live readiness.googlePlayConsole.appSigning.${key}`);
  }

  const crossChecks = object(live.localCrossChecks, 'pre-upload live readiness.localCrossChecks');
  same(
    crossChecks.assetLinksWithUploadAndPlayFingerprints,
    'passed-local-not-deployed',
    'pre-upload live readiness.localCrossChecks.assetLinksWithUploadAndPlayFingerprints',
  );
  const device = object(crossChecks.connectedAndroidDevice,
    'pre-upload live readiness.localCrossChecks.connectedAndroidDevice');
  same(device.manufacturer, 'Google', 'pre-upload live readiness.connectedAndroidDevice.manufacturer');
  same(device.model, 'Pixel 7 Pro', 'pre-upload live readiness.connectedAndroidDevice.model');
  same(device.osVersion, '16', 'pre-upload live readiness.connectedAndroidDevice.osVersion');
  same(device.installedVersionName, candidate.versionName,
    'pre-upload live readiness.connectedAndroidDevice.installedVersionName');
  same(device.installedBuildNumber, candidate.buildNumber,
    'pre-upload live readiness.connectedAndroidDevice.installedBuildNumber');
  same(device.installMethod, 'direct-apk-diagnostic',
    'pre-upload live readiness.connectedAndroidDevice.installMethod');
  same(device.storeInstall, 'pending', 'pre-upload live readiness.connectedAndroidDevice.storeInstall');

  const decisionGate = object(live.decisionGate, 'pre-upload live readiness.decisionGate');
  const expectedDecisionGate = {
    explicitCurrentInternalUploadApprovalRequired: true,
    submissionAllowed: false,
    saveDraftAllowed: false,
    rolloutAllowed: false,
    testerInvitationsAllowed: false,
  };
  for (const [key, value] of Object.entries(expectedDecisionGate)) {
    same(decisionGate[key], value, `pre-upload live readiness.decisionGate.${key}`);
  }

  const boundaries = object(live.boundaries, 'pre-upload live readiness.boundaries');
  const expectedBoundaries = {
    browserReadOnly: true,
    uploadedToStore: false,
    releaseMetadataSaved: false,
    testerListChanged: false,
    testerInvitationSent: false,
    productionChanged: false,
    publicRoutesChanged: false,
    containsTesterPersonalData: false,
    containsAccountIdentifiers: false,
    containsSecrets: false,
    containsRawDeviceIdentifiers: false,
  };
  for (const [key, value] of Object.entries(expectedBoundaries)) {
    same(boundaries[key], value, `pre-upload live readiness.boundaries.${key}`);
  }

  return {
    artifactPath,
    aabSha256: candidate.aabSha256,
    buildNumber: candidate.buildNumber,
    releaseName: releaseDraft.name,
    releaseNotes: notes,
    status: handoff.status,
  };
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
