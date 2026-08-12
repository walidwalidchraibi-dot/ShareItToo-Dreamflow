#!/usr/bin/env node

import { createHash, randomBytes } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import {
  chmodSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

function fail(message) {
  throw new Error(message);
}

function nonEmptyString(value, label) {
  if (typeof value !== 'string' || value.trim() === '') fail(`${label} must be a non-empty string.`);
  return value.trim();
}

function sha256(contents) {
  return createHash('sha256').update(contents).digest('hex');
}

function readProtectedVault(vaultFile) {
  const raw = readFileSync(vaultFile);
  const vault = JSON.parse(raw.toString('utf8'));
  if (vault.kind !== 'sit-staging-synthetic-account-vault' ||
      vault.apiBaseUrl !== 'https://staging.shareittoo.com/api/v1' ||
      vault.stripeLivemode !== false ||
      !Array.isArray(vault.accounts) || vault.accounts.length !== 2 ||
      vault.accounts.some((account) => !['owner', 'renter'].includes(account?.role))) {
    fail('The protected review vault is not a safe two-role Staging fixture.');
  }
  const fixture = vault.syntheticBooking;
  if (!fixture || !['accepted', 'active'].includes(fixture.workflowStatus) ||
      fixture.paymentMode !== 'memory' || fixture.stripeLivemode !== false ||
      fixture.paymentEndpointCalled !== false) {
    fail('The protected review fixture must remain active and payment-free during the isolated probe.');
  }
  return { raw, vault };
}

export async function runIsolatedAndroidRoleBookingDiagnostic({
  vaultFile,
  runner,
}) {
  const protectedVaultFile = resolve(nonEmptyString(vaultFile, 'vaultFile'));
  const { raw: originalRaw, vault } = readProtectedVault(protectedVaultFile);
  const originalSha256 = sha256(originalRaw);
  const temporaryDirectory = mkdtempSync(resolve(tmpdir(), 'sit-isolated-role-booking-'));
  chmodSync(temporaryDirectory, 0o700);
  const isolatedVaultFile = resolve(temporaryDirectory, 'accounts.json');
  const isolatedVault = structuredClone(vault);
  delete isolatedVault.syntheticBooking;
  isolatedVault.status = 'fixture-verified-ready-for-login';
  nonEmptyString(vault.runId, 'runId');
  isolatedVault.runId = `role-booking-${randomBytes(8).toString('hex')}`;
  writeFileSync(isolatedVaultFile, `${JSON.stringify(isolatedVault, null, 2)}\n`, { mode: 0o600 });
  chmodSync(isolatedVaultFile, 0o600);

  try {
    const result = await runner(isolatedVaultFile);
    if (sha256(readFileSync(protectedVaultFile)) !== originalSha256) {
      fail('The protected review vault changed during the isolated role-booking diagnostic.');
    }
    if (result?.status !== 'passed-bounded-synthetic-role-booking-diagnostic') {
      fail('The isolated Android role-booking diagnostic did not pass safely.');
    }
    return {
      ...result,
      isolation: {
        protectedReviewFixtureUnchanged: true,
        temporaryVaultRemovedAfterProbe: true,
        containsReviewCredentials: false,
      },
    };
  } finally {
    rmSync(temporaryDirectory, { recursive: true, force: true });
  }
}

function argumentValue(args, flag) {
  const index = args.indexOf(flag);
  return index >= 0 ? args[index + 1] : null;
}

async function run() {
  const args = process.argv.slice(2);
  const vaultFile = argumentValue(args, '--vault-file') ?? fail('--vault-file is required.');
  const adbPath = argumentValue(args, '--adb') ?? 'adb';
  const candidateDirectory = argumentValue(args, '--candidate-dir');
  const diagnosticPath = fileURLToPath(new URL('./diagnose_android_synthetic_role_booking.mjs', import.meta.url));
  const result = await runIsolatedAndroidRoleBookingDiagnostic({
    vaultFile,
    runner: async (isolatedVaultFile) => {
      const childArgs = [
        diagnosticPath,
        '--vault-file', isolatedVaultFile,
        '--adb', adbPath,
      ];
      if (candidateDirectory !== null) childArgs.push('--candidate-dir', candidateDirectory);
      let output;
      try {
        output = execFileSync(process.execPath, childArgs, {
          encoding: 'utf8',
          maxBuffer: 512 * 1024 * 1024,
          stdio: ['ignore', 'pipe', 'pipe'],
        });
      } catch {
        fail('The isolated Android role-booking child diagnostic failed without exposing private state.');
      }
      return JSON.parse(output);
    },
  });
  console.log(JSON.stringify(result, null, 2));
}

if (typeof process !== 'undefined' && process.argv?.[1] &&
    import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    await run();
  } catch (error) {
    console.error(`ERROR: ${error.message}`);
    process.exitCode = 1;
  }
}
