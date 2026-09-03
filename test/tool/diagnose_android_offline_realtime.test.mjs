import assert from 'node:assert/strict';
import test from 'node:test';

import {
  isExpectedForegroundPushPopup,
  telephonyDataDisconnected,
  visibleMessageOccurrenceCount,
} from '../../tool/diagnose_android_offline_realtime.mjs';

test('recognizes only the privacy-preserving V5.2 foreground popup', () => {
  const hierarchy = [
    '<node content-desc="Benachrichtigung: Neue ShareItToo-Aktualisierung. In der App ansehen." />',
    '<node content-desc="Öffnen" />',
  ].join('');

  assert.equal(isExpectedForegroundPushPopup(hierarchy), true);
  assert.equal(
    isExpectedForegroundPushPopup(
      '<node content-desc="Benachrichtigung: Neue Nachricht. Eine Nachricht ist da." />'
        + '<node content-desc="Öffnen" />',
    ),
    false,
  );
  assert.equal(
    isExpectedForegroundPushPopup(
      '<node content-desc="Neue ShareItToo-Aktualisierung" />'
        + '<node content-desc="In der App ansehen." />',
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

test('counts a repeated diagnostic message against the pre-send baseline', () => {
  const message = 'Kontrollierte SIT Staging-Pushprüfung (offline).';
  assert.equal(visibleMessageOccurrenceCount(`<node content-desc="${message}" />`, message), 1);
  assert.equal(
    visibleMessageOccurrenceCount(
      `<node content-desc="${message}" /><node content-desc="${message}" />`,
      message,
    ),
    2,
  );
  assert.equal(visibleMessageOccurrenceCount('<node content-desc="andere Nachricht" />', message), 0);
});
