# Current Work Package: C1D - V5.2 Checkout, Contract and Declaration Binding

Status: active after green C1C implementation and GitHub CI.

## Objective

Close the V5.2 checkout and platform-contract gaps proven open by
`docs/compliance/c1a-v52-delta-audit-2026-08-20.md`:

- show exactly two non-preselected V5.2 declarations with the exact displayed
  wording and explicit document-version references;
- persist the exact displayed declarations, document versions and immutable
  snapshots before a rental request can be emitted;
- expose ShareItToo's explicit platform-contract acceptance before the owner
  request and retain a durable, authenticated, rediscoverable receipt;
- keep the inactive V5.2 legal bundle and every live boundary fail-closed.

## Baseline and inputs

- Branch: `codex/master-workflow-20260808`; draft PR #7.
- C1C implementation: `a40b999202a762b352a0d5f3a3193fa68df7691e`;
  GitHub Actions run `32344616071` is green.
- Authoritative legal bundle: `assets/legal/de/legal_manifest_v52.json`, version
  `V5.2-2026-08-16`, nine A-I documents, status `draft-blocked`.
- The existing V5.1 workflow already creates a platform contract, two
  append-only declarations, immutable document snapshots and an HTML receipt
  before `booking.requested`; it is the migration baseline, not an authority to
  relabel as V5.2.
- The V5.2 Core specification requires this order: validate user and quote;
  store declarations and document versions immutably; create the platform
  contract; return explicit SIT acceptance; create and log the durable receipt;
  only then emit the owner request or begin an allowed PSP step.

## Allowed work

- Add forward-only schema support required for the nine V5.2 document types and
  their exact contract snapshot associations.
- Add a versioned V5.2 contract workflow, receipt generator and state-order
  tests without rewriting historical V5.1 records or artifacts.
- Bind the checkout to exactly two initially false declarations, the exact
  displayed wording, locale, build, timestamp, hashes and document references.
- Show privacy separately as information, never as an acceptance checkbox.
- Return and retain the explicit SIT acceptance and authenticated receipt
  metadata in the Flutter booking flow; provide a save/share route that fails
  closed on integrity or authorization errors.
- Add focused mutation, authorization, idempotency and event-order tests and
  wire them into the complete technical regression.

## Not allowed in C1D

- No provisioning or activation of the current `draft-blocked` V5.2 bundle.
- No invented public/download URL and no invented company, register, tax,
  provider, transfer, retention, supervisory or professional-review fact.
- No email-delivery success claim without a real, recorded delivery mechanism;
  an authenticated in-app durable receipt may be implemented and described as
  such.
- No additional, combined or preselected declaration and no privacy consent
  checkbox.
- No V5.1 history rewrite, destructive migration, reset, rebase or force-push.
- No production, VPS/OpenClaw, DNS, cloud console, payment, Store, provider,
  real-money, signed-release, public-rollout or live-traffic action.

## Acceptance criteria

- Exactly two declarations are visible and false by default; submit is blocked
  if either is missing, changed, stale or not bound to the current quote.
- The server rejects a wrong version, wording, hash, locale, build, document
  set, snapshot, actor, age/private status, region, category or quote.
- Platform contract ID/time, explicit SIT acceptance, immutable declaration and
  document snapshots, receipt hash/content and delivery event exist before the
  owner request event.
- The Flutter response model retains the platform contract and receipt metadata;
  the acceptance is visible and the receipt remains authenticated and
  rediscoverable from booking details.
- V5.1 evidence remains intact, V5.2 legal activation remains false and no
  current draft document is provisioned as approved.
- Focused tests, full local technical regression and GitHub CI are green for the
  bounded commit.

## Expected next transition

GREEN: C1E - V5.2 Identity and Private-Status Binding.
YELLOW/RED: preserve evidence and stop at the exact declaration, document,
ordering, authorization or legal-fact conflict.
