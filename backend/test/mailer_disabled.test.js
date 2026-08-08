import assert from 'node:assert/strict';
import test from 'node:test';

process.env.DATABASE_URL ??= 'postgres://example:example@localhost:5432/example';
process.env.JWT_SECRET ??= 'test-secret-that-is-longer-than-thirty-two-characters';
process.env.MAIL_TRANSPORT = 'disabled';

const mailer = await import('../src/mailer.js');

test('an intentionally disabled mail transport stays disabled after a send attempt', async () => {
  assert.equal(await mailer.verifyMailer(), 'disabled');
  await assert.rejects(
    mailer.sendVerificationEmail({
      email: 'person@example.com',
      displayName: 'Test Person',
      token: 'secret-action-token',
    }),
    (error) => error?.code === 'mail_delivery_failed',
  );
  assert.equal(mailer.getMailerStatus(), 'disabled');
});
