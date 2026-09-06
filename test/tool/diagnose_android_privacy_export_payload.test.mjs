import assert from 'node:assert/strict';
import test from 'node:test';

import {
  privacyExportSinkJava,
  privacyExportSinkManifest,
  validatePrivacyExportPayload,
  validatePrivacyExportSinkSources,
} from '../../tool/diagnose_android_privacy_export_payload.mjs';

function payload(overrides = {}) {
  return Buffer.from(JSON.stringify({
    schemaVersion: '1.0',
    accountId: 'owner-id',
    generatedAt: '2026-09-06T18:00:00.000Z',
    data: { profile: { email: 'owner@example.invalid' } },
    localDevice: {
      accountProfile: { accountId: 'owner-id' },
      savedItems: { accountId: 'owner-id' },
      ownedListings: { accountId: 'owner-id' },
      reviews: { accountId: 'owner-id' },
      operationalRecords: { accountId: 'owner-id' },
      safetyPrivacy: { accountId: 'owner-id' },
    },
    ...overrides,
  }));
}

const identities = Object.freeze({
  ownerUserId: 'owner-id',
  ownerEmail: 'owner@example.invalid',
  foreignUserId: 'renter-id',
  foreignEmail: 'renter@example.invalid',
});

test('temporary Android sink has no network or external-storage capability', () => {
  const result = validatePrivacyExportSinkSources();
  assert.equal(result.internetPermission, false);
  assert.equal(result.externalStoragePermission, false);
  assert.equal(result.privateFileOnly, true);
  assert.doesNotMatch(privacyExportSinkManifest, /uses-permission/u);
  assert.doesNotMatch(privacyExportSinkJava, /https?:|Socket|URLConnection|HttpClient|WebView/u);
});

test('accepts an exact owner-bound export with all six local sections', () => {
  const result = validatePrivacyExportPayload({ bytes: payload(), ...identities });
  assert.equal(result.exactOwnerBound, true);
  assert.equal(result.foreignIdentityAbsent, true);
  assert.deepEqual(result.localSections, [
    'accountProfile',
    'operationalRecords',
    'ownedListings',
    'reviews',
    'safetyPrivacy',
    'savedItems',
  ]);
});

test('rejects a foreign root principal or foreign identity anywhere', () => {
  assert.throws(
    () => validatePrivacyExportPayload({
      bytes: payload({ accountId: 'renter-id' }),
      ...identities,
    }),
    /root contract or exact owner binding/u,
  );
  assert.throws(
    () => validatePrivacyExportPayload({
      bytes: payload({
        data: {
          profile: { email: 'owner@example.invalid' },
          note: 'renter@example.invalid',
        },
      }),
      ...identities,
    }),
    /foreign test principal/u,
  );
});

test('rejects missing sections, cross-owner local sections and credential keys', () => {
  assert.throws(
    () => validatePrivacyExportPayload({
      bytes: payload({ localDevice: { accountProfile: { accountId: 'owner-id' } } }),
      ...identities,
    }),
    /exact six local sections/u,
  );
  const wrongSection = JSON.parse(payload().toString('utf8'));
  wrongSection.localDevice.reviews.accountId = 'renter-id';
  assert.throws(
    () => validatePrivacyExportPayload({ bytes: Buffer.from(JSON.stringify(wrongSection)), ...identities }),
    /belongs to another principal/u,
  );
  assert.throws(
    () => validatePrivacyExportPayload({
      bytes: payload({ data: { email: 'owner@example.invalid', accessToken: 'forbidden' } }),
      ...identities,
    }),
    /credential- or session-shaped key/u,
  );
});

test('rejects invalid, empty and oversized export bytes', () => {
  assert.throws(
    () => validatePrivacyExportPayload({ bytes: Buffer.alloc(0), ...identities }),
    /invalid byte length/u,
  );
  assert.throws(
    () => validatePrivacyExportPayload({ bytes: Buffer.from('not-json'), ...identities }),
    /not valid JSON/u,
  );
  assert.throws(
    () => validatePrivacyExportPayload({
      bytes: payload({ generatedAt: 'not-a-timestamp' }),
      ...identities,
    }),
    /root contract or exact owner binding/u,
  );
  assert.throws(
    () => validatePrivacyExportPayload({
      bytes: Buffer.alloc((32 * 1024 * 1024) + 1),
      ...identities,
    }),
    /invalid byte length/u,
  );
});
