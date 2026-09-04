# SIT Staging acceptance checkpoint — 2026-09-04

This is an interim requirement inventory for the encompassing Android-Staging
Goal, not a closure report or a new implementation package. PASS is restricted
to the exact observation named below. Historical device passes never certify
the latest uninstalled candidate. PARTIAL means narrower evidence exists;
OPEN means the required end-to-end result remains unproved. No requirement is
removed because an owner dependency or provider hold is outstanding.

Source inspected: `c4c576d3e26166591130ca1e4744048069afbbc3`, branch
`codex/master-workflow-20260808`, worktree
`/Users/walidchraibi/Worktrees/SIT-master-workflow-20260808`.

## Fresh read-only runtime evidence

The source-defined proxy mapping (`backend/ops/Caddyfile`, `handle_path /api/*`)
and routes (`backend/src/app.js`) identify `/api/version` and
`/api/health/ready` on the exact Staging origin. Both returned HTTP 200 JSON.
At **2026-09-04T02:59:29.048Z**, the latter reports:

- service `shareittoo-api`, environment `staging`, status `ok`;
- deployed source `5d88295fa7fe313b83936783a0582a505b2ba486`;
- database and mail `ok`, pending/dead notifications both zero;
- payment transport `memory`, live mode false, failed events/unbalanced
  ledger groups both zero; support-deadline health `ok`.

The deployed endpoint does not expose the selected listing-AI provider fields.
They remain **unverified by this observation**; older mock-provider evidence
is not silently upgraded into current provider verification. Zero queue counts
do not prove device delivery. Memory payment is not a Stripe sandbox pass.
Earlier non-JSON/404 results from other paths do not establish a Staging outage.

Only credential-free GETs were made. No notification, mail, provider request,
payment, configuration change or deployment was initiated. The redacted
machine readback is retained in the private WP04 evidence directory as
`staging-read-only-20260904T025929Z.json`.
Readback SHA-256:
`ee8a3fba4f3065e6295844700a9ddcadf82ebdea22f6b04267e4da39df3ae8cb`.

## Scoped Drive/owner-input refresh

Read-only discovery checked the supplied SIT root, its
`00_CODEX_AKTUELL_AB_2026-08-20` folder and the direct
`10_C1_V5.2_AFTER_CUTOVER` contents. The latest direct Codex handover found is
[09_SIT_FULL_PILOT_READY_HANDOVER_2026-09-02.md](https://drive.google.com/file/d/1gDz5zi447uTXWU86E9iPIrxkme-z0ZSb/view).
It still explicitly records independent legal review and operator/provider
facts as open. The direct V5.2 folder contains the August18 core specification
and legal PDF, not a newer approval artifact. No credentials, backup codes or
KYC material was opened. This is not an exhaustive claim about all of Drive.

Current local `assets/legal/de/legal_manifest_v52.json` independently remains
`draft-blocked`, `activationAllowed=false`, with no effective date. Neither
general autonomy nor a technical test constitutes the missing independent
review/approved effective snapshots. The current Staging Goal remains intact;
older Drive candidate-completion wording does not close it.

## Requirement-to-evidence matrix

| Required outcome | State | Existing evidence and exact remaining gap |
| --- | --- | --- |
| Staging version/readiness | PASS | The timestamped read-only observation above, on deployed `5d88295f`; not an application-wide acceptance pass. |
| Final source, signed candidate and exact CI | PARTIAL | Frozen `2026090402`/`bfd3e9e4` is locally archived and hash-verified but uninstalled; its Regression failed, CodeQL passed. Current local `c4c576d3` has normal regression and complete cold R10 green, with byte-identical debug APKs; its push/CI are pending. |
| Email registration, verification, login/logout and persistence | PARTIAL | N20/N22 prove historical `2026090305` UI flows; repeat affected flows on the accepted final Pixel candidate. |
| Password recovery/change and Account-A→B isolation | PARTIAL | N21 proves historical recovery, single-use link and old-credential rejection; local typed-outcome/epoch regressions pass. Complete the final-candidate device matrix, including direct password change and uncertain/partial outcomes. |
| Google sign-in | PARTIAL | N23 proves Google login, repeat login and cold start on `2026090306`; later shared-SDK changes require affected final-candidate revalidation. |
| Facebook and Apple sign-in where supported | OPEN | WP02 provider-readiness records missing setup/owner dependencies. Do not substitute a hidden button or invent provider/account/membership facts. |
| Real SMS completion | PARTIAL | N29/`2026090307` has narrower backend/invalid-code/cold-start proof; immediate retry-dialog completion needs the corrected accepted candidate and a fresh owner SMS window. |
| Real image analysis and owner-reviewed complete listing proposal | OPEN | WP03 corrects the real adapter with synthetic tests only. A real consented image, authorized server provider/budget and review-before-publication flow remain necessary. Clarification/manual fallback must also be tested. |
| Draft, edit, publish, pause/reactivate, catalog search/filter, favorites and wishlists | PARTIAL | N22/N27 prove historical draft/publication/discovery/retirement across two roles. Editing, remaining lifecycle actions and all discovery controls still need full final-candidate evidence. |
| Quote, rental request, acceptance/rejection and contract/availability consistency | PARTIAL | N27 proves a non-binding Pilot-Simulation only. V5.2 prerequisites and the actual intended contract workflow are not satisfied by simulation. |
| Messages, attachments, location and appointments | PARTIAL | N27 proves text chat and offline queue behavior on an older candidate. The complete attachment/location/appointment matrix remains open. |
| Transactional push foreground/background/process-ended | PARTIAL | N27 contains historical controlled FCM evidence. Revalidate the accepted final source/device pair; distinguish process termination from Android user force-stop and document the supported behavior. |
| Pickup, return, cancellation/withdrawal, damages, reviews and invoices | OPEN | Complete real intended two-role lifecycle evidence is missing; maintain legal/provider boundaries and audit/availability consistency. |
| Stripe sandbox payment, rejection/interruption, duplicate delivery, refund and simulated payout | OPEN | Fresh runtime is memory-only. WP04 two-secret wiring is locally tested, but platform identity/approved secret setup and all eight P0B real-sandbox scenarios remain open. Never call memory results Stripe test funds. |
| Cart, projects and booking groups | OPEN | The full connected two-role device workflows are not established by the cited device journeys. |
| Support submission/follow-up, reports, blocking, privacy export and deletion | PARTIAL | N28 proves reachability, not these mutations. Exercise scoped disposable Staging identities with exact cleanup/retention rules, not the owner's account. |
| Light/Dark and available background variants | PARTIAL | N28 shows readable older-candidate Light/Dark and four reachable background choices; it did not select the background variants. Final selections/persistence and affected surfaces remain to test. |
| Offline/online, process restart, permission changes and accessibility | PARTIAL | N27/N28 provide older network/cold-start/large-text evidence; the final-candidate permission and complete accessibility matrices are still missing. |
| Full Pixel acceptance and evidence cleanup | OPEN | All applicable rows must be completed on the correct accepted candidate/provider pair; retain explicit owner-dependent gaps. |
| Same-candidate private OnePlus handoff and cross-device acceptance | OPEN | No OnePlus access until full Pixel closure. Then verify package/hash/signature, separate accounts and actual two-device flows; no installation is inferred from preparing an APK. |

## Next execution order

1. Exact cold R10 is complete and its execution-only evidence validates. Preserve
   its `c4c576d3` binding, failed predecessors and successful cleanup. Do not
   start another broad hardening Goal from the runner's legacy next-package label.
2. Once the existing owner GitHub verification is completed, renew through the
   official flow, normally push the preserved local commits, and obtain
   exact Regression/CodeQL. A newer CI result does not certify frozen `bfd3e9e4`.
3. Resolve the candidate-specific CI/installation prerequisite before Pixel
   acceptance. Keep old artifacts immutable; any required successor gets its
   own source/version/configuration/signature and complete evidence.
4. Perform the final-candidate email/Google/SMS, two-role listing/chat/push and
   support/privacy/presentation tests. Owner-only dependencies wait separately;
   continue independent executable cases, not another broad hardening Goal.
5. Complete the legitimate provider/legal prerequisites and real AI/Stripe
   sandbox/lifecycle acceptance; do not turn holds into successful substitutes.
6. Only after complete Pixel closure, prepare and test the identical OnePlus
   handoff. Production, public rollout, Store, real-money and paid-order
   boundaries remain unchanged; the EUR100 ceiling is not a purchase action.

## Evidence references

- `WP04_R10_COLD_STORAGE_2026-09-04.md` and the frozen
  `WP02_PIXEL_CANDIDATE_2026090402_HANDOVER.md`.
- `N20_PIXEL_APP_UI_REGISTRATION_2026-09-03.md`,
  `N21_PIXEL_PASSWORD_RECOVERY_2026-09-03.md`,
  `N22_PIXEL_EMAIL_VERIFIED_TWO_ROLE_PRODUCT_JOURNEY_2026-09-03.md`,
  `N23_PIXEL_GOOGLE_SOCIAL_AUTH_PRINCIPAL_EPOCH_2026-09-03.md`.
- `N27_CURRENT_CANDIDATE_PIXEL_TWO_ROLE_PUSH_OFFLINE_2026-09-03.md`,
  `N28_CURRENT_CANDIDATE_PIXEL_SURFACE_MATRIX_2026-09-03.md`,
  `WP02_PROVIDER_READINESS_2026-09-03.md`.
- `WP03_LISTING_AI_PROVIDER_RESPONSE_2026-09-04.md`,
  `WP04_STRIPE_WEBHOOK_DESTINATIONS_2026-09-04.md`, and
  `SIT_AUTONOMOUS_WORK_PACKAGE_QUEUE_2026-09-03.md`.
