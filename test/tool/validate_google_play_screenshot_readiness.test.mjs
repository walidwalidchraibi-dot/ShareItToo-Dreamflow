import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { validateGooglePlayScreenshotReadiness } from '../../tool/validate_google_play_screenshot_readiness.mjs';

const repositoryRoot = new URL('../../', import.meta.url).pathname;
const canonical = JSON.parse(await readFile(
  new URL('../../docs/evidence/b11/google-play-feed-screenshot-readiness-20260812.json', import.meta.url), 'utf8'));

async function fixture(mutate) {
  const root = await mkdtemp(join(tmpdir(), 'sit-screenshot-ready-'));
  const evidence = structuredClone(canonical);
  mutate(evidence);
  const evidencePath = join(root, 'evidence.json');
  await writeFile(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`);
  return { root, evidencePath };
}

test('accepts the clean fixture while old local screenshots remain superseded', () => {
  assert.deepEqual(validateGooglePlayScreenshotReadiness({ repositoryRoot }), {
    status: 'superseded-four-local-candidates-not-uploaded',
    curatedListingCount: 4,
  });
});

test('rejects claiming a clean feed while technical fixtures remain visible', async (t) => {
  const data = await fixture((evidence) => { evidence.feedObservation.legacyTechnicalListingsVisible = true; });
  t.after(() => rm(data.root, { recursive: true, force: true }));
  assert.throws(() => validateGooglePlayScreenshotReadiness({ repositoryRoot, ...data }),
    /contradicts/);
});

test('rejects claiming deletion authority', async (t) => {
  const data = await fixture((evidence) => { evidence.completedRemediation.deletionAuthorized = true; });
  t.after(() => rm(data.root, { recursive: true, force: true }));
  assert.throws(() => validateGooglePlayScreenshotReadiness({ repositoryRoot, ...data }),
    /destructive or production authority/);
});
