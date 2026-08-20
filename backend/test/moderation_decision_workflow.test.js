import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  ModerationDomainError,
  moderationReviewDeadline,
  normalizeModerationDecisionInput,
} from '../src/moderation_domain.js';
import {
  setPrivateMarketplaceReviewStatus,
  submitModerationReviewRequest,
} from '../src/moderation_decision_workflow.js';

test('moderation review deadline is six calendar months with end-of-month clamping', () => {
  assert.equal(
    moderationReviewDeadline('2026-08-31T12:30:00Z').toISOString(),
    '2027-02-28T12:30:00.000Z',
  );
  assert.equal(
    moderationReviewDeadline('2026-10-30T08:00:00Z').toISOString(),
    '2027-04-30T08:00:00.000Z',
  );
});

test('reasoned decisions disclose human or automated detection truthfully', () => {
  assert.deepEqual(normalizeModerationDecisionInput({
    facts: 'Der dokumentierte Testfall wurde geprüft.',
    basis: 'Community-Regel 4.2',
    reasoning: 'Die protokollierten Tatsachen erfüllen die Regel.',
    detectionMethod: 'human',
  }), {
    facts: 'Der dokumentierte Testfall wurde geprüft.',
    basis: 'Community-Regel 4.2',
    reasoning: 'Die protokollierten Tatsachen erfüllen die Regel.',
    detectionMethod: 'human',
    automatedMeans: null,
  });
  assert.throws(
    () => normalizeModerationDecisionInput({
      facts: 'Dokumentierter Testfall',
      basis: 'Community-Regel 4.2',
      reasoning: 'Regel wurde erfüllt.',
      detectionMethod: 'automated',
    }),
    (error) => error instanceof ModerationDomainError
      && error.code === 'moderation_automated_means_required',
  );
});

function scriptedClient(steps) {
  return {
    async query(statement, values = []) {
      const step = steps.shift();
      assert.ok(step, `Unexpected query: ${statement}`);
      assert.match(statement, step.pattern);
      if (step.assertValues) step.assertValues(values);
      return step.result;
    },
  };
}

test('only the recipient may request one reasoned review inside the six-month window', async () => {
  const decision = {
    id: 'decision-1',
    recipient_user_id: 'user-1',
    review_available: true,
    review_deadline_at: '2099-02-28T12:30:00Z',
  };
  const submittedAt = new Date('2026-08-20T12:00:00Z');
  const client = scriptedClient([
    { pattern: /WHERE idempotency_key = \$1/u, result: { rowCount: 0, rows: [] } },
    { pattern: /FROM moderation_decisions WHERE id::text = \$1 FOR UPDATE/u, result: { rowCount: 1, rows: [decision] } },
    { pattern: /FROM moderation_review_requests WHERE decision_id = \$1/u, result: { rowCount: 0, rows: [] } },
    {
      pattern: /INSERT INTO moderation_review_requests/u,
      result: {
        rowCount: 1,
        rows: [{
          id: 'review-1', decision_id: decision.id, status: 'submitted',
          reason: 'Bitte berücksichtigen Sie den beigefügten Kontext.',
          submitted_at: submittedAt, resolved_at: null, resolution: null,
        }],
      },
    },
    { pattern: /INSERT INTO moderation_review_events/u, result: { rowCount: 1, rows: [] } },
    { pattern: /INSERT INTO audit_log/u, result: { rowCount: 1, rows: [] } },
  ]);
  const result = await submitModerationReviewRequest(client, {
    actor: { id: 'user-1', role: 'user' },
    decisionId: decision.id,
    raw: { reason: 'Bitte berücksichtigen Sie den beigefügten Kontext.' },
    idempotencyKey: 'review-1',
  });
  assert.equal(result.reviewRequest.decisionId, decision.id);
  assert.equal(result.reviewRequest.status, 'submitted');

  const forbiddenClient = scriptedClient([
    { pattern: /WHERE idempotency_key = \$1/u, result: { rowCount: 0, rows: [] } },
    { pattern: /FROM moderation_decisions WHERE id::text = \$1 FOR UPDATE/u, result: { rowCount: 1, rows: [decision] } },
  ]);
  await assert.rejects(
    submitModerationReviewRequest(forbiddenClient, {
      actor: { id: 'user-2', role: 'user' },
      decisionId: decision.id,
      raw: { reason: 'Unzulässiger fremder Prüfungsantrag.' },
      idempotencyKey: 'review-2',
    }),
    (error) => error.code === 'moderation_decision_forbidden',
  );
});

test('moderation persistence is user-bound, append-only and never auto-mutates a measure', () => {
  const migration = readFileSync(
    new URL('../sql/migrations/026_v52_categories_moderation_operator.up.sql', import.meta.url),
    'utf8',
  );
  const workflow = readFileSync(
    new URL('../src/moderation_decision_workflow.js', import.meta.url),
    'utf8',
  );
  for (const table of [
    'private_marketplace_review_events',
    'moderation_decisions',
    'moderation_review_events',
  ]) {
    assert.match(
      migration,
      new RegExp(`CREATE TRIGGER ${table}_append_only[\\s\\S]*?ON ${table}`, 'u'),
    );
  }
  assert.match(migration, /recipient_user_id TEXT NOT NULL/u);
  assert.match(migration, /review_deadline_at TIMESTAMPTZ/u);
  assert.match(workflow, /measureChanged: false/u);
  assert.match(workflow, /WHERE decision\.recipient_user_id = \$1/u);
});

test('private marketplace review replay returns the status recorded by the idempotent event', async () => {
  const client = scriptedClient([
    {
      pattern: /SELECT user_id, to_status[\s\S]*private_marketplace_review_events/u,
      result: { rowCount: 1, rows: [{ user_id: 'user-1', to_status: 'blocked' }] },
    },
    {
      pattern: /FROM users WHERE id = \$1[\s\S]*FOR UPDATE/u,
      result: {
        rowCount: 1,
        rows: [{ id: 'user-1', role: 'user', private_marketplace_review_status: 'clear' }],
      },
    },
  ]);
  const result = await setPrivateMarketplaceReviewStatus(client, {
    actor: { id: 'admin-1', role: 'admin' },
    userId: 'user-1',
    raw: {
      status: 'blocked',
      reasonCode: 'risk.review',
      decision: {},
    },
    idempotencyKey: 'review-event-1',
  });
  assert.deepEqual(result, {
    userId: 'user-1',
    status: 'blocked',
    replayed: true,
  });
});
