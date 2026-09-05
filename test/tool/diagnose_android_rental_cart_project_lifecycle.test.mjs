import assert from 'node:assert/strict';
import test from 'node:test';

import {
  runAndroidRentalCartProjectLifecycle,
  selectableCalendarDayNode,
} from '../../tool/diagnose_android_rental_cart_project_lifecycle.mjs';

const candidate = Object.freeze({
  applicationId: 'com.shareittoo.app',
  versionName: '1.0.0',
  buildNumber: '2026090507',
  commit: '1'.repeat(40),
  releaseChannel: 'internal',
  apiBaseUrl: 'https://staging.shareittoo.com/api/v1',
  android: { apkSha256: '2'.repeat(64) },
});

test('selects only one enabled clickable current calendar day', () => {
  const selectable = '<node class="android.view.View" text="5" content-desc="" '
    + 'enabled="true" clickable="true" bounds="[100,400][200,500]"/>';
  const disabled = '<node class="android.view.View" text="5" content-desc="" '
    + 'enabled="false" clickable="true" bounds="[300,400][400,500]"/>';
  assert.equal(selectableCalendarDayNode(selectable + disabled, 5), selectable);
  assert.equal(selectableCalendarDayNode(selectable + selectable, 5), null);
  assert.equal(selectableCalendarDayNode(selectable, 6), null);
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
    captureBaseline: async () => {
      calls.push('capture-baseline');
      return { status: 'isolated-rental-cart-baseline-captured' };
    },
    addTwice: async () => {
      calls.push('add-twice');
      return { status: 'pixel-renter-identical-cart-intent-submitted-twice' };
    },
    inspectSingleIntent: async () => {
      calls.push('inspect-single');
      return { status: 'isolated-rental-cart-single-intent-server-confirmed' };
    },
    verifyCart: async () => {
      calls.push('verify-cart');
      return { status: 'pixel-renter-cart-intent-present-stably' };
    },
    createAndAssignProject: async () => {
      calls.push('create-assign');
      return { status: 'pixel-renter-project-created-and-assigned' };
    },
    inspectProjectAssignment: async () => {
      calls.push('inspect-assignment');
      return { status: 'isolated-rental-cart-project-server-confirmed' };
    },
    verifyRestartPersistence: async () => {
      calls.push('restart');
      return { status: 'pixel-renter-cart-intent-project-assigned-present-stably' };
    },
    verifyOtherPrincipalIsolation: async () => {
      calls.push('owner-isolation');
      return { status: 'pixel-owner-cart-intent-absent-stably' };
    },
    verifyRenterRestored: async () => {
      calls.push('renter-restored');
      return { status: 'pixel-renter-cart-intent-project-assigned-present-stably' };
    },
    removeIntent: async () => {
      calls.push('remove-intent');
      return { status: 'pixel-renter-exact-cart-intent-removed' };
    },
    verifyRemoved: async () => {
      calls.push('verify-removed');
      return { status: 'pixel-renter-cart-intent-absent-stably' };
    },
    cleanupCart: async () => {
      calls.push('cleanup-cart');
      return { status: 'isolated-rental-cart-baseline-restored' };
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

test('closes duplicate intent, project, persistence, isolation, and cleanup', async () => {
  const calls = [];
  const result = await runAndroidRentalCartProjectLifecycle({
    candidate,
    deviceSummary: { model: 'Pixel 7 Pro', physical: true },
    operations: passingOperations(calls),
    capturedAt: '2026-09-05T22:00:00.000Z',
  });
  assert.equal(result.status, 'passed-pixel-rental-cart-project-lifecycle');
  assert.equal(result.tests.exactServerIntentCount, 1);
  assert.equal(result.tests.unrelatedCartBaselineRestored, true);
  assert.equal(result.boundaries.rentalRequestCreated, false);
  assert.equal(result.boundaries.reservationCreated, false);
  assert.equal(JSON.stringify(result).includes('/private/'), false);
  assert.deepEqual(calls, [
    'prepare',
    'activate',
    'capture-baseline',
    'add-twice',
    'inspect-single',
    'verify-cart',
    'create-assign',
    'inspect-assignment',
    'restart',
    'owner-isolation',
    'renter-restored',
    'remove-intent',
    'verify-removed',
    'cleanup-cart',
    'retire',
    'restore-owner',
  ]);
});

test('restores cart, retires listing, and restores owner after a physical failure', async () => {
  const calls = [];
  const operations = passingOperations(calls);
  operations.verifyOtherPrincipalIsolation = async () => {
    calls.push('owner-isolation');
    throw new Error('Owner cart isolation did not settle safely.');
  };
  await assert.rejects(
    () => runAndroidRentalCartProjectLifecycle({
      candidate,
      deviceSummary: { model: 'Pixel 7 Pro', physical: true },
      operations,
    }),
    /did not settle safely/u,
  );
  assert.deepEqual(calls.slice(-3), ['cleanup-cart', 'retire', 'restore-owner']);
});
