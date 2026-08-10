import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { validateB11ReleaseDocs } from '../../tool/validate_b11_release_docs.mjs';

const repositoryRoot = fileURLToPath(new URL('../../', import.meta.url));
const deviceManifest = JSON.parse(
  readFileSync(resolve(repositoryRoot, 'store/device-validation.json'), 'utf8'),
);
const evidenceRef = deviceManifest.releaseChecks.candidateIdentityAndSignatures.evidenceRef;
const candidateEvidence = JSON.parse(readFileSync(resolve(repositoryRoot, evidenceRef), 'utf8'));
const pubspecText = readFileSync(resolve(repositoryRoot, 'pubspec.yaml'), 'utf8');
const documentPaths = [
  'docs/architecture/B11_CLOSED_STORE_RELEASE_AND_DEVICE_VALIDATION_2026-08-09.md',
  'docs/operations/B11_CLOSED_STORE_AND_DEVICE_TEST_RUNBOOK_2026-08-09.md',
  'docs/evidence/b11/README.md',
];
const documents = Object.fromEntries(
  documentPaths.map((relativePath) => [relativePath, readFileSync(resolve(repositoryRoot, relativePath), 'utf8')]),
);

function validate(overrides = {}) {
  return validateB11ReleaseDocs({
    root: repositoryRoot,
    deviceManifest: structuredClone(deviceManifest),
    candidateEvidence: structuredClone(candidateEvidence),
    pubspecText,
    documents: structuredClone(documents),
    allowCandidateRollover: true,
    ...overrides,
  });
}

function strictBaselineManifest() {
  return structuredClone(deviceManifest);
}

function validateStrict(overrides = {}) {
  return validateB11ReleaseDocs({
    root: repositoryRoot,
    deviceManifest: strictBaselineManifest(),
    candidateEvidence: structuredClone(candidateEvidence),
    pubspecText,
    documents: structuredClone(documents),
    allowCandidateRollover: false,
    ...overrides,
  });
}

test('repository B11 release documentation matches the current candidate', () => {
  const result = validateStrict();
  assert.equal(result.buildNumber, '2026081029');
  assert.equal(result.documents, 3);
  assert.equal(result.passedCells, 0);
  assert.equal(result.passedReleaseChecks, 4);
});

test('rejects a stale build number in a snapshot', () => {
  const changed = structuredClone(documents);
  const path = documentPaths[0];
  changed[path] = changed[path].replace(
    '1.0.0 (2026081029)',
    '1.0.0 (2026080903)',
  );
  assert.throws(() => validateStrict({ documents: changed }), /snapshot is stale or incomplete/);
});

test('rejects a stale or missing app-link diagnostic in a snapshot', () => {
  const changed = structuredClone(documents);
  const path = documentPaths[1];
  changed[path] = changed[path].replace(
    '| Direkte Android-App-Link-Diagnose | `passed`',
    '| Direkte Android-App-Link-Diagnose | `open`',
  );
  assert.throws(() => validateStrict({ documents: changed }), /snapshot is stale or incomplete/);
});

test('rejects a stale or missing authenticated-session diagnostic in a snapshot', () => {
  const changed = structuredClone(documents);
  const path = documentPaths[2];
  changed[path] = changed[path].replace(
    '| Angemeldete Android-Sitzungsdiagnose | `passed`',
    '| Angemeldete Android-Sitzungsdiagnose | `open`',
  );
  assert.throws(() => validateStrict({ documents: changed }), /snapshot is stale or incomplete/);
});

test('rejects a stale or missing synthetic-role booking diagnostic in a snapshot', () => {
  const changed = structuredClone(documents);
  const path = documentPaths[0];
  changed[path] = changed[path].replace(
    '| Synthetische Android-Rollenbuchung | `passed`',
    '| Synthetische Android-Rollenbuchung | `open`',
  );
  assert.throws(() => validateStrict({ documents: changed }), /snapshot is stale or incomplete/);
});

test('rejects a stale or missing authenticated deep-link diagnostic in a snapshot', () => {
  const changed = structuredClone(documents);
  const path = documentPaths[1];
  changed[path] = changed[path].replace(
    '| Authentifizierte Android-Deep-Links | `passed`',
    '| Authentifizierte Android-Deep-Links | `open`',
  );
  assert.throws(() => validateStrict({ documents: changed }), /snapshot is stale or incomplete/);
});

test('rejects duplicate snapshot markers', () => {
  const changed = structuredClone(documents);
  const path = documentPaths[2];
  changed[path] += '\n<!-- SIT_CURRENT_RELEASE_SNAPSHOT_BEGIN -->\n';
  assert.throws(() => validateStrict({ documents: changed }), /exactly one current-release snapshot block/);
});

test('rejects candidate evidence whose artifact hash differs', () => {
  const changed = structuredClone(candidateEvidence);
  changed.android.apkSha256 = 'a'.repeat(64);
  assert.throws(
    () => validateStrict({ candidateEvidence: changed }),
    /candidate evidence.android.apkSha256 does not match/,
  );
});

test('rejects a device matrix row that points to an older build', () => {
  const changed = structuredClone(documents);
  const path = documentPaths[1];
  changed[path] = changed[path].replace(
    '| Android real | offen | offen | `2026081029` | WLAN',
    '| Android real | offen | offen | `2026080903` | WLAN',
  );
  assert.throws(() => validateStrict({ documents: changed }), /four runbook device-matrix rows/);
});

test('rejects pubspec drift from the documented candidate', () => {
  assert.throws(
    () => validateStrict({ pubspecText: 'version: 1.0.0+2026081028\n' }),
    /candidate.buildNumber does not match/,
  );
});

test('rollover mode accepts an incomplete current candidate above the documented baseline', () => {
  const result = validate({ pubspecText: 'version: 1.0.0+2026081030\n' });
  assert.equal(result.buildNumber, '2026081029');
  assert.equal(result.rolloverBuildNumber, '2026081030');
  assert.equal(result.documentedBuild, '2026081029');
  assert.equal(result.passedReleaseChecks, 4);
});

test('rollover mode rejects a build older than the documented candidate', () => {
  assert.throws(
    () => validate({
      pubspecText: `version: 1.0.0+2026081028\n`,
    }),
    /must not be older than the documented candidate/,
  );
});
