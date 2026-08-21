import assert from 'node:assert/strict';
import test from 'node:test';

import {
  listSupportMessageTemplates,
  normalizeSupportMessageDraft,
  normalizeSupportMessagePublication,
  normalizeSupportMessageReview,
  supportMessageTemplateSource,
} from '../src/support_message_domain.js';

const caseNumber = 'SIT-ABCDEFGHJKLM';
const supportCase = Object.freeze({
  human_readable_case_number: caseNumber,
  status: 'received',
  next_update_at: new Date('2026-08-22T10:00:00.000Z'),
  evidence_due_at: null,
  response_due_at: null,
  appeal_deadline: null,
  safety_flag: false,
});

function intakeVariables(overrides = {}) {
  return {
    first_name: 'Walid',
    confirmed_fact: 'Der Supportfall ist serverseitig eingegangen.',
    user_action_or_no_action: 'Du musst im Moment nichts weiter tun.',
    next_update_date: '22.08.2026',
    next_update_time: '12:00',
    ...overrides,
  };
}

test('Drive template catalog is hash-bound, complete and exposes safe metadata only', () => {
  const templates = listSupportMessageTemplates();
  assert.equal(supportMessageTemplateSource.templateCount, 55);
  assert.equal(supportMessageTemplateSource.sourceSha256,
    '947f307e7919eed543c28e36af4d2b364d87dcde52025649d0d4620d64baaaa5');
  assert.equal(templates.length, 55);
  assert.equal(templates.find((entry) => entry.id === 'T-001').genericDraftAvailable, true);
  assert.equal(templates.find((entry) => entry.id === 'T-021').moneySnapshotRequired, true);
  assert.equal(templates.find((entry) => entry.id === 'T-043').genericDraftAvailable, false);
  assert.equal('body' in templates[0], false);
});

test('green template renders exact server case ID and can be recorded in app', () => {
  const result = normalizeSupportMessageDraft({
    templateId: 'T-001',
    recipientUserId: 'user-1',
    variables: intakeVariables(),
    publishNow: true,
  }, { supportCase });
  assert.equal(result.approvalLevel, 'green_automatic');
  assert.equal(result.sendStatus, 'sent');
  assert.equal(result.structuredVariables.case_id, caseNumber);
  assert.match(result.renderedContent, /SIT-ABCDEFGHJKLM/u);
  assert.match(result.renderedContent, /22\.08\.2026/u);
  assert.match(result.renderedContent, /12:00 Uhr/u);
  assert.doesNotMatch(result.renderedContent, /\{\{|\}\}/u);
  assert.match(result.renderedContentSha256, /^[0-9a-f]{64}$/u);
});

test('missing, unexpected and mismatched placeholders fail closed', () => {
  assert.throws(
    () => normalizeSupportMessageDraft({
      templateId: 'T-001',
      variables: intakeVariables({ confirmed_fact: undefined }),
    }, { supportCase }),
    /support_message_variable_invalid/u,
  );
  assert.throws(
    () => normalizeSupportMessageDraft({
      templateId: 'T-001',
      variables: { ...intakeVariables(), internal_note: 'Nicht sichtbar' },
    }, { supportCase }),
    /support_message_variable_unexpected/u,
  );
  assert.throws(
    () => normalizeSupportMessageDraft({
      templateId: 'T-001',
      variables: { ...intakeVariables(), case_id: 'SIT-ZZZZZZZZZZZZ' },
    }, { supportCase }),
    /support_message_server_binding_mismatch/u,
  );
  assert.throws(
    () => normalizeSupportMessageDraft({
      templateId: 'T-001',
      variables: { ...intakeVariables(), next_update_time: '10:00' },
    }, { supportCase }),
    /support_message_server_binding_mismatch/u,
  );
});

test('sensitive data and unsafe decision claims are blocked in variables', () => {
  for (const confirmed_fact of [
    'API-Key: sk_live_1234567890',
    'Kontakt: gegenpartei@example.test',
    'IBAN DE89370400440532013000',
    'Die andere Partei ist eindeutig schuldig.',
    'Die Erstattung ist garantiert.',
  ]) {
    assert.throws(
      () => normalizeSupportMessageDraft({
        templateId: 'T-001',
        variables: intakeVariables({ confirmed_fact }),
      }, { supportCase }),
      /support_message_(?:sensitive_content|policy_claim)_blocked/u,
    );
  }
});

test('yellow requires review while red and money templates stay on dedicated paths', () => {
  assert.throws(
    () => normalizeSupportMessageDraft({
      templateId: 'T-002',
      variables: {
        first_name: 'Walid',
        active_stage: 'Übergabe',
        safe_next_step: 'Beende die Übergabe vorerst.',
        confirmed_fact: 'Der Fall ist eingegangen.',
        open_check: 'Der bestätigte Übergabestatus.',
        next_update_date: '22.08.2026',
        next_update_time: '12:00',
      },
      publishNow: true,
    }, { supportCase }),
    /support_message_human_review_required/u,
  );
  assert.throws(
    () => normalizeSupportMessageDraft({ templateId: 'T-043', variables: {} }, { supportCase }),
    /support_message_red_template_requires_decision_workflow/u,
  );
  assert.throws(
    () => normalizeSupportMessageDraft({ templateId: 'T-021', variables: {} }, { supportCase }),
    /support_message_money_template_requires_snapshot_workflow/u,
  );
});

test('review and publication require exact hash and positive version', () => {
  const review = normalizeSupportMessageReview({
    outcome: 'approved',
    expectedVersion: 1,
    expectedPayloadSha256: 'a'.repeat(64),
    reviewNotes: 'Wortlaut und bestätigte Falldaten wurden geprüft.',
  });
  assert.equal(review.expectedVersion, 1);
  assert.equal(review.expectedPayloadSha256, 'a'.repeat(64));
  assert.equal(normalizeSupportMessagePublication({
    expectedVersion: 2,
    expectedPayloadSha256: 'b'.repeat(64),
  }).expectedVersion, 2);
  assert.throws(
    () => normalizeSupportMessageReview({
      outcome: 'approved', expectedVersion: 0, expectedPayloadSha256: 'a'.repeat(64),
      reviewNotes: 'Wortlaut wurde geprüft.',
    }),
    /support_message_version_invalid/u,
  );
});
