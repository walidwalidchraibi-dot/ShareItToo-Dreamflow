#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_ID="com.shareittoo.app"

cd "$ROOT"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

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

if rg -n "com\.mycompany|CounterApp|Dreamflow|dreamflow" \
  android ios lib pubspec.yaml >/dev/null; then
  fail "Legacy application identity remains in release source files."
fi

grep -Fq "applinks:shareittoo.com" ios/Runner/Runner.entitlements || \
  fail "iOS associated-domain entitlement is missing."
grep -Fq 'android:autoVerify="true"' android/app/src/main/AndroidManifest.xml || \
  fail "Android verified links are not enabled."

if command -v plutil >/dev/null 2>&1; then
  plutil -lint ios/Runner/Info.plist ios/Runner/Runner.entitlements >/dev/null
fi

master_description="$(file assets/images/shareittoo_app_icon_master.png)"
[[ "$master_description" == *"1024 x 1024"* ]] || \
  fail "App icon master must be exactly 1024 x 1024 pixels."

[[ -f android/key.properties ]] || \
  fail "android/key.properties is required for a signed release build."

echo "Release candidate preflight passed for $EXPECTED_ID, version $version."
