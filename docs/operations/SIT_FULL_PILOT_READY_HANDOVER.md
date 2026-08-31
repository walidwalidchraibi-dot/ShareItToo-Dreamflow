# SIT full closed-pilot readiness handover

Status: **PILOT_READY = PARTIAL** on 31.08.2026.

## Frozen candidate

- Branch: `codex/master-workflow-20260808`.
- Artifact source HEAD: `1ba604ca249a7454be52009a13ea2c7755cf037c`.
- Android: `com.shareittoo.app`, `1.0.0+2026083101`, minSdk 24,
  targetSdk 35.
- Scope: Google Play Internal testing, Staging API and private pilot
  `heilbronn_wave0` only.
- AAB SHA-256:
  `d3f04245ad33ea700537da6aa3593047d62ec107a4eadc72decfc2eab07a4af8`.
- Upload-certificate SHA-256:
  `098f485e57161558e911fc3c742845925584db31c474cdba08dda02feb0129a4`.

Canonical signing, package/version/SDK identity, owner-only archive, ZIP
integrity, Bundletool 1.18.1 and the binary privacy scan passed. The candidate
contains the required Firebase Android configuration without copying its
values into evidence.

## Technical closure

Guest Explore was blocked by an old corrupt account cache because public
discovery awaited account-only user data. Correction commit `65909cad...`
makes guest discovery independent of that cache, preserves corrupt bytes for
truthful recovery and keeps principal/session-epoch checks on authenticated
loads. The new exact APK was installed non-destructively on the reachable
Pixel; online guest catalog, explicit offline error and recovery after network
return/process restart passed.

The full local regression passed in one standard gate run without a retained
timing, rate-limit, parallelism or build-path workaround: 2011 tool checks,
backend and PostgreSQL, Flutter, analyzer with zero issues, Web/Wasm, loopback
smoke and Android debug. The fixed release-host capacity gate passed from
5,969,704 KiB free at start to 5,804,016 KiB free at completion. Exact
artifact-source GitHub Regression `33433680525`, including clean-checkout
reproducibility, and CodeQL `33433680485` passed; open code-scanning alerts are
zero. Exact API-image publish workflow `33435615332` also passed and published
the commit-labelled staging image.

Older replaced SIT build and QA outputs were moved off the constrained system
volume only after a TAR integrity readback and SHA-256 verification. The
current `2026083101` signed archive, source, signing material and unrelated
project files remained in place. This cleanup is not a release prerequisite.

Blue-Ocean listing, image privacy, the deterministic mock/fixture listing
evaluator, Regional Price Engine V2, G2 discovery/saved/cart, G3 same-owner
multi-item, G4 deterministic planner, G5 supply enrichment/listing sets,
Support, Privacy/Retention and database migration/backup/restore are green in
the automated pilot envelope. External generative AI, binding reservations,
contracts, real payments and public release remain disabled.

## External state

Google Play processed exact build `2026083101` in **Internal testing** and the
draft is ready to release. The prior active Internal build remains
`2026082601`; the two-user tester list is unchanged. Production and Open
testing are unavailable, and Closed Alpha remains unchanged on `2026081506`.
No other track or Store setting was changed. Final Internal activation remains
`AUTH_OWNER_ACCOUNT_SELECTION_REQUIRED`: the official browser is waiting for
selection of the existing SIT Play Developer Google account. No new developer
account was created.

Staging health/readiness are green but still report source commit
`cedc5ecfd65a9f2bcf731b5ac10dfd66a8a8160b`, memory payment transport and
`livemode=false`. Deploying the exact commit-labelled image remains
`AUTH_OWNER_ACCOUNT_SELECTION_REQUIRED` at the official Hostinger Google
account chooser. Firebase Console and GitHub CLI sessions are valid. No
credential was inspected or extracted.

The Pixel result is a direct-APK diagnostic, not Google Play split-delivery
evidence. Authenticated G3-G5 device journeys require exact Staging plus a
valid pilot account. The remote OnePlus remains
`DEVICE_TEST_DEFERRED_PHYSICAL_ACCESS`.

The private, unshared SIT Drive folder `PRIVATE_PLAY_UPLOAD_2026083101`
contains two hash-bound AAB parts, reassembly instructions, current candidate
manifest, machine evidence, this handover and the Internal release notes.
Readback confirms all seven expected files, their sizes and non-shared state.

## Human pilot sequence after the two deferred actions

1. Deploy only the exact candidate image to Staging, retain memory payments,
   then read back `/api/version`, `/api/health` and `/api/health/ready`.
2. Publish only draft `2026083101` to the existing Internal tester list and
   read back the active Internal state; do not promote or submit for review.
3. Install/update through Google Play and verify split delivery plus version.
4. Run guest online/offline/recovery, registration/login, process restart and
   Account-A-to-B isolation.
5. Run one available and one unavailable G3/G4 project, one owner/renter G5
   listing-set journey and confirm every payment/contract surface stays
   simulated and non-binding.

## Final assessment

There is no known open P0/P1 code blocker and the exact signed Internal
candidate is technically ready. The result is **PARTIAL**, not YES, because
the exact backend is not yet deployed, the Internal draft is not active, and
the authenticated/store-delivered device matrix therefore cannot honestly be
claimed. Machine evidence:
`docs/evidence/release-readiness/full-pilot-candidate-2026083101.json`.
