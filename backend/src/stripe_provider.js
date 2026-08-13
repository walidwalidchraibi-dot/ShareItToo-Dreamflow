import crypto from 'node:crypto';

import { PaymentDomainError } from './payment_domain.js';

function flattenForm(value, prefix = '', output = new URLSearchParams()) {
  if (value === undefined || value === null) return output;
  if (Array.isArray(value)) {
    value.forEach((entry, index) => flattenForm(entry, `${prefix}[${index}]`, output));
    return output;
  }
  if (typeof value === 'object') {
    Object.entries(value).forEach(([key, entry]) => {
      flattenForm(entry, prefix ? `${prefix}[${key}]` : key, output);
    });
    return output;
  }
  output.append(prefix, String(value));
  return output;
}

function memoryId(prefix) {
  return `${prefix}_${crypto.randomBytes(12).toString('hex')}`;
}

function providerError(status, payload) {
  const code = typeof payload?.error?.code === 'string' ? payload.error.code : 'stripe_request_failed';
  return new PaymentDomainError(status >= 500 ? 503 : 409, code, {
    providerStatus: status,
    declineCode: typeof payload?.error?.decline_code === 'string' ? payload.error.decline_code : undefined,
  });
}

export class StripeProvider {
  constructor({
    mode,
    secretKey = '',
    apiBase = 'https://api.stripe.com/v1',
    apiVersion = '',
    livemode = false,
    fetchImpl = globalThis.fetch,
  }) {
    this.mode = mode;
    this.secretKey = secretKey;
    this.apiBase = apiBase.replace(/\/$/, '');
    this.apiVersion = apiVersion;
    this.livemode = livemode;
    this.fetchImpl = fetchImpl;
    this.memory = new Map();
  }

  get enabled() {
    return this.mode !== 'disabled';
  }

  async request(path, { method = 'POST', params = {}, idempotencyKey = null, accountId = null } = {}) {
    if (this.mode !== 'stripe') throw new PaymentDomainError(503, 'stripe_transport_not_enabled');
    let response;
    try {
      response = await this.fetchImpl(`${this.apiBase}${path}`, {
        method,
        headers: {
          Authorization: `Bearer ${this.secretKey}`,
          Accept: 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
          ...(idempotencyKey ? { 'Idempotency-Key': idempotencyKey } : {}),
          ...(accountId ? { 'Stripe-Account': accountId } : {}),
          ...(this.apiVersion ? { 'Stripe-Version': this.apiVersion } : {}),
        },
        body: method === 'GET' ? undefined : flattenForm(params),
        signal: AbortSignal.timeout(15_000),
      });
    } catch {
      throw new PaymentDomainError(503, 'stripe_unavailable');
    }
    let payload;
    try {
      payload = await response.json();
    } catch {
      throw new PaymentDomainError(503, 'stripe_invalid_response');
    }
    if (!response.ok) throw providerError(response.status, payload);
    return payload;
  }

  async createConnectedAccount({ userId, email, country, currency, idempotencyKey }) {
    if (this.mode === 'memory') {
      return {
        id: `acct_memory_${crypto.createHash('sha256').update(userId).digest('hex').slice(0, 20)}`,
        country,
        default_currency: currency.toLowerCase(),
        details_submitted: true,
        charges_enabled: true,
        payouts_enabled: true,
        capabilities: { transfers: 'active' },
        livemode: false,
        created: Math.floor(Date.now() / 1000),
      };
    }
    return this.request('/accounts', {
      idempotencyKey,
      params: {
        type: 'express',
        country,
        email,
        default_currency: currency.toLowerCase(),
        capabilities: { transfers: { requested: true } },
        metadata: { sit_user_id: userId },
      },
    });
  }

  async createAccountLink({ accountId, refreshUrl, returnUrl, idempotencyKey }) {
    if (this.mode === 'memory') {
      const token = memoryId('onboard');
      const url = `${returnUrl}${returnUrl.includes('?') ? '&' : '?'}memory_onboarding=${encodeURIComponent(token)}`;
      this.memory.set(token, { type: 'account_link', accountId });
      return { object: 'account_link', url, expires_at: Math.floor(Date.now() / 1000) + 1800 };
    }
    return this.request('/account_links', {
      idempotencyKey,
      params: {
        account: accountId,
        refresh_url: refreshUrl,
        return_url: returnUrl,
        type: 'account_onboarding',
        collection_options: { fields: 'eventually_due' },
      },
    });
  }

  async createCustomer({ userId, email, name, idempotencyKey }) {
    if (this.mode === 'memory') {
      return { id: `cus_memory_${crypto.createHash('sha256').update(userId).digest('hex').slice(0, 20)}`, livemode: false };
    }
    return this.request('/customers', {
      idempotencyKey,
      params: { email, name, metadata: { sit_user_id: userId } },
    });
  }

  async createPaymentCheckout({
    paymentId,
    bookingId,
    customerId,
    amountMinor,
    currency,
    itemTitle,
    transferGroup,
    successUrl,
    cancelUrl,
    expiresAt,
    idempotencyKey,
  }) {
    if (this.mode === 'memory') {
      const id = memoryId('cs_memory');
      const paymentIntent = memoryId('pi_memory');
      const url = `${successUrl}${successUrl.includes('?') ? '&' : '?'}session_id=${encodeURIComponent(id)}&memory=1`;
      const result = {
        id,
        object: 'checkout.session',
        url,
        payment_intent: paymentIntent,
        customer: customerId,
        expires_at: expiresAt,
        livemode: false,
      };
      this.memory.set(id, { ...result, bookingId, paymentId, amountMinor, currency, transferGroup });
      return result;
    }
    return this.request('/checkout/sessions', {
      idempotencyKey,
      params: {
        mode: 'payment',
        customer: customerId,
        payment_method_types: ['card'],
        success_url: successUrl,
        cancel_url: cancelUrl,
        expires_at: expiresAt,
        client_reference_id: bookingId,
        line_items: [{
          quantity: 1,
          price_data: {
            currency: currency.toLowerCase(),
            unit_amount: amountMinor,
            product_data: { name: itemTitle },
          },
        }],
        payment_intent_data: {
          transfer_group: transferGroup,
          metadata: { sit_booking_id: bookingId, sit_payment_id: paymentId },
        },
        metadata: { sit_booking_id: bookingId, sit_payment_id: paymentId },
      },
    });
  }

  async createRefund({ chargeId, amountMinor, reverseTransfer, refundPlatformFee, idempotencyKey, metadata }) {
    if (this.mode === 'memory') {
      return {
        id: memoryId('re_memory'),
        status: 'succeeded',
        charge: chargeId,
        amount: amountMinor,
        currency: metadata.currency.toLowerCase(),
        livemode: false,
      };
    }
    return this.request('/refunds', {
      idempotencyKey,
      params: {
        charge: chargeId,
        amount: amountMinor,
        reverse_transfer: reverseTransfer,
        refund_application_fee: refundPlatformFee,
        metadata,
      },
    });
  }

  async createTransfer({ accountId, chargeId, amountMinor, currency, transferGroup, idempotencyKey, metadata }) {
    if (this.mode === 'memory') {
      return {
        id: memoryId('tr_memory'),
        destination: accountId,
        source_transaction: chargeId,
        amount: amountMinor,
        currency: currency.toLowerCase(),
        transfer_group: transferGroup,
        reversed: false,
        livemode: false,
        created: Math.floor(Date.now() / 1000),
      };
    }
    return this.request('/transfers', {
      idempotencyKey,
      params: {
        destination: accountId,
        source_transaction: chargeId,
        amount: amountMinor,
        currency: currency.toLowerCase(),
        transfer_group: transferGroup,
        metadata,
      },
    });
  }

  async reverseTransfer({ transferId, amountMinor, idempotencyKey, metadata }) {
    if (this.mode === 'memory') {
      return {
        id: memoryId('trr_memory'),
        transfer: transferId,
        amount: amountMinor,
        metadata,
        created: Math.floor(Date.now() / 1000),
      };
    }
    return this.request(`/transfers/${encodeURIComponent(transferId)}/reversals`, {
      idempotencyKey,
      params: { amount: amountMinor, metadata },
    });
  }

}
