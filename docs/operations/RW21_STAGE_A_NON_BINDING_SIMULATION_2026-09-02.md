# RW21 Stage-A non-binding simulation

Status: **IMPLEMENTED AND LOCALLY VERIFIED / STAGING DEPLOYMENT PENDING** on
02.09.2026.

## Purpose

The closed Heilbronn Stage-A pilot can exercise two real Staging accounts,
listing discovery, a renter request, owner acceptance, shared chat and
transactional in-app/push notification creation without representing a legal
booking. The simulation creates no platform contract, reservation, payment,
payout, refund, dispute, receipt, handover, return, damage or review effect.

The mode is derived rather than independently switchable. It exists only when
the backend is in `staging` or `test`, the booking mode is `pilot`, and the
private pilot is enabled. Production cannot enable it through an additional
environment flag.

## Fail-closed controls

- The client requires an explicit simulation acknowledgement and labels the
  renter and owner surfaces as an unverbindliche Pilot-Simulation.
- The server stores `simulation_only` as first-class booking truth, excludes
  simulations from availability and permits only request acceptance,
  rejection or cancellation.
- Contract, payment and legal-declaration creation are skipped. Payment reads
  and checkout creation reject simulation bookings.
- PostgreSQL independently rejects simulation-booking rows in every financial,
  contract, refund, dispute, deposit and actual-loss table.
- Simulation notifications are visibly labelled and never enter the email
  channel. They may use only in-app delivery and the separately gated
  transactional push path.
- Accepted simulations expose chat but not handover, return, payment, receipt
  or review actions.

## Verification

- Node tool inventory: 2,027 passed, 0 failed.
- Backend unit suite: 756 passed, 0 failed, 2 documented skips; syntax checks
  passed.
- Local PostgreSQL integration: passed and cleaned, including migration 070
  and the independent database side-effect guard.
- Flutter suite: 635 passed, 0 failed, 3 documented skips.
- Flutter analyzer: 0 issues.
- Focused Stage-A checkout, server-boundary and remote-runner tests passed.

The complete release regression is intentionally not yet claimable for the
old `2026090204` artifact: runtime-affecting files changed after that
candidate's source commit. A new candidate must be cut only after Staging
deployment and remote role-flow verification.

## Deployment, device and external boundaries

No Staging deployment, Store upload, tester-list change, Firebase change,
payment activation, Production action or device installation is part of this
implementation checkpoint. Subsequent physical validation is Pixel-only;
OnePlus is explicitly outside this package.

Staging must apply migration 070 and deploy the exact committed backend before
the private synthetic runner is executed. The runner reads credentials only
from the owner-only vault outside Git, returns sanitized booleans, and proves
requested-to-accepted visibility, unaffected availability, payment rejection,
shared chat and in-app notifications.

## Rollback and next gate

Code rollback is the normal forward Git revert. The migration down script
removes the simulation triggers, function, index and column; it must not be run
while simulation rows exist without an explicit data-preservation decision.

Next: commit and push this implementation, obtain exact-SHA Regression and
CodeQL, deploy the same backend to Staging, run the sanitized two-role E2E, then
cut a strictly newer Internal/Staging candidate for the Pixel. Real contracts,
real money, public rollout and unreviewed V5.2 legal assets remain closed.
