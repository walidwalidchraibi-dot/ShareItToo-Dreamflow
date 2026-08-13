import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ListingValidationError,
  normalizeListingPayload,
  parseCatalogQuery,
  shapePublicListing,
  storageNameFromListingPhoto,
} from '../src/listing_catalog.js';

const validListing = {
  title: 'Bosch Bohrmaschine',
  description: 'Voll funktionsfähig mit Koffer und Zubehör.',
  categoryId: 'cat8',
  subcategory: 'Bohrmaschinen',
  pricePerDay: 12,
  priceRaw: 12,
  currency: 'EUR',
  photos: ['https://shareittoo.com/api/v1/uploads/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa-full.webp'],
  locationText: 'Musterstraße 1, Berlin',
  city: 'Berlin',
  country: 'Deutschland',
  lat: 52.5201,
  lng: 13.4051,
  condition: 'good',
  status: 'active',
};

test('listing normalization enforces a complete active catalogue item', () => {
  const listing = normalizeListingPayload(validListing, { id: 'listing-1', ownerId: 'owner' });
  assert.equal(listing.id, 'listing-1');
  assert.equal(listing.ownerId, 'owner');
  assert.equal(listing.minDays, 1);
  assert.equal(listing.maxDays, 30);
  assert.equal(listing.deposit, null);
  assert.equal(listing.protectionModel, 'none');
  assert.equal(listing.availabilityMode, 'calendar');
  assert.equal(listing.isActive, true);
});

test('legacy deposit and protection input is neutralized for the launch product', () => {
  const listing = normalizeListingPayload({
    ...validListing,
    deposit: 500,
    protectionModel: 'standard',
  }, { id: 'listing-1', ownerId: 'owner' });
  assert.equal(listing.deposit, null);
  assert.equal(listing.protectionModel, 'none');
});

test('active listings require an image while drafts may remain private without one', () => {
  assert.throws(
    () => normalizeListingPayload({ ...validListing, photos: [] }, { id: 'listing-1', ownerId: 'owner' }),
    (error) => error instanceof ListingValidationError && error.code === 'listing_photo_required',
  );
  const draft = normalizeListingPayload(
    { ...validListing, photos: [], status: 'draft', isActive: false },
    { id: 'listing-1', ownerId: 'owner' },
  );
  assert.equal(draft.status, 'draft');
  assert.equal(draft.isActive, false);
});

test('public listings disclose only an approximate location', () => {
  const shaped = shapePublicListing({ ...validListing, geohash: 'private-geohash' }, { distanceKm: 1.26 });
  assert.equal(shaped.locationText, 'Berlin, Deutschland');
  assert.equal(shaped.lat, 52.52);
  assert.equal(shaped.lng, 13.41);
  assert.equal(shaped.geohash, '');
  assert.equal(shaped.distanceKm, 1.3);
});

test('catalog query parsing bounds filters and pagination', () => {
  const query = parseCatalogQuery({
    q: ' Kamera ',
    categories: 'cat3,cat8',
    conditions: 'good,invalid',
    lat: '52.52',
    lng: '13.405',
    radiusKm: '60',
    sort: 'distance',
    limit: '500',
    offset: '99999',
  });
  assert.equal(query.q, 'Kamera');
  assert.deepEqual(query.categories, ['cat3', 'cat8']);
  assert.deepEqual(query.conditions, ['good']);
  assert.equal(query.radiusKm, 60);
  assert.equal(query.sort, 'distance');
  assert.equal(query.limit, 50);
  assert.equal(query.offset, 0);
});

test('only canonical server-generated full-size listing images can be bound', () => {
  const base = 'https://shareittoo.com/api/v1';
  assert.equal(
    storageNameFromListingPhoto(validListing.photos[0], base),
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa-full.webp',
  );
  assert.equal(storageNameFromListingPhoto('https://example.com/image.webp', base), null);
  assert.equal(
    storageNameFromListingPhoto(
      'https://shareittoo.com/api/v1/uploads/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa-thumb.webp',
      base,
    ),
    null,
  );
});
