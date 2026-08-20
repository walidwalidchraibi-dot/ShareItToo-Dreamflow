# Current Work Package: U0 - Pilot Cockpit and Unit Economics

Status: active after green G2B implementation and exact GitHub CI.

## Objective

Build the bounded, internal and read-only pilot-cockpit foundation that makes
SIT economics and founder dependence measurable without inventing live data.
The cockpit must keep cash reality separate from normalized economics and must
label every value by evidence class: `actual`, `configured`, `estimated` or
`unavailable`.

U0 is an evidence and reporting package. It may derive aggregates from
existing repository/database facts and explicit input assumptions, but it
must not activate payments, KYC, fraud providers, analytics, cloud services,
marketing, production access or invasive time tracking.

## Baseline and inputs

- Branch: `codex/master-workflow-20260808`; draft PR #7.
- G2B implementation head:
  `c14dacb8a99669724839d07c41c2dbf6b0b497b5`; exact GitHub Actions run
  `32388755772` is green and created no signed or published artifact.
- Drive controls: `01_CONTROL_V2.3_AUTONOMOUS.md` and
  `02_CODEX_WORK_PACKAGES_SIT_V2.3.md`.
- Drive Founder-Independence source:
  `03_SIT_FOUNDER_INDEPENDENCE_UND_DELEGATION.pdf`, version 18.08.2026.
- FI0 contracts under `ops/founder-independence/` remain authoritative for
  roles, critical-process ownership, aggregate founder-hours categories and
  escalation routing.
- Existing booking quote, payment ledger, payout, refund, financial-document,
  project-cart, audit and retention schemas are the only runtime facts U0 may
  treat as actual.

## Required behavior

- Provide an internal, role-protected read-only cockpit snapshot with an
  explicit period and generation timestamp.
- Show cash and normalized P&L separately. Cash must not include unpaid,
  failed, merely authorized or hypothetical amounts.
- Show GMV, platform revenue, the VAT component, captured/refunded/provider
  fee flows and contribution margin per booking and per completed handover
  where the source facts exist.
- Represent KYC, fraud, cloud, AI and marketing cost classes even when their
  current state is zero, disabled, estimated or unavailable. Do not silently
  collapse `unavailable` into zero.
- Show the bounded project funnel from existing non-reserving cart/project
  intent through quote/recheck and existing booking lifecycle milestones.
- Show aggregate founder hours by strategy, operations, support, technical and
  emergency categories, plus aggregate escalations and their routing quality.
  No automatic screen, keyboard, app, message or activity monitoring.
- Expose the normalized founder-labor replacement cost as an explicit
  assumption, never as an actual cash expense unless supported by a real
  ledger record.
- Never label SIT profitable when normalized contribution after the configured
  founder replacement cost is negative or unavailable.

## Metric and provenance requirements

- Every monetary value uses integer minor units plus an ISO currency. Mixed
  currencies are not summed without an explicit, separately authorized FX
  source; U0 may instead return per-currency buckets.
- Every metric carries source/provenance, evidence class and completeness.
- Revenue, VAT and provider-fee calculations must be tied to existing
  immutable quote/payment/financial-document truth; no tax rate or provider
  price may be invented.
- Estimates and configured assumptions must be separately listed so changing
  one cannot rewrite actual historical results.
- Missing live/provider facts must remain visible as `unavailable` and keep
  normalized profitability `undetermined` where material.
- The cockpit must not expose user identity, chat text, precise locations,
  payment credentials, secrets, raw evidence photos or unrelated personal
  data. Counts and financial aggregates are sufficient.
- Queries must be bounded, read-only and suitable for later management
  handover. No purge, reconciliation, payout, refund or booking mutation is
  permitted.

## Not allowed in U0

- No production/VPS/OpenClaw/Maximus/SSH/DNS/cloud-console access or mutation.
- No real payment, payout, refund, KYC, fraud, email, SMS, push, provider or
  analytics traffic.
- No new legal/tax conclusion, VAT rate, cost estimate, founder wage,
  profitability claim or business-model decision without an explicit source.
- No automated founder surveillance, detailed personal activity log or
  employee-style monitoring.
- No public/admin production UI, Store action, signed candidate, deployment,
  PR merge or public rollout.
- No G3A/grouped booking, G4, G5, P0, A0, AI, SIT Business or global work.

## Acceptance criteria

- A deterministic snapshot schema distinguishes actual/configured/estimated/
  unavailable values and cash/normalized views.
- Focused fixtures prove correct cent arithmetic, refunds, VAT components,
  provider costs, per-booking/per-handover contribution and per-currency
  separation without double counting.
- Disabled or missing KYC/fraud/cloud/AI/marketing sources remain explicit and
  cannot generate a false zero-cost or profitability claim.
- Project-funnel and founder-independence aggregates are bounded,
  privacy-minimal and fail closed on invalid inputs.
- Role/access tests prove the cockpit is read-only and limited to the existing
  appropriate internal role set.
- Documentation defines formulas, provenance, current unavailable inputs,
  rollback and the future path to actual pilot evidence.
- Focused backend/tool tests, complete local regression and exact GitHub CI are
  green. No live system is required.

## Required final gate

U0 is the end of the current autonomous runway. After a green U0 report and
exact CI, do not start G3A or any later package. Preserve the clean branch and
send the concise Maximus/Telegram completion gate requesting Walid's decision
on G3A timing and scope. Do not modify Maximus or treat the alert route as a
SIT runtime dependency.
