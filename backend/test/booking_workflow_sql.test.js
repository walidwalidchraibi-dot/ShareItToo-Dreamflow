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
