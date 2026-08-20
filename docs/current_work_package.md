# Current Work Package: G5B - SIT Sets and 1-Stop Sets

Status: **active under the V2.4 rolling-autonomy runway** on 21.08.2026.

## Authorization and boundary

Walid instructed Codex to follow `00_NEXT_COMMAND_G3A_APPROVED_V2.4.txt`.
G5A is technically GREEN at commit
`2da5cc925619055f0f5decddb282af6ff694c641`; exact GitHub Actions run
`32428183285` passed with 323 backend and 317 Flutter tests, plus one documented
Flutter skip. V2.4 therefore auto-continues to G5B even though every
planner/supply/set public-release gate remains closed.

No production external generative AI is authorized. No production, public/live,
VPS/OpenClaw, Maximus, SSH, DNS, cloud-console, real-payment, Store, signing,
provider-account or destructive action is authorized. PR #7 remains Draft and
unmerged. Booking groups, the planner and G5 supply enrichment remain disabled
by default and unavailable in release mode. G5B must preserve the same
fail-closed boundary.

## G5A handover

- Supply enrichment runs only after successful primary-listing creation and
  cannot block or roll back that listing. It uses bounded deterministic
  category templates and makes no title/photo detection claim.
- All five owner outcomes are revision-bound and owner-scoped. Confirmed
  accessories remain item-specific handover documentation; linked listing
  creation copies only safe fields and revalidates owner and classification.
- Private sessions are stripped from public listing output. Export, erasure,
  retention and audit bindings cover the new state.
- The backend and Flutter feature controls default off, reject production or
  release use, and have no external-AI/public-release path.

## G5B required result

- Allow an owner to link existing active listings into an optional SIT Set or
  1-Stop Set. Every member must have the same owner; the server must own and
  validate membership, identifiers, versioning and lifecycle transitions.
- Preserve every member listing's individual bookability. Set creation or
  membership must not silently reserve, merge, duplicate or replace the
  underlying listings, quotes, bookings, contracts or legal evidence.
- A set may be shown for a selected period only when all required members are
  currently eligible and available. Availability and price must be revalidated
  from authoritative server truth; stale or incomplete facts fail closed.
- Preserve item-level price allocation, handover/return evidence, damage,
  `needsReview`, refunds and audit references by reusing the established
  G3/G4/V5.2 boundaries rather than inventing set-level truth.
- Deterministic ranking may favor fewer handovers only as an explicit approved
  signal. Business status and hidden price manipulation must never affect set
  eligibility or ranking.
- Keep account export, erasure, retention, privacy, audit and rollback coverage
  bounded and explicit. No real payment, new legal approval, public rollout,
  external analytics or provider traffic is authorized.

## Package gate

Run focused same-owner, membership/versioning, individual-bookability,
all-required-availability, price allocation, evidence/damage, ranking,
concurrency, lifecycle and feature-gate tests plus the complete technical
regression at the exact package head. Record data lifecycle, compatibility,
privacy impact, migration/rollback and remaining legal/release gates. When G5B
is technically GREEN, V2.4 auto-continues to FI1 without enabling sets publicly
or changing production/payment/provider state.
