import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { validateG2DataLifecycle } from '../../tool/validate_g2_data_lifecycle.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const baseLifecycle = JSON.parse(
  readFileSync(resolve(root, 'store/g2-data-lifecycle.json'), 'utf8'),
);
const clone = (value) => structuredClone(value);

function validate({ lifecycleManifest = clone(baseLifecycle), sourceTexts = {}, runtimePersistenceText } = {}) {
  return validateG2DataLifecycle({
    root,
    lifecycleManifest,
    sourceTexts,
    runtimePersistenceText,
  });
}

test('accepts current local Gemerkt and keeps both persistent cart classes inactive', () => {
  assert.deepEqual(validate(), {
    state: 'g2a-current-g2b-inactive',
    currentSavedItemKeyCount: 3,
    persistentCartEnabled: false,
    projectCartEnabled: false,
  });
});

test('rejects a cart activation before export deletion and retention coverage', () => {
  const lifecycleManifest = clone(baseLifecycle);
  lifecycleManifest.plannedPersistentData.rentalCart.runtimeStatus = 'active';
  assert.throws(
    () => validate({ lifecycleManifest }),
    /remain inactive and fail closed before G2B/,
  );
});

test('rejects persistent runtime keys while the G2B lifecycle is inactive', () => {
  assert.throws(
    () => validate({ runtimePersistenceText: "const key = 'rental_cart_v1';" }),
    /Persistent rental\/project cart code exists/,
  );
});

test('rejects account deletion that leaves local Gemerkt behind', () => {
  const path = 'lib/services/account_deletion_service.dart';
  const changed = readFileSync(resolve(root, path), 'utf8')
    .replaceAll('await DataService.clearSavedItemsForAccountDeletion();', '');
  assert.throws(
    () => validate({ sourceTexts: { [path]: changed } }),
    /confirmed account deletion paths must purge Gemerkt/,
  );
});

test('rejects a privacy export that omits the local-device section', () => {
  const path = 'lib/screens/privacy_info_screen.dart';
  const changed = readFileSync(resolve(root, path), 'utf8')
    .replace("export['localDevice']", "export['omittedLocalDevice']");
  assert.throws(
    () => validate({ sourceTexts: { [path]: changed } }),
    /Privacy export is missing G2 marker/,
  );
});
