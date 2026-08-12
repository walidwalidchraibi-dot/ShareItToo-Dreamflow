import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repositoryRoot = fileURLToPath(new URL('../../', import.meta.url));

test('release preflight always validates the privacy draft and requires approval for Store mode', () => {
  const source = readFileSync(resolve(repositoryRoot, 'scripts/release_candidate_preflight.sh'), 'utf8');
  assert.match(source, /node --check tool\/validate_privacy_disclosures\.mjs/);
  assert.match(source, /node tool\/validate_privacy_disclosures\.mjs\n/);
  assert.match(
    source,
    /if \[\[ "\$\{SIT_REQUIRE_STORE_SUBMISSION:-0\}" == "1" \]\]; then[\s\S]*node tool\/validate_privacy_disclosures\.mjs --require-approved/,
  );
  assert.ok(
    source.indexOf('node tool/validate_privacy_disclosures.mjs --require-approved')
      < source.indexOf('dart run tool/validate_store_metadata.dart --require-submittable'),
  );
});

test('technical regression runs syntax, tests, and the honest privacy draft validator', () => {
  const source = readFileSync(resolve(repositoryRoot, 'scripts/technical_regression_check.sh'), 'utf8');
  for (const command of [
    'node --check tool/validate_privacy_disclosures.mjs',
    'node --test test/tool/validate_privacy_disclosures.test.mjs',
    'node tool/validate_privacy_disclosures.mjs',
  ]) {
    assert.ok(source.includes(command), `technical regression is missing: ${command}`);
  }
});

test('signed binary privacy scan inventories enabled Maps and allows dormant endpoint code', () => {
  const source = readFileSync(resolve(repositoryRoot, 'tool/verify_android_binary_privacy.mjs'), 'utf8');
  assert.match(source, /nominatim\.openstreetmap\.org/);
  assert.match(source, /tile\.openstreetmap\.org/);
  assert.match(source, /maps\.googleapis\.com/);
  assert.match(source, /Google Maps Platform/);
  assert.match(source, /!googleMapsClientCredentialPresent \|\| googleMapsEndpointPresent/);
  assert.match(source, /codeEndpointPresent: googleMapsEndpointPresent/);
  assert.match(source, /pending-console-verification/);
  assert.match(source, /https:\/\/api\.openai\.com\//);
});

test('release builder binds an optional restricted Google Maps client credential', () => {
  const source = readFileSync(
    resolve(repositoryRoot, 'scripts/build_android_release_candidate.sh'),
    'utf8',
  );
  assert.match(source, /if \[\[ -n "\$\{GOOGLE_MAPS_API_KEY:-\}" \]\]; then/);
  assert.match(source, /--dart-define=GOOGLE_MAPS_API_KEY=\$GOOGLE_MAPS_API_KEY/);
});
