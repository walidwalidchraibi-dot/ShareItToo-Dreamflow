import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import pg from 'pg';
import sharp from 'sharp';

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
        '003_b4_phone_constraint_fix.up.sql',
        '004_b5_listing_catalog.up.sql',
        '005_b6_booking_workflow.up.sql',
        '006_b7_communications.up.sql',
      ]);
      assert.match(migrationRows.rows[0].checksum, /^[0-9a-f]{64}$/);
      assert.match(migrationRows.rows[2].checksum, /^[0-9a-f]{64}$/);

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
        `UPDATE users SET phone_e164 = '+4915212345678' WHERE id = 'owner'`,
      );
      await setupPool.query(
        `INSERT INTO listings (id, owner_id, payload, is_active)
         VALUES (
           'legacy-b4-rollback-listing', 'owner',
           '{"id":"legacy-b4-rollback-listing","ownerId":"owner","title":"Legacy B4 listing"}'::jsonb,
           true
         )`,
      );
      const legacyB4Listing = await setupPool.query(
        `SELECT catalog_version, is_active, status
         FROM listings WHERE id = 'legacy-b4-rollback-listing'`,
      );
      assert.deepEqual(legacyB4Listing.rows[0], {
        catalog_version: 0,
        is_active: true,
        status: 'active',
      });
      await assert.rejects(
        setupPool.query(`UPDATE users SET phone_e164 = '015212345678' WHERE id = 'owner'`),
        (error) => error?.code === '23514' && error?.constraint === 'users_phone_e164_check',
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
           id, owner_id, payload, is_active, catalog_version, catalog_revision,
           status, currency, price_per_day_minor,
           title, description, category_id, condition, location_text, city, country,
           latitude, longitude, min_days, max_days, protection_model
         ) VALUES (
           'listing-1', 'owner',
           '{"id":"listing-1","ownerId":"owner","title":"Camera","description":"Camera for integration tests","categoryId":"cat3","subcategory":"Kameras","tags":["camera"],"pricePerDay":15,"priceRaw":15,"priceUnit":"day","currency":"EUR","deposit":null,"photos":["https://shareittoo.com/api/v1/uploads/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb-full.webp"],"locationText":"Owner exact address","lat":52.5201,"lng":13.4051,"geohash":"private","condition":"good","minDays":1,"maxDays":30,"createdAt":"2026-08-08T20:00:00.000Z","isActive":true,"verificationStatus":"pending","city":"Berlin","country":"Deutschland","status":"active","timesLent":0,"protectionModel":"standard"}'::jsonb,
           true, 1, 1, 'active', 'EUR', 1500,
           'Camera', 'Camera for integration tests', 'cat3', 'good',
           'Owner exact address', 'Berlin', 'Deutschland', 52.5201, 13.4051,
           1, 30, 'standard'
         )`,
      );
      await setupPool.query(
        `INSERT INTO uploads (
           owner_id, storage_name, mime_type, byte_size, purpose, visibility,
           listing_id, content_sha256, content_scan_status
         ) VALUES (
           'owner', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb-full.webp',
           'image/webp', 10, 'listing_image', 'public', 'listing-1', $1, 'passed'
         )`,
        ['b'.repeat(64)],
      );
      await setupPool.query(
        `UPDATE listings
         SET payload = jsonb_set(
               jsonb_set(payload, '{status}', '"paused"'::jsonb),
               '{isActive}', 'false'::jsonb
             ),
             is_active = false
         WHERE id = 'listing-1'`,
      );
      const quarantinedRollbackWrite = await setupPool.query(
        `SELECT catalog_version, catalog_revision, is_active
         FROM listings WHERE id = 'listing-1'`,
      );
      assert.deepEqual(quarantinedRollbackWrite.rows[0], {
        catalog_version: 0,
        catalog_revision: 1,
        is_active: false,
      });
      await setupPool.query(
        `UPDATE listings
         SET payload = jsonb_set(
               jsonb_set(payload, '{status}', '"active"'::jsonb),
               '{isActive}', 'true'::jsonb
             ),
             is_active = true,
             status = 'active',
             catalog_version = 1,
             catalog_revision = catalog_revision + 1
         WHERE id = 'listing-1'`,
      );
      const restoredForwardWrite = await setupPool.query(
        `SELECT catalog_version, catalog_revision, is_active
         FROM listings WHERE id = 'listing-1'`,
      );
      assert.deepEqual(restoredForwardWrite.rows[0], {
        catalog_version: 1,
        catalog_revision: 2,
        is_active: true,
      });

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
      const rollbackBookings = await setupPool.query(
        `SELECT workflow_version, workflow_status, rental_start_date, rental_end_date
         FROM bookings WHERE id IN ('booking-a', 'booking-b') ORDER BY id`,
      );
      assert.deepEqual(rollbackBookings.rows.map((row) => row.workflow_version), [0, 0]);
      assert.deepEqual(rollbackBookings.rows.map((row) => row.workflow_status), ['requested', 'requested']);
      assert.ok(rollbackBookings.rows.every((row) => row.rental_start_date && row.rental_end_date));

      const first = await setupPool.connect();
      const second = await setupPool.connect();
      try {
        await first.query('BEGIN');
        await second.query('BEGIN');
        await first.query(`UPDATE bookings SET status = 'accepted' WHERE id = 'booking-a'`);
        const competingAcceptance = second.query(
          `UPDATE bookings SET status = 'accepted' WHERE id = 'booking-b'`,
        ).then(
          () => null,
          (error) => error,
        );
        await new Promise((resolve) => setTimeout(resolve, 100));
        await first.query('COMMIT');
        assert.equal((await competingAcceptance)?.code, '23P01');
        await second.query('ROLLBACK');
      } finally {
        first.release();
        second.release();
      }
      await setupPool.query(`UPDATE bookings SET status = 'pending'`);
      await setupPool.query(
        `UPDATE bookings
         SET workflow_version = 1,
             workflow_status = 'requested',
             workflow_revision = workflow_revision + 1
         WHERE id IN ('booking-a', 'booking-b')`,
      );

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
      const { drainNotificationOutbox } = await import('../src/notifications.js');
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
      const catalogResponse = await fetch(
        `${baseUrl}/v1/listings?q=Camera&categories=cat3&conditions=good&lat=52.52&lng=13.405&radiusKm=10&sort=distance`,
      );
      assert.equal(catalogResponse.status, 200);
      const catalog = await catalogResponse.json();
      assert.equal(catalog.listings.length, 1);
      assert.equal(catalog.listings[0].id, 'listing-1');
      assert.equal(catalog.listings[0].locationText, 'Berlin, Deutschland');
      assert.equal(catalog.listings[0].lat, 52.52);
      assert.equal(catalog.listings[0].lng, 13.41);
      assert.equal(catalog.listings[0].geohash, '');
      assert.equal(catalog.listings[0].approximateLocation, true);
      assert.deepEqual(catalog.listings[0].photos, [
        'https://shareittoo.com/api/v1/uploads/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb-full.webp',
      ]);
      assert.equal(catalog.page.hasMore, false);

      const emptyCatalogResponse = await fetch(`${baseUrl}/v1/listings?q=does-not-exist`);
      assert.equal(emptyCatalogResponse.status, 200);
      assert.deepEqual((await emptyCatalogResponse.json()).listings, []);

      const renterAHeaders = {
        Authorization: `Bearer ${tokenFor('renter-a')}`,
        'Content-Type': 'application/json',
      };
      const renterBHeaders = {
        Authorization: `Bearer ${tokenFor('renter-b')}`,
        'Content-Type': 'application/json',
      };
      const availabilityRules = Array.from({ length: 7 }, (_, weekday) => ({
        weekday,
        localStart: '00:00',
        localEnd: '23:59',
        isAvailable: true,
      }));
      const replaceAvailability = await fetch(`${baseUrl}/v1/listings/listing-1/availability`, {
        method: 'PUT',
        headers: ownerHeaders,
        body: JSON.stringify({
          timezone: 'Europe/Berlin',
          minimumDays: 1,
          maximumDays: 30,
          noticeHours: 0,
          acceptanceWindowMinutes: 30,
          rules: availabilityRules,
          blocks: [{
            startDate: '2026-12-01',
            endDate: '2026-12-03',
            kind: 'maintenance',
            reason: 'Integration maintenance window',
          }],
        }),
      });
      assert.equal(replaceAvailability.status, 200);
      assert.ok((await replaceAvailability.json()).revision > 1);

      const availabilityResponse = await fetch(
        `${baseUrl}/v1/listings/listing-1/availability?from=2026-09-01&to=2026-12-10`,
      );
      assert.equal(availabilityResponse.status, 200);
      const availability = (await availabilityResponse.json()).availability;
      assert.equal(availability.timezone, 'Europe/Berlin');
      assert.equal(availability.rules.length, 7);
      assert.equal(availability.unavailable.filter((entry) => entry.type === 'block').length, 1);

      const rollbackPayload = {
        id: 'b5-rollback-booking',
        itemId: 'listing-1',
        ownerId: 'owner',
        renterId: 'renter-a',
        status: 'pending',
        start: '2026-12-10T10:00:00.000Z',
        end: '2026-12-12T10:00:00.000Z',
        createdAt: '2026-08-09T01:00:00.000Z',
      };
      await setupPool.query(
        `INSERT INTO rental_requests (
           id, item_id, owner_id, renter_id, status, payload, created_at
         ) VALUES (
           'b5-rollback-booking', 'listing-1', 'owner', 'renter-a',
           'pending', $1::jsonb, $2
         )`,
        [JSON.stringify(rollbackPayload), rollbackPayload.createdAt],
      );
      await setupPool.query(
        `INSERT INTO bookings (
           id, listing_id, owner_id, renter_id, status, starts_at, ends_at,
           currency, quoted_total_minor
         ) VALUES (
           'b5-rollback-booking', 'listing-1', 'owner', 'renter-a',
           'pending', $1, $2, 'EUR', 3000
         )`,
        [rollbackPayload.start, rollbackPayload.end],
      );
      const quarantinedBooking = await setupPool.query(
        `SELECT workflow_version FROM bookings WHERE id = 'b5-rollback-booking'`,
      );
      assert.equal(quarantinedBooking.rows[0].workflow_version, 0);
      const hiddenRollbackBooking = await fetch(`${baseUrl}/v1/rental-requests`, {
        headers: { Authorization: `Bearer ${tokenFor('renter-a')}` },
      });
      assert.equal(hiddenRollbackBooking.status, 200);
      assert.equal(
        (await hiddenRollbackBooking.json()).requests.some((entry) => entry.id === 'b5-rollback-booking'),
        false,
      );
      const revalidatedRollbackBooking = await fetch(
        `${baseUrl}/v1/bookings/b5-rollback-booking`,
        {
          method: 'PATCH',
          headers: { ...renterAHeaders, 'Idempotency-Key': 'revalidate-b5-rollback-booking' },
          body: JSON.stringify({
            itemId: 'listing-1',
            startDate: '2026-12-10',
            endDate: '2026-12-12',
          }),
        },
      );
      const revalidatedRollbackPayload = await revalidatedRollbackBooking.json();
      assert.equal(
        revalidatedRollbackBooking.status,
        200,
        JSON.stringify(revalidatedRollbackPayload),
      );
      const revalidatedBooking = revalidatedRollbackPayload.booking;
      assert.equal(revalidatedBooking.workflowVersion, 1);
      assert.equal(revalidatedBooking.workflowStatus, 'requested');
      assert.equal(revalidatedBooking.quote.totalMinor, 3300);

      const blockedCheck = await fetch(`${baseUrl}/v1/listings/listing-1/availability/check`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ startDate: '2026-12-01', endDate: '2026-12-02' }),
      });
      assert.equal(blockedCheck.status, 409);
      assert.equal((await blockedCheck.json()).reason, 'listing_period_blocked');

      const quotePayload = {
        itemId: 'listing-1',
        startDate: '2026-10-01',
        endDate: '2026-10-03',
        ownerDeliversAtDropoffChosen: false,
        ownerPicksUpAtReturnChosen: false,
      };
      const quoteResponse = await fetch(`${baseUrl}/v1/bookings/quote`, {
        method: 'POST',
        headers: renterAHeaders,
        body: JSON.stringify(quotePayload),
      });
      assert.equal(quoteResponse.status, 200);
      const quoted = await quoteResponse.json();
      assert.equal(quoted.quote.days, 2);
      assert.equal(quoted.quote.baseRentalMinor, 3000);
      assert.equal(quoted.quote.platformFeeMinor, 300);
      assert.equal(quoted.quote.totalMinor, 3300);
      assert.match(quoted.start, /T22:00:00\.000Z$/);

      const createHeaders = {
        ...renterAHeaders,
        'Idempotency-Key': 'create-b6-flow-integration',
      };
      const createB6 = () => fetch(`${baseUrl}/v1/bookings`, {
        method: 'POST',
        headers: createHeaders,
        body: JSON.stringify({ ...quotePayload, id: 'b6-flow' }),
      });
      const createdB6Response = await createB6();
      assert.equal(createdB6Response.status, 201);
      const createdB6 = (await createdB6Response.json()).booking;
      assert.equal(createdB6.status, 'pending');
      assert.equal(createdB6.workflowStatus, 'requested');
      assert.equal(createdB6.quotedTotalRenter, 33);
      assert.equal(createdB6.ownerId, 'owner');
      assert.equal(createdB6.renterId, 'renter-a');
      const replayB6 = await createB6();
      assert.equal(replayB6.status, 200);
      assert.equal((await replayB6.json()).replayed, true);

      const rejectedLegacyCreation = await fetch(`${baseUrl}/v1/rental-requests/sync`, {
        method: 'PUT',
        headers: renterAHeaders,
        body: JSON.stringify({
          requests: [{
            id: 'legacy-b6-create',
            itemId: 'listing-1',
            status: 'pending',
            start: '2026-12-20T10:00:00.000Z',
            end: '2026-12-22T10:00:00.000Z',
          }],
        }),
      });
      assert.equal(rejectedLegacyCreation.status, 409);
      assert.equal(
        (await rejectedLegacyCreation.json()).error,
        'booking_creation_requires_idempotent_endpoint',
      );

      const duplicateB6 = await fetch(`${baseUrl}/v1/bookings`, {
        method: 'POST',
        headers: { ...renterAHeaders, 'Idempotency-Key': 'create-b6-duplicate-integration' },
        body: JSON.stringify({ ...quotePayload, id: 'b6-flow-duplicate' }),
      });
      assert.equal(duplicateB6.status, 409);
      assert.equal((await duplicateB6.json()).error, 'duplicate_booking_request');

      const amendedB6 = await fetch(`${baseUrl}/v1/bookings/b6-flow`, {
        method: 'PATCH',
        headers: { ...renterAHeaders, 'Idempotency-Key': 'amend-b6-flow-integration' },
        body: JSON.stringify({ ...quotePayload, endDate: '2026-10-04' }),
      });
      assert.equal(amendedB6.status, 200);
      const amendedBooking = (await amendedB6.json()).booking;
      assert.equal(amendedBooking.quote.days, 3);
      assert.equal(amendedBooking.quote.totalMinor, 4950);
      assert.equal(amendedBooking.workflowRevision, 2);

      const createConflict = await fetch(`${baseUrl}/v1/bookings`, {
        method: 'POST',
        headers: { ...renterBHeaders, 'Idempotency-Key': 'create-b6-conflict-integration' },
        body: JSON.stringify({
          itemId: 'listing-1',
          id: 'b6-conflict',
          startDate: '2026-10-02',
          endDate: '2026-10-05',
        }),
      });
      assert.equal(createConflict.status, 201);

      const outsiderTransition = await fetch(`${baseUrl}/v1/bookings/b6-flow/transitions`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${tokenFor('outsider')}`,
          'Content-Type': 'application/json',
          'Idempotency-Key': 'outsider-b6-transition',
        },
        body: JSON.stringify({ status: 'accepted' }),
      });
      assert.equal(outsiderTransition.status, 403);

      const acceptB6 = await fetch(`${baseUrl}/v1/bookings/b6-flow/transitions`, {
        method: 'POST',
        headers: { ...ownerHeaders, 'Idempotency-Key': 'accept-b6-flow-integration' },
        body: JSON.stringify({ status: 'accepted' }),
      });
      assert.equal(acceptB6.status, 200);
      assert.equal((await acceptB6.json()).booking.workflowStatus, 'accepted');

      const conflictingAcceptance = await fetch(`${baseUrl}/v1/bookings/b6-conflict/transitions`, {
        method: 'POST',
        headers: { ...ownerHeaders, 'Idempotency-Key': 'accept-b6-conflict-integration' },
        body: JSON.stringify({ status: 'accepted' }),
      });
      assert.equal(conflictingAcceptance.status, 409);
      assert.equal((await conflictingAcceptance.json()).error, 'booking_period_unavailable');

      const activateB6 = await fetch(`${baseUrl}/v1/bookings/b6-flow/transitions`, {
        method: 'POST',
        headers: { ...renterAHeaders, 'Idempotency-Key': 'activate-b6-flow-integration' },
        body: JSON.stringify({ status: 'running' }),
      });
      assert.equal(activateB6.status, 200);
      assert.equal((await activateB6.json()).booking.workflowStatus, 'active');

      const completeB6 = await fetch(`${baseUrl}/v1/bookings/b6-flow/transitions`, {
        method: 'POST',
        headers: { ...ownerHeaders, 'Idempotency-Key': 'complete-b6-flow-integration' },
        body: JSON.stringify({ status: 'completed' }),
      });
      assert.equal(completeB6.status, 200);
      const completedB6 = (await completeB6.json()).booking;
      assert.equal(completedB6.workflowStatus, 'completed');
      assert.equal(completedB6.status, 'completed');
      const b6Events = await setupPool.query(
        `SELECT from_status, to_status
         FROM booking_events WHERE booking_id = 'b6-flow'
         ORDER BY from_status NULLS FIRST, to_status`,
      );
      assert.deepEqual(
        b6Events.rows.map((row) => `${row.from_status ?? 'null'}->${row.to_status}`).sort(),
        [
          'null->requested',
          'requested->requested',
          'requested->accepted',
          'accepted->confirmed',
          'confirmed->active',
          'active->returned',
          'returned->completed',
        ].sort(),
      );

      const createExpiring = await fetch(`${baseUrl}/v1/bookings`, {
        method: 'POST',
        headers: { ...renterBHeaders, 'Idempotency-Key': 'create-b6-expiring-integration' },
        body: JSON.stringify({
          itemId: 'listing-1',
          id: 'b6-expiring',
          startDate: '2026-11-01',
          endDate: '2026-11-03',
        }),
      });
      assert.equal(createExpiring.status, 201);
      const renterCannotAccept = await fetch(`${baseUrl}/v1/bookings/b6-expiring/transitions`, {
        method: 'POST',
        headers: { ...renterBHeaders, 'Idempotency-Key': 'renter-accept-b6-expiring' },
        body: JSON.stringify({ status: 'accepted' }),
      });
      assert.equal(renterCannotAccept.status, 409);
      assert.equal((await renterCannotAccept.json()).error, 'invalid_status_transition');
      const acceptExpiring = await fetch(`${baseUrl}/v1/bookings/b6-expiring/transitions`, {
        method: 'POST',
        headers: { ...ownerHeaders, 'Idempotency-Key': 'owner-accept-b6-expiring' },
        body: JSON.stringify({ status: 'accepted' }),
      });
      assert.equal(acceptExpiring.status, 200);
      await setupPool.query(
        `UPDATE bookings SET hold_expires_at = now() - interval '1 minute'
         WHERE id = 'b6-expiring'`,
      );
      const sweepResponse = await fetch(`${baseUrl}/v1/rental-requests`, {
        headers: { Authorization: `Bearer ${tokenFor('renter-b')}` },
      });
      assert.equal(sweepResponse.status, 200);
      const swept = (await sweepResponse.json()).requests.find((entry) => entry.id === 'b6-expiring');
      assert.equal(swept.workflowStatus, 'cancelled');
      assert.equal(swept.cancelledBy, 'system');

      const listingImage = await sharp({
        create: {
          width: 960,
          height: 640,
          channels: 3,
          background: { r: 30, g: 90, b: 160 },
        },
      }).jpeg({ quality: 92 }).toBuffer();
      const uploadForm = new FormData();
      uploadForm.append('purpose', 'listing_image');
      uploadForm.append('file', new Blob([listingImage], { type: 'image/jpeg' }), 'camera.jpg');
      const listingUploadResponse = await fetch(`${baseUrl}/v1/uploads`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenFor('owner')}` },
        body: uploadForm,
      });
      assert.equal(listingUploadResponse.status, 201);
      const listingUpload = await listingUploadResponse.json();
      assert.match(listingUpload.url, /\/uploads\/[0-9a-f-]{36}-full\.webp$/);
      assert.match(listingUpload.thumbnailUrl, /\/uploads\/[0-9a-f-]{36}-thumb\.webp$/);
      assert.equal(listingUpload.width, 960);
      assert.equal(listingUpload.height, 640);
      const localMediaUrl = (remoteUrl) => (
        `${baseUrl}/v1/uploads/${encodeURIComponent(new URL(remoteUrl).pathname.split('/').at(-1))}`
      );
      const privateBeforeBinding = await fetch(localMediaUrl(listingUpload.url));
      assert.equal(privateBeforeBinding.status, 401);
      assert.equal((await privateBeforeBinding.json()).error, 'authentication_required');

      const lifecycleListing = {
        id: 'listing-lifecycle',
        ownerId: 'outsider',
        title: 'Bosch professional drill',
        description: 'A reliable professional drill for the complete listing lifecycle test.',
        categoryId: 'cat1',
        subcategory: 'Werkzeuge',
        tags: ['bohrer', 'bosch'],
        pricePerDay: 18,
        priceRaw: 18,
        priceUnit: 'day',
        currency: 'EUR',
        deposit: 60,
        photos: [listingUpload.url],
        locationText: 'Exact owner address 12',
        city: 'Berlin',
        country: 'Deutschland',
        lat: 52.5205,
        lng: 13.4095,
        geohash: 'private-geohash',
        condition: 'good',
        minDays: 1,
        maxDays: 14,
        handoverRadiusKm: 15,
        protectionModel: 'standard',
        status: 'active',
        isActive: true,
      };
      const createLifecycleListing = await fetch(`${baseUrl}/v1/listings`, {
        method: 'POST',
        headers: ownerHeaders,
        body: JSON.stringify(lifecycleListing),
      });
      assert.equal(createLifecycleListing.status, 201);
      const createdLifecycleListing = (await createLifecycleListing.json()).listing;
      assert.equal(createdLifecycleListing.id, 'listing-lifecycle');
      assert.equal(createdLifecycleListing.ownerId, 'owner');
      assert.equal(createdLifecycleListing.status, 'active');
      assert.equal(createdLifecycleListing.availabilityMode, 'calendar');

      const processedUpload = await setupPool.query(
        `SELECT mime_type, byte_size, thumbnail_mime_type, thumbnail_byte_size,
                image_width, image_height, content_sha256, content_scan_status,
                visibility, listing_id
         FROM uploads WHERE storage_name = $1`,
        [new URL(listingUpload.url).pathname.split('/').at(-1)],
      );
      assert.equal(processedUpload.rowCount, 1);
      assert.equal(processedUpload.rows[0].mime_type, 'image/webp');
      assert.equal(processedUpload.rows[0].thumbnail_mime_type, 'image/webp');
      assert.ok(processedUpload.rows[0].byte_size > 0);
      assert.ok(processedUpload.rows[0].thumbnail_byte_size > 0);
      assert.equal(processedUpload.rows[0].image_width, 960);
      assert.equal(processedUpload.rows[0].image_height, 640);
      assert.match(processedUpload.rows[0].content_sha256, /^[0-9a-f]{64}$/);
      assert.equal(processedUpload.rows[0].content_scan_status, 'passed');
      assert.equal(processedUpload.rows[0].visibility, 'public');
      assert.equal(processedUpload.rows[0].listing_id, 'listing-lifecycle');

      for (const mediaUrl of [listingUpload.url, listingUpload.thumbnailUrl]) {
        const publicMedia = await fetch(localMediaUrl(mediaUrl));
        assert.equal(publicMedia.status, 200);
        assert.equal(publicMedia.headers.get('content-type'), 'image/webp');
        assert.match(publicMedia.headers.get('cache-control'), /^public,/);
        assert.ok((await publicMedia.arrayBuffer()).byteLength > 0);
      }

      const lifecycleSearch = await fetch(
        `${baseUrl}/v1/listings?q=Bosch&categories=cat1&minPrice=17&maxPrice=19&lat=52.52&lng=13.41&radiusKm=5&sort=price_asc`,
      );
      assert.equal(lifecycleSearch.status, 200);
      const lifecycleCatalog = await lifecycleSearch.json();
      assert.equal(lifecycleCatalog.listings.length, 1);
      assert.equal(lifecycleCatalog.listings[0].id, 'listing-lifecycle');
      assert.equal(lifecycleCatalog.listings[0].locationText, 'Berlin, Deutschland');
      assert.equal(lifecycleCatalog.listings[0].lat, 52.52);
      assert.equal(lifecycleCatalog.listings[0].lng, 13.41);
      assert.equal(lifecycleCatalog.listings[0].geohash, '');

      const foreignEdit = await fetch(`${baseUrl}/v1/listings/listing-lifecycle`, {
        method: 'PUT',
        headers: {
          Authorization: `Bearer ${tokenFor('outsider')}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ ...lifecycleListing, title: 'Foreign edit' }),
      });
      assert.equal(foreignEdit.status, 403);
      assert.equal((await foreignEdit.json()).error, 'listing_forbidden');

      const foreignCreate = await fetch(`${baseUrl}/v1/listings`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${tokenFor('outsider')}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ ...lifecycleListing, id: 'listing-foreign' }),
      });
      assert.equal(foreignCreate.status, 403);
      assert.equal((await foreignCreate.json()).error, 'listing_photo_forbidden');
      assert.equal((await setupPool.query(
        `SELECT count(*)::int AS count FROM listings WHERE id = 'listing-foreign'`,
      )).rows[0].count, 0);

      const updateLifecycleListing = await fetch(`${baseUrl}/v1/listings/listing-lifecycle`, {
        method: 'PUT',
        headers: ownerHeaders,
        body: JSON.stringify({
          ...lifecycleListing,
          ownerId: 'outsider',
          title: 'Bosch professional drill set',
          pricePerDay: 22,
          priceRaw: 22,
        }),
      });
      assert.equal(updateLifecycleListing.status, 200);
      const updatedLifecycleListing = (await updateLifecycleListing.json()).listing;
      assert.equal(updatedLifecycleListing.ownerId, 'owner');
      assert.equal(updatedLifecycleListing.title, 'Bosch professional drill set');
      assert.equal(updatedLifecycleListing.pricePerDay, 22);

      await setupPool.query(
        `UPDATE listings
         SET payload = jsonb_set(payload, '{title}', '"B4 rollback title"'::jsonb)
         WHERE id = 'listing-lifecycle'`,
      );
      const quarantinedLifecycle = await setupPool.query(
        `SELECT catalog_version, catalog_revision, status, is_active
         FROM listings WHERE id = 'listing-lifecycle'`,
      );
      assert.equal(quarantinedLifecycle.rows[0].catalog_version, 0);
      assert.equal(quarantinedLifecycle.rows[0].status, 'active');
      assert.equal(quarantinedLifecycle.rows[0].is_active, true);
      assert.equal((await fetch(localMediaUrl(listingUpload.url))).status, 401);
      const quarantinedSearch = await fetch(`${baseUrl}/v1/listings?q=Bosch`);
      assert.equal(quarantinedSearch.status, 200);
      assert.deepEqual((await quarantinedSearch.json()).listings, []);

      const restoreQuarantinedLifecycle = await fetch(
        `${baseUrl}/v1/listings/listing-lifecycle`,
        {
          method: 'PUT',
          headers: ownerHeaders,
          body: JSON.stringify({
            ...lifecycleListing,
            title: 'Bosch restored after rollback',
            pricePerDay: 22,
            priceRaw: 22,
          }),
        },
      );
      assert.equal(restoreQuarantinedLifecycle.status, 200);
      const restoredLifecycleRow = await setupPool.query(
        `SELECT catalog_version, catalog_revision
         FROM listings WHERE id = 'listing-lifecycle'`,
      );
      assert.equal(restoredLifecycleRow.rows[0].catalog_version, 1);
      assert.ok(
        restoredLifecycleRow.rows[0].catalog_revision
          > quarantinedLifecycle.rows[0].catalog_revision,
      );
      assert.equal((await fetch(localMediaUrl(listingUpload.url))).status, 200);

      const pauseLifecycleListing = await fetch(
        `${baseUrl}/v1/listings/listing-lifecycle/status`,
        {
          method: 'PATCH',
          headers: ownerHeaders,
          body: JSON.stringify({ status: 'paused' }),
        },
      );
      assert.equal(pauseLifecycleListing.status, 200);
      assert.equal((await pauseLifecycleListing.json()).listing.status, 'paused');
      const pausedSearch = await fetch(`${baseUrl}/v1/listings?q=Bosch`);
      assert.equal(pausedSearch.status, 200);
      assert.deepEqual((await pausedSearch.json()).listings, []);
      const pausedMedia = await fetch(localMediaUrl(listingUpload.url));
      assert.equal(pausedMedia.status, 401);
      const pausedMediaOwner = await fetch(localMediaUrl(listingUpload.url), {
        headers: { Authorization: `Bearer ${tokenFor('owner')}` },
      });
      assert.equal(pausedMediaOwner.status, 200);
      assert.equal(pausedMediaOwner.headers.get('cache-control'), 'private, no-store');
      const pausedBooking = await fetch(`${baseUrl}/v1/bookings`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${tokenFor('renter-a')}`,
          'Content-Type': 'application/json',
          'Idempotency-Key': 'create-paused-booking-integration',
        },
        body: JSON.stringify({
          id: 'paused-booking',
          itemId: 'listing-lifecycle',
          startDate: '2026-12-20',
          endDate: '2026-12-22',
        }),
      });
      assert.equal(pausedBooking.status, 404);
      assert.equal((await pausedBooking.json()).error, 'listing_not_found');

      const reactivateLifecycleListing = await fetch(
        `${baseUrl}/v1/listings/listing-lifecycle/status`,
        {
          method: 'PATCH',
          headers: ownerHeaders,
          body: JSON.stringify({ status: 'active' }),
        },
      );
      assert.equal(reactivateLifecycleListing.status, 200);
      assert.equal((await reactivateLifecycleListing.json()).listing.status, 'active');
      assert.equal((await fetch(localMediaUrl(listingUpload.url))).status, 200);

      const deleteLifecycleListing = await fetch(`${baseUrl}/v1/listings/listing-lifecycle`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${tokenFor('owner')}` },
      });
      assert.equal(deleteLifecycleListing.status, 204);
      const deletedSearch = await fetch(`${baseUrl}/v1/listings?q=Bosch`);
      assert.equal(deletedSearch.status, 200);
      assert.deepEqual((await deletedSearch.json()).listings, []);
      assert.equal((await fetch(localMediaUrl(listingUpload.url))).status, 401);

      const acceptRequest = (id) => fetch(`${baseUrl}/v1/bookings/${id}/transitions`, {
        method: 'POST',
        headers: {
          ...ownerHeaders,
          'Idempotency-Key': `accept-${id}-integration`,
        },
        body: JSON.stringify({
          status: 'accepted',
        }),
      });
      const acceptanceResponses = await Promise.all([
        acceptRequest('booking-a'),
        acceptRequest('booking-b'),
      ]);
      assert.deepEqual(acceptanceResponses.map((response) => response.status).sort(), [200, 409]);
      const conflictResponse = acceptanceResponses.find((response) => response.status === 409);
      assert.equal((await conflictResponse.json()).error, 'booking_period_unavailable');

      const acceptedIndex = acceptanceResponses.findIndex((response) => response.status === 200);
      const acceptedBookingId = acceptedIndex === 0 ? 'booking-a' : 'booking-b';
      const acceptedRenterId = acceptedIndex === 0 ? 'renter-a' : 'renter-b';
      const acceptedRenterHeaders = acceptedIndex === 0 ? renterAHeaders : renterBHeaders;

      const registerOwnerPush = await fetch(`${baseUrl}/v1/auth/devices/push`, {
        method: 'PUT',
        headers: ownerHeaders,
        body: JSON.stringify({
          token: 'integration-owner-push-token',
          platform: 'android',
          locale: 'de-DE',
        }),
      });
      assert.equal(registerOwnerPush.status, 200);

      const createThread = await fetch(
        `${baseUrl}/v1/message-threads/booking/${acceptedBookingId}`,
        { method: 'POST', headers: acceptedRenterHeaders },
      );
      assert.equal(createThread.status, 201);
      const b7Thread = (await createThread.json()).thread;
      assert.equal(b7Thread.bookingId, acceptedBookingId);
      assert.equal(b7Thread.communicationVersion, 1);

      const sendMessage = () => fetch(
        `${baseUrl}/v1/message-threads/${b7Thread.id}/messages`,
        {
          method: 'POST',
          headers: {
            ...acceptedRenterHeaders,
            'Idempotency-Key': 'b7-message-integration-0001',
          },
          body: JSON.stringify({ text: 'Treffen wir uns um 18 Uhr?' }),
        },
      );
      const firstMessage = await sendMessage();
      assert.equal(firstMessage.status, 201);
      const sentMessage = (await firstMessage.json()).message;
      assert.equal(sentMessage.senderId, acceptedRenterId);
      const replayedMessage = await sendMessage();
      assert.equal(replayedMessage.status, 200);
      assert.equal((await replayedMessage.json()).message.id, sentMessage.id);

      const outsiderMessages = await fetch(
        `${baseUrl}/v1/message-threads/${b7Thread.id}/messages`,
        { headers: { Authorization: `Bearer ${tokenFor('outsider')}` } },
      );
      assert.equal(outsiderMessages.status, 403);

      const markRead = await fetch(
        `${baseUrl}/v1/message-threads/${b7Thread.id}/read`,
        { method: 'POST', headers: ownerHeaders },
      );
      assert.equal(markRead.status, 200);
      assert.ok((await markRead.json()).readCount >= 1);

      const report = await fetch(`${baseUrl}/v1/messages/${sentMessage.id}/reports`, {
        method: 'POST',
        headers: ownerHeaders,
        body: JSON.stringify({ reasonCode: 'integration_probe', details: 'B7 report path' }),
      });
      assert.equal(report.status, 201);

      const block = await fetch(`${baseUrl}/v1/user-blocks/${acceptedRenterId}`, {
        method: 'PUT',
        headers: ownerHeaders,
        body: JSON.stringify({ reasonCode: 'integration_probe' }),
      });
      assert.equal(block.status, 204);
      const blockedMessage = await fetch(
        `${baseUrl}/v1/message-threads/${b7Thread.id}/messages`,
        {
          method: 'POST',
          headers: {
            ...acceptedRenterHeaders,
            'Idempotency-Key': 'b7-message-integration-blocked',
          },
          body: JSON.stringify({ text: 'Diese Nachricht muss blockiert werden.' }),
        },
      );
      assert.equal(blockedMessage.status, 403);
      assert.equal((await blockedMessage.json()).error, 'contact_blocked');
      assert.equal((await fetch(`${baseUrl}/v1/user-blocks/${acceptedRenterId}`, {
        method: 'DELETE',
        headers: ownerHeaders,
      })).status, 204);

      for (let drain = 0; drain < 10; drain += 1) {
        if (await drainNotificationOutbox({ limit: 100 }) === 0) break;
      }
      const ownerNotifications = await fetch(`${baseUrl}/v1/notifications?limit=100`, {
        headers: ownerHeaders,
      });
      assert.equal(ownerNotifications.status, 200);
      const messageNotifications = (await ownerNotifications.json()).notifications
        .filter((notification) => notification.kind === 'message_received'
          && notification.threadId === b7Thread.id);
      assert.equal(messageNotifications.length, 1);
      const messageOutbox = await setupPool.query(
        `SELECT channel, status, attempt_count
         FROM notification_outbox
         WHERE event_key = $1
         ORDER BY channel`,
        [`message:${sentMessage.id}`],
      );
      assert.deepEqual(messageOutbox.rows.map((row) => row.channel), ['in_app', 'push']);
      assert.ok(messageOutbox.rows.every((row) => ['sent', 'suppressed'].includes(row.status)));
      assert.ok(messageOutbox.rows.every((row) => row.attempt_count === 1));

      const deepLinkFallback = await fetch(
        `${baseUrl}/v1/open/booking/${acceptedBookingId}`,
      );
      assert.equal(deepLinkFallback.status, 200);
      assert.match(await deepLinkFallback.text(), /In der App öffnen/);

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
        `INSERT INTO listings (id, owner_id, payload, is_active, status)
         VALUES (
           'auth-user-listing', 'auth-user',
           '{"id":"auth-user-listing","ownerId":"auth-user","title":"Private title","description":"Call me at +49123456789","photos":["private-photo-url"],"status":"paused","isActive":false}'::jsonb,
           false, 'paused'
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
