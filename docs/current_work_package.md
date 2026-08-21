# Current Work Package: FI1 - Operational Delegation Layer

Status: **active under the V2.4 rolling-autonomy runway** on 21.08.2026.

## Authorization and boundary

Walid instructed Codex to follow `00_NEXT_COMMAND_G3A_APPROVED_V2.4.txt`.
G5B is technically GREEN at commit
`21106645639c2c09334468817ca3e7b206ae411c`; GitHub Actions run
`32430660117` associated with that exact PR head passed with 331 backend and
321 Flutter tests, plus one documented Flutter skip. V2.4 therefore
auto-continues to FI1 while all public/live and real-payment gates stay closed.

No production, public/live, VPS/OpenClaw, Maximus, SSH, DNS, cloud-console,
real-payment, Store, signing, provider-account, account-permission or
destructive action is authorized. PR #7 remains Draft and unmerged. Booking
groups, planner, supply enrichment and listing sets remain disabled by default
and unavailable in release mode. FI1 must not invent real role assignments,
delegates, account permissions, staffing evidence or absence-test results.

## G5B handover

- Server-owned versioned sets link only existing same-owner listings and retain
  individual bookability. Required members must all be current and available
  for the selected period; stale truth fails closed.
- Resolution uses existing quote preview truth and preserves exact item price,
  evidence, damage, `needsReview`, refund and audit boundaries.
- 1-Stop eligibility uses the exact internal handover-location hash. Ranking
  may use fewer handovers only; Business status, price and hidden manipulation
  are excluded.
- Migration 031 is additive and has a fail-closed non-empty rollback. Export,
  erasure, retention and privacy inventories cover all three set tables.

## FI1 required result

- Extend the FI0 role model with explicit owner roles, delegate roles and
  executable runbooks for booking groups/listing sets, project planner/cart,
  item evidence/`needsReview` and normal support escalation.
- Bind existing authoritative audit sources and clear, bounded escalation
  thresholds. Normal failures must route to functional roles rather than a
  named person; strategy, existential and explicit owner-authorization gates
  remain distinct.
- Do not create personal account dependencies or claim company-system RBAC,
  staffing, delegate assignment or absence readiness without external evidence.
- Keep the admin pilot cockpit aggregate-only and read-only. Its normal
  operational funnel, founder-hours aggregates and founder-escalation
  aggregates must remain explicitly separate and must never be blended into a
  silent zero or synthetic profitability result.
- Preserve existing staff step-up, least privilege, append-only audit, privacy,
  no-store and sensitive-metadata restrictions. Do not add invasive activity
  tracking, private evidence content or automatic founder monitoring.

## Package gate

Run focused role/delegate/runbook, audit-source, threshold, named-person,
cockpit-separation and fail-closed readiness tests plus the complete backend and
technical regression at the exact package head. Record external staffing/RBAC,
absence-test and founder-replacement gates honestly. When FI1 is technically
GREEN, V2.4 auto-continues to P0A without activating any feature or changing
production, payment, provider, Store or account state.
