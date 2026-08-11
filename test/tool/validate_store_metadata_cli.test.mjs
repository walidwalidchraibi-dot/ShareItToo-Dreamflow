import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const repositoryRoot = resolve(import.meta.dirname, '../..');
const validator = resolve(repositoryRoot, 'tool/validate_store_metadata.dart');
const baseManifest = JSON.parse(readFileSync(resolve(repositoryRoot, 'store/submission.json'), 'utf8'));
const baseAccountReadiness = JSON.parse(readFileSync(
  resolve(repositoryRoot, 'store/platform-account-readiness.json'),
  'utf8',
));

function runWithManifests({
  mutateManifest = () => {},
  mutateAccountReadiness = () => {},
}) {
  const directory = mkdtempSync(join(tmpdir(), 'sit-store-metadata-'));
  try {
    const manifest = structuredClone(baseManifest);
    const accountReadiness = structuredClone(baseAccountReadiness);
    mutateManifest(manifest);
    mutateAccountReadiness(accountReadiness);
    const manifestPath = join(directory, 'submission.json');
    const accountReadinessPath = join(directory, 'platform-account-readiness.json');
    writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
    writeFileSync(accountReadinessPath, `${JSON.stringify(accountReadiness, null, 2)}\n`);
    return spawnSync('dart', [
      'run',
      validator,
      '--manifest',
      manifestPath,
      '--account-readiness',
      accountReadinessPath,
    ], {
      cwd: repositoryRoot,
      encoding: 'utf8',
    });
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

test('rejects a missing mandatory Store release gate', () => {
  const result = runWithManifests({
    mutateManifest: (manifest) => {
      delete manifest.blockingGates.googlePlayAccountAndFee;
    },
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /must contain exactly the required Store release gates/);
});

test('rejects an unrecognized Store release gate', () => {
  const result = runWithManifests({
    mutateManifest: (manifest) => {
      manifest.blockingGates.unreviewedShortcut = 'closed';
    },
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /must contain exactly the required Store release gates/);
});

test('rejects closing the Play account gate before account setup and fee evidence', () => {
  const result = runWithManifests({
    mutateManifest: (manifest) => {
      manifest.blockingGates.googlePlayAccountAndFee = 'closed';
    },
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /must match verified Play account readiness/);
});

test('rejects closing the Apple account gate before membership and signing evidence', () => {
  const result = runWithManifests({
    mutateManifest: (manifest) => {
      manifest.blockingGates.appleAccountXcodeAndSigning = 'closed';
    },
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /must match verified Apple account readiness/);
});

test('rejects closing the Firebase owner-terms gate without owner confirmation', () => {
  const result = runWithManifests({
    mutateManifest: (manifest) => {
      manifest.blockingGates.firebaseTermsAcceptedByOwner = 'closed';
    },
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /must match the owner confirmation/);
});

test('rejects account readiness containing an email address', () => {
  const result = runWithManifests({
    mutateAccountReadiness: (readiness) => {
      readiness.googlePlay.evidenceRef = 'private@example.test';
    },
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /must remain sanitized/);
});

test('rejects hiding the paid Play registration in the account boundary', () => {
  const result = runWithManifests({
    mutateAccountReadiness: (readiness) => {
      readiness.boundaries.purchaseMade = false;
    },
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /purchase history must match/);
});

test('rejects hiding the accepted Play agreements in the account boundary', () => {
  const result = runWithManifests({
    mutateAccountReadiness: (readiness) => {
      readiness.boundaries.agreementAccepted = false;
    },
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /agreement history must match/);
});

test('rejects a purchase claim without a paid Store account state', () => {
  const result = runWithManifests({
    mutateAccountReadiness: (readiness) => {
      readiness.googlePlay.registrationFeePaid = false;
    },
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /purchase history must match/);
});
