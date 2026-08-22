# Technical debt required before release readiness

Status: open, non-live register created on 22.08.2026.

This register prevents local test accommodations from becoming permanent
product or release prerequisites. None of the entries changes production,
Payment, Store, Cloud/VPS/DNS or pilot state. Release readiness must not be
claimed until every item below has reproducible evidence and is closed.

| ID | Current observation / temporary accommodation | Required deterministic exit evidence |
| --- | --- | --- |
| `TD-RR-001` | Backend module loading now has repository-owned non-secret test defaults, but local verification still prepends a temporary signed Node-compatible runtime; `pnpm` is not available as a normal shell command. | A clean documented Mac setup and CI both resolve the pinned Node and pnpm versions without a copied temp runtime; `pnpm install --frozen-lockfile`, Backend tests, syntax checks and secret scan pass from a fresh shell. |
| `TD-RR-002` | S4N added repository-owned fresh limiter stores and twice-repeated real 10/30/240 threshold tests with one fixed source. The historical monolithic PostgreSQL HTTP integration still gives some auth/recovery scenarios distinct reserved test IPs. | Remove every request-source accommodation from the monolithic integration, run two complete clean regressions without rotation/reset/wait, and retain green exact-commit CI together with the isolated threshold proof. |
| `TD-RR-003` | The serial default was removed in S4L and two complete local standard-parallel runs passed, but exact-commit CI and a retained repeated stress result are still missing. | Remove timer/animation leakage, run the complete suite repeatedly at the standard supported parallelism, and retain a stress result with zero flakes in local and CI evidence; concurrency one must no longer be required for a green result. |
| `TD-RR-004` | Local PostgreSQL verification is assembled manually with a temporary data directory and selected loopback port. | Add a version-pinned, repository-owned local integration runner using an available loopback port, readiness probe, isolated database and guaranteed trap/finally cleanup; two consecutive clean-machine runs must pass without manual intervention. |
| `TD-RR-005` | Validator tests left 3,728 `sit-*` temp fixtures (about 2.84 GiB), eventually causing `ENOSPC`; manual removal was required. | Every fixture uses scoped temp roots and cleanup in success/failure paths. Run the complete technical regression twice and prove bounded disk delta with no orphaned `sit-*` fixture directories. |
| `TD-RR-006` | The reset-token clock-boundary defect exposed by PostgreSQL used transaction time for `created_at` and a later process clock for `expires_at`. The product fix now supplies one timestamp and has focused coverage. | Keep the exact-lifetime unit test and run migration/API integration repeatedly on PostgreSQL 16. Release evidence must show no boundary flake and retain the database 30-minute upper-bound constraint. |

## Observation log

- 22.08.2026, S4H: extending the already large PostgreSQL HTTP integration with
  more authenticated requests exhausted its shared general rate-limit bucket
  before the final compliance-page assertion. No new IP rotation, limiter
  bypass or increased production limit was introduced. The new S4H state
  transitions were moved to direct transactional workflow integration against
  PostgreSQL; the unchanged canonical HTTP integration and complete technical
  regression then passed. `TD-RR-002` remains open until isolated application
  and limiter tests pass repeatedly without request-source manipulation.
- 22.08.2026, S4H: PostgreSQL 16 verification again required a manually created
  scoped data directory and loopback port. Successful cleanup is operational
  hygiene, not deterministic runner evidence; `TD-RR-004` remains open.
- 22.08.2026, S4I: the standard HTTP integration passed after adding the two
  content-guard requests without another limiter exemption, changed limit or
  new request-source rotation. This is positive package evidence but does not
  close `TD-RR-002`; the suite still needs repository-owned isolated limiter
  state and separate repeatable threshold tests. The fresh PostgreSQL 16
  instance was again started manually, so `TD-RR-004` also remains open.
- 22.08.2026, S4J: the first integration run reproduced `TD-RR-002`: six new
  harassment endpoint requests consumed the monolithic application's remaining
  general-limit budget and a later unchanged compliance request received 429.
  No wait, IP rotation, bypass or increased general limit was accepted. The S4J
  HTTP scenario now owns a fresh application/limiter instance while continuing
  against the same isolated PostgreSQL transaction fixture; the canonical
  integration then passed twice consecutively from fresh databases. This is
  deterministic scenario isolation, but
  `TD-RR-002` remains open until the whole monolith is split and real thresholds
  pass separately and repeatedly.
- 22.08.2026, S4J: the focused Flutter check still used concurrency one and the
  PostgreSQL instance still required manual lifecycle commands. These runs do
  not close `TD-RR-003` or `TD-RR-004`; neither accommodation may be part of the
  release-ready path.
- 22.08.2026, S4K: the first PostgreSQL address-window run exposed a real
  timezone defect: the JavaScript PostgreSQL client represented SQL `DATE`
  values as instants and the local timezone shifted the policy date backward.
  The product query now reads those values explicitly as calendar-date text;
  focused and fresh PostgreSQL tests cover the booking-local-date comparison.
  This is a source fix, not a timing workaround.
- 22.08.2026, S4K: the final full gate passed without sleeps, limiter changes,
  request-source rotation or clock-bound waiting. The exact boundary tests use
  injected clocks and the integration uses database-checked appointment truth.
  Temporary database/log fixtures were stopped and moved to Trash. Manual
  PostgreSQL setup, temporary Node resolution, Flutter concurrency one and the
  required two-run bounded-disk proof remain open under `TD-RR-001`,
  `TD-RR-003`, `TD-RR-004` and `TD-RR-005`; this successful package does not
  close them.
- 22.08.2026, S4L: adding the specialized endpoint late in the monolithic
  PostgreSQL HTTP sequence consumed the shared safety-intake test bucket and
  returned `429`. No wait, IP rotation, limiter reset/bypass or higher product
  limit was accepted. Authenticated route/limiter wiring and transactional
  PostgreSQL workflow/database truth are tested separately. `TD-RR-002`
  remains open until isolated real-threshold tests pass repeatedly.
- 22.08.2026, S4L: the technical runner's implicit concurrency-one default was
  removed. Two consecutive complete Flutter runs passed at standard
  parallelism with 376 passes and one documented skip each. This is positive
  local evidence, but `TD-RR-003` remains open pending retained stress evidence
  and green CI on the exact commit.
- 22.08.2026, S4L: Backend tests now load repository-owned non-secret defaults
  for otherwise required unit-test configuration without overriding CI or an
  explicit integration environment. The full default package command passed
  with 568 tests and one expected no-database skip. Temporary Node resolution
  and unavailable shell `pnpm` still keep `TD-RR-001` open.
- 22.08.2026, S4L: the final PostgreSQL 16 integration passed all migrations
  through `062`, all three handover exceptions, forged-audit rejection and
  rollback refusal. Its lifecycle was still manually orchestrated, so
  `TD-RR-004` remains open.
- 22.08.2026, S4M: spring and autumn DST, the inclusive 48-hour boundary and
  seven-calendar-day recurrence are covered by injected fixed instants in both
  server and client policy tests. The complete Flutter suite passed at standard
  parallelism with 379 passes and one documented skip. No sleep, clock-bound
  retry, concurrency override, limiter change or IP rotation was introduced.
  This is further local evidence for `TD-RR-003`, not closure without retained
  stress evidence and exact-commit CI.
- 22.08.2026, S4M: fresh PostgreSQL 16 applied migration `063` and verified the
  versioned calendar constraints. The database lifecycle was still assembled
  manually and local Backend checks still used the temporary Node runtime, so
  `TD-RR-004` and `TD-RR-001` remain open. The temporary database was stopped
  and moved to Trash; neither accommodation is a release prerequisite.
- 22.08.2026, S4N: a dedicated Safety bucket alone was proven insufficient
  because the preceding general bucket could still starve urgent intake. The
  source fix allows only exact protected Safety and handover-exception requests
  to skip that bucket while a dedicated 30-attempt limiter still runs before
  auth/database work. Exact 10/30/240 loopback boundaries passed twice with one
  fixed source and fresh application instances, with no sleep, reset, IP
  rotation or production-limit change. This closes the isolated-policy part of
  `TD-RR-002`; the item remains open until the historical monolithic fixture is
  free of request-source accommodations and exact-commit CI is green.
- 22.08.2026, S4N: the complete Flutter suite again passed at standard
  parallelism with 379 passes and one documented skip. Two fresh PostgreSQL 16
  integrations also passed, but their lifecycle was still manual. These are
  positive local results for `TD-RR-003` and `TD-RR-004`, not closure evidence.

## Closure rule

Each item closes only through a separate bounded implementation with committed
tests, a clean repeated local result and green CI on the exact commit. A note,
manual workaround or single successful rerun is not closure. P0/P1 security,
legal and data-integrity blockers continue to preempt this debt register.
