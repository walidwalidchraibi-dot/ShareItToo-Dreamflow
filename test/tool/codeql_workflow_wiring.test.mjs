import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const workflow = readFileSync(
  new URL('../../.github/workflows/codeql.yml', import.meta.url),
  'utf8',
);

test('CodeQL covers main, pull request, schedule and manual entry points', () => {
  assert.match(workflow, /^name: codeql$/mu);
  assert.match(workflow, /^  push:$/mu);
  assert.match(workflow, /^      - main$/mu);
  assert.doesNotMatch(workflow, /^      - codex\//mu);
  assert.match(workflow, /^  pull_request:$/mu);
  assert.match(workflow, /^  schedule:$/mu);
  assert.match(workflow, /^  workflow_dispatch:$/mu);
});

test('CodeQL uses the current supported action and extended JavaScript queries', () => {
  assert.match(workflow, /uses: github\/codeql-action\/init@v4/u);
  assert.match(workflow, /languages: javascript-typescript/u);
  assert.match(workflow, /queries: security-extended/u);
  assert.match(workflow, /uses: github\/codeql-action\/analyze@v4/u);
  assert.doesNotMatch(workflow, /github\/codeql-action\/(?:init|analyze)@v[123]\b/u);
});

test('CodeQL is bounded and cannot silently ignore findings or workflow failures', () => {
  assert.match(workflow, /^permissions:\n  contents: read$/mu);
  assert.match(workflow, /^      security-events: write$/mu);
  assert.match(workflow, /^    timeout-minutes: 20$/mu);
  assert.match(workflow, /^  cancel-in-progress: true$/mu);
  assert.doesNotMatch(workflow, /continue-on-error/u);
  assert.doesNotMatch(workflow, /secrets\./u);
  assert.doesNotMatch(workflow, /(?:deploy|publish|upload-artifact|workflow_run)/u);
});
