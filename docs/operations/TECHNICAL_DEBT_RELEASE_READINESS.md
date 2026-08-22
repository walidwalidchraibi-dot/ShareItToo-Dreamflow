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

## Closure rule

Each item closes only through a separate bounded implementation with committed
tests, a clean repeated local result and green CI on the exact commit. A note,
manual workaround or single successful rerun is not closure. P0/P1 security,
legal and data-integrity blockers continue to preempt this debt register.
