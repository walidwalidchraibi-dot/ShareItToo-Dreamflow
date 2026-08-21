import assert from 'node:assert/strict';
import test from 'node:test';

import {
  canTransitionSupportCase,
  newHumanReadableCaseNumber,
  normalizeSupportCaseInput,
  normalizeSupportCaseTransition,
  supportApprovalLevels,
  supportCaseFamilies,
  supportCaseStatuses,
  supportPriorities,
  supportRouteFor,
} from '../src/support_case_domain.js';

const now = new Date('2026-08-21T10:00:00.000Z');
const nextUpdateAt = new Date('2026-08-21T12:00:00.000Z');
const decisionId = '11111111-1111-4111-8111-111111111111';

function caseRecord(overrides = {}) {
  return {
    status: 'acknowledged',
    priority: 'p1',
    severity: 'high',
    approval_level: 'yellow_human_review',
    current_owner_role: 'booking_operations_owner',
    current_owner_id: null,
    decision_id: null,
    lock_version: 3,
    ...overrides,
  };
}

function transition(record, raw, actorRole = 'support') {
  return normalizeSupportCaseTransition(record, {
    expectedVersion: record.lock_version,
    reason: 'Sachlich geprüfter nächster Schritt.',
    nextAction: 'Fall innerhalb der Frist weiter prüfen.',
    nextUpdateAt,
    ...raw,
  }, { actorRole, now });
}

test('support taxonomy and controlled vocabularies stay canonical and exclude paused', () => {
  assert.equal(Object.keys(supportCaseFamilies).length, 13);
  assert.deepEqual(supportCaseStatuses, [
    'received',
    'acknowledged',
    'waiting_for_user',
    'waiting_for_other_party',
    'under_review',
    'escalated',
    'decision_pending_approval',
    'decided',
    'implementation_pending',
    'resolved',
    'closed',
    'reopened',
  ]);
  assert.equal(supportCaseStatuses.includes('paused'), false);
  assert.deepEqual(supportPriorities, ['p0', 'p1', 'p2', 'p3']);
  assert.deepEqual(supportApprovalLevels, [
    'green_automatic',
    'yellow_human_review',
    'red_explicit_decision',
  ]);
  for (const [family, subtypes] of Object.entries(supportCaseFamilies)) {
    assert.ok(subtypes.length >= 4, family);
    for (const subtype of subtypes) assert.doesNotThrow(() => supportRouteFor(family, subtype));
  }
});

test('routing is deterministic and fails closed at money, privacy, authority and P0 boundaries', () => {
  assert.deepEqual(
    supportRouteFor('general_help', 'general_how_to'),
    {
      priority: 'p3',
      severity: 'low',
      ownerRole: 'general_support_owner',
      approvalLevel: 'green_automatic',
      waitingOn: 'support_owner',
      safetyFlag: false,
      privacyFlag: false,
      dsaFlag: false,
      authorityFlag: false,
      moneyFlag: false,
      accountTakeoverFlag: false,
    },
  );
  const handover = supportRouteFor('active_handover', 'qr_or_code_failure');
  assert.equal(handover.priority, 'p1');
  assert.equal(handover.approvalLevel, 'yellow_human_review');

  for (const [family, subtype, owner] of [
    ['money_case', 'refund_request_or_review', 'finance_owner'],
    ['privacy_security', 'access_or_copy_request', 'privacy_owner'],
    ['legal_authority', 'formal_legal_notice', 'legal_authority_owner'],
  ]) {
    const route = supportRouteFor(family, subtype);
    assert.equal(route.ownerRole, owner);
    assert.equal(route.approvalLevel, 'red_explicit_decision');
  }
  const danger = supportRouteFor('trust_safety', 'immediate_physical_danger');
  assert.equal(danger.priority, 'p0');
  assert.equal(danger.severity, 'critical');
  assert.equal(danger.approvalLevel, 'red_explicit_decision');
  assert.equal(danger.safetyFlag, true);
});

test('routing rejects unknown or mismatched taxonomy values', () => {
  assert.throws(
    () => supportRouteFor('unknown', 'general_how_to'),
    /support_case_type_invalid/,
  );
  assert.throws(
    () => supportRouteFor('general_help', 'refund_request_or_review'),
    /support_case_subtype_invalid/,
  );
});

test('human-readable case number is opaque, fixed length and ambiguity-safe', () => {
  const number = newHumanReadableCaseNumber(Buffer.from([0, 1, 2, 3, 4, 5, 6, 7, 8]));
  assert.match(number, /^SIT-[A-HJ-NP-Z2-9]{12}$/);
  assert.equal(number.length, 16);
  assert.doesNotMatch(number.slice(4), /[01IO]/);
});

test('intake derives authoritative route and retains non-live operating truth', () => {
  const result = normalizeSupportCaseInput({
    caseType: 'money_case',
    caseSubType: 'refund_request_or_review',
    summary: 'Erstattung im Testmodus nachvollziehbar prüfen.',
    linkedBookingId: 'booking-123',
    linkedPaymentId: decisionId,
  }, {
    sourceChannel: 'app',
    operatingMode: 'internal_testing',
    nextUpdateAt,
    now,
  });
  assert.equal(result.status, 'received');
  assert.equal(result.priority, 'p2');
  assert.equal(result.ownerRole, 'finance_owner');
  assert.equal(result.approvalLevel, 'red_explicit_decision');
  assert.equal(result.moneyFlag, true);
  assert.equal(result.operatingMode, 'internal_testing');
  assert.equal(result.locale, 'de-DE');
  assert.equal(result.linkedBookingId, 'booking-123');
});

test('intake rejects live modes, malformed references and unsafe deadlines', () => {
  const raw = {
    caseType: 'general_help',
    caseSubType: 'general_how_to',
    summary: 'Eine zulässige Zusammenfassung.',
  };
  assert.throws(
    () => normalizeSupportCaseInput(raw, {
      operatingMode: 'production',
      nextUpdateAt,
      now,
    }),
    /support_operating_mode_invalid/,
  );
  assert.throws(
    () => normalizeSupportCaseInput({ ...raw, linkedPaymentId: 'not-a-uuid' }, {
      nextUpdateAt,
      now,
    }),
    /support_linked_payment_invalid/,
  );
  assert.throws(
    () => normalizeSupportCaseInput(raw, { nextUpdateAt: now, now }),
    /support_next_update_at_required/,
  );
  assert.throws(
    () => normalizeSupportCaseInput(raw, {
      nextUpdateAt: new Date('2026-10-01T10:00:00.000Z'),
      now,
    }),
    /support_next_update_at_required/,
  );
});

test('intake derives bounded internal checkpoints when no client deadline is supplied', () => {
  const base = { summary: 'Interner Checkpoint wird vom Server bestimmt.' };
  const p0 = normalizeSupportCaseInput({
    ...base,
    caseType: 'trust_safety',
    caseSubType: 'immediate_physical_danger',
  }, { now });
  const p3 = normalizeSupportCaseInput({
    ...base,
    caseType: 'general_help',
    caseSubType: 'general_how_to',
  }, { now });
  assert.equal(p0.nextUpdateAt.toISOString(), '2026-08-21T10:15:00.000Z');
  assert.equal(p3.nextUpdateAt.toISOString(), '2026-08-22T10:00:00.000Z');
});

test('transition graph is explicit and rejects skips, paused and stale versions', () => {
  assert.equal(canTransitionSupportCase('received', 'acknowledged'), true);
  assert.equal(canTransitionSupportCase('received', 'resolved'), false);
  assert.throws(
    () => transition(caseRecord({ status: 'received' }), { status: 'resolved' }),
    /support_transition_not_allowed/,
  );
  assert.throws(
    () => transition(caseRecord(), { status: 'paused' }),
    /support_status_invalid/,
  );
  assert.throws(
    () => normalizeSupportCaseTransition(caseRecord(), {
      status: 'under_review',
      expectedVersion: 2,
      reason: 'Stale Version muss scheitern.',
      nextAction: 'Weiter prüfen.',
      nextUpdateAt,
    }, { actorRole: 'support', now }),
    /support_case_version_conflict/,
  );
});

test('only staff or system can transition a support case', () => {
  assert.throws(
    () => transition(caseRecord(), { status: 'under_review' }, 'user'),
    /support_transition_forbidden/,
  );
});

test('waiting and escalation transitions require explicit operational context', () => {
  assert.throws(
    () => transition(caseRecord(), { status: 'waiting_for_user', waitingReason: '' }),
    /support_waiting_reason_required/,
  );
  const waiting = transition(caseRecord(), {
    status: 'waiting_for_user',
    waitingReason: 'Beleg wurde konkret angefordert.',
  });
  assert.equal(waiting.waitingOn, 'reporter');
  assert.equal(waiting.waitingReason, 'Beleg wurde konkret angefordert.');

  const underReview = caseRecord({ status: 'under_review' });
  assert.throws(
    () => transition(underReview, {
      status: 'escalated',
      escalationTargetRole: 'unknown_owner',
    }),
    /support_escalation_target_invalid/,
  );
  const escalated = transition(underReview, {
    status: 'escalated',
    escalationTargetRole: 'privacy_owner',
  });
  assert.equal(escalated.currentOwnerRole, 'privacy_owner');
  assert.equal(escalated.waitingOn, 'privacy_owner');
});

test('green cases cannot enter approval and decided cases stay operationally active', () => {
  assert.throws(
    () => transition(caseRecord({
      status: 'under_review',
      approval_level: 'green_automatic',
      severity: 'low',
      priority: 'p3',
      current_owner_role: 'general_support_owner',
    }), { status: 'decision_pending_approval' }),
    /support_decision_approval_level_invalid/,
  );
  const decided = transition(caseRecord({ status: 'decision_pending_approval' }), {
    status: 'decided',
    decisionId,
  });
  assert.equal(decided.decisionId, decisionId);
  assert.equal(decided.waitingOn, 'support_owner');
  assert.equal(decided.nextAction, 'Fall innerhalb der Frist weiter prüfen.');
  assert.deepEqual(decided.nextUpdateAt, nextUpdateAt);
});

test('implementation, resolution, closure and reopen guards fail closed', () => {
  assert.throws(
    () => transition(caseRecord({ status: 'decided' }), {
      status: 'implementation_pending',
      implementationPendingAction: '',
    }),
    /support_implementation_action_required/,
  );
  assert.throws(
    () => transition(caseRecord({ status: 'decided', priority: 'p0', severity: 'critical' }), {
      status: 'resolved',
      resolutionReference: 'Interne Auflösung dokumentiert.',
    }),
    /support_p0_resolution_requires_admin/,
  );
  const resolved = transition(
    caseRecord({ status: 'decided', priority: 'p0', severity: 'critical' }),
    { status: 'resolved', resolutionReference: 'Interne Auflösung dokumentiert.' },
    'admin',
  );
  assert.equal(resolved.waitingOn, 'none');
  assert.equal(resolved.nextAction, null);
  assert.equal(resolved.resolutionReference, 'Interne Auflösung dokumentiert.');

  assert.throws(
    () => transition(caseRecord({ status: 'resolved' }), {
      status: 'closed',
      closureReason: 'anything',
    }),
    /support_closure_reason_invalid/,
  );
  assert.throws(
    () => transition(caseRecord({ status: 'closed' }), {
      status: 'reopened',
      reopenReason: '',
    }),
    /support_reopen_reason_required/,
  );
  const reopened = transition(caseRecord({ status: 'closed' }), {
    status: 'reopened',
    reopenReason: 'Neue erhebliche Information wurde eingereicht.',
  });
  assert.equal(reopened.status, 'reopened');
  assert.equal(reopened.waitingOn, 'support_owner');
});
