# WP02 — shared provider SDK ownership correction

Status: **LOCAL FULL REGRESSION PASS / EXACT SOURCE CI PENDING / DEVICE OPEN**.
Base HEAD: `239c5aa1f74e55cb2991f97832a1d855a7ae7e94`.
Branch: `codex/master-workflow-20260808`.
Worktree: `/Users/walidchraibi/Worktrees/SIT-master-workflow-20260808`.

## Decision and scope

The read-only preparation in `WP02_PROVIDER_READINESS_2026-09-03.md`
reproduced cleanup from obsolete social calls that acquired no identity.
Additional offline probes established the same effect for disabled providers
and an interleaving where late A cancellation cleared an already acquired B
SDK identity. This is an authentication ownership defect, not proof of backend
data disclosure or the cause of the earlier physical SMS dialog observation.

Use one independent serialized SDK-operation queue for social acquisition and
phone credential confirmation through awaited cleanup. It reuses the existing
queue implementation but not the persisted-SIT-session queue instance. A mere
entry guard or UID check before an awaited global sign-out cannot protect the
interleaving. No observation timeout releases the queue while native work is
still running. Backend identity/session transactions retain their own owner
checks and targeted cleanup.

The owner received the bounded decision overview before implementation.
Source CI for the preceding SMS correction finished during this local work:
Regression `33806616812`, including clean checkout, and CodeQL `33806616843`
pass on the base HEAD. Those checks do not certify this new correction.

## Behavior

- Social entry captures the session epoch synchronously even if omitted by the
  caller. Obsolete/disabled entry acquires and cleans nothing. Queued actions
  recheck currency when admitted. Provider initialization/acquisition is also
  followed by a current-action check before the next SDK step.
- Only successful resource acquisition is tracked for Firebase, Google and
  Facebook cleanup. Failed/cancelled acquisition does not sign out an existing
  unrelated Firebase identity. Firebase cleanup requires the acquired UID and
  exact shared SDK-operation epoch, and is awaited before admitting a successor.
- Social and manual/automatic phone credential confirmation share this queue.
  A new SMS challenge does not transfer an already acquired SDK identity to
  another attempt. Cleanup uses the SDK-operation epoch, not the current SMS
  challenge generation. The existing `shouldCleanUpPhoneIdentity` predicate
  therefore receives SDK-operation epochs on its real call sites.
- Superseded SMS challenges are checked again before remote confirmation.
  Known remote acceptance is retained if the response arrives after an owner
  or challenge change. Confirmed cleanup failure remains different from an
  unconfirmed or unknown outcome. No UI navigation or dialog ownership changes.

## Verification and permanent inventory

Maintained offline integration tests use real AuthService with mock Firebase,
Google and Facebook interfaces and an in-memory HTTP client. A network-forbidding
override prevents accidental real traffic. Two explicit profiles are now part
of `technical_regression_check.sh`; default skipped-profile cases are not
counted as executed tests. The profiles cover preflight, disabled providers,
same-UID succession, queued stale owners, delayed cleanup, social/phone order,
native provider cancellation/acquisition/backend failures, and confirmed versus
unconfirmed phone cleanup outcomes. The original five obsolete/disabled
reproductions pass after the fix.

A permanent inventory confines SDK imports/mutations to the reviewed facade,
checks queue/ownership wiring and requires both mock profiles in the full gate.
Focused analyzer is clean after explicitly declaring the four already locked
mock-interface packages as dev dependencies. Only dependency classification
changes in the lockfile; versions, source hashes and runtime packages do not.

Focused profiles: 17 shared-SDK/phone cases and 11 native-provider cases PASS;
the nonselected profile's skips are not passes. Complete Node tool inventory:
2,151 PASS. Backend: 795 PASS with two expected skips, syntax checks PASS.
The first full local gate stopped at the unchanged host-capacity floor before
executing tests. Following the precisely recorded generated-cache recovery in
`N29_BUILD_HOST_DEBT_2026-09-03.md`, the full gate completed with exit 0:
2,151 tool tests; 665 default Flutter passes plus 33 profile skips (five
pre-existing and 28 separately executed below); analyzer zero issues; the
17-case and 11-case mock profiles; other configured profiles; Web debug;
Wasm dry run; loopback smoke; Android debug and binary audit all PASS.
Android audit reports minSdk 24, 14 permissions and eight exported components.
This is not standalone Wasm runtime, a signed candidate, or device acceptance.
Historical artifact/device validators used the documented local metadata-only
mode (`CI=true SIT_ALLOW_CANDIDATE_ROLLOVER=1`). Exact new-HEAD GitHub
Regression/CodeQL/clean-checkout and physical candidate proof remain pending.
The recovery does not close the recurring host debt: end free space was
1,106,232 KiB and the normal build-to-archive lifecycle still needs proof
without manual cache recovery.

Finalized private logs, outside Git (SHA-256):

- `/tmp/sit-wp02-sdk-full-regression-capacity-recovered.log`:
  `4cd9a21abcf42e3df8131da7b0ff0593250fe4b78ea7776055dc6d3096420a8b`.
- `/tmp/sit-wp02-sdk-backend-regression.log`:
  `534389034080f98127a34dbe733b4e50d0fda02b2dba29c99b7e33f5c45a96d7`.
- `/tmp/sit-wp02-sdk-full-secret-scan.log`:
  `cda1386c67777788667e7087b58983d034d2f4b8b373c22ec91352197064bc09`.

Full-history and working-tree secret scan PASS: zero new unexpected findings;
21 exact historical findings matched the reviewed baseline. `git diff --check`
passes. Private logs do not contain or substitute for real-provider acceptance.

## Source-binding audit

AuthService, the full-gate script and dev-dependency manifests change current
source inventories. The 23 affected JSON manifests change only reviewed hash
fields; five validators change only corresponding literal hashes. Structural
comparison excludes only `sha256`, `privacyManifestSha256` and
`activeProviderEvidenceSha256`; every other claim remains identical to base.
No approval, retention, provider decision, historical verified HEAD, frozen
artifact hash or external readiness is promoted by the binding refresh.
Ratchets that deliberately reference older historical manifests retain their
original hashes; only ratchets bound to the current base are advanced.

## Remaining risk, rollback and next step

An unresolved native SDK future keeps later SDK operations waiting until it
terminates; a non-cancelling timeout must not manufacture safe ownership release.
Native platform behavior still needs a separately bound candidate and affected
Pixel acceptance. Existing best-effort social cleanup semantics are preserved;
no stronger claim of external-provider session revocation is made.

No migration or backend deployment. Rollback is a normal reviewed forward
revert of the eventual bounded commit, with source bindings refreshed; no
history rewrite. Frozen Pixel candidate 2026090307 is unchanged. No extra SMS,
Meta app, Apple account, provider activation, Store change, OnePlus access,
real-money action or PR merge occurred. WP01/WP02 and the encompassing Goal
remain incomplete until their original runtime requirements are evidenced.
