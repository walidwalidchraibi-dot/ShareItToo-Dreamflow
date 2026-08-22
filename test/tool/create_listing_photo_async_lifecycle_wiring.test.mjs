import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const source = readFileSync(
  new URL('../../lib/screens/create_listing_screen.dart', import.meta.url),
  'utf8',
);
const pickedThumb = source.match(
  /class _PickedThumb[\s\S]*?\n\}\n\n\/\/ ---------- Simple Accordion/u,
)?.[0];

assert.ok(pickedThumb, 'expected the picked-photo thumbnail widget');

test('picked-photo preview rechecks its context after asynchronous file access', () => {
  assert.match(
    pickedThumb,
    /class _PickedThumb[\s\S]*?final bytes = await file\.readAsBytes\(\);\s+if \(!context\.mounted\) return;\s+showDialog\(\s+context: context,/u,
  );
});

test('photo-preview lifecycle fix contains no timing or lint accommodation', () => {
  assert.doesNotMatch(pickedThumb, /ignore:\s*use_build_context_synchronously/u);
  assert.doesNotMatch(pickedThumb, /Future(?:<void>)?\.delayed|Timer\s*\(/u);
});
