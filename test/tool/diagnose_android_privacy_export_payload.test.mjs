import assert from 'node:assert/strict';
import test from 'node:test';

import {
  privacyExportSinkJava,
  privacyExportSinkManifest,
  privacyExportPasswordField,
  privacyExportPasswordDialogVisible,
  parsePrivacyExportSinkReceipt,
  privacyExportSinkFileSize,
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

function androidNode({
  text = '',
  contentDescription = '',
  className = 'android.view.View',
  enabled = 'true',
  clickable = 'false',
  focusable = 'false',
  password = 'false',
  hint = '',
  bounds = '[0,0][100,100]',
} = {}) {
  return `<node text="${text}" content-desc="${contentDescription}" class="${className}"`
    + ` enabled="${enabled}" clickable="${clickable}" focusable="${focusable}"`
    + ` password="${password}" hint="${hint}" bounds="${bounds}" />`;
}

function passwordField(overrides = {}) {
  return androidNode({
    className: 'android.widget.EditText',
    enabled: 'true',
    clickable: 'true',
    focusable: 'true',
    password: 'true',
    hint: 'Aktuelles Passwort',
    bounds: '[190,1005][1250,1153]',
    ...overrides,
  });
}

test('password dialog recognition binds to exactly one protected editable field', () => {
  const realPixelShape = `<hierarchy>${androidNode({ text: 'Datenexport bestätigen' })}`
    + `${passwordField()}</hierarchy>`;
  assert.equal(privacyExportPasswordDialogVisible(realPixelShape), true);
  assert.match(privacyExportPasswordField(realPixelShape), /android\.widget\.EditText/u);
  assert.equal(privacyExportPasswordDialogVisible(
    `<hierarchy>${androidNode({ text: 'Datenexport bestätigen' })}</hierarchy>`,
  ), false);
  assert.equal(privacyExportPasswordDialogVisible(
    `<hierarchy>${androidNode({ text: 'Datenexport bestätigen' })}`
      + `${androidNode({ text: 'Aktuelles Passwort' })}</hierarchy>`,
  ), false);
  for (const unsafeField of [
    passwordField({ enabled: 'false' }),
    passwordField({ clickable: 'false' }),
    passwordField({ focusable: 'false' }),
    passwordField({ password: 'false' }),
  ]) {
    assert.equal(privacyExportPasswordDialogVisible(
      `<hierarchy>${androidNode({ text: 'Datenexport bestätigen' })}${unsafeField}</hierarchy>`,
    ), false);
  }
  assert.equal(privacyExportPasswordDialogVisible(
    `<hierarchy>${androidNode({ text: 'Datenexport bestätigen' })}`
      + `${passwordField()}${passwordField({ bounds: '[190,1200][1250,1348]' })}</hierarchy>`,
  ), false);
});

test('temporary Android sink has no network or external-storage capability', () => {
  const result = validatePrivacyExportSinkSources();
  assert.equal(result.internetPermission, false);
  assert.equal(result.externalStoragePermission, false);
  assert.equal(result.privateFileOnly, true);
  assert.doesNotMatch(privacyExportSinkManifest, /uses-permission/u);
  assert.doesNotMatch(privacyExportSinkJava, /https?:|Socket|URLConnection|HttpClient|WebView/u);
});

test('temporary sink requires an exact bounded file size before reading bytes', () => {
  assert.equal(privacyExportSinkFileSize('196\n', 'receipt.json'), 196);
  assert.equal(
    privacyExportSinkFileSize(String(32 * 1024 * 1024), 'shareittoo-data-export.json'),
    32 * 1024 * 1024,
  );
  for (const missingOrUnsafe of ['', '0', 'not found', '-1', '4097']) {
    assert.throws(
      () => privacyExportSinkFileSize(missingOrUnsafe, 'receipt.json'),
      /unavailable|invalid byte length/u,
    );
  }
  assert.throws(
    () => privacyExportSinkFileSize('1', '../receipt.json'),
    /not allowlisted/u,
  );
});

test('temporary sink receipt is exact and bounded for chooser or direct delivery', () => {
  const receipt = Buffer.from(JSON.stringify({
    status: 'received',
    bytes: 1234,
    sha256: 'a'.repeat(64),
  }));
  assert.deepEqual(parsePrivacyExportSinkReceipt(receipt), {
    status: 'received',
    bytes: 1234,
    sha256: 'a'.repeat(64),
  });
  for (const invalid of [
    Buffer.from('not-json'),
    Buffer.from(JSON.stringify({ status: 'received', bytes: 0, sha256: 'a'.repeat(64) })),
    Buffer.from(JSON.stringify({ status: 'received', bytes: 1, sha256: 'invalid' })),
    Buffer.from(JSON.stringify({
      status: 'received', bytes: 1, sha256: 'a'.repeat(64), extra: true,
    })),
  ]) {
    assert.throws(() => parsePrivacyExportSinkReceipt(invalid), /receipt is invalid/u);
  }
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
