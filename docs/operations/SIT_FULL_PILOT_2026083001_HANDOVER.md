# SIT closed-pilot candidate 2026083001 — Handover

Status: **BUILD READY — STAGING AND PLAY INTERNAL PENDING** on 30.08.2026.

## Exact candidate

- Package: `com.shareittoo.app`.
- Version: `1.0.0+2026083001`.
- Artifact source commit:
  `8cf69273fcc31dd5183d265fb6d4e43d6b2cc9b5`.
- Track and environment: Google Play `Internal testing` and
  `https://staging.shareittoo.com/api/v1` only.
- Pilot: `heilbronn_wave0`.
- AAB size: `108943212` bytes.
- AAB SHA-256:
  `008d24a8ae7dc879f6ab55eafa490db98811270572448cbf66b87c81005d6cc1`.
- Upload-certificate SHA-256:
  `098f485e57161558e911fc3c742845925584db31c474cdba08dda02feb0129a4`.
- minSdk: `24`; targetSdk: `35`.

The owner-only archive is outside Git. Canonical signing, package and version
identity, ZIP integrity, Bundletool 1.18.1 validation and the binary privacy
scan passed. The Android Firebase configuration was available to the build
without copying values into repository evidence.

## Closed-pilot scope

The signed compile-time envelope exposes the non-binding G3 same-owner
multi-item surface, five deterministic G4 planner templates and G5 supply
enrichment/listing sets. Inventory and quotes are revalidated before a planner
selection reaches the non-reserving cart. Backend errors remain unknown/error
states and late Account-A results are suppressed after a switch to Account B.

No surface may create a reservation, binding request, contract or real
payment. External generative AI, public release, Production, Open testing and
Closed testing remain disabled. Staging uses the mock listing evaluator with a
zero-cent provider budget.

## Verification

The full local technical regression passed, including 2011 tool checks,
backend and PostgreSQL tests, Flutter tests and analyzer, Web/Wasm, loopback
smoke and Android debug. Exact source HEAD passed GitHub Regression
`33318505901`, including clean-checkout reproducibility, and CodeQL
`33318505919`; open code-scanning alerts were zero. No timing, retry,
rate-limit or reduced-parallelism workaround was retained.

## External readback and handoff

GitHub workflow `33318951234` published the exact commit-labelled API image
after its own backend, PostgreSQL, Flutter and clean-checkout jobs passed.
Direct Staging readback remains healthy but still exposes old commit
`cedc5ecfd65a9f2bcf731b5ac10dfd66a8a8160b`; payment transport is `memory`
and `livemode=false`. Hostinger deployment is pending the existing Google
account selection and must then use the exact published image plus
`heilbronn_wave0` overlay.

Google Play readback confirmed only Internal testing, active version
`2026082601`, the unchanged two-user tester list and an empty unsaved draft.
The local Mac was locked and Chrome file access remained disabled, so the AAB
was not uploaded or activated. A private, unshared seven-file handoff named
`PRIVATE_PLAY_UPLOAD_2026083001` is present in the SIT Drive folder. Its two
parts are exactly 60000000 and 48943212 bytes and the README binds both hashes,
reassembly, full AAB hash and the Internal-only procedure. It also carries the
exact de-DE release notes and a bounded MacBook Codex execution prompt.

Physical OnePlus/Pixel results remain `NOT_RUN` until the exact Internal build
is distributed and a device is reachable. These observations must be updated
only from direct readback; no older candidate or device result transfers to
`2026083001`.
