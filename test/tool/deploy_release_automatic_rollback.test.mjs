import assert from 'node:assert/strict';
import { chmod, cp, mkdir, mkdtemp, readFile, readdir, rm, writeFile } from
  'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const sourceScript = new URL('../../backend/ops/deploy_release.sh', import.meta.url);

async function executable(path, content) {
  await writeFile(path, content);
  await chmod(path, 0o755);
}

test('a failed production rollout restores and verifies the previous exact image', async (t) => {
  const root = await mkdtemp(join(tmpdir(), 'sit-deploy-rollback-'));
  t.after(() => rm(root, { recursive: true, force: true }));

  const backend = join(root, 'backend');
  const ops = join(backend, 'ops');
  const fakeBin = join(root, 'bin');
  const releases = join(root, 'releases');
  const state = join(root, 'docker-state');
  const log = join(root, 'docker-log');
  await Promise.all([
    mkdir(ops, { recursive: true }),
    mkdir(fakeBin, { recursive: true }),
    mkdir(releases, { recursive: true }),
  ]);
  await cp(sourceScript, join(ops, 'deploy_release.sh'));
  await chmod(join(ops, 'deploy_release.sh'), 0o755);
  await writeFile(join(backend, 'compose.prod.yml'), 'services:\n  api:\n    image: placeholder\n');
  await writeFile(join(backend, '.env'), 'POSTGRES_PASSWORD=test\nJWT_SECRET=test\n');
  await executable(join(ops, 'backup.sh'), '#!/usr/bin/env bash\nexit 0\n');

  await executable(join(fakeBin, 'curl'), `#!/usr/bin/env bash
case "\${*: -1}" in
  */version) printf '{"commit":"%s"}\\n' "\${PREVIOUS_COMMIT}" ;;
  */health) exit 0 ;;
  *) exit 0 ;;
esac
`);
  await executable(join(fakeBin, 'docker'), `#!/usr/bin/env bash
printf '%s\\n' "$*" >> "\${DOCKER_LOG}"
if [[ "$1" == image && "$2" == inspect ]]; then
  if [[ "$3" == *"\${TARGET_COMMIT}"* ]]; then
    case "$*" in
      *revision*) printf '%s\\n' "\${TARGET_COMMIT}" ;;
      *version*) printf '0.1.0-%s\\n' "\${TARGET_COMMIT:0:12}" ;;
      *created*) printf '2026-08-13T00:00:00Z\\n' ;;
    esac
  else
    case "$*" in
      *version*) printf '0.1.0-previous\\n' ;;
      *created*) printf '2026-08-12T00:00:00Z\\n' ;;
    esac
  fi
  exit 0
fi
if [[ "$1" == inspect ]]; then
  if [[ "$*" == *State.Health* ]]; then
    printf 'healthy\\n'
  else
    printf 'sha256:previous-image\\n'
  fi
  exit 0
fi
if [[ "$1" == compose ]]; then
  count=0
  [[ -f "\${DOCKER_STATE}" ]] && count=$(<"\${DOCKER_STATE}")
  count=$((count + 1))
  printf '%s' "$count" > "\${DOCKER_STATE}"
  [[ "$count" == 1 ]] && exit 42
  exit 0
fi
exit 1
`);

  const targetCommit = 'a'.repeat(40);
  const previousCommit = 'b'.repeat(40);
  const result = spawnSync(join(ops, 'deploy_release.sh'),
    ['production', targetCommit], {
      encoding: 'utf8',
      env: {
        ...process.env,
        PATH: `${fakeBin}:${process.env.PATH}`,
        TARGET_COMMIT: targetCommit,
        PREVIOUS_COMMIT: previousCommit,
        CONFIRM_PRODUCTION_DEPLOY: targetCommit,
        IMAGE_REPOSITORY: 'registry.invalid/sit-api',
        HEALTH_URL: 'https://example.invalid/api',
        RELEASE_LOG_DIR: releases,
        DOCKER_STATE: state,
        DOCKER_LOG: log,
      },
    });

  assert.equal(result.status, 42);
  assert.match(result.stderr, /previous image restored and verified/);
  const dockerLog = await readFile(log, 'utf8');
  assert.equal((dockerLog.match(/compose /g) ?? []).length, 2);
  assert.match(dockerLog, /sha256:previous-image/);
  const reports = await readdir(releases);
  assert.equal(reports.length, 1);
  const report = JSON.parse(await readFile(join(releases, reports[0]), 'utf8'));
  assert.equal(report.status, 'passed');
  assert.equal(report.failedCommit, targetCommit);
  assert.equal(report.restoredCommit, previousCommit);
  assert.equal(report.restoredImageId, 'sha256:previous-image');
});
