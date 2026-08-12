import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { validateGooglePlayAppContentProgress } from '../../tool/validate_google_play_app_content_progress.mjs';

const repositoryRoot = new URL('../../', import.meta.url).pathname;
const canonical = JSON.parse(await readFile(new URL(
  '../../docs/evidence/b11/google-play-app-content-progress-20260812.json', import.meta.url), 'utf8'));

async function fixture(mutate) {
  const root = await mkdtemp(join(tmpdir(), 'sit-play-progress-'));
  const evidence = structuredClone(canonical);
  mutate(evidence);
  const evidencePath = join(root, 'evidence.json');
  await writeFile(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`);
  return { root, evidencePath };
}

test('accepts seven saved and four fail-closed Play tasks', () => {
  assert.deepEqual(validateGooglePlayAppContentProgress({ repositoryRoot }), {
    status: 'seven-of-eleven-saved-data-safety-step-two-observed', savedTasks: 7, openTasks: 4,
  });
});

test('rejects claiming OAuth account creation before provider activation', async (t) => {
  const data = await fixture((evidence) => {
    evidence.dataSafetyDraft.oauthPreparedButUnavailable = false;
  });
  t.after(() => rm(data.root, { recursive: true, force: true }));
  assert.throws(() => validateGooglePlayAppContentProgress({ repositoryRoot, ...data }),
    /data-safety partial draft/);
});

test('rejects claiming an AAB upload', async (t) => {
  const data = await fixture((evidence) => { evidence.storeDraft.appBundleUploaded = true; });
  t.after(() => rm(data.root, { recursive: true, force: true }));
  assert.throws(() => validateGooglePlayAppContentProgress({ repositoryRoot, ...data }), /draft state/);
});

test('rejects claiming the partial Data safety draft was submitted', async (t) => {
  const data = await fixture((evidence) => { evidence.dataSafetyDraft.submitted = true; });
  t.after(() => rm(data.root, { recursive: true, force: true }));
  assert.throws(() => validateGooglePlayAppContentProgress({ repositoryRoot, ...data }), /data-safety partial draft/);
});

test('rejects an email address or review credential in evidence', async (t) => {
  const data = await fixture((evidence) => { evidence.note = 'private@example.invalid'; });
  t.after(() => rm(data.root, { recursive: true, force: true }));
  assert.throws(() => validateGooglePlayAppContentProgress({ repositoryRoot, ...data }), /unsafe or unsanitized/);
});
