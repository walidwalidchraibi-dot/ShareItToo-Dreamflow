# WP05 cart assignment — initiating-account correction

Status: P1 reproduced locally; correction and closure still OPEN.
Source under test: `b748e3befcef7b0af0efe93135a510a98b56ba16`, canonical
`/Users/walidchraibi/Worktrees/SIT-master-workflow-20260808`, branch
`codex/master-workflow-20260808`. Only evidence documents changed during probes.
The preceding project-creation correction retains its separate exact clean
proof. Installed0404/source55a1 is unchanged and contains neither correction.
GitHub remains owner-deferred; no remote/auth/CI/PR/push activity.

## Concrete decision and evidence

`wishlists_screen.dart::_assignCartItem` opens an untracked modal sheet before
capturing an initiating account. It completes via the current Navigator and
its result is installed with mounted-only checks. The controlled local widget
probe proves that A's assignment sheet remains after A-to-B while a newer B
dialog remains on top. Stable A successfully assigns its item to its own project.

`DataService.assignRentalCartItemToProject` reads a cart, then calls the unbound
`BackendRepository.putRentalCartItem`. The enabled-backend HTTP mock returns A's
cart while installing B's synthetic session. The following PUT actually uses
B's synthetic authorization with A's item/listing/project data. Stable A uses A
and completes. This is a demonstrated mock dispatch, not an assertion that real
server validation accepted cross-account data or that the Pixel leaked data.

Each profile has one passing control and one failed desired invariant. No real
network, account, provider, payment, cart or device mutation occurs. The private
probe uses only fabricated example.invalid identities and HTTP interception.
No concurrency, timeout, cache purge, or failed-result waiver is used.

## Bounded sequence and exit

1. Bind the exact assignment sheet and its completion to the captured snapshot
   owner/epoch; dismiss only A's route and preserve newer B routes.
2. Carry that owner through the prerequisite cart read, guest synchronization,
   local queue and item upsert. A response or 401 must not select B credentials.
   Reject stale results and suppress A-only errors/navigation under B.
3. Permanently include stable owner/guest, silent switch, logout/relogin epoch,
   late success/error and HTTP cross-account controls in the normal regression.
4. Refresh exact source hashes only, preserve all non-hash legal/privacy/provider
   facts, and run focused checks, analyzer, full regression and exact clean proof.
5. Only after this closure and residual cart-path classification, freeze a new
   distinctly versioned signed Pixel successor; never overwrite0404 evidence.

Direct cart add/delete/recheck, item navigation and complete booking groups
are not proved safe by the assignment probe. They require bounded classification
before claiming complete cart acceptance. Do not silently expand this correction
to all security actions, providers, backend business rules or unrelated support.
Stop the affected action on contradictory privacy/security/release evidence;
do not block independent work merely because GitHub is deferred. No Store,
OnePlus, SMS, paid provider or production action is authorized by this package.

Private retained logs: `SIT_WP05_0404_EVIDENCE.ZJuzfC/cart-assignment-red-widget.log`
and `cart-assignment-red-http.log`, under the existing task workspace. Exact
digests and post-correction outcomes must be appended at closure, never replace
these red-first observations with a later green result.
