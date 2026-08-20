# Current Work Package: G2B - Persistent Rental Cart

Status: active after green G2L implementation and exact GitHub CI.

## Objective

Implement the bounded persistent `Mietkorb` foundation: account-bound rental
cart and project containers, local guest preparation with return after
login/registration, and server-side availability plus quote recheck. A cart is
always an unverbindliche Absicht and never a reservation. Direct single-item
rental and every existing V5.2 price, contract, checkout, booking and Payment
gate remain authoritative.

G2B is an orchestration layer. It may prepare or revalidate selections, but it
must not invent inventory, price, availability, acceptance, booking,
reservation or payment state.

## Baseline and inputs

- Branch: `codex/master-workflow-20260808`; draft PR #7.
- G2L implementation head:
  `b84787e630a96de632eee90e8c7e016a078fcaef`; exact GitHub Actions run
  `32383235202` is green and created no signed or published artifact.
- Drive controls: `01_CONTROL_V2.3_AUTONOMOUS.md` and
  `02_CODEX_WORK_PACKAGES_SIT_V2.3.md`.
- Product source:
  `02_SIT_GROWTH_PRODUCT_PROJEKTKORB_UND_PLANER.pdf`, version 2.0,
  18.08.2026.
- V5.2 Core/Legal Map, deterministic server quote, booking state machine,
  privacy/retention contracts and Store/release gates retain higher
  subject-specific authority.
- G2L lifecycle contract: `store/g2-data-lifecycle.json`.
- G2L implementation report:
  `docs/compliance/g2l-g2-data-lifecycle-2026-08-20.md`.

## Required behavior

- `Mietkorb` contains individual rental selections, project containers and
  the existing separate `Gemerkt` view.
- Authenticated carts are account-bound and can be restored on another device.
- A guest can prepare a bounded cart locally. Login or registration returns to
  the cart and reconciles the guest selection without silently discarding an
  existing account cart.
- Project container identity, selected listings, date/time inputs and
  project-linked selection state survive app/device changes where applicable.
- Cart status is visibly `Im Mietkorb - noch nicht reserviert`; other users may
  still book an item.
- Stored price information is labelled informative. Before a cart can enter an
  existing request/checkout path, the backend rechecks the current listing,
  category, time range, conflicts and deterministic server quote.
- An unavailable or changed line is surfaced explicitly. A changed quote must
  be actively accepted through the existing V5.2 declarations/checkout rules;
  no silent price or content acceptance.
- Existing direct single-item rental remains available and behaviorally
  unchanged.

## Data and lifecycle requirements

- Use an explicit versioned cart/project schema with deterministic ownership,
  ordering and idempotent mutations.
- Preserve all G2A legacy `Gemerkt` keys and values; do not reinterpret them as
  cart reservations or migrate them destructively.
- Extend account export, confirmed deletion, retention inventory and their
  exact source hashes for every newly active cart/project dataset before
  activation.
- Guest data remains local and data-minimal until authentication; authenticated
  sync is server-authoritative and scoped to the current account.
- Do not store raw secrets, payment credentials, legal acceptance substitutes,
  chat text, exact analytics free text or unrelated personal data in carts.
- Database migrations must be forward-only, narrowly scoped and reversible by
  a documented non-destructive follow-up; no destructive cleanup or history
  rewrite.

## Not allowed in G2B

- No reservation merely by adding to cart and no client-authoritative price,
  availability, category or conflict decision.
- No new contract state, legal declaration, consent, retention period,
  discount, fee, refund, cancellation, no-show or damage rule.
- No real money, Payment activation, deposit, protection/insurance or grouped
  multi-recipient checkout.
- No automatic multi-owner request, grouped booking lifecycle, partial-offer
  workflow, payout aggregation, SIT Planer, external AI or new analytics
  provider; those require later bounded packages.
- No rewrite of historical legal, quote, consent, contract, device or release
  evidence.
- No production, VPS/OpenClaw, Maximus, SSH, DNS, cloud-console, provider,
  account, Store, signed candidate, public rollout, PR merge or destructive Git
  action.

## Acceptance criteria

- Persistent account cart/project containers restore exactly and remain
  explicitly non-reserving.
- Guest preparation returns through login/registration and reconciles without
  silent loss or cross-account leakage.
- Server recheck returns explicit current/unavailable/changed outcomes and an
  exact deterministic quote binding before existing request/checkout work.
- Concurrent availability changes cannot create a false reservation or bypass
  the existing booking-conflict guard.
- Export, confirmed deletion and retention cover every active new dataset;
  Privacy/Legal/Store states remain honest draft/open where unresolved.
- Legacy `Gemerkt`, direct single-item rental, deep links, navigation and
  existing V5.2 booking/checkout behavior stay regression-covered.
- Focused backend, migration, Flutter, lifecycle, negative and concurrency
  tests pass; complete local regression and exact GitHub CI are green.

## Expected next transition

GREEN: U0 - pilot cockpit and unit economics. YELLOW/RED: stop at the exact
data-loss, account-isolation, availability, quote, legal/privacy/retention or
existing-booking ambiguity. No live system is needed to complete G2B.
