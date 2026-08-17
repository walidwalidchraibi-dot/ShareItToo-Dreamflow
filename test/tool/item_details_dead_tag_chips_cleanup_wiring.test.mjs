import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const source = readFileSync(
  new URL('../../lib/widgets/item_details_overlay.dart', import.meta.url),
  'utf8',
);

test('item details cannot regain the unused tag-chip presentation class', () => {
  assert.doesNotMatch(source, /class _TagChips\b/u);
  assert.doesNotMatch(source, /_TagChips\s*\(/u);
});

test('active delivery and category presentation remain intact', () => {
  assert.match(source, /class _DeliveryMetaChips extends StatelessWidget/u);
  assert.match(source, /item\.offersDeliveryAtDropoff/u);
  assert.match(source, /item\.offersPickupAtReturn/u);
  assert.match(source, /class _CategoryNameById extends StatelessWidget/u);
  assert.match(source, /DataService\.getCategories\(\)/u);
  assert.match(source, /DataService\.coarseCategoryFor\(cat\.name\)/u);
});

test('active description collapse behavior remains next to the removed block', () => {
  const description = source.match(
    /class _CollapsingDescriptionSlot[\s\S]*?class _CollapsingDescriptionSlotState[\s\S]*?class /u,
  )?.[0] ?? '';
  assert.match(description, /required this\.text/u);
  assert.match(description, /required this\.ownerBoxKey/u);
  assert.match(description, /SchedulerBinding\.instance\.addPostFrameCallback/u);
  assert.match(description, /_measureOwner\(\)/u);
  assert.match(description, /_expanded/u);
});

test('listing details still keep price booking and owner actions', () => {
  assert.match(source, /listingCustomerPriceText\(/u);
  assert.match(source, /DataService\.addRentalRequest\(req\)/u);
  assert.match(source, /PrivatePilotCheckoutScreen/u);
  assert.match(source, /PublicProfileScreen/u);
  assert.match(source, /WishlistSelectionSheet/u);
});
