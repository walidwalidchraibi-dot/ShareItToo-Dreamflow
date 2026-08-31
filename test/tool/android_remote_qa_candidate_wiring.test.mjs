import assert from 'node:assert/strict';
import { readFileSync, statSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';

const root = resolve(import.meta.dirname, '..', '..');
const read = (path) => readFileSync(resolve(root, path), 'utf8');

test('Remote QA Android wiring is separate, staging-only and owner-distributed', () => {
  const gradle = read('android/app/build.gradle');
  const manifest = read('android/app/src/main/AndroidManifest.xml');
  const identity = read('lib/services/release_identity.dart');
  const build = read('scripts/build_android_remote_qa_candidate.sh');
  const privacy = read('tool/verify_android_binary_privacy.mjs');

  assert.match(gradle, /SIT_REMOTE_QA_BUILD/u);
  assert.match(gradle, /SIT_DISABLE_FIREBASE_ANDROID_PLUGINS/u);
  assert.match(gradle, /remoteQaRequested != firebaseAndroidPluginsDisabled/u);
  assert.match(gradle, /com\.shareittoo\.app\.qa/u);
  assert.match(gradle, /ShareItToo QA/u);
  assert.match(manifest, /\$\{sitAppLabel\}/u);
  assert.match(manifest, /\$\{sitAppLinksAutoVerify\}/u);

  assert.match(identity, /remoteQa != remoteQaIdentity/u);
  assert.match(identity, /remoteQa && channel != 'staging'/u);

  assert.match(build, /https:\/\/staging\.shareittoo\.com\/api\/v1/u);
  assert.match(build, /com\.shareittoo\.app\.qa/u);
  assert.match(build, /--split-per-abi/u);
  assert.match(build, /app-arm64-v8a-release\.apk/u);
  assert.match(build, /SIT_SOCIAL_GOOGLE_ENABLED=false/u);
  assert.match(build, /SIT_SOCIAL_APPLE_ENABLED=false/u);
  assert.match(build, /SIT_SOCIAL_FACEBOOK_ENABLED=false/u);
  assert.match(build, /SIT_REQUIRE_STORE_SUBMISSION/u);
  assert.ok(build.includes('\\"storeUploaded\\": false'));
  assert.ok(build.includes('\\"productionAllowed\\": false'));
  assert.ok(build.includes('\\"realMoneyAllowed\\": false'));
  assert.doesNotMatch(build, /127\.0\.0\.1/u);

  assert.match(privacy, /args\['application-id'\]/u);
  assert.ok(privacy.includes('^com\\.shareittoo\\.app(?:\\.qa)?$'));

  const mode = statSync(resolve(root, 'scripts/build_android_remote_qa_candidate.sh')).mode;
  assert.equal(mode & 0o077, 0, 'Remote QA build script must be owner-only executable');
});
