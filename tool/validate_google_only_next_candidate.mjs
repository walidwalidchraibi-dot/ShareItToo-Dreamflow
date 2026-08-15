#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

function fail(message) {
  throw new Error(message);
}

function enabled(value) {
  return value === '1' || value === 'true' || value === true;
}

function buildNumberFromPubspec(contents) {
  const match = /^version:\s*[^+\s]+\+(\d+)\s*$/mu.exec(contents);
  if (!match) fail('pubspec.yaml must contain a numeric Flutter build number.');
  return match[1];
}

export function validateGoogleOnlyNextCandidate({
  repositoryRoot,
  requireBuildable = false,
  environment = {},
  manifestPath = resolve(repositoryRoot, 'store/google-only-next-candidate.json'),
  pubspecContents = readFileSync(resolve(repositoryRoot, 'pubspec.yaml'), 'utf8'),
} = {}) {
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  const device = JSON.parse(readFileSync(resolve(repositoryRoot, 'store/device-validation.json'), 'utf8'));
  const policy = manifest.nextCandidatePolicy ?? {};
  const baseline = manifest.baselineCandidate ?? {};
  if (manifest.schemaVersion !== 1 ||
      manifest.kind !== 'google-only-next-consolidated-candidate' ||
      manifest.state !== 'prepared-not-built' ||
      baseline.applicationId !== device.candidate?.applicationId ||
      baseline.versionName !== device.candidate?.versionName ||
      baseline.buildNumber !== device.candidate?.buildNumber ||
      baseline.commit !== device.candidate?.commit ||
      baseline.releaseChannel !== 'internal' ||
      baseline.apiBaseUrl !== 'https://staging.shareittoo.com/api/v1' ||
      policy.versionName !== baseline.versionName ||
      policy.buildNumberRule !== 'strictly-higher-than-baseline' ||
      policy.releaseChannel !== 'internal' ||
      policy.apiBaseUrl !== 'https://staging.shareittoo.com/api/v1' ||
      policy.googleLoginEnabled !== true ||
      policy.appleLoginEnabled !== false ||
      policy.facebookLoginEnabled !== false ||
      policy.providerEvidenceRef !==
        'docs/evidence/b11/firebase-google-signin-provider-20260815.json') {
    fail('Google-only next-candidate plan is stale or no longer fail-closed.');
  }
  const provider = JSON.parse(readFileSync(resolve(
    repositoryRoot, policy.providerEvidenceRef), 'utf8'));
  if (provider.kind !== 'firebase-google-signin-provider-configuration' ||
      provider.firebase?.providerEnabled !== true ||
      provider.firebase?.appleProviderEnabled !== false ||
      provider.firebase?.facebookProviderEnabled !== false ||
      provider.localConfigurations?.android?.uploadSigningSha1ClientPresent !== true ||
      provider.localConfigurations?.android?.playAppSigningSha1ClientPresent !== true ||
      provider.localConfigurations?.android?.webClientCount !== 1 ||
      provider.candidate?.buildNumber !== baseline.buildNumber ||
      provider.candidate?.googleLoginReleaseGateEnabled !== false ||
      provider.candidate?.appleLoginReleaseGateEnabled !== false ||
      provider.candidate?.facebookLoginReleaseGateEnabled !== false) {
    fail('Google provider evidence is incomplete or contradicts the baseline candidate.');
  }
  const hardStops = manifest.hardStops ?? {};
  const requiredTrue = [
    'sameOrOlderBuildNumber',
    'appleWithoutAppleDeveloperConfiguration',
    'facebookWithoutMetaConfiguration',
    'productionApi',
    'storeSubmission',
    'realPayments',
  ];
  const requiredFalse = [
    'containsSecrets',
    'containsEmailAddresses',
    'containsAccountIdentifiers',
  ];
  if (Object.keys(hardStops).length !== 9 ||
      requiredTrue.some((key) => hardStops[key] !== true) ||
      requiredFalse.some((key) => hardStops[key] !== false)) {
    fail('Google-only next-candidate hard stops are incomplete or unsafe.');
  }
  const plannedBuildNumber = buildNumberFromPubspec(pubspecContents);
  if (requireBuildable) {
    if (BigInt(plannedBuildNumber) <= BigInt(baseline.buildNumber)) {
      fail('Next consolidated candidate requires a strictly higher build number.');
    }
    if (!enabled(environment.SIT_SOCIAL_GOOGLE_ENABLED) ||
        enabled(environment.SIT_SOCIAL_APPLE_ENABLED) ||
        enabled(environment.SIT_SOCIAL_FACEBOOK_ENABLED)) {
      fail('Next consolidated candidate must enable Google only.');
    }
    if ((environment.SIT_RELEASE_CHANNEL ?? 'internal') !== 'internal' ||
        (environment.SIT_API_BASE_URL ?? 'https://staging.shareittoo.com/api/v1') !==
          'https://staging.shareittoo.com/api/v1' ||
        enabled(environment.SIT_REQUIRE_STORE_SUBMISSION)) {
      fail('Google-only candidate is restricted to internal Staging without submission.');
    }
  }
  return {
    state: manifest.state,
    baselineBuildNumber: baseline.buildNumber,
    plannedBuildNumber,
    buildable: requireBuildable,
  };
}

function runCli() {
  const repositoryRoot = resolve(fileURLToPath(new URL('..', import.meta.url)));
  const requireBuildable = process.argv.includes('--require-buildable');
  const unknown = process.argv.slice(2).filter((value) => value !== '--require-buildable');
  if (unknown.length) fail(`Unknown argument: ${unknown[0]}`);
  const result = validateGoogleOnlyNextCandidate({
    repositoryRoot,
    requireBuildable,
    environment: process.env,
  });
  process.stdout.write(
    `Google-only next candidate: PASS (${result.state}, baseline ${result.baselineBuildNumber}, ` +
      `planned ${result.plannedBuildNumber}, buildable=${result.buildable})\n`,
  );
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  try {
    runCli();
  } catch (error) {
    process.stderr.write(`${error?.message ?? 'Google-only next-candidate validation failed.'}\n`);
    process.exitCode = 1;
  }
}
