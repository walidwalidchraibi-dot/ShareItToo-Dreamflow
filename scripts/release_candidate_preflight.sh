#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_ID="com.shareittoo.app"

cd "$ROOT"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v dart >/dev/null 2>&1 || fail "dart is required for store metadata validation."
command -v node >/dev/null 2>&1 || fail "node is required for public store page validation."
node --check tool/verify_public_store_pages.mjs
node --check tool/verify_brand_assets.mjs
node --check tool/verify_android_binary_privacy.mjs
node --check tool/validate_device_evidence.mjs
node --check tool/validate_legal_readiness.mjs
node --check tool/diagnose_store_review_accounts.mjs
node --check tool/validate_store_review_access.mjs
node --check tool/validate_b11_release_docs.mjs
node --check tool/prepare_android_device_test.mjs
node --check tool/diagnose_android_app_links.mjs
node --check tool/diagnose_android_authenticated_session.mjs
node --check tool/diagnose_android_authenticated_links.mjs
node --check tool/run_staging_synthetic_booking.mjs
node --check tool/validate_firebase_release_config.mjs
node --check tool/validate_android_signing_config.mjs
node tool/verify_brand_assets.mjs
dart run tool/validate_store_metadata.dart
node tool/validate_device_evidence.mjs
node tool/validate_legal_readiness.mjs
node tool/validate_store_review_access.mjs
if [[ "${SIT_ALLOW_CANDIDATE_ROLLOVER:-0}" == "1" ]]; then
  [[ "${SIT_RELEASE_CHANNEL:-internal}" == "internal" ]] || \
    fail "Candidate rollover is restricted to the internal channel."
  [[ "${SIT_API_BASE_URL:-https://staging.shareittoo.com/api/v1}" == \
      "https://staging.shareittoo.com/api/v1" ]] || \
    fail "Candidate rollover is restricted to the isolated staging API."
  [[ "${SIT_REQUIRE_STORE_SUBMISSION:-0}" != "1" ]] || \
    fail "Candidate rollover is forbidden for a Store-submission build."
  node tool/validate_b11_release_docs.mjs --allow-candidate-rollover
else
  node tool/validate_b11_release_docs.mjs
fi
node tool/validate_firebase_release_config.mjs
if [[ "${SIT_REQUIRE_STORE_SUBMISSION:-0}" == "1" ]]; then
  node tool/validate_firebase_release_config.mjs --require-configured --platform all
  node tool/validate_device_evidence.mjs --require-passed
  node tool/validate_legal_readiness.mjs --require-approved
  node tool/validate_store_review_access.mjs --require-ready
  dart run tool/validate_store_metadata.dart --require-submittable
  node tool/verify_public_store_pages.mjs
fi

version="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]{10}$ ]] || \
  fail "pubspec version must use semantic version plus YYYYMMDDNN build number."

build_number="${version##*+}"
(( 10#$build_number <= 2100000000 )) || fail "Android versionCode exceeds the Play limit."

grep -Fq "applicationId = \"$EXPECTED_ID\"" android/app/build.gradle || \
  fail "Android applicationId does not match $EXPECTED_ID."
grep -Fq "namespace = \"$EXPECTED_ID\"" android/app/build.gradle || \
  fail "Android namespace does not match $EXPECTED_ID."
grep -Fq "PRODUCT_BUNDLE_IDENTIFIER = $EXPECTED_ID;" ios/Runner.xcodeproj/project.pbxproj || \
  fail "iOS bundle identifier does not match $EXPECTED_ID."

# Search only version-controlled release sources. Recursive grep also sees
# Gradle/Flutter caches created by an earlier debug build and can therefore
# report stale identity strings that are not part of the candidate.
legacy_identity_found="$(git grep -nE \
  "com\.mycompany|CounterApp|Dreamflow|dreamflow" \
  -- android ios lib pubspec.yaml || true)"
if [[ -n "$legacy_identity_found" ]]; then
  fail "Legacy application identity remains in release source files."
fi

grep -Fq "applinks:shareittoo.com" ios/Runner/Runner.entitlements || \
  fail "iOS associated-domain entitlement is missing."
grep -Fq '<key>aps-environment</key>' ios/Runner/Runner.entitlements || \
  fail "iOS push-notification entitlement is missing."
grep -Fq 'android:autoVerify="true"' android/app/src/main/AndroidManifest.xml || \
  fail "Android verified links are not enabled."
grep -Fq 'android:allowBackup="false"' android/app/src/main/AndroidManifest.xml || \
  fail "Android application backup must be disabled."
grep -Fq 'android:usesCleartextTraffic="false"' android/app/src/main/AndroidManifest.xml || \
  fail "Android cleartext traffic must be disabled."
grep -Fq 'android:maxSdkVersion="32"' android/app/src/main/AndroidManifest.xml || \
  fail "Legacy Android read-storage permission must be capped at API 32."
grep -Fq 'android:maxSdkVersion="28"' android/app/src/main/AndroidManifest.xml || \
  fail "Legacy Android write-storage permission must be capped at API 28."
if grep -Fq 'android:requestLegacyExternalStorage' android/app/src/main/AndroidManifest.xml; then
  fail "Legacy Android external storage mode must not be enabled."
fi
[[ -f android/app/src/main/res/xml/backup_rules.xml ]] || \
  fail "Android backup exclusion rules are missing."
[[ -f android/app/src/main/res/xml/data_extraction_rules.xml ]] || \
  fail "Android data extraction rules are missing."

if command -v plutil >/dev/null 2>&1; then
  plutil -lint ios/Runner/Info.plist ios/Runner/Runner.entitlements >/dev/null
fi

master_description="$(file assets/images/shareittoo_app_icon_master.png)"
[[ "$master_description" == *"1024 x 1024"* ]] || \
  fail "App icon master must be exactly 1024 x 1024 pixels."

[[ -f android/key.properties ]] || \
  fail "android/key.properties is required for a signed release build."
if [[ "${SIT_REQUIRE_STORE_SUBMISSION:-0}" == "1" ]]; then
  node tool/validate_android_signing_config.mjs --require-canonical
else
  node tool/validate_android_signing_config.mjs
fi

echo "Release candidate preflight passed for $EXPECTED_ID, version $version."
