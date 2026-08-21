import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createSupportMessage,
  publishSupportMessage,
  reviewSupportMessage,
} from '../src/support_message_workflow.js';

const now = new Date('2026-08-21T10:00:00.000Z');
const caseId = '11111111-1111-4111-8111-111111111111';
const messageId = '22222222-2222-4222-8222-222222222222';
const noRows = { rowCount: 0, rows: [] };

function caseRow(overrides = {}) {
  return {
    id: caseId,
    human_readable_case_number: 'SIT-ABCDEFGHJKLM',
    reporter_user_id: 'user-1',
    affected_user_ids: ['user-2'],
    current_owner_id: 'support-1',
    operating_mode: 'simulation',
    status: 'received',
    next_update_at: new Date('2026-08-22T10:00:00.000Z'),
    evidence_due_at: null,
    response_due_at: null,
    appeal_deadline: null,
    safety_flag: false,
    ...overrides,
  };
}

function messageRow(overrides = {}) {
  return {
    id: messageId,
    case_id: caseId,
    sender_type: 'support',
    sender_id: 'support-1',
    recipient_user_id: 'user-1',
    message_type: 'support_template',
    message_title: 'Aktiver Übergabe- oder Rückgabefall',
    template_id: 'T-002',
    template_version: '1.0.0',
    locale: 'de-DE',
    rendered_content: 'Sicherer gerenderter Inhalt',
    rendered_content_sha256: 'a'.repeat(64),
    structured_variables: {},
    approval_level: 'yellow_human_review',
    approved_by: null,
    approved_at: null,
    approval_payload_sha256: null,
    reviewed_by: null,
    reviewed_at: null,
    review_outcome: null,
    send_status: 'pending_approval',
    sent_at: null,
    delivery_status: null,
    corrects_message_id: null,
    lock_version: 1,
    created_at: now,
    recipient_account_status: 'active',
    recipient_deactivated_at: null,
    ...overrides,
  };
}

class ScriptedClient {
  constructor(steps) {
    this.steps = [...steps];
  }

  async query(sql, params = []) {
    const step = this.steps.shift();
    assert.ok(step, `unexpected query: ${sql}`);
    if (step.match) assert.match(sql, step.match);
    if (step.check) step.check({ sql, params });
    return typeof step.result === 'function' ? step.result({ sql, params }) : step.result;
  }

  done() {
    assert.equal(this.steps.length, 0, 'not all scripted queries were used');
  }
}

function intakeVariables() {
  return {
    first_name: 'Walid',
    confirmed_fact: 'Der Supportfall ist serverseitig eingegangen.',
    user_action_or_no_action: 'Du musst im Moment nichts weiter tun.',
    next_update_date: '22.08.2026',
    next_update_time: '12:00',
  };
}

test('green template publication records an in-app message without external delivery', async () => {
  const client = new ScriptedClient([
    { match: /message\.idempotency_key = \$1/u, result: noRows },
    { match: /FROM support_cases WHERE id::text = \$1 FOR UPDATE/u, result: { rowCount: 1, rows: [caseRow()] } },
    { match: /FROM users[\s\S]*FOR KEY SHARE/u, result: { rowCount: 1, rows: [{ id: 'user-1' }] } },
    { match: /SELECT \* FROM support_messages WHERE idempotency_key/u, result: noRows },
    {
      match: /INSERT INTO support_messages/u,
      check: ({ params }) => {
        assert.equal(params[3], 'user-1');
        assert.equal(params[5], 'T-001');
        assert.equal(params[11], 'green_automatic');
        assert.equal(params[12], 'sent');
        assert.equal(params[13], now);
        assert.equal(params[14], 'in_app_recorded');
        assert.match(params[8], /SIT-ABCDEFGHJKLM/u);
        assert.doesNotMatch(params[8], /\{\{|\}\}/u);
      },
      result: ({ params }) => ({
        rowCount: 1,
        rows: [messageRow({
          id: params[0],
          sender_id: params[2],
          recipient_user_id: params[3],
          message_title: params[4],
          template_id: params[5],
          rendered_content: params[8],
          rendered_content_sha256: params[9],
          approval_level: params[11],
          send_status: params[12],
          sent_at: params[13],
          delivery_status: params[14],
        })],
      }),
    },
    {
      match: /INSERT INTO support_case_events/u,
      check: ({ params }) => {
        assert.equal(params[1], 'message.published');
        const payload = JSON.parse(params[5]);
        assert.equal(payload.inAppMessageRecorded, true);
        assert.equal(payload.externalMessageSent, false);
        assert.equal(params[6], true);
        assert.equal(params[7], 'user_visible');
      },
      result: noRows,
    },
    {
      match: /INSERT INTO audit_log/u,
      check: ({ params }) => {
        assert.equal(params[2], 'support.message_published');
        const metadata = JSON.parse(params[4]);
        assert.equal(metadata.externalMessageSent, false);
        assert.doesNotMatch(JSON.stringify(metadata), /serverseitig eingegangen/u);
      },
      result: noRows,
    },
  ]);
  const result = await createSupportMessage(client, {
    actor: { id: 'support-1', role: 'support' },
    caseId,
    raw: {
      templateId: 'T-001',
      recipientUserId: 'user-1',
      variables: intakeVariables(),
      publishNow: true,
    },
    idempotencyKey: 'message-create-1',
    now,
  });
  assert.equal(result.replayed, false);
  assert.equal(result.message.sendStatus, 'sent');
  assert.equal(result.message.externalMessageSent, false);
  client.done();
});

test('message creation rejects a recipient whose account is closed', async () => {
  const client = new ScriptedClient([
    { match: /message\.idempotency_key = \$1/u, result: noRows },
    { match: /FROM support_cases WHERE id::text = \$1 FOR UPDATE/u, result: { rowCount: 1, rows: [caseRow()] } },
    { match: /FROM users[\s\S]*FOR KEY SHARE/u, result: noRows },
  ]);
  await assert.rejects(
    createSupportMessage(client, {
      actor: { id: 'support-1', role: 'support' },
      caseId,
      raw: {
        templateId: 'T-001',
        recipientUserId: 'user-1',
        variables: intakeVariables(),
        publishNow: true,
      },
      idempotencyKey: 'closed-recipient',
      now,
    }),
    /support_message_recipient_account_closed/u,
  );
  client.done();
});

test('message recipient must belong to the locked support case', async () => {
  const client = new ScriptedClient([
    { match: /message\.idempotency_key = \$1/u, result: noRows },
    { match: /FOR UPDATE/u, result: { rowCount: 1, rows: [caseRow()] } },
  ]);
  await assert.rejects(
    createSupportMessage(client, {
      actor: { id: 'support-1', role: 'support' },
      caseId,
      raw: { templateId: 'T-001', recipientUserId: 'stranger', variables: intakeVariables() },
      idempotencyKey: 'wrong-recipient',
      now,
    }),
    /support_message_recipient_forbidden/u,
  );
  client.done();
});

test('independent admin review binds approval to the exact immutable hash', async () => {
  const row = messageRow();
  const client = new ScriptedClient([
    { match: /FROM support_case_events AS event/u, result: noRows },
    { match: /FOR UPDATE OF message/u, result: { rowCount: 1, rows: [{ ...row, case_operating_mode: 'simulation' }] } },
    { match: /SELECT 1 FROM support_case_events/u, result: noRows },
    {
      match: /UPDATE support_messages/u,
      check: ({ params }) => {
        assert.equal(params[1], 'admin-1');
        assert.equal(params[3], 'approved');
        assert.equal(params[5], 'admin-1');
        assert.equal(params[7], row.rendered_content_sha256);
        assert.equal(params[8], 'approved');
        assert.equal(params[9], 1);
      },
      result: ({ params }) => ({
        rowCount: 1,
        rows: [{
          ...row,
          reviewed_by: params[1],
          reviewed_at: params[2],
          review_outcome: params[3],
          approved_by: params[5],
          approved_at: params[6],
          approval_payload_sha256: params[7],
          send_status: params[8],
          lock_version: 2,
        }],
      }),
    },
    { match: /INSERT INTO support_case_events/u, result: noRows },
    { match: /INSERT INTO audit_log/u, result: noRows },
  ]);
  const result = await reviewSupportMessage(client, {
    actor: { id: 'admin-1', role: 'admin' },
    caseId,
    messageId,
    raw: {
      outcome: 'approved',
      expectedVersion: 1,
      expectedPayloadSha256: row.rendered_content_sha256,
      reviewNotes: 'Wortlaut und bestätigte Falldaten wurden geprüft.',
    },
    idempotencyKey: 'message-review-1',
    now,
  });
  assert.equal(result.message.sendStatus, 'approved');
  assert.equal(result.message.approvalPayloadSha256, row.rendered_content_sha256);
  client.done();
});

test('message author cannot review their own yellow draft', async () => {
  const client = new ScriptedClient([
    { match: /FROM support_case_events AS event/u, result: noRows },
    { match: /FOR UPDATE OF message/u, result: { rowCount: 1, rows: [{ ...messageRow({ sender_id: 'admin-1' }), case_operating_mode: 'simulation' }] } },
    { match: /SELECT 1 FROM support_case_events/u, result: noRows },
  ]);
  await assert.rejects(
    reviewSupportMessage(client, {
      actor: { id: 'admin-1', role: 'admin' },
      caseId,
      messageId,
      raw: {
        outcome: 'approved',
        expectedVersion: 1,
        expectedPayloadSha256: 'a'.repeat(64),
        reviewNotes: 'Wortlaut und Falldaten wurden geprüft.',
      },
      idempotencyKey: 'self-review',
      now,
    }),
    /support_message_self_review_forbidden/u,
  );
  client.done();
});

test('reviewed yellow message publishes only into the authenticated in-app record', async () => {
  const approved = messageRow({
    approved_by: 'admin-1',
    approved_at: now,
    approval_payload_sha256: 'a'.repeat(64),
    reviewed_by: 'admin-1',
    reviewed_at: now,
    review_outcome: 'approved',
    send_status: 'approved',
    lock_version: 2,
  });
  const client = new ScriptedClient([
    { match: /FROM support_case_events AS event/u, result: noRows },
    { match: /FOR UPDATE OF message/u, result: { rowCount: 1, rows: [{ ...approved, case_current_owner_id: 'support-1', case_operating_mode: 'simulation' }] } },
    { match: /SELECT 1 FROM support_case_events/u, result: noRows },
    {
      match: /UPDATE support_messages/u,
      check: ({ params }) => assert.deepEqual(params, [messageId, now, 2, 'approved']),
      result: { rowCount: 1, rows: [{ ...approved, send_status: 'sent', sent_at: now, delivery_status: 'in_app_recorded', lock_version: 3 }] },
    },
    {
      match: /INSERT INTO support_case_events/u,
      check: ({ params }) => {
        const payload = JSON.parse(params[5]);
        assert.equal(payload.externalMessageSent, false);
        assert.equal(params[7], 'user_visible');
      },
      result: noRows,
    },
    { match: /INSERT INTO audit_log/u, result: noRows },
  ]);
  const result = await publishSupportMessage(client, {
    actor: { id: 'support-1', role: 'support' },
    caseId,
    messageId,
    raw: { expectedVersion: 2, expectedPayloadSha256: 'a'.repeat(64) },
    idempotencyKey: 'message-publish-1',
    now,
  });
  assert.equal(result.message.sendStatus, 'sent');
  assert.equal(result.message.externalMessageSent, false);
  client.done();
});

test('publication rechecks a promised next-update deadline after approval', async () => {
  const approved = messageRow({
    approved_by: 'admin-1',
    approved_at: now,
    approval_payload_sha256: 'a'.repeat(64),
    reviewed_by: 'admin-1',
    reviewed_at: now,
    review_outcome: 'approved',
    send_status: 'approved',
    lock_version: 2,
    structured_variables: { next_update_date: '21.08.2026' },
  });
  const client = new ScriptedClient([
    { match: /FROM support_case_events AS event/u, result: noRows },
    {
      match: /case_next_update_at/u,
      result: {
        rowCount: 1,
        rows: [{
          ...approved,
          case_current_owner_id: 'support-1',
          case_operating_mode: 'simulation',
          case_next_update_at: now,
        }],
      },
    },
    { match: /SELECT 1 FROM support_case_events/u, result: noRows },
  ]);
  await assert.rejects(
    publishSupportMessage(client, {
      actor: { id: 'support-1', role: 'support' },
      caseId,
      messageId,
      raw: { expectedVersion: 2, expectedPayloadSha256: 'a'.repeat(64) },
      idempotencyKey: 'message-publish-overdue',
      now,
    }),
    /support_message_next_update_overdue/u,
  );
  client.done();
});

test('publication rejects a message whose recipient account was closed after drafting', async () => {
  const approved = messageRow({
    approved_by: 'admin-1',
    approved_at: now,
    approval_payload_sha256: 'a'.repeat(64),
    reviewed_by: 'admin-1',
    reviewed_at: now,
    review_outcome: 'approved',
    send_status: 'approved',
    lock_version: 2,
    recipient_account_status: 'closed',
    recipient_deactivated_at: now,
  });
  const client = new ScriptedClient([
    { match: /FROM support_case_events AS event/u, result: noRows },
    {
      match: /JOIN users AS recipient[\s\S]*FOR UPDATE OF message, recipient/u,
      result: {
        rowCount: 1,
        rows: [{
          ...approved,
          case_current_owner_id: 'support-1',
          case_operating_mode: 'simulation',
          case_next_update_at: new Date('2026-08-22T10:00:00.000Z'),
        }],
      },
    },
  ]);
  await assert.rejects(
    publishSupportMessage(client, {
      actor: { id: 'support-1', role: 'support' },
      caseId,
      messageId,
      raw: { expectedVersion: 2, expectedPayloadSha256: 'a'.repeat(64) },
      idempotencyKey: 'closed-recipient-publication',
      now,
    }),
    /support_message_recipient_account_closed/u,
  );
  client.done();
});
