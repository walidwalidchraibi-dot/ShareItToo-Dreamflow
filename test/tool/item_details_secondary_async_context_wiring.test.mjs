import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const source = readFileSync(
  new URL('../../lib/widgets/item_details_overlay.dart', import.meta.url),
  'utf8',
);
const regression = readFileSync(
  new URL('../../scripts/technical_regression_check.sh', import.meta.url),
  'utf8',
);
const sheetState = source.match(
  /class _ItemDetailsSheetState[\s\S]*?\nclass _/u,
)?.[0];
const pageOverflow = source.match(
  /onPressed: \(\) async \{\s+final choice =\s+await showSITOverflowMenu<String>[\s\S]*?\n              \},/u,
)?.[0];
const countdown = source.match(
  /void _onTick\(Duration elapsed\) async \{[\s\S]*?\n  \}/u,
)?.[0];
const fallbackAction = source.match(
  /class _ExpressFallbackSheetState[\s\S]*?onPressed: \(\) async \{[\s\S]*?\n                      \},/u,
)?.[0];

assert.ok(sheetState, 'expected item-details sheet State');
assert.ok(pageOverflow, 'expected item-details overflow action');
assert.ok(countdown, 'expected express countdown callback');
assert.ok(fallbackAction, 'expected express fallback action');

test('sheet share and range selection recheck their owning State', () => {
  assert.match(
    sheetState,
    /catch \(e\) \{\s+f\.debugPrint\('\[share\] failed: \$e'\);\s+if \(!mounted\) return;\s+await AppPopup\.toast\(context,/u,
  );
  assert.match(
    sheetState,
    /getUnavailableRangesForItem\(widget\.item\.id\);\s+if \(!mounted\) return;[\s\S]*?final picked = await Navigator\.of\(context\)\.push<DateTimeRange>[\s\S]*?\);\s+if \(!mounted\) return;\s+if \(picked != null\)/u,
  );
});

test('sheet wishlist management proves lifecycle after every dialog and write', () => {
  assert.match(
    sheetState,
    /showManageOptions\(context\);\s+if \(!mounted\) return;\s+if \(choice == 'move'\)[\s\S]*?showMove\(context,[\s\S]*?\);\s+if \(!mounted\) return;/u,
  );
  assert.match(
    sheetState,
    /setItemWishlist\(widget\.item\.id, sel\);\s+if \(!mounted\) return;\s+setState\(\(\) => _wishlistId = sel\)/u,
  );
  assert.match(
    sheetState,
    /removeItemFromWishlist\(widget\.item\.id\);\s+if \(!mounted\) return;\s+setState\(\(\) => _wishlistId = null\)/u,
  );
});

test('listing overflow proves its exact build context in every async branch', () => {
  assert.match(
    pageOverflow,
    /if \(!context\.mounted \|\| choice == null\) return;\s+switch \(choice\)/u,
  );
  assert.match(
    pageOverflow,
    /Clipboard\.setData[\s\S]*?if \(!context\.mounted\) break;\s+await AppPopup\.toast\(context,[\s\S]*?catch \(e\)[\s\S]*?if \(!context\.mounted\) break;\s+await AppPopup\.toast\(context,/u,
  );
  assert.match(
    pageOverflow,
    /getCurrentUser\(\);\s+if \(current == null \|\| !context\.mounted\) break;[\s\S]*?if \(result == null \|\| !context\.mounted\) break;[\s\S]*?addSystemMessageToThread[\s\S]*?if \(!context\.mounted\) break;\s+await Navigator\.of\(context\)\.push/u,
  );
});

test('express feedback proves its owning or exact callback context', () => {
  assert.match(
    countdown,
    /await AppPopup\.toast\(context,[\s\S]*?if \(!mounted\) return;\s+Navigator\.of\(context\)\.maybePop\(\);/u,
  );
  assert.match(
    fallbackAction,
    /if \(context\.mounted\) \{\s+Navigator\.of\(context\)\.maybePop\(\);\s+\}/u,
  );
});

test('secondary context fixes are permanent and add no accommodation', () => {
  assert.match(
    regression,
    /node --test test\/tool\/item_details_secondary_async_context_wiring\.test\.mjs/u,
  );
  for (const value of [sheetState, pageOverflow, countdown, fallbackAction]) {
    assert.doesNotMatch(value, /ignore:\s*use_build_context_synchronously/u);
    assert.doesNotMatch(value, /Future(?:<void>)?\.delayed|Timer\s*\(/u);
  }
});
