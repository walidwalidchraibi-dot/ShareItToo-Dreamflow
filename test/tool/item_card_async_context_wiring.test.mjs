import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const source = readFileSync(
  new URL('../../lib/widgets/item_card.dart', import.meta.url),
  'utf8',
);

test('wishlist load cannot update a disposed item card', () => {
  assert.match(
    source,
    /final id = await DataService\.getWishlistForItem\(widget\.itemId\);\s+if \(!mounted\) return;\s+setState/u,
  );
});

test('first wishlist assignment guards every post-dialog UI access', () => {
  assert.match(
    source,
    /final sel = await WishlistSelectionSheet\.showAdd\(context\);\s+if \(!mounted\) return;[\s\S]*?await DataService\.setItemWishlist\(widget\.itemId, sel\);\s+if \(!mounted\) return;\s+setState[\s\S]*?context\.read<LocalizationController>\(\)/u,
  );
});

test('manage and move paths recheck lifecycle before context and state use', () => {
  assert.match(
    source,
    /showManageOptions\(context\);\s+if \(!mounted\) return;[\s\S]*?showMove\(context,[\s\S]*?if \(!mounted\) return;[\s\S]*?setItemWishlist\(widget\.itemId, sel\);\s+if \(!mounted\) return;\s+setState/u,
  );
  assert.match(
    source,
    /removeItemFromWishlist\(widget\.itemId\);\s+if \(!mounted\) return;\s+setState/u,
  );
});

test('lifecycle fix contains no timing or lint accommodation', () => {
  assert.doesNotMatch(source, /ignore:\s*use_build_context_synchronously/u);
  assert.doesNotMatch(source, /Future(?:<void>)?\.delayed|Timer\s*\(/u);
});
