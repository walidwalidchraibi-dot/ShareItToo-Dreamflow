import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const workflow = readFileSync(
  new URL('../../.github/workflows/regression.yml', import.meta.url),
  'utf8',
);

test('CI validates the documented incomplete Android candidate as a safe rollover', () => {
  assert.match(
    workflow,
    /name: Run regression script[\s\S]*?SIT_ALLOW_CANDIDATE_ROLLOVER: '1'[\s\S]*?bash scripts\/technical_regression_check\.sh/,
  );
});
