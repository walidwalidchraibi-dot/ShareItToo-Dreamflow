# 48H R10 technical-debt register

Status: **TD-R10-001 LOCALLY RESOLVED — EXACT CI PENDING**

This R10-specific register records clean-checkout, toolchain and reproducibility
findings discovered after the historical PF18 release-readiness checkpoint. It
is deliberately separate from the immutable 21-item PF18 snapshot so that new
work cannot silently rewrite a completed historical audit.

| ID | Finding and current evidence | Deterministic exit contract |
|---|---|---|
| `TD-R10-001` | **LOCALLY RESOLVED 24.08.2026; EXACT CI PENDING.** A clean direct Gradle debug build silently used fallback identity `1.0+1` when generated Flutter version metadata was absent. The technical gate now derives `1.0.0+2026082302` from checked-in `pubspec.yaml` before its unchanged single direct build. Two equivalent APKs also exposed byte drift limited exactly to DEX header checksum/SHA-1 bytes and the D8 synthetic-class checksum map; normalization is restricted to those fields and no raw binary identity is claimed. Project output and intentionally fresh package caches are measured separately at 3,208,463 KiB and 6,119,769 KiB and cleaned. | Close only after the independent exact-PR-head clean-clone job, normal Regression and CodeQL pass. Permanently retain locked restores, standard parallelism, exact build identity, unknown-drift failure and separate fixed 5-GiB project/8-GiB temporary-cache bounds. No stale local properties, undocumented cache, manual cleanup, retry, reduced suite or false byte-identity claim may replace them. |

## Observation log

- 24.08.2026, R10: six bounded clean-clone runs successively exposed the stale
  direct-Gradle version fallback, exact D8 synthetic-checksum metadata drift,
  debug `kernel_blob.bin` versus release `libapp.so` payload selection and an
  initially combined cache/output bound. The retained implementation fixes or
  exactly classifies each issue without retry, timing or parallelism changes.
  The full local run at `322e97e` is green and cleans 9,328,232 KiB of measured
  temporary project/cache state. `TD-R10-001` remains open only for exact
  GitHub clean-clone, Regression and CodeQL verification.
