# S3P moderation Statement of Reasons - technical compliance record

Status: locally verified on 22.08.2026; exact commit and GitHub Actions evidence
are pending.

## Implemented controls

- New significant moderation measures require one versioned Statement of
  Reasons in the same transaction; a deferred PostgreSQL trigger enforces the
  rule independently of application code.
- Facts, basis, reasoning, origin, exact scope, duration and the actual role of
  automated means are bound to the affected user. Fully automated significant
  decisions fail closed.
- The Statement is append-only and records a real Administrator as the human
  issuer/reviewer. Audit metadata omits the sensitive free-text facts.
- Action semantics determine duration. Fixed suspensions require a future end;
  continuing restrictions have no invented end; reversals have no ongoing
  duration.
- The authenticated user view is `private, no-store` and displays only a
  complete, internally consistent Statement. It never fills legacy gaps with
  assumptions.
- The existing free electronic review route is now available from the same
  user surface, remains recipient-bound and rate-limited, and is resolved only
  through an explicit Administrator action.
- Privacy export and the retention inventory include the new dataset. The
  privacy and retention manifests remain draft and fail closed.

## Local verification

- Focused Backend domain/workflow tests: 17 passed. The complete Backend run
  passed 455 tests with the single PostgreSQL-only integration test skipped
  because no local PostgreSQL service was available.
- Focused Flutter and wiring tests: 8 passed. Changed-file analysis reported no
  issues.
- Privacy validator and 17 tests, retention validator and 41 tests, P0B PSP
  validator and 5 tests, and invited-pilot validator and 6 tests passed while
  preserving every HOLD boundary.
- The full local CI-metadata regression passed 358 Flutter tests with one
  documented skip, the separate Google-only test, Web build and loopback smoke,
  and Android debug build. The local run did not claim private historical AAB,
  physical-device or Store proof.
- PostgreSQL migration `044`, complete Backend regression, dependency and
  secret checks, Compose validation and API image build remain pending GitHub
  CI evidence for the exact commit.

## Residual gates

- Independent professional review must confirm applicability, final wording,
  territorial phrasing, review deadlines and any external redress copy.
- Independent review assignment, correction of erroneous decisions, linked
  measure reversal and user-facing review-resolution reasons remain a separate
  package.
- External DSA transparency reporting, public operation, production,
  provider/payment, Store submission, signed release and real money remain
  disabled or unapproved.
