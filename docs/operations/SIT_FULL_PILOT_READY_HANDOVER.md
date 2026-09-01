# SIT full closed-pilot readiness handover

Status: **PILOT_READY = PARTIAL** on 01.09.2026.

## Frozen candidate

- Branch: `codex/master-workflow-20260808`.
- Artifact source HEAD: `0c0624c9f1a76c886112a15c41564d6375b69238`.
- Android: `com.shareittoo.app`, `1.0.0+2026090103`, minSdk 24,
  targetSdk 35.
- Scope: Google Play Internal testing, Staging API and private pilot
  `heilbronn_wave0` only.
- AAB SHA-256:
  `b6fac301b932b024014fdadbe5e8a01f545ddad50815f8e9f53df0045afe39bc`.
- APK SHA-256:
  `234117934094ebb4011c02776162903fd67dde391c711db7982584351981ae9a`.
- Upload-certificate SHA-256:
  `098f485e57161558e911fc3c742845925584db31c474cdba08dda02feb0129a4`.

Canonical signing, package/version/SDK identity, owner-only archive, ZIP
integrity, Bundletool 1.18.1 and the binary privacy scan passed. The candidate
contains the required Firebase Android configuration without copying its
values into evidence. The version code is higher than the directly observed
Play draft `2026083101` and active Internal build `2026082601`.

## Technical closure

The full standard local gate passed from `flutter clean` in one run with 2,013
of 2,013 repository tool checks, backend and PostgreSQL, Flutter, analyzer with
zero issues, Web/Wasm, loopback smoke and Android debug. Commit `ff29c2d8...`
permanently bootstraps locked Flutter metadata before the Node inventory; this
closed the clean-bootstrap gap revealed after the preceding candidate. The
release-host capacity guard passed without a retained timing, rate-limit,
parallelism or build-path workaround. Reproducible generated outputs were
cleaned only after the signed archive and hashes had been preserved.

Blue-Ocean listing, image privacy, Regional Price Engine V2, G2 discovery,
saved state and cart, G3 same-owner multi-item, G4 deterministic planner, G5
supply enrichment and listing sets, Support, Privacy/Retention and database
migration/backup/restore are green in the automated closed-pilot envelope.
Binding reservations, contracts, real payments and public release remain
disabled.

Official local Codex authentication is classified
`CODEX_AUTH_LOCAL_DEV_SUPPORTED`. A fresh, explicitly enabled evaluation of
the synthetic cordless-drill fixture passed through the disabled-by-default
`codex_local_dev` adapter using ChatGPT authentication, an ephemeral read-only
sandbox and no API billing. It produced an editable `cat8 / Bohrmaschinen`
draft, kept brand, model, value and region unclaimed, left all eleven owner
confirmations false and could not publish. This remains developer evidence,
not a SIT runtime provider.

## Reachable-device result

The exact APK was installed non-destructively on the reachable Pixel 7 Pro.
The previous `2026090102` data container, install identity and canonical
signature were preserved. The installed APK bytes match the candidate hash.

Guest discovery shows the real public catalog online. With Wi-Fi and mobile
data temporarily disabled it shows the explicit error “Anzeigen konnten nicht
geladen werden” rather than an empty catalog or success. Enabling an already
saved Wi-Fi connection restored catalog content; no network identifier was
retained. A separate force-stop/relaunch proof preserved install and
data-container identity.

The device is currently signed out. The authenticated physical G3/G4/G5 matrix
therefore remains `NOT_RUN` until the exact Staging image and a separate
synthetic pilot account are available. Google Play split delivery is also not
claimed for the direct APK. The remote OnePlus remains
`DEVICE_TEST_DEFERRED_PHYSICAL_ACCESS`.

## External state and exact deferred lanes

The last direct Google Play readback used the authenticated SIT developer
session and confirmed Internal testing only. Active Internal remains
`2026082601`; draft `2026083101` remains unactivated; the selected tester list
contains two users and is unchanged; Closed Alpha remains `2026081506`;
Production and Open testing are unavailable. Candidate `2026090103` has not
yet been uploaded, processed or activated.

Staging health/readiness remain green but still report source commit
`cedc5ecfd65a9f2bcf731b5ac10dfd66a8a8160b`, memory payment transport and
`livemode=false`. The exact `0c0624c9...` image has not yet been published or
deployed.

The Mac locked after the authenticated Play and Hostinger sessions had been
verified. GitHub CLI additionally requires a fresh official device approval.
No password, OAuth token, browser cookie, API key or signing secret was read,
copied or requested. These exact lanes are classified
`DEFERRED_PHYSICAL_OWNER_ACTION_MAC_UNLOCK` and
`AUTH_OWNER_DEVICE_APPROVAL_REQUIRED`; they do not invalidate the completed
local code, build, AI, regression, device or Drive evidence.

The private, unshared SIT Drive folder `PRIVATE_PLAY_UPLOAD_2026090103`
contains seven read-back files: the two hash-bound AAB parts, reassembly
instructions, Internal release notes, candidate evidence, Pixel evidence and
this handover. Every item is owner-only and not shared. The superseded folder
is retained but renamed `REPLACED_DO_NOT_USE_PRIVATE_PLAY_UPLOAD_2026090102`,
so it cannot be mistaken for the current candidate.

## Exact continuation after Mac unlock

1. Complete the official GitHub device approval, push the normal fast-forward
   branch and require exact-source Regression, clean-checkout reproducibility,
   CodeQL and zero open code-scanning alerts.
2. Dispatch the exact-source regression with API-image publishing enabled.
   Deploy only the exact commit-labelled image to Staging with
   `heilbronn_wave0`, memory payments and `livemode=false`; verify version,
   health and readiness readback.
3. In Google Play, replace the inactive draft only within Internal testing
   with exact build `2026090103`, leave testers and all other tracks unchanged,
   activate it and read the final state back.
4. Verify Play split delivery when a reachable device can update from the
   tester account. Provision a separate synthetic Staging pilot account and
   run the authenticated G3/G4/G5 matrix without real money.
5. Update the machine evidence, this handover, current state/work package and
   the final three private Drive files. Commit and push documentation normally;
   keep PR #7 Draft and unmerged.

## Final assessment

There is no known open P0/P1 technical pilot blocker. The current signed
candidate is locally build-, regression-, privacy-, AI- and guest-device-ready.
The result remains **PARTIAL**, not YES, because its exact branch commits are
not yet upstream/CI-bound, exact Staging is not deployed and build `2026090103`
is not yet the active Play Internal release. Machine evidence:
`docs/evidence/release-readiness/full-pilot-candidate-2026090103.json`.
