# S4AC Gradle single-attempt cache contract

Status: locally verified, exact GitHub closure pending.

## Canonical checks

```sh
node --test \
  test/tool/android_debug_single_attempt_wiring.test.mjs \
  test/tool/ci_candidate_rollover_wiring.test.mjs
./android/gradlew -p android :app:assembleDebug --no-daemon
CI=true SIT_ALLOW_CANDIDATE_ROLLOVER=1 \
  bash scripts/technical_regression_check.sh
```

The first command reports ten passes. Both Android commands execute one direct
Gradle build path without the Flutter CLI APK retry. The final command is local
CI-metadata-only evidence because the historical candidate AAB is absent; it is
not actual CI, Store or device evidence.

## GitHub acceptance

Do not rerun failed run `32592388940` as a way to make it green. A new exact
remediation commit must pass on its own. Record whether its Basic Cache entry is
cold/written, then retain a later run that restores the PR-scoped entry. Neither
run may depend on a sleep, loop, automatic retry, alternate Maven mirror,
manual cache injection or paid cache provider.

This package does not close `TD-RR-011`; it implements its deterministic local
path. P0B remains `HOLD` / `NO-GO`.
