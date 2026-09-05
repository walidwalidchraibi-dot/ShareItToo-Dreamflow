import assert from 'node:assert/strict';
import test from 'node:test';

import {
  runAndroidSearchSavedLifecycle,
} from '../../tool/diagnose_android_search_saved_lifecycle.mjs';

const candidate = Object.freeze({
  applicationId: 'com.shareittoo.app',
  versionName: '1.0.0',
  buildNumber: '2026090506',
  commit: 'd350e3e26f03ec52eac1a86c1cf400148dfd50b1',
  releaseChannel: 'internal',
  apiBaseUrl: 'https://staging.shareittoo.com/api/v1',
  android: { apkSha256: '1'.repeat(64) },
});

function passingOperations(calls) {
  return {
    prepare: async () => {
      calls.push('prepare');
      return { vaultFile: '/private/accounts.json' };
    },
    activate: async () => {
      calls.push('activate');
      return { status: 'isolated-product-journey-fixture-active' };
    },
    searchOpenAndSave: async () => {
      calls.push('search-open-save');
      return { status: 'pixel-renter-search-filter-open-save-passed' };
    },
    verifyRestartPersistence: async () => {
      calls.push('restart-persistence');
      return { status: 'pixel-renter-saved-item-present-stably' };
    },
    verifyOtherPrincipalIsolation: async () => {
      calls.push('owner-isolation');
      return { status: 'pixel-owner-saved-item-absent-stably' };
    },
    verifyRenterRestored: async () => {
      calls.push('renter-restored');
      return { status: 'pixel-renter-saved-item-present-stably' };
    },
    removeSaved: async () => {
      calls.push('remove');
      return { status: 'pixel-renter-exact-saved-item-removed' };
    },
    verifyRemoved: async () => {
      calls.push('verify-removed');
      return { status: 'pixel-renter-saved-item-absent-stably' };
    },
    retire: async () => {
      calls.push('retire');
      return { status: 'email-verified-two-role-product-journey-retired' };
    },
    restoreOwner: async () => {
      calls.push('restore-owner');
      return true;
    },
  };
}

test('closes exact Pixel search, saved-state persistence and account isolation', async () => {
  const calls = [];
  const result = await runAndroidSearchSavedLifecycle({
    candidate,
    deviceSummary: { model: 'Pixel 7 Pro', physical: true },
    operations: passingOperations(calls),
    capturedAt: '2026-09-05T20:00:00.000Z',
  });
  assert.equal(result.status, 'passed-pixel-search-saved-lifecycle');
  assert.deepEqual(calls, [
    'prepare',
    'activate',
    'search-open-save',
    'restart-persistence',
    'owner-isolation',
    'renter-restored',
    'remove',
    'verify-removed',
    'retire',
    'restore-owner',
  ]);
  assert.equal(result.tests.processRestartPersistence, 'passed-three-stable-settled-observations');
  assert.equal(result.tests.accountIsolation, 'passed-other-principal-three-stable-settled-observations');
  assert.equal(result.boundaries.unrelatedSavedItemsChanged, false);
  assert.equal(result.boundaries.bookingCreated, false);
  assert.equal(result.boundaries.containsSecrets, false);
  assert.equal(JSON.stringify(result).includes('/private/'), false);
});

test('retires the listing and restores the owner after a saved-state failure', async () => {
  const calls = [];
  const operations = passingOperations(calls);
  operations.verifyOtherPrincipalIsolation = async () => {
    calls.push('owner-isolation');
    throw new Error('Owner isolation did not settle safely.');
  };
  await assert.rejects(
    () => runAndroidSearchSavedLifecycle({
      candidate,
      deviceSummary: { model: 'Pixel 7 Pro', physical: true },
      operations,
    }),
    /did not settle safely/u,
  );
  assert.deepEqual(calls.slice(-2), ['retire', 'restore-owner']);
});
test('rejects an inexact lifecycle outcome and still cleans up', async () => {
  const calls = [];
  const operations = passingOperations(calls);
  operations.removeSaved = async () => {
    calls.push('remove');
    return { status: 'ambiguous' };
  };
  await assert.rejects(
    () => runAndroidSearchSavedLifecycle({
      candidate,
      deviceSummary: { model: 'Pixel 7 Pro', physical: true },
      operations,
    }),
    /did not close exactly/u,
  );
  assert.deepEqual(calls.slice(-2), ['retire', 'restore-owner']);
});
