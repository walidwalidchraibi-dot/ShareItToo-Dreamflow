import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const requestDetail = readFileSync(
  new URL('../../lib/screens/request_detail_screen.dart', import.meta.url),
  'utf8',
);
const dialog = readFileSync(
  new URL(
    '../../lib/widgets/private_pilot_owner_acceptance_dialog.dart',
    import.meta.url,
  ),
  'utf8',
);
const pricing = readFileSync(
  new URL('../../lib/services/private_pilot_pricing.dart', import.meta.url),
  'utf8',
);

test('owner acceptance reconstructs the strict immutable request snapshot', () => {
  assert.match(pricing, /PrivatePilotQuote\.fromRentalRequestSnapshot/u);
  for (const field of [
    'quotedDays',
    'quotedPricePerDayMinor',
    'quotedBaseRentalMinor',
    'quotedDiscountPercent',
    'quotedDiscountMinor',
    'quotedRentalSubtotalMinor',
    'quotedPlatformFeeMinor',
    'quotedTotalMinor',
    'quotedOwnerPayoutMinor',
    'quotedCurrency',
  ]) {
    assert.match(pricing, new RegExp(`request\\.${field}`, 'u'));
  }
  assert.match(
    pricing,
    /request\.quotedOwnerPayoutMinor != quote\.rentalSubtotalMinor/u,
  );
});

test('remote owner acceptance is disabled when the server snapshot is invalid', () => {
  assert.match(
    requestDetail,
    /usesRemoteBackend && serverQuote == null[\s\S]*?Annahme gesperrt/u,
  );
  assert.match(
    requestDetail,
    /onAccept: displayedQuote == null\s+\? null/u,
  );
  assert.match(
    requestDetail,
    /Kein verbindlicher Preis verfügbar\. Die Annahme bleibt gesperrt\./u,
  );
});

test('local fallback is visibly nonbinding and isolated from the remote branch', () => {
  assert.match(
    requestDetail,
    /serverQuote \?\?[\s\S]*?usesRemoteBackend[\s\S]*?PrivatePilotPricing\.quoteForItem/u,
  );
  assert.match(requestDetail, /Lokaler Testpreis · kein Echtgeld/u);
  assert.match(dialog, /Lokaler Testpreis · kein Echtgeld/u);
});

test('owner sees exact rent, renter fee, renter total and intended payout', () => {
  for (const label of [
    'Privater Mietpreis',
    'SIT-Plattformbeitrag des Mieters',
    'Gesamtpreis des Mieters',
    'Deine vorgesehene Auszahlung',
  ]) {
    assert.match(requestDetail, new RegExp(label, 'u'));
  }
  assert.match(dialog, /displayedQuote\.rentalSubtotalMinor/u);
  assert.match(dialog, /displayedQuote\.platformFeeMinor/u);
  assert.match(dialog, /displayedQuote\.totalMinor/u);
});

test('acceptance dialog and backend transition receive the same guarded quote flow', () => {
  assert.match(
    requestDetail,
    /showPrivatePilotOwnerAcceptanceDialog\([\s\S]*?quote: displayedQuote,[\s\S]*?isBindingServerQuote: serverQuote != null/u,
  );
  assert.match(
    requestDetail,
    /if \(declarations == null\) return;[\s\S]*?updateRentalRequestStatus\([\s\S]*?status: 'accepted'/u,
  );
  assert.match(dialog, /PrivatePilotConfig\.ownerAcceptanceDeclaration/u);
  assert.match(
    dialog,
    /PrivatePilotQuote\.fromRentalRequestSnapshot\(request\)/u,
  );
  assert.match(
    dialog,
    /onPressed: confirmed && displayedQuote != null/u,
  );
  assert.match(
    dialog,
    /onChanged: displayedQuote == null\s+\? null/u,
  );
  assert.match(dialog, /Preisprüfung fehlgeschlagen/u);
});

test('every alternative owner-acceptance surface reaches the guarded dialog', () => {
  for (const relative of [
    '../../lib/screens/ongoing_owner_detail_screen.dart',
    '../../lib/screens/owner_requests_screen.dart',
    '../../lib/screens/message_thread_screen.dart',
  ]) {
    const caller = readFileSync(new URL(relative, import.meta.url), 'utf8');
    assert.match(caller, /showPrivatePilotOwnerAcceptanceDialog\(/u);
  }
});
