import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import test from 'node:test';

process.env.DATABASE_URL ??= 'postgres://localhost/fixture';
process.env.JWT_SECRET ??= crypto.randomBytes(48).toString('base64url');
process.env.PUSH_TRANSPORT = 'disabled';

const { buildFcmMessageForTest } = await import('../src/push_sender.js');

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
  assert.equal(message.android.notification.icon, 'ic_stat_shareittoo_v2');
  assert.equal(message.android.notification.clickAction, 'SIT_NOTIFICATION_CLICK');
  assert.equal(message.apns.headers['apns-priority'], '10');
});
