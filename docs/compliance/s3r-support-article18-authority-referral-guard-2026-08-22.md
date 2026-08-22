# S3R Article 18 authority-referral guard - technical compliance record

Status: locally verified in focused tests on 22.08.2026. Exact-head PostgreSQL
and GitHub Actions verification is pending. This is technical evidence, not a
legal opinion, legal approval or authorization for authority disclosure.

## Implemented controls

- P0 threat/violence and immediate-danger cases are conservative internal
  review candidates; the candidate flag is not a criminal or reporting finding.
- Candidate listing and assessment require an active Administrator plus
  session-bound Staff Step-up. Normal support access fails closed.
- Every assessment records explicit human review with automation role `none`,
  reviewer-authorization evidence and append-only audit truth.
- A reporting-path assessment requires a factual basis, at least one symbolic
  evidence reference, explicit jurisdiction-routing basis and a non-empty
  allowlisted minimum information scope.
- An unknown concerned Member State is represented explicitly and cannot be
  replaced by an invented state. Non-reporting outcomes cannot carry proposed
  disclosure data.
- The application and database reject mutation, deletion, unsafe
  supersession, stale or mismatched Step-up, live-mode candidates, duplicate or
  malformed references and unauthorized roles.
- Events and global audit omit factual narrative and evidence references.
  Restricted assessment evidence is retention-inventoried and excluded from
  automatic self-service export.
- External delivery is false in every record. No adapter exists, and the
  dispatch endpoint remains disabled even for an elevated Administrator.
- Rollback refuses to discard recorded assessment evidence.

## Verification observed so far

- Focused domain, workflow, existing support regression and static-wiring run:
  58 passed, zero failed and zero skipped. The later focused run including the
  privacy and retention bindings passed 71 of 71.
- Backend source syntax and shell syntax checks passed.
- Earlier complete Backend execution with the S3R implementation: 468 total,
  467 passed, zero failed and one expected PostgreSQL skip because no local
  PostgreSQL service is installed.
- The complete local CI-metadata regression passed all fail-closed validators,
  the accepted analyzer baseline, 359 Flutter tests with one documented skip,
  the separate Google-only profile test, Web debug build, loopback smoke and
  Android debug build. No signed candidate, Store upload or publication was
  produced.

## Open legal and operational gates

SIT has no recorded professional conclusion for a real case, named legal/DSA
decision owner, authenticated competent-authority channel, approved disclosure
scope, disclosure log, or final retention/legal-hold policy. Those gates keep
external reporting disabled. The technical path neither determines whether
Article 18 applies nor contacts an authority.

No production, external notification, public pilot, payment, payout, Store,
Cloud/VPS/DNS, signed-release, publication or merge action is included.
