import assert from 'node:assert/strict';
import test from 'node:test';

import {
  bothExactSearchListingCardsVisible,
  exactMessageListingVisible,
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

test('recognizes the exact cancelled-booking chat semantics label', () => {
  const title = 'SIT Rollenprüfung n22-safe-run';
  assert.equal(exactMessageListingVisible(`<node content-desc="· ${title}"/>`, title), true);
  assert.equal(exactMessageListingVisible(`<node content-desc="${title}"/>`, title), true);
  assert.equal(exactMessageListingVisible('<node content-desc="Andere Anzeige"/>', title), false);
});

test('recognizes both exact listings when the companion semantics wrap', () => {
  const target = 'SIT Meldung n22-safe-run';
  const companion = 'SIT Sichtbarkeit n22-safe-run';
  const hierarchy = [
    `<node content-desc="Anzeige öffnen: ${target}"/>`,
    `<node content-desc="Unter Gemerkt speichern: ${target}"/>`,
    '<node content-desc="Anzeige öffnen: SIT Sichtbarkeit&#10;n22-safe-run"/>',
    '<node content-desc="Unter Gemerkt speichern: SIT Sichtbarkeit&#10;n22-safe-run"/>',
  ].join('');
  assert.equal(bothExactSearchListingCardsVisible(hierarchy, target, companion), true);
  assert.equal(bothExactSearchListingCardsVisible(hierarchy, target, 'Andere Anzeige'), false);
});

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
