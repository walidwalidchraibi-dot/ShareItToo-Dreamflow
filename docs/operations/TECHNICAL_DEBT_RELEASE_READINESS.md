# Technical debt required before release readiness

Status: open, non-live register created on 22.08.2026.

This register prevents local test accommodations from becoming permanent
product or release prerequisites. None of the entries changes production,
Payment, Store, Cloud/VPS/DNS or pilot state. Release readiness must not be
claimed until every item below has reproducible evidence and is closed.

| ID | Current observation / temporary accommodation | Required deterministic exit evidence |
| --- | --- | --- |
| `TD-RR-001` | Local verification currently prepends a temporary signed Node 22-compatible runtime and the bundled app runtime; `pnpm` is not available as a normal shell command. | A clean documented Mac setup and CI both resolve the pinned Node and pnpm versions without a copied temp runtime; `pnpm install --frozen-lockfile`, Backend tests, syntax checks and secret scan pass from a fresh shell. |
| `TD-RR-002` | The monolithic PostgreSQL HTTP integration gives added auth/recovery requests distinct reserved test IPs so unrelated calls do not consume one shared rate-limit bucket. | Split or reset test application/limiter state so each scenario has an isolated deterministic bucket; separately test the real limiter thresholds; repeat the suite without IP rotation as a pass prerequisite. |
| `TD-RR-003` | Flutter regression runs at concurrency one because unrelated animated widget tests were previously nondeterministic in parallel. | Remove timer/animation leakage, run the complete suite repeatedly at the standard supported parallelism, and retain a stress result with zero flakes; concurrency one must no longer be required for a green result. |
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

## Closure rule

Each item closes only through a separate bounded implementation with committed
tests, a clean repeated local result and green CI on the exact commit. A note,
manual workaround or single successful rerun is not closure. P0/P1 security,
legal and data-integrity blockers continue to preempt this debt register.
