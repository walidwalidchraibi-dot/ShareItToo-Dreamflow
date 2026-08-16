import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const script = readFileSync(new URL('../../scripts/technical_regression_check.sh', import.meta.url), 'utf8');

test('locks the measured Flutter analyzer backlog and still rejects growth', () => {
  assert.match(script, /^ANALYZER_BASELINE=229$/m);
  assert.match(script, /if \(\( issue_count > ANALYZER_BASELINE \)\)/);
  assert.match(script, /Analyzer regression detected/);
});

test('rejects reintroduction of cleared correctness analyzer codes', () => {
  for (const code of [
    'dead_code',
    'empty_catches',
    'equal_keys_in_map',
    'unreachable_switch_default',
    'unused_import',
    'unused_local_variable',
  ]) {
    assert.match(script, new RegExp(`^  ${code}$`, 'm'));
  }
  assert.match(script, /Analyzer correctness regression detected/);
});
