# WP05 — support intake bound to its initiating account

Status: LOCAL CORRECTION / FULL NORMAL PASS / CLEAN-CHECKOUT PROOF NEXT.

## Evidence and scope

Base: `f304544fb503868d7007ba5ecbb32aedf0980794`, branch
`codex/master-workflow-20260808`, worktree
`/Users/walidchraibi/Worktrees/SIT-master-workflow-20260808`.

The preceding Pixel/privacy package independently reproduced a pending A
support receipt appearing after a switch to B; the stable-A control passed.
This package additionally reproduced four transport failures: both intake
endpoints selected B after a stale-A call or retried with B after an A 401.
Two same-session transport controls passed. Tests used synthetic sessions
and a zone-local MockClient, never real support cases or provider traffic.

Affected entrypoints: Help Center, booking details, ongoing owner details,
public profile and message thread. The two writes are support-case creation
and handover-exception intake. Case lists/details/appeals and the entire
legacy local-thread persistence queue are not covered by a complete new
account-switch proof; they remain acceptance follow-ups, not presumed safe.

## Implemented invariant

- A support interaction loads one immutable token-free owner under a stable
  authentication epoch. Every entry captures it before the first action await.
  An old interaction never adopts B, even when A later signs in again.
- All five entrypoints pass that owner through the form and owned navigation.
  Owner checks surround asynchronous reads, receipt handling, local support
  thread continuation and navigation. Mismatching current-user IDs stop.
- Both backend writes require the explicit owner and owner-only credentials.
  Idempotency-Key is retained. A 401 is not retried using global current auth.
- Success and failure are shown only to the still-current initiating owner.
  Unknown transport outcomes remain “not confirmed,” not “not submitted.”
  No local replacement case or definitive rejection is invented.
- Session invalidation clears form text and removes only A-owned route/dialog
  identities. An unrelated B dialog above A survives. No global stack pop,
  arbitrary timeout, delayed toast or Navigator reset is used.
- Once A's request was validly sent, its server-side result is not undone by a
  UI account switch. The client suppresses the stale result; it cannot cancel
  a potentially completed server operation or transfer it to B.

## Verification

Focused: 56 UI/support tests; ten enabled support/privacy HTTP-helper tests;
seven principal wiring tests; 202 privacy/retention/RW/source-binding tests.
Changed-file analyzer: zero issues. Working-tree/history secret scan passes
with the unchanged reviewed historical baseline. No scanner/test waiver.

Full normal regression is terminal PASS: all 2,180 tool tests, 700 default
Flutter tests plus all mandatory additional profiles (33 default profile
skips do not replace their explicit runs), whole analyzer zero issues, Web
build/Wasm dry run, loopback Web smoke and Android debug build (38 seconds).
R11 verifies minSdk 24, 14 permissions and eight exported components. Capacity
and generated-output limits pass without a purge or lowered concurrency.
Full log SHA-256:
`934cb53af5f38107870bce81d4df4c00ae8c30ea89cb3757a19ee67dc7485679`.
No standalone Wasm runtime or signed-artifact reproduction is claimed.

The initial guarded guest flow left a progress spinner running beneath the
login sheet. Its existing deterministic test failed; the sending state now
ends before waiting for that sheet. All 56 UI tests then passed. No longer
timeout, reduced parallelism or retry-to-green was introduced.

The source inventories now additionally require the shared support principal
controller. Drift tests enforce its privacy and draft-cleanup bindings. Other
inventory and dependent validator changes are SHA-only, compared to base with
non-hash claims/assertions preserved. Existing approval, provider, historical
candidate and CI states are not advanced by refreshing source hashes.

Focused proof SHA-256 values:

- Red transport: `f0994f754819b07d28d7c8756d93762d0bb4d004558f6a4188c0678579aa989b`.
- UI: `404a9e66b3ce9cd40ca8c1a38c3ca77fdcb0b195fe1367c952399bbaa208c2de`.
- HTTP: `18b527e0389de4e7506420366c3c8e0dd65b9c3b1890991ea6855b4cf521decb`.
- Bindings: `bda9fef8b4fcc887fff8c7df036e30672be840f39f20d212ebc30885e56b44c6`.
- Analyzer: `f8179d35b0a88dad34bfd77d5218ac6a761f25e10f082865d9bd922e8d2d165b`.

## Separation, rollback and next work

Frozen installed Pixel build `2026090403` remains bound to
`f6a9a41471058c9f80ffd01283c42b9d74a8845c` and DOES NOT contain this correction.
Its immutable APK/AAB and earlier evidence are unchanged. No device action,
backend deployment, real support write, SMS, OnePlus, Store, production,
provider activation or account mutation occurred in this correction package.

GitHub authentication, push and exact Regression/CodeQL remain deferred by the
owner, not waived or passed. Full normal regression passes; commit this bounded
correction, then prove the exact implementation from a clean checkout.
A distinct future signed candidate and actual two-role support acceptance are
required before claiming device closure. The encompassing Goal remains open.

No schema migration. Rollback is an ordinary reviewed revert of this bounded
implementation and matching source bindings, never a history rewrite; rollback
would restore the known intake race and cannot establish release readiness.
