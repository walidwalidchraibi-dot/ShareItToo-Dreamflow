import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  assertSafeR10TempRoot,
  compareApkInventories,
  parseAaptBadging,
  parseAaptPermissions,
} from '../../tool/run_r10_clean_reproducibility.mjs';

const technicalRegression = readFileSync(
  new URL('../../scripts/technical_regression_check.sh', import.meta.url),
  'utf8',
);

test('accepts only one bounded R10 directory directly under the temp root', () => {
  assert.equal(
    assertSafeR10TempRoot('/tmp/sit-r10-clean-reproducibility-abc123', '/tmp'),
    '/tmp/sit-r10-clean-reproducibility-abc123',
  );
  assert.throws(
    () => assertSafeR10TempRoot('/tmp', '/tmp'),
    /unsafe_r10_temp_root/u,
  );
  assert.throws(
    () => assertSafeR10TempRoot('/tmp/sit-r10-clean-reproducibility-a/nested', '/tmp'),
    /unsafe_r10_temp_root/u,
  );
});

test('parses the exact Android package and SDK identity', () => {
  assert.deepEqual(parseAaptBadging([
    "package: name='com.shareittoo.app' versionCode='2026082405' versionName='1.0.0' compileSdkVersion='35'",
    "sdkVersion:'24'",
    "targetSdkVersion:'35'",
    "application-debuggable",
  ].join('\n')), {
    applicationId: 'com.shareittoo.app',
    versionCode: '2026082405',
    versionName: '1.0.0',
    compileSdk: 35,
    minSdk: 24,
    targetSdk: 35,
    debuggable: true,
  });
});

test('normalizes and sorts the merged APK permission surface', () => {
  assert.deepEqual(parseAaptPermissions([
    'package: com.shareittoo.app',
    "uses-permission: name='android.permission.CAMERA'",
    "uses-permission: name='android.permission.READ_EXTERNAL_STORAGE' maxSdkVersion='32'",
    "uses-permission: name='android.permission.INTERNET'",
  ].join('\n')), [
    { name: 'android.permission.CAMERA', maxSdkVersion: null },
    { name: 'android.permission.INTERNET', maxSdkVersion: null },
    { name: 'android.permission.READ_EXTERNAL_STORAGE', maxSdkVersion: 32 },
  ]);
});

test('distinguishes byte identity, metadata-only drift and payload drift', () => {
  const first = {
    sha256: 'a'.repeat(64),
    entries: [
      { name: 'AndroidManifest.xml', sha256: '1'.repeat(64) },
      { name: 'classes.dex', sha256: '2'.repeat(64) },
    ],
  };
  assert.deepEqual(compareApkInventories(first, structuredClone(first)), {
    classification: 'byte-identical',
    byteIdentical: true,
    payloadIdentical: true,
    differingEntries: [],
  });

  const metadataOnly = structuredClone(first);
  metadataOnly.sha256 = 'b'.repeat(64);
  assert.deepEqual(compareApkInventories(first, metadataOnly), {
    classification: 'zip-container-or-signing-metadata-only',
    byteIdentical: false,
    payloadIdentical: true,
    differingEntries: [],
  });

  const changed = structuredClone(metadataOnly);
  changed.entries[1].sha256 = '3'.repeat(64);
  assert.deepEqual(compareApkInventories(first, changed), {
    classification: 'payload-drift',
    byteIdentical: false,
    payloadIdentical: false,
    differingEntries: ['classes.dex'],
  });
});

test('the complete technical gate retains the R10 contract tests', () => {
  assert.match(
    technicalRegression,
    /node --check tool\/run_r10_clean_reproducibility\.mjs\nnode --test test\/tool\/run_r10_clean_reproducibility\.test\.mjs/u,
  );
});
