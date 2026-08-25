#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const sourcePaths = {
  dataService: 'lib/services/data_service.dart',
  accountDeletion: 'lib/services/account_deletion_service.dart',
  privacyInfo: 'lib/screens/privacy_info_screen.dart',
  legalPrivacy: 'lib/screens/legal_privacy_screen.dart',
  mainNavigation: 'lib/navigation/main_navigation.dart',
  itemDetails: 'lib/widgets/item_details_overlay.dart',
  login: 'lib/screens/login_screen.dart',
  register: 'lib/screens/register_screen.dart',
  backendApp: 'backend/src/app.js',
  backendExport: 'backend/src/privacy_export.js',
  backendWorkflow: 'backend/src/rental_cart_workflow.js',
  migration: 'backend/sql/migrations/027_g2_persistent_rental_cart.up.sql',
};

function fail(message) {
  throw new Error(message);
}

function object(value, label) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${label} must be an object.`);
  }
  return value;
}

function exactKeys(value, expected, label) {
  if (Object.keys(value).sort().join(',') !== expected.slice().sort().join(',')) {
    fail(`${label} must contain exactly: ${expected.join(', ')}.`);
  }
}

function exactArray(value, expected, label) {
  if (!Array.isArray(value) || value.join(',') !== expected.join(',')) {
    fail(`${label} must contain exactly: ${expected.join(', ')}.`);
  }
}

function source(root, sourceTexts, path) {
  return Object.hasOwn(sourceTexts, path)
    ? sourceTexts[path]
    : readFileSync(resolve(root, path), 'utf8');
}

function count(value, pattern) {
  return [...value.matchAll(pattern)].length;
}

function includesEvery(value, markers, label) {
  for (const marker of markers) {
    if (!value.includes(marker)) fail(`${label} is missing ${marker}.`);
  }
}

export function validateG2DataLifecycle({
  root,
  lifecycleManifest,
  sourceTexts = {},
}) {
  const lifecycle = object(lifecycleManifest, 'store/g2-data-lifecycle.json');
  exactKeys(lifecycle, [
    'schemaVersion',
    'state',
    'terminology',
    'currentSavedItems',
    'persistentData',
    'boundaries',
  ], 'G2 lifecycle manifest');
  if (lifecycle.schemaVersion !== 1
      || lifecycle.state !== 'g2b-persistent-cart-active') {
    fail('G2 lifecycle manifest must bind the active G2B state.');
  }

  const terminology = object(lifecycle.terminology, 'terminology');
  exactKeys(terminology, ['savedItems', 'cartArea', 'projectContainer'], 'terminology');
  if (terminology.savedItems !== 'Gemerkt'
      || terminology.cartArea !== 'Mietkorb'
      || terminology.projectContainer !== 'Projektkorb') {
    fail('G2 terminology must use the approved names.');
  }

  const savedItems = object(lifecycle.currentSavedItems, 'currentSavedItems');
  exactKeys(savedItems, [
    'runtimeStatus',
    'binding',
    'storageScope',
    'canonicalKey',
    'legacyKeys',
    'exportStatus',
    'accountDeletionStatus',
    'retentionRule',
  ], 'currentSavedItems');
  if (savedItems.canonicalKey !== 'wishlist_state_v2') {
    fail('currentSavedItems.canonicalKey must bind the atomic saved-state document.');
  }
  exactArray(savedItems.legacyKeys, [
    'saved_item_ids',
    'wishlists_meta_v1',
    'wishlist_assign_v1',
  ], 'currentSavedItems.legacyKeys');
  if (savedItems.runtimeStatus !== 'active-local-device'
      || savedItems.binding !== 'non-binding-no-reservation'
      || savedItems.exportStatus !== 'implemented-local-device-section'
      || savedItems.accountDeletionStatus !== 'implemented-local-purge') {
    fail('Current Gemerkt lifecycle is incomplete or overstated.');
  }

  const persistent = object(lifecycle.persistentData, 'persistentData');
  exactKeys(persistent, ['rentalCart', 'projectCart'], 'persistentData');
  const rentalCart = object(persistent.rentalCart, 'persistentData.rentalCart');
  exactKeys(rentalCart, [
    'runtimeStatus',
    'binding',
    'storageKeys',
    'serverDatasets',
    'exportStatus',
    'accountDeletionStatus',
    'retentionRule',
    'serverAuthoritativeRecheck',
  ], 'persistentData.rentalCart');
  exactArray(
    rentalCart.storageKeys,
    ['rental_cart_v1', 'rental_cart_sync_owner_v1'],
    'rentalCart.storageKeys',
  );
  exactArray(
    rentalCart.serverDatasets,
    ['rental_carts', 'rental_cart_items'],
    'rentalCart.serverDatasets',
  );
  if (rentalCart.runtimeStatus !== 'active-guest-local-account-server'
      || rentalCart.binding !== 'non-binding-no-reservation-no-hold'
      || rentalCart.exportStatus !== 'implemented-local-and-account-export'
      || rentalCart.accountDeletionStatus
        !== 'implemented-explicit-server-delete-and-local-purge'
      || rentalCart.retentionRule
        !== 'user-controlled-until-removal-confirmed-account-deletion-or-app-data-clear'
      || rentalCart.serverAuthoritativeRecheck !== true) {
    fail('Persistent rental-cart lifecycle is incomplete or overstated.');
  }

  const projectCart = object(persistent.projectCart, 'persistentData.projectCart');
  exactKeys(projectCart, [
    'runtimeStatus',
    'binding',
    'storageKeys',
    'serverDatasets',
    'exportStatus',
    'accountDeletionStatus',
    'retentionRule',
  ], 'persistentData.projectCart');
  exactArray(projectCart.storageKeys, ['project_cart_v1'], 'projectCart.storageKeys');
  exactArray(
    projectCart.serverDatasets,
    ['rental_cart_projects'],
    'projectCart.serverDatasets',
  );
  if (projectCart.runtimeStatus !== 'active-guest-local-account-server'
      || projectCart.binding !== 'organizational-container-no-group-request'
      || projectCart.exportStatus !== 'implemented-local-and-account-export'
      || projectCart.accountDeletionStatus !== 'implemented-cascade-and-local-purge'
      || projectCart.retentionRule
        !== 'user-controlled-until-removal-confirmed-account-deletion-or-app-data-clear') {
    fail('Persistent project-cart lifecycle is incomplete or overstated.');
  }

  const boundaries = object(lifecycle.boundaries, 'boundaries');
  exactKeys(boundaries, [
    'persistentCartEnabled',
    'projectCartEnabled',
    'newDataCollectionEnabled',
    'reservationCreatedByCart',
    'availabilityHoldCreatedByCart',
    'groupRequestEnabled',
    'paymentChanged',
    'retentionPeriodInvented',
    'legalApprovalChanged',
    'historicalSnapshotsChanged',
    'productionChanged',
  ], 'boundaries');
  if (boundaries.persistentCartEnabled !== true
      || boundaries.projectCartEnabled !== true
      || boundaries.newDataCollectionEnabled !== true) {
    fail('G2B persistent cart activation must be recorded.');
  }
  for (const key of [
    'reservationCreatedByCart',
    'availabilityHoldCreatedByCart',
    'groupRequestEnabled',
    'paymentChanged',
    'retentionPeriodInvented',
    'legalApprovalChanged',
    'historicalSnapshotsChanged',
    'productionChanged',
  ]) {
    if (boundaries[key] !== false) fail(`boundaries.${key} must remain false.`);
  }

  const dataService = source(root, sourceTexts, sourcePaths.dataService);
  includesEvery(dataService, [
    "'wishlist_state_v2'",
    "'rental_cart_v1'",
    "'project_cart_v1'",
    "'rental_cart_sync_owner_v1'",
    'syncGuestRentalCartAfterAuthentication',
    'BackendRepository.putRentalCartProject',
    'BackendRepository.putRentalCartItem',
    'BackendRepository.recheckRentalCart',
    "'persistentRentalCart': true",
    "'persistentProjectCart': true",
    'prefs.remove(_rentalCartKey)',
    'prefs.remove(_wishlistStateKey)',
    'prefs.remove(_projectCartKey)',
    'prefs.remove(_rentalCartSyncOwnerKey)',
    'canSyncGuestCartToAccount',
    'canReadLocalRentalCart',
  ], 'DataService G2B lifecycle');
  const syncStart = dataService.indexOf('syncGuestRentalCartAfterAuthentication');
  const syncEnd = dataService.indexOf('static Future<RentalCart> getRentalCart', syncStart);
  const syncSource = dataService.slice(syncStart, syncEnd);
  const lastRemoteUpsert = Math.max(
    syncSource.lastIndexOf('BackendRepository.putRentalCartProject'),
    syncSource.lastIndexOf('BackendRepository.putRentalCartItem'),
  );
  const localPurge = syncSource.indexOf('prefs.remove(_rentalCartKey)');
  if (lastRemoteUpsert < 0 || localPurge <= lastRemoteUpsert) {
    fail('Guest cart must be purged only after all server upserts complete.');
  }

  const deletion = source(root, sourceTexts, sourcePaths.accountDeletion);
  if (count(deletion, /DataService\.clearSavedItemsForAccountDeletion\(\)/gu) !== 2) {
    fail('Both confirmed account deletion paths must purge local G2 data.');
  }

  const backendApp = source(root, sourceTexts, sourcePaths.backendApp);
  includesEvery(backendApp, [
    "app.get('/v1/rental-cart'",
    "app.put('/v1/rental-cart/projects/:id'",
    "app.put('/v1/rental-cart/items/:id'",
    "app.post('/v1/rental-cart/recheck'",
    "DELETE FROM rental_carts WHERE user_id = $1",
  ], 'Backend rental-cart API and deletion');
  const backendExport = source(root, sourceTexts, sourcePaths.backendExport);
  includesEvery(backendExport, [
    'rentalCartProjects',
    'rentalCartItems',
    'reservationCreated: false',
  ], 'Backend account export');
  const workflow = source(root, sourceTexts, sourcePaths.backendWorkflow);
  includesEvery(workflow, [
    'quoteBooking',
    'persist: false',
    'recheckRentalCart',
    'reservationCreated: false',
    "quote_status = 'unavailable'",
  ], 'Rental-cart workflow');
  if (/createBooking/u.test(workflow) || /INSERT\s+INTO\s+bookings/iu.test(workflow)) {
    fail('Rental-cart workflow must never create a booking or reservation.');
  }
  const migration = source(root, sourceTexts, sourcePaths.migration);
  includesEvery(migration, [
    'CREATE TABLE IF NOT EXISTS rental_carts',
    'CREATE TABLE IF NOT EXISTS rental_cart_projects',
    'CREATE TABLE IF NOT EXISTS rental_cart_items',
    'ON DELETE CASCADE',
  ], 'G2B migration');
  if (/hold_expires_at/u.test(migration) || /REFERENCES\s+bookings/iu.test(migration)) {
    fail('Rental-cart persistence must not create a hold or booking relationship.');
  }

  const mainNavigation = source(root, sourceTexts, sourcePaths.mainNavigation);
  if (!mainNavigation.includes('index != 0 && index != 1 && index != 4')) {
    fail('Guests must be able to open the local Mietkorb tab.');
  }
  const itemDetails = source(root, sourceTexts, sourcePaths.itemDetails);
  includesEvery(itemDetails, [
    "const Text('In den Mietkorb')",
    'DataService.addRentalCartItem',
    'noch nicht reserviert',
  ], 'Item detail Mietkorb entry');
  for (const path of [sourcePaths.login, sourcePaths.register]) {
    if (!source(root, sourceTexts, path)
      .includes('syncGuestRentalCartAfterAuthentication')) {
      fail(`${path} must reconcile guest intent after authentication.`);
    }
  }

  const privacyInfo = source(root, sourceTexts, sourcePaths.privacyInfo);
  includesEvery(privacyInfo, [
    'DataService.exportSavedItemsForPrivacy()',
    "export['localDevice']",
    'Mietkorb',
  ], 'Privacy export and disclosure');
  const legalPrivacy = source(root, sourceTexts, sourcePaths.legalPrivacy);
  includesEvery(legalPrivacy, [
    '„Gemerkt“ bleibt unverbindlich und ist keine Reservierung.',
    'Im Mietkorb – noch nicht reserviert',
    'bis zur Entfernung durch den Nutzer',
  ], 'Legal privacy copy');

  return {
    state: lifecycle.state,
    currentSavedItemKeyCount: savedItems.legacyKeys.length + 1,
    persistentCartEnabled: true,
    projectCartEnabled: true,
    reservationCreatedByCart: false,
  };
}

function main() {
  const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
  const lifecycleManifest = JSON.parse(
    readFileSync(resolve(root, 'store/g2-data-lifecycle.json'), 'utf8'),
  );
  const result = validateG2DataLifecycle({ root, lifecycleManifest });
  process.stdout.write(
    `G2 data lifecycle: PASS (state=${result.state}, savedKeys=${result.currentSavedItemKeyCount}, persistentCart=true, projectCart=true, reservationCreated=false)\n`,
  );
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (error) {
    process.stderr.write(`ERROR: ${error.message}\n`);
    process.exitCode = 1;
  }
}
