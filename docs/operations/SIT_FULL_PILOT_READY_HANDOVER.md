# SIT closed-pilot candidate handover

Status: **TECHNICAL_CANDIDATE_READY / PILOT_BLOCKED_LEGAL_GATE** on
02.09.2026.

## Frozen technical candidate

- Worktree: `/Users/walidchraibi/Worktrees/SIT-master-workflow-20260808`.
- Branch: `codex/master-workflow-20260808`.
- Artifact source HEAD: `94dd09ea562107c4dd758bd9a73e7c3e8f97e21c`.
- Android: `com.shareittoo.app`, `1.0.0+2026090201`, minSdk 24,
  targetSdk 35.
- Scope: Google Play Internal testing, Staging API and private pilot
  `heilbronn_wave0` only.
- AAB SHA-256:
  `5301dabccada20f2b77b5668adfc4f1aa60fb45eb43fc8590a3257d7bf796bec`.
- APK SHA-256:
  `a0e0f63219986d44ae6b626409aeebc34035f100e842c57d85616c5aad550593`.
- Upload-certificate SHA-256:
  `098f485e57161558e911fc3c742845925584db31c474cdba08dda02feb0129a4`.

The signed release AAB and APK are stored in the private owner-only archive
`2026090201-94dd09ea562107c4dd758bd9a73e7c3e8f97e21c`. Package, version,
SDK identity, signing certificate, ZIP structure, Bundletool 1.18.1 validation
and binary privacy scan passed. No secret or tester identity is present in
repository evidence.

The complete local candidate-rollover regression passed after a clean Flutter
bootstrap. It includes the repository tool inventory, Backend/PostgreSQL,
Flutter (634 tests with only documented skips), analyzer with zero issues,
Web/Wasm, a real loopback smoke and Android debug (448 tasks). The release-host
capacity guard passed without retaining a timing, retry, rate-limit,
parallelism or build-path workaround.

The exact final-evidence GitHub Regression and CodeQL run IDs are recorded only
after the evidence commit is pushed and both workflows complete. PR #7 remains
Draft, open and unmerged throughout that readback.

## Pixel candidate verification

The Pixel 7 Pro now runs the exact direct APK `1.0.0+2026090201`. The update
from `2026090106` was non-destructive: the upload signature and installed APK
hash match the private candidate, while first-install and app-data-container
identity remained unchanged. The device is signed out; no login, logout or
account mutation occurred.

The public Staging endpoint and the guest UI both confirmed an empty catalog,
not an endless loader and not a transport failure. Temporarily disabling Wi-Fi
produced the explicit `Anzeigen konnten nicht geladen werden.` state. After
restoring the existing Wi-Fi and verifying real Staging reachability, the
server-confirmed empty catalog returned. A force-stop/relaunch also preserved
the exact APK and data-container identity.

Android can report Wi-Fi enabled before Staging is reachable. That timing debt
is closed by a deterministic reachability gate and five regression tests; a
fixed sleep or retry workaround is not a release prerequisite. The run retained
no screenshot, hierarchy, network identifier, account content or device ID.
Google Play split delivery and the authenticated pilot matrix remain unclaimed;
the latter is correctly blocked by the V5.2 legal-snapshot gate.

## Exact Staging state

Staging runs the exact source checkout and API image
`shareittoo-api:94dd09ea562107c4dd758bd9a73e7c3e8f97e21c` with client-build
requirement `1.0.0+2026090201`. Health and readiness are green, and all 354
foreign-key constraints pass the deploy guard. Payment transport remains
in-memory with `livemode=false`; listing AI remains the local mock with no
external provider or billing. The deployment evidence is
`/docker/shareittoo/releases/staging-20260902T015652Z-94dd09ea5621.json`.

## Closed-pilot acceptance truth

B7-B10 now share one fail-closed acceptance contract: synthetic users must be
confirmed private users, listings use the pilot category `cat3/Kameras` and
Heilbronn, offers and acceptance carry the exact V5.2 declarations, and the
client build must match this candidate. The legal-readiness preflight runs
before any acceptance fixture can be created.

The preflight currently returns
`closed_pilot_v52_legal_snapshots_not_ready`; its proof leaves zero active B7
fixtures. Staging foreign-key integrity remains green after cleanup. The
pre-cleanup and post-cleanup database backups and restore proof are retained
under the private VPS backup path recorded in operations evidence.

## Authentic legal stop

`assets/legal/de/legal_manifest_v52.json` is still `draft-blocked`, has no
effective date and explicitly sets `activationAllowed=false`. Its nine user
documents have no approved public or download URLs and the manifest lists 21
open operator/provider facts. The P0B review intake is
`prepared-awaiting-independent-professional-review`, with
`professionallyReviewed=false` and no permission to claim professional
approval.

Accordingly, the nine V5.2 contract snapshots must not be provisioned, even on
Staging, and no booking acceptance, Play activation, public registration or
real-money path may be presented as ready. This is an external professional
legal gate, not a technical failure and not a gate that Codex may fabricate or
self-approve.

## Play and repository boundaries

Build `2026090201` has not been uploaded or activated. The last directly
observed active Internal build remains `2026082601`; the tester list remains at
two entries. Production, Open testing, Closed testing, Store metadata and all
tester settings remain unchanged. Superseded Internal drafts must not be used
as this candidate.

PR #7 remains Draft and unmerged. No Production, Firebase, public Cloud,
payment, DNS, public Store, external listing-AI provider or account mutation is
part of this closure.

## Required gate to continue the real pilot

1. Obtain independent professional V5.2 review and approval evidence.
2. Resolve the open operator, provider, PSP, privacy and retention facts.
3. Produce an effective approved manifest with final document hashes and
   explicit authorization to provision its snapshots on Staging.
4. Provision only those approved snapshots, then rerun B7-B10 and the complete
   authenticated physical-device pilot matrix.
5. Cut or revalidate a candidate only after those results; any Play Internal
   activation remains a separate exact-candidate owner action.

Machine evidence:
`docs/evidence/release-readiness/full-pilot-candidate-2026090201.json`.

## Final assessment

The code, Staging deployment and signed Android artifact are prepared as far
as technically and safely possible. **PILOT_READY must not be claimed.** The
correct closure is `PILOT_BLOCKED_LEGAL_GATE` until the professional V5.2 gate
and approved snapshot provisioning are real and evidenced.
