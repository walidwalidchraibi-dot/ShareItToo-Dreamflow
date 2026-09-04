# WP05 saved-cart surface — consolidated principal ownership

Status: residual P1 defects reproduced; implementation and closure OPEN.
Tested source: `b28da2aa06816fd47eefe3a6657e7674e92cce03` in canonical
`/Users/walidchraibi/Worktrees/SIT-master-workflow-20260808`, branch
`codex/master-workflow-20260808`. Only evidence documents changed during probes.
Owner explicitly deferred GitHub: no auth, remote read, CI, PR or push action.
The preceding assignment correction has its own exact clean proof; these new
findings do not relabel that proof as full-cart acceptance. No new signed build,
Pixel, OnePlus, real account, provider or backend mutation occurred.

## Why this package is next

The remaining paths on the same cart surface still capture a global session
after asynchronous work or install results using only `mounted`. Controlled
probes now demonstrate the failure class beyond creation/assignment. Closing
these privacy/data-integrity paths takes priority over new device mutation or
non-blocking support work. Bundle the remaining cart-surface corrections before
another signed candidate; this is not a new feature or broad unrelated hardening.

## Observed versus still inferred

| Path | Current proof | Consequence and scope |
| --- | --- | --- |
| Add cart item | Stable mocked response passes; late A200 is accepted after B; A401 triggers a refresh using synthetic B credentials | Pin dispatch, refresh policy and result to A; actual server persistence is not claimed |
| Delete cart item | Same service failures plus late A UI snapshot replaces an independently loaded B snapshot | Reject stale result; preserve B state and foreign route |
| Delete project | Same service and UI failures | Same owner chain; no real project was deleted |
| Recheck cart | Same service and UI failures | A availability/price response must not become B state |
| Create custom wishlist | Stable A passes; A dialog remains beneath B; confirming A draft after silent B replacement creates its name under B | Capture owner before dialog, close the exact A route, bind local write |
| Cart-item/booking-group/planner/listing-set navigation | Static risk: session/read awaits with mounted-only navigation and late cleanup | Add targeted controls before claiming safe navigation; no dynamic navigation leak is claimed yet |
| Wishlist folder, rename/delete and inline folder actions | Static risk: folder does not bind its lifetime to the principal; dialogs use global completion/current principal | Classify with exact-route/owner tests; do not claim these rows already passed or failed dynamically |
| Item-details cart entry, two call sites | Static risk: `_storeRentalCartIntent` has no owner and its notice is untracked | Cover the cart action only, not unrelated reservation/edit business flows |

Enabled HTTP/service/UI probe:7 stable controls PASS /11 desired invariants FAIL.
This is four service controls, four late-success failures, four foreign-refresh
failures, three stable UI controls and three stale-UI failures. The B UI snapshot
is independently observed before completing A's response; B's foreign dialog
survives, but A's private project text incorrectly reappears beneath it.
Separate default wishlist probe:1 stable control PASS /2 desired invariants FAIL.
Total:8 controls pass and13 invariant failures across isolated synthetic tests.

These are local HTTP interception and preference/widget fixtures. Fabricated
example.invalid identities and fake credentials are used, never real account
data. Mock success controls establish bounded response handling, not real
deletion, payment, contract or provider acceptance. In the401 probe the simulated
B refresh returns503; a successful B refresh/retry or real backend write is not
claimed. The prohibited cross-principal refresh attempt itself is observed.

The first combined run had6 passes/12 failures. Its two delete-project widget
rows failed because direct callback invocation did not establish request start;
those two rows are NOT product-defect proof. The fixture now taps the actual
localized chip delete button and verifies request start. Final corresponding
stable control passes and the late-A failure reproduces as above. No timeout,
sleep, test parallelism, runtime code or result assertion was relaxed. Preserve
both logs; fixture debt is closed by the real interaction, not by a waiver.

## Bounded implementation sequence

1. Inventory all existing cart and saved-folder action entry points and record
   their initiating owner, awaited work, dispatch, result, notices and navigation.
   Retain the already-fixed project creation/assignment/read cases as controls.
2. Reuse the existing credential-free principal/epoch type for the four direct
   cart mutations and their guest-sync/local-queue prerequisites. Add owner-bound
   repository methods where missing; never globally refresh as a new account.
3. Bind direct cart results and notices, custom-list creation and folder/dialog
   lifetime to their initiating owner. Track exact routes; A cleanup must never
   pop B's current navigator or clear B's newer handle. Cover rename/delete and
   inline folder actions as part of this surface, after reproducing the relevant
   risk. Pass explicit owners at covered local-write boundaries; preserve
   unrelated persistence behavior unless a stronger contract is explicitly tested.
4. Guard cart-origin navigation before each awaited read, remote call, route
   opening and post-route work. Bind the lifetime of any A-owned destination
   by exact route identity while preserving B destinations. Cover only the
   item-details cart helper, not reservation/edit/payment business flows.
5. Make safe current-account/guest behavior and interrupted/silent/epoch-change,
   late200/401/error, malformed session, foreign dialog/page and old-finally/new
   handle behavior permanent tests. Failed or uncertain operations must not
   become successful saves, false empty state or definite non-mutation claims.
6. Refresh only exact source hashes and dependent constants; retain every legal,
   privacy, provider and approval fact. Run focused tests, analyzer, full normal
   regression and exact clean proof on the consolidated final source.
7. Only then select a distinct successor version/signing envelope and resume
   real Pixel cart/core acceptance. Never rebuild into0404 archives or promote
   previous-source device evidence. GitHub remains deferred, not waived.

## Exit, limits and stop conditions

Closure requires all listed entries classified, confirmed defects corrected,
their negative controls green without weakening stable behavior, exact final
source proof and an honest remaining-device/provider matrix. No schema, pricing,
contract, reservation, refund, provider-hold, public registration, Store or
production changes are included. Broader real AI, Stripe sandbox, legal/operator
facts, full Pixel functionality and later OnePlus acceptance remain OPEN.
If an unrelated business/security issue is discovered, record its evidence and
priority rather than silently widening this package. Stop the affected action
on contradictory principal, release or protected-data evidence; continue other
independent in-scope work. Do not request another owner gate for these already
authorized local corrections, and do not begin another signed candidate while
the confirmed P1 cases remain open.

Machine proof: `docs/evidence/release-readiness/wp05-cart-surface-principal-red-20260904.json`.
Private probe sources/logs remain in the current task workspace. Their digests
are recorded in that proof; no raw private runtime/device evidence is committed.
