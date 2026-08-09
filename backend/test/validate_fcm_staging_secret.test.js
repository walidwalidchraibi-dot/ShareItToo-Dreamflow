import assert from 'node:assert/strict';
import { chmod, mkdir, mkdtemp, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { validateFcmStagingSecret } from '../ops/validate_fcm_staging_secret.mjs';

const projectId = 'shareittoo-staging';
const keyBegin = ['-----BEGIN', 'PRIVATE', 'KEY-----'].join(' ');
const keyEnd = ['-----END', 'PRIVATE', 'KEY-----'].join(' ');

function account(overrides = {}) {
  return JSON.stringify({
    type: 'service_account',
    project_id: projectId,
    private_key_id: '0123456789abcdef0123456789abcdef',
    private_key: `${keyBegin}\nsynthetic-test-material\n${keyEnd}\n`,
    client_email: `sit-fcm-staging@${projectId}.iam.gserviceaccount.com`,
    client_id: '123456789012345678901',
    token_uri: 'https://oauth2.googleapis.com/token',
    ...overrides,
  });
}

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), 'sit-fcm-secret-test-'));
  const repository = join(root, 'repository');
  const secrets = join(root, 'secrets');
  await mkdir(repository);
  await mkdir(secrets);
  const secret = join(secrets, 'firebase-service-account.json');
  await writeFile(secret, account(), { mode: 0o600 });
  return { root, repository, secrets, secret };
}

test('accepts an owner-only staging service account outside the repository', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));

  const result = validateFcmStagingSecret({
    filePath: data.secret,
    expectedProjectId: projectId,
    repositoryRoot: data.repository,
  });

  assert.equal(result.projectId, projectId);
  assert.equal(result.fileMode, 0o600);
});

test('rejects a service account stored inside the repository', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));
  const inside = join(data.repository, 'firebase-service-account.json');
  await writeFile(inside, account(), { mode: 0o600 });

  assert.throws(() => validateFcmStagingSecret({
    filePath: inside,
    expectedProjectId: projectId,
    repositoryRoot: data.repository,
  }), { code: 'fcm_staging_secret_inside_repository' });
});

test('rejects group- or world-readable credential files', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));
  await chmod(data.secret, 0o640);

  assert.throws(() => validateFcmStagingSecret({
    filePath: data.secret,
    expectedProjectId: projectId,
    repositoryRoot: data.repository,
  }), { code: 'fcm_staging_secret_permissions_invalid' });
});

test('rejects symbolic links even when their target is owner-only', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));
  const link = join(data.secrets, 'firebase-service-account-link.json');
  await symlink(data.secret, link);

  assert.throws(() => validateFcmStagingSecret({
    filePath: link,
    expectedProjectId: projectId,
    repositoryRoot: data.repository,
  }), { code: 'fcm_staging_secret_type_invalid' });
});

test('rejects any non-staging project before reading credentials', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));

  assert.throws(() => validateFcmStagingSecret({
    filePath: data.secret,
    expectedProjectId: 'shareittoo-production',
    repositoryRoot: data.repository,
  }), { code: 'fcm_staging_project_mismatch' });
});

test('rejects credentials from another Firebase project without leaking details', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));
  await writeFile(data.secret, account({ project_id: 'another-project' }), { mode: 0o600 });

  assert.throws(() => validateFcmStagingSecret({
    filePath: data.secret,
    expectedProjectId: projectId,
    repositoryRoot: data.repository,
  }), (error) => {
    assert.equal(error.code, 'fcm_staging_secret_credentials_invalid');
    assert.equal(error.message, 'FCM staging secret gate failed.');
    return true;
  });
});

test('rejects the broad auto-created Firebase Admin SDK account', async (t) => {
  const data = await fixture();
  t.after(() => rm(data.root, { recursive: true, force: true }));
  await writeFile(data.secret, account({
    client_email: `firebase-adminsdk-fbsvc@${projectId}.iam.gserviceaccount.com`,
  }), { mode: 0o600 });

  assert.throws(() => validateFcmStagingSecret({
    filePath: data.secret,
    expectedProjectId: projectId,
    repositoryRoot: data.repository,
  }), (error) => {
    assert.equal(error.code, 'fcm_staging_secret_credentials_invalid');
    assert.equal(error.message, 'FCM staging secret gate failed.');
    return true;
  });
});
