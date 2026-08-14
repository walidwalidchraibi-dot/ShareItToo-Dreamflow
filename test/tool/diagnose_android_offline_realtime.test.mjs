import assert from 'node:assert/strict';
import test from 'node:test';

import {
  isExpectedForegroundPushPopup,
} from '../../tool/diagnose_android_offline_realtime.mjs';

test('recognizes only an in-app foreground popup for the active fixture', () => {
  const fixtureTitle = 'SIT Rollenprüfung offline-safe';
  const hierarchy = [
    '<node content-desc="Benachrichtigung: Neue Nachricht. Eine Nachricht ist da." />',
    '<node content-desc="Öffnen" />',
    `<node content-desc="${fixtureTitle}" />`,
  ].join('');

  assert.equal(isExpectedForegroundPushPopup(hierarchy, fixtureTitle), true);
  assert.equal(
    isExpectedForegroundPushPopup(hierarchy, 'anderer sicherer Test'),
    false,
  );
  assert.equal(
    isExpectedForegroundPushPopup(
      '<node content-desc="Öffnen" /><node content-desc="SIT Rollenprüfung offline-safe" />',
      fixtureTitle,
    ),
    false,
  );
});
