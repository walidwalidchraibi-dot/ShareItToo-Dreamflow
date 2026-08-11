import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repositoryRoot = fileURLToPath(new URL('../../', import.meta.url));

function read(path) {
  return readFileSync(resolve(repositoryRoot, path), 'utf8');
}

test('release preflight always validates the legal draft and requires approval for Store mode', () => {
  const source = read('scripts/release_candidate_preflight.sh');
  assert.match(source, /node --check tool\/validate_legal_readiness\.mjs/);
  assert.match(source, /node tool\/validate_legal_readiness\.mjs\n/);
  assert.match(
    source,
    /if \[\[ "\$\{SIT_REQUIRE_STORE_SUBMISSION:-0\}" == "1" \]\]; then[\s\S]*node tool\/validate_legal_readiness\.mjs --require-approved/,
  );
  assert.ok(
    source.indexOf('node tool/validate_legal_readiness.mjs --require-approved')
      < source.indexOf('dart run tool/validate_store_metadata.dart --require-submittable'),
  );
});

test('technical regression runs syntax, tests, and the honest legal draft validator', () => {
  const source = read('scripts/technical_regression_check.sh');
  for (const command of [
    'node --check tool/validate_legal_readiness.mjs',
    'node --test test/tool/validate_legal_readiness.test.mjs',
    'node tool/validate_legal_readiness.mjs',
  ]) {
    assert.ok(source.includes(command));
  }
});

test('both changed shell entrypoints remain valid Bash', () => {
  for (const path of [
    'scripts/release_candidate_preflight.sh',
    'scripts/technical_regression_check.sh',
  ]) {
    const result = spawnSync('bash', ['-n', resolve(repositoryRoot, path)], {
      encoding: 'utf8',
    });
    assert.equal(result.status, 0, result.stderr);
  }
});
