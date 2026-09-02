# SIT closed-pilot candidate handover

Status: **TECHNICAL_CANDIDATE_READY / PILOT_BLOCKED_LEGAL_GATE** on
02.09.2026.

## Frozen technical candidate

- Worktree: `/Users/walidchraibi/Worktrees/SIT-master-workflow-20260808`.
- Branch: `codex/master-workflow-20260808`.
- Artifact source HEAD: `c678c6911569139eabdbcd45a57112f2ef8567fb`.
- Android: `com.shareittoo.app`, `1.0.0+2026090106`, minSdk 24,
  targetSdk 35.
- Scope: Google Play Internal testing, Staging API and private pilot
  `heilbronn_wave0` only.
- AAB SHA-256:
  `534844a37a5790e5bcb67370671e1a48c099bc0b9a8c65136c4b2a0f7cd7d883`.
- APK SHA-256:
  `309e1982b40ecc2f8679d8bb35d6e91e05109b4770bac806bebacb43350da24b`.
- Upload-certificate SHA-256:
  `098f485e57161558e911fc3c742845925584db31c474cdba08dda02feb0129a4`.

The signed release AAB and APK are stored in the private owner-only archive
`2026090106-c678c6911569139eabdbcd45a57112f2ef8567fb`. Package, version,
SDK identity, signing certificate, ZIP structure, Bundletool 1.18.1 validation
and binary privacy scan passed. No secret or tester identity is present in
repository evidence.

The complete local candidate-rollover regression passed after a clean Flutter
bootstrap. It includes the repository tool inventory, Backend/PostgreSQL,
Flutter (634 tests with only documented skips), analyzer with zero issues,
Web/Wasm, a real loopback smoke and Android debug (448 tasks). The release-host
capacity guard passed without retaining a timing, retry, rate-limit,
parallelism or build-path workaround.

## Exact Staging state

Staging runs the exact source checkout and API image
`shareittoo-api:c678c6911569139eabdbcd45a57112f2ef8567fb` with client-build
requirement `1.0.0+2026090106`. Health and readiness are green, and all 354
foreign-key constraints pass the deploy guard. Payment transport remains
in-memory with `livemode=false`; listing AI remains the local mock with no
external provider or billing. The deployment evidence is
`/docker/shareittoo/releases/staging-20260902T001250Z-c678c6911569.json`.

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

Build `2026090106` has not been uploaded or activated. The last directly
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
`docs/evidence/release-readiness/full-pilot-candidate-2026090106.json`.

## Final assessment

The code, Staging deployment and signed Android artifact are prepared as far
as technically and safely possible. **PILOT_READY must not be claimed.** The
correct closure is `PILOT_BLOCKED_LEGAL_GATE` until the professional V5.2 gate
and approved snapshot provisioning are real and evidenced.
