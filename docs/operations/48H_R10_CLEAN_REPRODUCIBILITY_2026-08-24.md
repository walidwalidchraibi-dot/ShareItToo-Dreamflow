# 48H R10 clean-checkout and build reproducibility

Status: **LOCAL VERIFIED — EXACT GITHUB REGRESSION AND CODEQL PENDING**

R10 creates a no-hardlink local clone at an exact detached Git head and starts
with zero `.dart_tool`, `build`, `android/.gradle` and `backend/node_modules`
footprint. Backend, Flutter and Gradle dependencies are restored from checked-in
locks into fresh bounded temporary caches; neither private Firebase/signing
files nor credentials are copied. The clone runs the Backend suite, syntax
checks, dependency audit, sanitized repository secret scan, repository-owned
PostgreSQL runner and the full analyzer/Flutter/Web/Wasm/Android technical gate.

The retained local run is bound to implementation head
`322e97ecc0c20c7f765054523dbcf1ddf45d0e9a`. It preserves exact hashes for
seven dependency/toolchain files, 112 schema/migration files, 84 image/font/
license assets and all three font files. Toolchain identity is Flutter 3.41.7,
Dart 3.11.5, Node 22.23.2, pnpm 11.16.0, Java 17 and Gradle 8.12.

The first clean run exposed that direct Gradle assembly silently used fallback
identity `1.0+1` when generated `android/local.properties` did not yet contain
Flutter version fields. The permanent correction now derives debug build
metadata from checked-in `pubspec.yaml` immediately before the existing single
direct Gradle build. The retained APK identity is therefore
`com.shareittoo.app`, `1.0.0+2026082302`, compile/target SDK 35 and minSdk 24.

Two forced equivalent debug builds have equal size and 795 extracted entries,
but their raw hashes are not identical. The only differing entry is
`classes18.dex`. Exact normalization proves that the changed bytes are limited
to DEX header checksum/SHA-1 bytes 8-31 and a nine-hex-digit D8 synthetic-class
checksum value. No raw binary identity is claimed; every other entry and the
normalized DEX payload must match, and any unexplained entry drift fails.

The merged artifact retains the exact reviewed 14-permission inventory,
backup and cleartext traffic disabled, no legacy external-storage mode, backend
disabled by default in debug, external AI and real payment disabled, all social
providers default-off, no compiled OpenAI API origin, and Firebase SDKs present
with Messaging auto-init, Analytics collection and Crashlytics collection all
default-off. Runtime strings are inspected from the debug
`assets/flutter_assets/kernel_blob.bin`, not a release-only `libapp.so`.

Generated project output is 3,208,463 KiB under the unchanged 5-GiB project
cap. Fresh Flutter, Gradle and pnpm caches total 6,119,769 KiB under their
separate 8-GiB temporary-cache cap. Total measured temporary footprint is
9,328,232 KiB. The clone, all three caches and both APK copies are removed at
the end. No retry, reduced parallelism, sleep, hidden cache, retained artifact,
signed candidate, Production/VPS/Cloud/Firebase/Store/Payment/account change,
API billing, credential extraction, PR merge or publication is part of R10.

The committed validator is fail-closed for exact local evidence and supports a
separate structural execution mode for a detached GitHub PR-head checkout. R10
closes only after that independent job, normal Regression and CodeQL are bound
to exact successful checks. R11 is next after that closure.
