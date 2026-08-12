#!/usr/bin/env bash
set -euo pipefail

# Transitional analyzer baseline for the existing legacy issue backlog.
# Keep this in sync with the accepted repository baseline until the backlog is reduced.
ANALYZER_BASELINE=628
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: flutter is not available in PATH." >&2
  exit 1
fi

if ! command -v dart >/dev/null 2>&1; then
  echo "ERROR: dart is not available in PATH." >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: node is not available in PATH." >&2
  exit 1
fi

flutter --version

dart --version

dart run tool/validate_store_metadata.dart
node --test test/tool/validate_store_metadata_cli.test.mjs

node --check tool/validate_legal_readiness.mjs
node --test test/tool/validate_legal_readiness.test.mjs
node tool/validate_legal_readiness.mjs

node --check tool/validate_privacy_disclosures.mjs
node --test test/tool/validate_privacy_disclosures.test.mjs
node tool/validate_privacy_disclosures.mjs

node --check tool/validate_retention_deletion_readiness.mjs
node --test test/tool/validate_retention_deletion_readiness.test.mjs
node tool/validate_retention_deletion_readiness.mjs

node --check tool/diagnose_store_review_accounts.mjs
node --test test/tool/diagnose_store_review_accounts.test.mjs
node --check tool/diagnose_store_review_safety_actions.mjs
node --test test/tool/diagnose_store_review_safety_actions.test.mjs
node --check tool/diagnose_store_review_disposable_deletion.mjs
node --test test/tool/diagnose_store_review_disposable_deletion.test.mjs
node --check tool/validate_store_review_access.mjs
node --test test/tool/validate_store_review_access.test.mjs
node tool/validate_store_review_access.mjs

node --check tool/validate_device_evidence.mjs
node --test test/tool/validate_device_evidence.test.mjs
node tool/validate_device_evidence.mjs

node --check tool/validate_b11_release_docs.mjs
node --test test/tool/validate_b11_release_docs.test.mjs
node tool/validate_b11_release_docs.mjs

node --check tool/validate_google_play_internal_handoff.mjs
node --test test/tool/validate_google_play_internal_handoff.test.mjs

node --check tool/validate_google_play_closed_testing.mjs
node --test test/tool/validate_google_play_closed_testing.test.mjs
node --check tool/prepare_google_play_closed_testing_observation.mjs
node --test test/tool/prepare_google_play_closed_testing_observation.test.mjs
node --test test/tool/google_play_closed_testing_wiring.test.mjs
node tool/validate_google_play_closed_testing.mjs
node --check tool/validate_google_play_closed_testing_feedback.mjs
node --test test/tool/validate_google_play_closed_testing_feedback.test.mjs
node tool/validate_google_play_closed_testing_feedback.mjs
node --check tool/validate_google_play_production_access_application.mjs
node --test test/tool/validate_google_play_production_access_application.test.mjs
node tool/validate_google_play_production_access_application.mjs

node --check tool/validate_apple_testflight_handoff.mjs
node --test test/tool/validate_apple_testflight_handoff.test.mjs

node --check tool/prepare_android_device_test.mjs
node --test test/tool/prepare_android_device_test.test.mjs

node --check tool/diagnose_android_app_links.mjs
node --test test/tool/diagnose_android_app_links.test.mjs
node --check tool/diagnose_android_authenticated_session.mjs
node --test test/tool/diagnose_android_authenticated_session.test.mjs
node --check tool/diagnose_android_authenticated_links.mjs
node --test test/tool/diagnose_android_authenticated_links.test.mjs
node --check tool/run_isolated_android_authenticated_links_diagnostic.mjs
node --test test/tool/run_isolated_android_authenticated_links_diagnostic.test.mjs
node --check tool/provision_staging_test_accounts.mjs
node --test test/tool/provision_staging_test_accounts.test.mjs
node --check tool/prepare_store_screenshot_fixture.mjs
node --test test/tool/prepare_store_screenshot_fixture.test.mjs
node --check tool/run_staging_synthetic_booking.mjs
node --test test/tool/run_staging_synthetic_booking.test.mjs
node --check tool/run_isolated_android_role_booking_diagnostic.mjs
node --test test/tool/run_isolated_android_role_booking_diagnostic.test.mjs

node --check tool/validate_firebase_release_config.mjs
node --test test/tool/validate_firebase_release_config.test.mjs
node tool/validate_firebase_release_config.mjs

node --check tool/validate_android_signing_config.mjs
node --test test/tool/validate_android_signing_config.test.mjs

node --check tool/verify_brand_assets.mjs
node tool/verify_brand_assets.mjs

analyze_log="$(mktemp)"
trap 'rm -f "$analyze_log"' EXIT

set +e
flutter analyze 2>&1 | tee "$analyze_log"
analyze_status=${PIPESTATUS[0]}
set -e

issue_count="$({
  grep -Eo '(^|[^0-9])[0-9]+ issue(s)? found\.' "$analyze_log" || true
} | tail -n1 | grep -Eo '[0-9]+' || true)"

if [[ -z "$issue_count" ]]; then
  echo "ERROR: Could not parse analyzer issue count from flutter analyze output." >&2
  exit 1
fi

if (( issue_count > ANALYZER_BASELINE )); then
  echo "ERROR: Analyzer regression detected: ${issue_count} issues (baseline ${ANALYZER_BASELINE})." >&2
  exit 1
fi

if (( issue_count < ANALYZER_BASELINE )); then
  echo "Analyzer improvement detected; baseline update recommended (${issue_count} < ${ANALYZER_BASELINE})."
else
  echo "Analyzer baseline accepted (${issue_count} issues)."
fi

if (( analyze_status == 0 )) && (( issue_count > 0 )); then
  echo "ERROR: flutter analyze exited 0 but reported ${issue_count} issues; refusing ambiguous success." >&2
  exit 1
fi

if (( analyze_status != 0 )) && (( issue_count == 0 )); then
  echo "ERROR: flutter analyze exited ${analyze_status} despite reporting zero issues; refusing ambiguous failure." >&2
  exit 1
fi

flutter test --reporter expanded

flutter build web --debug

flutter build apk --debug
