import assert from 'node:assert/strict';
import test from 'node:test';

process.env.DATABASE_URL ??= 'postgres://example:example@localhost:5432/example';
process.env.JWT_SECRET ??= 'test-secret-that-is-longer-than-thirty-two-characters';
process.env.MAIL_TRANSPORT = 'memory';
process.env.PUBLIC_BASE_URL = 'https://shareittoo.com/api/v1';
process.env.APP_PUBLIC_URL = 'https://shareittoo.com';

const accountActions = await import('../src/account_actions.js');
const mailer = await import('../src/mailer.js');
const security = await import('../src/security.js');

test('account action tokens are random and only their hash is stored', async () => {
  const calls = [];
  const client = {
    async query(sql, parameters) {
      calls.push({ sql, parameters });
      return { rows: [], rowCount: 0 };
    },
  };

  const first = await accountActions.createActionToken(client, {
    userId: 'user-1',
    kind: 'verify_email',
  });
  const second = await accountActions.createActionToken(client, {
    userId: 'user-1',
    kind: 'verify_email',
  });

  assert.notEqual(first, second);
  assert.ok(first.length >= 64);
  assert.equal(calls[1].parameters[2], security.hashActionToken(first));
  assert.equal(calls[1].parameters.includes(first), false);
});

test('malformed account tokens are rejected without a database lookup', async () => {
  let queried = false;
  const client = {
    async query() {
      queried = true;
      return { rows: [] };
    },
  };

  const result = await accountActions.lockValidActionToken(client, {
    token: 'too-short',
    kind: 'reset_password',
  });
  assert.equal(result, null);
  assert.equal(queried, false);
});

test('memory mail transport produces a one-time verification link', async () => {
  assert.equal(await mailer.verifyMailer(), 'ok');
  const info = await mailer.sendVerificationEmail({
    email: 'person@example.com',
    displayName: 'Test Person',
    token: 'secret-action-token',
  });
  const message = JSON.parse(info.message);
  assert.equal(message.to[0].address, 'person@example.com');
  assert.match(message.subject, /Bestätige deine E-Mail-Adresse/);
  assert.match(message.html, /secret-action-token/);
  assert.match(message.text, /24 Stunden/);
});

test('memory mail transport protects an email-address change', async () => {
  const verificationInfo = await mailer.sendEmailChangeVerification({
    email: 'new-address@example.com',
    displayName: 'Test Person',
    token: 'secret-email-change-token',
  });
  const verification = JSON.parse(verificationInfo.message);
  assert.equal(verification.to[0].address, 'new-address@example.com');
  assert.match(verification.subject, /neue ShareItToo-E-Mail-Adresse/);
  assert.match(verification.html, /secret-email-change-token/);
  assert.match(verification.text, /24 Stunden/);

  const alertInfo = await mailer.sendEmailChangeAlert({
    email: 'old-address@example.com',
    displayName: 'Test Person',
  });
  const alert = JSON.parse(alertInfo.message);
  assert.equal(alert.to[0].address, 'old-address@example.com');
  assert.match(alert.subject, /Änderung/);
  assert.doesNotMatch(alert.text, /secret-email-change-token/);
});

test('memory mail transport produces a one-time account deletion link', async () => {
  const info = await mailer.sendAccountDeletionEmail({
    email: 'person@example.com',
    displayName: 'Test Person',
    token: 'secret-deletion-token',
  });
  const message = JSON.parse(info.message);
  assert.equal(message.to[0].address, 'person@example.com');
  assert.match(message.subject, /Löschung/);
  assert.match(message.html, /secret-deletion-token/);
  assert.match(message.text, /30 Minuten/);
});

test('account result pages escape untrusted content', () => {
  const page = accountActions.resultPage({
    success: false,
    title: '<script>alert(1)</script>',
    message: '<img src=x onerror=alert(1)>',
  });
  assert.doesNotMatch(page, /<script>/);
  assert.doesNotMatch(page, /<img/);
  assert.match(page, /&lt;script&gt;/);
});
