#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

function fail(message) {
  throw new Error(message);
}

function object(value, label) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${label} must be an object.`);
  }
  return value;
}

function exactKeys(value, expected, label) {
  const keys = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (JSON.stringify(keys) !== JSON.stringify(wanted)) {
    fail(`${label} must contain exactly the approved keys.`);
  }
}

export function validateGooglePlayAppContentHandoff({
  repositoryRoot,
  handoffPath = resolve(repositoryRoot, 'store/google-play/app-content-handoff.json'),
  allowCandidateRollover = false,
}) {
  const handoff = object(JSON.parse(readFileSync(handoffPath, 'utf8')), 'handoff');
  const deviceValidation = object(
    JSON.parse(readFileSync(resolve(repositoryRoot, 'store/device-validation.json'), 'utf8')),
    'device validation',
  );
  const currentCandidate = object(deviceValidation.candidate, 'device validation candidate');
  if (handoff.schemaVersion !== 1 ||
      handoff.status !== 'nine-of-eleven-saved-two-open' ||
      handoff.submissionAllowed !== false) {
    fail('App-content handoff must remain prepared and fail-closed.');
  }
  const encoded = JSON.stringify(handoff);
  if (encoded.includes('@') || handoff.containsSecrets !== false ||
      handoff.containsAccountAddresses !== false ||
      handoff.containsReviewCredentials !== false) {
    fail('App-content handoff must remain sanitized.');
  }

  const candidate = object(handoff.candidate, 'candidate');
  const candidateBuildNumber = String(candidate.buildNumber ?? '');
  const currentBuildNumber = String(currentCandidate.buildNumber ?? '');
  const buildNumbersValid = /^\d+$/.test(candidateBuildNumber) &&
    /^\d+$/.test(currentBuildNumber);
  const candidateBuild = buildNumbersValid ? BigInt(candidateBuildNumber) : 0n;
  const currentBuild = buildNumbersValid ? BigInt(currentBuildNumber) : 0n;
  const buildBindingValid = allowCandidateRollover
    ? candidateBuild > 0n && candidateBuild <= currentBuild
    : candidate.buildNumber === currentCandidate.buildNumber;
  if (candidate.applicationId !== 'com.shareittoo.app' ||
      candidate.versionName !== currentCandidate.versionName ||
      !buildBindingValid ||
      candidate.releaseChannel !== 'internal' ||
      candidate.apiBaseUrl !== 'https://staging.shareittoo.com/api/v1') {
    fail('App-content handoff is not bound to the internal Staging candidate.');
  }

  const tasks = object(handoff.tasks, 'tasks');
  const taskNames = [
    'privacyPolicy', 'appAccess', 'ads', 'contentRating', 'targetAudience',
    'dataSafety', 'advertisingId', 'governmentApps', 'financialFeatures', 'health',
    'categoryAndContact', 'storeListing',
  ];
  exactKeys(tasks, taskNames, 'tasks');
  if (tasks.privacyPolicy.status !== 'blocked-public-route-approval' ||
      tasks.privacyPolicy.proposedUrl !== 'https://shareittoo.com/privacy' ||
      tasks.appAccess.status !== 'saved-protected-console-entry' ||
      tasks.appAccess.loginRequired !== true ||
      tasks.appAccess.credentialsInRepository !== false ||
      tasks.ads.status !== 'saved-current-build-no-ads' ||
      tasks.ads.proposedAnswer !== false ||
      tasks.contentRating.status !==
        'saved-iarc-completed-usk-12-plus' ||
      tasks.contentRating.category !== 'all-other-app-types' ||
      tasks.contentRating.userGeneratedContent !== true ||
      tasks.contentRating.directUserCommunication !== true ||
      tasks.contentRating.preciseDeviceLocationSharedByUser !== true ||
      tasks.contentRating.protectedContactAddressEntered !== true ||
      tasks.contentRating.iarcTermsAccepted !== true ||
      tasks.contentRating.questionnaireSubmitted !== true ||
      tasks.contentRating.germanyRating !== 'usk-12-plus' ||
      tasks.contentRating.sentForReview !== false ||
      tasks.contentRating.evidenceRef !==
        'docs/evidence/b11/google-play-iarc-content-rating-completion-20260813.json' ||
      tasks.targetAudience.status !== 'saved-eighteen-and-over' ||
      tasks.targetAudience.minimumAge !== 18 ||
      tasks.targetAudience.designedForChildren !== false ||
      tasks.dataSafety.collectsOrTransmitsUserData !== true ||
      tasks.dataSafety.status !==
        'all-data-type-answers-prepared-console-save-blocked' ||
      tasks.dataSafety.accountCreationMethod !== 'username-and-password' ||
      tasks.dataSafety.oauthPreparedButUnavailable !== true ||
      tasks.dataSafety.deleteAccountUrlSaved !== false ||
      tasks.dataSafety.preparedDeleteAccountUrl !==
        'https://shareittoo.com/account-deletion' ||
      tasks.dataSafety.preparedPartialDataDeletionAnswer !== false ||
      tasks.dataSafety.dataTypesPrepared !== 16 ||
      tasks.dataSafety.dataTypesEvidenceRef !==
        'docs/evidence/b11/google-play-data-safety-datatypes-20260812.json' ||
      tasks.dataSafety.answerMatrixEvidenceRef !==
        'docs/evidence/b11/google-play-data-safety-answer-matrix-20260813.json' ||
      tasks.dataSafety.providerClassificationEvidenceRef !==
        'docs/evidence/b11/google-play-service-provider-sharing-classification-20260813.json' ||
      tasks.dataSafety.stepTwoEvidenceRef !==
        'docs/evidence/b11/google-play-data-safety-step2-20260812.json' ||
      tasks.dataSafety.sellsData !== false ||
      tasks.dataSafety.advertisingTracking !== false ||
      tasks.advertisingId.status !==
        'saved-current-build-no-advertising-id' ||
      tasks.advertisingId.proposedAnswer !== false ||
      tasks.advertisingId.evidenceRef !==
        'docs/evidence/b11/google-play-advertising-id-declaration-20260812.json' ||
      tasks.governmentApps.status !== 'saved-not-government-app' ||
      tasks.governmentApps.proposedAnswer !== false ||
      tasks.financialFeatures.status !== 'saved-no-financial-features' ||
      tasks.financialFeatures.proposedAnswer !== 'no-financial-features' ||
      tasks.financialFeatures.physicalGoodsRental !== true ||
      tasks.financialFeatures.digitalGoodsBilling !== false ||
      tasks.health.status !== 'saved-no-health-features' ||
      tasks.health.proposedAnswer !== false ||
      tasks.categoryAndContact.status !== 'saved-shopping-and-public-contact' ||
      tasks.categoryAndContact.category !== 'Shopping' ||
      tasks.storeListing.copyAndGraphicsPrepared !== true ||
      tasks.storeListing.phoneScreenshotsValidated !== true ||
      tasks.storeListing.validatedPhoneScreenshotCount !== 4 ||
      tasks.storeListing.recommendedPhoneScreenshotTarget !== 4 ||
      tasks.storeListing.uploadedToPlayConsole !== true ||
      tasks.storeListing.status !==
        'saved-in-console-compatible-copy-and-assets' ||
      tasks.storeListing.screenshotReadinessRef !==
        'docs/evidence/b11/google-play-feed-screenshot-compatibility-2026081403-20260814.json' ||
      tasks.storeListing.consoleSaveEvidenceRef !==
        'docs/evidence/b11/google-play-store-listing-saved-20260813.json') {
    fail('One or more prepared Play answers no longer match the bounded product truth.');
  }

  const hardStops = object(handoff.hardStops, 'hardStops');
  for (const [key, value] of Object.entries(hardStops)) {
    if (value !== true) fail(`hardStops.${key} must remain enabled.`);
  }
  if (Object.keys(hardStops).length !== 7) {
    fail('App-content handoff must preserve all seven hard stops.');
  }
  if (!Array.isArray(handoff.evidenceRefs) || handoff.evidenceRefs.length !== 11 ||
      handoff.evidenceRefs.some((ref) => typeof ref !== 'string' ||
        ref.includes('..') || !resolve(repositoryRoot, ref).startsWith(`${resolve(repositoryRoot)}/`))) {
    fail('App-content evidence references are invalid.');
  }
  for (const ref of handoff.evidenceRefs) readFileSync(resolve(repositoryRoot, ref));
  return { taskCount: taskNames.length, buildNumber: candidate.buildNumber };
}

function runCli() {
  const repositoryRoot = resolve(fileURLToPath(new URL('..', import.meta.url)));
  const allowCandidateRollover = process.argv.includes('--allow-candidate-rollover');
  const unknownArgs = process.argv.slice(2).filter((arg) => arg !== '--allow-candidate-rollover');
  if (unknownArgs.length > 0) fail(`Unknown argument: ${unknownArgs[0]}`);
  const result = validateGooglePlayAppContentHandoff({ repositoryRoot, allowCandidateRollover });
  process.stdout.write(
    `Google Play app-content handoff: PASS (${result.taskCount} tasks, ` +
      `observed console build ${result.buildNumber})\n`,
  );
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  try {
    runCli();
  } catch (error) {
    process.stderr.write(`${error?.message ?? 'Google Play app-content handoff failed.'}\n`);
    process.exitCode = 1;
  }
}
