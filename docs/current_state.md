# ShareItToo Current State

Verified: 2026-08-20 on the Mac mini.

## Repository baseline

- Checkout: `/Users/walidchraibi/Worktrees/SIT-master-workflow-20260808`
- Branch / PR: `codex/master-workflow-20260808`, draft PR #7 against `main`.
- Current G2A implementation head:
  `335eb8999d79aa33159ca3c0498d515947040833`.
- The G2A implementation commit is contained in the local branch, remote
  branch and PR head; the PR remains cleanly mergeable.
- Exact GitHub Actions run `32380693921` is green: backend regression and
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
- FI0 removes the named personal GHCR namespace from critical CI, Docker and
  preflight configuration. Registry and source identity are repository- or
  role-configured; missing explicit preflight configuration fails closed.
- FI0 defines six unassigned functional roles, a critical-process schema, the
  existing append-only audit binding, manual monthly founder-hours aggregates
  and a reusable absence/delegate runbook. No account assignment was invented.
- G2A changes the five primary destinations to `Entdecken`, `Mietkorb`,
  `Buchungen`, `Nachrichten`, `Mein SIT` while preserving the established
  Bookings asset icon and profile-image affordance.
- Existing Wishlist data stays on `wishlists_meta_v1` and
  `wishlist_assign_v1` and is presented as `Mietkorb` > `Gemerkt` with an
  explicit non-binding/no-reservation notice. No persistent cart or project
  data was introduced.
- The old internal `WishlistsScreen` type remains a compatibility entry point;
  existing app/deep-link contracts are unchanged.

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
- Complete Flutter suite: 301 passed with one documented skip; the extra
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
- FI0 role assignees, delegates, company-system ownership, account RBAC,
  absence tests and the normalized founder-replacement compensation amount
  remain explicit external gates. No personal activity monitoring is enabled.

## Next source of truth

The active bounded task is `docs/current_work_package.md`: G2L legal/privacy
delta for G2 only. G2A is technically complete; FI0 external role/account
assignments and all C1I release/device gates remain HOLD. Older reports and
root `architecture.md` are evidence/history, not permission to reopen a closed
launch boundary.
