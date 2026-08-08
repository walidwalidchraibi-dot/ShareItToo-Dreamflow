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
      assert.deepEqual(migrationRows.rows.map((row) => row.name), ['001_b3_foundation.up.sql']);
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
      const tokenFor = (id) => signAccessToken({ id, email: `${id}@example.com` });

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
