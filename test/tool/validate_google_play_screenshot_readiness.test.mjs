import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { validateGooglePlayScreenshotReadiness } from '../../tool/validate_google_play_screenshot_readiness.mjs';

const repositoryRoot = new URL('../../', import.meta.url).pathname;
const canonical = JSON.parse(await readFile(
  new URL('../../docs/evidence/b11/google-play-feed-screenshot-compatibility-2026081403-20260814.json', import.meta.url), 'utf8'));

async function fixture(mutate) {
  const root = await mkdtemp(join(tmpdir(), 'sit-screenshot-ready-'));
  const evidence = structuredClone(canonical);
  mutate(evidence);
  const evidencePath = join(root, 'evidence.json');
  await writeFile(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`);
  return { root, evidencePath };
}

test('accepts four historical screenshots after exact current Store compatibility review', () => {
  assert.deepEqual(validateGooglePlayScreenshotReadiness({ repositoryRoot }), {
    status: 'verified-compatible-no-visible-product-change',
    curatedListingCount: 4,
  });
});

test('rejects compatibility when a visible screen source changed', async (t) => {
  const data = await fixture((evidence) => { evidence.compatibilityReview.visibleScreenSourceChanged = true; });
  t.after(() => rm(data.root, { recursive: true, force: true }));
  assert.throws(() => validateGooglePlayScreenshotReadiness({ repositoryRoot, ...data }),
    /contradicts/);
});

test('rejects claiming a Store change during compatibility review', async (t) => {
  const data = await fixture((evidence) => { evidence.boundaries.storeListingChangedDuringReview = true; });
  t.after(() => rm(data.root, { recursive: true, force: true }));
  assert.throws(() => validateGooglePlayScreenshotReadiness({ repositoryRoot, ...data }),
    /must not claim Store changes/);
});
