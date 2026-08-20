#!/usr/bin/env node

import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const sourcePaths = {
  dataService: 'lib/services/data_service.dart',
  accountDeletion: 'lib/services/account_deletion_service.dart',
  privacyInfo: 'lib/screens/privacy_info_screen.dart',
  legalPrivacy: 'lib/screens/legal_privacy_screen.dart',
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

function text(root, sourceTexts, path) {
  return Object.hasOwn(sourceTexts, path)
    ? sourceTexts[path]
    : readFileSync(resolve(root, path), 'utf8');
}

function count(value, pattern) {
  return [...value.matchAll(pattern)].length;
}

function collectRuntimePersistenceText(root, override) {
  if (override !== undefined) return override;
  const roots = ['lib', 'backend/src', 'backend/sql/migrations'];
  const values = [];
  const visit = (path) => {
    if (!existsSync(path)) return;
    const metadata = statSync(path);
    if (metadata.isDirectory()) {
      for (const entry of readdirSync(path)) visit(resolve(path, entry));
      return;
    }
    if (/\.(?:dart|js|mjs|sql)$/u.test(path)) {
      values.push(readFileSync(path, 'utf8'));
    }
  };
  for (const path of roots) visit(resolve(root, path));
  return values.join('\n');
}

function assertInactivePersistentData(value, label) {
  const item = object(value, label);
  exactKeys(item, [
    'runtimeStatus',
    'storageKeys',
    'serverDatasets',
    'exportStatus',
    'accountDeletionStatus',
    'retentionStatus',
  ], label);
  if (item.runtimeStatus !== 'inactive-not-collected'
      || item.exportStatus !== 'required-before-activation'
      || item.accountDeletionStatus !== 'required-before-activation'
      || item.retentionStatus !== 'open-before-activation'
      || !Array.isArray(item.storageKeys)
      || item.storageKeys.length !== 0
      || !Array.isArray(item.serverDatasets)
      || item.serverDatasets.length !== 0) {
    fail(`${label} must remain inactive and fail closed before G2B.`);
  }
}

export function validateG2DataLifecycle({
  root,
  lifecycleManifest,
  sourceTexts = {},
  runtimePersistenceText,
}) {
  const lifecycle = object(lifecycleManifest, 'store/g2-data-lifecycle.json');
  exactKeys(lifecycle, [
    'schemaVersion',
    'state',
    'terminology',
    'currentSavedItems',
    'plannedPersistentData',
    'boundaries',
  ], 'G2 lifecycle manifest');
  if (lifecycle.schemaVersion !== 1
      || lifecycle.state !== 'g2a-current-g2b-inactive') {
    fail('G2 lifecycle manifest must bind the active G2A and inactive G2B state.');
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
    'legacyKeys',
    'exportStatus',
    'accountDeletionStatus',
    'retentionRule',
  ], 'currentSavedItems');
  if (savedItems.runtimeStatus !== 'active-local-device'
      || savedItems.binding !== 'non-binding-no-reservation'
      || savedItems.storageScope !== 'local-device-shared-preferences'
      || savedItems.exportStatus !== 'implemented-local-device-section'
      || savedItems.accountDeletionStatus !== 'implemented-local-purge'
      || savedItems.retentionRule
        !== 'user-controlled-until-removal-account-deletion-or-app-data-clear') {
    fail('Current Gemerkt lifecycle is incomplete or overstated.');
  }
  const expectedLegacyKeys = [
    'saved_item_ids',
    'wishlists_meta_v1',
    'wishlist_assign_v1',
  ];
  if (!Array.isArray(savedItems.legacyKeys)
      || savedItems.legacyKeys.join(',') !== expectedLegacyKeys.join(',')) {
    fail('Current Gemerkt lifecycle must bind every real legacy key in order.');
  }

  const planned = object(lifecycle.plannedPersistentData, 'plannedPersistentData');
  exactKeys(planned, ['rentalCart', 'projectCart'], 'plannedPersistentData');
  assertInactivePersistentData(planned.rentalCart, 'plannedPersistentData.rentalCart');
  assertInactivePersistentData(planned.projectCart, 'plannedPersistentData.projectCart');

  const boundaries = object(lifecycle.boundaries, 'boundaries');
  exactKeys(boundaries, [
    'persistentCartEnabled',
    'projectCartEnabled',
    'newDataCollectionEnabled',
    'retentionPeriodInvented',
    'legalApprovalChanged',
    'historicalSnapshotsChanged',
    'productionChanged',
  ], 'boundaries');
  for (const [key, value] of Object.entries(boundaries)) {
    if (value !== false) fail(`boundaries.${key} must remain false in G2L.`);
  }

  const dataService = text(root, sourceTexts, sourcePaths.dataService);
  for (const key of expectedLegacyKeys) {
    if (!dataService.includes(`'${key}'`)) {
      fail(`DataService is missing the real Gemerkt key ${key}.`);
    }
  }
  for (const marker of [
    'exportSavedItemsForPrivacy',
    "'scope': 'local-device'",
    "'binding': 'non-binding-no-reservation'",
    "'persistentRentalCart': false",
    "'persistentProjectCart': false",
    'clearSavedItemsForAccountDeletion',
  ]) {
    if (!dataService.includes(marker)) fail(`DataService is missing G2 lifecycle marker: ${marker}.`);
  }
  for (const key of ['_savedItemsKey', '_wishlistsMetaKey', '_wishlistAssignKey']) {
    if (!dataService.includes(`prefs.remove(${key})`)) {
      fail(`Account deletion does not remove ${key}.`);
    }
  }

  const deletion = text(root, sourceTexts, sourcePaths.accountDeletion);
  if (count(deletion, /DataService\.clearSavedItemsForAccountDeletion\(\)/gu) !== 2) {
    fail('Both remote and local confirmed account deletion paths must purge Gemerkt.');
  }
  const privacyInfo = text(root, sourceTexts, sourcePaths.privacyInfo);
  for (const marker of [
    'DataService.exportSavedItemsForPrivacy()',
    "export['localDevice']",
    'lokal auf diesem Gerät gespeicherte Merklisten und Artikelzuordnungen',
  ]) {
    if (!privacyInfo.includes(marker)) fail(`Privacy export is missing G2 marker: ${marker}.`);
  }
  const legalPrivacy = text(root, sourceTexts, sourcePaths.legalPrivacy);
  for (const marker of [
    '„Gemerkt“ ist unverbindlich und keine Reservierung.',
    'noch keinen persistenten Miet- oder Projektkorb',
    'eigene Export-, Lösch- und Aufbewahrungsabdeckung erforderlich',
  ]) {
    if (!legalPrivacy.includes(marker)) fail(`Privacy copy is missing G2 marker: ${marker}.`);
  }

  const runtime = collectRuntimePersistenceText(root, runtimePersistenceText);
  if (/rental_cart_v1|project_cart_v1|CREATE\s+TABLE[^;]*(?:rental|project)_carts?|\/v1\/(?:rental|project)-carts?/iu.test(runtime)) {
    fail('Persistent rental/project cart code exists while the G2 lifecycle remains inactive.');
  }

  return {
    state: lifecycle.state,
    currentSavedItemKeyCount: savedItems.legacyKeys.length,
    persistentCartEnabled: false,
    projectCartEnabled: false,
  };
}

function main() {
  const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
  const lifecycleManifest = JSON.parse(
    readFileSync(resolve(root, 'store/g2-data-lifecycle.json'), 'utf8'),
  );
  const result = validateG2DataLifecycle({ root, lifecycleManifest });
  process.stdout.write(
    `G2 data lifecycle: PASS (state=${result.state}, savedKeys=${result.currentSavedItemKeyCount}, persistentCart=false, projectCart=false)\n`,
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
