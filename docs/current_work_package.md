# Current Work Package: G2L - Legal/Privacy Delta for G2

Status: active after green G2A implementation and exact GitHub CI.

## Objective

Version only the legal/privacy terminology and data-lifecycle contracts that
are affected by the G2 vocabulary and the planned cart topology. Cover
`Gemerkt`, `Mietkorb` and the later `Projektkorb` in export, deletion and
retention before persistent cart work begins. Preserve every historical legal,
consent, quote and evidence snapshot unchanged.

This package is fail-closed: it may bind an inactive future cart data type or
record an open decision, but it must not claim collection, approval, a fixed
retention period or a deletion implementation that does not yet exist.

## Baseline and inputs

- Branch: `codex/master-workflow-20260808`; draft PR #7.
- G2A implementation head:
  `335eb8999d79aa33159ca3c0498d515947040833`; exact GitHub Actions run
  `32380693921` is green and created no signed or published artifact.
- Drive controls: `01_CONTROL_V2.3_AUTONOMOUS.md` and
  `02_CODEX_WORK_PACKAGES_SIT_V2.3.md`.
- Growth terminology source:
  `02_SIT_GROWTH_PRODUCT_PROJEKTKORB_UND_PLANER.pdf`, version 2.0,
  18.08.2026.
- V5.2 Core/Legal Map, current privacy and retention inventories, data export,
  account deletion and exact `sourceInventory` bindings retain higher
  subject-specific authority.
- G2A implementation report:
  `docs/compliance/g2a-navigation-gemerkt-migration-2026-08-20.md`.

## Allowed work

- Audit every current legal/privacy term, manifest, validator, export route,
  account-deletion route and retention contract affected by G2A or required
  before G2B.
- Classify `Gemerkt` as the existing non-binding saved-item state without
  pretending it is a reservation or persistent rental cart.
- Define the later `Mietkorb`/`Projektkorb` data topology only to the minimum
  needed for truthful export, deletion and retention coverage. Mark runtime-
  inactive or unimplemented facts explicitly.
- Version current affected legal/privacy artifacts and refresh exact hashes
  only after the source changes are reviewed. Update every binding for a
  changed `sourceInventory` path.
- Extend validators and focused tests so missing cart export/deletion/retention
  coverage fails closed before G2B can activate persistence.
- Preserve current draft/open/HOLD states and document every unresolved owner,
  legal, processor or retention decision.

## Not allowed in G2L

- No rewrite, deletion or replacement of historical legal, consent, quote,
  contract, privacy, retention or device-evidence snapshots.
- No invented legal basis, retention period, controller/processor role,
  company/operator fact, approval, consent wording or deletion capability.
- No persistent rental/project cart, server schema, cart API, login-return,
  availability/quote recheck, grouped booking, multi-owner or Payment behavior;
  those belong to G2B or later.
- No change to prices, discounts, contract formation, withdrawal,
  cancellation, evidence, moderation, financial documents or release state.
- No productive AI, analytics/ads, new provider traffic or new data collection.
- No production, VPS/OpenClaw, SSH, DNS, cloud-console, payment, Store, signed
  candidate, public rollout, account or destructive Git action.

## Acceptance criteria

- Current public/internal terminology truthfully distinguishes `Gemerkt` from
  a reservation and distinguishes the empty G2A `Mietkorb` shell from the
  inactive persistent cart planned for G2B.
- Existing saved-item metadata and assignments are included in current export,
  deletion and retention reasoning under their real legacy keys.
- The planned rental/project-cart data class cannot become persistent in G2B
  unless export, deletion and retention validators recognize it.
- Runtime-inactive future data is not falsely listed as currently collected;
  open retention/legal decisions remain explicit and fail closed.
- Every changed current artifact has a new version/hash where required, while
  all historical snapshots and their hashes remain byte-identical.
- Privacy, retention, legal and Store validators pass in honest draft mode and
  still reject premature approval or activation.
- Focused lifecycle, hash-drift and negative tests pass; complete regression
  and exact GitHub CI are green.

## Expected next transition

GREEN: G2B - persistent rental cart with login return and server-side
availability/quote recheck. YELLOW/RED: stop before G2B at the exact legal,
privacy, retention, export, deletion or historical-snapshot ambiguity. A
substantive choice not already settled by V5.2/current decisions is a HARD
STOP and must not be guessed.
