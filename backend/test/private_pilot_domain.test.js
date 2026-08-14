import assert from 'node:assert/strict';
import test from 'node:test';

import {
  assertPrivatePilotBooking,
  assertPrivatePilotListing,
  privatePilotDocument,
  privatePilotRequiredCheckoutDeclarations,
  PrivatePilotValidationError,
} from '../src/private_pilot_domain.js';
import {
  evaluateReturnTimeline,
  evaluateCancellation,
  cancellationAmounts,
  isBookingChatOpen,
  shortNoticeGraceDeadline,
  splitAuthorizedBookingAmount,
} from '../src/private_pilot_return_domain.js';

function checkoutDeclarations() {
  return privatePilotRequiredCheckoutDeclarations.map((entry) => ({
    type: entry.type,
    exactWording: entry.wording,
    documentName: privatePilotDocument.name,
    documentVersion: privatePilotDocument.version,
    language: privatePilotDocument.language,
    accepted: true,
    acceptedAt: '2026-08-14T12:00:00.000Z',
  }));
}

test('private listing and booking guardrails reject bypasses', () => {
  assert.equal(assertPrivatePilotListing({
    privateStatusConfirmed: true,
    categoryId: 'cat8',
    country: 'Deutschland',
  }), true);
  assert.throws(
    () => assertPrivatePilotListing({
      privateStatusConfirmed: true,
      categoryId: 'cat10',
      country: 'Deutschland',
    }),
    (error) => error instanceof PrivatePilotValidationError
      && error.code === 'private_pilot_category_not_allowed',
  );
  assert.throws(
    () => assertPrivatePilotBooking({
      privateStatusConfirmed: true,
      ownerDeliversAtDropoffChosen: true,
    }),
    (error) => error.code === 'private_pilot_delivery_disabled',
  );
  assert.equal(assertPrivatePilotBooking({
    privateStatusConfirmed: true,
    legalDeclarations: checkoutDeclarations(),
  }), true);
  assert.throws(
    () => assertPrivatePilotBooking({
      privateStatusConfirmed: true,
      legalDeclarations: checkoutDeclarations().slice(0, -1),
    }),
    (error) => error.code ===
      'private_pilot_declaration_missing:withdrawal_knowledge',
  );
});

test('missing return confirmation is neutral and never creates needsReview', () => {
  const timeline = evaluateReturnTimeline({
    scheduledReturnAt: '2026-09-01T10:00:00Z',
    ownerConfirmed: true,
    renterConfirmed: false,
    now: '2026-09-03T09:00:00Z',
  });
  assert.equal(timeline.state, 'awaitingReturnConfirmation');
  assert.equal(timeline.t1, null);
  assert.equal(timeline.clarificationDeadline, '2026-09-06T10:00:00.000Z');
});

test('return timeline releases after the applicable window without a case', () => {
  const both = evaluateReturnTimeline({
    scheduledReturnAt: '2026-09-01T10:00:00Z',
    mutuallyConfirmedActualReturnAt: '2026-09-01T09:30:00Z',
    ownerConfirmed: true,
    renterConfirmed: true,
    now: '2026-09-03T09:31:00Z',
  });
  assert.equal(both.state, 'payoutEligible');
  assert.equal(both.payoutInstructionDueAt, '2026-09-03T09:30:00.000Z');

  const missing = evaluateReturnTimeline({
    scheduledReturnAt: '2026-09-01T10:00:00Z',
    ownerConfirmed: false,
    renterConfirmed: true,
    now: '2026-09-06T10:01:00Z',
  });
  assert.equal(missing.state, 'payoutEligible');
});

test('only a substantiated case enters needsReview and keeps chat open', () => {
  const timeline = evaluateReturnTimeline({
    scheduledReturnAt: '2026-09-01T10:00:00Z',
    ownerConfirmed: true,
    renterConfirmed: true,
    substantiatedCaseOpenedAt: '2026-09-02T08:00:00Z',
    now: '2026-09-02T09:00:00Z',
  });
  assert.equal(timeline.state, 'needsReview');
  assert.equal(timeline.responseDueAt, '2026-09-07T08:00:00.000Z');
  assert.equal(isBookingChatOpen({ returnState: timeline.state }), true);
  assert.equal(isBookingChatOpen({
    returnState: timeline.state,
    caseClosedAt: '2026-09-04T08:00:00Z',
  }), false);
});

test('alleged damage never creates a charge or blocks undisputed rent', () => {
  const result = splitAuthorizedBookingAmount({
    authorizedBookingMinor: 11_000,
    contestedAuthorizedMinor: 2_000,
    allegedDamageMinor: 50_000,
  });
  assert.equal(result.undisputedReleasableMinor, 9_000);
  assert.equal(result.additionalChargeMinor, 0);

  const damageOnly = splitAuthorizedBookingAmount({
    authorizedBookingMinor: 11_000,
    allegedDamageMinor: 50_000,
  });
  assert.equal(damageOnly.undisputedReleasableMinor, 11_000);
});

test('short-notice cancellation grace ends exactly after 60 minutes or at start', () => {
  assert.equal(
    shortNoticeGraceDeadline({
      contractConfirmedAt: '2026-09-01T15:00:00Z',
      rentalStartAt: '2026-09-01T20:00:00Z',
    }).toISOString(),
    '2026-09-01T16:00:00.000Z',
  );
  assert.equal(
    shortNoticeGraceDeadline({
      contractConfirmedAt: '2026-09-01T15:00:00Z',
      rentalStartAt: '2026-09-01T15:30:00Z',
    }).toISOString(),
    '2026-09-01T15:30:00.000Z',
  );
  assert.equal(shortNoticeGraceDeadline({
    contractConfirmedAt: '2026-09-01T15:00:00Z',
    rentalStartAt: '2026-09-02T15:00:00Z',
  }), null);
});

test('V4 cancellation uses exact instants and cent-based proportional refund', () => {
  const outcome = evaluateCancellation({
    rentalStartAt: '2026-09-01T20:00:00Z',
    contractConfirmedAt: '2026-09-01T15:00:00Z',
    cancelAt: '2026-09-01T17:00:00Z',
    actor: 'renter',
  });
  assert.equal(outcome.refundBasisPoints, 5000);
  assert.deepEqual(cancellationAmounts({
    totalMinor: 11001,
    refundBasisPoints: outcome.refundBasisPoints,
  }), {
    totalMinor: 11001,
    refundBasisPoints: 5000,
    refundMinor: 5501,
    retainedMinor: 5500,
  });
  assert.equal(evaluateCancellation({
    rentalStartAt: '2026-09-01T20:00:00Z',
    cancelAt: '2026-09-02T10:00:00Z',
    actor: 'owner',
  }).refundBasisPoints, 10000);
});
