import assert from 'node:assert/strict';
import { createHash, randomBytes } from 'node:crypto';
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { cleanStagingStoreFeed } from '../../tool/clean_staging_store_feed.mjs';

function writeVault(root, name, { owner, listingId, nested = false }) {
  const directory = join(root, name);
  mkdirSync(directory, { mode: 0o700 });
  const vaultFile = join(directory, 'accounts.json');
  const booking = { listingId, bookingId: `booking-${name}`, workflowStatus: 'accepted' };
  const value = {
    schemaVersion: 1,
    kind: 'sit-staging-synthetic-account-vault',
    apiBaseUrl: 'https://staging.shareittoo.com/api/v1',
    stripeLivemode: false,
    status: 'synthetic-booking-active',
    ...(nested ? { nested: { booking } } : { syntheticBooking: booking }),
    accounts: [{
      role: 'owner',
      email: owner,
      password: `Aa9-${randomBytes(18).toString('base64url')}`,
    }],
  };
  writeFileSync(vaultFile, `${JSON.stringify(value)}\n`, { mode: 0o600 });
  chmodSync(vaultFile, 0o600);
  return vaultFile;
}

function fixture() {
  const root = mkdtempSync(join(tmpdir(), 'sit-feed-clean-'));
  chmodSync(root, 0o700);
  const vaultFile = writeVault(root, 'one', { owner: 'one@example.invalid', listingId: 'protected-one' });
  writeVault(root, 'two', { owner: 'two@example.invalid', listingId: 'protected-two', nested: true });
  const stale = writeVault(root, 'stale', { owner: 'stale@example.invalid', listingId: 'obsolete' });
  const value = JSON.parse(readFileSync(stale, 'utf8'));
  value.status = 'fixture-verified-ready-for-login';
  delete value.syntheticBooking;
  writeFileSync(stale, `${JSON.stringify(value)}\n`, { mode: 0o600 });
  return { root, vaultFile };
}

function response(status, value) {
  return new Response(JSON.stringify(value), { status, headers: { 'content-type': 'application/json' } });
}

function initialState() {
  return new Map([
    ['one@example.invalid', [
      ...['drill', 'camera', 'tent', 'projector'].map((name) => ({
        id: `sit-store-preview-v1-${name}`, title: `Curated ${name}`, status: 'active', isActive: true,
      })),
      { id: 'protected-one', title: 'SIT Rollenprüfung one', status: 'active', isActive: true,
        description: 'Isoliertes Staging-Inserat für die Rollenprüfung.',
        categoryId: 'other',
        photos: ['https://staging.shareittoo.com/uploads/logo'] },
      { id: 'old-one', title: 'SIT Rollenprüfung old one', status: 'active', isActive: true },
    ]],
    ['two@example.invalid', [
      { id: 'protected-two', title: 'SIT Rollenprüfung two', status: 'active', isActive: true,
        photos: ['https://staging.shareittoo.com/uploads/genuine'] },
      { id: 'old-two', title: 'SIT Rollenprüfung old two', status: 'active', isActive: true },
    ]],
  ]);
}

function api(state, { failRenameFor, inaccessibleEmails = new Set(['stale@example.invalid']) } = {}) {
  const calls = [];
  const tokens = new Map();
  const fetchImpl = async (url, options = {}) => {
    const parsed = new URL(url);
    const path = parsed.pathname.replace('/api/v1', '');
    const method = options.method ?? 'GET';
    calls.push({ method, path });
    if (path === '/uploads/logo') return new Response('placeholder');
    if (path === '/uploads/genuine') return new Response('genuine-product-photo');
    if (path === '/uploads/replacement') return new Response('replacement');
    if (path === '/auth/login') {
      const email = JSON.parse(options.body).email;
      if (inaccessibleEmails.has(email)) return response(401, { error: 'invalid_credentials' });
      const token = `token-${email}`;
      tokens.set(token, email);
      return response(200, { accessToken: token });
    }
    if (path === '/listings' && method === 'GET') {
      return response(200, {
        listings: [...state.values()].flat().filter((entry) => entry.status === 'active'),
        page: { hasMore: false },
      });
    }
    if (path === '/uploads' && method === 'POST') {
      return response(201, { url: 'https://staging.shareittoo.com/uploads/replacement' });
    }
    const token = options.headers?.Authorization?.replace('Bearer ', '');
    const email = tokens.get(token);
    if (path === '/listings/mine') return response(200, { listings: state.get(email) });
    const statusMatch = /^\/listings\/([^/]+)\/status$/u.exec(path);
    if (method === 'PATCH' && statusMatch) {
      const body = JSON.parse(options.body);
      state.set(email, state.get(email).map((entry) => entry.id === statusMatch[1]
        ? { ...entry, status: body.status, isActive: body.status === 'active' } : entry));
      return response(200, {});
    }
    const listingMatch = /^\/listings\/([^/]+)$/u.exec(path);
    if (method === 'PUT' && listingMatch) {
      if (listingMatch[1] === failRenameFor) return response(500, { error: 'injected' });
      const body = JSON.parse(options.body);
      state.set(email, state.get(email).map((entry) => entry.id === listingMatch[1] ? body : entry));
      return response(200, { listing: body });
    }
    throw new Error(`Unexpected ${method} ${path}`);
  };
  return { calls, fetchImpl };
}

test('cleans every synthetic owner while preserving recursively referenced accepted bookings', async () => {
  const data = fixture();
  const state = initialState();
  const { calls, fetchImpl } = api(state);
  const result = await cleanStagingStoreFeed({
    vaultFile: data.vaultFile,
    vaultRoot: data.root,
    fetchImpl,
    placeholderSha256: createHash('sha256').update('placeholder').digest('hex'),
  });
  assert.deepEqual(result, {
    status: 'staging-store-feed-clean',
    privateVaultsChecked: 3,
    syntheticOwnersChecked: 2,
    skippedHistoricalOwners: 1,
    pausedTechnicalListings: 2,
    renamedProtectedListings: 2,
    replacedProtectedPlaceholderPhotos: 1,
    curatedActiveListings: 4,
    protectedActiveBookings: 2,
    publicTechnicalListingsRemaining: 0,
    protectedBookingsPreserved: true,
    productionChanged: false,
    listingDeleted: false,
    paymentEndpointCalled: false,
    containsSecrets: false,
    containsEmailAddresses: false,
    containsListingIdentifiers: false,
  });
  assert.equal([...state.values()].flat().filter((entry) => entry.status === 'paused').length, 2);
  assert.equal([...state.values()].flat().some((entry) => /^SIT Rollenprüfung\b/u.test(entry.title) && entry.status === 'active'), false);
  const neutralized = state.get('one@example.invalid').find(({ id }) => id === 'protected-one');
  assert.equal(neutralized.description,
    'Kompakte Systemkamera mit Objektiv, Akku, Ladegerät und gepolsterter Tragetasche.');
  assert.equal(neutralized.categoryId, 'electronics');
  assert.deepEqual(neutralized.tags, ['kamera', 'foto']);
  assert.equal(state.get('two@example.invalid').find(({ id }) => id === 'protected-two').photos[0],
    'https://staging.shareittoo.com/uploads/genuine');
  assert.equal(calls.some(({ method }) => method === 'DELETE'), false);
});

test('rolls back earlier mutations when a later owner mutation fails', async () => {
  const data = fixture();
  const state = initialState();
  const original = structuredClone([...state.entries()]);
  const { fetchImpl } = api(state, { failRenameFor: 'protected-two' });
  await assert.rejects(cleanStagingStoreFeed({
    vaultFile: data.vaultFile, vaultRoot: data.root, fetchImpl,
  }), /HTTP 500/);
  assert.deepEqual([...state.entries()], original);
});

test('fails closed when an accepted protected listing is inaccessible', async () => {
  const data = fixture();
  const state = initialState();
  state.set('two@example.invalid', state.get('two@example.invalid').filter(({ id }) => id !== 'protected-two'));
  const { fetchImpl } = api(state);
  await assert.rejects(cleanStagingStoreFeed({
    vaultFile: data.vaultFile, vaultRoot: data.root, fetchImpl,
  }), /no accessible owner listing/);
});
