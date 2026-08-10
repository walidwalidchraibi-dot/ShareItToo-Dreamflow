import assert from 'node:assert/strict';
import { chmodSync, mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import test from 'node:test';

import {
  createSyntheticBookingFixture,
  transitionSyntheticBookingFixture,
} from '../../tool/run_staging_synthetic_booking.mjs';

function vaultFixture({ baseUrl = 'https://staging.shareittoo.com/api/v1' } = {}) {
  const root = mkdtempSync(resolve(tmpdir(), 'sit-synthetic-booking-'));
  chmodSync(root, 0o700);
  const vaultFile = resolve(root, 'accounts.json');
  const imagePath = resolve(root, 'fixture.png');
  writeFileSync(imagePath, Buffer.alloc(512, 7));
  writeFileSync(vaultFile, `${JSON.stringify({
    schemaVersion: 1,
    kind: 'sit-staging-synthetic-account-vault',
    runId: '20260810t065907z-a6b6f407',
    status: 'fixture-verified-ready-for-login',
    apiBaseUrl: baseUrl,
    stripeLivemode: false,
    accounts: [
      { role: 'owner', email: 'owner@example.invalid', password: 'Owner-Password-123456' },
      { role: 'renter', email: 'renter@example.invalid', password: 'Renter-Password-123456' },
    ],
  }, null, 2)}\n`, { mode: 0o600 });
  chmodSync(vaultFile, 0o600);
  return { vaultFile, imagePath };
}

function response(status, value) {
  return new Response(value === null ? '' : JSON.stringify(value), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function createFetch(log) {
  let login = 0;
  return async (url, options = {}) => {
    const path = new URL(url).pathname.replace('/api/v1', '');
    log.push({ path, method: options.method ?? 'GET' });
    if (path === '/auth/login') {
      login += 1;
      return response(200, { accessToken: `synthetic-token-${login}-${'x'.repeat(30)}` });
    }
    if (path === '/listings/mine') return response(200, { listings: [] });
    if (path === '/rental-requests') return response(200, { requests: [] });
    if (path === '/uploads') return response(201, { url: 'https://staging.shareittoo.com/api/v1/uploads/fixture.webp' });
    if (path === '/listings') return response(201, { listing: { id: 'fixture' } });
    if (path.endsWith('/availability')) return response(200, { availability: {} });
    if (path === '/bookings') return response(201, { booking: { workflowStatus: 'requested' } });
    throw new Error(`Unexpected path ${path}`);
  };
}

test('creates an isolated requested booking and returns no credentials or identifiers', async () => {
  const fixture = vaultFixture();
  const calls = [];
  const result = await createSyntheticBookingFixture({
    ...fixture,
    fetchImpl: createFetch(calls),
    now: new Date('2026-08-10T08:00:00.000Z'),
    random: () => Buffer.from('a1b2c3d4', 'hex'),
  });
  assert.deepEqual(result, {
    status: 'synthetic-booking-requested',
    rolesLoggedIn: ['owner', 'renter'],
    listingCreated: true,
    bookingCreated: true,
    fixtureRecovered: false,
    workflowStatus: 'requested',
    paymentMode: 'memory',
    stripeLivemode: false,
    paymentEndpointCalled: false,
    containsSecrets: false,
    containsEmailAddresses: false,
    containsTokens: false,
  });
  assert.equal(calls.some(({ path }) => path.includes('payment')), false);
  const stored = JSON.parse(readFileSync(fixture.vaultFile, 'utf8'));
  assert.equal(stored.syntheticBooking.workflowStatus, 'requested');
});

test('transitions the synthetic booking with the correct roles and no payment endpoint', async () => {
  const fixture = vaultFixture();
  await createSyntheticBookingFixture({
    ...fixture,
    fetchImpl: createFetch([]),
    random: () => Buffer.from('a1b2c3d4', 'hex'),
  });
  const calls = [];
  for (const [status, actingRole, workflowStatus] of [
    ['accepted', 'owner', 'accepted'],
    ['running', 'renter', 'active'],
    ['completed', 'owner', 'completed'],
  ]) {
    const fetchImpl = async (url) => {
      const path = new URL(url).pathname.replace('/api/v1', '');
      calls.push(path);
      if (path === '/auth/login') return response(200, { accessToken: `synthetic-token-${'x'.repeat(40)}` });
      if (path.endsWith('/transitions')) return response(200, { booking: { workflowStatus } });
      throw new Error(`Unexpected path ${path}`);
    };
    const result = await transitionSyntheticBookingFixture({ ...fixture, status, fetchImpl });
    assert.equal(result.actingRole, actingRole);
    assert.equal(result.paymentEndpointCalled, false);
  }
  assert.equal(calls.some((path) => path.includes('payment')), false);
  assert.equal(JSON.parse(readFileSync(fixture.vaultFile, 'utf8')).status, 'synthetic-booking-completed');
});

test('recovers one already-created requested fixture without creating a duplicate', async () => {
  const fixture = vaultFixture();
  const calls = [];
  let login = 0;
  const result = await createSyntheticBookingFixture({
    ...fixture,
    now: new Date('2026-08-10T08:00:00.000Z'),
    fetchImpl: async (url) => {
      const path = new URL(url).pathname.replace('/api/v1', '');
      calls.push(path);
      if (path === '/auth/login') {
        login += 1;
        return response(200, { accessToken: `synthetic-token-${login}-${'x'.repeat(30)}` });
      }
      if (path === '/listings/mine') {
        return response(200, { listings: [{
          id: 'existing-listing',
          title: 'SIT Rollenprüfung 20260810t065907z-a6b6f407',
        }] });
      }
      if (path === '/rental-requests') {
        return response(200, { requests: [{
          id: 'existing-booking',
          itemId: 'existing-listing',
          workflowStatus: 'requested',
          startDate: '2026-10-09',
          endDate: '2026-10-11',
        }] });
      }
      throw new Error(`Unexpected path ${path}`);
    },
  });
  assert.equal(result.fixtureRecovered, true);
  assert.equal(result.workflowStatus, 'requested');
  assert.equal(calls.includes('/uploads'), false);
  assert.equal(calls.includes('/listings'), false);
  assert.equal(calls.includes('/bookings'), false);
});

test('rejects a production or otherwise different API base before any request', async () => {
  const fixture = vaultFixture({ baseUrl: 'https://shareittoo.com/api/v1' });
  let called = false;
  await assert.rejects(
    createSyntheticBookingFixture({
      ...fixture,
      fetchImpl: async () => {
        called = true;
        return response(500, null);
      },
    }),
    /not an isolated, verified Staging role set/,
  );
  assert.equal(called, false);
});
