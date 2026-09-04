# WP05 cart project — initiating-account correction

Status: locally implemented; focused and full normal regression PASS.
Exact clean-checkout, successor-candidate/device and GitHub proof remain OPEN.
GitHub is explicitly deferred by the owner. This is a bounded P1 interruption
of cart/projects acceptance, not another broad hardening Goal.

## Evidence and decision

Execution worktree `/Users/walidchraibi/Worktrees/SIT-master-workflow-20260808`,
branch `codex/master-workflow-20260808`, base
`ebd0520dfbc1dd9526c721334db5ed99b223dabc` (clean before this correction).
The unchanged installed Pixel is `2026090404`, source
`55a1aa5a11a53151ee6740785eb1e25b79f6b06e`; it does NOT contain this correction.

Actual read-only Pixel/API baseline at 13:37 UTC: known synthetic owner,
non-reservation disclosure, explicit empty cart and project/planner actions.
Both distinct backend principals have HTTP200/private-no-store carts with
zero items/projects, revision0 and no reservation. Temporary probe sessions
were revoked individually and rejected afterward; original Pixel role remains
at Entdecken. No project/cart/booking mutation. Runtime remains Staging5d88295f,
memory payment and live false. A planner button does not prove a working
inventory resolver, and an absent group action in an empty cart does not prove
the backend feature flag is disabled.

Inspection of `wishlists_screen.dart::_addProject` found an awaited dialog
before `DataService.addRentalCartProject` captured the current account. On exact
base ebd0520d, an isolated widget probe proved two failures: A's draft remained
after switching to B; confirming it persisted A's title in B's cart. The stable
A control passed. This is a reproduced local UI/storage defect, not an observed
real-account leak on the Pixel. The original red log is retained.

## Correction and verification

- The cart snapshot carries a credential-free principal/session/epoch owner.
  Project actions capture it synchronously before their first await and check
  it before dispatch, after completion and before showing a result.
- A confirmed guest remains supported; malformed/unreadable session data is
  never accepted as guest authority. Actual logout/relogin invalidates old
  actions even when the same account returns.
- The exact A draft/notice route is tracked and removed on session change;
  newer B dialogs are left intact. Project callbacks also complete their own
  route, not the globally current navigator route.
- Project writes and their prerequisite guest migration keep the same owner
  through local queues and authenticated project/item upserts. They never
  fall back to B credentials or retry a 401 as B. An interrupted guest sync
  retains the original pending intent. A late A confirmation is not a B result.
- Account-change events clear the old cart snapshot. Reloads verify ownership
  before installing results. Other cart mutations, assignment dialogs and the
  complete listing/booking-group lifecycle are not certified by this package.

Focused default tests: 40 PASS, including ten new owner/epoch/widget controls;
enabled-backend HTTP mock profile: 8 PASS; wiring guards: 6 PASS; analyzer: zero.
The HTTP profile is permanently included in the normal regression. No real
provider, SMS, payment, deployment or device write was used in these tests.

One prior local-principal test expected an A project to finish after immediate
session replacement. It now requires explicit cancellation and no project in
either A or B; the unrelated saved-item assertion remains unchanged. This is
the intentional stronger dispatch contract, not a skipped test or weaker
isolation check. The obsolete five-line principal wrapper was removed only
after it became unreferenced; analyzer warnings were not suppressed.

An initial expanded widget run stalled by invoking unrelated native logout
cleanup in a fake-async project test. It was explicitly terminated and is NOT
a pass despite the runner's exit status. TD-WP05-PROJECT-FIXTURE-LOGOUT is closed
for this test: the fixture now uses the existing serialized session-clear
operation with native cleanup disabled, verifies its receipt and real epoch,
and passes deterministically. No timeout/concurrency or production logout
behavior changed. Full native SDK/logout acceptance is not claimed here.

## Bindings, remaining work and rollback

Dependent source hashes were refreshed only for changed inputs and their exact
hash graph. Non-hash privacy/legal/provider claims and validator assertions are
unchanged. Original signed archives and physical evidence remain immutable.

The first full normal run stopped at the tool inventory: 35 retention-validator
tests shared one stale `data_service.dart` source hash in the retention manifest,
which the initial refresh list omitted. That failure is retained; later full
checks were not run in that invocation. The exact missing binding was refreshed
without changing retention rules or any approval; its 46 tests pass. A second
run exposed a resumed-helper defect and omitted retention ratchet references:
already modified intermediate manifests were not seeded into the refresh graph.
Both intermediate failures remain recorded (50, then 22 tool failures). The
helper now includes existing changed intermediates and the explicit retention
hash mapping. All2216 tool tests pass; a second refresh is a deterministic
no-op. No validator assertion, readiness fact or retention rule was weakened.
The complete normal rerun passes: all2216 tools,735 default Flutter tests with
33 declared-profile skips plus every mandatory profile (including the new eight
HTTP cases), analyzer0, Web build/Wasm dry run, loopback smoke and Android debug
build41s. R11 confirms minSdk24/14 permissions/8 exported components. This is
neither standalone Wasm-runtime nor signed-successor/device/CI proof. No earlier
failing or interrupted run is promoted. Machine evidence:
`docs/evidence/release-readiness/wp05-cart-project-principal-local-20260904.json`.

After this successful run, standard scoped Flutter cleanup removed only
regenerable build intermediates (about3GB) and restored about12GiB free. This
was storage housekeeping AFTER a pass, not a prerequisite workaround or a
replacement for clean-source proof. The signed0404 private archive is outside
that tree and remains intact. The normal debug APK digest is retained in the
machine evidence, but the regenerated debug output itself was cleaned.

Next complete exact committed-source clean proof.
Before further project mutations on Pixel, prepare a separately versioned,
signed and verified candidate; do not reuse/relabel0404. Continue cart/projects
and the remaining Growth/core matrix afterward. Full support, real AI, Stripe
sandbox, legal/operator facts, final CI and full Pixel/OnePlus acceptance remain
open. No automatic provider or public release activation is implied.

There is no schema migration or external rollback. Until a verified successor
is installed, the original0404 archive/device is unchanged. If this source
correction needs reversal, use a new forward commit after review, never rewrite
history or discard existing work.
