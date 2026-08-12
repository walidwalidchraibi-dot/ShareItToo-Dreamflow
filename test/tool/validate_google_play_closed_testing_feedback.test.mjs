import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { validateGooglePlayClosedTestingFeedback } from '../../tool/validate_google_play_closed_testing_feedback.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const plan = JSON.parse(readFileSync(resolve(root, 'store/google-play/closed-testing-feedback-plan.json'), 'utf8'));
const readiness = JSON.parse(readFileSync(resolve(root, 'store/google-play/closed-testing-readiness.json'), 'utf8'));

test('accepts the empty plan before the real closed test', () => {
  const result = validateGooglePlayClosedTestingFeedback({
    plan: structuredClone(plan),
    closedTestingReadiness: structuredClone(readiness),
  });
  assert.equal(result.state, 'planned');
  assert.equal(result.scenarioCount, 9);
});

test('rejects invented feedback before the test starts', () => {
  const fixture = structuredClone(plan);
  fixture.aggregate.feedbackItemCount = 1;
  assert.throws(
    () => validateGooglePlayClosedTestingFeedback({ plan: fixture, closedTestingReadiness: readiness }),
    /must remain empty until the real closed test starts/,
  );
});

test('rejects personal tester data anywhere in the plan', () => {
  const fixture = structuredClone(plan);
  fixture.aggregate.feedbackThemes.push('tester@example.test');
  assert.throws(
    () => validateGooglePlayClosedTestingFeedback({ plan: fixture, closedTestingReadiness: readiness }),
    /must not contain tester or account email addresses/,
  );
});

test('rejects a device identifier field even without a value', () => {
  const fixture = structuredClone(plan);
  fixture.aggregate.deviceId = null;
  assert.throws(
    () => validateGooglePlayClosedTestingFeedback({ plan: fixture, closedTestingReadiness: readiness }),
    /forbidden private field/,
  );
});

test('rejects collecting feedback without an active closed test', () => {
  const fixture = structuredClone(plan);
  fixture.state = 'collecting';
  fixture.aggregate.observedTesterCount = 12;
  assert.throws(
    () => validateGooglePlayClosedTestingFeedback({ plan: fixture, closedTestingReadiness: readiness }),
    /requires an active or completed closed test/,
  );
});

test('accepts a sanitized aggregate while the closed test is running', () => {
  const fixture = structuredClone(plan);
  fixture.state = 'collecting';
  fixture.aggregate.observedTesterCount = 12;
  fixture.aggregate.completedScenarioRuns = 16;
  fixture.aggregate.feedbackItemCount = 3;
  fixture.aggregate.issueCounts.p2 = 1;
  const active = structuredClone(readiness);
  active.status = 'running';
  const result = validateGooglePlayClosedTestingFeedback({ plan: fixture, closedTestingReadiness: active });
  assert.equal(result.feedbackItemCount, 3);
});
