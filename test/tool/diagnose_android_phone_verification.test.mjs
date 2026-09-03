import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';

import {
  inspectStagingPhoneProvider,
  normalizePrivatePhoneInput,
  sanitizePhoneVerificationFailure,
  validateFrozenCandidateMobileCompatibility,
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

test('frozen candidate accepts only non-mobile post-build changes', () => {
  assert.deepEqual(
    validateFrozenCandidateMobileCompatibility({
      candidateIsAncestor: true,
      changedPaths: [
        'backend/src/config.js',
        'docs/current_state.md',
        'tool/diagnose_android_phone_verification.mjs',
        'test/tool/diagnose_android_phone_verification.test.mjs',
        'store/privacy-disclosures.json',
        'store/retention-deletion-readiness.json',
      ],
    }),
    {
      candidateIsAncestor: true,
      changedPathCount: 6,
      mobileSourceChanged: false,
    },
  );
  assert.throws(
    () => validateFrozenCandidateMobileCompatibility({
      candidateIsAncestor: true,
      changedPaths: ['lib/services/auth_service.dart'],
    }),
    /Mobile source changed/u,
  );
  assert.throws(
    () => validateFrozenCandidateMobileCompatibility({
      candidateIsAncestor: false,
      changedPaths: [],
    }),
    /not an ancestor/u,
  );
});

function jsonResponse(status, value = null) {
  return {
    status,
    json: async () => value,
  };
}

test('provider preflight reports disabled and revokes its exact diagnostic session', async () => {
  const calls = [];
  const result = await inspectStagingPhoneProvider(async (url, options = {}) => {
    calls.push({ url, options });
    if (url.endsWith('/auth/login')) {
      return jsonResponse(200, {
        accessToken: 'a'.repeat(24),
        refreshToken: 'r'.repeat(24),
      });
    }
    if (url.endsWith('/auth/phone-verification/status')) {
      return jsonResponse(200, { available: false, provider: null });
    }
    if (url.endsWith('/auth/logout')) return jsonResponse(204);
    throw new Error('unexpected request');
  }, { email: 'private-at-invalid', password: 'not-printed' });

  assert.deepEqual(result, {
    available: false,
    provider: null,
    diagnosticSessionRevoked: true,
  });
  assert.equal(calls.length, 3);
  assert.match(calls[2].options.body, /refreshToken/u);
});

test('provider preflight recognizes only exact enabled state and always cleans up', async () => {
  const calls = [];
  const enabled = await inspectStagingPhoneProvider(async (url) => {
    calls.push(url);
    if (url.endsWith('/auth/login')) {
      return jsonResponse(200, {
        accessToken: 'a'.repeat(24),
        refreshToken: 'r'.repeat(24),
      });
    }
    if (url.endsWith('/auth/phone-verification/status')) {
      return jsonResponse(200, { available: true, provider: 'firebase-phone' });
    }
    return jsonResponse(204);
  }, { email: 'private-at-invalid', password: 'not-printed' });
  assert.equal(enabled.available, true);
  assert.equal(enabled.diagnosticSessionRevoked, true);
  assert.equal(calls.at(-1).endsWith('/auth/logout'), true);

  const ambiguousCalls = [];
  await assert.rejects(
    inspectStagingPhoneProvider(async (url) => {
      ambiguousCalls.push(url);
      if (url.endsWith('/auth/login')) {
        return jsonResponse(200, {
          accessToken: 'a'.repeat(24),
          refreshToken: 'r'.repeat(24),
        });
      }
      if (url.endsWith('/auth/phone-verification/status')) {
        return jsonResponse(200, { available: true, provider: null });
      }
      return jsonResponse(204);
    }, { email: 'private-at-invalid', password: 'not-printed' }),
    /status is ambiguous/u,
  );
  assert.equal(ambiguousCalls.at(-1).endsWith('/auth/logout'), true);
});

test('provider preflight fails closed when its diagnostic session cannot be revoked', async () => {
  await assert.rejects(
    inspectStagingPhoneProvider(async (url) => {
      if (url.endsWith('/auth/login')) {
        return jsonResponse(200, {
          accessToken: 'a'.repeat(24),
          refreshToken: 'r'.repeat(24),
        });
      }
      if (url.endsWith('/auth/phone-verification/status')) {
        return jsonResponse(200, { available: false, provider: null });
      }
      return jsonResponse(503);
    }, { email: 'private-at-invalid', password: 'not-printed' }),
    /session cleanup failed/u,
  );
});

test('N24 is explicit-artifact bound and never reads or stores an SMS code', () => {
  for (const marker of [
    'validatePrivateAndroidReleaseArchive',
    'SIT_N24_CANDIDATE_DIRECTORY',
    "phase === 'preflight'",
    'diagnosticSessionRevoked',
    'verifyCurrentHeadAndroidInstalledCandidate',
    "provider: 'firebase-phone'",
    "status = 'awaiting-owner-sms-code'",
    "status = 'passed-valid-code-and-cold-restart'",
    'containsPhoneNumber: false',
    'containsSmsCode: false',
    'protectedSyntheticOwnerRetained: true',
  ]) assert.match(source, new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/gu, '\\$&'), 'u'));
  assert.doesNotMatch(source, /validateCurrentHeadAndroidReleaseArchive/gu);
  assert.doesNotMatch(source, /content query --uri|sms inbox|READ_SMS|RECEIVE_SMS/giu);
  assert.doesNotMatch(source, /pm clear|uninstall|clear data/giu);
});
