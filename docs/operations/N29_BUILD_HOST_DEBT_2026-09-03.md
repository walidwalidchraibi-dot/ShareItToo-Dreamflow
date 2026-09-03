# N29 build-host and toolchain debt

Status: **OPEN — not a release-readiness closure**. Observed 2026-09-03 on
candidate source `77d5103cb3c89af3ca5187a6c2642e28fa0703dd`.
Historical closed registers are not rewritten by this new observation.

## TD-N29-HOST-CAPACITY — OPEN

The first signed-build attempt stopped before compilation: only 4,617,064 KiB
free plus replaceable project output, below the unchanged 5,242,880-KiB floor.
A later check found 4,597,884 KiB. No artifact was created by those guard checks.

Two exact Gradle 8.12 transforms were identified as expanded Flutter debug
engine libraries, arm64-v8a and x86_64. Their source JARs passed ZIP integrity
checks. With no Java process running, only generated cache entries
`26f86134965bdab933c5a4d386b1b1ad` and
`02ab5dee75c42f372ba049a2bbf02775` were removed. Source packages were retained
and permit regeneration. Signed archives, quarantine, private handoffs,
personal files and credentials were untouched.

After this explicit host-state change, the signed build started with
2,091,436 KiB free plus 3,449,432 KiB generated (5,540,868 KiB effective).
It succeeded, archived both verified artifacts and cleaned its generated
output. End state: 5,936,252 KiB free, 34,524 KiB generated, fixed limits intact.

This is temporary recovery, not a permanent cache-purge prerequisite. A future
debug build can recreate the removed entries. Before release readiness,
provide normal host capacity and prove the unchanged full gate followed by
the signed archive lifecycle without intervening manual cache removal,
retry loops, reduced parallelism or relaxed bounds. Retain exact CI and
before/after measurements. The original failed attempt remains failed evidence.

### Recurrence during WP02 SDK ownership correction

On base HEAD `239c5aa1f74e55cb2991f97832a1d855a7ae7e94` plus the local WP02
correction, the full local gate again stopped before tests: 4,770,824 KiB
effective capacity versus the unchanged 5,242,880-KiB floor. This is a recurring
host constraint, not a failed test or closed debt. The original log is
`/tmp/sit-wp02-sdk-full-regression.log`.

The same two exact engine-transform entries above had been regenerated. Both
retained source JARs passed ZIP verification. The only Gradle 8.12 daemon was
IDLE and stopped normally; no Gradle build was active and neither target had
an open file handle. Only those two generated entries were removed again.
The resumed gate started with 2,067,244 KiB free and 3,643,156 KiB generated,
5,710,400 KiB effective. Log:
`/tmp/sit-wp02-sdk-full-regression-capacity-recovered.log`.

This manual recovery is NOT a supported permanent build prerequisite. Normal
host capacity and a complete uninterrupted gate-to-signed-archive lifecycle
without manual cache purges are still required before release-readiness closure.

The later WP02 test-order isolation full-gate attempt stopped again at
4,729,044 KiB effective capacity; it did not run tests or produce an artifact.
No further manual purge was made. Read-only inventory found roughly 3.6 GiB
of replaceable SIT output and 6.6 GiB of shared Gradle caches. Protected release
archives were preserved. The connected Crucial X9 has substantial free space,
but is exFAT: its availability is not proof of suitable build-cache filesystem
semantics, private-file permissions, or a validated multi-volume capacity
plan. No files were moved, volume reformatted or host configuration changed.

## TD-N29-KOTLIN-METADATA — OPEN

The signed bundle build emitted an incompatible Kotlin metadata diagnostic
from Firebase Auth 24.2.0: metadata 2.3.0 with compiler expectation 2.1.0.
Both the AAB and APK subsequently built successfully and the builder exited 0;
artifact verification and real Pixel update/navigation passed. This diagnostic
also appears in earlier retained successful release-build logs, so it is not
established as a regression introduced by the SMS correction.

No warning suppression, dependency override or compiler-check bypass was used.
The exact affected task and safe compatible toolchain alignment still need
bounded investigation. Before claiming toolchain-clean release readiness,
resolve the diagnostic with pinned supported dependencies, deterministic
regression and a clean signed build. An exit-0 build alone does not close it.
The SDK XML-version warning also remains visible; no broad upgrade is implied.

Local logs (not secret evidence or repository prerequisites):
`/tmp/sit-n29-build07-signed-release.log` and
`/tmp/sit-n29-build07-signed-release-after-capacity-recovery.log`.
