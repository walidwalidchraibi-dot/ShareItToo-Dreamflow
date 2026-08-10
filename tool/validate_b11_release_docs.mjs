#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const snapshotBegin = '<!-- SIT_CURRENT_RELEASE_SNAPSHOT_BEGIN -->';
const snapshotEnd = '<!-- SIT_CURRENT_RELEASE_SNAPSHOT_END -->';

const snapshotDocuments = [
  'docs/architecture/B11_CLOSED_STORE_RELEASE_AND_DEVICE_VALIDATION_2026-08-09.md',
  'docs/operations/B11_CLOSED_STORE_AND_DEVICE_TEST_RUNBOOK_2026-08-09.md',
  'docs/evidence/b11/README.md',
];

function fail(message) {
  throw new Error(message);
}

function object(value, label) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${label} must be an object.`);
  }
  return value;
}

function nonEmptyString(value, label) {
  if (typeof value !== 'string' || value.trim() === '') {
    fail(`${label} must be a non-empty string.`);
  }
  return value.trim();
}

function sha256(value, label) {
  const result = nonEmptyString(value, label).toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(result)) fail(`${label} must be a SHA-256 value.`);
  return result;
}

function fullCommit(value, label) {
  const result = nonEmptyString(value, label).toLowerCase();
  if (!/^[a-f0-9]{40}$/.test(result)) fail(`${label} must be a full Git commit.`);
  return result;
}

function readJson(root, relativePath) {
  try {
    return JSON.parse(readFileSync(resolve(root, relativePath), 'utf8'));
  } catch (error) {
    fail(`${relativePath} could not be read as JSON: ${error.message}`);
  }
}

function parsePubspecVersion(pubspecText) {
  const match = /^version:\s*(\d+\.\d+\.\d+)\+(\d{10})\s*$/m.exec(pubspecText);
  if (!match) fail('pubspec.yaml must use semantic+YYYYMMDDNN versioning.');
  return { versionName: match[1], buildNumber: match[2] };
}

function countMatches(text, needle) {
  return text.split(needle).length - 1;
}

function same(actual, expected, label) {
  if (actual !== expected) fail(`${label} does not match the current candidate.`);
}

export function renderB11ReleaseSnapshot({ deviceManifest, candidateEvidence }) {
  const manifest = object(deviceManifest, 'store/device-validation.json');
  const candidate = object(manifest.candidate, 'candidate');
  const android = object(candidate.android, 'candidate.android');
  const diagnostic = object(android.directDiagnostic, 'candidate.android.directDiagnostic');
  const evidence = object(candidateEvidence, 'candidate evidence');
  const staging = object(evidence.staging, 'candidate evidence.staging');

  const passedCells = Array.isArray(manifest.deviceMatrix)
    ? manifest.deviceMatrix.filter((cell) => cell?.status === 'passed').length
    : 0;
  const totalCells = Array.isArray(manifest.deviceMatrix) ? manifest.deviceMatrix.length : 0;
  const releaseChecks = Object.values(object(manifest.releaseChecks, 'releaseChecks'));
  const passedReleaseChecks = releaseChecks.filter((check) => check?.status === 'passed').length;

  return `${snapshotBegin}
### Aktueller maschinengebundener B11-Kandidat

| Merkmal | Verbindlicher Wert |
|---|---|
| App-Identität | \`${nonEmptyString(candidate.applicationId, 'candidate.applicationId')}\` (Android und iOS) |
| Version und Build | \`${nonEmptyString(candidate.versionName, 'candidate.versionName')} (${nonEmptyString(candidate.buildNumber, 'candidate.buildNumber')})\` |
| App-Commit | \`${fullCommit(candidate.commit, 'candidate.commit')}\` |
| Kanal und API | \`${nonEmptyString(candidate.releaseChannel, 'candidate.releaseChannel')}\`, \`${nonEmptyString(candidate.apiBaseUrl, 'candidate.apiBaseUrl')}\` |
| Firebase und Zahlung | vollständig: \`${candidate.firebaseConfigured === true}\`; \`${nonEmptyString(candidate.paymentMode, 'candidate.paymentMode')}\`; \`stripeLivemode=${candidate.stripeLivemode === true}\` |
| Android-AAB SHA-256 | \`${sha256(android.aabSha256, 'candidate.android.aabSha256')}\` |
| Android-APK SHA-256 | \`${sha256(android.apkSha256, 'candidate.android.apkSha256')}\` |
| Uploadzertifikat SHA-256 | \`${sha256(android.signingCertificateSha256, 'candidate.android.signingCertificateSha256')}\` |
| Direkte Android-Diagnose | \`${nonEmptyString(diagnostic.status, 'candidate.android.directDiagnostic.status')}\` auf ${nonEmptyString(diagnostic.deviceModel, 'candidate.android.directDiagnostic.deviceModel')}, Android ${nonEmptyString(diagnostic.osVersion, 'candidate.android.directDiagnostic.osVersion')}; \`${nonEmptyString(diagnostic.evidenceRef, 'candidate.android.directDiagnostic.evidenceRef')}\` |
| Kandidatenbeleg | \`${nonEmptyString(manifest.releaseChecks.candidateIdentityAndSignatures.evidenceRef, 'releaseChecks.candidateIdentityAndSignatures.evidenceRef')}\` |
| Staging-Servercommit | \`${fullCommit(staging.serverCommit, 'candidate evidence.staging.serverCommit')}\` |
| Ehrlicher Freigabestand | \`${nonEmptyString(manifest.state, 'state')}/${nonEmptyString(manifest.goNoGo, 'goNoGo')}\`; Gerätezellen ${passedCells}/${totalCells}; Releaseprüfungen ${passedReleaseChecks}/${releaseChecks.length} |

Dieser Block wird aus den verbindlichen JSON-Nachweisen geprüft. Die direkte APK-Diagnose ist keine Store-Installation und schließt weder die Rollen-/Netzmatrix noch TalkBack, Push, iOS/TestFlight, Produktion oder Echtgeld.
${snapshotEnd}`;
}

export function validateB11ReleaseDocs({
  root,
  deviceManifest,
  candidateEvidence,
  pubspecText,
  documents,
}) {
  const manifest = object(deviceManifest, 'store/device-validation.json');
  const candidate = object(manifest.candidate, 'candidate');
  const evidence = object(candidateEvidence, 'candidate evidence');
  const evidenceCandidate = object(evidence.candidate, 'candidate evidence.candidate');
  const evidenceAndroid = object(evidence.android, 'candidate evidence.android');
  const android = object(candidate.android, 'candidate.android');
  const pubspec = parsePubspecVersion(pubspecText);

  if (manifest.schemaVersion !== 1 || evidence.schemaVersion !== 1) {
    fail('B11 manifest and candidate evidence must both use schemaVersion=1.');
  }
  if (evidence.kind !== 'android-release-candidate') {
    fail('The candidate evidence must use kind=android-release-candidate.');
  }
  same(candidate.versionName, pubspec.versionName, 'candidate.versionName');
  same(candidate.buildNumber, pubspec.buildNumber, 'candidate.buildNumber');

  for (const key of [
    'applicationId',
    'bundleId',
    'versionName',
    'buildNumber',
    'commit',
    'releaseChannel',
    'apiBaseUrl',
    'firebaseConfigured',
    'paymentMode',
    'stripeLivemode',
  ]) {
    same(evidenceCandidate[key], candidate[key], `candidate evidence.candidate.${key}`);
  }
  for (const key of ['aabSha256', 'apkSha256', 'signingCertificateSha256']) {
    same(evidenceAndroid[key], android[key], `candidate evidence.android.${key}`);
  }
  if (evidenceAndroid.signatureVerified !== true || evidenceAndroid.packageIdentityVerified !== true) {
    fail('The current Android candidate evidence must verify signature and package identity.');
  }
  if (evidence.privacyAndNetwork?.binaryScan !== 'passed') {
    fail('The current Android candidate evidence must contain a passed binary privacy scan.');
  }
  if (evidence.boundaries?.uploadedToStore !== false || evidence.boundaries?.containsSecrets !== false || evidence.boundaries?.containsRawDeviceIdentifiers !== false) {
    fail('The current candidate evidence must preserve store, secret, and device-identifier boundaries.');
  }

  const expectedSnapshot = renderB11ReleaseSnapshot({ deviceManifest: manifest, candidateEvidence: evidence });
  for (const relativePath of snapshotDocuments) {
    const content = documents?.[relativePath] ?? readFileSync(resolve(root, relativePath), 'utf8');
    if (countMatches(content, snapshotBegin) !== 1 || countMatches(content, snapshotEnd) !== 1) {
      fail(`${relativePath} must contain exactly one current-release snapshot block.`);
    }
    if (!content.includes(expectedSnapshot)) {
      fail(`${relativePath} current-release snapshot is stale or incomplete.`);
    }
  }

  const runbookPath = 'docs/operations/B11_CLOSED_STORE_AND_DEVICE_TEST_RUNBOOK_2026-08-09.md';
  const runbook = documents?.[runbookPath] ?? readFileSync(resolve(root, runbookPath), 'utf8');
  const matrixRows = runbook
    .split('\n')
    .filter((line) => /^\| (Android|iOS) real \|/.test(line));
  if (matrixRows.length !== 4 || matrixRows.some((line) => !line.includes(`\`${candidate.buildNumber}\``))) {
    fail('The four runbook device-matrix rows must use the current candidate build number.');
  }

  return {
    buildNumber: candidate.buildNumber,
    commit: candidate.commit,
    documents: snapshotDocuments.length,
    passedCells: manifest.deviceMatrix.filter((cell) => cell.status === 'passed').length,
    totalCells: manifest.deviceMatrix.length,
    passedReleaseChecks: Object.values(manifest.releaseChecks).filter((check) => check.status === 'passed').length,
    totalReleaseChecks: Object.keys(manifest.releaseChecks).length,
  };
}

function loadRepositoryInputs(root) {
  const deviceManifest = readJson(root, 'store/device-validation.json');
  const evidenceRef = nonEmptyString(
    deviceManifest.releaseChecks?.candidateIdentityAndSignatures?.evidenceRef,
    'releaseChecks.candidateIdentityAndSignatures.evidenceRef',
  );
  if (!/^docs\/evidence\/b11\/[a-z0-9._-]+\.json$/.test(evidenceRef)) {
    fail('The current candidate evidence reference must stay below docs/evidence/b11/.');
  }
  return {
    deviceManifest,
    candidateEvidence: readJson(root, evidenceRef),
    pubspecText: readFileSync(resolve(root, 'pubspec.yaml'), 'utf8'),
  };
}

const invokedPath = process.argv[1] ? pathToFileURL(resolve(process.argv[1])).href : null;
if (invokedPath === import.meta.url) {
  try {
    const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
    const result = validateB11ReleaseDocs({ root, ...loadRepositoryInputs(root) });
    console.log(
      `B11 release docs valid: build=${result.buildNumber}, documents=${result.documents}, ` +
      `matrix=${result.passedCells}/${result.totalCells}, releaseChecks=${result.passedReleaseChecks}/${result.totalReleaseChecks}.`,
    );
  } catch (error) {
    console.error(`ERROR: ${error.message}`);
    process.exit(1);
  }
}
