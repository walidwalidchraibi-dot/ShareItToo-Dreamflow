import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { validatePhoneVerificationReadiness } from
  '../../tool/validate_phone_verification_readiness.mjs';

const root = new URL('../../', import.meta.url).pathname;
const canonical = JSON.parse(readFileSync(
  new URL('../../store/phone-verification-readiness.json', import.meta.url),
  'utf8',
));

test('accepts the owner-authorized Firebase console activation while the real-device test remains closed', () => {
  assert.deepEqual(validatePhoneVerificationReadiness({ root }), {
    state: 'firebase-console-activated-staging-test-pending',
    buildNumber: canonical.sourceBuild.buildNumber,
    openGates: 6,
    activationAllowed: false,
  });
});

test('rejects claiming activation before every external gate is evidenced', () => {
  const readiness = structuredClone(canonical);
  readiness.activationAllowed = true;
  assert.throws(
    () => validatePhoneVerificationReadiness({ root, readiness }),
    /external gates must remain fail-closed/,
  );
});

test('rejects removing the observed Firebase phone provider activation', () => {
  const readiness = structuredClone(canonical);
  readiness.consoleEvidence.phoneProviderEnabled = false;
  assert.throws(
    () => validatePhoneVerificationReadiness({ root, readiness }),
    /console evidence is incomplete or unsafe/,
  );
});

test('rejects removing the saved Germany-only SMS region policy', () => {
  const readiness = structuredClone(canonical);
  readiness.consoleEvidence.smsRegionPolicySaved = false;
  assert.throws(
    () => validatePhoneVerificationReadiness({ root, readiness }),
    /console evidence is incomplete or unsafe/,
  );
});

test('rejects a client-side phone verification bypass', () => {
  const current = readFileSync(
    new URL('../../lib/services/auth_service.dart', import.meta.url),
    'utf8',
  );
  assert.throws(
    () => validatePhoneVerificationReadiness({
      root,
      readiness: canonical,
      sourceOverrides: {
        'lib/services/auth_service.dart': `${current}\n// phoneVerified: true`,
      },
    }),
    /must not grant client-side phone verification/,
  );
});

test('rejects a reused source build number after pubspec advances', () => {
  assert.throws(
    () => validatePhoneVerificationReadiness({
      root,
      readiness: canonical,
      sourceOverrides: {
        'pubspec.yaml': `name: lendify\nversion: 1.0.0+${BigInt(canonical.sourceBuild.buildNumber) + 1n}\n`,
      },
    }),
    /not bound to the current source build/,
  );
});

test('rejects phone numbers in readiness evidence', () => {
  const readiness = structuredClone(canonical);
  readiness.note = '+4915212345678';
  assert.throws(
    () => validatePhoneVerificationReadiness({ root, readiness }),
    /account data or a secret/,
  );
});
