import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { validateGooglePlayAppContentHandoff } from '../../tool/validate_google_play_app_content_handoff.mjs';

const repositoryRoot = new URL('../../', import.meta.url).pathname;
const canonical = JSON.parse(await readFile(
  new URL('../../store/google-play/app-content-handoff.json', import.meta.url), 'utf8'));

async function fixture(mutate = () => {}) {
  const root = await mkdtemp(join(tmpdir(), 'sit-play-content-'));
  const handoff = structuredClone(canonical);
  mutate(handoff);
  const handoffPath = join(root, 'handoff.json');
  await writeFile(handoffPath, `${JSON.stringify(handoff, null, 2)}\n`);
  return { root, handoffPath };
}

test('accepts seven saved Play tasks while review, public pages, and IARC remain stopped', () => {
  const result = validateGooglePlayAppContentHandoff({ repositoryRoot });
  assert.deepEqual(result, { taskCount: 11, buildNumber: '2026081202' });
});

test('rejects claiming ads for the current binary', async (t) => {
  const data = await fixture((handoff) => { handoff.tasks.ads.proposedAnswer = true; });
  t.after(() => rm(data.root, { recursive: true, force: true }));
  assert.throws(() => validateGooglePlayAppContentHandoff({ repositoryRoot, ...data }),
    /product truth/);
});

test('rejects lowering the prepared target audience below eighteen', async (t) => {
  const data = await fixture((handoff) => { handoff.tasks.targetAudience.minimumAge = 13; });
  t.after(() => rm(data.root, { recursive: true, force: true }));
  assert.throws(() => validateGooglePlayAppContentHandoff({ repositoryRoot, ...data }),
    /product truth/);
});

test('rejects enabling review submission', async (t) => {
  const data = await fixture((handoff) => { handoff.hardStops.sendForReview = false; });
  t.after(() => rm(data.root, { recursive: true, force: true }));
  assert.throws(() => validateGooglePlayAppContentHandoff({ repositoryRoot, ...data }),
    /hardStops.sendForReview/);
});

test('rejects claiming OAuth support before the providers are available', async (t) => {
  const data = await fixture((handoff) => {
    handoff.tasks.dataSafety.oauthPreparedButUnavailable = false;
  });
  t.after(() => rm(data.root, { recursive: true, force: true }));
  assert.throws(() => validateGooglePlayAppContentHandoff({ repositoryRoot, ...data }),
    /product truth/);
});

test('rejects credential or account data', async (t) => {
  const data = await fixture((handoff) => { handoff.account = 'private@example.test'; });
  t.after(() => rm(data.root, { recursive: true, force: true }));
  assert.throws(() => validateGooglePlayAppContentHandoff({ repositoryRoot, ...data }),
    /sanitized/);
});
