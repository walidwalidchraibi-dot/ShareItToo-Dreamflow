# Technical debt required before release readiness

Status: open, non-live register created on 22.08.2026.

This register prevents local test accommodations from becoming permanent
product or release prerequisites. None of the entries changes production,
Payment, Store, Cloud/VPS/DNS or pilot state. Release readiness must not be
claimed until every item below has reproducible evidence and is closed.

| ID | Current observation / temporary accommodation | Required deterministic exit evidence |
| --- | --- | --- |
| `TD-RR-001` | S4P installed and repository-bound normal-shell Node 22 plus exact Corepack pnpm 11.16.0. A fresh login shell passed frozen install, Backend, syntax, moderate audit, secret scan and PostgreSQL without a copied runtime; exact-commit CI is unavailable. | Retain green exact-package CI for the same pinned Node/pnpm contract and commands. No copied runtime or Codex-internal fallback may appear in the evidence. |
| `TD-RR-002` | S4R removed every historical request-source accommodation from the monolithic PostgreSQL integration and isolates unrelated scenarios with fresh application/limiter instances. Exactly one multi-source input remains solely to prove account lockout against a distributed attack. Isolated 10/30/240 thresholds, two fresh PostgreSQL runs and two complete regressions pass locally; exact-commit CI is unavailable. | Retain green exact-commit CI for the monolithic integration and isolated threshold contract. No source rotation for unrelated scenarios, reset hook, wait, bypass or increased production limit may reappear. |
| `TD-RR-003` | S4S adds a clean-exact-commit proof that runs the complete Flutter suite five times at default parallelism and rejects concurrency overrides, sleeps and retries. All five local runs passed with 379 tests plus one documented skip each at `cea3a1f`; exact-commit CI with the explicit stress input is unavailable. | Retain green exact-commit CI with `run_flutter_parallel_stress=true` using the same five complete runs. No concurrency one, reduced suite, sleep, retry or pass-on-rerun may appear in the evidence. |
| `TD-RR-004` | S4O added the PostgreSQL-16-pinned repository runner; S4P repeated it from the normal pinned Node/pnpm shell. Consecutive fresh-cluster runs passed with runner temp roots `0 -> 0`; exact-commit CI is unavailable. | Retain green exact-package CI for the runner contract and canonical PostgreSQL 16 integration without caller-supplied port, database or lifecycle commands. |
| `TD-RR-005` | S4Q routes all twelve known leaking suites through scoped fail-closed cleanup and adds a twice-repeated parallel boundedness guard to the full gate. After recoverable historical cleanup, the focused guard and two complete technical regressions passed `0/0 KiB -> 0/0 KiB`; exact-commit CI is unavailable. | Retain green exact-commit CI running the same boundedness guard with no orphaned `sit-*` fixture directories. Manual cleanup, a larger disk, alternate temp root or serial execution cannot be acceptance evidence. |
| `TD-RR-006` | S4U retains a clean-head proof of the single persisted issuance clock, exact 30-minute derived expiry and independently validated database bound. Five focused units and two fresh PostgreSQL 16 integrations passed at `db92a8c` with temp roots `0 -> 0`; exact-commit CI is unavailable. | Retain green exact-commit PostgreSQL 16 CI with the same source, exact-lifetime unit and migration/API constraint. No sleep, retry, clock wait, relaxed bound, reused database or manual schema may appear in the evidence. |
| `TD-RR-007` | S4T removes the CI Gradle wrapper's three-attempt loop and five-/ten-second sleeps. The workflow now performs one checksum-bound wrapper invocation; eight focused tests, a direct Gradle 8.12/Java 17 check and the complete local gate pass at `84357c4`. Exact-commit CI is unavailable. | Retain independent green exact-commit CI runs with exactly one wrapper invocation after verified cache setup. No attempt loop, sleep, retry or pass-on-rerun may appear in the evidence. |
| `TD-RR-008` | S4V removes the P0A Web smoke's fixed port and twenty-attempt `sleep 0.1` readiness poll. The repository helper binds an OS-selected loopback port before serving and requests each required artifact once. Three focused tests, five consecutive real smokes and the complete local gate pass at `1d6aeda`; exact-commit CI is unavailable. | Retain green exact-commit CI with one bind and one request per artifact on the OS-selected port. No fixed default port, sleep, retry, readiness poll, pass-on-rerun or external server prerequisite may reappear. |
| `TD-RR-009` | S4W removes the local booking-QA CDP tool's 50-millisecond reload timer, two-second sleep and reconnect. It guards the current main-frame loader, consumes the correlated new-loader lifecycle event and verifies exact storage without printing values. Four focused tests, five consecutive repetitions and the complete local gate pass at `8bc4fed`; no real browser seed was applied. | Retain green exact-commit CI for fragmented-frame/event-order/storage-negative contracts, then retain one controlled local-browser observation in a dedicated QA profile. No sleep, timer, reconnect retry, uncorrelated event or value-bearing verification output may reappear. |
| `TD-RR-010` | S4X replaces the Flutter analyzer's permissive ceiling with an exact normalized diagnostic fingerprint. S4Y then guards all Wishlist selector async gaps and ratchets the exact backlog `220 -> 214` at `1958248`, with only `use_build_context_synchronously` decreasing `98 -> 92`. | Continue reducing the committed snapshot only alongside reviewed source fixes until total zero, then retain green exact-commit CI. Never raise it, replace findings at equal count, suppress lints, make warnings non-fatal or update evidence merely to pass. |

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
- 22.08.2026, S4O: the repository-owned local PostgreSQL runner now requires
  major 16, creates a unique cluster and database on an OS-selected loopback
  port, requires `pg_isready`, runs the canonical integration and performs
  guarded `finally` cleanup on success and deliberate test-child failure. Six
  contract tests and two real consecutive runs passed through migration `063`;
  runner temp-root count was `0 -> 0`. No fixed port, sleep, reused database or
  manual cleanup was used. `TD-RR-004` is locally implemented but remains open
  until exact-commit CI and a normal pinned Node/pnpm shell satisfy the closure
  rule.
- 22.08.2026, S4O full gate: two stale static contracts were exposed rather
  than bypassed. Safety wiring now checks the central bounded limiter policy,
  and return lifecycle wiring checks seven booking-calendar days instead of
  fixed 24-hour arithmetic. The complete gate then passed at standard Flutter
  parallelism; neither correction changed product policy to fit a test.
- 22.08.2026, S4P: the normal login shell initially had no Node command and
  exposed pnpm 11.19.0 only through a Codex-internal fallback. Repository
  bootstraps now install/link Node 22, activate exact pnpm 11.16.0 and expose
  FVM Flutter 3.41.7, Dart 3.11.5 and Java 17 through normal shell paths. Fresh
  shell frozen install, Backend/PostgreSQL and the complete technical gate pass
  with no temporary runtime, PATH prefix, `JAVA_HOME` override or serial
  Flutter mode. This completes the local part of `TD-RR-001`; exact CI is still
  required for closure.
- 22.08.2026, S4P security audit: the first normal-shell audit found one
  moderate `uuid 9.0.1` advisory exclusively below unused Firebase Admin
  Storage. Storage and Firestore are now exact ignored optional dependencies,
  their 123-package surface is absent, Auth/Messaging focused checks pass and
  the production audit reports zero known vulnerabilities. CI now fails from
  moderate severity. No forced incompatible version, advisory mute or provider
  configuration change was used.
- 22.08.2026, S4P regression: another complete Flutter run passed at standard
  parallelism with 379 passes and one documented skip. This is retained local
  evidence for `TD-RR-003`; exact-commit CI/stress evidence remains missing.
- 22.08.2026, S4Q: twelve tool-test files were proven to own all 1,605 current
  orphan fixture directories (731,460 KiB). A shared safe-prefix tracker now
  registers fail-closed `node:test` cleanup, and the full technical gate runs a
  count-and-KiB boundedness guard over all affected suites twice at standard
  Node parallelism. The guard first proved the historical set no longer grew;
  those directories and the unused temporary Node copy were then moved to
  Trash. A clean focused run and two consecutive complete technical regressions
  passed `0/0 KiB -> 0/0 KiB`, without sleeps, serialization, alternate temp
  roots or manual deletion between runs. This implements the local part of
  `TD-RR-005`; exact-commit CI is still required for formal closure.
- 22.08.2026, S4R: all reserved request sources used only to preserve order in
  the monolithic PostgreSQL HTTP integration were removed. Independent DSA,
  evidence, recovery, export and authentication scenarios now close the prior
  loopback server and create a fresh application with fresh limiter stores
  while retaining the same isolated database. A source contract allows exactly
  one forwarded header: ten distinct sources are the explicit distributed
  credential-attack input whose target account must still lock. The final
  per-source login threshold uses one fresh loopback application. Focused
  policy/contract tests, two fresh PostgreSQL 16 runs, full Backend and two
  complete standard-parallel regressions passed without wait, reset, bypass,
  limit change or unrelated source rotation. This implements the local part of
  `TD-RR-002`; exact-commit CI is still required for formal closure.
- 22.08.2026, S4S: a repository-owned clean-exact-commit proof ran the complete
  Flutter suite five consecutive times at standard parallelism. Every run
  passed 379 tests with one documented skip at
  `cea3a1f404f90cc4ae1ed8dd86c453245f97e331`; the temp-fixture root remained
  empty. A committed contract rejects concurrency overrides, sleeps and
  retries. GitHub exposes the same proof only through an explicit manual input
  defaulting false. This implements the local retained-stress part of
  `TD-RR-003`; exact-commit CI with that input remains required for closure.
- 22.08.2026, S4T: the Flutter CI job's three-attempt Gradle wrapper loop and
  five-/ten-second sleeps were removed. It now runs one
  `./android/gradlew --version` after the verified basic-cache setup. A committed
  contract locks exactly one invocation, step order, Gradle 8.12's distribution
  SHA-256 and URL validation, and rejects attempt loops, sleeps and retries.
  Eight focused tests, a direct Gradle 8.12/Java 17 invocation and the complete
  clean implementation-head local metadata gate passed. This implements the
  local part of `TD-RR-007`; independent green exact-commit CI is still required
  for formal closure.
- 22.08.2026, S4U: a clean-exact-commit command repeated the reset-token
  single-clock unit five times and the repository-owned fresh PostgreSQL 16
  integration twice. All runs passed at
  `db92a8c6564a9554bc6379c95783eec6d3406a69`; migration `057` retained the
  database 30-minute upper bound and runner temp roots stayed `0 -> 0`. The
  committed wiring contract rejects sleeps, retries, clock waits, concurrency
  overrides and noncanonical database execution. This implements the local
  deterministic part of `TD-RR-006`; exact-commit CI remains required for
  formal closure.
- 22.08.2026, S4V: the P0A Web smoke's fixed port `18765`, twenty-attempt curl
  loop and fixed `sleep 0.1` were removed. The repository-owned Python helper
  now binds an OS-selected `127.0.0.1` port synchronously and performs one
  request for each of the three current-source artifacts. Three focused tests,
  the complete clean implementation-head local metadata gate and five further
  consecutive real smokes passed at
  `1d6aeda04a272648ae5fdea98f7b8a94f5a85a9f`. The ten-second request timeout
  fails closed and cannot retry. This implements the local deterministic part
  of `TD-RR-008`; exact-commit CI remains required for formal closure.
- 22.08.2026, S4W: the local booking-QA CDP seed's scheduled 50-millisecond
  reload, two-second sleep and target reconnect were removed. The tool now
  guards the current main-frame loader, queues events received before command
  responses, waits for the same frame's new-loader `load` lifecycle event and
  fails on any post-reload storage mismatch without printing stored values.
  Four focused tests, five consecutive repetitions and the complete clean
  implementation-head local metadata gate passed at
  `8bc4feddc4fed87c4614c1c20df0776dfec04571`; cache and SIT temp-root counts
  remained zero. No browser seed was applied. This implements the automated
  portion of `TD-RR-009`; exact-commit CI and one controlled local-browser
  observation remain required for formal closure.
- 22.08.2026, S4X: the technical gate's count-only analyzer ceiling was
  removed. The exact snapshot now locks all 220 normalized severity, path, code
  and message records at fingerprint
  `3a2fcf242ac029bcf4e3f2b70a92660700f88b68a05e3a3fca7d81b94b5010bd`.
  Seven focused tests reject unratcheted improvement, same-count replacement
  and parse/summary disagreement. The actual analyzer and complete clean
  implementation-head local metadata gate passed at
  `5a1aba962aa4047b938af4415882a7834681d894`. This contains `TD-RR-010` but
  does not close it; reviewed source ratchets to zero plus exact-commit CI remain
  mandatory.
- 22.08.2026, S4Y: four mounted checks now stop Wishlist add/move selectors
  immediately after either async lookup when the caller was disposed. No delay,
  retry or lint suppression was introduced. The analyzer ratcheted exactly
  `220 -> 214`, `use_build_context_synchronously` `98 -> 92`, and the Wishlist
  path bucket `6 -> 0`; every other bucket stayed unchanged. Nine focused tests,
  five saved-item tests and the complete clean implementation-head local
  metadata gate passed at `195824802b5edaf2c65d8b8ab611abfccae4b707`.
  `TD-RR-010` remains open for further reviewed reductions to zero and
  exact-commit CI.

## Closure rule

Each item closes only through a separate bounded implementation with committed
tests, a clean repeated local result and green CI on the exact commit. A note,
manual workaround or single successful rerun is not closure. P0/P1 security,
legal and data-integrity blockers continue to preempt this debt register.
