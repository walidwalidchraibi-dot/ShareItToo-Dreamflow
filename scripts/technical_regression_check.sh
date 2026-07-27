#!/usr/bin/env bash
set -euo pipefail

# Transitional analyzer baseline for the existing legacy issue backlog.
# Keep this in sync with the accepted repository baseline until the backlog is reduced.
ANALYZER_BASELINE=729
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

flutter --version

dart --version

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
