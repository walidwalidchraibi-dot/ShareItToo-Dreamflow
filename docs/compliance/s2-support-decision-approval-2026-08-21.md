# S2 support decision approval ledger - technical compliance record

Status: locally verified implementation candidate, non-live and fail-closed.
GitHub PostgreSQL integration is required before closeout.

## Bound source and blocker scope

This package follows the current Drive Support Packet source-of-truth,
case-handling SOP, automation approval specification and 167-scenario matrix.
It directly addresses the technical blocker conditions represented by:

- `SUP-008`: a pending-approval state without an exact draft;
- `SUP-009`: a red decision recorded without independent approval;
- `SUP-010`: resolution without verified implementation evidence;
- `SUP-020`: support-role access outside the assigned queue; and
- `SUP-033`: proposal content changed after approval.

The package does not treat those Drive documents as professional legal advice,
an approved retention schedule, real operator assignment or provider
authority.

## Implemented controls

- Canonically normalized proposal payload with exact SHA-256 binding.
- Explicit `pending`, `approved`, `rejected` and reserved `superseded`
  approval states with database truth constraints.
- Administrator-only review behind active account and Staff Step-up.
- Four-eyes rule: proposer and approver must be different accounts.
- Optimistic expected version and exact expected payload hash on review and
  implementation records.
- PostgreSQL trigger protection for immutable proposal content, completed
  approval evidence and same-state implementation evidence.
- Separate implementation status, reference, verifier, verification time and
  failure reason; approval itself never implements a measure.
- Simulation/internal-testing-only implementation ledger endpoint. It emits
  append-only internal events and sanitized audit metadata but has no external
  action adapter.
- Decision-backed resolution requires approved exact hash plus succeeded,
  verified implementation. Non-green cases cannot resolve without a decision.
- Support-role queue, detail, transitions, decision list and proposal creation
  require an explicit `current_owner_id` assignment to that staff account.
- Bounded measure allowlist. Monetary entries are simulation-only refund or
  payout reviews, integer minor units and EUR; automation is rejected.
- Privacy export, retention inventory and both exact source-hash manifests now
  include the S2 workflow and migration while remaining draft/fail-closed.

## Pre-close verification

- Focused S1/S2 domain and workflow verification: 44 tests passed, zero
  failed.
- Complete local backend regression: 388 tests passed, zero failed and one
  PostgreSQL integration test skipped because no local `TEST_DATABASE_URL` is
  configured.
- Privacy, retention/deletion, PSP sandbox and invited-pilot validator tests:
  67 passed, zero failed. Their executable validators also pass while keeping
  every dependent live gate false.
- CI-compatible technical regression passes: 321 Flutter tests, the separate
  Google-only social-profile test, Web build and loopback smoke, and Android
  debug APK build.
- Backend syntax/shell checks and full Git-history/working-tree secret scan
  pass. Production dependency audit has zero high or critical findings and one
  known moderate transitive `uuid` advisory through optional Firebase Admin
  storage dependencies; it is not silently classified as fixed.

GitHub CI must still apply migration `033` to PostgreSQL 16 and execute its
database guard probes before this candidate is recorded as integrated.

## Remaining boundaries

- No approved support policy snapshot was invented and no snapshot-authoring
  route is included.
- No message was sent and no user-facing decision communication is claimed.
- No evidence file upload, malware scan, appeal workflow or account measure is
  implemented by S2.
- No payment/refund/payout provider call or real-money state change can be
  initiated by these routes.
- Professional legal, retention, privacy, operator/provider, Store, Cloud,
  public pilot and production gates remain open and fail closed.
