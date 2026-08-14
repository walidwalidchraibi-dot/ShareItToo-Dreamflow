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

test('public compliance pages stay visibly fail-closed before legal approval', () => {
  assert.equal(accountActions.publicComplianceOverview().status, 'draft');
  assert.equal(accountActions.publicComplianceOverview().submissionReady, false);

  const support = accountActions.publicSupportPage();
  assert.match(support, /data-sit-public-page="support"/);
  assert.match(support, /data-sit-compliance-status="draft"/);
  assert.doesNotMatch(support, /mailto:/);

  const privacy = accountActions.publicPrivacyPage();
  assert.match(privacy, /data-sit-public-page="privacy"/);
  assert.match(privacy, /data-sit-compliance-status="draft"/);
  assert.match(privacy, /rechtlicher Endprüfung/);

  const imprint = accountActions.publicImprintPage();
  assert.match(imprint, /data-sit-public-page="imprint"/);
  assert.match(imprint, /data-sit-compliance-status="draft"/);

  const deletion = accountActions.accountDeletionRequestForm({ submitted: false });
  assert.match(deletion, /data-sit-public-page="account-deletion"/);
  assert.match(deletion, /data-sit-compliance-status="operational"/);
});

test('approved public privacy copy covers the evidenced current data flows and deletion limits', () => {
  const privacy = accountActions.publicPrivacyPage({
    compliance: {
      approved: true,
      providerName: 'Example Provider',
      providerAddress: 'Example Address',
      privacyEmail: 'privacy-contact.invalid',
      effectiveDate: '2026-08-12',
    },
  });

  assert.match(privacy, /data-sit-compliance-status="approved"/);
  assert.match(privacy, /Example Provider/);
  assert.match(privacy, /Google Maps Platform/);
  assert.match(privacy, /Firebase Cloud Messaging/);
  assert.match(privacy, /Firebase Crashlytics/);
  assert.match(privacy, /Telefonnummer per SMS bestätigen/);
  assert.match(privacy, /deutsche Rufnummern/);
  assert.match(privacy, /bis zu 180 Tagen/);
  assert.match(privacy, /90 Tage/);
  assert.match(privacy, /keine dauerhafte Hintergrund- oder Live-Ortung/);
  assert.match(privacy, /keine aktivierte Echtgeld-Zahlungsübertragung an Stripe/);
  assert.match(privacy, /keine Ausweisprüfung/);
  assert.match(privacy, /keine Karten- oder Bankdaten/);
  assert.match(privacy, /Empfänger und Dienstleister/);
  assert.match(privacy, /Speicherung, Löschung und Rechte/);
  assert.match(privacy, /innerhalb von 14 Tagen/);
  assert.match(privacy, /shareittoo\.com\/account-deletion/);
  assert.doesNotMatch(privacy, /OpenAI/);
});

test('approved public imprint exposes only the confirmed provider identity', () => {
  const imprint = accountActions.publicImprintPage({
    compliance: {
      approved: true,
      providerName: 'Example Provider',
      providerAddress: 'Example Address',
      supportEmail: 'contact.invalid',
      representative: 'Example Representative',
      contentResponsible: 'Example Responsible',
    },
  });

  assert.match(imprint, /data-sit-compliance-status="approved"/);
  assert.match(imprint, /Example Provider/);
  assert.match(imprint, /Example Representative/);
  assert.match(imprint, /Example Responsible/);
  assert.match(imprint, /mailto:contact\.invalid/);
});

test('approved public support page exposes a clear electronic notice and complaint route', () => {
  const support = accountActions.publicSupportPage({
    compliance: {
      approved: true,
      supportEmail: 'support-contact.invalid',
    },
  });

  assert.match(support, /data-sit-compliance-status="approved"/);
  assert.match(support, /mailto:support-contact\.invalid/);
  assert.match(support, /Rechtswidrige Inhalte melden/);
  assert.match(support, /Meldung rechtswidriger Inhalt/);
  assert.match(support, /Beschwerde zu einer Moderationsentscheidung/);
  assert.match(support, /kein Notruf/);
});
