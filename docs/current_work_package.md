# Current Work Package: C1F - V5.2 Handover, Return, Evidence and needsReview

Status: active after green C1E implementation and GitHub CI.

## Objective

Migrate the existing handover, return, private condition-evidence and return-case
foundation to the exact V5.2 contract and authorization boundaries without
activating payments or the draft legal bundle:

- bind pickup/return evidence and counterparty confirmation to the exact V5.2
  platform contract, quote and `handover_return_damage` document snapshot;
- preserve four current presenter photos, the correct presenter/counterparty
  roles, counterparty confirmation or at least one deviation photo, QR or
  six-digit fallback and the prohibition on self-confirmation;
- make T0, the 48-hour report window, the neutral T0+5-day missing-confirmation
  window and T1 case deadlines server-owned and immutable;
- replace the remaining client-writable `needsReview` opening path with an
  owned, private-evidence-bound, idempotent server workflow;
- keep alleged physical damage documentary only and release the undisputed
  authorized booking portion without creating a charge, offset or deposit.

## Baseline and inputs

- Branch: `codex/master-workflow-20260808`; draft PR #7.
- C1E implementation: `52f2ed7a301d84a9855a2a152b46b824f16264fb`;
  GitHub Actions run `32351561805` is green.
- Drive control `02_CODEX_WORK_PACKAGES_SIT_V2.3.md` maps C1F specifically to
  handover, return, evidence and `needsReview`.
- V5.2 Core sections 8 and 9 and the corresponding user-facing legal-map parts
  require the exact four-photo roles, counterparty verification, private
  evidence and the T0/T1 timeline.
- Existing foundations include migration 019,
  `backend/src/booking_condition_evidence_workflow.js`,
  `backend/src/booking_confirmation_workflow.js`,
  `backend/src/private_pilot_return_domain.js` and
  `backend/src/return_lifecycle_workflow.js`.
- C1A marks the basic photo and return-timeline behavior done, but explicitly
  requires V5.2 version migration and missing boundary/authorization tests.
- The pre-implementation audit found one material open boundary: the legacy
  rental-request metadata path can still request `needsReview` with
  client-provided evidence references and a client-provided contested amount,
  and it checks the end but not the beginning of the T0-to-T0+48h window.

## Allowed work

- Add only forward, append-only schema/events required to bind V5.2 condition
  evidence, confirmation and return cases to contract/document/quote/upload
  facts while preserving all V5.1 rows.
- Require owned, private, server-processed image uploads with stored SHA-256 and
  the exact handover/return/report purpose before evidence or a substantiated
  case is accepted.
- Enforce pickup presenter `owner`, pickup verifier `renter`, return presenter
  `renter` and return verifier `owner`; no actor may confirm their own challenge.
- Preserve at least four presenter images for overall view, detail, accessories
  and a critical condition point. A deviation decision requires at least one
  counterparty photo; a clean confirmation cannot silently coexist with a
  deviation photo.
- Bind QR and six-digit verification to one booking, segment, presenter,
  counterparty, challenge lifetime and exact evidence set, with bounded retries
  and idempotent replay.
- Derive T0 from mutually confirmed actual return, otherwise mutually confirmed
  changed return, otherwise the stored scheduled return. Reject return-case
  opening before T0 or after T0+48 hours.
- Keep missing confirmation neutral as `awaitingReturnConfirmation` until
  T0+5 calendar days. An incomplete report may request completion but cannot
  create `needsReview` or extend the payout timeline by itself.
- For a substantiated case, persist T1, exact reason, owned evidence, the
  already-authorized contested amount, undisputed releasable amount, T1+5
  response deadline and T1+7/weekly status schedule.
- Add focused role, ownership, hash, mutation, idempotency, early/late boundary,
  neutral-state, amount-cap, no-charge and event-order tests and wire them into
  the complete technical regression.

## Not allowed in C1F

- No new client-authoritative booking status, case status, amount, deadline or
  evidence reference.
- No damage award, automatic damage charge, damage offset, security deposit,
  protection product, guarantee, SIT collection or legal adjudication.
- No actual payout, refund, capture, transfer, chargeback or other PSP action;
  only truthful local authorization splits and instructions may be recorded.
- No provisioning or activation of the `draft-blocked` V5.2 legal bundle and no
  invented legal, provider, delivery or public-URL fact.
- No destructive migration, V5.1 history rewrite, reset, rebase, force-push or
  branch deletion.
- No production, VPS/OpenClaw, DNS, cloud console, payment, Store, provider,
  signed-release, public-rollout or live-traffic action.

## Acceptance criteria

- Every new V5.2 pickup/return evidence item and confirmation is bound to the
  exact booking participant, platform contract, quote, V5.2 document snapshot,
  upload purpose/content hash, source and timestamp.
- Presenter and verifier roles are exact for both segments; four presenter
  photos are mandatory, deviation requires a counterparty photo, and neither
  QR nor fallback code permits self-confirmation or cross-booking reuse.
- Historical V5.1 evidence remains readable and immutable; no existing row or
  hash is relabeled as V5.2.
- T0 precedence is exact. `needsReview` is impossible before T0, after T0+48h,
  for only a missing confirmation or from incomplete/unowned evidence.
- Missing confirmation remains neutral until T0+5 days and then advances
  without automatically inventing a dispute.
- A substantiated T1 case records the reason, exact already-authorized contested
  amount, zero additional charge, undisputed releasable amount, response
  deadline and recurring status schedule server-side and append-only.
- Direct legacy metadata attempts to create or alter a V5.2 return case fail
  closed and point callers to the authorized workflow.
- Account export, privacy inventory and retention inventory cover every new
  evidence, case and event dataset without changing draft/approval state.
- Existing V5.1 behavior stays green; focused tests, full local technical
  regression and GitHub CI are green for the bounded implementation commit.

## Expected next transition

GREEN: C1G - V5.2 Privacy, Network, FCM and Crashlytics.
YELLOW/RED: preserve evidence and stop at the exact contract binding,
authorization, timeline, amount, privacy or payment conflict.
