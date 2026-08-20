# Current Work Package: G2A - Navigation and Gemerkt Migration

Status: active after green FI0 implementation and exact GitHub CI.

## Objective

Change only the primary navigation and existing wishlist presentation to the
approved G2 vocabulary:

`Entdecken · Mietkorb · Buchungen · Nachrichten · Mein SIT`

Move the existing heart/wishlist experience into a clearly labelled `Gemerkt`
area under `Mietkorb` without losing data, breaking old routes or implying that
saved items are reserved. Preserve the current Bookings icon, profile-image
navigation affordance, direct single-item rental and all existing C1 rules.

## Baseline and inputs

- Branch: `codex/master-workflow-20260808`; draft PR #7.
- FI0 implementation head:
  `28566f22488adf2047e88e5258f4b8361d2db59c`; exact GitHub Actions run
  `32376912466` is green and created no signed or published artifact.
- Drive controls: `01_CONTROL_V2.3_AUTONOMOUS.md` and
  `02_CODEX_WORK_PACKAGES_SIT_V2.3.md`.
- Mapped Growth source:
  `02_SIT_GROWTH_PRODUCT_PROJEKTKORB_UND_PLANER.pdf`, version 2.0,
  18.08.2026. V5.2 price, contract, booking, privacy and release rules retain
  higher subject-specific authority.
- Existing wishlist persistence, route/deep-link handling, bottom navigation,
  Bookings icon and profile-image icon must be audited before editing.

## Allowed work

- Inspect current navigation destinations, selected-index behavior, back-stack,
  guest/auth gates, old wishlist entry points, persisted wishlist keys and
  supported app/deep links.
- Rename and reorder the five primary destinations exactly as approved.
- Add a bounded `Mietkorb` navigation shell that can expose existing `Gemerkt`
  content while truthfully keeping cart/reservation behavior unavailable until
  G2B.
- Migrate or alias existing wishlist state non-destructively so current saved
  items remain available after update and rollback.
- Preserve old wishlist/favorites routes through a compatibility redirect or
  equivalent tested route mapping.
- Preserve direct search, single-item listing and booking flows.
- Add focused widget, persistence, migration, route and accessibility tests.

## Not allowed in G2A

- No server-persistent rental/project cart, cart availability checks, project
  containers, multi-item request, partial offer, multi-owner checkout or grouped
  payment/ledger behavior; those belong to G2B or later.
- No legal/privacy text, version, hash, export, deletion or retention change;
  the required terminology/data delta belongs to G2L after G2A.
- No SIT Planer, productive external AI, project recommendation, ranking,
  project analytics or marketing/advertising analytics.
- No change to quote arithmetic, discounts, contracts, declarations, checkout,
  booking lifecycle, handover/return evidence, moderation or financial
  documents.
- No silent deletion, overwrite or relabelling of saved user data.
- No production, provider, account, cloud, payment, Store, signed-candidate,
  public rollout, SSH or destructive Git action.

## Acceptance criteria

- Primary navigation renders exactly five destinations in this order:
  `Entdecken`, `Mietkorb`, `Buchungen`, `Nachrichten`, `Mein SIT`.
- The established Bookings icon remains the Bookings icon. `Mein SIT` retains
  the profile-image affordance rather than regressing to an unrelated generic
  icon.
- Every existing saved/wishlist item survives migration and remains removable
  and reachable under `Mietkorb` > `Gemerkt`.
- `Gemerkt` visibly states that saving is non-binding and not a reservation.
  G2A introduces no false cart, availability or booking guarantee.
- Old supported wishlist/favorites routes and deep links reach the new
  `Gemerkt` destination without loops or data loss.
- Guest/auth behavior, selected-tab restoration, back navigation, direct
  single-item rental and all C1 contracts remain unchanged.
- Focused navigation, persistence/migration, deep-link and accessibility tests
  pass; complete regression and exact GitHub CI are green.

## Expected next transition

GREEN: G2L - legal/privacy delta for the changed G2 terminology and data
topology before persistent cart work. YELLOW/RED: preserve the old wishlist
data and stop at the exact migration, route, accessibility or legal ambiguity
without guessing or proceeding to G2B.
