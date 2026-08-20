# Current Work Package: G3D - Shared Handover/Return and Item Evidence

Status: **active under the V2.4 rolling-autonomy runway** on 20.08.2026.

## Authorization and boundary

Walid selected `G3A_ENTSCHEIDUNG_A` and instructed Codex to follow
`00_NEXT_COMMAND_G3A_APPROVED_V2.4.txt`. G3C is technically GREEN at commit
`ff02c6afb1bcadedc05c746ec2ed990478506bbe`; exact GitHub Actions run
`32413370914` passed. V2.4 therefore auto-continues to G3D.

No production, public/live, VPS/OpenClaw, Maximus, SSH, DNS, cloud-console,
real-payment, Store, signing, provider-account or destructive action is
authorized. PR #7 remains Draft and unmerged. `BOOKING_GROUPS_ENABLED` remains
false and production activation is rejected.

## G3C handover

- Migration 029 adds immutable server-truth group quote revisions, normalized
  item allocations, append-only state events and actor/request-hash-bound
  idempotency records.
- An initial quote covers every group position. The owner can accept all,
  decline all or propose a freshly requoted changed item set. A counter-offer
  becomes effective only after exact, explicit renter consent.
- Database guards bind actors, predecessor chain, quote hashes, full initial
  membership and allowed transitions. Silent partial acceptance fails closed.
- G3C creates no booking, rental request, availability hold, contract, payment
  or refund. The public route remains disabled.
- Exact PostgreSQL, backend, Flutter, Web, Android debug, secret, dependency,
  Compose and API-image checks passed in CI.
- Detailed evidence is in
  `docs/compliance/g3c-group-quote-state-orchestration-2026-08-20.md`; the
  architecture decision is
  `docs/decisions/ADR-029-g3c-group-quote-state-orchestration.md`.

## G3D required result

- Bind one compatible handover and one compatible return appointment at group
  level without replacing item-specific V5.2 evidence.
- Preserve required photos, accessory state, evidence identifiers, damage and
  `needsReview` independently per item.
- A disputed item must not automatically poison unrelated positions unless an
  explicit system-risk rule applies.
- Preserve current V5.2 chat, timer, address, role and privacy boundaries.
- Keep the complete path technical/test-only behind the disabled group flag.

## Package gate

Run focused checks, the full technical regression and exact commit-bound CI.
Record decision, data isolation and rollback. When G3D is GREEN, V2.4
auto-continues to G3E; stop only at a defined hard gate.
