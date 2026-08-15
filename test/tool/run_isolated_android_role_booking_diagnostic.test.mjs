import assert from 'node:assert/strict';
import { chmodSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import test from 'node:test';

import { runIsolatedAndroidRoleBookingDiagnostic } from
  '../../tool/run_isolated_android_role_booking_diagnostic.mjs';

function syntheticCredential(role) {
  return ['private', role, 'fixture'].join('-');
}

function fixture() {
  const root = mkdtempSync(resolve(tmpdir(), 'sit-protected-role-booking-'));
  chmodSync(root, 0o700);
  const vaultFile = resolve(root, 'accounts.json');
  writeFileSync(vaultFile, `${JSON.stringify({
    schemaVersion: 1,
    kind: 'sit-staging-synthetic-account-vault',
    runId: 'protected-review-fixture',
    status: 'synthetic-booking-active',
    apiBaseUrl: 'https://staging.shareittoo.com/api/v1',
    stripeLivemode: false,
    accounts: [
      { role: 'owner', email: 'owner@example.invalid', password: syntheticCredential('owner') },
      { role: 'renter', email: 'renter@example.invalid', password: syntheticCredential('renter') },
    ],
    syntheticBooking: {
      workflowStatus: 'accepted',
      paymentMode: 'memory',
      stripeLivemode: false,
      paymentEndpointCalled: false,
    },
  }, null, 2)}\n`, { mode: 0o600 });
  chmodSync(vaultFile, 0o600);
  return vaultFile;
}

test('uses an isolated vault and preserves the active protected review fixture', async () => {
  const vaultFile = fixture();
  const before = readFileSync(vaultFile, 'utf8');
  let observedIsolatedVault = null;
  const result = await runIsolatedAndroidRoleBookingDiagnostic({
    vaultFile,
    runner: async (isolatedVaultFile) => {
      observedIsolatedVault = JSON.parse(readFileSync(isolatedVaultFile, 'utf8'));
      writeFileSync(isolatedVaultFile, `${JSON.stringify({ consumed: true })}\n`, { mode: 0o600 });
      return {
        schemaVersion: 1,
        kind: 'android-synthetic-role-booking-diagnostic',
        status: 'passed-bounded-synthetic-role-booking-diagnostic',
        boundaries: { containsSecrets: false },
      };
    },
    retirementRunner: async ({ vaultFile: isolatedVaultFile }) => {
      const isolated = JSON.parse(readFileSync(isolatedVaultFile, 'utf8'));
      assert.equal(isolated.consumed, true);
      return {
        status: 'synthetic-booking-retired',
        bookingCompleted: true,
        listingPaused: true,
        paymentEndpointCalled: false,
        stripeLivemode: false,
      };
    },
  });

  assert.equal(observedIsolatedVault.syntheticBooking, undefined);
  assert.equal(observedIsolatedVault.accounts.length, 2);
  assert.equal(readFileSync(vaultFile, 'utf8'), before);
  assert.deepEqual(result.isolation, {
    protectedReviewFixtureUnchanged: true,
    temporaryVaultRemovedAfterProbe: true,
    temporaryBookingCompleted: true,
    temporaryListingPaused: true,
    containsReviewCredentials: false,
  });
  assert.equal(JSON.stringify(result).includes(syntheticCredential('owner')), false);
});

test('fails closed when the temporary role-booking fixture is not retired', async () => {
  const vaultFile = fixture();
  await assert.rejects(
    runIsolatedAndroidRoleBookingDiagnostic({
      vaultFile,
      runner: async () => ({
        status: 'passed-bounded-synthetic-role-booking-diagnostic',
      }),
      retirementRunner: async () => ({
        status: 'synthetic-booking-retired',
        bookingCompleted: true,
        listingPaused: false,
        paymentEndpointCalled: false,
        stripeLivemode: false,
      }),
    }),
    /not retired safely/,
  );
});

test('retires a partially created fixture after the child diagnostic fails', async () => {
  const vaultFile = fixture();
  let retired = false;
  await assert.rejects(
    runIsolatedAndroidRoleBookingDiagnostic({
      vaultFile,
      runner: async (isolatedVaultFile) => {
        const isolated = JSON.parse(readFileSync(isolatedVaultFile, 'utf8'));
        isolated.syntheticBooking = {
          workflowStatus: 'requested',
          paymentMode: 'memory',
          stripeLivemode: false,
          paymentEndpointCalled: false,
        };
        writeFileSync(isolatedVaultFile, `${JSON.stringify(isolated, null, 2)}\n`, { mode: 0o600 });
        throw new Error('sanitized child failure');
      },
      retirementRunner: async () => {
        retired = true;
        return {
          status: 'synthetic-booking-retired',
          bookingCompleted: true,
          listingPaused: true,
          paymentEndpointCalled: false,
          stripeLivemode: false,
        };
      },
    }),
    /sanitized child failure/,
  );
  assert.equal(retired, true);
});

test('rejects an unsafe or terminal protected fixture before running', async () => {
  const vaultFile = fixture();
  const vault = JSON.parse(readFileSync(vaultFile, 'utf8'));
  vault.syntheticBooking.workflowStatus = 'completed';
  writeFileSync(vaultFile, `${JSON.stringify(vault, null, 2)}\n`, { mode: 0o600 });
  let called = false;
  await assert.rejects(
    runIsolatedAndroidRoleBookingDiagnostic({
      vaultFile,
      runner: async () => {
        called = true;
      },
    }),
    /must remain active and payment-free/,
  );
  assert.equal(called, false);
});
