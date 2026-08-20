# Current Work Package: FI0 - Founder-Independence Guardrails

Status: active after technically complete C1I readiness audit with release HOLD.

## Objective

Reduce avoidable founder-only operational dependencies without changing the
product roadmap or activating external systems. Audit personal hardcodes and
define narrow role, delegate, audit and runbook standards. Apply code or
documentation guardrails only where the audit proves an in-scope gap.

## Baseline and inputs

- Branch: `codex/master-workflow-20260808`; draft PR #7.
- C1H implementation head:
  `2a67a43ce79da87a127836edfc764079edccbd27`; exact GitHub Actions run
  `32374184599` is green.
- C1I is technically complete with release-readiness HOLD. It created no
  signed candidate and changed no Store, provider, device or production state.
- Drive controls: `01_CONTROL_V2.3_AUTONOMOUS.md` and
  `02_CODEX_WORK_PACKAGES_SIT_V2.3.md`.
- FI0 source of truth: the mapped Founder-Independence and delegation reference
  in the current SIT Drive package. Growth, Business and architecture sources
  are not permission to implement later packages early.

## Allowed work

- Search repository code, configuration templates, CI, operations documents
  and tests for personal names, personal email addresses, personal accounts,
  individual-only approval assumptions, single-person recovery paths and
  founder-bound operational wording.
- Distinguish acceptable protected local ownership from avoidable product or
  operational hardcoding. Never copy protected values into repository files.
- Define stable role names, least-privilege delegate expectations, separation
  of duties, append-only audit expectations, break-glass handling and concise
  runbook ownership.
- Add narrow configuration validation, neutral role constants, documentation
  or tests only where existing touched surfaces need a proven guardrail.
- Keep every unknown owner, delegate, account, provider and legal fact
  unresolved and fail-closed.
- Produce a dated FI0 audit/report with done/open/deferred classifications and
  update current-state/current-package artifacts.

## Not allowed in FI0

- No invasive time tracking, employee monitoring, productivity surveillance or
  collection of personal activity data.
- No creation, deletion, invitation or permission change for GitHub, Google,
  Firebase, Apple, Play, payment, email, DNS, cloud, VPS/OpenClaw, Store or
  provider accounts.
- No password, passkey, 2FA, secret, signing material or recovery-code movement.
- No invented person, delegate, legal representative, mailbox, phone number,
  account owner, company role, approval or escalation route.
- No production, public, live traffic, payment, real-money, signed-candidate,
  Store, SSH, destructive Git or user-data migration action.
- No G2 navigation/cart implementation before FI0 is closed and the exact G2A
  package is opened.

## Acceptance criteria

- Repository personal hardcodes and individual-only operational dependencies
  are inventoried with file-bound evidence and classified as safe-local,
  remediation-needed, external-owner-gate or later-package scope.
- System-facing authorization uses neutral roles/capabilities rather than a
  named person wherever the current repository already exposes that surface.
- Every sensitive operation retains least privilege, traceable actor/action/
  time/result evidence, explicit approval boundaries and a documented recovery
  owner without publishing protected identity data.
- Founder-only steps have a role/delegate/runbook standard or an explicit
  external HOLD; no unavailable delegate is fabricated.
- Tests and validators cover any changed executable guardrail. Full regression
  remains green in proportion to the implementation change.
- No invasive tracking, account/provider mutation, secret movement, signed
  artifact, Store action or live-system change occurs.

## Expected next transition

GREEN: G2A - Navigation and Gemerkt migration, using only its mapped Drive
sources and preserving Bookings icon, profile-image icon, wishlist data and
deep links. YELLOW/RED: preserve the FI0 evidence and stop at the exact owner,
account, secret, legal or external permission gate without guessing.
