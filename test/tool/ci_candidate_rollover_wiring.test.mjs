import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const workflow = readFileSync(
  new URL('../../.github/workflows/regression.yml', import.meta.url),
  'utf8',
);
const androidBuild = readFileSync(
  new URL('../../scripts/build_android_release_candidate.sh', import.meta.url),
  'utf8',
);

test('CI validates the documented incomplete Android candidate as a safe rollover', () => {
  assert.match(
    workflow,
    /name: Run regression script[\s\S]*?SIT_ALLOW_CANDIDATE_ROLLOVER: '1'[\s\S]*?bash scripts\/technical_regression_check\.sh/,
  );
  assert.match(
    workflow,
    /name: Build a signed, commit-bound Android release candidate[\s\S]*?SIT_ALLOW_CANDIDATE_ROLLOVER: '1'[\s\S]*?bash scripts\/build_android_release_candidate\.sh/,
  );
});

test('Android packaging scopes Firebase validation to Android', () => {
  assert.match(
    androidBuild,
    /SIT_FIREBASE_VALIDATION_PLATFORM=android bash scripts\/release_candidate_preflight\.sh/,
  );
});
