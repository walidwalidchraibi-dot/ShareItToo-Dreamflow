#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

function fail(message) {
  throw new Error(message);
}

export function validateGooglePlayScreenshotReadiness({
  repositoryRoot,
  evidencePath = resolve(repositoryRoot, 'docs/evidence/b11/google-play-feed-screenshot-readiness-20260812.json'),
} = {}) {
  const evidence = JSON.parse(readFileSync(evidencePath, 'utf8'));
  if (evidence.schemaVersion !== 1 ||
      evidence.kind !== 'google-play-feed-screenshot-readiness' ||
      evidence.status !== 'blocked-legacy-technical-listings-visible') {
    fail('Feed screenshot readiness must preserve the observed blocked state.');
  }
  if (evidence.candidate?.applicationId !== 'com.shareittoo.app' ||
      evidence.candidate?.versionName !== '1.0.0' ||
      evidence.candidate?.buildNumber !== '2026081116' ||
      evidence.candidate?.releaseChannel !== 'internal' ||
      evidence.candidate?.apiBaseUrl !== 'https://staging.shareittoo.com/api/v1') {
    fail('Feed screenshot readiness is not bound to the exact internal candidate.');
  }
  if (evidence.device?.installedCandidateVerified !== true ||
      evidence.device?.syntheticScreenshotSessionReady !== true ||
      evidence.fixture?.status !== 'ready-reused' ||
      evidence.fixture?.curatedListingCount !== 4 ||
      evidence.fixture?.createdDuringObservation !== 0 ||
      evidence.feedObservation?.curatedListingVisible !== true ||
      evidence.feedObservation?.legacyTechnicalListingsVisible !== true ||
      evidence.feedObservation?.storeScreenshotAccepted !== false) {
    fail('Feed screenshot observation is incomplete or prematurely accepted.');
  }
  if (evidence.requiredRemediation?.deletionAuthorized !== false ||
      evidence.requiredRemediation?.productionChangeAuthorized !== false) {
    fail('Screenshot remediation must not claim destructive or production authority.');
  }
  const boundaries = evidence.boundaries ?? {};
  if (Object.keys(boundaries).length !== 9 ||
      Object.values(boundaries).some((value) => value !== false) ||
      JSON.stringify(evidence).includes('@')) {
    fail('Screenshot readiness must remain sanitized and side-effect free.');
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
