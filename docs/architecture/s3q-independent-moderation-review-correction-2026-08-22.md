# S3Q independent moderation review and correction - architecture

Status: implemented and locally verified for non-live operation on 22.08.2026.
Exact implementation commit and GitHub PostgreSQL evidence are pending. No
production, external delivery or public or invited pilot operation is enabled.

## Source basis

- Drive `13_SIT_SUPPORT_TEST_MATRIX_V1.md`, ID
  `1CcCqdsEVveiqoKJqZlA_iHKfZhttU5Le`, scenarios `SUP-119` and `SUP-120`.
- Drive `07_TRUST_SAFETY_MODERATION_PRIVACY_LEGAL`, ID
  `1fxfhV8aBH2MKrqfnudY6_mKeC5P1HPDXac41c0KZpu4`, checked on
  22.08.2026.
- S3P Statement-of-Reasons boundary in migration `044` and
  `docs/architecture/s3p-moderation-statement-of-reasons-2026-08-22.md`.

## Review assignment and evidence model

Migration `045` adds one append-only `moderation_review_resolutions` row per
review request. A review may move from submitted to in-review only when an
active Administrator other than the original decision issuer claims it. The
claim is session-step-up protected, idempotent and bound to the exact request.

The resolution records the human reviewer, verified independence, an explicit
`none` automation role, one of `upheld`, `modified` or `reversed`, the exact
user-facing reason, whether the measure changed, any linked correction
decision and communication time. PostgreSQL independently guards assignment,
state transitions, correction-decision identity and append-only history. A
terminal review without matching resolution evidence fails closed.

## Correction transaction

The assigned reviewer resolves the review and, when required, applies the
correction inside the same database transaction. `upheld` forbids a correction.
`modified` and `reversed` require a successfully applied, human-only correction
and a new S3P-complete moderation decision and Statement of Reasons.

The correction adapter reuses the existing guarded moderation workflows:

- a listing restriction may be modified between `hidden` and `removed`, or
  reversed to `active`;
- a private-marketplace restriction may be modified between
  `review_required` and `blocked`, or reversed to `clear`;
- an active account or scope suspension may be reversed by lifting it.

Every adapter locks and verifies the exact current measure state before acting.
A concurrent or already-changed measure fails closed. Modification of a
suspension and correction of a report-resolution record are not implemented;
those reviews can be upheld, while unsafe correction attempts are rejected.

## Staff and user surfaces

The review queue, claim and resolution endpoints require an authenticated,
active Administrator plus Staff Step-up. The original issuer cannot claim or
resolve their own review. The Flutter admin surface presents the original
decision evidence and explicit uphold, modify and reverse actions; no worker or
classifier can select an outcome.

The affected user's authenticated `private, no-store` decision stream exposes
only complete resolution evidence. It shows the independent human-review result,
exact reason and whether a correction was implemented, without disclosing the
reviewer's identity. Missing or inconsistent terminal evidence is not rendered
as a successful review.

## Decision boundary and exclusions

This package provides the technical workflow for the S3P review route. It does
not establish legal correctness, activate a moderation team, decide content
illegality, send email or push, publish an external transparency report, repair
legacy records, or execute unsupported correction types.

No production service, Cloud/VPS/DNS, payment, payout, Store, real-money,
signed-release or public-pilot state changes.
