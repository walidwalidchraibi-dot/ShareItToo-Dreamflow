#!/usr/bin/env bash
set -euo pipefail

task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_web_root="$task_root/build/web"
task_port="${P0A_WEB_SMOKE_PORT:-18765}"

[[ "$task_port" =~ ^[0-9]{2,5}$ ]] || {
  echo "ERROR: P0A_WEB_SMOKE_PORT must be a numeric loopback port." >&2
  exit 1
}

for task_file in index.html main.dart.js manifest.json; do
  [[ -s "$task_web_root/$task_file" ]] || {
    echo "ERROR: Missing current-source web artifact: $task_file" >&2
    exit 1
  }
done

python3 -m http.server "$task_port" --bind 127.0.0.1 --directory "$task_web_root" \
  >/dev/null 2>&1 &
task_server_pid=$!
trap 'kill "$task_server_pid" 2>/dev/null || true; wait "$task_server_pid" 2>/dev/null || true' EXIT

task_ready=false
for _ in {1..20}; do
  if curl --fail --silent "http://127.0.0.1:$task_port/index.html" \
      >/dev/null; then
    task_ready=true
    break
  fi
  sleep 0.1
done

[[ "$task_ready" == true ]] || {
  echo "ERROR: Current-source web build did not answer on loopback." >&2
  exit 1
}

curl --fail --silent --show-error "http://127.0.0.1:$task_port/manifest.json" \
  | grep -F 'ShareItToo' >/dev/null

echo "P0A web smoke: PASS (loopback only, current-source debug build)."
