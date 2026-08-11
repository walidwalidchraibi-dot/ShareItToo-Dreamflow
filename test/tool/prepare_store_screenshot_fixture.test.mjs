import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { chmodSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import test from 'node:test';

import {
  prepareStoreScreenshotFixture,
  storeScreenshotListings,
} from '../../tool/prepare_store_screenshot_fixture.mjs';

function privateVault() {
  const root = mkdtempSync(resolve(tmpdir(), 'sit-store-screenshot-'));
  chmodSync(root, 0o700);
  const vaultFile = resolve(root, 'accounts.json');
  const password = `Aa9!${crypto.randomBytes(24).toString('base64url')}`;
  writeFileSync(vaultFile, `${JSON.stringify({
    schemaVersion: 1,
    kind: 'sit-staging-synthetic-account-vault',
    runId: 'store-screenshot-test',
    status: 'fixture-verified-ready-for-login',
    apiBaseUrl: 'https://staging.shareittoo.com/api/v1',
    stripeLivemode: false,
    accounts: [
      { role: 'owner', email: 'owner@example.invalid', password },
      { role: 'renter', email: 'renter@example.invalid', password },
    ],
  }, null, 2)}\n`, { mode: 0o600 });
  chmodSync(vaultFile, 0o600);
  return vaultFile;
}

function response(status, value) {
  return new Response(value === null ? '' : JSON.stringify(value), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

test('creates four truthful Staging listings without touching payments or production', async () => {
  const calls = [];
  const createdPayloads = [];
  let uploadNumber = 0;
  const result = await prepareStoreScreenshotFixture({
    vaultFile: privateVault(),
    fetchImpl: async (url, options = {}) => {
      const parsed = new URL(url);
      const path = parsed.pathname.replace('/api/v1', '');
      calls.push({ origin: parsed.origin, path, method: options.method ?? 'GET' });
      if (path === '/auth/login') {
        return response(200, { accessToken: `synthetic-token-${'x'.repeat(40)}` });
      }
      if (path === '/listings/mine') return response(200, { listings: [] });
      if (path === '/uploads') {
        uploadNumber += 1;
        return response(201, {
          url: `https://staging.shareittoo.com/api/v1/uploads/store-${uploadNumber}.webp`,
        });
      }
      if (path === '/listings') {
        const body = JSON.parse(options.body);
        createdPayloads.push(body);
        return response(201, { listing: { id: body.id } });
      }
      if (path.endsWith('/availability')) return response(200, { availability: {} });
      throw new Error(`Unexpected path ${path}`);
    },
  });

  assert.deepEqual(result, {
    status: 'store-screenshot-fixture-ready',
    listingCount: 4,
    createdCount: 4,
    reusedCount: 0,
    target: 'staging-only',
    productionChanged: false,
    paymentEndpointCalled: false,
    containsSecrets: false,
    containsEmailAddresses: false,
    containsTokens: false,
    containsFixtureIdentifiers: false,
  });
  assert.equal(createdPayloads.length, 4);
  assert.deepEqual(
    createdPayloads.map(({ title }) => title),
    storeScreenshotListings.map(({ title }) => title),
  );
  assert.equal(createdPayloads.every(({ city }) => city === 'Berlin'), true);
  assert.equal(createdPayloads.every(({ status, isActive }) => status === 'active' && isActive), true);
  assert.equal(calls.every(({ origin }) => origin === 'https://staging.shareittoo.com'), true);
  assert.equal(calls.some(({ path }) => /payment|stripe/i.test(path)), false);
});

test('reuses an exact complete fixture without duplicate uploads or listings', async () => {
  const calls = [];
  const existing = storeScreenshotListings.map(({ id, title }) => ({
    id,
    title,
    status: 'active',
  }));
  const result = await prepareStoreScreenshotFixture({
    vaultFile: privateVault(),
    fetchImpl: async (url) => {
      const path = new URL(url).pathname.replace('/api/v1', '');
      calls.push(path);
      if (path === '/auth/login') {
        return response(200, { accessToken: `synthetic-token-${'x'.repeat(40)}` });
      }
      if (path === '/listings/mine') return response(200, { listings: existing });
      throw new Error(`Unexpected path ${path}`);
    },
  });

  assert.equal(result.createdCount, 0);
  assert.equal(result.reusedCount, 4);
  assert.deepEqual(calls, ['/auth/login', '/listings/mine']);
});

test('fails closed when an expected identifier conflicts with another listing', async () => {
  await assert.rejects(
    prepareStoreScreenshotFixture({
      vaultFile: privateVault(),
      fetchImpl: async (url) => {
        const path = new URL(url).pathname.replace('/api/v1', '');
        if (path === '/auth/login') {
          return response(200, { accessToken: `synthetic-token-${'x'.repeat(40)}` });
        }
        if (path === '/listings/mine') {
          return response(200, {
            listings: [{
              id: storeScreenshotListings[0].id,
              title: 'Conflicting title',
              status: 'active',
            }],
          });
        }
        throw new Error(`Unexpected path ${path}`);
      },
    }),
    /conflicting curated Staging listing/u,
  );
});

test('redacts fixture identifiers from screenshot preparation transport errors', async () => {
  const privateListingId = storeScreenshotListings[0].id;
  await assert.rejects(
    prepareStoreScreenshotFixture({
      vaultFile: privateVault(),
      fetchImpl: async (url, options = {}) => {
        const path = new URL(url).pathname.replace('/api/v1', '');
        if (path === '/auth/login') {
          return response(200, { accessToken: `synthetic-token-${'x'.repeat(40)}` });
        }
        if (path === '/listings/mine') return response(200, { listings: [] });
        if (path === '/uploads') {
          return response(201, { url: 'https://staging.shareittoo.com/api/v1/uploads/store.webp' });
        }
        if (path === '/listings') {
          const body = JSON.parse(options.body);
          return response(201, { listing: { id: body.id } });
        }
        if (path === `/listings/${privateListingId}/availability`) {
          return response(409, { error: 'fixture-conflict' });
        }
        throw new Error(`Unexpected path ${path}`);
      },
    }),
    (error) => {
      assert.match(error.message, /Staging PUT request failed with HTTP 409/);
      assert.equal(error.message.includes(privateListingId), false);
      return true;
    },
  );
});
