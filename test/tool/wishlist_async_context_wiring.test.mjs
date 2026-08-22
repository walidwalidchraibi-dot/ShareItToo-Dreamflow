import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const source = readFileSync(
  new URL('../../lib/widgets/wishlist_selection_sheet.dart', import.meta.url),
  'utf8',
);

test('wishlist dialogs stop after every asynchronous lookup when context is gone', () => {
  assert.equal(
    source.match(/if \(!context\.mounted\) return null;/gu)?.length,
    4,
  );
  assert.equal(
    source.match(
      /DataService\.getWishlists\(\);\s+if \(!context\.mounted\) return null;/gu,
    )?.length,
    2,
  );
  assert.equal(
    source.match(
      /DataService\.getItemsByWishlist\(\);\s+if \(!context\.mounted\) return null;/gu,
    )?.length,
    2,
  );
});

test('wishlist context safety uses no lint suppression or delayed retry', () => {
  assert.doesNotMatch(source, /ignore:\s*use_build_context_synchronously/u);
  assert.doesNotMatch(source, /Future\.delayed|Timer\(|retry/u);
});
