# WP04 prerequisite — cold R10 storage capacity

Status: **FULL NORMAL REGRESSION AND HOST EXPANSION PASS / CLEAN R10 PENDING**.
Technical debt: `TD-WP04-R10-COLD-CAPACITY` — **OPEN** until the normal full
gate and exact clean-head R10 both pass without intervening cleanup.
This is a build-host verification correction, not mobile/provider work or
completion of WP04. Base: `2408ada3ef3a5939e0222ac3655f2afa580b8fd1`.
Worktree: `/Users/walidchraibi/Worktrees/SIT-master-workflow-20260808`;
branch: `codex/master-workflow-20260808`.

## Actual failure

Corrected R10 session 14219 is terminal, exit 1. The exact isolated checkout
passed toolchain capture, locked restores, Backend tests/syntax, dependency
audit, secret scan, isolated PostgreSQL and the complete technical regression
(634 seconds). The second Android debug build also passed (50 seconds).
However, extracting the second APK failed with unzip exit 50 and a disk-full
write error. No APK-equivalence result or execution JSON was produced.
This is NOT a full clean-checkout pass.

The task-owned 32-GiB APFS build image had about 10 GiB available when the
run started. Cold package caches, project output, APK copies and both unpacked
inventories exhausted that remaining space. The existing generic five-GiB
cache floor was not a sufficient cold-R10 admission check. The source,
protected inputs and signed archives were not affected. The runner removed
its guarded generated child in `finally`; its parent directory and the
separate failure log remain. No manual cache deletion or timeout retry.

Failure log: private `SIT_WP04_WEBHOOK_EVIDENCE.IQxzop/r10-corrected.log`;
SHA-256 `797d0088f5966cc1503a2559ec3d2866b0ef352ba6958b191b0011778e70984a`.

## Correction and deterministic checks

R10 now reads free space on its actual temporary filesystem before reading
Git or creating the isolated clone. It requires 24 GiB: the unchanged five-GiB
project and eight-GiB package-cache bounds, one GiB for the clone, five GiB
for APK copies/extractions, and five GiB reserve. This is an admission budget,
not an exclusive reservation against unrelated concurrent writers.

The output-bound validator uses those same project/cache constants without
raising either limit. Both APK builds, both full inventories, raw hashes,
metadata-drift classification, runtime checks and cleanup remain unchanged.
There is no CLI bypass or undocumented cache dependency.

Deterministic tests cover the exact threshold, one KiB below, the observed
ten-GiB case before any Git access, malformed/negative/overflow statistics and
an unavailable filesystem. The helper suite passes 15/15; combined runner and
existing evidence-validator suites pass 23/23. Five unchanged cache-wrapper
tests also pass. The red helper log reports the missing guard export; the
behavioral failure is the complete old R10 attempt described above. Red and
green logs are retained separately. A real native-filesystem probe also
rejects the low-space internal volume without starting a build.

## Host recovery and closure still required

No live build or open volume handle remained before the task-owned image was
detached. The offline recovery copy completed and a recursive bytewise diff
passed (excluding only macOS AppleDouble `._*` sidecars). The existing logical
image was enlarged to 64 GiB, reattached and positively mapped to its own
virtual APFS container before that container was grown. The APFS filesystem
check exited zero. The physical external SSD was not reformatted or resized.

The exact image path, mount name, owner-only directories, SDK and private
normal build-cache profile remain unchanged. The unchanged wrapper validates
the exact image/APFS mapping, owner permissions and separate physical backing.
The native R10 probe sees 44,311,904 KiB free against 25,165,824 KiB required.
The existing real Java probe passes POSIX permissions, fsync, atomic rename,
symlink roundtrip and a separate-process exclusive lock. No other image,
user volume or login was changed. No cache or historical artifact was removed.

The offline 32-GiB recovery image remains at the private external location
recorded in the task checkpoint. Restore only as a separate controlled offline
operation after stopping verified users of the current image; it must not
overwrite a mounted or subsequently changed image.

Full normal regression now passes (session 69380, exit 0): 2,171 tool tests,
665 default Flutter passes / 33 explicit-profile skips and all configured
profiles, analyzer zero, Web debug / Wasm dry run, loopback smoke, Android
debug in 17 seconds (11/471 tasks executed), minSdk 24 and R11's 14 permissions
/ 8 exports. The original checkout and guarded cache were used without any
intervening purge. This is not a signed release or standalone Wasm-runtime
acceptance. Frozen signed 2026090402 APK/AAB hashes were separately rechecked
and still match their archive manifest.

Before closure: commit the bounded correction and complete a fresh full
R10 on that exact clean commit. Keep this failed attempt separate. Until then,
capacity debt and R10 remain OPEN. GitHub authentication and exact new-head
CI are still pending; the old frozen candidate's failed Regression and green
CodeQL are not evidence for this correction.

No Pixel/OnePlus installation, provider call, payment, deployment, Store,
Production, credential extraction, billing or PR merge occurred.

## Retained private proof

Logs remain in the task's owner-only `SIT_WP04_WEBHOOK_EVIDENCE.IQxzop` directory.

| Proof | SHA-256 |
| --- | --- |
| Combined 23 runner/validator tests | `7e0d1ed98e4c3bcf55d0929deb9fcbd5ee8d362792d3596fd4483a4e2ff67561` |
| Expanded host/profile admission | `f3df75b9599204769500e4b646e2826c6cb821f468c3407cf58753e595761d21` |
| Real filesystem probe | `ac1c29d766a886e906acd94d972eef9244af3e56795c49dcf8f666fb87f49652` |
| Full normal regression | `edb8693af3f40d2de1f859836954d1633025cd0ffb53e6af815ddd7354cb848c` |
