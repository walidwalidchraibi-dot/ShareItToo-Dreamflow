#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

function fail(message) { throw new Error(message); }

export function validateGooglePlayAppContentProgress({
  repositoryRoot,
  evidencePath = resolve(repositoryRoot,
    'docs/evidence/b11/google-play-app-content-progress-20260812.json'),
} = {}) {
  const evidence = JSON.parse(readFileSync(evidencePath, 'utf8'));
  if (evidence.schemaVersion !== 1 || evidence.kind !== 'google-play-app-content-progress' ||
      evidence.status !== 'seven-of-eleven-saved-data-safety-step-two-observed') {
    fail('Play app-content progress state is invalid.');
  }
  if (evidence.candidate?.applicationId !== 'com.shareittoo.app' ||
      evidence.candidate?.versionName !== '1.0.0' ||
      evidence.candidate?.buildNumber !== '2026081202' ||
      evidence.candidate?.releaseChannel !== 'internal' ||
      evidence.candidate?.apiBaseUrl !== 'https://staging.shareittoo.com/api/v1') {
    fail('Play app-content progress is not bound to the internal candidate.');
  }
  if (evidence.counts?.totalTasks !== 11 || evidence.counts?.savedTasks !== 7 ||
      evidence.counts?.openTasks !== 4 || !Array.isArray(evidence.savedTasks) ||
      evidence.savedTasks.join(',') !==
        'appAccess,ads,targetAudience,governmentApps,financialFeatures,health,categoryAndContact') {
    fail('Play app-content task counts or saved tasks are incomplete.');
  }
  const expectedOpen = ['privacyPolicy', 'contentRating', 'dataSafety', 'storeListing'];
  if (Object.keys(evidence.openTasks ?? {}).join(',') !== expectedOpen.join(',') ||
      Object.values(evidence.openTasks).some((value) => typeof value !== 'string' || !value.includes('pending') && !value.includes('not-release-ready'))) {
    fail('Play app-content open tasks are not fail-closed.');
  }
  if (evidence.storeDraft?.germanCopySaved !== true ||
      evidence.storeDraft?.phoneScreenshotsValidatedLocal !== 4 ||
      evidence.storeDraft?.phoneScreenshotsUploaded !== false ||
      evidence.storeDraft?.appBundleUploaded !== false) {
    fail('Play store draft state is invalid.');
  }
  const dataSafety = evidence.dataSafetyDraft ?? {};
  if (dataSafety.collectsOrSharesRequiredData !== true || dataSafety.encryptedInTransit !== true ||
      dataSafety.accountCreationMethod !== 'username-and-password' ||
      dataSafety.oauthPreparedButUnavailable !== true ||
      dataSafety.deleteAccountUrlSaved !== false ||
      dataSafety.partialDataDeletionAnswerSaved !== false ||
      dataSafety.preparedPartialDataDeletionAnswer !== false ||
      dataSafety.stepTwoEvidenceRef !==
        'docs/evidence/b11/google-play-data-safety-step2-20260812.json' ||
      dataSafety.dataTypesSaved !== false ||
      dataSafety.submitted !== false) {
    fail('Play data-safety partial draft state is invalid.');
  }
  const boundaries = evidence.boundaries ?? {};
  if (Object.keys(boundaries).length !== 9 || Object.values(boundaries).some((value) => value !== false) ||
      JSON.stringify(evidence).includes('@')) {
    fail('Play app-content progress boundaries are unsafe or unsanitized.');
  }
  const stepTwoEvidence = JSON.parse(readFileSync(resolve(repositoryRoot,
    dataSafety.stepTwoEvidenceRef), 'utf8'));
  if (stepTwoEvidence.kind !== 'google-play-data-safety-step-2-observation' ||
      stepTwoEvidence.candidate?.buildNumber !== evidence.candidate.buildNumber ||
      stepTwoEvidence.observedSavedAnswers?.accountCreationMethods?.join(',') !==
        'username-and-password' ||
      stepTwoEvidence.preparedUnsavedAnswers?.oauthAccountCreation !== false ||
      stepTwoEvidence.preparedUnsavedAnswers?.partialDataDeletion !== false ||
      Object.values(stepTwoEvidence.boundaries ?? {}).some((value) => value !== false) ||
      JSON.stringify(stepTwoEvidence).includes('@')) {
    fail('Play data-safety step-two observation is invalid or unsafe.');
  }
  return { status: evidence.status, savedTasks: evidence.counts.savedTasks, openTasks: evidence.counts.openTasks };
}

function main() {
  const repositoryRoot = resolve(fileURLToPath(new URL('..', import.meta.url)));
  const result = validateGooglePlayAppContentProgress({ repositoryRoot });
  process.stdout.write(`Google Play app-content progress: PASS (${result.savedTasks}/11 saved, ${result.openTasks} open)\n`);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  try { main(); } catch (error) {
    process.stderr.write(`${error?.message ?? 'Play app-content progress validation failed.'}\n`);
    process.exitCode = 1;
  }
}
