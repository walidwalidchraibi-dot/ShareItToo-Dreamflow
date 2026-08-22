import assert from 'node:assert/strict';
import { chmodSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import test from 'node:test';

import { diagnoseStoreReviewSafetyActions } from '../../tool/diagnose_store_review_safety_actions.mjs';

function fixture() {
  const root = resolve(tmpdir(), `sit-review-safety-${process.pid}-${Date.now()}-${Math.random()}`);
  mkdirSync(root, { recursive: true, mode: 0o700 });
  chmodSync(root, 0o700);
  const path = resolve(root, 'accounts.json');
  writeFileSync(path, JSON.stringify({
    schemaVersion: 1,
    kind: 'sit-staging-synthetic-account-vault',
    apiBaseUrl: 'https://staging.shareittoo.com/api/v1',
    stripeLivemode: false,
    status: 'synthetic-booking-active',
    accounts: [
      { role: 'owner', registrationStatus: 'accepted', verificationStatus: 'email-link-verified', email: 'owner@example.test', password: `owner-${'x'.repeat(24)}` },
      { role: 'renter', registrationStatus: 'accepted', verificationStatus: 'email-link-verified', email: 'renter@example.test', password: `renter-${'y'.repeat(24)}` },
    ],
    syntheticBooking: {
      listingId: 'listing-safe', bookingId: 'booking-safe', threadId: 'thread-safe',
      workflowStatus: 'accepted', paymentMode: 'memory', stripeLivemode: false,
      paymentEndpointCalled: false,
    },
  }), { mode: 0o600 });
  chmodSync(path, 0o600);
  return path;
}

function response(status, value, headers = {}) {
  return new Response(value === null ? null : JSON.stringify(value), {
    status,
    headers: { 'content-type': 'application/json', ...headers },
  });
}

function successfulFetch(calls) {
  let login = 0;
  return async (url, options = {}) => {
    const path = new URL(url).pathname.replace('/api/v1', '');
    const method = options.method ?? 'GET';
    calls.push({ path, method, body: options.body ? JSON.parse(options.body) : null });
    if (path === '/auth/login') return response(200, { accessToken: `${login++ ? 'renter' : 'owner'}-${'t'.repeat(40)}` });
    if (path === '/auth/me') return response(200, { user: { id: options.headers.Authorization.includes('owner') ? 'owner-id' : 'renter-id' } });
    if (path === '/account/export') return response(200, {
      schemaVersion: '1.0', accountId: 'renter-id', data: {
        account: { id: 'renter-id' }, authentication: {}, marketplace: {}, communication: {},
        notifications: {}, trustAndSafety: {}, financialActivity: {}, auditEvents: [],
      },
    }, { 'cache-control': 'private, no-store', 'content-disposition': 'attachment; filename="shareittoo-data-export.json"' });
    if (path === '/reports' && method === 'POST') return response(201, { report: { id: 'report-safe', targetType: 'listing', targetId: 'listing-safe', status: 'open' } });
    if (path === '/reports/mine') return response(200, { reports: [{ id: 'report-safe' }] });
    if (path === '/user-blocks/owner-id' && ['PUT', 'DELETE'].includes(method)) return response(204, null);
    if (path === '/user-blocks') {
      const deleted = calls.some((entry) => entry.path === '/user-blocks/owner-id' && entry.method === 'DELETE');
      return response(200, { blocks: deleted ? [] : [{ userId: 'owner-id' }] });
    }
    if (path === '/message-threads/thread-safe' && method === 'PATCH') return response(200, { archivedForUserIds: [] });
    if (path === '/message-threads') return response(200, { threads: [{ id: 'thread-safe' }] });
    return response(404, { error: 'unexpected_test_path' });
  };
}

test('passes report, temporary block cleanup and private export without leaking identifiers', async () => {
  const calls = [];
  const result = await diagnoseStoreReviewSafetyActions({
    vaultFile: fixture(), fetchImpl: successfulFetch(calls), capturedAt: new Date('2026-08-11T03:00:00Z'),
  });
  assert.equal(result.status, 'report-block-export-passed-deletion-pending');
  assert.equal(result.scenarios.reportAndBlock, 'passed');
  assert.equal(result.scenarios.accountExport, 'passed');
  assert.equal(result.scenarios.accountDeletion, 'pending');
  assert.equal(result.checks.temporaryUserBlockRemoved, true);
  assert.equal(result.checks.sharedChatRestored, true);
  assert.equal(result.boundaries.lastingUserBlockCreated, false);
  const serialized = JSON.stringify(result);
  assert.doesNotMatch(serialized, /owner-id|renter-id|report-safe|listing-safe|thread-safe|example\.test|owner-x|renter-y/);
  assert.ok(calls.some((entry) => entry.path === '/user-blocks/owner-id' && entry.method === 'DELETE'));
  assert.ok(calls.some((entry) => entry.path === '/message-threads/thread-safe' && entry.method === 'PATCH'));
  const exportCall = calls.find((entry) => entry.path === '/account/export');
  assert.equal(exportCall.method, 'POST');
  assert.deepEqual(exportCall.body, { currentPassword: `renter-${'y'.repeat(24)}` });
});

test('rejects an incomplete or cacheable account export before moderation mutations', async () => {
  const calls = [];
  const fetchImpl = successfulFetch(calls);
  await assert.rejects(
    diagnoseStoreReviewSafetyActions({
      vaultFile: fixture(),
      fetchImpl: async (url, options) => {
        if (new URL(url).pathname.endsWith('/account/export')) {
          return response(200, { schemaVersion: '1.0' }, { 'cache-control': 'public' });
        }
        return fetchImpl(url, options);
      },
    }),
    /not private, complete, and bound/,
  );
  assert.equal(calls.some((entry) => entry.path === '/reports'), false);
});
