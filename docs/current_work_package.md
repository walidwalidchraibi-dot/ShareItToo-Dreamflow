# Current Work Package: C1E - V5.2 Withdrawal, Cancellation, No-Show and Separate Refunds

Status: active after green C1D implementation and GitHub CI.

## Objective

Close the remaining V5.2 withdrawal and cancellation gaps proven open by
`docs/compliance/c1a-v52-delta-audit-2026-08-20.md` without activating payments
or the draft legal bundle:

- preserve the accessible, reason-free, two-step withdrawal flow and its
  durable receipt while binding affected paths to V5.2 document/version facts;
- keep the exact 14-day solution-right precedence, 24-hour rule and bounded
  60-minute grace period;
- replace every unresolved after-start or renter-no-show amount with a complete
  authorization- and evidence-bound actual-loss workflow;
- account for saved expenses, actual replacement rental and proven lower or
  absent loss before any rent/fee obligation can become final;
- preserve separate `rent_refund` and `sit_fee_refund` objects and debtors.

## Baseline and inputs

- Branch: `codex/master-workflow-20260808`; draft PR #7.
- C1D implementation: `67c5fda88a4637ba2e55a6b28595f2e8af1596c0`;
  GitHub Actions run `32347860649` is green.
- Drive control `02_CODEX_WORK_PACKAGES_SIT_V2.3.md` maps C1E specifically to
  withdrawal, cancellation, no-show and separate refunds.
- V5.2 Core sections 5 and 6 are authoritative for ordering, time boundaries,
  actual-loss reductions and debtor separation.
- Existing V5.1 foundations include `backend/src/v51_termination_domain.js`,
  `backend/src/v51_withdrawal_workflow.js`, migration 018, Flutter withdrawal
  UI, durable receipts and refund obligations.
- C1A proves the remaining gap: `pending_actual_loss_assessment` has no complete
  authorized capture, decision and closure path for replacement rental, saved
  expenses and lower/zero loss.

## Allowed work

- Audit the existing withdrawal, cancellation, no-show, refund-obligation,
  booking-state and receipt paths before mutation.
- Add only forward, append-only schema/events needed to capture actual-loss
  inputs, evidence references, counterparty statements, calculations and final
  resolution without overwriting historical V5.1 evidence.
- Version the affected withdrawal/cancellation workflow for V5.2 and bind it to
  the exact booking quote, contract/document versions, actor and timeline.
- Preserve the reason-free two-step withdrawal flow, immediate durable receipt,
  before-/after-handover outcomes and `withdrawalReturnRequired` state.
- Implement deterministic cent calculations with a hard cap at the stored
  discounted rent, explicit deductions for saved expenses and actual
  replacement rental, and support for proven lower or zero loss.
- Apply the same actual-loss rule to renter no-show; never use a fixed
  100-percent penalty.
- Keep rent and SIT-fee refund/obligation records separate, idempotent,
  auditable and bound to their different debtors.
- Add focused boundary, role, mutation, idempotency, receipt and event-order
  tests and wire them into the complete technical regression.

## Not allowed in C1E

- No actual PSP refund, capture, payout, transfer, chargeback or real-money
  operation; only truthful local obligations/calculations may be created.
- No automatic damage charge, damage offset, security deposit, protection
  product, guarantee or SIT collection service.
- No unilateral client amount/status decision and no unsupported legal,
  allocation or adjudication rule.
- No provisioning or activation of the `draft-blocked` V5.2 legal bundle and no
  invented public/download URL, provider fact or delivery-success claim.
- No destructive migration, V5.1 history rewrite, reset, rebase, force-push or
  branch deletion.
- No production, VPS/OpenClaw, DNS, cloud console, payment, Store, provider,
  signed-release, public-rollout or live-traffic action.

## Acceptance criteria

- A valid 14-day solution right takes precedence over cancellation in every
  affected state.
- At least 24 hours before start yields full rent and fee refund; under 24 hours
  retains at most 50 percent of discounted rent and a fee equal to 10 percent
  of that retained rent.
- A contract concluded less than 24 hours before start receives exactly 60
  minutes free cancellation from receipt, capped at rental start, with the
  exact deadline persisted and displayed.
- After start and for renter no-show, no fixed penalty is generated. The final
  rent amount is capped by the stored quote and reduced by saved expenses,
  actual replacement rental and proven lower/absent loss.
- Only authorized actors can submit or resolve evidence; all transitions and
  calculations are server-side, idempotent, append-only and auditable.
- `rent_refund` and `sit_fee_refund` remain separate with the correct debtor;
  no payment execution is implied while payments remain disabled.
- Withdrawal/cancellation receipts preserve exact text, version, time, booking,
  amount basis and hashes and remain authenticated and rediscoverable.
- Existing V5.1 evidence remains intact, V5.2 activation remains false and no
  current draft document is provisioned as approved.
- Focused tests, full local technical regression and GitHub CI are green for the
  bounded implementation commit.

## Expected next transition

GREEN: C1F - V5.2 Handover, Return, Evidence and needsReview.
YELLOW/RED: preserve evidence and stop at the exact authorization, timeline,
amount, legal-version or debtor conflict.
