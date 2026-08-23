#!/usr/bin/env bash
set -euo pipefail

# Transitional analyzer baseline for the existing legacy issue backlog.
# Keep this in sync with the accepted repository baseline until the backlog is reduced.
# Re-measured on Flutter 3.41.7 / Dart 3.11.5 on 2026-08-16 after the first
# safe mechanical cleanup, the targeted correctness/startup-safety batch, and
# removal of all unused local variables, private state remnants, and
# unreferenced legacy UI components without changing reachable UI paths.
FORBIDDEN_ANALYZER_CODES=(
  dead_code
  empty_catches
  equal_keys_in_map
  unreachable_switch_default
  unused_import
  unused_local_variable
)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT"

source scripts/release_host_capacity_guard.sh
release_host_capacity_begin

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

bash scripts/test_temp_fixture_boundedness.sh

if [[ "${SIT_ALLOW_CANDIDATE_ROLLOVER:-0}" == "1" ]]; then
  dart run tool/validate_store_metadata.dart --allow-candidate-rollover
else
  dart run tool/validate_store_metadata.dart
fi
node --test test/tool/validate_store_metadata_cli.test.mjs

node --check tool/validate_legal_readiness.mjs
node --test test/tool/validate_legal_readiness.test.mjs
node tool/validate_legal_readiness.mjs

node --check tool/validate_support_launch_content.mjs
node --test test/tool/validate_support_launch_content.test.mjs
node --test backend/test/consumer_dispute_config.test.js backend/test/support_message_domain.test.js backend/test/support_message_workflow.test.js
node tool/validate_support_launch_content.mjs

node --check tool/validate_product_safety_readiness.mjs
node --test test/tool/validate_product_safety_readiness.test.mjs backend/test/product_safety_config.test.js
node tool/validate_product_safety_readiness.mjs

node --check tool/validate_founder_independence_guardrails.mjs
node --test test/tool/validate_founder_independence_guardrails.test.mjs
node tool/validate_founder_independence_guardrails.mjs

node --check tool/validate_operational_delegation.mjs
node --test test/tool/validate_operational_delegation.test.mjs
node tool/validate_operational_delegation.mjs

node --check tool/validate_p0a_closed_pilot_readiness.mjs
node --test test/tool/validate_p0a_closed_pilot_readiness.test.mjs
node --test test/tool/p0a_web_smoke_readiness.test.mjs
PYTHONDONTWRITEBYTECODE=1 python3 test/tool/seed_booking_qa_cdp_event_test.py
node tool/validate_p0a_closed_pilot_readiness.mjs

node --check tool/validate_p0b_pilot_dossier.mjs
node --test test/tool/validate_p0b_pilot_dossier.test.mjs
node tool/validate_p0b_pilot_dossier.mjs

node --check tool/validate_privacy_disclosures.mjs
node --check tool/validate_support_test_matrix_traceability.mjs
node --test test/tool/validate_support_test_matrix_traceability.test.mjs
node tool/validate_support_test_matrix_traceability.mjs
node --check tool/validate_support_evidence_external_readiness.mjs
node --test test/tool/validate_support_evidence_external_readiness.test.mjs
node tool/validate_support_evidence_external_readiness.mjs
node --check tool/validate_active_infrastructure_mail_provider_readiness.mjs
node --test test/tool/validate_active_infrastructure_mail_provider_readiness.test.mjs
node tool/validate_active_infrastructure_mail_provider_readiness.mjs
node --test test/tool/validate_privacy_disclosures.test.mjs
node --test test/tool/validate_messaging_launch_scope.test.mjs
node --test test/tool/support_final_decision_wiring.test.mjs
node --test test/tool/support_appeal_wiring.test.mjs
node --test test/tool/support_break_glass_wiring.test.mjs
node --test test/tool/support_message_template_wiring.test.mjs
node --test test/tool/support_status_machine_v1_alignment_wiring.test.mjs
node --test test/tool/support_deadline_watchdog_wiring.test.mjs
node --test test/tool/support_operational_privacy_wiring.test.mjs
node --test test/tool/support_legacy_migration_wiring.test.mjs
node --test test/tool/support_evidence_security_wiring.test.mjs
node --test test/tool/support_safety_impact_wiring.test.mjs
node --test test/tool/support_duplicate_case_linking_wiring.test.mjs
node --test test/tool/support_feedback_priority_wiring.test.mjs
node --test test/tool/support_progress_update_wiring.test.mjs
node --test test/tool/support_single_issue_intake_wiring.test.mjs
node --test test/tool/support_privacy_intake_wiring.test.mjs
node --test test/tool/support_account_deletion_retention_wiring.test.mjs
node --test test/tool/support_dsa_notice_intake_wiring.test.mjs
node --test test/tool/support_dsa_notice_locator_completion_wiring.test.mjs
node --test test/tool/s3p_statement_of_reasons_wiring.test.mjs
node --test test/tool/s3q_independent_moderation_review_wiring.test.mjs
node --test backend/test/moderation_account_measure_domain.test.js
node --test test/tool/support_article18_guard_wiring.test.mjs
node --test test/tool/support_privacy_rights_control_plane_wiring.test.mjs
node --test test/tool/support_privacy_incident_control_plane_wiring.test.mjs
node --test test/tool/file_picker_security_upgrade.test.mjs
node --test test/tool/pdf_wasm_dependency_upgrade.test.mjs
node --test test/tool/printing_web_pdfjs_reachability.test.mjs
node --test test/tool/mobile_scanner_iphone17_floor.test.mjs
node --test test/tool/android_lifecycle_gradle_floor.test.mjs
node --test test/tool/android_gradle9_bridge_floor.test.mjs
node --test test/tool/android_path_provider_gradle_floor.test.mjs
node --test test/tool/android_gradle_warning_visibility.test.mjs
node --test test/tool/codeql_workflow_wiring.test.mjs
node --test test/tool/pr7_integration_pilot_candidate_plan_wiring.test.mjs
node --test test/tool/closed_android_pilot_test_measurement_plan_wiring.test.mjs
node --test test/tool/validate_android_photo_picker_policy.test.mjs
node tool/validate_privacy_disclosures.mjs

node --check tool/validate_retention_deletion_readiness.mjs
node --test test/tool/validate_retention_deletion_readiness.test.mjs
node --test test/tool/verify_restore_readiness_wiring.test.mjs
node tool/validate_retention_deletion_readiness.mjs
node --check tool/validate_production_restore_readiness.mjs
node --test test/tool/validate_production_restore_readiness.test.mjs
node --test test/tool/deploy_release_automatic_rollback.test.mjs
node tool/validate_production_restore_readiness.mjs

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
node --check tool/archive_android_release_candidate.mjs
node --test test/tool/archive_android_release_candidate.test.mjs

node --check tool/validate_b11_release_docs.mjs
node --test test/tool/validate_b11_release_docs.test.mjs
node --test test/tool/ci_candidate_rollover_wiring.test.mjs
if [[ "${SIT_ALLOW_CANDIDATE_ROLLOVER:-0}" == "1" ]]; then
  node tool/validate_b11_release_docs.mjs --allow-candidate-rollover
else
  node tool/validate_b11_release_docs.mjs
fi

node --check tool/validate_google_play_internal_handoff.mjs
node --test test/tool/validate_google_play_internal_handoff.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_google_play_internal_handoff.mjs --ci-metadata-only
else
  node tool/validate_google_play_internal_handoff.mjs
fi
node --test test/tool/upload_exact_crashlytics_mapping_wiring.test.mjs
node --check tool/validate_google_play_app_content_handoff.mjs
node --test test/tool/validate_google_play_app_content_handoff.test.mjs
if [[ "${SIT_ALLOW_CANDIDATE_ROLLOVER:-0}" == "1" ]]; then
  node tool/validate_google_play_app_content_handoff.mjs --allow-candidate-rollover
else
  node tool/validate_google_play_app_content_handoff.mjs
fi

node --check tool/validate_google_play_closed_testing.mjs
node --test test/tool/validate_google_play_closed_testing.test.mjs
node --check tool/prepare_google_play_closed_testing_observation.mjs
node --test test/tool/prepare_google_play_closed_testing_observation.test.mjs
node --test test/tool/google_play_closed_testing_wiring.test.mjs
node tool/validate_google_play_closed_testing.mjs
node --check tool/validate_google_play_closed_testing_feedback.mjs
node --test test/tool/validate_google_play_closed_testing_feedback.test.mjs
if [[ "${SIT_ALLOW_CANDIDATE_ROLLOVER:-0}" == "1" ]]; then
  node tool/validate_google_play_closed_testing_feedback.mjs --allow-candidate-rollover
else
  node tool/validate_google_play_closed_testing_feedback.mjs
fi
node --check tool/validate_google_play_production_access_application.mjs
node --test test/tool/validate_google_play_production_access_application.test.mjs
node tool/validate_google_play_production_access_application.mjs

node --check tool/validate_apple_testflight_handoff.mjs
node --test test/tool/validate_apple_testflight_handoff.test.mjs
node --check tool/diagnose_ios_tooling_readiness.mjs
node --test test/tool/diagnose_ios_tooling_readiness.test.mjs
if [[ "${SIT_ALLOW_CANDIDATE_ROLLOVER:-0}" == "1" ]]; then
  node tool/validate_apple_testflight_handoff.mjs --allow-android-candidate-rollover
else
  node tool/validate_apple_testflight_handoff.mjs
fi

node --check tool/prepare_android_device_test.mjs
node --test test/tool/prepare_android_device_test.test.mjs
node --check tool/diagnose_android_controlled_fcm.mjs
node --test test/tool/diagnose_android_controlled_fcm.test.mjs
node --check tool/restore_android_synthetic_session.mjs
node --check tool/diagnose_android_logout_lifecycle.mjs
node --check tool/diagnose_android_offline_realtime.mjs
node --check tool/run_isolated_android_device_message_diagnostic.mjs
node --test test/tool/run_isolated_android_device_message_diagnostic.test.mjs

node --check tool/diagnose_android_app_links.mjs
node --test test/tool/diagnose_android_app_links.test.mjs
node --check tool/validate_current_head_android_authenticated_safe_links.mjs
node --test test/tool/validate_current_head_android_authenticated_safe_links.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_current_head_android_authenticated_safe_links.mjs --ci-metadata-only
else
  node tool/validate_current_head_android_authenticated_safe_links.mjs
fi
node --check tool/diagnose_current_head_android_main_navigation.mjs
node --test test/tool/diagnose_current_head_android_main_navigation.test.mjs
node --check tool/validate_current_head_android_main_navigation.mjs
node --test test/tool/validate_current_head_android_main_navigation.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_current_head_android_main_navigation.mjs --ci-metadata-only
else
  node tool/validate_current_head_android_main_navigation.mjs
fi
node --check tool/diagnose_current_head_android_legal_routes.mjs
node --test test/tool/diagnose_current_head_android_legal_routes.test.mjs
node --check tool/validate_current_head_android_legal_routes.mjs
node --test test/tool/validate_current_head_android_legal_routes.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_current_head_android_legal_routes.mjs --ci-metadata-only
else
  node tool/validate_current_head_android_legal_routes.mjs
fi
node --check tool/diagnose_current_head_android_large_text_main_navigation.mjs
node --test test/tool/diagnose_current_head_android_large_text_main_navigation.test.mjs
node --check tool/validate_current_head_android_release_archive.mjs
node --test test/tool/validate_current_head_android_release_archive.test.mjs
node --check tool/install_current_head_android_candidate_update.mjs
node --test test/tool/install_current_head_android_candidate_update.test.mjs
node --check tool/diagnose_android_main_navigation_touch_targets.mjs
node --test test/tool/diagnose_android_main_navigation_touch_targets.test.mjs
node --check tool/validate_pf14b_current_head_android_touch_target.mjs
node --test test/tool/validate_pf14b_current_head_android_touch_target.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_pf14b_current_head_android_touch_target.mjs --ci-metadata-only
else
  node tool/validate_pf14b_current_head_android_touch_target.mjs
fi
node --check tool/diagnose_pf16_current_candidate_read_only.mjs
node --test test/tool/diagnose_pf16_current_candidate_read_only.test.mjs
node --check tool/validate_pf16_current_candidate_read_only.mjs
node --test test/tool/validate_pf16_current_candidate_read_only.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_pf16_current_candidate_read_only.mjs --ci-metadata-only
else
  node tool/validate_pf16_current_candidate_read_only.mjs
fi
node --check tool/diagnose_pf17_current_candidate_authenticated_safe_links.mjs
node --test test/tool/diagnose_pf17_current_candidate_authenticated_safe_links.test.mjs
node --check tool/validate_pf17_current_candidate_authenticated_safe_links.mjs
node --test test/tool/validate_pf17_current_candidate_authenticated_safe_links.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_pf17_current_candidate_authenticated_safe_links.mjs --ci-metadata-only
else
  node tool/validate_pf17_current_candidate_authenticated_safe_links.mjs
fi
node --check tool/diagnose_current_candidate_android_talkback_main_navigation.mjs
node --test test/tool/diagnose_current_candidate_android_talkback_main_navigation.test.mjs
node --check tool/validate_pf19_current_candidate_talkback_preflight.mjs
node --test test/tool/validate_pf19_current_candidate_talkback_preflight.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_pf19_current_candidate_talkback_preflight.mjs --ci-metadata-only
else
  node tool/validate_pf19_current_candidate_talkback_preflight.mjs
fi
node --check tool/diagnose_current_candidate_android_device_services_opt_in.mjs
node --test test/tool/diagnose_current_candidate_android_device_services_opt_in.test.mjs
node --check tool/validate_pf20_current_candidate_device_services_opt_in.mjs
node --test test/tool/validate_pf20_current_candidate_device_services_opt_in.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_pf20_current_candidate_device_services_opt_in.mjs --ci-metadata-only
else
  node tool/validate_pf20_current_candidate_device_services_opt_in.mjs
fi

node --check tool/diagnose_current_candidate_android_talkback_settings_main_navigation.mjs
node --test test/tool/diagnose_current_candidate_android_talkback_settings_main_navigation.test.mjs
node --check tool/validate_pf21_current_candidate_talkback_settings_preflight.mjs
node --test test/tool/validate_pf21_current_candidate_talkback_settings_preflight.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_pf21_current_candidate_talkback_settings_preflight.mjs --ci-metadata-only
else
  node tool/validate_pf21_current_candidate_talkback_settings_preflight.mjs
fi
node --check tool/validate_pf18_pre_intervention_readiness_audit.mjs
node --test test/tool/validate_pf18_pre_intervention_readiness_audit.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_pf18_pre_intervention_readiness_audit.mjs --ci-metadata-only
else
  node tool/validate_pf18_pre_intervention_readiness_audit.mjs
fi
node --check tool/validate_pf22_final_non_live_launch_readiness_checkpoint.mjs
node --test test/tool/validate_pf22_final_non_live_launch_readiness_checkpoint.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_pf22_final_non_live_launch_readiness_checkpoint.mjs --ci-metadata-only
else
  node tool/validate_pf22_final_non_live_launch_readiness_checkpoint.mjs
fi
node --check tool/validate_blue_ocean_n0_baseline.mjs
node --test test/tool/validate_blue_ocean_n0_baseline.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_blue_ocean_n0_baseline.mjs --ci-metadata-only
else
  node tool/validate_blue_ocean_n0_baseline.mjs
fi
node --check tool/validate_blue_ocean_n1_listing_flow_audit.mjs
node --test test/tool/validate_blue_ocean_n1_listing_flow_audit.test.mjs
node tool/validate_blue_ocean_n1_listing_flow_audit.mjs
node --check tool/validate_blue_ocean_n2_listing_ai_foundation.mjs
node --test test/tool/validate_blue_ocean_n2_listing_ai_foundation.test.mjs
node tool/validate_blue_ocean_n2_listing_ai_foundation.mjs
node --check tool/validate_blue_ocean_n3_listing_ai_gateway.mjs
node --test test/tool/validate_blue_ocean_n3_listing_ai_gateway.test.mjs
node tool/validate_blue_ocean_n3_listing_ai_gateway.mjs
node --check tool/validate_blue_ocean_n4_image_privacy_pipeline.mjs
node --test test/tool/validate_blue_ocean_n4_image_privacy_pipeline.test.mjs
node tool/validate_blue_ocean_n4_image_privacy_pipeline.mjs
node --check tool/validate_current_head_android_large_text_main_navigation.mjs
node --test test/tool/validate_current_head_android_large_text_main_navigation.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_current_head_android_large_text_main_navigation.mjs --ci-metadata-only
else
  node tool/validate_current_head_android_large_text_main_navigation.mjs
fi
node --test test/tool/g2a_navigation_migration_wiring.test.mjs
node --test test/tool/main_navigation_touch_target_wiring.test.mjs
node --check tool/validate_g2_data_lifecycle.mjs
node --test test/tool/validate_g2_data_lifecycle.test.mjs
node tool/validate_g2_data_lifecycle.mjs
node --check tool/diagnose_android_authenticated_session.mjs
node --test test/tool/diagnose_android_authenticated_session.test.mjs
node --check tool/validate_current_head_android_authenticated_session.mjs
node --test test/tool/validate_current_head_android_authenticated_session.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_current_head_android_authenticated_session.mjs --ci-metadata-only
else
  node tool/validate_current_head_android_authenticated_session.mjs
fi
node --check tool/validate_current_head_android_offline_session.mjs
node --test test/tool/validate_current_head_android_offline_session.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_current_head_android_offline_session.mjs --ci-metadata-only
else
  node tool/validate_current_head_android_offline_session.mjs
fi
node --check tool/diagnose_android_authenticated_links.mjs
node --test test/tool/diagnose_android_authenticated_links.test.mjs
node --check tool/run_isolated_android_authenticated_links_diagnostic.mjs
node --test test/tool/run_isolated_android_authenticated_links_diagnostic.test.mjs
node --check tool/provision_staging_test_accounts.mjs
node --test test/tool/provision_staging_test_accounts.test.mjs
node --check tool/prepare_store_screenshot_fixture.mjs
node --test test/tool/prepare_store_screenshot_fixture.test.mjs
node --check tool/clean_staging_store_feed.mjs
node --test test/tool/clean_staging_store_feed.test.mjs
node --check tool/validate_google_play_screenshot_readiness.mjs
node --test test/tool/validate_google_play_screenshot_readiness.test.mjs
node --check tool/validate_google_play_screenshot_candidate.mjs
node --test test/tool/validate_google_play_screenshot_candidate.test.mjs
node --check tool/capture_google_play_android_screenshots.mjs
node --test test/tool/capture_google_play_android_screenshots.test.mjs
node --check tool/validate_google_cloud_android_key_restriction.mjs
node --test test/tool/validate_google_cloud_android_key_restriction.test.mjs
node tool/validate_google_cloud_android_key_restriction.mjs
node --check tool/validate_public_store_route_production_preflight.mjs
node --test test/tool/validate_public_store_route_production_preflight.test.mjs
node tool/validate_public_store_route_production_preflight.mjs
node --check tool/validate_public_store_backend_candidate_preflight.mjs
node --test test/tool/validate_public_store_backend_candidate_preflight.test.mjs
node tool/validate_public_store_backend_candidate_preflight.mjs
node --check tool/validate_google_play_app_content_progress.mjs
node --test test/tool/validate_google_play_app_content_progress.test.mjs
node --check tool/validate_google_play_data_safety_answer_matrix.mjs
node --test test/tool/validate_google_play_data_safety_answer_matrix.test.mjs
if [[ "${SIT_ALLOW_CANDIDATE_ROLLOVER:-0}" == "1" ]]; then
  node tool/validate_google_play_data_safety_answer_matrix.mjs --allow-candidate-rollover
else
  node tool/validate_google_play_data_safety_answer_matrix.mjs
fi
node --check tool/validate_google_play_service_provider_sharing_classification.mjs
node --test test/tool/validate_google_play_service_provider_sharing_classification.test.mjs
if [[ "${SIT_ALLOW_CANDIDATE_ROLLOVER:-0}" == "1" ]]; then
  node tool/validate_google_play_service_provider_sharing_classification.mjs --allow-candidate-rollover
else
  node tool/validate_google_play_service_provider_sharing_classification.mjs
fi
node --check tool/run_staging_synthetic_booking.mjs
node --test test/tool/run_staging_synthetic_booking.test.mjs
node --check tool/run_isolated_android_role_booking_diagnostic.mjs
node --test test/tool/run_isolated_android_role_booking_diagnostic.test.mjs
node --check tool/diagnose_android_synthetic_role_booking.mjs
node --test test/tool/diagnose_android_synthetic_role_booking.test.mjs

node --check tool/validate_firebase_release_config.mjs
node --test test/tool/validate_firebase_release_config.test.mjs
firebase_validation_platform="${SIT_FIREBASE_VALIDATION_PLATFORM:-all}"
[[ "$firebase_validation_platform" =~ ^(android|ios|all)$ ]] || {
  echo "ERROR: SIT_FIREBASE_VALIDATION_PLATFORM must be android, ios, or all." >&2
  exit 1
}
firebase_config_path="$ROOT/android/app/google-services.json"
firebase_ios_config_path="$ROOT/ios/Runner/GoogleService-Info.plist"
firebase_required_names=(
  SIT_FIREBASE_PROJECT_ID
  SIT_FIREBASE_MESSAGING_SENDER_ID
  SIT_FIREBASE_STORAGE_BUCKET
  SIT_FIREBASE_ANDROID_APP_ID
  SIT_FIREBASE_ANDROID_API_KEY
)
firebase_env_missing=false
for firebase_name in "${firebase_required_names[@]}"; do
  if [[ -z "${!firebase_name:-}" ]]; then
    firebase_env_missing=true
    break
  fi
done
if [[ "$firebase_validation_platform" =~ ^(android|all)$ &&
      -f "$firebase_config_path" && "$firebase_env_missing" == "true" ]]; then
  firebase_env_lines="$(node --input-type=module - "$firebase_config_path" <<'NODE'
import { readFileSync } from 'node:fs';
import { deriveAndroidFirebaseReleaseEnvironment } from './tool/validate_firebase_release_config.mjs';

const config = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const values = deriveAndroidFirebaseReleaseEnvironment(config);
for (const [name, value] of Object.entries(values)) {
  process.stdout.write(`${name}=${value}\n`);
}
NODE
)"
  while IFS='=' read -r firebase_name firebase_value; do
    case "$firebase_name" in
      SIT_FIREBASE_PROJECT_ID|SIT_FIREBASE_MESSAGING_SENDER_ID|SIT_FIREBASE_STORAGE_BUCKET|SIT_FIREBASE_ANDROID_APP_ID|SIT_FIREBASE_ANDROID_API_KEY)
        if [[ -z "${!firebase_name:-}" ]]; then
          printf -v "$firebase_name" '%s' "$firebase_value"
          export "$firebase_name"
        fi
        ;;
      *)
        echo "ERROR: Unexpected Firebase environment field." >&2
        exit 1
        ;;
    esac
  done <<< "$firebase_env_lines"
  unset firebase_env_lines firebase_value
fi
if [[ "$firebase_validation_platform" =~ ^(ios|all)$ &&
      -f "$firebase_ios_config_path" ]]; then
  firebase_env_lines="$(node --input-type=module - "$firebase_ios_config_path" <<'NODE'
import { readFileSync } from 'node:fs';
import {
  deriveIosFirebaseReleaseEnvironment,
  parseGoogleServiceInfoPlist,
} from './tool/validate_firebase_release_config.mjs';

const config = parseGoogleServiceInfoPlist(readFileSync(process.argv[2], 'utf8'));
const values = deriveIosFirebaseReleaseEnvironment(config);
for (const [name, value] of Object.entries(values)) {
  process.stdout.write(`${name}=${value}\n`);
}
NODE
)"
  while IFS='=' read -r firebase_name firebase_value; do
    case "$firebase_name" in
      SIT_FIREBASE_PROJECT_ID|SIT_FIREBASE_MESSAGING_SENDER_ID|SIT_FIREBASE_STORAGE_BUCKET|SIT_FIREBASE_IOS_APP_ID|SIT_FIREBASE_IOS_API_KEY)
        if [[ -z "${!firebase_name:-}" ]]; then
          printf -v "$firebase_name" '%s' "$firebase_value"
          export "$firebase_name"
        fi
        ;;
      *)
        echo "ERROR: Unexpected Apple Firebase environment field." >&2
        exit 1
        ;;
    esac
  done <<< "$firebase_env_lines"
  unset firebase_env_lines firebase_value
fi
node tool/validate_firebase_release_config.mjs --platform "$firebase_validation_platform"

node --check tool/validate_google_only_next_candidate.mjs
node --test test/tool/validate_google_only_next_candidate.test.mjs
node tool/validate_google_only_next_candidate.mjs

node --check tool/validate_phone_verification_readiness.mjs
node --test test/tool/validate_phone_verification_readiness.test.mjs
if [[ "${SIT_ALLOW_CANDIDATE_ROLLOVER:-0}" == "1" ]]; then
  node tool/validate_phone_verification_readiness.mjs --allow-candidate-rollover
else
  node tool/validate_phone_verification_readiness.mjs
fi

node --check tool/validate_android_signing_config.mjs
node --test test/tool/validate_android_signing_config.test.mjs

node --check tool/verify_brand_assets.mjs
node tool/verify_brand_assets.mjs
node --test test/tool/messages_screen_dead_ui_cleanup_wiring.test.mjs
node --test test/tool/request_detail_dead_message_card_cleanup_wiring.test.mjs
node --test test/tool/explore_listing_card_dead_verification_getter_cleanup_wiring.test.mjs
node --test test/tool/explore_dead_code_ratchet_wiring.test.mjs
node --test test/tool/data_service_dead_demo_code_ratchet_wiring.test.mjs
node --test test/tool/booking_detail_dead_collapsible_hint_state_cleanup_wiring.test.mjs
node --test test/tool/ongoing_owner_detail_dead_manual_handover_state_cleanup_wiring.test.mjs
node --test test/tool/ongoing_owner_detail_dead_start_handover_gate_cleanup_wiring.test.mjs
node --test test/tool/ongoing_owner_detail_dead_code_ratchet_wiring.test.mjs
node --test test/tool/booking_detail_dead_can_message_getter_cleanup_wiring.test.mjs
node --test test/tool/booking_detail_dead_presentation_helpers_ratchet_wiring.test.mjs
node --test test/tool/booking_detail_dead_manual_pickup_ratchet_wiring.test.mjs
node --test test/tool/booking_detail_fixed_default_parameter_ratchet_wiring.test.mjs
node --test test/tool/message_thread_dead_helper_ratchet_wiring.test.mjs
node --test test/tool/message_thread_legacy_ui_ratchet_wiring.test.mjs
node --test test/tool/message_thread_analyzer_zero_ratchet_wiring.test.mjs
node --test test/tool/return_handover_stepper_dead_datetime_formatter_cleanup_wiring.test.mjs
node --test test/tool/booking_detail_dead_return_renter_code_cleanup_wiring.test.mjs
node --test test/tool/firebase_device_services_opt_in_wiring.test.mjs
node --test test/tool/v51_withdrawal_and_cancellation_wiring.test.mjs
node --test test/tool/v52_actual_loss_wiring.test.mjs
node --test backend/test/v52_handover_return_workflow.test.js
node --test test/tool/v51_condition_evidence_wiring.test.mjs
node --test test/tool/v51_return_lifecycle_wiring.test.mjs
node --test test/tool/v51_selected_range_price_truth_wiring.test.mjs
node --test test/tool/v51_booking_detail_server_price_snapshot_wiring.test.mjs
node --test test/tool/v51_checkout_server_quote_validation_wiring.test.mjs
node --test test/tool/v51_local_quote_snapshot_persistence_wiring.test.mjs
node --test test/tool/v51_owner_acceptance_server_price_wiring.test.mjs
node --test test/tool/v51_checkout_backend_error_wiring.test.mjs
node --check tool/validate_v51_legal_assets.mjs
node --test test/tool/validate_v51_legal_assets.test.mjs
node tool/validate_v51_legal_assets.mjs
node --check tool/validate_v52_legal_assets.mjs
node --test test/tool/validate_v52_legal_assets.test.mjs
node tool/validate_v52_legal_assets.mjs
node --check tool/validate_g3l_legal_draft.mjs
node --test test/tool/validate_g3l_legal_draft.test.mjs
node tool/validate_g3l_legal_draft.mjs
node --check tool/validate_p0b_legal_review_intake.mjs
node --test test/tool/validate_p0b_legal_review_intake.test.mjs
node tool/validate_p0b_legal_review_intake.mjs
node --check backend/src/operational_readiness_gate.js
node --test backend/test/operational_readiness_gate.test.js
node --check tool/validate_p0b_ops_readiness.mjs
node --test test/tool/validate_p0b_ops_readiness.test.mjs
node tool/validate_p0b_ops_readiness.mjs
node --check tool/validate_p0b_signed_device_evidence.mjs
node --test test/tool/validate_p0b_signed_device_evidence.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  # actions/checkout is intentionally shallow. CI validates the exact recorded
  # remote run metadata; local validation additionally requires the candidate
  # commit object and can re-hash the private archive on the Mac mini.
  node tool/validate_p0b_signed_device_evidence.mjs --ci-metadata-only
else
  node tool/validate_p0b_signed_device_evidence.mjs
fi
node --check tool/validate_current_head_android_candidate.mjs
node --test test/tool/validate_current_head_android_candidate.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_current_head_android_candidate.mjs --ci-metadata-only
else
  node tool/validate_current_head_android_candidate.mjs
fi
node --check tool/diagnose_current_head_android_restart.mjs
node --test test/tool/diagnose_current_head_android_restart.test.mjs
node --check tool/validate_current_head_android_restart.mjs
node --test test/tool/validate_current_head_android_restart.test.mjs
if [[ "${CI:-false}" == "true" ]]; then
  node tool/validate_current_head_android_restart.mjs --ci-metadata-only
else
  node tool/validate_current_head_android_restart.mjs
fi
node --check tool/validate_p0b_psp_sandbox_e2e.mjs
node --test test/tool/validate_p0b_psp_sandbox_e2e.test.mjs
node tool/validate_p0b_psp_sandbox_e2e.mjs
node --check tool/validate_p0b_invited_synthetic_pilot_readiness.mjs
node --test test/tool/validate_p0b_invited_synthetic_pilot_readiness.test.mjs
node tool/validate_p0b_invited_synthetic_pilot_readiness.mjs
node --test test/tool/g5b_listing_sets_wiring.test.mjs
node --test test/tool/analyzer_baseline_wiring.test.mjs
node --test test/tool/validate_flutter_analyzer_debt.test.mjs
node --test test/tool/wishlist_async_context_wiring.test.mjs
node --test test/tool/item_card_async_context_wiring.test.mjs
node --test test/tool/listing_options_async_context_wiring.test.mjs
node --test test/tool/profile_info_async_lifecycle_wiring.test.mjs
node --test test/tool/create_listing_photo_async_lifecycle_wiring.test.mjs
node --test test/tool/public_profile_async_context_wiring.test.mjs
node --test test/tool/request_detail_async_context_wiring.test.mjs
node --test test/tool/bookings_async_context_wiring.test.mjs
node --test test/tool/owner_requests_async_context_wiring.test.mjs
node --test test/tool/search_results_async_context_wiring.test.mjs
node --test test/tool/explore_async_context_wiring.test.mjs
node --test test/tool/message_thread_async_context_wiring.test.mjs
node --test test/tool/ongoing_owner_time_overflow_async_context_wiring.test.mjs
node --test test/tool/ongoing_owner_request_decision_async_context_wiring.test.mjs
node --test test/tool/ongoing_owner_handover_maps_async_context_wiring.test.mjs
node --test test/tool/booking_detail_primary_async_context_wiring.test.mjs
node --test test/tool/booking_detail_handover_return_async_context_wiring.test.mjs
node --test test/tool/item_details_reservation_async_context_wiring.test.mjs
node --test test/tool/item_details_secondary_async_context_wiring.test.mjs
node --test test/tool/item_details_radio_group_migration_wiring.test.mjs
node --test test/tool/item_details_dead_code_ratchet_wiring.test.mjs
node --test test/tool/android_debug_single_attempt_wiring.test.mjs
node --test test/tool/flutter_parallel_stress_wiring.test.mjs
node --test test/tool/reset_token_clock_boundary_wiring.test.mjs
node --test test/tool/postgres_runner_ci_wiring.test.mjs
node --test test/tool/validate_external_gate_setup.test.mjs
node tool/validate_external_gate_setup.mjs
node --check tool/validate_pilot_launch_tiers.mjs
node --test test/tool/validate_pilot_launch_tiers.test.mjs
node tool/validate_pilot_launch_tiers.mjs
node --check tool/validate_external_gate_execution_board.mjs
node --test test/tool/validate_external_gate_execution_board.test.mjs
node tool/validate_external_gate_execution_board.mjs
node --check tool/validate_walid_external_gate_action_pack.mjs
node --test test/tool/validate_walid_external_gate_action_pack.test.mjs
node tool/validate_walid_external_gate_action_pack.mjs
node --test test/tool/release_host_capacity_guard_wiring.test.mjs

analyze_log="$(mktemp)"
trap 'rm -f "$analyze_log"' EXIT

set +e
flutter analyze 2>&1 | tee "$analyze_log"
analyze_status=${PIPESTATUS[0]}
set -e

if grep -Eq '(^|[[:space:]])No issues found!' "$analyze_log"; then
  issue_count=0
else
  issue_count="$({
    grep -Eo '(^|[^0-9])[0-9]+ issue(s)? found\.' "$analyze_log" || true
  } | tail -n1 | grep -Eo '[0-9]+' || true)"
fi

if [[ -z "$issue_count" ]]; then
  echo "ERROR: Could not parse analyzer issue count from flutter analyze output." >&2
  exit 1
fi

node tool/validate_flutter_analyzer_debt.mjs --log "$analyze_log"

for analyzer_code in "${FORBIDDEN_ANALYZER_CODES[@]}"; do
  if grep -Eq "(^|[[:space:]•])${analyzer_code}$" "$analyze_log"; then
    echo "ERROR: Analyzer correctness regression detected: ${analyzer_code}." >&2
    exit 1
  fi
done

if (( analyze_status == 0 )) && (( issue_count > 0 )); then
  echo "ERROR: flutter analyze exited 0 but reported ${issue_count} issues; refusing ambiguous success." >&2
  exit 1
fi

if (( analyze_status != 0 )) && (( issue_count == 0 )); then
  echo "ERROR: flutter analyze exited ${analyze_status} despite reporting zero issues; refusing ambiguous failure." >&2
  exit 1
fi

flutter_test_concurrency="${SIT_FLUTTER_TEST_CONCURRENCY:-}"
if [[ -n "$flutter_test_concurrency" ]]; then
  if [[ ! "$flutter_test_concurrency" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: SIT_FLUTTER_TEST_CONCURRENCY must be a positive integer." >&2
    exit 1
  fi
  flutter test --reporter expanded --concurrency "$flutter_test_concurrency"
else
  # Standard Flutter parallelism is the release-readiness path. A caller may
  # still select a positive value for diagnostics, but serial execution is not
  # the repository default and cannot establish release readiness.
  flutter test --reporter expanded
fi

# Compile and execute the exact next social-auth profile without producing a
# release artifact: Google is opt-in, while Apple and Facebook remain closed.
flutter test --reporter expanded \
  --dart-define=SIT_TEST_GOOGLE_ONLY_PROFILE=true \
  --dart-define=SIT_SOCIAL_GOOGLE_ENABLED=true \
  --dart-define=SIT_SOCIAL_APPLE_ENABLED=false \
  --dart-define=SIT_SOCIAL_FACEBOOK_ENABLED=false \
  test/social_auth_google_only_profile_test.dart

if ! web_build_output="$(flutter build web --debug 2>&1)"; then
  printf '%s\n' "$web_build_output"
  echo "ERROR: Flutter Web debug build failed." >&2
  exit 1
fi
printf '%s\n' "$web_build_output"
if printf '%s\n' "$web_build_output" \
  | grep -Eq 'Wasm dry run findings|avoid_double_and_int_checks'; then
  echo "ERROR: Flutter Web build reported unresolved WebAssembly findings." >&2
  exit 1
fi
bash scripts/p0a_web_smoke.sh

if ! android_build_output="$(
  ./android/gradlew -p android :app:assembleDebug --no-daemon --warning-mode all 2>&1
)"; then
  printf '%s\n' "$android_build_output"
  echo "ERROR: Android debug build failed." >&2
  exit 1
fi
printf '%s\n' "$android_build_output"
if grep -Fq "Build file '$PWD/android/" <<<"$android_build_output" \
  || grep -Fq "Settings file '$PWD/android/" <<<"$android_build_output"; then
  echo "ERROR: Android build reported a warning from an SIT-owned Gradle script." >&2
  exit 1
fi

android_sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$android_sdk_root" && -f android/local.properties ]]; then
  android_sdk_root="$(sed -n 's/^sdk\.dir=//p' android/local.properties | tail -n1)"
fi
if [[ -z "$android_sdk_root" ]]; then
  android_sdk_root="$HOME/Library/Android/sdk"
fi
android_build_tools_root="$android_sdk_root/build-tools"
android_build_tools="$(find "$android_build_tools_root" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n1)"
android_aapt="$android_build_tools/aapt"
android_debug_apk="build/app/outputs/flutter-apk/app-debug.apk"
[[ -x "$android_aapt" ]] || {
  echo "ERROR: aapt is unavailable for the Android platform-reach check." >&2
  exit 1
}
[[ -f "$android_debug_apk" ]] || {
  echo "ERROR: Android debug APK is unavailable for the platform-reach check." >&2
  exit 1
}
android_debug_badging="$("$android_aapt" dump badging "$android_debug_apk")"
if ! grep -Fq "sdkVersion:'24'" <<<"$android_debug_badging"; then
  echo "ERROR: Android debug binary no longer has the reviewed minSdk 24 floor." >&2
  exit 1
fi
echo "Android debug binary platform reach: PASS (minSdk 24)."

release_host_capacity_end
