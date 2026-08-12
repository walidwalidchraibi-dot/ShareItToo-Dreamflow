import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const script = readFileSync(new URL('../../scripts/technical_regression_check.sh', import.meta.url), 'utf8');

test('locks the measured Flutter analyzer backlog and still rejects growth', () => {
  assert.match(script, /^ANALYZER_BASELINE=616$/m);
  assert.match(script, /if \(\( issue_count > ANALYZER_BASELINE \)\)/);
  assert.match(script, /Analyzer regression detected/);
});
