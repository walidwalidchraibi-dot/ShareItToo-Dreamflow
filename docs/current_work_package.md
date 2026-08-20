# Current Work Package: C1A - V5.2 Delta Audit

Status: active after the green R1 guidance commit.

## Objective

Compare the verified R0 baseline and current implementation against the two
authoritative V5.2 documents in the Drive folder `10_C1_V5.2_AFTER_CUTOVER`.
Produce a read-only `done / open / obsolete / conflict` matrix before any C1
product implementation.

## Baseline and inputs

- Branch: `codex/master-workflow-20260808`; draft PR #7.
- Verified R0 product baseline: `df62700a4ead526abc5d84edb0139f17fb0c21bc`.
- Local authority: `AGENTS.md`, `docs/current_state.md`, current code, tests,
  migrations and validated manifests.
- Drive authority: V2.3 control/work-package documents plus V5.2 Core and V5.2
  Legal Map. Treat V5.2 as a specification to audit, not as a one-shot command.

## Allowed work

- Read code, tests, migrations, manifests and mapped Drive specifications.
- Run non-mutating searches and focused validation needed to prove status.
- Write a sanitized C1A audit artifact and update this handover after the audit.

## Not allowed in C1A

- No product behavior, schema, legal text, manifest approval or release change.
- No production, VPS/OpenClaw, DNS, cloud, payment, Store, provider or live
  traffic action.
- No signed candidate, deployment, public rollout or destructive Git action.

## Acceptance criteria

- Every material V5.2 requirement is classified as done, open, obsolete or
  conflict with repository evidence.
- Dependencies and the smallest safe order for proven-open C1B-C1I slices are
  explicit.
- Unresolved legal/product conflicts become a hard stop; no silent assumption.
- If no conflict exists, continue only into the C1 slices proven open by the
  audit, in dependency order.

## Expected next transition

GREEN: implement only proven-open C1B-C1I slices. YELLOW/RED: preserve the audit
and stop at the specific legal/product/account gate.
