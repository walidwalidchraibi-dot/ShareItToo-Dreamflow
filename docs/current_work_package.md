# Current Work Package: C1B - V5.2 Price and Quote Truth

Status: active after the green C1A delta audit.

## Objective

Close only the pricing deltas proven open by
`docs/compliance/c1a-v52-delta-audit-2026-08-20.md`:

- bind every discount to a stable server-side identifier, concrete display
  label and funding source inside the immutable quote snapshot;
- make the checkout expose the exact `Preisaufschlüsselung` while keeping the
  renter total visible without an extra interaction;
- ensure card, detail, checkout, owner acceptance, cancellation and receipt
  paths use the same stored cent values rather than current listing state.

## Baseline and inputs

- Branch: `codex/master-workflow-20260808`; draft PR #7.
- R1 guidance commit: `04a9db9df19e88e2fd379cc47606d063134d978b`.
- C1A result: GREEN for bounded C1B-C1I continuation; release remains HOLD.
- Authoritative product rules: V5.2 Core sections 1-3 and 14 plus the V5.2
  Legal Map price and event-flow decisions.

## Allowed work

- Add forward-only schema fields or a new migration for immutable discount
  evidence if required.
- Update server quote generation, strict client parsing and price surfaces.
- Add or update focused backend, Flutter, wiring and PostgreSQL tests.
- Update hash-bound manifests only for changed inventoried source files while
  preserving every draft/open/fail-closed status.

## Not allowed in C1B

- No V5.2 legal-text activation, contract wording change or declaration
  migration; those belong to C1C/C1D.
- No production, VPS/OpenClaw, DNS, cloud, payment, Store, provider or live
  traffic action.
- No real-money enablement, signed release upload, public rollout or
  destructive Git action.

## Acceptance criteria

- The server is the only binding source for discount identity, wording,
  funding and all monetary values.
- Discounted and undiscounted canonical V5.2 examples plus cent-rounding cases
  pass in backend and Flutter tests.
- The exact checkout label `Preisaufschlüsselung` is present and the total
  remains visible without opening it.
- Existing transport/deposit/protection/real-money boundaries remain closed.
- Full local technical regression and GitHub CI are green after the bounded
  commit.

## Expected next transition

GREEN: C1C - V5.2 Legal Registry and Immutable Assets.
YELLOW/RED: preserve evidence and stop at the exact pricing/schema conflict.
