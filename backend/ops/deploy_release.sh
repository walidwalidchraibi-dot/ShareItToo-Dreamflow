#!/usr/bin/env bash
set -euo pipefail

task_backend_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_environment="${1:-}"
task_commit="${2:-}"

if [[ "$task_environment" != staging && "$task_environment" != production ]]; then
  echo "Usage: $0 <staging|production> <40-character-commit>" >&2
  exit 1
fi
if [[ ! "$task_commit" =~ ^[0-9a-f]{40}$ ]]; then
  echo "A full lowercase 40-character Git commit is required." >&2
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
  task_env_file="$task_backend_root/.env"
  task_health_url="${HEALTH_URL:-https://shareittoo.com/api}"
  task_project_name=backend
  if [[ "${CONFIRM_PRODUCTION_DEPLOY:-}" != "$task_commit" ]]; then
    echo "Set CONFIRM_PRODUCTION_DEPLOY to the exact commit before a production rollout." >&2
    exit 1
  fi
  "$task_backend_root/ops/backup.sh"
else
  task_compose="$task_backend_root/compose.staging.yml"
  task_env_file="$task_backend_root/.env.staging"
  task_health_url="${HEALTH_URL:-http://127.0.0.1:${STAGING_API_PORT:-18080}}"
  task_project_name=sit-staging
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
  --env-file "$task_env_file" -f "$task_compose" \
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
printf '{"environment":"%s","commit":"%s","previousCommit":"%s","version":"%s","buildTime":"%s","deployedAt":"%s"}\n' \
  "$task_environment" "$task_commit" "$task_previous_commit" "$task_version" \
  "$task_build_time" "$task_timestamp" > "$task_report"
chmod 600 "$task_report"

printf 'Deployment verified: %s %s\nEvidence: %s\n' \
  "$task_environment" "$task_commit" "$task_report"
