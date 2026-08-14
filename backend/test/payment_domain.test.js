import assert from 'node:assert/strict';
import test from 'node:test';
import { StripeProvider } from '../src/stripe_provider.js';

import {
  captureLedger,
  paymentAmounts,
  paymentStatusForProvider,
  refundLedger,
  requestHash,
  splitRefund,
  privatePilotReleasableOwnerAmount,
  stripeSignatureHeader,
  transferLedger,
  verifyStripeSignature,
} from '../src/payment_domain.js';

test('private pilot payout releases only the undisputed authorized owner share', () => {
  const result = privatePilotReleasableOwnerAmount({
    paymentAmountMinor: 1100,
    ownerPayoutMinor: 1000,
    contestedAuthorizedMinor: 330,
  });
  assert.deepEqual(result, {
    ownerAfterRefundsMinor: 1000,
    heldOwnerMinor: 300,
    releasableMinor: 700,
  });
});

test('private pilot payout accounts for refunds and prior transfers', () => {
  const result = privatePilotReleasableOwnerAmount({
    paymentAmountMinor: 1100,
    ownerPayoutMinor: 1000,
    refundedOwnerMinor: 500,
    transferredMinor: 100,
    contestedAuthorizedMinor: 110,
  });
  assert.equal(result.heldOwnerMinor, 100);
  assert.equal(result.releasableMinor, 300);
});

function balanced(entries) {
  return entries.reduce((sum, entry) => sum + entry.debitMinor - entry.creditMinor, 0) === 0;
}

test('payment amounts are copied from the authoritative booking quote', () => {
  assert.deepEqual(paymentAmounts({
    quoted_total_minor: '1190',
    owner_payout_minor: '1000',
    rental_subtotal_minor: '900',
    security_deposit_minor: '5000',
    currency: 'EUR',
  }), {
    amountMinor: 1190,
    ownerPayoutMinor: 1000,
    platformFeeMinor: 190,
    rentalSubtotalMinor: 900,
    securityDepositMinor: 0,
    currency: 'EUR',
  });
  assert.throws(() => paymentAmounts({
    quoted_total_minor: '100', owner_payout_minor: '101', rental_subtotal_minor: '100', currency: 'EUR',
  }), /invalid_booking_payment_amounts/);
});

test('capture, transfer and refund ledger entries always balance', () => {
  const capture = captureLedger({ amountMinor: 1190, ownerPayoutMinor: 1000, platformFeeMinor: 190, ownerId: 'owner' });
  const transfer = transferLedger({ amountMinor: 1000, ownerId: 'owner' });
  const split = splitRefund({ amountMinor: 595, paymentAmountMinor: 1190, ownerPayoutMinor: 1000 });
  const refund = refundLedger({ amountMinor: 595, ...split, ownerId: 'owner' });
  assert.equal(balanced(capture), true);
  assert.equal(balanced(transfer), true);
  assert.equal(balanced(refund), true);
  assert.deepEqual(split, { ownerShareMinor: 500, platformShareMinor: 95 });
});

test('Stripe webhook signatures reject tampering, expiry and malformed headers', () => {
  const secret = 'whsec_unit_test_secret';
  const rawBody = Buffer.from('{"id":"evt_test","type":"payment_intent.succeeded"}');
  const now = Date.now();
  const header = stripeSignatureHeader({ payload: rawBody, secret, timestamp: Math.floor(now / 1000) });
  assert.equal(verifyStripeSignature({ rawBody, header, secret, now }), true);
  assert.throws(() => verifyStripeSignature({ rawBody: Buffer.from(`${rawBody}x`), header, secret, now }), /invalid_webhook_signature/);
  assert.throws(() => verifyStripeSignature({ rawBody, header, secret, now: now + 301_000 }), /expired_webhook_signature/);
  assert.throws(() => verifyStripeSignature({ rawBody, header: 'invalid', secret, now }), /invalid_webhook_signature/);
});

test('provider events map to authoritative payment states', () => {
  assert.equal(paymentStatusForProvider('payment_intent.succeeded', {}), 'captured');
  assert.equal(paymentStatusForProvider('payment_intent.payment_failed', {}), 'failed');
  assert.equal(paymentStatusForProvider('checkout.session.expired', {}), 'cancelled');
  assert.equal(paymentStatusForProvider('checkout.session.async_payment_failed', {}), 'failed');
  assert.equal(paymentStatusForProvider('payment_intent.amount_capturable_updated', {}), 'authorized');
  assert.equal(paymentStatusForProvider('checkout.session.completed', { status: 'complete', payment_status: 'paid' }), null);
  assert.equal(paymentStatusForProvider('checkout.session.async_payment_succeeded', { status: 'complete', payment_status: 'paid' }), null);
  assert.equal(paymentStatusForProvider('charge.refund.updated', { status: 'succeeded' }), null);
  assert.equal(paymentStatusForProvider('payment_intent.processing', { status: 'processing' }), null);
  assert.equal(paymentStatusForProvider('unrelated.event', {}), null);
});

test('request hashes are stable across object key order', () => {
  assert.equal(requestHash({ b: 2, a: { d: 4, c: 3 } }), requestHash({ a: { c: 3, d: 4 }, b: 2 }));
});

test('Stripe transport sends server-only form parameters and idempotency', async () => {
  let captured;
  const provider = new StripeProvider({
    mode: 'stripe',
    secretKey: 'sk_test_unit',
    fetchImpl: async (url, options) => {
      captured = { url, options };
      return { ok: true, status: 200, json: async () => ({ id: 'cus_test' }) };
    },
  });
  await provider.createCustomer({
    userId: 'user-1', email: 'person@example.invalid', name: 'Person', idempotencyKey: 'customer:user-1',
  });
  assert.equal(captured.url, 'https://api.stripe.com/v1/customers');
  assert.equal(captured.options.headers.Authorization, 'Bearer sk_test_unit');
  assert.equal(captured.options.headers['Idempotency-Key'], 'customer:user-1');
  const form = captured.options.body.toString();
  assert.match(form, /metadata%5Bsit_user_id%5D=user-1/);
  assert.doesNotMatch(form, /sk_test_unit/);

  await provider.createPaymentCheckout({
    paymentId: 'payment-1',
    bookingId: 'booking-1',
    customerId: 'cus_test',
    amountMinor: 1190,
    currency: 'EUR',
    itemTitle: 'Kamera',
    transferGroup: 'booking_booking-1',
    successUrl: 'https://shareittoo.com/api/v1/open/payment/booking-1?result=success',
    cancelUrl: 'https://shareittoo.com/api/v1/open/payment/booking-1?result=cancelled',
    expiresAt: 1799539200,
    idempotencyKey: 'checkout:booking-1',
  });
  const checkoutForm = captured.options.body.toString();
  assert.doesNotMatch(checkoutForm, /payment_method_types/);
  assert.match(checkoutForm, /payment_intent_data%5Btransfer_group%5D=booking_booking-1/);
  assert.doesNotMatch(checkoutForm, /setup_future_usage/);
});
