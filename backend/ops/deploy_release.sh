#!/usr/bin/env bash
set -euo pipefail

task_backend_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_environment="${1:-}"
task_commit="${2:-}"
task_enable_staging_fcm="${ENABLE_STAGING_FCM:-0}"
task_node_binary="${NODE_BINARY:-node}"
task_deployment_started=false
task_previous_image_id=''
task_previous_commit=''
task_previous_version='unknown'
task_previous_build_time='unknown'
task_rollback_override=''
task_release_dir="${RELEASE_LOG_DIR:-/docker/shareittoo/releases}"
task_staging_pilot_id="${SIT_STAGING_PILOT_ID:-}"
task_pull_release_image="${PULL_RELEASE_IMAGE:-0}"

cleanup() {
  if [[ -n "$task_rollback_override" ]]; then
    rm -f -- "$task_rollback_override"
  fi
}

rollback_failed_deployment() {
  task_failed_status=$?
  trap - ERR
  set +e

  if [[ "$task_deployment_started" == true && -n "$task_previous_image_id" ]]; then
    task_rollback_override="$(mktemp)"
    printf 'services:\n  api:\n    image: "%s"\n' \
      "$task_previous_image_id" > "$task_rollback_override"

    task_rollback_commit="${task_previous_commit:-unknown}"
    APP_VERSION="$task_previous_version" \
    APP_COMMIT="$task_rollback_commit" \
    APP_BUILD_TIME="$task_previous_build_time" \
    docker compose --project-name "$task_project_name" \
      --env-file "$task_env_file" "${task_compose_args[@]}" \
      -f "$task_rollback_override" \
      up -d --no-build --wait --wait-timeout 180
    task_rollback_compose_status=$?

    task_restored_image_id="$(docker inspect --format '{{.Image}}' \
      "$task_api_container" 2>/dev/null)"
    task_restored_health="$(docker inspect \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
      "$task_api_container" 2>/dev/null)"
    curl --fail --silent --show-error --max-time 20 \
      "$task_health_url/health" >/dev/null
    task_rollback_health_status=$?

    if [[ "$task_rollback_compose_status" == 0 &&
          "$task_rollback_health_status" == 0 &&
          "$task_restored_health" == healthy &&
          "$task_restored_image_id" == "$task_previous_image_id" ]]; then
      install -d -m 700 "$task_release_dir"
      task_rollback_timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
      task_rollback_report="$task_release_dir/${task_environment}-rollback-${task_rollback_timestamp}-${task_commit:0:12}.json"
      printf '{"environment":"%s","failedCommit":"%s","restoredCommit":"%s","restoredImageId":"%s","rolledBackAt":"%s","status":"passed"}\n' \
        "$task_environment" "$task_commit" "$task_rollback_commit" \
        "$task_previous_image_id" "$task_rollback_timestamp" > "$task_rollback_report"
      chmod 600 "$task_rollback_report"
      printf 'Deployment failed; previous image restored and verified.\nEvidence: %s\n' \
        "$task_rollback_report" >&2
    else
      printf 'CRITICAL: deployment failed and automatic rollback could not be verified.\n' >&2
    fi
  elif [[ "$task_deployment_started" == true ]]; then
    printf 'CRITICAL: deployment failed and no previous API image was available for rollback.\n' >&2
  fi

  cleanup
  exit "$task_failed_status"
}

trap cleanup EXIT
trap rollback_failed_deployment ERR

if [[ "$task_environment" != staging && "$task_environment" != production ]]; then
  echo "Usage: $0 <staging|production> <40-character-commit>" >&2
  exit 1
fi
if [[ ! "$task_commit" =~ ^[0-9a-f]{40}$ ]]; then
  echo "A full lowercase 40-character Git commit is required." >&2
  exit 1
fi
if [[ "$task_enable_staging_fcm" != 0 && "$task_enable_staging_fcm" != 1 ]]; then
  echo "ENABLE_STAGING_FCM must be 0 or 1." >&2
  exit 1
fi
if [[ "$task_environment" == production && "$task_enable_staging_fcm" == 1 ]]; then
  echo "The staging FCM override is forbidden for production deployments." >&2
  exit 1
fi
if [[ "$task_pull_release_image" != 0 && "$task_pull_release_image" != 1 ]]; then
  echo "PULL_RELEASE_IMAGE must be 0 or 1." >&2
  exit 1
fi
if [[ "$task_environment" == production && -n "$task_staging_pilot_id" ]]; then
  echo "SIT_STAGING_PILOT_ID is forbidden for production deployments." >&2
  exit 1
fi
if [[ -n "$task_staging_pilot_id" && "$task_staging_pilot_id" != heilbronn_wave0 ]]; then
  echo "SIT_STAGING_PILOT_ID must be empty or heilbronn_wave0." >&2
  exit 1
fi

task_image="${IMAGE_REPOSITORY:-shareittoo-api}:$task_commit"
if [[ "$task_pull_release_image" == 1 ]]; then
  if [[ ! "${IMAGE_REPOSITORY:-}" =~ ^ghcr\.io/[a-z0-9._-]+/[a-z0-9._-]+$ ]]; then
    echo "PULL_RELEASE_IMAGE requires an explicit GHCR IMAGE_REPOSITORY." >&2
    exit 1
  fi
  docker pull "$task_image"
fi
task_image_commit="$(docker image inspect "$task_image" --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}')"
task_version="$(docker image inspect "$task_image" --format '{{ index .Config.Labels "org.opencontainers.image.version" }}')"
task_build_time="$(docker image inspect "$task_image" --format '{{ index .Config.Labels "org.opencontainers.image.created" }}')"
if [[ "$task_image_commit" != "$task_commit" ]]; then
  echo "Image revision label does not match $task_commit." >&2
  exit 1
fi

if [[ "$task_environment" == production ]]; then
  task_compose="$task_backend_root/compose.prod.yml"
  task_compose_args=(-f "$task_compose")
  task_env_file="$task_backend_root/.env"
  task_health_url="${HEALTH_URL:-https://shareittoo.com/api}"
  task_project_name=backend
  task_api_container=shareittoo-api
  task_fcm_enabled=false
  task_database_container=shareittoo-postgres
  task_database_user=shareittoo
  task_database_name=shareittoo
  if [[ "${CONFIRM_PRODUCTION_DEPLOY:-}" != "$task_commit" ]]; then
    echo "Set CONFIRM_PRODUCTION_DEPLOY to the exact commit before a production rollout." >&2
    exit 1
  fi
  "$task_backend_root/ops/backup.sh"
else
  task_compose="$task_backend_root/compose.staging.yml"
  task_compose_args=(-f "$task_compose")
  task_env_file="$task_backend_root/.env.staging"
  task_health_url="${HEALTH_URL:-http://127.0.0.1:${STAGING_API_PORT:-18080}}"
  task_project_name=sit-staging
  task_api_container=shareittoo-staging-api
  task_fcm_enabled=false
  task_database_container=shareittoo-staging-postgres
  task_database_user=shareittoo_staging
  task_database_name=shareittoo_staging
  if [[ "$task_staging_pilot_id" == heilbronn_wave0 ]]; then
    task_compose_args+=(-f "$task_backend_root/compose.staging.pilot.yml")
  fi
  if [[ "$task_enable_staging_fcm" == 1 ]]; then
    FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-}" \
    FIREBASE_SERVICE_ACCOUNT_HOST_FILE="${FIREBASE_SERVICE_ACCOUNT_HOST_FILE:-}" \
      "$task_node_binary" "$task_backend_root/ops/validate_fcm_staging_secret.mjs"
    task_compose_args+=(-f "$task_backend_root/compose.staging.fcm.yml")
    task_fcm_enabled=true
  fi
fi

if [[ ! -f "$task_env_file" ]]; then
  echo "Missing environment file: $task_env_file" >&2
  exit 1
fi

DATABASE_CONTAINER="$task_database_container" \
DATABASE_USER="$task_database_user" \
DATABASE_NAME="$task_database_name" \
  "$task_backend_root/ops/check_foreign_key_integrity.sh"

task_previous_commit="$(curl --fail --silent --show-error --max-time 15 "$task_health_url/version" 2>/dev/null | sed -n 's/.*"commit":"\([0-9a-f]*\)".*/\1/p' || true)"
task_previous_image_id="$(docker inspect --format '{{.Image}}' "$task_api_container" 2>/dev/null || true)"
if [[ -n "$task_previous_image_id" ]]; then
  task_previous_version="$(docker image inspect "$task_previous_image_id" \
    --format '{{ index .Config.Labels "org.opencontainers.image.version" }}' 2>/dev/null || true)"
  task_previous_build_time="$(docker image inspect "$task_previous_image_id" \
    --format '{{ index .Config.Labels "org.opencontainers.image.created" }}' 2>/dev/null || true)"
  task_previous_version="${task_previous_version:-unknown}"
  task_previous_build_time="${task_previous_build_time:-unknown}"
fi

task_deployment_started=true
APP_VERSION="$task_version" \
APP_COMMIT="$task_commit" \
APP_BUILD_TIME="$task_build_time" \
docker compose --project-name "$task_project_name" \
  --env-file "$task_env_file" "${task_compose_args[@]}" \
  up -d --no-build --wait --wait-timeout 180

task_version_payload="$(curl --fail --silent --show-error --max-time 20 "$task_health_url/version")"
if ! grep -q "\"commit\":\"$task_commit\"" <<<"$task_version_payload"; then
  echo "Deployment health endpoint does not expose the requested commit." >&2
  exit 1
fi
curl --fail --silent --show-error --max-time 20 "$task_health_url/health/ready" >/dev/null

install -d -m 700 "$task_release_dir"
task_timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
task_report="$task_release_dir/${task_environment}-${task_timestamp}-${task_commit:0:12}.json"
printf '{"environment":"%s","commit":"%s","previousCommit":"%s","version":"%s","buildTime":"%s","deployedAt":"%s","stagingFcm":%s,"stagingPilotId":"%s"}\n' \
  "$task_environment" "$task_commit" "$task_previous_commit" "$task_version" \
  "$task_build_time" "$task_timestamp" "$task_fcm_enabled" \
  "$task_staging_pilot_id" > "$task_report"
chmod 600 "$task_report"
task_deployment_started=false

printf 'Deployment verified: %s %s\nEvidence: %s\n' \
  "$task_environment" "$task_commit" "$task_report"
