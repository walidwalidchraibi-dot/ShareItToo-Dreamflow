# Current Work Package: G3E - Disabled Multi-Item UX and End-to-End Integration

Status: **active under the V2.4 rolling-autonomy runway** on 20.08.2026.

## Authorization and boundary

Walid selected `G3A_ENTSCHEIDUNG_A` and instructed Codex to follow
`00_NEXT_COMMAND_G3A_APPROVED_V2.4.txt`. G3D is technically GREEN at commit
`871fc3299f8b2520dfeba623532c792351eb757c`; exact GitHub Actions run
`32416833455` passed. V2.4 therefore auto-continues to G3E.

No production, public/live, VPS/OpenClaw, Maximus, SSH, DNS, cloud-console,
real-payment, Store, signing, provider-account or destructive action is
authorized. PR #7 remains Draft and unmerged. `BOOKING_GROUPS_ENABLED` remains
false and production activation is rejected.

## G3D handover

- Migration 030 adds an append-only bridge from accepted group positions to
  separately valid V5.2 item bookings and exactly one shared pickup plus one
  shared return appointment.
- Binding validates the final group quote, exact item allocation, actors,
  period, currency, V5.2 contract, underlying quote and both declarations.
- Photos, accessories, confirmations, chat, timers, return/damage state and
  `needsReview` remain independently keyed by item booking. Only an explicit
  active account-scope participant suspension holds the complete overlay.
- G3D creates no booking, contract, payment, refund or damage charge. Exact
  addresses remain inside the existing item-booking disclosure boundary.
- Exact PostgreSQL, backend, Flutter, Web, Android debug, secret, dependency,
  Compose and API-image checks passed in CI.
- Detailed evidence is in
  `docs/compliance/g3d-shared-handover-item-evidence-2026-08-20.md`; the
  architecture decision is
  `docs/decisions/ADR-030-g3d-shared-handover-item-evidence.md`.

## G3E required result

- Present a same-owner multi-item request/cart with an unambiguous group total
  and exact item-level breakdown.
- Compare the owner's counter-offer with the preceding quote and require
  explicit renter acceptance of the exact revision.
- Present the shared pickup/return appointment while keeping the complete
  evidence checklist and status visible independently for every item.
- Exercise the bounded group path end-to-end without creating real money,
  Store, cloud, production or public/live state.
- Keep every entry point disabled by default and unavailable for public/live
  use until G3L and the later professional legal gate permit activation.

## Package gate

Run focused checks, the full technical regression and exact commit-bound CI.
Record UX consent boundaries, item isolation, activation controls and rollback.
When G3E is GREEN, V2.4 auto-continues to G3L-DRAFT; stop only at a defined
hard gate.
