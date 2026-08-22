import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const source = readFileSync(
  new URL('../../lib/screens/public_profile_screen.dart', import.meta.url),
  'utf8',
);

test('profile sharing rechecks its exact context after clipboard access', () => {
  assert.match(
    source,
    /await Clipboard\.setData\([\s\S]*?if \(!context\.mounted\) return;\s+AppPopup\.toast\(context,/u,
  );
});

test('profile blocking proves context lifetime before its asynchronous flow', () => {
  assert.match(
    source,
    /if \(value == 'block_user'\)[\s\S]*?if \(targetUserId\.isEmpty\) return;\s+if \(!context\.mounted\) return;\s+await runPublicProfileBlockFlow\(\s+context,/u,
  );
});

test('public-profile context fix contains no timing or lint accommodation', () => {
  assert.doesNotMatch(source, /ignore:\s*use_build_context_synchronously/u);
  assert.doesNotMatch(source, /Future(?:<void>)?\.delayed|Timer\s*\(/u);
});
