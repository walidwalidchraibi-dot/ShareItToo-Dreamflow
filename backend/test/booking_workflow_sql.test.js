import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import test from 'node:test';

const workflowPath = resolve(import.meta.dirname, '../src/booking_workflow.js');

test('booking creation binds its shared creation instant as timestamptz everywhere', async () => {
  const source = await readFile(workflowPath, 'utf8');
  const insert = source.match(
    /INSERT INTO bookings \([\s\S]*?private_status_confirmed_at[\s\S]*?\n     \)`/u,
  )?.[0] ?? '';

  assert.notEqual(insert, '');
  assert.match(
    insert,
    /\$25::timestamptz, \$25::timestamptz,[\s\S]*THEN \$25::timestamptz ELSE NULL::timestamptz END/u,
  );
  assert.doesNotMatch(insert, /\$24::jsonb, \$25, \$25,/u);
});

test('missing owner pilot acceptance is translated into a client error', async () => {
  const source = await readFile(workflowPath, 'utf8');

  assert.match(
    source,
    /function requiredPrivatePilotOwnerAcceptance[\s\S]*error instanceof PrivatePilotValidationError[\s\S]*new BookingWorkflowError\(400, error\.code\)/u,
  );
  assert.equal(
    source.match(/requiredPrivatePilotOwnerAcceptance\(candidate\)/gu)?.length,
    3,
  );
});

test('private booking eligibility is rechecked from persisted state at quote, request and acceptance', async () => {
  const source = await readFile(workflowPath, 'utf8');

  for (const marker of [
    'listing.private_pilot_region_code',
    'owner.private_use_confirmed_at AS owner_private_use_confirmed_at',
    'owner.private_marketplace_review_status AS owner_private_marketplace_review_status',
    'SELECT private_use_confirmed_at, private_marketplace_review_status',
    'assertPrivatePilotStoredListing({',
    'assertPrivatePilotAccountState({',
    'allowedRegions: config.privatePilot?.allowedRegions ?? []',
  ]) assert.match(source, new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'u'));
  assert.equal(
    source.match(/await assertPrivatePilotBookingEligibility\(client,/gu)?.length,
    3,
  );
  assert.match(
    source,
    /listingForBooking\(client, row\.listing_id, \{\s+lock: true,\s+participantIds: \[row\.renter_id\],[\s\S]*allowedRegions: config\.privatePilot\?\.allowedRegions/u,
  );
});

test('locked booking paths serialize users before listings in a deterministic order', async () => {
  const source = await readFile(workflowPath, 'utf8');
  const helperStart = source.indexOf('async function listingForBooking');
  const helperEnd = source.indexOf('async function assertPrivatePilotBookingEligibility');
  const helper = helperStart >= 0 && helperEnd > helperStart
    ? source.slice(helperStart, helperEnd)
    : '';

  assert.notEqual(helper, '');
  assert.match(helper, /ORDER BY id\s+FOR UPDATE/u);
  assert.match(helper, /FOR UPDATE OF listing/u);
  assert.doesNotMatch(helper, /FOR UPDATE OF listing, owner/u);
  assert.ok(helper.indexOf('ORDER BY id') < helper.indexOf('FOR UPDATE OF listing'));
  assert.match(
    source,
    /listingForBooking\(client, listingId, \{\s+lock: true,\s+participantIds: \[actor\.id\]/u,
  );
  assert.match(
    source,
    /listingForBooking\(client, row\.listing_id, \{\s+lock: true,\s+participantIds: \[row\.renter_id\]/u,
  );
});
