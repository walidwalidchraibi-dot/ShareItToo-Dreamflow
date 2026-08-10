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
    ...overrides,
  });
}

test('repository B11 release documentation matches the current candidate', () => {
  const result = validate();
  assert.equal(result.buildNumber, '2026081018');
  assert.equal(result.documents, 3);
  assert.equal(result.passedCells, 0);
  assert.equal(result.passedReleaseChecks, 3);
});

test('rejects a stale build number in a snapshot', () => {
  const changed = structuredClone(documents);
  const path = documentPaths[0];
  changed[path] = changed[path].replace('1.0.0 (2026081018)', '1.0.0 (2026080903)');
  assert.throws(() => validate({ documents: changed }), /snapshot is stale or incomplete/);
});

test('rejects a stale or missing app-link diagnostic in a snapshot', () => {
  const changed = structuredClone(documents);
  const path = documentPaths[1];
  changed[path] = changed[path].replace(
    '| Direkte Android-App-Link-Diagnose | `passed`',
    '| Direkte Android-App-Link-Diagnose | `open`',
  );
  assert.throws(() => validate({ documents: changed }), /snapshot is stale or incomplete/);
});

test('rejects duplicate snapshot markers', () => {
  const changed = structuredClone(documents);
  const path = documentPaths[2];
  changed[path] += '\n<!-- SIT_CURRENT_RELEASE_SNAPSHOT_BEGIN -->\n';
  assert.throws(() => validate({ documents: changed }), /exactly one current-release snapshot block/);
});

test('rejects candidate evidence whose artifact hash differs', () => {
  const changed = structuredClone(candidateEvidence);
  changed.android.apkSha256 = 'a'.repeat(64);
  assert.throws(
    () => validate({ candidateEvidence: changed }),
    /candidate evidence.android.apkSha256 does not match/,
  );
});

test('rejects a device matrix row that points to an older build', () => {
  const changed = structuredClone(documents);
  const path = documentPaths[1];
  changed[path] = changed[path].replace(
    '| Android real | offen | offen | `2026081018` | WLAN',
    '| Android real | offen | offen | `2026080903` | WLAN',
  );
  assert.throws(() => validate({ documents: changed }), /four runbook device-matrix rows/);
});

test('rejects pubspec drift from the documented candidate', () => {
  assert.throws(
    () => validate({ pubspecText: pubspecText.replace('1.0.0+2026081018', '1.0.0+2026081019') }),
    /candidate.buildNumber does not match/,
  );
});
