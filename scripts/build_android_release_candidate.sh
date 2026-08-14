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

SIT_FIREBASE_VALIDATION_PLATFORM=android bash scripts/release_candidate_preflight.sh

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

if [[ -n "${SIT_FACEBOOK_APP_ID:-}" ]]; then
  export SIT_FACEBOOK_APP_ID
fi
if [[ -n "${SIT_FACEBOOK_CLIENT_TOKEN:-}" ]]; then
  export SIT_FACEBOOK_CLIENT_TOKEN
fi

if [[ "${SIT_ENABLE_STAGING_CRASH_DIAGNOSTIC:-0}" == "1" ]]; then
  diagnostic_run_id="${SIT_STAGING_CRASH_DIAGNOSTIC_RUN_ID:-}"
  if [[ "$API_BASE_URL" != "https://staging.shareittoo.com/api/v1" ||
        "$CHANNEL" != "internal" ||
        "${SIT_REQUIRE_STORE_SUBMISSION:-0}" == "1" ||
        ! "$diagnostic_run_id" =~ ^b11-[a-z0-9-]{6,64}$ ]]; then
    echo "ERROR: Controlled Crashlytics diagnostics require internal staging, a safe run ID, and a non-submission build." >&2
    exit 1
  fi
  common_args+=(
    "--dart-define=SIT_ENABLE_STAGING_CRASH_DIAGNOSTIC=true"
    "--dart-define=SIT_STAGING_CRASH_DIAGNOSTIC_RUN_ID=$diagnostic_run_id"
  )
fi

firebase_define_names=(
  SIT_FIREBASE_PROJECT_ID
  SIT_FIREBASE_MESSAGING_SENDER_ID
  SIT_FIREBASE_STORAGE_BUCKET
  SIT_FIREBASE_ANDROID_APP_ID
  SIT_FIREBASE_ANDROID_API_KEY
  SIT_FIREBASE_IOS_APP_ID
  SIT_FIREBASE_IOS_API_KEY
)
for define_name in "${firebase_define_names[@]}"; do
  define_value="${!define_name:-}"
  if [[ -n "$define_value" ]]; then
    common_args+=("--dart-define=$define_name=$define_value")
  fi
done

legal_define_names=(
  SIT_LEGAL_PROVIDER_APPROVED
  SIT_LEGAL_PROVIDER_NAME
  SIT_LEGAL_PROVIDER_ADDRESS
  SIT_LEGAL_REPRESENTATIVE
  SIT_LEGAL_CONTENT_RESPONSIBLE
  SIT_LEGAL_CONTACT_EMAIL
  SIT_LEGAL_CONTACT_PHONE
)
for define_name in "${legal_define_names[@]}"; do
  define_value="${!define_name:-}"
  if [[ -n "$define_value" ]]; then
    common_args+=("--dart-define=$define_name=$define_value")
  fi
done

# A Maps credential belongs only on the backend. Refuse legacy build
# environments so it cannot accidentally be embedded in a release binary.
if [[ -n "${GOOGLE_MAPS_API_KEY:-}" ]]; then
  echo "ERROR: GOOGLE_MAPS_API_KEY must not be embedded in an app build; configure GOOGLE_MAPS_SERVER_API_KEY only on the backend." >&2
  exit 1
fi

if [[ "${SIT_REQUIRE_FIREBASE:-0}" == "1" ]]; then
  node tool/validate_firebase_release_config.mjs --require-configured --platform android
fi

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
signing_certificate_sha256="$("$build_tools/apksigner" verify --print-certs "$apk" | \
  sed -E -n 's/^(V[0-9]+ Signer:|Signer #[0-9]+) certificate SHA-256 digest: ([0-9A-Fa-f]{64})$/\2/p' | \
  head -n1 | tr '[:upper:]' '[:lower:]')"
[[ "$signing_certificate_sha256" =~ ^[0-9a-f]{64}$ ]] || {
  echo "ERROR: APK signing certificate SHA-256 could not be verified." >&2
  exit 1
}
canonical_signing_certificate_sha256="098f485e57161558e911fc3c742845925584db31c474cdba08dda02feb0129a4"
if [[ "${SIT_REQUIRE_STORE_SUBMISSION:-0}" == "1" && \
      "$signing_certificate_sha256" != "$canonical_signing_certificate_sha256" ]]; then
  echo "ERROR: Store candidate is not signed by the canonical ShareItToo upload certificate." >&2
  exit 1
fi
"$build_tools/aapt" dump badging "$apk" | grep -Fq "package: name='com.shareittoo.app' versionCode='$build_number' versionName='$build_name'" || {
  echo "ERROR: APK package or version identity does not match the release request." >&2
  exit 1
}

evidence_dir="build/release-evidence/android-$build_number"
mkdir -p "$evidence_dir"
privacy_report="$evidence_dir/privacy-scan.json"
node tool/verify_android_binary_privacy.mjs \
  --apk "$apk" \
  --aab "$aab" \
  --aapt "$build_tools/aapt" \
  --commit "$commit" \
  --api-base-url "$API_BASE_URL" \
  --version-name "$build_name" \
  --version-code "$build_number" \
  --output "$privacy_report"

aab_sha="$(shasum -a 256 "$aab" | awk '{print $1}')"
apk_sha="$(shasum -a 256 "$apk" | awk '{print $1}')"
privacy_report_sha="$(shasum -a 256 "$privacy_report" | awk '{print $1}')"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
firebase_configured=false
if [[ -n "${SIT_FIREBASE_PROJECT_ID:-}" && \
      -n "${SIT_FIREBASE_MESSAGING_SENDER_ID:-}" && \
      -n "${SIT_FIREBASE_ANDROID_APP_ID:-}" && \
      -n "${SIT_FIREBASE_ANDROID_API_KEY:-}" ]]; then
  firebase_configured=true
fi

printf '%s\n' \
  "{" \
  "  \"platform\": \"android\"," \
  "  \"applicationId\": \"com.shareittoo.app\"," \
  "  \"versionName\": \"$build_name\"," \
  "  \"versionCode\": \"$build_number\"," \
  "  \"commit\": \"$commit\"," \
  "  \"channel\": \"$CHANNEL\"," \
  "  \"apiBaseUrl\": \"$API_BASE_URL\"," \
  "  \"firebaseConfigured\": $firebase_configured," \
  "  \"signingCertificateSha256\": \"$signing_certificate_sha256\"," \
  "  \"createdAt\": \"$created_at\"," \
  "  \"androidBinaryPrivacyScan\": \"passed\"," \
  "  \"androidBinaryPrivacyReport\": \"privacy-scan.json\"," \
  "  \"androidBinaryPrivacyReportSha256\": \"$privacy_report_sha\"," \
  "  \"aabSha256\": \"$aab_sha\"," \
  "  \"apkSha256\": \"$apk_sha\"" \
  "}" > "$evidence_dir/manifest.json"

cp "$aab" "$evidence_dir/shareittoo-$build_name-$build_number-$commit.aab"
cp "$apk" "$evidence_dir/shareittoo-$build_name-$build_number-$commit.apk"

node tool/archive_android_release_candidate.mjs

echo "Signed Android release candidate created for commit $commit."
echo "Evidence: $evidence_dir/manifest.json"
