import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { chmodSync, mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import test from 'node:test';

import {
  archiveCompletedSyntheticBookingFixture,
  archiveTerminalSyntheticBookingFixture,
  createSyntheticBookingFixture,
  prepareSyntheticBookingThread,
  reconcileSyntheticBookingFixture,
  runSyntheticRoleBookingLifecycle,
  sendSyntheticBookingDiagnosticMessage,
  transitionSyntheticBookingFixture,
} from '../../tool/run_staging_synthetic_booking.mjs';

function createEphemeralFixturePassword() {
  return `Aa9!${crypto.randomBytes(24).toString('base64url')}`;
}

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
      { role: 'owner', email: 'owner@example.invalid', password: createEphemeralFixturePassword() },
      { role: 'renter', email: 'renter@example.invalid', password: createEphemeralFixturePassword() },
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

test('runs the complete role-visible lifecycle without returning private fixture data', async () => {
  const fixture = vaultFixture();
  const calls = [];
  let workflowStatus = null;
  let login = 0;
  const result = await runSyntheticRoleBookingLifecycle({
    ...fixture,
    now: new Date('2026-08-11T19:20:00.000Z'),
    random: () => Buffer.from('a1b2c3d4', 'hex'),
    fetchImpl: async (url, options = {}) => {
      const path = new URL(url).pathname.replace('/api/v1', '');
      calls.push({ path, method: options.method ?? 'GET' });
      if (path === '/auth/login') {
        login += 1;
        return response(200, { accessToken: `synthetic-token-${login}-${'x'.repeat(30)}` });
      }
      if (path === '/listings/mine') return response(200, { listings: [] });
      if (path === '/rental-requests') {
        if (workflowStatus === null) return response(200, { requests: [] });
        return response(200, { requests: [{ id: 'sit-20260810t065907z-a6b6f407-a1b2c3d4-booking', workflowStatus }] });
      }
      if (path === '/uploads') return response(201, { url: 'https://staging.shareittoo.com/api/v1/uploads/fixture.webp' });
      if (path === '/listings') return response(201, { listing: { id: 'fixture' } });
      if (path.endsWith('/availability')) return response(200, { availability: {} });
      if (path === '/bookings') {
        workflowStatus = 'requested';
        return response(201, { booking: { workflowStatus } });
      }
      if (path.endsWith('/transitions')) {
        const requested = JSON.parse(options.body).status;
        workflowStatus = { accepted: 'accepted', running: 'active', completed: 'completed' }[requested];
        return response(200, { booking: { workflowStatus } });
      }
      throw new Error(`Unexpected path ${path}`);
    },
  });
  assert.equal(result.status, 'passed-bounded-synthetic-role-booking-lifecycle');
  assert.deepEqual(result.workflow, ['requested', 'accepted', 'active', 'completed']);
  assert.equal(result.tests.ownerRequestVisibility.result, 'requested-visible-to-owner');
  assert.equal(result.tests.renterUpcomingVisibility.result, 'accepted-visible-to-renter');
  assert.equal(result.tests.renterRunningVisibility.result, 'active-visible-to-renter');
  assert.equal(result.tests.renterCompletedVisibility.result, 'completed-visible-to-renter');
  assert.equal(result.paymentEndpointCalled, false);
  assert.equal(result.containsSecrets, false);
  assert.equal(result.containsFixtureIdentifiers, false);
  assert.equal(calls.some(({ path }) => path.includes('payment')), false);
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

test('archives only a completed payment-free fixture without returning private identifiers', async () => {
  const fixture = vaultFixture();
  await createSyntheticBookingFixture({
    ...fixture,
    fetchImpl: createFetch([]),
    random: () => Buffer.from('a1b2c3d4', 'hex'),
  });
  for (const [status, workflowStatus] of [
    ['accepted', 'accepted'],
    ['running', 'active'],
    ['completed', 'completed'],
  ]) {
    await transitionSyntheticBookingFixture({
      ...fixture,
      status,
      fetchImpl: async (url) => {
        const path = new URL(url).pathname.replace('/api/v1', '');
        if (path === '/auth/login') return response(200, { accessToken: `synthetic-token-${'x'.repeat(40)}` });
        if (path.endsWith('/transitions')) return response(200, { booking: { workflowStatus } });
        throw new Error(`Unexpected path ${path}`);
      },
    });
  }
  const result = archiveCompletedSyntheticBookingFixture({
    vaultFile: fixture.vaultFile,
    nextRunId: 'next-private-run',
    now: new Date('2026-08-10T17:40:00.000Z'),
  });
  assert.deepEqual(result, {
    status: 'synthetic-booking-archived',
    historyCount: 1,
    readyForNextFixture: true,
    paymentMode: 'memory',
    stripeLivemode: false,
    paymentEndpointCalled: false,
    containsSecrets: false,
    containsEmailAddresses: false,
    containsTokens: false,
    containsFixtureIdentifiers: false,
  });
  const stored = JSON.parse(readFileSync(fixture.vaultFile, 'utf8'));
  assert.equal(stored.syntheticBooking, undefined);
  assert.equal(stored.syntheticBookingHistory.length, 1);
  assert.equal(stored.syntheticBookingHistory[0].workflowStatus, 'completed');
  assert.equal(stored.runId, 'next-private-run');
  assert.equal(stored.status, 'fixture-verified-ready-for-login');
});

test('refuses to archive an active fixture', async () => {
  const fixture = vaultFixture();
  await createSyntheticBookingFixture({
    ...fixture,
    fetchImpl: createFetch([]),
    random: () => Buffer.from('a1b2c3d4', 'hex'),
  });
  assert.throws(
    () => archiveCompletedSyntheticBookingFixture({
      vaultFile: fixture.vaultFile,
      nextRunId: 'next-private-run',
    }),
    /Only a completed, payment-free Staging fixture can be archived/,
  );
});

test('reconciles and archives a server-cancelled payment-free fixture', async () => {
  const fixture = vaultFixture();
  await createSyntheticBookingFixture({
    ...fixture,
    fetchImpl: createFetch([]),
    random: () => Buffer.from('a1b2c3d4', 'hex'),
  });
  const storedBefore = JSON.parse(readFileSync(fixture.vaultFile, 'utf8'));
  const result = await reconcileSyntheticBookingFixture({
    ...fixture,
    now: new Date('2026-08-11T07:50:00.000Z'),
    fetchImpl: async (url) => {
      const path = new URL(url).pathname.replace('/api/v1', '');
      if (path === '/auth/login') return response(200, { accessToken: `synthetic-token-${'x'.repeat(40)}` });
      if (path === '/rental-requests') {
        return response(200, {requests: [{
          id: storedBefore.syntheticBooking.bookingId,
          workflowStatus: 'cancelled',
        }]});
      }
      throw new Error(`Unexpected path ${path}`);
    },
  });
  assert.deepEqual(result, {
    status: 'synthetic-booking-reconciled-terminal',
    workflowStatus: 'cancelled',
    terminal: true,
    paymentMode: 'memory',
    stripeLivemode: false,
    paymentEndpointCalled: false,
    containsSecrets: false,
    containsEmailAddresses: false,
    containsTokens: false,
    containsFixtureIdentifiers: false,
  });
  const reconciled = JSON.parse(readFileSync(fixture.vaultFile, 'utf8'));
  assert.equal(reconciled.status, 'synthetic-booking-terminal');
  assert.equal(reconciled.syntheticBooking.workflowStatus, 'cancelled');

  const archived = archiveTerminalSyntheticBookingFixture({
    vaultFile: fixture.vaultFile,
    nextRunId: 'fresh-push-run',
  });
  assert.equal(archived.readyForNextFixture, true);
  assert.equal(archived.containsFixtureIdentifiers, false);
  const ready = JSON.parse(readFileSync(fixture.vaultFile, 'utf8'));
  assert.equal(ready.status, 'fixture-verified-ready-for-login');
  assert.equal(ready.syntheticBooking, undefined);
  assert.equal(ready.syntheticBookingHistory.at(-1).workflowStatus, 'cancelled');
});

test('refuses terminal archive before server reconciliation', async () => {
  const fixture = vaultFixture();
  await createSyntheticBookingFixture({
    ...fixture,
    fetchImpl: createFetch([]),
    random: () => Buffer.from('a1b2c3d4', 'hex'),
  });
  assert.throws(
    () => archiveTerminalSyntheticBookingFixture({
      vaultFile: fixture.vaultFile,
      nextRunId: 'fresh-push-run',
    }),
    /Only a reconciled terminal, payment-free Staging fixture can be archived/,
  );
});

test('prepares a controlled thread and sends an identifier-free diagnostic message result', async () => {
  const fixture = vaultFixture();
  await createSyntheticBookingFixture({
    ...fixture,
    fetchImpl: createFetch([]),
    random: () => Buffer.from('a1b2c3d4', 'hex'),
  });
  await transitionSyntheticBookingFixture({
    ...fixture,
    status: 'accepted',
    fetchImpl: async (url) => {
      const path = new URL(url).pathname.replace('/api/v1', '');
      if (path === '/auth/login') return response(200, { accessToken: `synthetic-token-${'x'.repeat(40)}` });
      if (path.endsWith('/transitions')) return response(200, { booking: { workflowStatus: 'accepted' } });
      throw new Error(`Unexpected path ${path}`);
    },
  });
  const threadResult = await prepareSyntheticBookingThread({
    ...fixture,
    fetchImpl: async (url) => {
      const path = new URL(url).pathname.replace('/api/v1', '');
      if (path === '/auth/login') return response(200, { accessToken: `synthetic-token-${'x'.repeat(40)}` });
      if (path.includes('/message-threads/booking/')) {
        return response(201, { thread: { id: 'private-thread-id' } });
      }
      throw new Error(`Unexpected path ${path}`);
    },
  });
  assert.equal(threadResult.containsFixtureIdentifiers, false);
  assert.equal(JSON.parse(readFileSync(fixture.vaultFile, 'utf8')).syntheticBooking.threadId, 'private-thread-id');

  const messageResult = await sendSyntheticBookingDiagnosticMessage({
    ...fixture,
    diagnosticKind: 'foreground',
    fetchImpl: async (url) => {
      const path = new URL(url).pathname.replace('/api/v1', '');
      if (path === '/auth/login') return response(200, { accessToken: `synthetic-token-${'x'.repeat(40)}` });
      if (path.includes('/message-threads/private-thread-id/messages')) {
        return response(201, { message: { id: 'private-message-id' } });
      }
      throw new Error(`Unexpected path ${path}`);
    },
  });
  assert.equal(messageResult.status, 'synthetic-booking-diagnostic-message-sent');
  assert.equal(messageResult.diagnosticKind, 'foreground');
  assert.equal(messageResult.containsFixtureIdentifiers, false);
  assert.equal(messageResult.paymentEndpointCalled, false);
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

test('redacts private fixture identifiers from diagnostic message transport errors', async () => {
  const fixture = vaultFixture();
  const vault = JSON.parse(readFileSync(fixture.vaultFile, 'utf8'));
  vault.status = 'synthetic-booking-active';
  vault.syntheticBooking = {
    schemaVersion: 1,
    listingId: 'private-listing-id',
    bookingId: 'private-booking-id',
    threadId: 'private-thread-id',
    title: 'Private fixture title',
    workflowStatus: 'accepted',
    paymentMode: 'memory',
    stripeLivemode: false,
    paymentEndpointCalled: false,
  };
  writeFileSync(fixture.vaultFile, `${JSON.stringify(vault, null, 2)}\n`, { mode: 0o600 });
  chmodSync(fixture.vaultFile, 0o600);

  await assert.rejects(
    sendSyntheticBookingDiagnosticMessage({
      ...fixture,
      diagnosticKind: 'logout',
      fetchImpl: async (url) => {
        const path = new URL(url).pathname.replace('/api/v1', '');
        if (path === '/auth/login') {
          return response(200, { accessToken: `synthetic-token-${'x'.repeat(40)}` });
        }
        return response(409, { error: 'fixture-conflict' });
      },
    }),
    (error) => {
      assert.match(error.message, /Staging POST request failed with HTTP 409/);
      assert.equal(error.message.includes('private-thread-id'), false);
      assert.equal(error.message.includes('private-booking-id'), false);
      return true;
    },
  );
});
