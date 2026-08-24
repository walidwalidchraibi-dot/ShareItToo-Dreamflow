import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import {
  parsePubspecBuildIdentity,
  prepareAndroidDebugBuildMetadata,
} from '../../tool/prepare_android_debug_build_metadata.mjs';

test('parses only the repository build identity shape', () => {
  assert.deepEqual(parsePubspecBuildIdentity('name: sit\nversion: 1.0.0+2026082302\n'), {
    versionName: '1.0.0',
    versionCode: '2026082302',
  });
  assert.throws(
    () => parsePubspecBuildIdentity('version: 1.0.0+1\n'),
    /android_debug_pubspec_identity_invalid/u,
  );
});

test('replaces stale generated version metadata from checked-in pubspec', async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'sit-debug-build-metadata-test-'));
  t.after(async () => rm(root, { recursive: true, force: true }));
  await mkdir(path.join(root, 'android'), { recursive: true });
  await writeFile(path.join(root, 'pubspec.yaml'), 'version: 1.0.0+2026082302\n');
  await writeFile(path.join(root, 'android/local.properties'), [
    'sdk.dir=/old/sdk',
    'flutter.sdk=/old/flutter',
    'flutter.versionName=1.0',
    'flutter.versionCode=1',
    '',
  ].join('\n'));

  const result = await prepareAndroidDebugBuildMetadata({
    root,
    androidSdkRoot: '/verified/android sdk',
    flutterRoot: '/verified/flutter',
    env: {},
  });
  assert.deepEqual(result, {
    versionName: '1.0.0',
    versionCode: '2026082302',
    buildMode: 'debug',
    metadataPath: 'android/local.properties',
    toolPathsPrinted: false,
  });
  assert.equal(await readFile(path.join(root, 'android/local.properties'), 'utf8'), [
    'sdk.dir=/verified/android\\ sdk',
    'flutter.sdk=/verified/flutter',
    'flutter.buildMode=debug',
    'flutter.versionName=1.0.0',
    'flutter.versionCode=2026082302',
    '',
  ].join('\n'));
});
