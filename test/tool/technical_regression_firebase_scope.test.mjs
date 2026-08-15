import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const regression = readFileSync(
  new URL('../../scripts/technical_regression_check.sh', import.meta.url),
  'utf8',
);

test('full regression defaults to all Firebase platforms', () => {
  assert.match(
    regression,
    /firebase_validation_platform="\$\{SIT_FIREBASE_VALIDATION_PLATFORM:-all\}"/,
  );
  assert.match(
    regression,
    /node tool\/validate_firebase_release_config\.mjs --platform "\$firebase_validation_platform"/,
  );
  assert.match(
    regression,
    /firebase_validation_platform" =~ \^\(android\|all\)\$/,
  );
});

test('full regression accepts only explicit android, ios, or all scope', () => {
  assert.match(regression, /\^\(android\|ios\|all\)\$/);
});
