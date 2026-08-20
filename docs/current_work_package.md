# Current Work Package: G3C - Quote and State Orchestration

Status: **active under the V2.4 rolling-autonomy runway** on 20.08.2026.

## Authorization and boundary

Walid selected `G3A_ENTSCHEIDUNG_A` and instructed Codex to follow
`00_NEXT_COMMAND_G3A_APPROVED_V2.4.txt`. G3B is technically GREEN at commit
`7b1be00420b41941758678e77f2a8caa1dc3a659`; exact GitHub Actions run
`32409736722` passed. V2.4 therefore auto-continues to G3C.

No production, public/live, VPS/OpenClaw, Maximus, SSH, DNS, cloud-console,
real-payment, Store, signing, provider-account or destructive action is
authorized. PR #7 remains Draft and unmerged. `BOOKING_GROUPS_ENABLED` remains
false and production activation is rejected.

## G3B handover

- Migration 028 adds immutable `booking_groups` and normalized append-only
  `booking_group_positions` without changing historical V5.2 records.
- A group binds one private owner/renter context and compatible country,
  currency, period, location, handover, legal, cancellation and payment facts.
- Position guards validate listing, quote, item allocation and optional
  existing booking bindings. Unique constraints fail closed under concurrent
  duplicate insertion.
- Exact PostgreSQL forward/rollback/concurrency coverage and the complete
  Flutter regression passed in CI.
- Detailed evidence is in
  `docs/compliance/g3b-booking-group-foundation-2026-08-20.md`; the architecture
  decision is `docs/decisions/ADR-028-g3b-booking-group-foundation.md`.

## G3C required result

- Build a deterministic server-truth group quote with explicit item
  allocations.
- Permit the owner to accept all, decline all, or create a counter-offer for a
  changed item set.
- Every counter-offer is a new immutable quote/version and requires explicit
  renter consent. Silent partial acceptance is forbidden.
- Transitions and audit events are idempotent; price and state are never
  client-authoritative.
- Preserve all single-item V5.2 contracts and keep the entire group path
  technically/test-only behind the disabled flag.

## Package gate

Run focused checks, the full technical regression and exact commit-bound CI.
Record the decision and rollback path. When G3C is GREEN, V2.4 auto-continues
to G3D; stop only at a defined hard gate.
