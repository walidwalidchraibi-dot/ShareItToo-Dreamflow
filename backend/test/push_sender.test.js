import assert from 'node:assert/strict';
import test from 'node:test';

import { buildFcmMessageForTest } from '../src/push_sender.js';

test('FCM messages preserve safe navigation context with string-only data', () => {
  const message = buildFcmMessageForTest(
    { token: 'device-token' },
    {
      eventKey: 'booking:confirmed:123',
      title: 'Buchung bestätigt',
      body: 'Deine Buchung wurde bestätigt.',
      actionUrl: 'https://staging.shareittoo.com/api/v1/open/booking/123',
      data: {
        entityType: 'booking',
        entityId: 123,
        privateValue: null,
        from: 'reserved',
        'google.internal': 'reserved',
      },
    },
  );

  assert.equal(message.token, 'device-token');
  assert.equal(message.notification.title, 'Buchung bestätigt');
  assert.deepEqual(message.data, {
    eventKey: 'booking:confirmed:123',
    actionUrl: 'https://staging.shareittoo.com/api/v1/open/booking/123',
    entityType: 'booking',
    entityId: '123',
  });
  assert.equal(message.android.priority, 'high');
  assert.equal(message.apns.headers['apns-priority'], '10');
});
