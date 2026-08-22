import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const source = readFileSync(
  new URL('../../lib/widgets/item_details_overlay.dart', import.meta.url),
  'utf8',
);
const sheetRequest = source.match(
  /class _ItemDetailsSheetState[\s\S]*?Future<void> _sendRequest\(\) async \{[\s\S]*?\n  String _priceWithUnit/u,
)?.[0];
const pageRequest = source.match(
  /class _ItemDetailsPageState[\s\S]*?Future<void> _sendRequest\(\) async \{[\s\S]*?\n  String _priceWithUnit/u,
)?.[0];
const bottomReserve = source.match(
  /Future<void> _handleReserve\(BuildContext context\) async \{[\s\S]*?\n  \}\n\}/u,
)?.[0];
const sentPopup = source.match(
  /Future<void> _showReservationSentPopup[\s\S]*?\n\}\n\nclass _/u,
)?.[0];

assert.ok(sheetRequest, 'expected listing-sheet request flow');
assert.ok(pageRequest, 'expected listing-page request flow');
assert.ok(bottomReserve, 'expected bottom-action reservation flow');
assert.ok(sentPopup, 'expected reservation confirmation popup');

test('sheet and page prove State and root navigator before confirmation UI', () => {
  assert.match(
    sheetRequest,
    /final rootNav = Navigator\.of\(context, rootNavigator: true\);\s+rootNav\.popUntil\(\(route\) => route\.isFirst\);\s+if \(!rootNav\.mounted\) return;\s+await _showReservationSentPopup\(rootNav\.context,/u,
  );
  assert.match(
    pageRequest,
    /clearSavedDateRange\(widget\.item\.id\);\s+await DataService\.clearSavedDeliverySelection\(widget\.item\.id\);\s+if \(!mounted\) return;\s+final rootNav = Navigator\.of\(context, rootNavigator: true\);\s+rootNav\.popUntil\(\(route\) => route\.isFirst\);\s+if \(!rootNav\.mounted\) return;\s+await _showReservationSentPopup\(rootNav\.context,/u,
  );
});

test('bottom reservation proves both State and exact caller context', () => {
  const exactProof = /if \(!mounted \|\| !context\.mounted\) return;/gu;
  assert.equal(bottomReserve.match(exactProof)?.length, 4);
  assert.match(
    bottomReserve,
    /updateRentalRequestTimes\([\s\S]*?if \(!mounted \|\| !context\.mounted\) return;\s+await AppPopup\.toast\(context,[\s\S]*?if \(!context\.mounted\) return;\s+Navigator\.of\(context\)\.maybePop\(\);/u,
  );
  assert.match(
    bottomReserve,
    /final rootNav = Navigator\.of\(context, rootNavigator: true\);\s+rootNav\.popUntil\(\(route\) => route\.isFirst\);\s+if \(!rootNav\.mounted\) return;\s+await _showReservationSentPopup\(rootNav\.context,/u,
  );
});

test('confirmation helper proves the exact navigator context after lookups', () => {
  assert.match(
    sentPopup,
    /_loadOwner\(item\.ownerId\);\s+final range = await DataService\.getRentalRequestById\(requestId\);\s+if \(!context\.mounted\) return;\s+final isDark = Theme\.of\(context\)/u,
  );
  assert.match(sentPopup, /await showGeneralDialog<void>\(\s+context: context,/u);
});

test('reservation completion has no timing or lint accommodation', () => {
  for (const value of [sheetRequest, pageRequest, bottomReserve, sentPopup]) {
    assert.doesNotMatch(value, /ignore:\s*use_build_context_synchronously/u);
    assert.doesNotMatch(value, /Future(?:<void>)?\.delayed|Timer\s*\(/u);
  }
  assert.doesNotMatch(
    source,
    /Future<void>\.delayed\(const Duration\(milliseconds: 120\)\)/u,
  );
});
