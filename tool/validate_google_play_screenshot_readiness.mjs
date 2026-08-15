#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

function fail(message) {
  throw new Error(message);
}

export function validateGooglePlayScreenshotReadiness({
  repositoryRoot,
  evidencePath = resolve(repositoryRoot, 'docs/evidence/b11/google-play-feed-screenshot-readiness-2026081505-20260815.json'),
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
    const currentCandidateEvidence = JSON.parse(readFileSync(safeRef(
      review.currentCandidateEvidenceRef, 'currentCandidateEvidenceRef'), 'utf8'));
    const storeInstall = JSON.parse(readFileSync(safeRef(
      review.baselineStoreInstallEvidenceRef, 'baselineStoreInstallEvidenceRef'), 'utf8'));
    const roleBooking = JSON.parse(readFileSync(safeRef(
      review.baselineRoleBookingEvidenceRef, 'baselineRoleBookingEvidenceRef'), 'utf8'));
    const expectedChangedFiles = [
      'lib/config/legal_provider_config.dart',
      'lib/main.dart',
      'lib/screens/change_address_screen.dart',
      'lib/screens/change_password_screen.dart',
      'lib/screens/check_availability_screen.dart',
      'lib/screens/contact_data_screen.dart',
      'lib/screens/edit_social_media_screen.dart',
      'lib/screens/invoice_detail_screen.dart',
      'lib/screens/legal_cancellation_policy_screen.dart',
      'lib/screens/legal_community_rules_screen.dart',
      'lib/screens/legal_fees_payments_screen.dart',
      'lib/screens/legal_imprint_screen.dart',
      'lib/screens/legal_privacy_screen.dart',
      'lib/screens/legal_terms_screen.dart',
      'lib/screens/message_thread_screen.dart',
      'lib/screens/messages_screen.dart',
      'lib/screens/moderation_admin_screen.dart',
      'lib/screens/notifications_screen.dart',
      'lib/screens/payment_checkout_screen.dart',
      'lib/screens/privacy_info_screen.dart',
      'lib/screens/report_user_screen.dart',
      'lib/screens/security_screen.dart',
      'lib/screens/select_rental_duration_screen.dart',
      'lib/screens/two_factor_auth_screen.dart',
      'lib/services/backend_realtime_service.dart',
      'lib/services/data_service.dart',
      'lib/services/firebase_runtime.dart',
      'lib/widgets/app_popup.dart',
      'lib/widgets/foreground_push_host.dart',
      'lib/widgets/messages_settings_sheet.dart',
      'lib/widgets/review_prompt_sheet.dart',
      'lib/widgets/search_overlay.dart',
    ];
    if (review.sourceSnapshotCommit !== '95f3e2e3ca7363f729c6a6d9ecf4170ddda501df' ||
        JSON.stringify(review.changedAppSourceFilesSinceSourceSnapshot) !==
          JSON.stringify(expectedChangedFiles) ||
        JSON.stringify(review.changedVisibleScreenshotSourceFiles) !== '[]' ||
        review.visibleScreenSourceChanged !== false ||
        review.storeListingCoreFlowsChanged !== false ||
        review.screenshotsNeedRecapture !== false ||
        currentCandidateEvidence.candidate?.buildNumber !== current.buildNumber ||
        currentCandidateEvidence.candidate?.commit !== current.commit ||
        currentCandidateEvidence.android?.apkSha256 !== current.apkSha256 ||
        currentCandidateEvidence.android?.signatureVerified !== true ||
        currentCandidateEvidence.android?.packageIdentityVerified !== true ||
        BigInt(storeInstall.candidate?.buildNumber ?? '0') > BigInt(current.buildNumber) ||
        storeInstall.postReleaseChecks?.playStoreInstallCompleted !== true ||
        storeInstall.postReleaseChecks?.installedVersionVerified !== true ||
        roleBooking.candidate?.buildNumber !== storeInstall.candidate?.buildNumber ||
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
