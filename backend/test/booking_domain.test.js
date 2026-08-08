import assert from 'node:assert/strict';
import test from 'node:test';

import {
  amountToMinor,
  canTransitionBooking,
  normalizeBookingStatus,
  normalizeCurrency,
  parseBookingPeriod,
} from '../src/booking_domain.js';

test('booking periods require two valid instants in chronological order', () => {
  const period = parseBookingPeriod('2026-09-01T10:00:00Z', '2026-09-02T10:00:00Z');
  assert.equal(period.startsAt.toISOString(), '2026-09-01T10:00:00.000Z');
  assert.equal(period.endsAt.toISOString(), '2026-09-02T10:00:00.000Z');
  assert.equal(parseBookingPeriod('invalid', '2026-09-02T10:00:00Z'), null);
  assert.equal(parseBookingPeriod('2026-09-02T10:00:00Z', '2026-09-02T10:00:00Z'), null);
  assert.equal(parseBookingPeriod('2026-09-03T10:00:00Z', '2026-09-02T10:00:00Z'), null);
});

test('money is normalized to integer minor units and an ISO currency', () => {
  assert.equal(amountToMinor('19.99'), 1999);
  assert.equal(amountToMinor(10.005), 1001);
  assert.equal(amountToMinor(-1), null);
  assert.equal(amountToMinor('not-money'), null);
  assert.equal(normalizeCurrency(' eur '), 'EUR');
  assert.equal(normalizeCurrency('EURO'), 'EUR');
});

test('only the correct participant can perform each booking transition', () => {
  const booking = { ownerId: 'owner', renterId: 'renter' };
  assert.equal(canTransitionBooking({ ...booking, current: 'pending', next: 'accepted', actorId: 'owner' }), true);
  assert.equal(canTransitionBooking({ ...booking, current: 'pending', next: 'accepted', actorId: 'renter' }), false);
  assert.equal(canTransitionBooking({ ...booking, current: 'accepted', next: 'running', actorId: 'renter' }), true);
  assert.equal(canTransitionBooking({ ...booking, current: 'running', next: 'completed', actorId: 'owner' }), true);
  assert.equal(canTransitionBooking({ ...booking, current: 'completed', next: 'accepted', actorId: 'owner' }), false);
  assert.equal(normalizeBookingStatus('unknown'), 'pending');
});
