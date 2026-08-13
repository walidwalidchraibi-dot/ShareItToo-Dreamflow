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
      evidence.status !== 'ten-of-twelve-saved-two-open') {
    fail('Play app-content progress state is invalid.');
  }
  if (evidence.candidate?.applicationId !== 'com.shareittoo.app' ||
      evidence.candidate?.versionName !== '1.0.0' ||
      evidence.candidate?.buildNumber !== '2026081302' ||
      evidence.candidate?.releaseChannel !== 'internal' ||
      evidence.candidate?.apiBaseUrl !== 'https://staging.shareittoo.com/api/v1') {
    fail('Play app-content progress is not bound to the internal candidate.');
  }
  if (evidence.counts?.totalTasks !== 12 || evidence.counts?.savedTasks !== 10 ||
      evidence.counts?.openTasks !== 2 || !Array.isArray(evidence.savedTasks) ||
      evidence.savedTasks.join(',') !==
        'appAccess,ads,targetAudience,governmentApps,financialFeatures,health,categoryAndContact,advertisingId,contentRating,storeListing') {
    fail('Play app-content task counts or saved tasks are incomplete.');
  }
  const expectedOpen = ['privacyPolicy', 'dataSafety'];
  if (Object.keys(evidence.openTasks ?? {}).join(',') !== expectedOpen.join(',') ||
      Object.values(evidence.openTasks).some((value) => typeof value !== 'string' || !value.includes('pending') && !value.includes('not-release-ready'))) {
    fail('Play app-content open tasks are not fail-closed.');
  }
  if (evidence.storeDraft?.germanCopySaved !== true ||
      evidence.storeDraft?.phoneScreenshotsValidatedLocal !== 4 ||
      evidence.storeDraft?.phoneScreenshotsUploaded !== true ||
      evidence.storeDraft?.appIconUploaded !== true ||
      evidence.storeDraft?.featureGraphicUploaded !== true ||
      evidence.storeDraft?.storeListingTaskCompleted !== true ||
      evidence.storeDraft?.consoleSaveEvidenceRef !==
        'docs/evidence/b11/google-play-store-listing-saved-20260813.json' ||
      evidence.storeDraft?.appBundleUploaded !== true ||
      evidence.storeDraft?.internalReleaseActive !== true ||
      evidence.storeDraft?.internalReleaseEvidenceRef !==
        'docs/evidence/b11/google-play-internal-release-active-20260813.json') {
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
      dataSafety.dataTypesPrepared !== 16 ||
      dataSafety.dataTypesEvidenceRef !==
        'docs/evidence/b11/google-play-data-safety-datatypes-20260812.json' ||
      dataSafety.answerMatrixEvidenceRef !==
        'docs/evidence/b11/google-play-data-safety-answer-matrix-20260813.json' ||
      dataSafety.providerClassificationEvidenceRef !==
        'docs/evidence/b11/google-play-service-provider-sharing-classification-20260813.json' ||
      dataSafety.dataTypesSaved !== false ||
      dataSafety.submitted !== false) {
    fail('Play data-safety partial draft state is invalid.');
  }
  const boundaries = evidence.boundaries ?? {};
  if (Object.keys(boundaries).length !== 11 ||
      boundaries.storeListingChanged !== true ||
      boundaries.storeListingAssetsUploaded !== true ||
      Object.entries(boundaries).some(([key, value]) =>
        ['storeListingChanged', 'storeListingAssetsUploaded'].includes(key) ?
          value !== true : value !== false) ||
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
  const dataTypesEvidence = JSON.parse(readFileSync(resolve(repositoryRoot,
    dataSafety.dataTypesEvidenceRef), 'utf8'));
  if (dataTypesEvidence.kind !== 'google-play-data-safety-data-types-preparation' ||
      dataTypesEvidence.candidate?.buildNumber !== evidence.candidate.buildNumber ||
      dataTypesEvidence.selectionCounts?.evaluated !== 17 ||
      dataTypesEvidence.selectionCounts?.select !== 16 ||
      dataTypesEvidence.selectionCounts?.doNotSelect !== 1 ||
      dataTypesEvidence.select?.includes('Files and docs / Files and docs') ||
      dataTypesEvidence.doNotSelect?.[0]?.dataType !==
        'Financial info / User payment info' ||
      Object.values(dataTypesEvidence.boundaries ?? {}).some((value) => value !== false) ||
      JSON.stringify(dataTypesEvidence).includes('@')) {
    fail('Play data-safety data-type preparation is invalid or unsafe.');
  }
  const answerMatrixEvidence = JSON.parse(readFileSync(resolve(repositoryRoot,
    dataSafety.answerMatrixEvidenceRef), 'utf8'));
  if (answerMatrixEvidence.kind !== 'google-play-data-safety-answer-matrix' ||
      answerMatrixEvidence.status !== 'all-data-type-answers-prepared-console-save-blocked' ||
      answerMatrixEvidence.candidate?.buildNumber !== evidence.candidate.buildNumber ||
      answerMatrixEvidence.dataTypes?.length !== 17 ||
      answerMatrixEvidence.dataTypes?.filter((entry) => entry.selected).length !== 16 ||
      answerMatrixEvidence.consoleBaseline?.dataTypeAnswersSaved !== false ||
      Object.values(answerMatrixEvidence.blockingGates ?? {}).some((value) => value !== false) ||
      Object.values(answerMatrixEvidence.boundaries ?? {}).some((value) => value !== false) ||
      JSON.stringify(answerMatrixEvidence).includes('@')) {
    fail('Play data-safety answer matrix is invalid, stale, or unsafe.');
  }
  const providerEvidence = JSON.parse(readFileSync(resolve(repositoryRoot,
    dataSafety.providerClassificationEvidenceRef), 'utf8'));
  if (providerEvidence.kind !== 'google-play-service-provider-sharing-classification' ||
      providerEvidence.status !==
        'technical-provider-roles-classified-owner-contract-and-legal-approval-open' ||
      providerEvidence.candidate?.buildNumber !== evidence.candidate.buildNumber ||
      providerEvidence.technicalConclusion?.classificationResearchComplete !== true ||
      providerEvidence.technicalConclusion?.consoleAnswerAllowed !== false ||
      Object.values(providerEvidence.blockingGates ?? {}).some((value) => value !== false) ||
      providerEvidence.boundaries?.technicalClassificationOnly !== true ||
      JSON.stringify(providerEvidence).includes('@')) {
    fail('Play service-provider classification is invalid, stale, or unsafe.');
  }
  const advertisingId = evidence.advertisingIdDraft ?? {};
  if (advertisingId.usesAdvertisingId !== false ||
      advertisingId.answerSaved !== true ||
      advertisingId.evidenceRef !==
        'docs/evidence/b11/google-play-advertising-id-declaration-20260812.json') {
    fail('Play Advertising ID draft state is invalid.');
  }
  const advertisingEvidence = JSON.parse(readFileSync(resolve(repositoryRoot,
    advertisingId.evidenceRef), 'utf8'));
  if (advertisingEvidence.kind !==
        'google-play-advertising-id-declaration-observation' ||
      advertisingEvidence.status !== 'console-declaration-saved-answer-no' ||
      advertisingEvidence.candidate?.buildNumber !== evidence.candidate.buildNumber ||
      advertisingEvidence.preparedAnswer !== false ||
      Object.values(advertisingEvidence.basis ?? {}).some((value) => value !== false) ||
      advertisingEvidence.boundaries?.consoleAnswerChanged !== true ||
      advertisingEvidence.boundaries?.draftSaved !== true ||
      Object.entries(advertisingEvidence.boundaries ?? {}).some(([key, value]) =>
        !['consoleAnswerChanged', 'draftSaved'].includes(key) && value !== false) ||
      JSON.stringify(advertisingEvidence).includes('@')) {
    fail('Play Advertising ID evidence is invalid or unsafe.');
  }
  const contentRating = evidence.contentRatingDraft ?? {};
  if (contentRating.questionnaireInProgress !== false ||
      contentRating.category !== 'all-other-app-types' ||
      contentRating.userGeneratedContent !== true ||
      contentRating.directUserCommunication !== true ||
      contentRating.preciseDeviceLocationSharedByUser !== true ||
      contentRating.protectedContactAddressEntered !== true ||
      contentRating.iarcTermsAccepted !== true ||
      contentRating.submitted !== true ||
      contentRating.germanyRating !== 'usk-12-plus' ||
      contentRating.sentForReview !== false ||
      contentRating.evidenceRef !==
        'docs/evidence/b11/google-play-iarc-content-rating-completion-20260813.json') {
    fail('Play IARC content-rating completion state is invalid.');
  }
  const listingEvidence = JSON.parse(readFileSync(resolve(repositoryRoot,
    evidence.storeDraft.consoleSaveEvidenceRef), 'utf8'));
  if (listingEvidence.kind !== 'google-play-store-listing-saved' ||
      listingEvidence.status !== 'saved-console-task-completed' ||
      listingEvidence.candidate?.buildNumber !== evidence.candidate.buildNumber ||
      listingEvidence.observedConsoleState?.storeListingTaskCompleted !== true ||
      listingEvidence.observedConsoleState?.dashboardCompletedTasks !== 9 ||
      listingEvidence.observedConsoleState?.dashboardTotalTasks !== 11 ||
      listingEvidence.copy?.mentionsFreeDocuments !== false ||
      listingEvidence.copy?.mentionsDepositOrProtection !== false ||
      listingEvidence.assets?.phoneScreenshots?.uploadedCount !== 4 ||
      listingEvidence.boundaries?.sentForReview !== false ||
      JSON.stringify(listingEvidence).includes('@')) {
    fail('Play store-listing save evidence is invalid or unsafe.');
  }
  const internalReleaseEvidence = JSON.parse(readFileSync(resolve(repositoryRoot,
    evidence.storeDraft.internalReleaseEvidenceRef), 'utf8'));
  if (internalReleaseEvidence.kind !== 'google-play-internal-release-active' ||
      internalReleaseEvidence.status !== 'available-to-internal-testers' ||
      internalReleaseEvidence.candidate?.buildNumber !== evidence.candidate.buildNumber ||
      internalReleaseEvidence.release?.track !== 'internal' ||
      internalReleaseEvidence.release?.statusObserved !== 'available-to-internal-testers' ||
      internalReleaseEvidence.validation?.errorCount !== 0 ||
      internalReleaseEvidence.boundaries?.productionChanged !== false ||
      JSON.stringify(internalReleaseEvidence).includes('@')) {
    fail('Play internal-release evidence is invalid or unsafe.');
  }
  const iarcEvidence = JSON.parse(readFileSync(resolve(repositoryRoot,
    contentRating.evidenceRef), 'utf8'));
  if (iarcEvidence.kind !== 'google-play-iarc-content-rating-completion' ||
      iarcEvidence.status !== 'questionnaire-completed-owner-terms-accepted-ratings-saved' ||
      iarcEvidence.candidate?.buildNumber !== evidence.candidate.buildNumber ||
      iarcEvidence.observedConsoleState?.questionnaire !== 'completed' ||
      iarcEvidence.observedConsoleState?.category !== 'all-other-app-types' ||
      iarcEvidence.observedConsoleState?.ownerAcceptedIarcTerms !== true ||
      iarcEvidence.observedConsoleState?.sentForReview !== false ||
      iarcEvidence.submittedTruth?.nativeUserContentExchange !== true ||
      iarcEvidence.submittedTruth?.userGeneratedContentPrimary !== true ||
      iarcEvidence.submittedTruth?.userOrContentBlocking !== true ||
      iarcEvidence.submittedTruth?.userOrContentReporting !== true ||
      iarcEvidence.submittedTruth?.preciseDeviceLocationSharedByUser !== true ||
      iarcEvidence.submittedTruth?.digitalGoodsPurchases !== false ||
      iarcEvidence.calculatedRatings?.germany !== 'usk-12-plus' ||
      iarcEvidence.boundaries?.questionnaireSubmitted !== true ||
      iarcEvidence.boundaries?.ownerTermsAcceptanceObserved !== true ||
      Object.entries(iarcEvidence.boundaries ?? {}).some(([key, value]) =>
        ['questionnaireSubmitted', 'ownerTermsAcceptanceObserved'].includes(key) ? value !== true : value !== false) ||
      JSON.stringify(iarcEvidence).includes('@')) {
    fail('Play IARC content-rating completion evidence is invalid or unsafe.');
  }
  return {
    status: evidence.status,
    totalTasks: evidence.counts.totalTasks,
    savedTasks: evidence.counts.savedTasks,
    openTasks: evidence.counts.openTasks,
  };
}

function main() {
  const repositoryRoot = resolve(fileURLToPath(new URL('..', import.meta.url)));
  const result = validateGooglePlayAppContentProgress({ repositoryRoot });
  process.stdout.write(`Google Play app-content progress: PASS (${result.savedTasks}/${result.totalTasks} saved, ${result.openTasks} open)\n`);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  try { main(); } catch (error) {
    process.stderr.write(`${error?.message ?? 'Play app-content progress validation failed.'}\n`);
    process.exitCode = 1;
  }
}
