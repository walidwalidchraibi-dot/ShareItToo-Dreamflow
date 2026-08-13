import crypto from 'node:crypto';

export class PaymentDomainError extends Error {
  constructor(status, code, details = undefined) {
    super(code);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export function canonicalJson(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

export function requestHash(value) {
  return crypto.createHash('sha256').update(canonicalJson(value)).digest('hex');
}

export function payloadHash(raw) {
  return crypto.createHash('sha256').update(raw).digest('hex');
}

export function paymentIdempotencyKey(value, prefix) {
  const key = typeof value === 'string' ? value.trim() : '';
  if (key.length >= 12 && key.length <= 200 && /^[A-Za-z0-9_.:-]+$/.test(key)) return key;
  throw new PaymentDomainError(400, 'invalid_idempotency_key', { prefix });
}

export function normalizePaymentCurrency(value, expected = 'EUR') {
  const currency = typeof value === 'string' ? value.trim().toUpperCase() : '';
  if (!/^[A-Z]{3}$/.test(currency)) throw new PaymentDomainError(400, 'invalid_payment_currency');
  if (expected && currency !== expected) {
    throw new PaymentDomainError(409, 'unsupported_payment_currency', { expected });
  }
  return currency;
}

export function paymentAmounts(booking) {
  const amountMinor = Number(booking.quoted_total_minor);
  const ownerPayoutMinor = Number(booking.owner_payout_minor);
  const rentalSubtotalMinor = Number(booking.rental_subtotal_minor);
  const integers = [amountMinor, ownerPayoutMinor, rentalSubtotalMinor];
  if (!integers.every(Number.isSafeInteger) || amountMinor <= 0
      || ownerPayoutMinor < 0 || ownerPayoutMinor > amountMinor
      || rentalSubtotalMinor < 0) {
    throw new PaymentDomainError(409, 'invalid_booking_payment_amounts');
  }
  return Object.freeze({
    amountMinor,
    ownerPayoutMinor,
    platformFeeMinor: amountMinor - ownerPayoutMinor,
    rentalSubtotalMinor,
    securityDepositMinor: 0,
    currency: normalizePaymentCurrency(booking.currency),
  });
}

export function captureLedger({ amountMinor, ownerPayoutMinor, platformFeeMinor, ownerId }) {
  if (ownerPayoutMinor + platformFeeMinor !== amountMinor) {
    throw new PaymentDomainError(500, 'unbalanced_payment_breakdown');
  }
  return Object.freeze([
    { accountCode: 'stripe_clearing', accountOwnerId: null, debitMinor: amountMinor, creditMinor: 0 },
    { accountCode: 'owner_payable', accountOwnerId: ownerId, debitMinor: 0, creditMinor: ownerPayoutMinor },
    { accountCode: 'platform_revenue', accountOwnerId: null, debitMinor: 0, creditMinor: platformFeeMinor },
  ].filter((entry) => entry.debitMinor > 0 || entry.creditMinor > 0));
}

export function transferLedger({ amountMinor, ownerId }) {
  if (!Number.isSafeInteger(amountMinor) || amountMinor <= 0) {
    throw new PaymentDomainError(500, 'invalid_transfer_amount');
  }
  return Object.freeze([
    { accountCode: 'owner_payable', accountOwnerId: ownerId, debitMinor: amountMinor, creditMinor: 0 },
    { accountCode: 'stripe_clearing', accountOwnerId: null, debitMinor: 0, creditMinor: amountMinor },
  ]);
}

export function refundLedger({ amountMinor, ownerShareMinor, platformShareMinor, ownerId }) {
  if (![amountMinor, ownerShareMinor, platformShareMinor].every(Number.isSafeInteger)
      || amountMinor <= 0 || ownerShareMinor < 0 || platformShareMinor < 0
      || ownerShareMinor + platformShareMinor !== amountMinor) {
    throw new PaymentDomainError(500, 'invalid_refund_breakdown');
  }
  return Object.freeze([
    ...(ownerShareMinor ? [{ accountCode: 'owner_payable', accountOwnerId: ownerId, debitMinor: ownerShareMinor, creditMinor: 0 }] : []),
    ...(platformShareMinor ? [{ accountCode: 'platform_revenue', accountOwnerId: null, debitMinor: platformShareMinor, creditMinor: 0 }] : []),
    { accountCode: 'stripe_clearing', accountOwnerId: null, debitMinor: 0, creditMinor: amountMinor },
  ]);
}

export function splitRefund({ amountMinor, paymentAmountMinor, ownerPayoutMinor }) {
  if (![amountMinor, paymentAmountMinor, ownerPayoutMinor].every(Number.isSafeInteger)
      || amountMinor <= 0 || amountMinor > paymentAmountMinor || ownerPayoutMinor < 0) {
    throw new PaymentDomainError(400, 'invalid_refund_amount');
  }
  const ownerShareMinor = amountMinor === paymentAmountMinor
    ? ownerPayoutMinor
    : Math.min(ownerPayoutMinor, Math.round(amountMinor * ownerPayoutMinor / paymentAmountMinor));
  return Object.freeze({
    ownerShareMinor,
    platformShareMinor: amountMinor - ownerShareMinor,
  });
}

export function paymentStatusForProvider(eventType, object = {}) {
  const status = object.status;
  if (eventType === 'checkout.session.expired') return 'cancelled';
  if (eventType === 'payment_intent.succeeded') return 'captured';
  if (eventType === 'payment_intent.payment_failed') return 'failed';
  if (eventType === 'payment_intent.canceled') return 'cancelled';
  if (eventType === 'payment_intent.requires_action' || status === 'requires_action') return 'requires_action';
  if (eventType === 'payment_intent.amount_capturable_updated' || status === 'requires_capture') return 'authorized';
  if (status === 'succeeded') return 'captured';
  return null;
}

export function stripeSignatureHeader({ payload, secret, timestamp = Math.floor(Date.now() / 1000) }) {
  const signature = crypto.createHmac('sha256', secret).update(`${timestamp}.${payload}`).digest('hex');
  return `t=${timestamp},v1=${signature}`;
}

export function verifyStripeSignature({ rawBody, header, secret, now = Date.now(), toleranceSeconds = 300 }) {
  if (!Buffer.isBuffer(rawBody) || !rawBody.length) throw new PaymentDomainError(400, 'empty_webhook_payload');
  if (typeof header !== 'string' || !header) throw new PaymentDomainError(400, 'missing_webhook_signature');
  const values = header.split(',').map((part) => part.trim().split('=', 2));
  const timestamp = Number(values.find(([key]) => key === 't')?.[1]);
  const signatures = values.filter(([key]) => key === 'v1').map(([, value]) => value);
  if (!Number.isSafeInteger(timestamp) || !signatures.length) {
    throw new PaymentDomainError(400, 'invalid_webhook_signature');
  }
  if (Math.abs(Math.floor(now / 1000) - timestamp) > toleranceSeconds) {
    throw new PaymentDomainError(400, 'expired_webhook_signature');
  }
  const expected = crypto.createHmac('sha256', secret)
    .update(`${timestamp}.${rawBody.toString('utf8')}`)
    .digest();
  const valid = signatures.some((candidate) => {
    if (!/^[0-9a-f]{64}$/i.test(candidate)) return false;
    const supplied = Buffer.from(candidate, 'hex');
    return supplied.length === expected.length && crypto.timingSafeEqual(supplied, expected);
  });
  if (!valid) throw new PaymentDomainError(400, 'invalid_webhook_signature');
  return true;
}

export function safeProviderObjectId(value, prefix) {
  const id = typeof value === 'string' ? value.trim() : '';
  if (!id.startsWith(prefix) || id.length > 255 || !/^[A-Za-z0-9_]+$/.test(id)) {
    throw new PaymentDomainError(400, 'invalid_provider_object_id');
  }
  return id;
}
