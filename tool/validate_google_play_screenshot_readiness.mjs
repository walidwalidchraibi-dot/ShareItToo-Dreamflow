#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

function fail(message) {
  throw new Error(message);
}

export function validateGooglePlayScreenshotReadiness({
  repositoryRoot,
  evidencePath = resolve(repositoryRoot, 'docs/evidence/b11/google-play-feed-screenshot-readiness-20260813.json'),
} = {}) {
  const evidence = JSON.parse(readFileSync(evidencePath, 'utf8'));
  const exactCandidate = JSON.parse(readFileSync(
    resolve(repositoryRoot, 'store/device-validation.json'), 'utf8')).candidate;
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
