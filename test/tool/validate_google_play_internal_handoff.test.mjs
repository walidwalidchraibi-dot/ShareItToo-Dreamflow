import assert from 'node:assert/strict';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import test from 'node:test';

import { validateGooglePlayInternalHandoff } from '../../tool/validate_google_play_internal_handoff.mjs';

const repositoryRoot = new URL('../../', import.meta.url).pathname;
const canonicalHandoff = JSON.parse(await readFile(
  new URL('../../store/google-play/internal-upload-handoff.json', import.meta.url), 'utf8'));
const canonicalEvidence = JSON.parse(await readFile(
  new URL('../../docs/evidence/b11/android-candidate-2026081201.json', import.meta.url), 'utf8'));

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), 'sit-play-handoff-'));
  const archiveRoot = join(root, 'archive');
  const handoffPath = join(root, 'handoff.json');
  const evidencePath = join(root, 'evidence.json');
  const artifactPath = join(
    archiveRoot,
    canonicalHandoff.artifact.archiveDirectoryName,
    canonicalHandoff.artifact.fileName,
  );
  const bytes = Buffer.from('synthetic exact AAB');
  const { createHash } = await import('node:crypto');
  const hash = createHash('sha256').update(bytes).digest('hex');
  const handoff = structuredClone(canonicalHandoff);
  const evidence = structuredClone(canonicalEvidence);
  handoff.candidate.aabSha256 = hash;
  evidence.android.aabSha256 = hash;
  await mkdir(dirname(artifactPath), { recursive: true });
  await writeFile(artifactPath, bytes, { mode: 0o600 });
  await writeFile(handoffPath, JSON.stringify(handoff));
  await writeFile(evidencePath, JSON.stringify(evidence));
  return { root, archiveRoot, handoffPath, evidencePath, artifactPath, handoff };
}

test('accepts the superseded private artifact while its safer replacement stays pending', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));
  const result = validateGooglePlayInternalHandoff({ repositoryRoot, ...data });
  assert.equal(result.buildNumber, '2026081201');
  assert.equal(result.artifactPath, data.artifactPath);
  assert.equal(result.releaseName, '1.0.0-internal-2026081201');
  assert.equal(result.status, 'superseded-privacy-rescan-failed-replacement-pending');
  assert.match(result.releaseNotes, /ausschließlich Staging und Testzahlungen/u);
});

test('rejects different AAB bytes', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));
  await writeFile(data.artifactPath, 'different bytes', { mode: 0o600 });
  assert.throws(() => validateGooglePlayInternalHandoff({ repositoryRoot, ...data }),
    /archived AAB SHA-256/);
});

test('rejects a regression to pending identity verification', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));
  data.handoff.preUploadGates.personalIdentityVerification = 'pending-user';
  await writeFile(data.handoffPath, JSON.stringify(data.handoff));
  assert.throws(() => validateGooglePlayInternalHandoff({ repositoryRoot, ...data }),
    /personalIdentityVerification/);
});

test('rejects a regression to pending device verification', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));
  data.handoff.preUploadGates.deviceVerification = 'pending-user';
  await writeFile(data.handoffPath, JSON.stringify(data.handoff));
  assert.throws(() => validateGooglePlayInternalHandoff({ repositoryRoot, ...data }),
    /deviceVerification/);
});

test('rejects a regression to pending phone verification', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));
  data.handoff.preUploadGates.phoneVerification = 'pending-user';
  await writeFile(data.handoffPath, JSON.stringify(data.handoff));
  assert.throws(() => validateGooglePlayInternalHandoff({ repositoryRoot, ...data }),
    /phoneVerification/);
});

test('rejects a regression to pending Play App Signing approval', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));
  data.handoff.preUploadGates.playAppSigningTerms = 'pending-owner-approval';
  await writeFile(data.handoffPath, JSON.stringify(data.handoff));
  assert.throws(() => validateGooglePlayInternalHandoff({ repositoryRoot, ...data }),
    /playAppSigningTerms/);
});

test('rejects a missing Play app record', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));
  data.handoff.preUploadGates.playAppRecordCreated = false;
  await writeFile(data.handoffPath, JSON.stringify(data.handoff));
  assert.throws(() => validateGooglePlayInternalHandoff({ repositoryRoot, ...data }),
    /playAppRecordCreated/);
});

test('rejects premature submission permission', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));
  data.handoff.submissionAllowed = true;
  await writeFile(data.handoffPath, JSON.stringify(data.handoff));
  assert.throws(() => validateGooglePlayInternalHandoff({ repositoryRoot, ...data }),
    /submissionAllowed/);
});

test('rejects an internal draft that permits rollout', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));
  data.handoff.releaseDraft.rolloutAllowed = true;
  await writeFile(data.handoffPath, JSON.stringify(data.handoff));
  assert.throws(() => validateGooglePlayInternalHandoff({ repositoryRoot, ...data }),
    /releaseDraft.rolloutAllowed/);
});

test('rejects credential-shaped fields', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));
  data.handoff.accountPassword = 'must-never-be-here';
  await writeFile(data.handoffPath, JSON.stringify(data.handoff));
  assert.throws(() => validateGooglePlayInternalHandoff({ repositoryRoot, ...data }),
    /forbidden credential-shaped field/);
});
