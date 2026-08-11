import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const repositoryRoot = resolve(import.meta.dirname, '../..');
const validator = resolve(repositoryRoot, 'tool/validate_store_metadata.dart');
const baseManifest = JSON.parse(readFileSync(resolve(repositoryRoot, 'store/submission.json'), 'utf8'));

function runWithManifest(mutate) {
  const directory = mkdtempSync(join(tmpdir(), 'sit-store-metadata-'));
  try {
    const manifest = structuredClone(baseManifest);
    mutate(manifest);
    const manifestPath = join(directory, 'submission.json');
    writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
    return spawnSync('dart', ['run', validator, '--manifest', manifestPath], {
      cwd: repositoryRoot,
      encoding: 'utf8',
    });
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

test('rejects a missing mandatory Store release gate', () => {
  const result = runWithManifest((manifest) => {
    delete manifest.blockingGates.googlePlayAccountAndFee;
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /must contain exactly the required Store release gates/);
});

test('rejects an unrecognized Store release gate', () => {
  const result = runWithManifest((manifest) => {
    manifest.blockingGates.unreviewedShortcut = 'closed';
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /must contain exactly the required Store release gates/);
});
