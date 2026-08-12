#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

function fail(message) {
  throw new Error(message);
}

function pngDimensions(bytes) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (bytes.length < 33 || !bytes.subarray(0, 8).equals(signature) ||
      bytes.subarray(12, 16).toString('ascii') !== 'IHDR') fail('Screenshot is not a valid PNG.');
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
}

export function validateGooglePlayScreenshotCandidate({
  repositoryRoot,
  evidencePath = resolve(repositoryRoot,
    'docs/evidence/b11/google-play-screenshot-candidate-feed-20260812.json'),
} = {}) {
  const evidence = JSON.parse(readFileSync(evidencePath, 'utf8'));
  if (evidence.schemaVersion !== 1 || evidence.kind !== 'google-play-screenshot-candidate' ||
      evidence.status !== 'validated-local-not-uploaded') fail('Screenshot candidate state is invalid.');
  if (evidence.candidate?.applicationId !== 'com.shareittoo.app' ||
      evidence.candidate?.versionName !== '1.0.0' ||
      evidence.candidate?.buildNumber !== '2026081116' ||
      evidence.candidate?.releaseChannel !== 'internal' ||
      evidence.candidate?.apiBaseUrl !== 'https://staging.shareittoo.com/api/v1') {
    fail('Screenshot candidate is not bound to the exact internal build.');
  }
  const scene = evidence.scene ?? {};
  if (!['feed', 'listing-detail'].includes(scene.id) || scene.locale !== 'de-DE' ||
      scene.syntheticContent !== true || scene.format !== 'png' ||
      !/^store\/assets\/google-play\/phone-screenshots\/0[12]-[a-z-]+\.png$/u.test(scene.storeFile)) {
    fail('Screenshot candidate scene metadata is invalid.');
  }
  const path = resolve(repositoryRoot, scene.storeFile);
  if (!path.startsWith(`${resolve(repositoryRoot)}/`)) fail('Screenshot path escapes the repository.');
  const bytes = readFileSync(path);
  const dimensions = pngDimensions(bytes);
  if (dimensions.width !== scene.width || dimensions.height !== scene.height ||
      scene.width < 320 || scene.height < 320 || scene.height > scene.width * 2 ||
      bytes.length !== scene.byteSize ||
      createHash('sha256').update(bytes).digest('hex') !== scene.sha256) {
    fail('Screenshot dimensions, size, or digest no longer match the evidence.');
  }
  if (scene.id === 'feed') {
    const cleanup = evidence.feedCleanup ?? {};
    if (cleanup.protectedActiveBookings !== 6 || cleanup.protectedPublicListingsObserved !== 6 ||
        cleanup.placeholderImagesRemaining !== 0 || cleanup.technicalCopyRemaining !== 0 ||
        cleanup.publicTechnicalTitlesRemaining !== 0 || cleanup.listingDeleted !== false ||
        scene.width !== 1080 || scene.height !== 1920) {
      fail('Feed screenshot cleanup or recommended dimensions are incomplete.');
    }
  }
  const validation = evidence.validation ?? {};
  if (Object.keys(validation).length !== 8 ||
      validation.exactInstalledCandidateObserved !== true ||
      validation.curatedSyntheticListing !== true ||
      validation.visualInspectionPassed !== true ||
      validation.personalDataVisible !== false || validation.deviceStatusBarVisible !== false ||
      validation.testCredentialVisible !== false || validation.technicalFixtureCopyVisible !== false ||
      validation.unapprovedProtectionClaimVisible !== false) {
    fail('Screenshot visual validation is incomplete.');
  }
  const boundaries = evidence.boundaries ?? {};
  if (Object.keys(boundaries).length !== 9 || Object.values(boundaries).some((value) => value !== false) ||
      JSON.stringify(evidence).includes('@')) fail('Screenshot candidate boundaries are unsafe.');
  return { status: evidence.status, scene: scene.id, width: scene.width, height: scene.height };
}

function main() {
  const repositoryRoot = resolve(fileURLToPath(new URL('..', import.meta.url)));
  const result = validateGooglePlayScreenshotCandidate({ repositoryRoot });
  process.stdout.write(`Google Play screenshot candidate: PASS (${result.scene}, ${result.width}x${result.height})\n`);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  try { main(); } catch (error) {
    process.stderr.write(`${error?.message ?? 'Screenshot candidate validation failed.'}\n`);
    process.exitCode = 1;
  }
}
