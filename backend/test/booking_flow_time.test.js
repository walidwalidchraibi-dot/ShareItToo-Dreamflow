import test from 'node:test';
import assert from 'node:assert/strict';

import {
  applyBookingFlowTimeAction,
  BookingFlowTimeError,
  normalizeBookingFlowTimeState,
} from '../src/booking_flow_time.js';

const base = Object.freeze({
  payload: { title: 'SIT Test' },
  ownerId: 'owner-1',
  renterId: 'renter-1',
  workflowStatus: 'accepted',
});

test('counterparties share one authoritative pickup proposal and confirmation', () => {
  const proposal = applyBookingFlowTimeAction({
    ...base,
    actorId: 'owner-1',
    raw: {
      action: 'propose',
      segment: 'pickup',
      label: 'Samstag, 22:00',
      timeIso: '2026-10-14T22:00:00.000Z',
    },
  });
  assert.equal(proposal.state.handoverTimeRequested, 'Samstag, 22:00');
  assert.equal(proposal.state.handoverTimeRequestedByUserId, 'owner-1');
  assert.equal(proposal.state.handoverTimeConfirmed, false);

  const confirmation = applyBookingFlowTimeAction({
    ...base,
    payload: proposal.payload,
    actorId: 'renter-1',
    raw: { action: 'confirm', segment: 'pickup' },
    now: new Date('2026-08-15T12:00:00.000Z'),
  });
  assert.equal(confirmation.state.handoverTimeConfirmed, true);
  assert.equal(confirmation.state.handoverTimeConfirmedByUserId, 'renter-1');
  assert.equal(confirmation.state.handoverTimeConfirmedAt, '2026-08-15T12:00:00.000Z');
  assert.equal(confirmation.state.flowTimeRevision, 2);
});

test('requester cannot confirm their own proposal', () => {
  assert.throws(
    () => applyBookingFlowTimeAction({
      ...base,
      payload: {
        handoverTimeRequested: 'Samstag, 22:00',
        handoverTimeIso: '2026-10-14T22:00:00.000Z',
        handoverTimeRequestedByUserId: 'owner-1',
      },
      actorId: 'owner-1',
      raw: { action: 'confirm', segment: 'pickup' },
    }),
    (error) => error instanceof BookingFlowTimeError
      && error.code === 'flow_time_counterparty_confirmation_required',
  );
});

test('outsiders cannot read or mutate normalized flow-time state', () => {
  assert.throws(
    () => applyBookingFlowTimeAction({
      ...base,
      actorId: 'outsider-1',
      raw: {
        action: 'propose',
        segment: 'return',
        label: 'Freitag, 10:00',
        timeIso: '2026-10-16T10:00:00.000Z',
      },
    }),
    (error) => error instanceof BookingFlowTimeError
      && error.code === 'booking_flow_time_forbidden',
  );
});

test('normalization does not expose unrelated booking payload fields', () => {
  const state = normalizeBookingFlowTimeState({
    title: 'private title',
    handoverTimeRequested: 'Samstag, 22:00',
    flowTimeRevision: 4,
  });
  assert.equal(state.handoverTimeRequested, 'Samstag, 22:00');
  assert.equal(state.flowTimeRevision, 4);
  assert.equal(Object.hasOwn(state, 'title'), false);
});
