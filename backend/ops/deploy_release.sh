#!/usr/bin/env bash
set -euo pipefail

task_backend_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_environment="${1:-}"
task_commit="${2:-}"
task_enable_staging_fcm="${ENABLE_STAGING_FCM:-0}"
task_node_binary="${NODE_BINARY:-node}"

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

task_image="${IMAGE_REPOSITORY:-shareittoo-api}:$task_commit"
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
  task_fcm_enabled=false
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
  task_fcm_enabled=false
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

task_previous_commit="$(curl --fail --silent --show-error --max-time 15 "$task_health_url/version" 2>/dev/null | sed -n 's/.*"commit":"\([0-9a-f]*\)".*/\1/p' || true)"

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

task_release_dir="${RELEASE_LOG_DIR:-/docker/shareittoo/releases}"
install -d -m 700 "$task_release_dir"
task_timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
task_report="$task_release_dir/${task_environment}-${task_timestamp}-${task_commit:0:12}.json"
printf '{"environment":"%s","commit":"%s","previousCommit":"%s","version":"%s","buildTime":"%s","deployedAt":"%s","stagingFcm":%s}\n' \
  "$task_environment" "$task_commit" "$task_previous_commit" "$task_version" \
  "$task_build_time" "$task_timestamp" "$task_fcm_enabled" > "$task_report"
chmod 600 "$task_report"

printf 'Deployment verified: %s %s\nEvidence: %s\n' \
  "$task_environment" "$task_commit" "$task_report"
