import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const source = readFileSync(
  new URL('../../lib/screens/profile_info_screen.dart', import.meta.url),
  'utf8',
);

test('late profile-load failure cannot update disposed state', () => {
  assert.match(
    source,
    /catch \(e\) \{\s+\/\/ just fallback[\s\S]*?if \(!mounted\) return;\s+setState\(\(\) \{\s+_loading = false;/u,
  );
});

test('successful save rechecks lifecycle after its toast before navigation', () => {
  assert.match(
    source,
    /setCurrentUser\(updated\);\s+if \(!mounted\) return;\s+await AppPopup\.toast\(context,[\s\S]*?if \(!mounted\) return;\s+Navigator\.of\(context\)\.maybePop\(\);/u,
  );
});

test('profile lifecycle fix contains no timing or lint accommodation', () => {
  assert.doesNotMatch(source, /ignore:\s*use_build_context_synchronously/u);
  assert.doesNotMatch(source, /Future(?:<void>)?\.delayed|Timer\s*\(/u);
});
