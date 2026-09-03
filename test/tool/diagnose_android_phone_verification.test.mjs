import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';

import {
  normalizePrivatePhoneInput,
  sanitizePhoneVerificationFailure,
} from '../../tool/diagnose_android_phone_verification.mjs';

const root = resolve(import.meta.dirname, '../..');
const source = readFileSync(
  resolve(root, 'tool/diagnose_android_phone_verification.mjs'),
  'utf8',
);

test('accepts only a German E.164 phone input', () => {
  assert.equal(normalizePrivatePhoneInput('0049 151 23456789'), '+4915123456789');
  assert.throws(
    () => normalizePrivatePhoneInput('+33123456789'),
    /valid German E.164/u,
  );
});

test('diagnostic failures suppress phone numbers and SMS secrets', () => {
  assert.equal(
    sanitizePhoneVerificationFailure(new Error('failed for +4915123456789')),
    'safe diagnostic reason unavailable',
  );
  assert.equal(
    sanitizePhoneVerificationFailure(new Error('The sanitized action is unavailable.')),
    'The sanitized action is unavailable.',
  );
});

test('N24 is current-candidate bound and never reads or stores an SMS code', () => {
  for (const marker of [
    'validateCurrentHeadAndroidReleaseArchive',
    'verifyCurrentHeadAndroidInstalledCandidate',
    "provider: 'firebase-phone'",
    "status = 'awaiting-owner-sms-code'",
    "status = 'passed-valid-code-and-cold-restart'",
    'containsPhoneNumber: false',
    'containsSmsCode: false',
    'protectedSyntheticOwnerRetained: true',
  ]) assert.match(source, new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/gu, '\\$&'), 'u'));
  assert.doesNotMatch(source, /content query --uri|sms inbox|READ_SMS|RECEIVE_SMS/giu);
  assert.doesNotMatch(source, /pm clear|uninstall|clear data/giu);
});
