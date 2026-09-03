import assert from 'node:assert/strict';
import test from 'node:test';

import {
  isExpectedForegroundPushPopup,
  telephonyDataDisconnected,
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

test('treats Android 17 no-service state minus one as disconnected', () => {
  assert.equal(telephonyDataDisconnected(
    'mDataConnectionState=-1\nmDataConnectionState=-1',
  ), true);
  assert.equal(telephonyDataDisconnected(
    'mDataConnectionState=-1\nmDataConnectionState=2',
  ), false);
  assert.equal(telephonyDataDisconnected('no telephony data state'), false);
});
