import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import pg from 'pg';

const databaseUrl = process.env.TEST_DATABASE_URL?.trim();

if (!databaseUrl) {
  test.skip('PostgreSQL foundation integration requires TEST_DATABASE_URL');
} else {
  test('migrations, concurrency guard, and private-resource boundaries work together', async () => {
    process.env.DATABASE_URL = databaseUrl;
    process.env.JWT_SECRET ??= 'test-secret-that-is-longer-than-thirty-two-characters';
    process.env.MAIL_TRANSPORT = 'memory';
    const uploadDir = await fs.mkdtemp(path.join(os.tmpdir(), 'sit-b3-uploads-'));
    process.env.UPLOAD_DIR = uploadDir;

    const { Pool } = pg;
    const setupPool = new Pool({ connectionString: databaseUrl, max: 4 });
    const currentDir = path.dirname(fileURLToPath(import.meta.url));
    const schema = await fs.readFile(path.resolve(currentDir, '../sql/schema.sql'), 'utf8');
    const { runMigrations } = await import('../src/migrations.js');

    let server;
    let applicationPool;
    try {
      await setupPool.query(schema);
      await runMigrations(setupPool);
      await runMigrations(setupPool);
      const migrationRows = await setupPool.query(
        `SELECT name, checksum FROM schema_migrations ORDER BY name`,
      );
      assert.deepEqual(migrationRows.rows.map((row) => row.name), [
        '001_b3_foundation.up.sql',
        '002_b4_auth_lifecycle.up.sql',
      ]);
      assert.match(migrationRows.rows[0].checksum, /^[0-9a-f]{64}$/);

      await setupPool.query('TRUNCATE users CASCADE');
      await setupPool.query(
        `INSERT INTO users (id, email, profile, role, account_status)
         VALUES
           ('owner', 'owner@example.com', '{}'::jsonb, 'user', 'active'),
           ('renter-a', 'renter-a@example.com', '{}'::jsonb, 'user', 'active'),
           ('renter-b', 'renter-b@example.com', '{}'::jsonb, 'user', 'active'),
           ('outsider', 'outsider@example.com', '{}'::jsonb, 'user', 'active'),
           ('suspended', 'suspended@example.com', '{}'::jsonb, 'user', 'suspended')`,
      );
      const legacyRefresh = await setupPool.query(
        `INSERT INTO refresh_tokens (
           user_id, token_hash, expires_at, user_agent
         ) VALUES (
           'owner', $1, now() + interval '1 day', 'Legacy rollback probe'
         )
         RETURNING id, session_id, family_id`,
        ['a'.repeat(64)],
      );
      assert.equal(legacyRefresh.rows[0].session_id, legacyRefresh.rows[0].id);
      assert.equal(legacyRefresh.rows[0].family_id, legacyRefresh.rows[0].id);
      const legacySession = await setupPool.query(
        `SELECT user_id, device_label FROM auth_sessions WHERE id = $1`,
        [legacyRefresh.rows[0].session_id],
      );
      assert.equal(legacySession.rows[0].user_id, 'owner');
      assert.equal(legacySession.rows[0].device_label, 'Legacy-App-Sitzung');
      const sessionIds = {
        owner: '11111111-1111-4111-8111-111111111111',
        'renter-a': '22222222-2222-4222-8222-222222222222',
        'renter-b': '33333333-3333-4333-8333-333333333333',
        outsider: '44444444-4444-4444-8444-444444444444',
        suspended: '55555555-5555-4555-8555-555555555555',
      };
      await setupPool.query(
        `INSERT INTO auth_sessions (id, user_id, device_label)
         VALUES
           ($1, 'owner', 'Owner test'),
           ($2, 'renter-a', 'Renter A test'),
           ($3, 'renter-b', 'Renter B test'),
           ($4, 'outsider', 'Outsider test'),
           ($5, 'suspended', 'Suspended test')`,
        Object.values(sessionIds),
      );
      await setupPool.query(
        `INSERT INTO listings (
           id, owner_id, payload, is_active, currency, price_per_day_minor
         ) VALUES (
           'listing-1', 'owner',
           '{"id":"listing-1","ownerId":"owner","title":"Camera","description":"Test","currency":"EUR"}'::jsonb,
           true, 'EUR', 1500
         )`,
      );

      for (const [id, renterId] of [['booking-a', 'renter-a'], ['booking-b', 'renter-b']]) {
        const payload = {
          id,
          itemId: 'listing-1',
          ownerId: 'owner',
          renterId,
          status: 'pending',
          start: '2026-09-10T10:00:00.000Z',
          end: '2026-09-12T10:00:00.000Z',
          createdAt: '2026-08-08T20:00:00.000Z',
        };
        await setupPool.query(
          `INSERT INTO rental_requests (
             id, item_id, owner_id, renter_id, status, payload, created_at
           ) VALUES ($1, 'listing-1', 'owner', $2, 'pending', $3::jsonb, $4)`,
          [id, renterId, JSON.stringify(payload), payload.createdAt],
        );
        await setupPool.query(
          `INSERT INTO bookings (
             id, listing_id, owner_id, renter_id, status, starts_at, ends_at,
             currency, quoted_total_minor
           ) VALUES (
             $1, 'listing-1', 'owner', $2, 'pending', $3, $4, 'EUR', 3000
           )`,
          [id, renterId, payload.start, payload.end],
        );
      }

      const first = await setupPool.connect();
      const second = await setupPool.connect();
      try {
        await first.query('BEGIN');
        await second.query('BEGIN');
        await first.query(`UPDATE bookings SET status = 'accepted' WHERE id = 'booking-a'`);
        const competingAcceptance = second.query(
          `UPDATE bookings SET status = 'accepted' WHERE id = 'booking-b'`,
        );
        await new Promise((resolve) => setTimeout(resolve, 100));
        await first.query('COMMIT');
        await assert.rejects(competingAcceptance, (error) => error?.code === '23P01');
        await second.query('ROLLBACK');
      } finally {
        first.release();
        second.release();
      }
      await setupPool.query(`UPDATE bookings SET status = 'pending'`);

      await setupPool.query(
        `INSERT INTO message_threads (
           id, request_id, item_id, user1_id, user2_id, payload
         ) VALUES (
           'thread-1', 'booking-a', 'listing-1', 'renter-a', 'owner', '{}'::jsonb
         )`,
      );
      const privateContents = Buffer.from('private-evidence');
      await fs.writeFile(path.join(uploadDir, 'private.png'), privateContents);
      await setupPool.query(
        `INSERT INTO uploads (
           owner_id, storage_name, mime_type, byte_size, purpose, visibility, thread_id
         ) VALUES (
           'owner', 'private.png', 'image/png', $1, 'handover_evidence', 'private', 'thread-1'
         )`,
        [privateContents.length],
      );

      const { createApp } = await import('../src/app.js');
      const { pool, } = await import('../src/db.js');
      const { signAccessToken } = await import('../src/security.js');
      applicationPool = pool;
      server = http.createServer(createApp());
      await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
      const baseUrl = `http://127.0.0.1:${server.address().port}`;
      const tokenFor = (id) => signAccessToken(
        { id, email: `${id}@example.com` },
        { sessionId: sessionIds[id] },
      );

      const ownerHeaders = {
        Authorization: `Bearer ${tokenFor('owner')}`,
        'Content-Type': 'application/json',
      };
      const acceptRequest = (id, renterId) => fetch(`${baseUrl}/v1/rental-requests/sync`, {
        method: 'PUT',
        headers: ownerHeaders,
        body: JSON.stringify({
          requests: [{
            id,
            itemId: 'listing-1',
            ownerId: 'owner',
            renterId,
            status: 'accepted',
            start: '2026-09-10T10:00:00.000Z',
            end: '2026-09-12T10:00:00.000Z',
          }],
        }),
      });
      const acceptanceResponses = await Promise.all([
        acceptRequest('booking-a', 'renter-a'),
        acceptRequest('booking-b', 'renter-b'),
      ]);
      assert.deepEqual(acceptanceResponses.map((response) => response.status).sort(), [200, 409]);
      const conflictResponse = acceptanceResponses.find((response) => response.status === 409);
      assert.equal((await conflictResponse.json()).error, 'booking_period_unavailable');

      const outsiderHeaders = { Authorization: `Bearer ${tokenFor('outsider')}` };
      const rentalResponse = await fetch(`${baseUrl}/v1/rental-requests`, { headers: outsiderHeaders });
      assert.equal(rentalResponse.status, 200);
      assert.deepEqual((await rentalResponse.json()).requests, []);

      const threadResponse = await fetch(`${baseUrl}/v1/message-threads`, { headers: outsiderHeaders });
      assert.equal(threadResponse.status, 200);
      assert.deepEqual((await threadResponse.json()).threads, []);

      const forbiddenUpload = await fetch(`${baseUrl}/v1/uploads/private.png`, { headers: outsiderHeaders });
      assert.equal(forbiddenUpload.status, 403);
      assert.equal((await forbiddenUpload.json()).error, 'upload_forbidden');

      const ownerUpload = await fetch(`${baseUrl}/v1/uploads/private.png`, {
        headers: { Authorization: `Bearer ${tokenFor('owner')}` },
      });
      assert.equal(ownerUpload.status, 200);
      assert.deepEqual(Buffer.from(await ownerUpload.arrayBuffer()), privateContents);

      const suspendedResponse = await fetch(`${baseUrl}/v1/rental-requests`, {
        headers: { Authorization: `Bearer ${tokenFor('suspended')}` },
      });
      assert.equal(suspendedResponse.status, 401);
      assert.equal((await suspendedResponse.json()).error, 'account_not_active');

      const { hashActionToken, hashPassword } = await import('../src/security.js');
      const initialPassword = 'InitialPassword1';
      const nextPassword = 'NextSecurePassword2';
      const emailChangePassword = 'EmailChangePassword4';
      await setupPool.query(
        `INSERT INTO users (
           id, email, password_hash, profile, role, account_status,
           email_verified_at, terms_accepted_at, privacy_accepted_at,
           minimum_age_confirmed_at
         ) VALUES
         (
           'auth-user', 'auth-user@example.com', $1, '{"displayName":"Auth User"}'::jsonb,
           'user', 'active', now(), now(), now(), now()
         ),
         (
           'email-user', 'email-old@example.com', $2, '{"displayName":"Email User"}'::jsonb,
           'user', 'active', now(), now(), now(), now()
         )`,
        [await hashPassword(initialPassword), await hashPassword(emailChangePassword)],
      );

      const login = (password, forwardedFor = '203.0.113.10') => fetch(`${baseUrl}/v1/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Forwarded-For': forwardedFor,
          'User-Agent': 'SIT integration test',
        },
        body: JSON.stringify({ email: 'auth-user@example.com', password }),
      });

      const firstLogin = await login(initialPassword);
      assert.equal(firstLogin.status, 200);
      const firstSession = await firstLogin.json();
      assert.match(firstSession.sessionId, /^[0-9a-f-]{36}$/);

      const sessionsResponse = await fetch(`${baseUrl}/v1/auth/sessions`, {
        headers: { Authorization: `Bearer ${firstSession.accessToken}` },
      });
      assert.equal(sessionsResponse.status, 200);
      const sessions = (await sessionsResponse.json()).sessions;
      assert.equal(sessions.length, 1);
      assert.equal(sessions[0].isThisDevice, true);

      const rotatedResponse = await fetch(`${baseUrl}/v1/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken: firstSession.refreshToken }),
      });
      assert.equal(rotatedResponse.status, 200);
      const rotatedSession = await rotatedResponse.json();
      assert.equal(rotatedSession.sessionId, firstSession.sessionId);
      assert.notEqual(rotatedSession.refreshToken, firstSession.refreshToken);

      const reuseResponse = await fetch(`${baseUrl}/v1/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken: firstSession.refreshToken }),
      });
      assert.equal(reuseResponse.status, 401);
      assert.equal((await reuseResponse.json()).error, 'refresh_token_reuse_detected');

      const revokedAccess = await fetch(`${baseUrl}/v1/auth/me`, {
        headers: { Authorization: `Bearer ${rotatedSession.accessToken}` },
      });
      assert.equal(revokedAccess.status, 401);

      const emailLogin = (email, password, forwardedFor) => fetch(`${baseUrl}/v1/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Forwarded-For': forwardedFor,
          'User-Agent': 'SIT email lifecycle test',
        },
        body: JSON.stringify({ email, password }),
      });
      const emailLoginResponse = await emailLogin(
        'email-old@example.com',
        emailChangePassword,
        '203.0.113.30',
      );
      assert.equal(emailLoginResponse.status, 200);
      const emailSession = await emailLoginResponse.json();
      const emailChangeRequest = await fetch(`${baseUrl}/v1/auth/email-change/request`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${emailSession.accessToken}`,
          'Content-Type': 'application/json',
          'X-Forwarded-For': '203.0.113.31',
        },
        body: JSON.stringify({
          newEmail: 'email-new@example.com',
          currentPassword: emailChangePassword,
        }),
      });
      assert.equal(emailChangeRequest.status, 202);
      assert.deepEqual(await emailChangeRequest.json(), { accepted: true });
      const emailChangeAction = await setupPool.query(
        `SELECT id, payload FROM auth_action_tokens
         WHERE user_id = 'email-user' AND kind = 'change_email' AND consumed_at IS NULL`,
      );
      assert.equal(emailChangeAction.rowCount, 1);
      assert.deepEqual(emailChangeAction.rows[0].payload, { newEmail: 'email-new@example.com' });
      const knownEmailChangeToken = 'email-change-token-that-is-long-enough-for-testing-1234567890';
      await setupPool.query(
        'UPDATE auth_action_tokens SET token_hash = $2 WHERE id = $1',
        [emailChangeAction.rows[0].id, hashActionToken(knownEmailChangeToken)],
      );
      const emailChangeConfirm = await fetch(
        `${baseUrl}/v1/auth/email-change/confirm?token=${encodeURIComponent(knownEmailChangeToken)}`,
        { headers: { 'X-Forwarded-For': '203.0.113.32' } },
      );
      assert.equal(emailChangeConfirm.status, 200);
      assert.match(await emailChangeConfirm.text(), /E-Mail-Adresse geändert/);
      const emailSessionAfterChange = await fetch(`${baseUrl}/v1/auth/me`, {
        headers: { Authorization: `Bearer ${emailSession.accessToken}` },
      });
      assert.equal(emailSessionAfterChange.status, 401);
      assert.equal((await emailLogin(
        'email-old@example.com',
        emailChangePassword,
        '203.0.113.33',
      )).status, 401);
      const newEmailLogin = await emailLogin(
        'email-new@example.com',
        emailChangePassword,
        '203.0.113.34',
      );
      assert.equal(newEmailLogin.status, 200);
      const changedEmailUser = await setupPool.query(
        `SELECT email, email_verified_at FROM users WHERE id = 'email-user'`,
      );
      assert.equal(changedEmailUser.rows[0].email, 'email-new@example.com');
      assert.ok(changedEmailUser.rows[0].email_verified_at);
      const emailAudit = await setupPool.query(
        `SELECT metadata FROM audit_log
         WHERE actor_id = 'email-user' AND action = 'auth.email_changed'
         ORDER BY id DESC LIMIT 1`,
      );
      assert.match(emailAudit.rows[0].metadata.newEmailHash, /^[0-9a-f]{64}$/);
      assert.doesNotMatch(JSON.stringify(emailAudit.rows[0].metadata), /email-new@example\.com/);

      for (let attempt = 0; attempt < 10; attempt += 1) {
        const failure = await emailLogin(
          'email-new@example.com',
          'WrongPassword9',
          `203.0.114.${attempt + 1}`,
        );
        assert.equal(failure.status, 401);
        assert.equal((await failure.json()).error, 'invalid_credentials');
      }
      const lockedUser = await setupPool.query(
        `SELECT failed_login_attempts, login_locked_until
         FROM users WHERE id = 'email-user'`,
      );
      assert.equal(lockedUser.rows[0].failed_login_attempts, 10);
      assert.ok(new Date(lockedUser.rows[0].login_locked_until) > new Date());
      assert.equal((await emailLogin(
        'email-new@example.com',
        emailChangePassword,
        '203.0.114.20',
      )).status, 401);
      await setupPool.query(
        `UPDATE users
         SET failed_login_attempts = 0, login_locked_until = NULL
         WHERE id = 'email-user'`,
      );

      const secondLogin = await login(initialPassword);
      assert.equal(secondLogin.status, 200);
      const passwordSession = await secondLogin.json();
      const passwordChange = await fetch(`${baseUrl}/v1/auth/password/change`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${passwordSession.accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          currentPassword: initialPassword,
          newPassword: nextPassword,
        }),
      });
      assert.equal(passwordChange.status, 204);

      const accessAfterPasswordChange = await fetch(`${baseUrl}/v1/auth/me`, {
        headers: { Authorization: `Bearer ${passwordSession.accessToken}` },
      });
      assert.equal(accessAfterPasswordChange.status, 401);
      assert.equal((await login(initialPassword)).status, 401);

      const thirdLogin = await login(nextPassword);
      assert.equal(thirdLogin.status, 200);
      const deletionSession = await thirdLogin.json();
      const erasedStorageName = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.png';
      await fs.writeFile(path.join(uploadDir, erasedStorageName), Buffer.from('private-profile-image'));
      await setupPool.query(
        `INSERT INTO listings (id, owner_id, payload, is_active)
         VALUES (
           'auth-user-listing', 'auth-user',
           '{"id":"auth-user-listing","ownerId":"auth-user","title":"Private title","description":"Call me at +49123456789","photos":["private-photo-url"],"status":"active","isActive":true}'::jsonb,
           true
         )`,
      );
      await setupPool.query(
        `INSERT INTO uploads (
           owner_id, storage_name, mime_type, byte_size, purpose, visibility, listing_id
         ) VALUES (
           'auth-user', $1, 'image/png', $2, 'profile_image', 'public', 'auth-user-listing'
         )`,
        [erasedStorageName, Buffer.byteLength('private-profile-image')],
      );
      const deletionHeaders = {
        Authorization: `Bearer ${deletionSession.accessToken}`,
        'Content-Type': 'application/json',
      };
      const deletionPreflight = await fetch(`${baseUrl}/v1/account/deletion-preflight`, {
        headers: deletionHeaders,
      });
      assert.equal(deletionPreflight.status, 200);
      assert.deepEqual(await deletionPreflight.json(), { canDelete: true, blockers: [] });

      const wrongDeletion = await fetch(`${baseUrl}/v1/account/deletion`, {
        method: 'POST',
        headers: deletionHeaders,
        body: JSON.stringify({ currentPassword: 'wrong-password' }),
      });
      assert.equal(wrongDeletion.status, 401);
      const deletion = await fetch(`${baseUrl}/v1/account/deletion`, {
        method: 'POST',
        headers: deletionHeaders,
        body: JSON.stringify({ currentPassword: nextPassword }),
      });
      assert.equal(deletion.status, 200);
      assert.deepEqual(await deletion.json(), { deleted: true });
      assert.equal((await login(nextPassword)).status, 401);
      const erasedUser = await setupPool.query(
        `SELECT email, password_hash, account_status, deactivated_at, personal_data_erased_at, profile
         FROM users WHERE id = 'auth-user'`,
      );
      assert.match(erasedUser.rows[0].email, /^deleted\+[0-9a-f-]+@anonymized\.invalid$/);
      assert.equal(erasedUser.rows[0].password_hash, null);
      assert.equal(erasedUser.rows[0].account_status, 'closed');
      assert.ok(erasedUser.rows[0].deactivated_at);
      assert.ok(erasedUser.rows[0].personal_data_erased_at);
      assert.equal(erasedUser.rows[0].profile.displayName, 'Gelöschter Nutzer');
      assert.equal((await setupPool.query(
        `SELECT count(*)::int AS count FROM auth_sessions WHERE user_id = 'auth-user'`,
      )).rows[0].count, 0);
      assert.equal((await setupPool.query(
        `SELECT count(*)::int AS count FROM uploads WHERE owner_id = 'auth-user'`,
      )).rows[0].count, 0);
      await assert.rejects(fs.access(path.join(uploadDir, erasedStorageName)), { code: 'ENOENT' });
      const erasedListing = await setupPool.query(
        `SELECT is_active, payload FROM listings WHERE id = 'auth-user-listing'`,
      );
      assert.equal(erasedListing.rows[0].is_active, false);
      assert.equal(erasedListing.rows[0].payload.description, undefined);
      assert.deepEqual(erasedListing.rows[0].payload.photos, []);
      assert.equal(erasedListing.rows[0].payload.status, 'ended');

      const deletionPage = await fetch(`${baseUrl}/v1/account-deletion`);
      assert.equal(deletionPage.status, 200);
      assert.match(await deletionPage.text(), /Konto löschen/);
      const unknownDeletionRequest = await fetch(`${baseUrl}/v1/account-deletion/request`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ email: 'unknown@example.com' }),
      });
      assert.equal(unknownDeletionRequest.status, 202);
      assert.match(await unknownDeletionRequest.text(), /Anfrage erhalten/);

      const registrationBody = {
        email: 'new-account@example.com',
        password: 'RegistrationPassword3',
        displayName: 'New Account',
        termsAccepted: true,
        privacyAccepted: true,
        minimumAgeConfirmed: true,
      };
      const register = () => fetch(`${baseUrl}/v1/auth/register`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Forwarded-For': '203.0.113.20',
        },
        body: JSON.stringify(registrationBody),
      });
      const registration = await register();
      assert.equal(registration.status, 202);
      assert.deepEqual(await registration.json(), { accepted: true });
      const duplicateRegistration = await register();
      assert.equal(duplicateRegistration.status, 202);
      assert.deepEqual(await duplicateRegistration.json(), { accepted: true });
      const unverifiedLogin = await fetch(`${baseUrl}/v1/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Forwarded-For': '203.0.113.21',
        },
        body: JSON.stringify({
          email: registrationBody.email,
          password: registrationBody.password,
        }),
      });
      assert.equal(unverifiedLogin.status, 403);
      assert.equal((await unverifiedLogin.json()).error, 'email_verification_required');

      const limitedAttempts = [];
      for (let attempt = 0; attempt < 9; attempt += 1) {
        limitedAttempts.push(await fetch(`${baseUrl}/v1/auth/login`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Forwarded-For': '203.0.113.77',
          },
          body: JSON.stringify({ email: 'unknown@example.com', password: 'WrongPassword9' }),
        }));
      }
      assert.equal(limitedAttempts.at(-1).status, 429);
      assert.equal((await limitedAttempts.at(-1).json()).error, 'rate_limit_exceeded');
    } finally {
      if (server) {
        await new Promise((resolve, reject) => server.close((error) => (
          error ? reject(error) : resolve()
        )));
      }
      if (applicationPool) await applicationPool.end();
      await setupPool.end();
      await fs.rm(uploadDir, { recursive: true, force: true });
    }
  });
}
