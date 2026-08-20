# ShareItToo Current State

Verified: 2026-08-20 on the Mac mini.

## Repository baseline

- Checkout: `/Users/walidchraibi/Worktrees/SIT-master-workflow-20260808`
- Branch / PR: `codex/master-workflow-20260808`, draft PR #7 against `main`.
- Current C1H implementation head:
  `2a67a43ce79da87a127836edfc764079edccbd27`.
- At that implementation head the local branch, remote branch and PR head are
  identical; the working tree is clean and the PR is cleanly mergeable.
- Exact GitHub Actions run `32374184599` is green: backend regression and
  Flutter regression passed, while image publication was skipped.
- No rebase, force-push, history rewrite, branch deletion, PR merge, signed
  release or published artifact occurred.

## Implemented system

- Flutter client version `1.0.0+2026081510` with Android, iOS and web targets.
- Node/Express backend with PostgreSQL migrations through `026`, deterministic
  server quotes, immutable legal/acceptance evidence, checkout and booking
  lifecycle, withdrawal/cancellation and actual-loss rules, handover/return
  evidence, messaging and moderation foundations.
- C1G binds neutral transactional FCM, separate opt-in Crashlytics, fail-closed
  external provider activation and the privacy/retention inventories.
- C1H binds an immutable server category allowlist, private-marketplace and
  commercial-review eligibility, reasoned user-bound moderation decisions,
  snapshot-bound financial documents, fail-closed operator/provider facts and
  a non-activating EUR 5,000 professional-review signal.
- Release and compliance state remains machine-validated under `store/` and by
  `tool/` plus `test/tool/`; repository architecture/evidence is versioned
  under `docs/`.
- Mac-mini Android signing and Android/iOS Firebase configuration gates passed
  the local recovery checks without exposing protected values. Their presence
  is not permission to create or sign a release.
- C1I revalidated the canonical Android upload-signing gate and both protected
  Firebase platform configurations without disclosing protected values.

## Current safe operating state

- C2C private-adult pilot for Germany and only explicitly server-approved
  regions. Missing region facts fail closed.
- Vehicles/transport, drones, paid delivery, shipping, express, deposits, SIT
  insurance/protection and automatic damage collection are out of scope.
- Real money is off; payment execution remains disabled/test-only.
- Ads, marketing analytics, general Firebase Analytics and external generative
  AI are off. Transactional FCM and voluntary Crashlytics remain separately
  controlled and default off.
- Store submission is blocked (`store/submission.json`: draft,
  `submissionAllowed=false`). The retained Store candidate `2026081509` and
  its physical evidence are historical; source build `2026081510` has no new
  signed, commit-bound candidate.
- Privacy, retention, legal, operator/provider and final-binary manifests remain
  draft, incomplete or fail-closed. Open owner, legal, provider, Apple/iOS,
  full device-matrix and final-binary gates must not be silently closed.
- No production, VPS/OpenClaw, SSH, DNS, cloud-console, payment, Store or
  live-provider mutation was made. The MacBook is not required.

## Validation and rollback

- Exact CI backend suite: 273 passed, 0 failed, 0 skipped with PostgreSQL.
- Local backend suite: 272 passed, 0 failed and one expected PostgreSQL skip
  without local `TEST_DATABASE_URL`.
- Complete Flutter suite: 298 passed with one documented skip; the extra
  Google-only profile test, analyzer baseline, web debug build and Android
  debug APK passed.
- Analyzer remains at the accepted 223-item baseline. Dependency audit has no
  high or critical advisory; one transitive moderate `uuid` advisory remains
  recorded without an unsafe forced override.
- Privacy remains draft with 17 data types and nine services. Retention remains
  draft with nine open decisions and 20 stable execution blockers.
- The verified migration package and Git bundle remain rollback evidence.
- C1I readiness result is HOLD: ADB currently sees no physical device; neither
  the `2026081509` nor old `2026081510` private candidate archive is present on
  this Mac mini; and all stored physical-device passes bind older commits.
- The historical Google-only candidate manifest remains internally valid, but
  its build `2026081510` binds commit `4cb0046`, not the current implementation
  head. Phone-verification readiness also fails current-source binding and is
  historical rather than a current release proof.

## Next source of truth

The active bounded task is `docs/current_work_package.md`: FI0 founder-
independence guardrails. C1I is technically complete with an explicit release
HOLD. Older reports and root `architecture.md` are evidence/history, not
permission to reopen a closed launch boundary.
