import assert from 'node:assert/strict';
import test from 'node:test';

import {
  actorRoleForBooking,
  amountToMinor,
  canTransitionBooking,
  canTransitionWorkflow,
  deliveryFeeForDistanceMinor,
  distanceKm,
  legacyStatusForWorkflow,
  normalizeBookingStatus,
  normalizeCurrency,
  parseBookingPeriod,
  parseRentalDates,
  platformFeeMinor,
  quoteRental,
  workflowStatusForLegacy,
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

test('rental dates are calendar-day based and remain stable across DST changes', () => {
  assert.deepEqual(parseRentalDates('2026-03-28', '2026-03-31'), {
    startDate: '2026-03-28',
    endDate: '2026-03-31',
    days: 3,
  });
  assert.equal(parseRentalDates('2026-02-30', '2026-03-02'), null);
  assert.equal(parseRentalDates('2026-03-30', '2026-03-30'), null);
  assert.equal(parseRentalDates('2026-03-31', '2026-03-30'), null);
});

test('server quote is deterministic in minor units and matches launch fee rules', () => {
  const quote = quoteRental({
    days: 5,
    pricePerDayMinor: 1_500,
    minimumDays: 1,
    maximumDays: 30,
    autoApplyDiscounts: true,
    discountTiers: [
      { days: 3, discountPercent: 10 },
      { days: 5, discountPercent: 20 },
    ],
    deliveryFeeMinor: 300,
    pickupFeeMinor: 420,
    currency: 'eur',
  });
  assert.deepEqual(quote, {
    quoteVersion: 1,
    currency: 'EUR',
    days: 5,
    pricePerDayMinor: 1_500,
    baseRentalMinor: 7_500,
    discountPercent: 20,
    discountMinor: 1_500,
    rentalSubtotalMinor: 6_000,
    platformFeeMinor: 600,
    deliveryFeeMinor: 300,
    pickupFeeMinor: 420,
    expressFeeMinor: 0,
    expressPlatformFeeMinor: 0,
    totalMinor: 7_320,
    ownerPayoutMinor: 6_720,
    securityDepositMinor: 0,
  });
  assert.equal(platformFeeMinor(0), 0);
  assert.equal(platformFeeMinor(1_000), 100);
  assert.equal(platformFeeMinor(1_001), 100);
  assert.equal(quoteRental({ days: 31, pricePerDayMinor: 100, maximumDays: 30 }), null);
});

test('distance delivery fees and workflow roles are server-controlled', () => {
  const berlinDistance = distanceKm(52.52, 13.405, 52.53, 13.405);
  assert.ok(berlinDistance > 1 && berlinDistance < 1.2);
  assert.equal(deliveryFeeForDistanceMinor(1), 300);
  assert.equal(deliveryFeeForDistanceMinor(10), 600);
  assert.equal(actorRoleForBooking({ actorId: 'owner', ownerId: 'owner', renterId: 'renter' }), 'owner');
  assert.equal(actorRoleForBooking({ actorId: 'renter', ownerId: 'owner', renterId: 'renter' }), 'renter');
  assert.equal(canTransitionWorkflow({ current: 'requested', next: 'accepted', actorRole: 'owner' }), true);
  assert.equal(canTransitionWorkflow({ current: 'requested', next: 'accepted', actorRole: 'renter' }), false);
  assert.equal(canTransitionWorkflow({ current: 'accepted', next: 'confirmed', actorRole: 'renter', pilotWithoutPayment: true }), true);
  assert.equal(canTransitionWorkflow({ current: 'completed', next: 'accepted', actorRole: 'owner' }), false);
  assert.equal(legacyStatusForWorkflow('confirmed'), 'accepted');
  assert.equal(legacyStatusForWorkflow('returned'), 'running');
  assert.equal(workflowStatusForLegacy('running'), 'active');
});
