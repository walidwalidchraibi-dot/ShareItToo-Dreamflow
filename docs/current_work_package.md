# Current Work Package: C1H - V5.2 Categories, Moderation, Invoice/Receipt and Operator Configuration

Status: active after green C1G implementation and GitHub CI.

## Objective

Close only the bounded category, private-marketplace, moderation, financial-
document and operator-configuration gaps proven open by C1A while preserving
historic records and keeping unknown legal or provider facts fail-closed:

- make the private-pilot category and subcategory allowlist exclusively
  server-owned and impossible to bypass through catalog reads, listing
  reactivation, quoting or booking creation;
- require persistent account, listing and booking private-status evidence and
  block accounts carrying a server-authoritative commercial-activity review
  indicator until it is resolved;
- complete the user-bound moderation decision and internal-review path with
  facts, contractual/legal basis, detection method, reasoning and deadline;
- lock the already implemented SIT-fee receipt and private-rental summary to
  stored payment, quote and refund snapshots without parallel tax arithmetic;
- centralize operator/provider/legal activation facts so production-facing
  legal and provider surfaces fail closed on missing, placeholder or
  unapproved values;
- add an internal, non-activating professional-review signal at the V5.2
  cumulative platform-fee threshold, without unlocking any feature.

## Baseline and inputs

- Branch: `codex/master-workflow-20260808`; draft PR #7.
- C1G implementation:
  `f2781366a5c0c9f2e2a26401cf862272bc7f1609`; GitHub Actions run
  `32358854576` is green and published no image or signed artifact.
- Drive control `02_CODEX_WORK_PACKAGES_SIT_V2.3.md` maps C1H to categories,
  moderation, invoice/receipt and operator fail-closed configuration.
- V5.2 Core sections 12 and 13 require a server-only category allowlist,
  private status at account/listing/booking, dealer-indicator blocking, DSA-
  capable reports and reasoned decisions, and financially correct documents.
- C1A items 1, 2, 19, 24 and 28 remain the bounded C1H gaps. Items 25 and 26
  are already technically green and must be verified and preserved rather
  than reimplemented without evidence.
- Transport means remain excluded. `cat3` may cover cameras only; drones and
  every vehicle, bicycle, e-bike, e-scooter, trailer, boat, handcart, sack
  truck or other transport means stay unavailable.

## Allowed work

- Define an immutable backend-owned category/subcategory launch allowlist and
  enforce it on public catalog queries, listing create/update/reactivation,
  quotes and booking creation while retaining inaccessible historic data.
- Bind booking eligibility to persistent renter, owner, listing and booking
  private-status declarations, Germany and an explicitly configured approved
  pilot region; absent region facts must fail closed rather than be guessed.
- Add a server-authoritative account review state for commercial/dealer
  indicators. Provide no invented automatic legal threshold; an unresolved
  indicator blocks new listings, quotes and bookings.
- Extend moderation with append-only, user-bound decision receipts and review
  requests. Keep reporter identity, private evidence and unrelated account
  data out of affected-user responses.
- Record moderation facts, rule or legal/contract basis, decision reasoning,
  human/automated detection method, review availability and the approved
  review deadline. Measures must be authoritative on the server, not local UI
  flags only.
- Verify SIT platform-fee receipts and private-rental booking summaries against
  immutable stored payment/quote/refund evidence; add regression coverage for
  unpaid, rejected, expired, refunded and no-fee cases.
- Add one central legal/operator readiness evaluator covering exact registered
  operator identity, address, management, register data, contacts, competent
  authority, withdrawal URL and approved provider facts. Keep all unknown
  values visibly unresolved and non-activating.
- Implement an internal compliance signal when cumulative actually received
  SIT platform fees reach EUR 5,000 and due operating, tax and refund reserves
  are covered. The signal is advisory and cannot activate a service or claim
  professional review completion.
- Add forward-only database migrations, focused tests, static validators and
  regression wiring required for these controls.

## Not allowed in C1H

- No enabling or publishing of a transport, drone or otherwise excluded
  category; no PStTG assumption for ordinary tools or camera rentals.
- No invented pilot region, dealer threshold, registered company, address,
  manager, register court/number, authority, hoster, SMTP, maps, PSP, Firebase,
  DPA, transfer, tax or provider fact.
- No claim that legal review, professional review, provider review, Store
  review or production readiness has completed without the corresponding
  owner or external evidence.
- No rewriting, deleting or silently relabelling historic listings, bookings,
  reports, payments, receipts or moderation events.
- No issuing a SIT receipt for private rent, blanket 19 percent VAT on private
  rent, landlord deduction for renter-paid SIT fees or document generation for
  rejected, expired or unpaid requests.
- No production, VPS/OpenClaw, cloud-console, DNS, live payment, Store,
  signed-release, public-rollout or destructive Git action.

## Acceptance criteria

- Disabled or unapproved categories and subcategories are absent from the
  server catalog and are rejected consistently at every write, reactivation,
  quote and booking boundary. Historic records remain intact but unavailable.
- A booking cannot be quoted or created unless both parties and the listing
  carry current persistent private-status evidence, the listing is in Germany
  and its region is explicitly server-approved. An unresolved commercial-
  activity indicator blocks the flow fail-closed.
- Reporting remains available for listing, profile/user, review and message.
  Every imposed measure has an append-only reasoned decision; the affected
  user can retrieve their receipt and submit one bounded internal-review
  request without learning protected reporter/evidence data.
- Account and content measures are enforced by backend state and are covered
  by authorization, idempotency and audit tests.
- Financial documents use stored authoritative snapshots only, separate SIT
  fee creditor/tax treatment from private rent, and are absent for unpaid or
  otherwise ineligible requests.
- Production-facing legal/operator/provider approval stays false when any
  required value is absent, placeholder-like, inconsistent or not explicitly
  approved. No missing fact is filled from a guess or sample.
- The EUR 5,000 signal uses actually received SIT platform fees and separately
  requires reserve coverage; it creates only an internal review requirement
  and never an activation approval.
- Focused tests, complete local technical regression and GitHub CI are green
  for the bounded implementation commit. External legal/provider evidence and
  physical launch validation remain truthful later gates.

## Expected next transition

GREEN: C1I - V5.2 full QA, physical network/device matrix and launch evidence.
YELLOW/RED: preserve evidence and stop at the exact missing legal, region,
moderation, financial or operator fact without weakening the fail-closed gate.
