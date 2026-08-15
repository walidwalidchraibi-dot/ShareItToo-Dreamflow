import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const workflow = readFileSync(
  new URL('../../.github/workflows/regression.yml', import.meta.url),
  'utf8',
);
const androidBuild = readFileSync(
  new URL('../../scripts/build_android_release_candidate.sh', import.meta.url),
  'utf8',
);
const releasePreflight = readFileSync(
  new URL('../../scripts/release_candidate_preflight.sh', import.meta.url),
  'utf8',
);
const technicalRegression = readFileSync(
  new URL('../../scripts/technical_regression_check.sh', import.meta.url),
  'utf8',
);
const wrapperProperties = readFileSync(
  new URL('../../android/gradle/wrapper/gradle-wrapper.properties', import.meta.url),
  'utf8',
);

test('CI validates the documented incomplete Android candidate as a safe rollover', () => {
  assert.match(
    workflow,
    /name: Run regression script[\s\S]*?SIT_ALLOW_CANDIDATE_ROLLOVER: '1'[\s\S]*?bash scripts\/technical_regression_check\.sh/,
  );
  assert.match(
    workflow,
    /name: Build a signed, commit-bound Android release candidate[\s\S]*?SIT_ALLOW_CANDIDATE_ROLLOVER: '1'[\s\S]*?bash scripts\/build_android_release_candidate\.sh/,
  );
});

test('Android packaging scopes Firebase validation to Android', () => {
  assert.match(
    androidBuild,
    /SIT_FIREBASE_VALIDATION_PLATFORM=android bash scripts\/release_candidate_preflight\.sh/,
  );
});

test('candidate rollover keeps the prior phone evidence read-only until the new binary is tested', () => {
  assert.match(
    releasePreflight,
    /validate_phone_verification_readiness\.mjs --allow-candidate-rollover/,
  );
  assert.match(
    technicalRegression,
    /validate_phone_verification_readiness\.mjs --allow-candidate-rollover/,
  );
});

test('Android packaging derives missing Firebase client values from the exact local config without logging them', () => {
  assert.match(androidBuild, /deriveAndroidFirebaseReleaseEnvironment/);
  assert.match(androidBuild, /android\/app\/google-services\.json/);
  assert.ok(
    androidBuild.indexOf('deriveAndroidFirebaseReleaseEnvironment')
      < androidBuild.indexOf('release_candidate_preflight.sh'),
  );
  assert.doesNotMatch(androidBuild, /echo "\$firebase_env_lines"/);
});

test('local Android regression derives the same exact Firebase client values without logging them', () => {
  assert.match(technicalRegression, /deriveAndroidFirebaseReleaseEnvironment/);
  assert.match(technicalRegression, /android\/app\/google-services\.json/);
  assert.ok(
    technicalRegression.indexOf('deriveAndroidFirebaseReleaseEnvironment')
      < technicalRegression.indexOf('validate_firebase_release_config.mjs --platform'),
  );
  assert.doesNotMatch(technicalRegression, /echo "\$firebase_env_lines"/);
});

test('direct Android preflight derives the same exact Firebase client values without logging them', () => {
  assert.match(releasePreflight, /deriveAndroidFirebaseReleaseEnvironment/);
  assert.match(releasePreflight, /android\/app\/google-services\.json/);
  assert.ok(
    releasePreflight.indexOf('deriveAndroidFirebaseReleaseEnvironment')
      < releasePreflight.indexOf('validate_firebase_release_config.mjs --platform'),
  );
  assert.doesNotMatch(releasePreflight, /echo "\$firebase_env_lines"/);
});

test('Android packaging exposes a preflight-only path before either binary build', () => {
  assert.match(androidBuild, /SIT_BUILD_PREFLIGHT_ONLY/);
  const preflightOnly = androidBuild.indexOf('Android release build preflight passed without creating artifacts.');
  assert.ok(preflightOnly > androidBuild.indexOf('validate_firebase_release_config.mjs --require-configured'));
  assert.ok(preflightOnly < androidBuild.indexOf('flutter build appbundle'));
  assert.ok(preflightOnly < androidBuild.indexOf('flutter build apk'));
});

test('CI provisions and caches the checksum-verified Gradle wrapper before Flutter builds', () => {
  assert.match(workflow, /uses: gradle\/actions\/setup-gradle@v6/);
  assert.match(workflow, /cache-provider: basic/);
  assert.match(
    workflow,
    /name: Provision the verified Gradle wrapper[\s\S]*?for attempt in 1 2 3; do[\s\S]*?\.\/android\/gradlew --version/,
  );
  assert.match(
    wrapperProperties,
    /^distributionUrl=https\\:\/\/downloads\.gradle\.org\/distributions\/gradle-8\.12-bin\.zip$/m,
  );
  assert.match(
    wrapperProperties,
    /^distributionSha256Sum=7a00d51fb93147819aab76024feece20b6b84e420694101f276be952e08bef03$/m,
  );
  assert.match(wrapperProperties, /^networkTimeout=60000$/m);
  assert.match(wrapperProperties, /^validateDistributionUrl=true$/m);
});
