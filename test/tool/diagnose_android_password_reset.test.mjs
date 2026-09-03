import assert from 'node:assert/strict';
import { chmodSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';

import {
  preparePasswordResetVault,
  transitionPasswordResetLogin,
  transitionPasswordResetRequest,
  verifyOldPasswordRejectedAndFinalize,
} from '../../tool/diagnose_android_password_reset.mjs';
import { createTestTempTracker } from './test_temp_fixtures.mjs';

const tempFixtures = createTestTempTracker();
const source = readFileSync(
  new URL('../../tool/diagnose_android_password_reset.mjs', import.meta.url),
  'utf8',
);

function fixedRandom(size) {
  return Buffer.alloc(size, 8);
}

function sourceAccount(root) {
  const path = resolve(root, 'n20-account.json');
  const syntheticFixturePassword = ['Old', 'Fixture', '08'.repeat(12)].join('');
  writeFileSync(path, `${JSON.stringify({
    schemaVersion: 1,
    kind: 'sit-staging-ui-registration-vault',
    runId: '20260903t080000z-08080808',
    status: 'pixel-ui-registration-login-complete',
    createdAt: '2026-09-03T08:00:00.000Z',
    apiBaseUrl: 'https://staging.shareittoo.com/api/v1',
    stripeLivemode: false,
    containsProductionCredentials: false,
    account: {
      role: 'owner',
      displayName: 'SITUI08080808',
      email: 'owner+sit-reset-owner@example.test',
      password: syntheticFixturePassword,
    },
  }, null, 2)}\n`, { mode: 0o600 });
  chmodSync(path, 0o600);
  return path;
}

test('prepares a distinct owner-only reset vault without exposing credentials', () => {
  const root = tempFixtures.makeSync('sit-password-reset-vault-');
  const result = preparePasswordResetVault({
    accountVaultFile: sourceAccount(root),
    vaultRoot: resolve(root, 'resets'),
    now: new Date('2026-09-03T08:10:00.000Z'),
    random: fixedRandom,
  });
  const vault = JSON.parse(readFileSync(result.vaultFile, 'utf8'));
  assert.equal(result.status, 'prepared-for-pixel-password-reset');
  assert.equal(result.containsEmailAddress, false);
  assert.equal(result.containsCredential, false);
  assert.match(vault.pendingPassword, /^S1tR[A-Za-z0-9_-]{24,}$/u);
  assert.equal(statSync(result.vaultFile).mode & 0o077, 0);
});

test('requires exact old-password rejection before safely moving the new credential', async () => {
  const root = tempFixtures.makeSync('sit-password-reset-finalize-');
  const accountVaultFile = sourceAccount(root);
  const prepared = preparePasswordResetVault({
    accountVaultFile,
    vaultRoot: resolve(root, 'resets'),
    now: new Date('2026-09-03T08:10:00.000Z'),
    random: fixedRandom,
  });
  const pending = JSON.parse(readFileSync(prepared.vaultFile, 'utf8')).pendingPassword;
  transitionPasswordResetRequest({ vaultFile: prepared.vaultFile });
  const result = await verifyOldPasswordRejectedAndFinalize({
    vaultFile: prepared.vaultFile,
    authenticate: async () => ({ status: 401, error: 'invalid_credentials' }),
    occurredAt: new Date('2026-09-03T08:20:00.000Z'),
  });
  const reset = JSON.parse(readFileSync(prepared.vaultFile, 'utf8'));
  const account = JSON.parse(readFileSync(accountVaultFile, 'utf8'));
  assert.equal(result.oldPasswordRejected, true);
  assert.equal(reset.pendingPassword, undefined);
  assert.equal(reset.credentialStoredOnlyInSourceVault, true);
  assert.equal(account.account.password, pending);
  assert.equal(statSync(accountVaultFile).mode & 0o077, 0);
  assert.equal(transitionPasswordResetLogin({ vaultFile: prepared.vaultFile }).status,
    'pixel-password-reset-login-complete');
});

test('rejects ambiguous auth outcomes and preserves both vaults byte-for-byte', async () => {
  for (const result of [
    { status: 200, error: null },
    { status: 401, error: null },
    { status: 408, error: 'invalid_credentials' },
  ]) {
    const root = tempFixtures.makeSync('sit-password-reset-reject-');
    const accountVaultFile = sourceAccount(root);
    const prepared = preparePasswordResetVault({
      accountVaultFile,
      vaultRoot: resolve(root, 'resets'),
      now: new Date('2026-09-03T08:10:00.000Z'),
      random: fixedRandom,
    });
    transitionPasswordResetRequest({ vaultFile: prepared.vaultFile });
    const beforeReset = readFileSync(prepared.vaultFile);
    const beforeAccount = readFileSync(accountVaultFile);
    await assert.rejects(
      verifyOldPasswordRejectedAndFinalize({
        vaultFile: prepared.vaultFile,
        authenticate: async () => result,
      }),
      /exact structured Staging contract/u,
    );
    assert.deepEqual(readFileSync(prepared.vaultFile), beforeReset);
    assert.deepEqual(readFileSync(accountVaultFile), beforeAccount);
  }
});

test('wires exact candidate, Pixel UI request, single-use confirmation and cold start', () => {
  for (const marker of [
    'validatePrivateAndroidReleaseArchive',
    'verifyInstalledCandidate',
    'ensureAndroidGuestSession',
    'restoreSyntheticSession',
    'Passwort vergessen?',
    'Passwort zurücksetzen',
    'Link senden',
    'E-Mail gesendet',
    'invalid_credentials',
    'new-password-pixel-login-cold-start-passed',
  ]) assert.match(source, new RegExp(marker.replace(/[?]/g, '\\?'), 'u'));
  assert.doesNotMatch(source, /console\.log\([^\n]*(email|password|token)/u);
});
