#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

function fail(message) {
  throw new Error(message);
}

export function validateGooglePlayScreenshotReadiness({
  repositoryRoot,
  evidencePath = resolve(repositoryRoot, 'docs/evidence/b11/google-play-feed-screenshot-compatibility-2026081401-20260814.json'),
} = {}) {
  const evidence = JSON.parse(readFileSync(evidencePath, 'utf8'));
  const exactCandidate = JSON.parse(readFileSync(
    resolve(repositoryRoot, 'store/device-validation.json'), 'utf8')).candidate;
  if (evidence.kind === 'google-play-feed-screenshot-compatibility') {
    if (evidence.schemaVersion !== 1 ||
        evidence.status !== 'verified-compatible-no-visible-product-change') {
      fail('Screenshot compatibility must preserve the verified compatibility state.');
    }
    const current = evidence.currentCandidate ?? {};
    if (current.applicationId !== 'com.shareittoo.app' ||
        current.versionName !== exactCandidate?.versionName ||
        current.buildNumber !== exactCandidate?.buildNumber ||
        current.commit !== exactCandidate?.commit ||
        current.apkSha256 !== exactCandidate?.android?.apkSha256) {
      fail('Screenshot compatibility is not bound to the exact current candidate.');
    }
    const safeRef = (ref, label) => {
      if (typeof ref !== 'string' || ref.includes('..') ||
          !ref.startsWith('docs/evidence/b11/') || !ref.endsWith('.json')) {
        fail(`${label} is not a safe B11 evidence reference.`);
      }
      return resolve(repositoryRoot, ref);
    };
    const source = JSON.parse(readFileSync(safeRef(
      evidence.sourceScreenshotEvidenceRef, 'sourceScreenshotEvidenceRef'), 'utf8'));
    const sourceCandidate = JSON.parse(readFileSync(safeRef(
      evidence.sourceCandidateEvidenceRef, 'sourceCandidateEvidenceRef'), 'utf8'));
    if (source.kind !== 'google-play-feed-screenshot-readiness' ||
        source.status !== 'exact-candidate-local-screenshots-validated-not-uploaded' ||
        source.candidate?.buildNumber !== sourceCandidate.candidate?.buildNumber ||
        source.candidate?.commit !== sourceCandidate.candidate?.commit ||
        source.candidate?.apkSha256 !== sourceCandidate.android?.apkSha256 ||
        BigInt(source.candidate?.buildNumber ?? '0') >= BigInt(current.buildNumber)) {
      fail('Screenshot compatibility source is stale or not an exact historical candidate.');
    }
    const review = evidence.compatibilityReview ?? {};
    const storeInstall = JSON.parse(readFileSync(safeRef(
      review.currentStoreInstallEvidenceRef, 'currentStoreInstallEvidenceRef'), 'utf8'));
    const roleBooking = JSON.parse(readFileSync(safeRef(
      review.currentRoleBookingEvidenceRef, 'currentRoleBookingEvidenceRef'), 'utf8'));
    if (review.sourceSnapshotCommit !== '95f3e2e3ca7363f729c6a6d9ecf4170ddda501df' ||
        JSON.stringify(review.changedAppSourceFilesSinceSourceSnapshot) !==
          JSON.stringify(['lib/services/backend_realtime_service.dart']) ||
        review.visibleScreenSourceChanged !== false ||
        review.storeListingCoreFlowsChanged !== false ||
        review.screenshotsNeedRecapture !== false ||
        storeInstall.candidate?.buildNumber !== current.buildNumber ||
        storeInstall.postReleaseChecks?.playStoreInstallCompleted !== true ||
        storeInstall.postReleaseChecks?.installedVersionVerified !== true ||
        roleBooking.candidate?.buildNumber !== current.buildNumber ||
        roleBooking.status !== 'passed-bounded-synthetic-role-booking-diagnostic') {
      fail('Screenshot compatibility review is incomplete or contradicts the current Store build.');
    }
    const boundaries = evidence.boundaries ?? {};
    if (Object.keys(boundaries).length !== 7 ||
        Object.values(boundaries).some((value) => value !== false) ||
        JSON.stringify(evidence).includes('@')) {
      fail('Screenshot compatibility must not claim Store changes or contain private data.');
    }
    return { status: evidence.status, curatedListingCount: source.fixture.curatedListingCount };
  }
  if (evidence.schemaVersion !== 1 ||
      evidence.kind !== 'google-play-feed-screenshot-readiness' ||
      evidence.status !== 'exact-candidate-local-screenshots-validated-not-uploaded') {
    fail('Feed screenshot readiness must preserve the exact local candidate state.');
  }
  if (evidence.candidate?.applicationId !== 'com.shareittoo.app' ||
      evidence.candidate?.versionName !== exactCandidate?.versionName ||
      evidence.candidate?.buildNumber !== exactCandidate?.buildNumber ||
      evidence.candidate?.commit !== exactCandidate?.commit ||
      evidence.candidate?.apkSha256 !== exactCandidate?.android?.apkSha256 ||
      evidence.candidate?.releaseChannel !== 'internal' ||
      evidence.candidate?.apiBaseUrl !== 'https://staging.shareittoo.com/api/v1' ||
      Object.hasOwn(evidence, 'replacementBuildNumber') ||
      Object.hasOwn(evidence, 'supersessionEvidenceRef')) {
    fail('Feed screenshot readiness is not bound to the exact installed build.');
  }
  if (evidence.device?.installedCandidateVerified !== true ||
      evidence.device?.syntheticScreenshotSessionReady !== true ||
      evidence.fixture?.status !== 'ready-reused' ||
      evidence.fixture?.curatedListingCount !== 4 ||
      evidence.fixture?.createdDuringObservation !== 0 ||
      evidence.feedObservation?.curatedListingVisible !== true ||
      evidence.feedObservation?.legacyTechnicalListingsVisible !== false ||
      evidence.feedObservation?.placeholderImagesVisible !== false ||
      evidence.feedObservation?.technicalFixtureCopyVisible !== false ||
      evidence.feedObservation?.protectedActiveBookings !== 6 ||
      evidence.feedObservation?.protectedPublicListingsObserved !== 6 ||
      evidence.feedObservation?.storeScreenshotAccepted !== true ||
      evidence.feedObservation?.validatedLocalCandidates !== 4) {
    fail('Feed screenshot observation is incomplete or contradicts the verified cleanup.');
  }
  if (evidence.completedRemediation?.method !==
        'pause-unreferenced-and-neutralize-protected-staging-listings' ||
      evidence.completedRemediation?.deletionPerformed !== false ||
      evidence.completedRemediation?.protectedBookingsPreserved !== true ||
      evidence.completedRemediation?.deletionAuthorized !== false ||
      evidence.completedRemediation?.productionChangeAuthorized !== false) {
    fail('Screenshot remediation must not claim destructive or production authority.');
  }
  if (!Array.isArray(evidence.candidateEvidenceRefs) || evidence.candidateEvidenceRefs.length !== 4) {
    fail('Screenshot readiness must bind all four validated local candidates.');
  }
  for (const ref of evidence.candidateEvidenceRefs) {
    const candidate = JSON.parse(readFileSync(resolve(repositoryRoot, ref), 'utf8'));
    if (candidate.status !== 'exact-candidate-local-not-uploaded' ||
        candidate.candidate?.buildNumber !== evidence.candidate.buildNumber) {
      fail('Screenshot readiness references a stale or unvalidated local candidate.');
    }
  }
  const boundaries = evidence.boundaries ?? {};
  if (Object.keys(boundaries).length !== 9 || boundaries.screenshotUploaded !== false ||
      boundaries.listingDeleted !== false || boundaries.listingPaused !== true ||
      Object.entries(boundaries).some(([key, value]) => key !== 'listingPaused' && value !== false) ||
      JSON.stringify(evidence).includes('@')) {
    fail('Screenshot readiness must remain sanitized and report only the bounded Staging pause.');
  }
  return { status: evidence.status, curatedListingCount: evidence.fixture.curatedListingCount };
}

function runCli() {
  const repositoryRoot = resolve(fileURLToPath(new URL('..', import.meta.url)));
  const result = validateGooglePlayScreenshotReadiness({ repositoryRoot });
  process.stdout.write(`Google Play screenshot readiness: PASS (${result.status}, ${result.curatedListingCount} curated listings)\n`);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  try {
    runCli();
  } catch (error) {
    process.stderr.write(`${error?.message ?? 'Google Play screenshot readiness failed.'}\n`);
    process.exitCode = 1;
  }
}
