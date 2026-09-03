import assert from 'node:assert/strict';
import {
  chmodSync,
  mkdtempSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import {
  prepareStagingEmailVerifiedTwoRoleJourney,
  retireStagingEmailVerifiedTwoRoleJourney,
  runStagingEmailVerifiedTwoRoleSimulation,
  verifyStagingEmailVerifiedJourneyPublished,
} from '../../tool/run_staging_email_verified_two_role_journey.mjs';

function response(status, value) {
  return { status, text: async () => JSON.stringify(value) };
}

function privateFixture() {
  const root = mkdtempSync(join(tmpdir(), 'sit-n22-two-role-'));
  chmodSync(root, 0o700);
  const sourceDirectory = join(root, 'source');
  const journeyDirectory = join(root, 'journeys');
  mkdirSync(sourceDirectory, { mode: 0o700 });
  mkdirSync(journeyDirectory, { mode: 0o700 });
  const sourceVaultFile = join(sourceDirectory, 'accounts.json');
  const imagePath = join(root, 'fixture.png');
  const accounts = [
    {
      role: 'owner',
      displayName: 'N22Owner',
      email: 'owner@example.invalid',
      password: ['owner', 'private', 'fixture', 'credential'].join('-'),
      registrationStatus: 'accepted',
      verificationStatus: 'email-link-verified',
      registrationAcceptedAt: '2026-09-03T00:00:00.000Z',
      verifiedAt: '2026-09-03T00:01:00.000Z',
    },
    {
      role: 'renter',
      displayName: 'N22Renter',
      email: 'renter@example.invalid',
      password: ['renter', 'private', 'fixture', 'credential'].join('-'),
      registrationStatus: 'accepted',
      verificationStatus: 'email-link-verified',
      registrationAcceptedAt: '2026-09-03T00:00:00.000Z',
      verifiedAt: '2026-09-03T00:01:00.000Z',
    },
  ];
  writeFileSync(sourceVaultFile, `${JSON.stringify({
    schemaVersion: 1,
    kind: 'sit-staging-synthetic-account-vault',
    runId: 'email-linked-source',
    status: 'email-link-verified-ready-for-login',
    apiBaseUrl: 'https://staging.shareittoo.com/api/v1',
    stripeLivemode: false,
    verificationMethod: 'email-link',
    accounts,
  })}\n`, { mode: 0o600 });
  writeFileSync(imagePath, Buffer.alloc(512, 7), { mode: 0o600 });
  return { root, sourceVaultFile, journeyDirectory, imagePath, accounts };
}

function safeBooking(state, workflowStatus) {
  return {
    id: state.bookingId,
    itemId: state.listing.id,
    workflowStatus,
    simulationOnly: true,
    platformContract: null,
    bindingExpiresAt: null,
    contractCreated: false,
    paymentCreated: false,
    reservationCreated: false,
    monetaryEffectMinor: 0,
  };
}

function stagingApi(accounts) {
  const state = {
    listing: null,
    bookingId: null,
    bookingStatus: null,
    threadId: 'thread-n22-fixture',
  };
  const byEmail = new Map(accounts.map((account) => [account.email, account]));
  const fetchImpl = async (url, options = {}) => {
    const parsed = new URL(url);
    const path = parsed.pathname.replace('/api/v1', '') + parsed.search;
    const method = options.method ?? 'GET';
    const authorization = options.headers?.Authorization ?? '';
    const role = authorization.includes('owner') ? 'owner' : 'renter';
    if (path === '/auth/login') {
      const body = JSON.parse(options.body);
      const account = byEmail.get(body.email);
      if (!account || account.password !== body.password) return response(401, { error: 'invalid_credentials' });
      return response(200, { accessToken: `${account.role}-${'x'.repeat(24)}` });
    }
    if (path === '/auth/me') {
      const account = accounts.find((entry) => entry.role === role);
      return response(200, { user: { id: `${role}-id`, email: account.email } });
    }
    if (path === '/uploads' && method === 'POST') {
      assert.ok(options.body instanceof FormData);
      return response(201, { url: 'https://staging.shareittoo.com/uploads/n22-full.png' });
    }
    if (path === '/listings' && method === 'POST') {
      state.listing = JSON.parse(options.body);
      return response(201, { listing: { ...state.listing, isActive: false } });
    }
    if (path === '/listings/mine') {
      return response(200, { listings: state.listing ? [{ ...state.listing }] : [] });
    }
    if (/^\/listings\/[^/]+\/availability$/u.test(path) && method === 'PUT') {
      return response(200, { availability: { saved: true } });
    }
    if (/^\/listings\/[^/]+\/status$/u.test(path) && method === 'PATCH') {
      const body = JSON.parse(options.body);
      state.listing.status = body.status;
      state.listing.isActive = body.status === 'active';
      return response(200, { listing: { ...state.listing } });
    }
    if (path === '/listings?sort=newest&limit=100') {
      return response(200, {
        listings: state.listing?.status === 'active' ? [{ ...state.listing }] : [],
      });
    }
    if (path === '/bookings' && method === 'POST') {
      const body = JSON.parse(options.body);
      state.bookingId = body.id;
      state.bookingStatus = 'requested';
      return response(201, { booking: safeBooking(state, state.bookingStatus) });
    }
    if (path === '/rental-requests') {
      return response(200, {
        requests: state.bookingId ? [safeBooking(state, state.bookingStatus)] : [],
      });
    }
    if (/\/availability\/check$/u.test(path)) return response(200, { available: true });
    if (/\/payment$/u.test(path)) return response(409, { error: 'pilot_simulation_payment_forbidden' });
    if (/\/transitions$/u.test(path) && method === 'POST') {
      state.bookingStatus = JSON.parse(options.body).status;
      return response(200, { booking: safeBooking(state, state.bookingStatus) });
    }
    if (path.startsWith('/message-threads/booking/')) {
      return response(201, { thread: { id: state.threadId } });
    }
    if (path === `/message-threads/${state.threadId}/messages` && method === 'POST') {
      return response(201, { message: { id: 'message-n22-fixture' } });
    }
    if (path === '/message-threads') return response(200, { threads: [{ id: state.threadId }] });
    if (path === `/message-threads/${state.threadId}/messages`) {
      return response(200, { messages: [{ text: 'SIT Stage-A Testchat: unverbindliche Pilot-Simulation.' }] });
    }
    if (path === '/notifications?limit=100') {
      return response(200, { notifications: [
        {
          entityId: state.bookingId,
          kind: 'booking_requested',
          title: 'Pilot-Simulation · Neue Buchungsanfrage',
          payload: { simulationOnly: true },
        },
        {
          entityId: state.bookingId,
          kind: 'booking_accepted',
          title: 'Pilot-Simulation · Anfrage angenommen',
          payload: { simulationOnly: true },
        },
      ] });
    }
    throw new Error(`Unexpected request: ${method} ${path}`);
  };
  return { state, fetchImpl };
}

test('runs and retires an isolated email-verified two-role Staging journey', async () => {
  const fixture = privateFixture();
  const api = stagingApi(fixture.accounts);
  const prepared = await prepareStagingEmailVerifiedTwoRoleJourney({
    sourceVaultFile: fixture.sourceVaultFile,
    vaultRoot: fixture.journeyDirectory,
    imagePath: fixture.imagePath,
    fetchImpl: api.fetchImpl,
    now: new Date('2026-09-03T08:00:00.000Z'),
    random: () => Buffer.from([1, 2, 3, 4]),
  });
  assert.equal(prepared.status, 'owner-draft-ready-for-pixel-publish');
  assert.equal(prepared.emailLinksVerified, true);
  assert.equal(prepared.distinctPrincipalsVerified, true);
  assert.equal(prepared.containsSecrets, false);
  assert.equal(prepared.containsEmailAddresses, false);
  assert.equal(prepared.containsTokens, false);
  assert.equal(api.state.listing.status, 'draft');

  api.state.listing.status = 'active';
  api.state.listing.isActive = true;
  const published = await verifyStagingEmailVerifiedJourneyPublished({
    vaultFile: prepared.vaultFile,
    fetchImpl: api.fetchImpl,
  });
  assert.equal(published.status, 'pixel-owner-publish-server-confirmed');
  assert.equal(published.publicCatalogVisible, true);

  const simulation = await runStagingEmailVerifiedTwoRoleSimulation({
    vaultFile: prepared.vaultFile,
    fetchImpl: api.fetchImpl,
    now: new Date('2026-09-03T08:10:00.000Z'),
    random: () => Buffer.from([5, 6, 7, 8]),
    wait: async () => {},
  });
  assert.equal(simulation.status, 'email-verified-two-role-simulation-ready-for-pixel-review');
  assert.equal(simulation.monetaryEffectMinor, 0);
  assert.equal(simulation.paymentEndpointCalled, false);

  const retired = await retireStagingEmailVerifiedTwoRoleJourney({
    vaultFile: prepared.vaultFile,
    fetchImpl: api.fetchImpl,
  });
  assert.equal(retired.status, 'email-verified-two-role-product-journey-retired');
  assert.equal(retired.bookingCancelled, true);
  assert.equal(retired.listingEnded, true);
  assert.equal(retired.publicCatalogEntryRemoved, true);
  assert.equal(retired.monetaryEffectMinor, 0);
  const vault = JSON.parse(readFileSync(prepared.vaultFile, 'utf8'));
  assert.equal(vault.status, 'email-linked-product-journey-retired');
  assert.equal(vault.realTwoRoleJourney.status, 'retired');
  assert.equal(vault.realTwoRoleJourney.listingStatus, 'ended');
  assert.equal(vault.realTwoRoleJourney.bookingStatus, 'cancelled');
});

test('rejects a source vault that has not completed both email links', async () => {
  const fixture = privateFixture();
  const source = JSON.parse(readFileSync(fixture.sourceVaultFile, 'utf8'));
  source.accounts[1].verificationStatus = 'pending';
  writeFileSync(fixture.sourceVaultFile, `${JSON.stringify(source)}\n`, { mode: 0o600 });
  await assert.rejects(
    () => prepareStagingEmailVerifiedTwoRoleJourney({
      sourceVaultFile: fixture.sourceVaultFile,
      vaultRoot: fixture.journeyDirectory,
      imagePath: fixture.imagePath,
      fetchImpl: async () => response(500, {}),
    }),
    /exact email-link-verified two-role Staging fixture/u,
  );
});
