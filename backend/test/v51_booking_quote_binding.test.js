import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import test from 'node:test';

const migrationPath = resolve(
  import.meta.dirname,
  '../sql/migrations/016_v51_booking_quotes.up.sql',
);
const workflowPath = resolve(import.meta.dirname, '../src/booking_workflow.js');
const appPath = resolve(import.meta.dirname, '../src/app.js');
const dataServicePath = resolve(import.meta.dirname, '../../lib/services/data_service.dart');
const checkoutScreenPath = resolve(
  import.meta.dirname,
  '../../lib/screens/private_pilot_checkout_screen.dart',
);
const privacyExportPath = resolve(import.meta.dirname, '../src/privacy_export.js');
const retentionInventoryPath = resolve(import.meta.dirname, '../src/retention_inventory.js');

test('V5.1 booking quotes are immutable, expiring, and actor-bound', async () => {
  const migration = await readFile(migrationPath, 'utf8');

  assert.match(migration, /CREATE TABLE IF NOT EXISTS booking_quotes/u);
  assert.match(migration, /renter_id TEXT NOT NULL REFERENCES users\(id\) ON DELETE RESTRICT/u);
  assert.match(migration, /listing_id TEXT NOT NULL REFERENCES listings\(id\) ON DELETE RESTRICT/u);
  assert.match(migration, /quote_hash TEXT NOT NULL CHECK \(quote_hash ~ '\^\[0-9a-f\]\{64\}\$'\)/u);
  assert.match(migration, /CHECK \(issued_at < expires_at\)/u);
  assert.match(
    migration,
    /CREATE TRIGGER booking_quotes_append_only[\s\S]*sit_reject_append_only_mutation\(\)/u,
  );
});

test('quote endpoint persists the exact server quote with a ten-minute lifetime', async () => {
  const source = await readFile(workflowPath, 'utf8');

  assert.match(source, /function quoteBindingPayload\(/u);
  assert.match(source, /const quoteHash = hashCommand\(binding\)/u);
  assert.match(source, /issuedAt\.getTime\(\) \+ \(10 \* 60 \* 1000\)/u);
  assert.match(source, /INSERT INTO booking_quotes/u);
  assert.match(source, /quoteId,[\s\S]*quoteHash,[\s\S]*quotedAt:[\s\S]*expiresAt:/u);
});

test('private-pilot creation fails closed without the stored fresh quote', async () => {
  const source = await readFile(workflowPath, 'utf8');

  assert.match(source, /throw new BookingWorkflowError\(409, 'fresh_booking_quote_required'\)/u);
  assert.match(source, /throw new BookingWorkflowError\(409, 'booking_quote_not_found'\)/u);
  assert.match(source, /throw new BookingWorkflowError\(409, 'booking_quote_expired'\)/u);
  assert.match(source, /throw new BookingWorkflowError\(409, 'booking_quote_changed'\)/u);
  assert.match(
    source,
    /const quoteBinding = privatePilot[\s\S]*await requireFreshBookingQuote/u,
  );
  assert.match(source, /hashCommand\(currentBinding\) === quoteHash/u);
});

test('the app fetches a fresh quote immediately before remote creation', async () => {
  const source = await readFile(dataServicePath, 'utf8');
  const remoteBlock = source.match(
    /if \(BackendConfig\.enabled && !QaRuntimeService\.isEnabled\) \{[\s\S]*?BackendRepository\.createBooking\([\s\S]*?\n    \} else \{/u,
  )?.[0] ?? '';

  assert.notEqual(remoteBlock, '');
  assert.match(remoteBlock, /BackendRepository\.quoteBooking\(createPayload\)/u);
  assert.match(remoteBlock, /createPayload\['quoteId'\] = quoteId/u);
  assert.match(remoteBlock, /createPayload\['quoteHash'\] = quoteHash/u);
  assert.match(remoteBlock, /BackendRepository\.createBooking\([\s\S]*createPayload/u);
});

test('checkout renders the server quote and stays locked without real payment transport', async () => {
  const [app, checkout] = await Promise.all([
    readFile(appPath, 'utf8'),
    readFile(checkoutScreenPath, 'utf8'),
  ]);

  assert.match(
    app,
    /paymentMethodAvailable: config\.payments\.transport === 'stripe'/u,
  );
  assert.match(checkout, /PrivatePilotQuote\.fromServerJson/u);
  assert.match(checkout, /_checkoutQuote = Map<String, dynamic>\.from\(envelope\)/u);
  assert.match(checkout, /_freshQuoteAvailable/u);
  assert.match(checkout, /_paymentMethodAvailable/u);
  assert.match(checkout, /checkoutQuote: _checkoutQuote/u);
  assert.match(checkout, /Bestätigen und bezahlen/u);
});

test('user export and retention inventory include the new quote records', async () => {
  const [privacyExport, retentionInventory] = await Promise.all([
    readFile(privacyExportPath, 'utf8'),
    readFile(retentionInventoryPath, 'utf8'),
  ]);

  assert.match(privacyExport, /FROM booking_quotes WHERE renter_id = \$1 ORDER BY issued_at/u);
  assert.match(privacyExport, /marketplace: \{ listings, bookings, bookingQuotes \}/u);
  assert.match(
    retentionInventory,
    /SELECT 'transactions', 'booking_quotes',[\s\S]*FROM booking_quotes/u,
  );
});
