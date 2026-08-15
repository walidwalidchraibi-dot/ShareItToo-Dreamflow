import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { validateGooglePlayScreenshotReadiness } from '../../tool/validate_google_play_screenshot_readiness.mjs';

const repositoryRoot = new URL('../../', import.meta.url).pathname;
const canonical = JSON.parse(await readFile(
  new URL('../../docs/evidence/b11/google-play-feed-screenshot-readiness-2026081506-20260815.json', import.meta.url), 'utf8'));
const historicalCompatibility = new URL(
  '../../docs/evidence/b11/google-play-feed-screenshot-compatibility-2026081405-20260814.json',
  import.meta.url,
).pathname;

async function fixture(mutate) {
  const root = await mkdtemp(join(tmpdir(), 'sit-screenshot-ready-'));
  const evidence = structuredClone(canonical);
  mutate(evidence);
  const evidencePath = join(root, 'evidence.json');
  await writeFile(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`);
  return { root, evidencePath };
}

test('accepts four exact current screenshots byte-identical to the existing Console draft', () => {
  assert.deepEqual(validateGooglePlayScreenshotReadiness({ repositoryRoot }), {
    status: 'exact-candidate-screenshots-byte-identical-existing-draft',
    curatedListingCount: 4,
  });
});

test('rejects preserved compatibility evidence once the exact candidate advances', () => {
  assert.throws(() => validateGooglePlayScreenshotReadiness({
    repositoryRoot,
    evidencePath: historicalCompatibility,
  }), /not bound to the exact current candidate/);
});

test('rejects exact-candidate readiness when visual acceptance is missing', async (t) => {
  const data = await fixture((evidence) => { evidence.feedObservation.storeScreenshotAccepted = false; });
  t.after(() => rm(data.root, { recursive: true, force: true }));
  assert.throws(() => validateGooglePlayScreenshotReadiness({ repositoryRoot, ...data }),
    /incomplete/);
});

test('rejects losing the exact Console draft upload', async (t) => {
  const data = await fixture((evidence) => { evidence.boundaries.screenshotUploaded = true; });
  t.after(() => rm(data.root, { recursive: true, force: true }));
  assert.throws(() => validateGooglePlayScreenshotReadiness({ repositoryRoot, ...data }),
    /bounded draft upload/);
});
