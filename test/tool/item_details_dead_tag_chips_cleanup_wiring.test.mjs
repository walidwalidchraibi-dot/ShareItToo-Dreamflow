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

test('item details page cannot regain its unused compact range formatter', () => {
  const pageState = source.match(
    /class _ItemDetailsPageState[\s\S]*?class _ItemMetaSection/u,
  )?.[0] ?? '';
  assert.doesNotMatch(pageState, /String _formatRange\s*\(/u);
  assert.match(pageState, /Future<void> _sendRequest\s*\(\)/u);
  assert.match(pageState, /DataService\.checkAvailability\(/u);
  assert.match(pageState, /DataService\.addRentalRequest\(req\)/u);
  assert.match(pageState, /String _priceWithUnit\s*\(/u);
  assert.match(pageState, /String _formatRangeForButton\s*\(/u);
});
