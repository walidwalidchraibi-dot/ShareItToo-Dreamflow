# WP05 — support-corrected Pixel candidate 2026090404

Status: PREPARED / EXACT COLD AND SIGNED LIFECYCLE PENDING.
No new artifact, installation, provider traffic or external service change.

## Decision and preparation provenance

Canonical worktree `/Users/walidchraibi/Worktrees/SIT-master-workflow-20260808`,
branch `codex/master-workflow-20260808`, clean preparation base
`4ed587fe29af6338ede7847bdfdf9d4633c0e95a`. Cached tracking refs21ahead/0behind
are NOT a fresh GitHub check. Owner requested continued work and deferred
GitHub; auth, remote reads, push and CI remain deferred, not passed or waived.
The previous goal turn was progress: maintained SDK entrypoint committed and
full normal regression completed. This package moves those fixes onto a
separately versioned, eventually device-testable candidate.

Local identity audit reads all15 private archive manifests and matches each
directory's versionCode/commit plus package ID. Highest archived code0403;
there is no0404 archive and no prior0404 reference in current versioned candidate
sources/evidence. Reserve versionName1.0.0/versionCode2026090404 for this local
Pixel successor. This is not a highest-ever-Play assertion or Store permission;
any future Play handoff still needs its own authoritative track/version check.

Only `pubspec.yaml` and the existing `SIT_CLIENT_BUILD` fallback in
`lib/config/private_pilot_config.dart` change from0403 to0404. Two-round bounded
hash propagation updates19 JSON files and five validator hash constants.
Every non-hash claim, source-entry membership, historical candidate identity,
approval state and validator assertion is preserved. Stale historical ratchets
are not promoted to current truth.159 affected tests pass; canonical upload
signing configuration and existing Android Firebase local-file/environment
consistency pass with values kept in memory. A direct validator invocation
without derived Firebase environment failed for missing environment values;
the normal supported file-to-environment path passes. No Firebase/account
configuration was changed. An incomplete first version edit was caught by the
bounded binder before any hashes changed; the complete two-file edit passes.

## Required unchanged candidate envelope

- Package `com.shareittoo.app`; Internal/non-public local Pixel use only.
- API `https://staging.shareittoo.com/api/v1`; Firebase Staging configuration.
- Canonical certificate SHA256
  `098f485e57161558e911fc3c742845925584db31c474cdba08dda02feb0129a4`.
- Google-only social profile; Apple/Facebook disabled.
- Closed `heilbronn_wave0`, non-binding Stage-A and existing technical G3–G5
  surfaces; no real payments, contract activation or provider-hold removal.
- minSdk24, target/compile36; transactional FCM, Analytics disabled and
  Crashlytics still requires its separate voluntary choice.
- No public registration, Store, production, OnePlus, backend deployment or
  actual support-case mutation in this preparation step.

Existing signed/installed0403/sourcef6a9a414 and its proof remain separate.
They contain neither support correction. Never rebuild into that archive or
run its strictly-newer installer/private pinned lifecycle scripts again.

## Verification sequence

1. Freeze this preparation commit with a clean tree; record the exact source
   in newly generated evidence, never using the preparation base as build HEAD.
2. Run unchanged `tool/run_r10_clean_reproducibility.mjs` on that exact source
   through maintained version2
   `/Users/walidchraibi/Documents/Codex/2026-08-19/new-chat/SIT_ANDROID_BUILD_20260904.json`.
   Use a fresh owner-only TMPDIR on the build APFS volume (24GiB admission
   budget); write execution JSON privately. The runner's separate fresh package
   caches, audit, PostgreSQL, complete regression and second debug build remain
   mandatory. Prior813f npm503/timeouts are retained, never bypassed.
3. On cold success, run the configured-checkout full normal regression and
   signed lifecycle on the same frozen source/profile, without manual purges,
   history changes, private-input copying or scanner exceptions. Independently
   verify both artifacts, compiled identity/privacy/surface and exact archive.
4. Only then prepare the data-preserving provisional Pixel update and new
   current-candidate acceptance. No OnePlus before complete Pixel closure.
   Final exact GitHub Regression/CodeQL remains required but owner-deferred.

At this preparation checkpoint, new normal/cold/signed/device results are all
OPEN. Prior implementation tests support only their original source/scope.
The wider Goal still needs real provider/legal prerequisites and its complete
two-role/functionality matrix; this candidate is not full launch readiness.
