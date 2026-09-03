import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';

import {
  googleProfileFingerprint,
  sanitizeGoogleSocialAuthFailure,
} from '../../tool/diagnose_android_google_social_auth.mjs';

const root = resolve(import.meta.dirname, '../..');
const source = readFileSync(
  resolve(root, 'tool/diagnose_android_google_social_auth.mjs'),
  'utf8',
);

test('profile fingerprint requires an authenticated profile', () => {
  const hierarchy = '<hierarchy><node text="Abmelden" /></hierarchy>';
  assert.equal(googleProfileFingerprint(hierarchy).length, 64);
  assert.throws(
    () => googleProfileFingerprint('<hierarchy />'),
    /Authenticated profile hierarchy is unavailable/u,
  );
});

test('diagnostic errors never expose private account details', () => {
  assert.equal(
    sanitizeGoogleSocialAuthFailure(new Error('account@example.invalid')),
    'safe diagnostic reason unavailable',
  );
  assert.equal(
    sanitizeGoogleSocialAuthFailure(new Error('The sanitized action is unavailable.')),
    'The sanitized action is unavailable.',
  );
});

test('real Google diagnostic is exact-account and restoration scoped', () => {
  for (const marker of [
    'validateCurrentHeadAndroidReleaseArchive',
    'verifyCurrentHeadAndroidInstalledCandidate',
    'exactPrivateGoogleAccountSelected: true',
    'sameStagingProfileAcrossAllThreeObservations: true',
    'duplicateAccountObserved: false',
    'protectedSyntheticOwnerRestored: true',
    'accountCreationVersusExistingLinkage: \'not-asserted\'',
    'containsEmailAddress: false',
    'containsPrivateFilesystemPaths: false',
  ]) assert.match(source, new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/gu, '\\$&'), 'u'));
  assert.doesNotMatch(source, /console\.log\(.*mailbox|JSON\.stringify\(.*mailbox/gu);
  assert.doesNotMatch(source, /clear data|pm clear|uninstall/gu);
});
