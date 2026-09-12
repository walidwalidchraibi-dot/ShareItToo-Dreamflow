import assert from 'node:assert/strict';
import test from 'node:test';

import {
  runCurrentCandidateReportBlockLifecycle,
} from '../../tool/diagnose_android_current_candidate_report_block.mjs';

const candidate = Object.freeze({
  applicationId: 'com.shareittoo.app',
  versionName: '1.0.0',
  buildNumber: '2026091201',
  commit: '1546812f625b4e8f1e700bf976410097cd45ac2f',
  android: {
    apkSha256: 'a8bfda4c1a0e7302b2528db8edfbe1318e88322023f65588da032220a24badd4',
  },
});

function operations(calls) {
  return {
    exercise: async () => { calls.push('exercise'); return true; },
    cleanup: async () => {
      calls.push('cleanup');
      return {
        status: 'cleanup-server-confirmed-recovery-required',
        exactListingsEnded: 3,
        exactBlockCount: 0,
        retainedModerationReportCount: 1,
        exactRoleSessionsRevoked: true,
      };
    },
    restoreOwner: async () => { calls.push('restore-owner'); return true; },
    markRestored: async () => { calls.push('mark-restored'); },
  };
}

test('closes exact-current report, block, unblock and reversible cleanup', async () => {
  const calls = [];
  const result = await runCurrentCandidateReportBlockLifecycle({
    candidate,
    deviceSummary: { model: 'Pixel 7 Pro', physical: true },
    operations: operations(calls),
    capturedAt: '2026-09-12T22:45:00.000Z',
  });
  assert.deepEqual(calls, ['exercise', 'cleanup', 'restore-owner', 'mark-restored']);
  assert.equal(result.status, 'passed-exact-current-pixel-report-block-restored');
  assert.equal(result.pixel.reportAcceptedExactlyOnce, true);
  assert.equal(result.pixel.bothSameOwnerListingsHidden, true);
  assert.equal(result.cleanup.moderationReportRetainedAsAudit, true);
  assert.equal(result.cleanup.recoveryRequired, false);
  assert.equal(result.boundaries.onePlusContacted, false);
  assert.equal(JSON.stringify(result).includes('example.test'), false);
});

test('still cleans up and restores the owner after a physical failure', async () => {
  const calls = [];
  const ops = operations(calls);
  ops.exercise = async () => {
    calls.push('exercise');
    throw new Error('The physical report did not settle.');
  };
  await assert.rejects(
    () => runCurrentCandidateReportBlockLifecycle({
      candidate,
      deviceSummary: { model: 'Pixel 7 Pro', physical: true },
      operations: ops,
    }),
    /did not settle/u,
  );
  assert.deepEqual(calls, ['exercise', 'cleanup', 'restore-owner', 'mark-restored']);
});

test('fails closed for a predecessor candidate before any operation', async () => {
  const calls = [];
  await assert.rejects(
    () => runCurrentCandidateReportBlockLifecycle({
      candidate: { ...candidate, buildNumber: '2026091110' },
      deviceSummary: { model: 'Pixel 7 Pro', physical: true },
      operations: operations(calls),
    }),
    /candidate binding/u,
  );
  assert.deepEqual(calls, []);
});

test('does not accept cleanup that drops the retained moderation audit', async () => {
  const calls = [];
  const ops = operations(calls);
  const baseCleanup = ops.cleanup;
  ops.cleanup = async () => ({
    ...(await baseCleanup()),
    retainedModerationReportCount: 0,
  });
  await assert.rejects(
    () => runCurrentCandidateReportBlockLifecycle({
      candidate,
      deviceSummary: { model: 'Pixel 7 Pro', physical: true },
      operations: ops,
    }),
    /cleanup is incomplete/u,
  );
});
