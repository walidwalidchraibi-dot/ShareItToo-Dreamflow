#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANNEL="${SIT_RELEASE_CHANNEL:-internal}"
API_BASE_URL="${SIT_API_BASE_URL:-https://staging.shareittoo.com/api/v1}"
REQUIRE_CLEAN="${SIT_REQUIRE_CLEAN:-1}"

cd "$ROOT"

if [[ "$REQUIRE_CLEAN" == "1" ]] && [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: Commit-bound release builds require a clean Git worktree." >&2
  exit 1
fi

commit="$(git rev-parse HEAD)"
version="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
build_name="${version%%+*}"
build_number="${version##*+}"

bash scripts/release_candidate_preflight.sh

common_args=(
  --release
  "--build-name=$build_name"
  "--build-number=$build_number"
  "--dart-define=SIT_BACKEND_ENABLED=true"
  "--dart-define=SIT_API_BASE_URL=$API_BASE_URL"
  "--dart-define=SIT_APP_COMMIT=$commit"
  "--dart-define=SIT_BUILD_NUMBER=$build_number"
  "--dart-define=SIT_RELEASE_CHANNEL=$CHANNEL"
  "--dart-define=SIT_BUNDLE_ID=com.shareittoo.app"
)

flutter build appbundle "${common_args[@]}"
flutter build apk "${common_args[@]}"

aab="build/app/outputs/bundle/release/app-release.aab"
apk="build/app/outputs/flutter-apk/app-release.apk"
[[ -f "$aab" ]] || { echo "ERROR: AAB was not created." >&2; exit 1; }
[[ -f "$apk" ]] || { echo "ERROR: APK was not created." >&2; exit 1; }

# Upload keys are intentionally self-signed. Verify the JAR signature itself;
# `-strict` would reject the expected self-signed certificate chain.
jarsigner -verify "$aab" >/dev/null

build_tools_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}/build-tools"
build_tools="$(find "$build_tools_root" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n1)"
[[ -x "$build_tools/apksigner" ]] || { echo "ERROR: apksigner is unavailable." >&2; exit 1; }
[[ -x "$build_tools/aapt" ]] || { echo "ERROR: aapt is unavailable." >&2; exit 1; }
"$build_tools/apksigner" verify --verbose "$apk" >/dev/null
"$build_tools/aapt" dump badging "$apk" | grep -Fq "package: name='com.shareittoo.app' versionCode='$build_number' versionName='$build_name'" || {
  echo "ERROR: APK package or version identity does not match the release request." >&2
  exit 1
}

evidence_dir="build/release-evidence/android-$build_number"
mkdir -p "$evidence_dir"
aab_sha="$(shasum -a 256 "$aab" | awk '{print $1}')"
apk_sha="$(shasum -a 256 "$apk" | awk '{print $1}')"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

printf '%s\n' \
  "{" \
  "  \"platform\": \"android\"," \
  "  \"applicationId\": \"com.shareittoo.app\"," \
  "  \"versionName\": \"$build_name\"," \
  "  \"versionCode\": \"$build_number\"," \
  "  \"commit\": \"$commit\"," \
  "  \"channel\": \"$CHANNEL\"," \
  "  \"apiBaseUrl\": \"$API_BASE_URL\"," \
  "  \"createdAt\": \"$created_at\"," \
  "  \"aabSha256\": \"$aab_sha\"," \
  "  \"apkSha256\": \"$apk_sha\"" \
  "}" > "$evidence_dir/manifest.json"

cp "$aab" "$evidence_dir/shareittoo-$build_name-$build_number-$commit.aab"
cp "$apk" "$evidence_dir/shareittoo-$build_name-$build_number-$commit.apk"

echo "Signed Android release candidate created for commit $commit."
echo "Evidence: $evidence_dir/manifest.json"
