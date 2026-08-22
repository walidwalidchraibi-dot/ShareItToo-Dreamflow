# Current Work Package: autonomous non-live launch-readiness continuation

Status: **active under Walid's exceptional no-artificial-stop instruction;
non-live and fail-closed** on 21.08.2026.

Walid instructed Codex to make SIT as launch-ready as safely possible inside
the established working frame, to continue across independent work lanes when
one lane is blocked, and to stop only when he explicitly says so. Code,
reversible migrations, local/free tooling, internal simulation, documentation,
tests, commits, pushes to draft PR #7 and CI verification are authorized.

The instruction still does not authorize new paid subscriptions, real money,
public registration or pilot activity, production, DNS, irreversible user
changes, Store submission, PR merge, or invented legal/operator/provider
approval. A missing external fact remains false and blocks only its dependent
lane.

## Active package

`S1_SUPPORT_CASE_FOUNDATION` is implemented and verified at commit
`64874b9eba0b6b2fca85f1c4f3cdfed0d702f095`. GitHub Actions run
`32491241853` passed backend, PostgreSQL migration, Flutter, Web and Android
debug regression; publication and signed-candidate jobs stayed skipped.

`S2_SUPPORT_DECISION_APPROVAL_LEDGER` is verified at exact commit
`072e2ba8029dc297bfcb3f9a25e2dd8bc59136fa` and exact successful GitHub
Actions run `32496163016`. It adds:

- migration `033` for draft, approval, rejection and implementation truth;
- immutable proposal hashes, expected versions and exact-hash approval;
- administrator-only four-eyes review behind Staff Step-up;
- simulation/internal-testing-only implementation evidence with no action
  adapter;
- resolution guards that require approved and verified implementation truth;
- explicit staff assignment boundaries for queue, detail and decision work;
- Privacy/Retention source-hash binding that remains draft and fail-closed.

No external message, evidence upload, real refund/payout, account measure,
deployment or public/live activation is part of S2.

`S2A_SUPPORT_DENIED_ACCESS_AUDIT` is verified at exact commit
`3742f00b11366205abb79c10295e775d301325e8` and exact successful GitHub Actions
run `32497715939`. It closes the `SUP-020` matrix requirement by recording
sanitized audit evidence when a support account attempts to read a case or
decision list outside its explicit assignment. The response stays fail-closed
and does not disclose whether an unassigned case exists. Break-glass remains
unimplemented and blocked.

`S3A_SAFETY_FIRST_SUPPORT_INTAKE` is verified at exact commit
`613adc06c9504b4778adf81b5ba5b892d3435825` and exact successful GitHub Actions
run `32500301293`. It implements Drive Support Packet scenarios `SUP-017` and
`SUP-093`: the app asks about immediate danger before normal categorization,
shows source-bound T-003 safety guidance for `yes` or `unsure`, and carries
immutable version evidence into the backend intake. Backend contradictions
fail closed and immediate danger routes to the Trust & Safety owner.

`S3B_CANONICAL_SUPPORT_INTAKE_RECEIPT` is verified at exact commit
`0185b2a0f05f6181f8975a48a4f96d0811681e8b` and exact successful GitHub Actions
run `32503031376`. It addresses `SUP-016` by connecting the Flutter intake to
the authenticated canonical support-case route. Invalid or unavailable
receipts remain fail-closed; no external message or live case action occurs.

`S3C_CANONICAL_HELP_CENTER_ENTRY` is verified at exact commit
`044c5e04522e0d1b5946b732a8090c3f3b2242b9` and exact successful GitHub Actions
run `32504712378`. It removes the Help Center's legacy local-only support
success claim and routes bounded free text through the safety-first canonical
intake. No external message or live case action occurs.

`S3D_USER_SUPPORT_CASE_LIST_DETAIL` is verified at exact commit
`61cd3ad8ef6ab178eee5305d1654c291d8c5a40f` and exact successful GitHub
Actions run `32506977131`. It connects the
existing authenticated user case-list and detail endpoints to a read-only
Flutter surface under the Help Center. Raw lifecycle/type/event codes are never
shown; unknown states fail closed. It addresses `SUP-143` and the accessibility
foundation for `SUP-146` through `SUP-148`.

`S3E_USER_ACTION_DEADLINE` is verified at exact commit
`2d01bebb24c884cf1358bd0e1cc606d8ad8ec536` and exact successful GitHub
Actions run `32508816204`. It addresses `SUP-144` with
a distinct server-authoritative deadline required exactly while a case is
`waiting_for_user`. Reversible migration `034`, append-only audit evidence and
the user-safe Flutter projection preserve the difference between `Antwort bis`
and `Nächstes Update`. Automatic reminders, timeout closure and external action
remain excluded.

`S3F_FINAL_SUPPORT_DECISION_PUBLICATION` is technically verified at exact
commit `1cff1763b316c1c0a3008219f7c88a0dc0028dac` and successful GitHub Actions
run `32512521575`. Migration `035`, Backend/PostgreSQL, Flutter, Web and Android
debug checks passed; the signed-candidate step and publication remained
skipped.

`S3G_CLOSED_CASE_APPEAL_SUBMISSION` is technically verified at exact commit
`966e374fe44af13bbbbfb92202e58b328e80a905` and exact successful GitHub Actions
run `32515722756`. It addresses the bounded technical path behind `SUP-151` and
the submission portion of `SUP-014`/template `T-042`: an explicitly configured,
exact server deadline; one authenticated reporter submission per published
decision; a separate review reference and next-update checkpoint; append-only
receipt/audit truth; and a fail-closed Flutter surface. All 404 Backend tests,
including PostgreSQL 16, and 343 Flutter tests passed with the documented
Flutter skip; Web and Android debug builds passed. The signed-candidate and
publication jobs remained skipped. S3G does not adjudicate the appeal, reopen a
case automatically, render or send a template, or execute any external or live
measure. Missing policy dates remain missing and are never invented.

`S3H_SUPPORT_BREAK_GLASS_ACCESS` is technically verified at exact
implementation/evidence commit
`cfb9a3377c432efb2d3c76620c35cb24623dd5e6` and successful GitHub Actions run
`32520795019`. It addresses Drive matrix scenarios `SUP-024` and `SUP-025` with a
P0-only, case/actor/session/step-up-bound grant of at most five minutes,
digest-only token storage, complete sanitized audit and an automatic independent
Admin review due at expiry. The exact reviewer session and Staff-Step-up are
persisted. User export receives only a safe transparency projection; the full
truth is inventoried as `securityAudit`. No incident-wide authority is inferred,
because no canonical incident binding exists. All 415 Backend tests including
PostgreSQL 16 passed; dependency/secret/Compose/API-image checks passed. The
same run passed the 343-test Flutter suite with one documented skip, the
separate Google-only test, Web build and loopback smoke, and Android debug
build. Signed-candidate, publication, merge and live paths remained skipped.

`S3I_GUARDED_SUPPORT_TEMPLATE_PUBLICATION` is technically verified at exact
implementation/evidence commit
`f8c596f2c555b1431720d8240f23dffe8770e936` and successful GitHub Actions run
`32525140426`. It imports and hash-binds the exact 55-template Drive catalog,
renders available case facts server-side in `Europe/Berlin`, blocks unresolved
placeholders and recognizable sensitive or unsafe claims, limits immediate
GREEN publication to an explicit case-state allowlist, and requires independent
exact-hash Admin review for YELLOW content. Migration `038` makes rendered,
approval and correction truth immutable and append-only. Publication is an
authenticated in-app record only; no email, push, provider or live action is
called. All 426 Backend tests including PostgreSQL 16, 345 Flutter tests with
one documented skip, Web, Android debug, dependency/secret/Compose and API-image
checks passed. RED, money and unavailable-server-binding templates remain on
HOLD for their dedicated workflows.

`S3J_SUPPORT_DEADLINE_WATCHDOG` is technically verified at exact
implementation/evidence commit
`7a8d7bb92f0c095a0561f0bb4e23500aa65f5866` and successful GitHub Actions run
`32528304577`. It addresses the internal technical core of Drive scenarios
`SUP-041`, `SUP-142`, `SUP-158`, `SUP-159` and `SUP-160`: one condition-bound
append-only alert for an unassigned active P0 case, one for an overdue next
update, duplicate-safe recurring evaluation, persisted worker health and
fail-closed message publication when a promised checkpoint has expired.
Migration `039` stores only aggregate worker state and indexes the two internal
event types. The active queue requires admin role plus Staff-Step-up, is
PII-minimized and sends zero external notifications. All 433 Backend tests,
including PostgreSQL 16, and the complete 345-test Flutter suite with one
documented skip, Web smoke/build and Android debug build passed. No owner,
deadline or case state is changed automatically; no external delivery,
production, payment, Store, signed candidate or live operation is enabled.

`S3K_SUPPORT_SINGLE_ISSUE_INTAKE` is technically verified at exact
implementation/evidence commit
`ca3f952b2621441028e560b4b76f17ba43d2f2ba` and successful GitHub Actions run
`32530748881`. It addresses Drive scenario `SUP-026`: safety triage stays first,
then a versioned confirmation blocks categories and submission until the
current case contains exactly one independently reviewable problem. A
multiple-problem answer requires separation guidance before the user may choose
one problem for this case. Migration `040` leaves legacy rows explicit, requires
the exact evidence on every new case and rejects later mutation. The server
uses no text classifier or inferred split. All 435 Backend tests, including
PostgreSQL 16, and the complete 346-test Flutter suite with one documented
skip, Web smoke/build and Android debug build passed. No linked case is invented
and no external delivery, production, payment, Store, signed candidate or live
operation is enabled.

`S3L_SUPPORT_PRIVACY_INTAKE_ROUTE` is technically verified at exact
implementation/evidence commit
`57ca7b016cae3447edaea352cb919dab99c390ae` and successful GitHub Actions run
`32532443847`. It addresses Drive scenario `SUP-028`: after safety and
single-issue triage, the normal support flow exposes all seven canonical
Privacy request types under `Datenschutz & Daten`. Submission creates a
separate `privacy_security` case; the server deterministically assigns
`privacy_owner`, a red decision boundary and a bounded operational update
checkpoint. The user receipt is accepted only when server-confirmed case type
and subtype equal the selected route, then identifies the separate Privacy
path and the exact next-update display. All 436 Backend tests and the complete
348-test Flutter suite with one documented skip, Web smoke/build and Android
debug build passed. No semantic text classifier, statutory deadline, external
delivery, production, payment, Store, signed candidate or live operation is
enabled.

`S3M_SUPPORT_ACCOUNT_DELETION_ACCESS_SEPARATION` is technically verified at
exact commit `6d8eb4856e46d6ce171ce8caa20479884a3d3498` and successful GitHub
Actions run `32533886775`. It addresses Drive scenario `SUP-029`: support
cases are disclosed as retained records instead of being treated as generic
account-deletion blockers, but active legal holds continue to block deletion.
The user must separately acknowledge this retention boundary. Successful
account deletion ends sessions and app access while pseudonymous case and
audit history remain controlled. Both the workflow and PostgreSQL migration
`041` reject creation or publication of new support messages to a closed
account. History replay remains read-only and idempotent. All 439 Backend tests
including PostgreSQL 16 and the complete 348-test Flutter suite with one
documented skip, Web smoke/build and Android debug build passed. No legal
retention period, external delivery, production, payment, Store, signed
candidate or live operation is enabled.

`S3N_SEPARATE_DSA_NOTICE_INTAKE` is technically verified at exact
implementation commit `c7b74ea0af919362a9706ebf23371a555b3986f5`, CI
fixture-isolation commit `a5e33c3f2a6eb61b739018ef5d4ca15777602bba` and
successful GitHub Actions run `32536618516`. It addresses Drive scenario
`SUP-027`: the authenticated app exposes a distinct illegal-content route,
requires versioned structured evidence and derives reporter identity from the
server. PostgreSQL migration `042` binds one opaque Notice ID to an immutable
evidence snapshot. User/API/event projections are minimized and full evidence
is privacy-exported only for the reporter. Intake and routing are deterministic,
but every illegality or content-measure decision remains an explicit human red
decision. All 445 Backend tests including PostgreSQL 16 and the complete
352-test Flutter suite with one documented skip, Web smoke/build and Android
debug build passed. Public/guest accessibility, legal/operator approval,
Statement of Reasons delivery, production, payment, Store, signed candidate
and live operation remain closed.

`S3O_DSA_NOTICE_LOCATOR_COMPLETION` is technically verified at exact
implementation commit `0c8724c3ba05b4b2afd8622087ae00970b573a8e` and
successful GitHub Actions run `32539524697`. It addresses Drive scenarios
`SUP-113` and `SUP-114`: a valid DSA notice now receives its Notice ID and
immutable receipt before locator completeness review. Missing or descriptive
locator input is retained as `needs_clarification` with a targeted
reporter-only prompt. The reporter may later append one exact, version-bound
locator without overwriting the original evidence. Migration `043` makes the
amendment append-only and independently guards the derived completion state.
All 449 Backend tests including PostgreSQL 16.14 and the complete 354-test
Flutter suite with one documented skip passed; the separate Google-only test,
Web smoke/build and Android debug build also passed. Locator classification is
a completeness signal only and cannot decide illegality or execute a content
measure. Public/guest access, legal/operator approval, production, payment,
Store, signed candidate and live operation remain closed.

`S3P_MODERATION_STATEMENT_OF_REASONS` is technically verified at exact
implementation commit `079dc0e139437a2c8b1732a5cd77a826b892d8c4`, follow-up
rate-limit isolation commit `23b9cb84e0286215661e78ac67638eeedcd819d4` and
successful GitHub Actions run `32542904176`. It addresses Drive scenarios
`SUP-115` through `SUP-118`: every new significant account,
function, listing or private-marketplace restriction and every reversal must
commit one versioned, append-only Statement of Reasons with exact facts, basis,
reasoning, origin, scope, duration and automation role. Migration `044`
independently rejects a significant decision without its Statement and binds
the human reviewer to the issuing Administrator. The authenticated user
surface fails closed for incomplete legacy evidence but preserves the existing
free electronic review route. All 456 Backend tests passed without skips on
PostgreSQL 16.14; the complete 358-test Flutter suite passed with one documented
skip together with the separate Google-only test, Web smoke/build, Android
debug build, dependency/history checks, Compose validation and the API image
build. The private signed-candidate step was not executed. Historical facts are
not invented; independent review assignment, correction workflow,
legal/operator approval, external transparency reporting, production, payment,
Store, signed candidate and live operation remain closed.

`S3Q_INDEPENDENT_MODERATION_REVIEW_CORRECTION` is technically verified at
implementation commit `b3d122bb0dc0a4377d6311aa4798c5f3367bfabf`,
migration-syntax correction `339db52e7577ac7f7711fbd963f7031a98934830`,
privacy-export correction and verified head
`6c58d33456885e2470e858a708297d7aa37832d8`, with successful GitHub Actions run
`32545973414`. It
addresses Drive scenarios `SUP-119` and `SUP-120`: only an active Administrator
other than the original decision issuer may claim and resolve a review, every
outcome is explicitly human-only and append-only, and `modified` or `reversed`
requires an applied correction plus a new S3P-complete decision and Statement
of Reasons in the same transaction. The affected user receives the exact
outcome, reason and implementation truth without reviewer identity. The local
exact-head CI applied all migrations through `045` on PostgreSQL 16.14 and
passed all 459 Backend tests without skips. Pinned Flutter 3.41.7 passed 359
tests with one documented skip together with the separate Google-only test,
Web smoke/build and Android debug build; dependency/history checks, Compose
validation and the commit-labelled API image build passed. The conditional
signed-candidate and API-image publication steps were skipped, and Draft PR #7
remained open and unmerged. Listing and private-marketplace corrections support bounded
modification or reversal; active suspensions support reversal only. Suspension
modification and report-resolution correction fail closed. Legal/operator
approval, real staffing, external delivery, production, payment, Store, signed
candidate and live operation remain closed.

`S3R_SUPPORT_ARTICLE18_AUTHORITY_REFERRAL_GUARD` is technically verified at
exact implementation head `3497a887d31935560c1371a13e92fee2def21344` and
successful GitHub Actions run `32548790305`. It addresses Drive scenarios
`SUP-121` and `SUP-122`: qualifying non-live P0 Trust & Safety cases enter a
minimal Administrator-only candidate queue, while only an active elevated
Administrator may append a human assessment with explicit jurisdiction route,
symbolic evidence references, minimum information scope and reviewer
authorization evidence. The flag is conservative triage, not a criminal or
reporting finding. Migration `046` and the application keep the assessment
append-only, omit restricted facts from normal audit and self-service export,
and reject unsafe rollback. Normal support is denied and even an Administrator
cannot dispatch externally: no provider, channel, address or sent state exists.
Dedicated intake and Article 18 rate-limit buckets prevent interference with
unrelated account-security operations. Exact-head CI passed all 468 Backend
tests without skips on PostgreSQL 16.14 and all migrations through `046`; 359
Flutter tests passed with one documented skip plus the separate Google-only
test, Web smoke/build and Android debug build. Dependency/history, Compose and
the commit-labelled API image build passed. Signed-candidate construction and
API-image publication were skipped. Professional legal approval, named real
owners, authenticated competent-authority channel, approved disclosure scope,
retention/legal hold, external reporting, production, payment, Store and all
live operation remain closed.

`S3S_SUPPORT_PRIVACY_RIGHTS_CONTROL_PLANE` is a locally and CI-verified
non-live package based on Drive scenarios `SUP-123` through `SUP-127` at exact
implementation commit `60b8017c00a63d18dd3d6887cfab3baee1f0fafb`.
Flutter now submits
one exact versioned right instead of combining access/portability,
rectification/erasure or objection/restriction. Migration `047` records the
request from receipt, a conservative Europe/Berlin calendar-month deadline,
72-hour internal reminder, append-only account-password identity evidence and
at most one reasoned two-additional-month extension behind Administrator
Staff-Step-up. Identity verification never shifts the deadline. User and staff
projections keep disclosure, erasure execution and external delivery false.
The new Privacy retention category remains the tenth open decision with no
invented period or purge. Focused technical checks, the full Backend unit run
and the previously skipped foundation integration against isolated PostgreSQL
16.15 are green. The complete local technical regression is also green: 359
Flutter tests with one documented skip, the separate Google-only profile test,
Web smoke/build and Android debug build passed. A CI-equivalent Backend run
passed all 471 tests without skips on isolated PostgreSQL 16.15 with every
migration through `047`. GitHub regression `32551835411` is green for head
`60b8017c00a63d18dd3d6887cfab3baee1f0fafb`; Actions tested the PR merge
snapshot `57e987471a770e222b91d47ea8e1e141bf3ceb23`. CI passed all 471 Backend
tests, audit/secret checks, Compose validation, the commit-labelled API image,
359 Flutter tests with one documented skip, the separate Google-only test,
Web smoke/build and Android debug build. Signed-candidate construction and API
image publication remained skipped.
Actual rights execution and delivery, scoped Legal Hold
resolution, professional review, and `SUP-128` through `SUP-131` remain
separate gates; production, payment, Store and every live path remain closed.

`S3T_SUPPORT_PRIVACY_INCIDENT_EXPORT_GUARD` is a locally and CI-verified
non-live package for the technical core of Drive scenarios `SUP-128` through
`SUP-131` at exact implementation commit
`cb8d378acf6cc2617386ed945e128aab41de5bff`. Migration `048` creates an immutable
awareness-bound incident record for three exact Privacy subtypes, fixes the
internal decision deadline to awareness plus 72 hours and allows only
Administrator/active-session/Staff-Step-up-bound non-live containment evidence.
The watchdog creates idempotent internal near/overdue alarms but has no external
transport or notification state. Account export is now an exact POST requiring
current-password re-authentication, takes its subject only from the active
session and minimizes inbound third-party structured exact locations while
retaining the subject's own structured location. Safe incident metadata is
exported; containment actions and internal identifiers are not. All 473
Backend tests passed without skips against isolated PostgreSQL 16.15 through
migration `048`; Privacy/Retention protections, the accepted analyzer baseline,
359 Flutter tests with one documented skip, the separate Google-only test, Web
smoke/build and Android debug build passed. The prior internal AAB `2026081509`
is absent from this Mac mini's private archive, so only CI-metadata validation
was performed; no artifact was created or changed. GitHub regression
`32553740248` is green for that exact implementation head and PR merge snapshot
`990015e391d38a26fe8e1f6682db3d219d4d0ae5`. Backend passed all 473 tests,
migrations through `048`, dependency/history audit, Compose and the
commit-labelled API image build; Flutter passed the complete technical script.
Signed-candidate construction and API-image publication remained skipped, and
Draft PR #7 remained open and unmerged. Human breach assessment,
legal/controller notification decisions, authority and recipient channels,
professional review, real staffing, production, payment, Store and every live
path remain closed.

## Prior ordered post-P0B gate close

## Gate progress

1. `P0B_NEXT_LEGAL_V52_REVIEW_ONLY`: intake package technically complete;
   independent professional review, operator facts and PSP contract remain
   external hard blockers. Exact package:
   `assets/legal/de/legal_review_intake_p0b_20260821.json`.
2. `P0B_NEXT_OPS_ROLES_BACKUP_ABSENCE_ONLY`: technical gate complete; four of
   four synthetic configuration rehearsals pass, but zero of six real role
   assignments and zero of four human 72-hour absence tests are evidenced.
3. `P0B_NEXT_SIGNED_DEVICE_EVIDENCE_ONLY`: Android current-source candidate,
   private archive, non-destructive Pixel update, installed-byte match and cold
   launch passed; exact source CI `32459509278` is green. iOS is blocked by
   missing full Xcode/CocoaPods and unverified physical iOS device; combined
   gate remains partial.
4. `P0B_NEXT_PSP_SANDBOX_E2E_ONLY`: fail-closed preflight and executable gate
   complete. No executed provider contract, approved marketplace product,
   provider sandbox acceptance, credentials or legal/privacy facts were found;
   therefore zero provider calls and zero of eight provider E2E scenarios ran.
5. `P0B_NEXT_INVITED_SYNTHETIC_PILOT_SPIEGELBERG_CAT8_30`: exact non-live
   envelope and runbook prepared. All four prerequisite gates remain false, so
   `spiegelberg` stays unconfigured; no roster, personal data, accounts,
   invites, listings or participant flow was created.

Independent safe work continues when an external dependency is missing. No
blocked gate is bypassed or silently marked complete.

All five ordered packages have now been processed to the maximum safe local
state. External legal, human-operations, iOS/device and contracted-provider
facts remain explicit HOLD conditions rather than inferred successes.

## Post-continuation closeout

- Exact implementation/evidence head: `cc4cf2454395acb4ab0202700ff4cb241ad0f43d`.
- GitHub Actions run `32461470531` completed successfully for that exact head:
  backend regression and Flutter regression passed; the production image publish
  job and signed-candidate job remained skipped by their closed gates.
- GitGuardian completed successfully, draft PR #7 remained mergeable and no
  merge or release action occurred.
- The local branch and its remote were synchronized with a clean working tree
  before this documentation closeout.
- Drive folder `00_CODEX_AKTUELL_AB_2026-08-20` was checked again on
  21.08.2026. Its newest command remains
  `00_NEXT_COMMAND_G3A_APPROVED_V2.4.txt`; no later runway authorization exists.
- The unresolved end-of-runway decision is recorded in
  `docs/SIT_PENDING_GATE_P0B_NEXT_RUNWAY.md`.

## Prior P0B close evidence

At that recorded close, **P0B-READINESS is the end of the V2.4** runway. There is no
automatic continuation after it. The active continuation documented above
comes only from Walid's later explicit authorization on 21.08.2026; it does
not retroactively change the P0B dossier.

- P0B implementation commit:
  `84ab2b587565baaf56b10791ea9b6bf3beb8591e`.
- Green GitHub Actions run: `32434902386`.
- GitHub synthetic PR merge:
  `65235f901c8fbc092394f2ca7da42562589a1c6c`.
- Draft PR #7 remains open, Draft and unmerged.
- Machine result: `decision=no_go_now`, 13 feature entries, ten blockers, two
  residual risks, five recommended tokens, `realMoney=false` and
  `autoContinue=false`.

## Persistent boundary

The prior P0B dossier itself activated nothing. The new authorization is
bounded to the ordered gate work and still does not authorize production,
VPS/OpenClaw, Maximus, SSH, DNS, Cloud, Store submission, real money or public
activation. Signed-candidate and provider-sandbox work may occur only inside
their later named gates and with their own preserved-data/fail-closed rules.

G3 booking groups, G4 planner/inventory, G5 supply enrichment and listing sets
remain disabled and production-rejected. The recommended future Spiegelberg
cohort and its region code remain unconfigured. No signed candidate was built,
no artifact was published and installed Pixel data remains preserved.

## Decision result

**NO-GO now.** Green technical CI does not satisfy the open professional legal,
operator/provider, payment sandbox, signed-device, staffing/absence, unit
economics, Privacy/Retention/Store and explicit activation gates.

The detailed dossier is
`docs/operations/P0B_PILOT_GO_NO_GO_DOSSIER.md`; the machine-readable source is
`docs/evidence/p0b/pilot-go-no-go-dossier.json`.

## Originally recommended tokens

1. `P0B_NEXT_LEGAL_V52_REVIEW_ONLY`
2. `P0B_NEXT_OPS_ROLES_BACKUP_ABSENCE_ONLY`
3. `P0B_NEXT_SIGNED_DEVICE_EVIDENCE_ONLY`
4. `P0B_NEXT_PSP_SANDBOX_E2E_ONLY`
5. `P0B_NEXT_INVITED_SYNTHETIC_PILOT_SPIEGELBERG_CAT8_30`

They are no longer authorization by inference: Walid explicitly authorized the
ordered continuation on 21.08.2026. Their substantive prerequisites remain
unchanged.

## S3U support AI and VSBG launch gates

`S3U_SUPPORT_AI_VSBG_LAUNCH_GATES` is locally and CI-verified at exact
implementation commit `4366a1b84d795d6c68a686284d9ae0ee74107b49` and
successful GitHub Actions run `32556439261`. It addresses Drive matrix
scenarios `SUP-132` through `SUP-136` without opening a live lane:

- direct and external AI remain unavailable and transport-free;
- any future direct AI chat requires a separate transparency/privacy/provider
  package rather than a flag change;
- VSBG configuration is shared, explicit and default-closed across app,
  Backend, Compose examples and Android build inputs;
- unresolved/TBD facts block public compliance and Store preflight;
- T-053 alone has an Administrator-only, independent exact-hash RED review and
  authenticated in-app publication path with all regulated values server-bound;
- old EU ODR links fail static and release validation.

Local final gates passed: 482 Backend/PostgreSQL tests through migration `048`,
361 Flutter tests plus one documented skip, the Google-only test, accepted
220-issue analyzer baseline, 58 Privacy/Retention protection tests, Legal/P0B
hold checks, Web debug/smoke and Android debug APK. CI repeated those gates for
PR merge snapshot `4b8ba3ca718dfbea8c9a658a0ccff31eb764c3e3`, passed all 482
Backend tests without skips and kept signed-candidate construction and API-image
publication skipped. Professional legal review, operator facts,
competent-body approval, real support staffing, external delivery, production,
payment, Store, signed-candidate and every live path remain closed. Autonomous
work continues next with `SUP-137` after the evidence-only head is green.

## S3V product-safety contact and rapid triage

`S3V_SUPPORT_PRODUCT_SAFETY_CONTACT_TRIAGE` is locally and CI-verified for
Drive scenario `SUP-137` at exact implementation commit
`c71c263f785b5305800706a5129a321a00f76937` and successful GitHub Actions run
`32558511471`. The app and Backend now accept one versioned structured
product-safety notice on the exact `trust_safety/dangerous_item_or_injury`
route, require emergency-first safety acknowledgement and return an opaque
`SIT-P-*` receipt with a database-enforced candidate triage checkpoint no later
than 60 minutes after receipt. Migration `049` preserves immutable evidence and
blocks unsafe rollback.

Public/Store readiness remains closed until the consumer contact, authority and
Safety Gate registrations, internal process and approval version are all real
and approved. The package contains no external transport, report, Safety Gate
submission, automatic listing/account action, production configuration or live
operation. The prepared Google Play Data Safety truth now includes optional
injury information as Health info: 17 of 18 reviewed types are selected, but
the matrix remains unsaved and no console action occurred.

Local verification passed 488 Backend unit tests with one environment-only
PostgreSQL skip, the separate isolated PostgreSQL 16.15 foundation integration
through migration `049`, the accepted 220-issue analyzer baseline, 363 Flutter
tests with one documented skip, the separate Google-only test, Web smoke/build
and Android debug APK. P0B PSP and invited-pilot gates remain HOLD/NO-GO after
source-hash refresh only. Professional legal review, real registrations,
staffing, external delivery, production, payment, Store, signed candidate and
all live paths remain closed. CI passed 489 Backend/PostgreSQL tests without
skips and the complete Flutter regression for PR merge snapshot
`bdfea22d35d2cf6b39486318563d8fbd0f2ddaae`; signed-candidate construction
and API-image publication remained skipped, and Draft PR #7 stayed open,
mergeable and unmerged.

## S3W support notification and authenticated routing

`S3W_SUPPORT_NOTIFICATION_AUTHENTICATED_ROUTING` is a locally and CI-verified
non-live package for Drive scenarios `SUP-138` through `SUP-142` at exact
implementation commit `452575c1c06aaf2502573fb1bf7d95724c9b024d`. Published
support messages schedule one generic in-app and Push update,
the external payload contains no identifier or sensitive case content, the
Push opens only the authenticated notification feed, and the case is then
re-fetched through the canonical user-bound endpoint. Lost access produces a
single generic fallback without cached data. Duplicate evaluation is absorbed
by the existing outbox uniqueness constraint.

The complete Backend unit run passes 492 tests with one expected
PostgreSQL-environment skip. Privacy/Retention validators and focused Flutter
tests are green. The complete local technical regression is also green: the
accepted 220-issue analyzer baseline, 365 Flutter tests with one documented
Google-profile skip, the separate Google-only profile test, Web build/loopback
smoke and Android debug APK build all pass. Exact implementation commit and
GitHub CI evidence are recorded by green run `32559993743` for PR merge
snapshot `5f60270857e8417b59ed9a5b5b4a777f72128ad2`: all 493
Backend/PostgreSQL tests passed without skips and the Flutter results repeated.
The signed candidate and API-image publication jobs were skipped; Draft PR #7
remained open, mergeable and unmerged. No live FCM, provider call, production,
payment, Store, signed candidate, deployment, merge or public pilot is enabled.

## S3X support case UI accessibility

`S3X_SUPPORT_CASE_UI_ACCESSIBILITY` is locally and CI-verified at exact
implementation commit `3f96e93e721dcf5daef948ca7370856511293829` for Drive
scenarios `SUP-143` through `SUP-152`. The existing canonical list/detail,
waiting-user deadline, published decision, appeal path and blocked-user filter
are retained. The UI now binds readable German status text, prominent action,
five-part decision meaning, widget-order keyboard traversal, labelled
semantics, headings, two-times text scaling, a 48 logical-pixel case-card
target and conditional `Blockiert` behavior to automated tests.

Focused checks pass 19 Flutter widget tests and three static matrix/wiring
tests; 58 Privacy/Retention protection tests and both source validators are
green. The complete local technical regression passes the accepted 220-issue
analyzer baseline, 367 Flutter tests with one documented Google-profile skip,
the separate Google-only test, Web build/loopback smoke and Android debug APK.
GitHub run `32561101446` repeated those gates for PR merge snapshot
`051f0da94e4a7b81900b54429628ce3a489687c5` and passed 493
Backend/PostgreSQL tests without skips. Signed-candidate construction and
API-image publication were skipped; Draft PR #7 stayed open, mergeable and
unmerged. No manual TalkBack/VoiceOver device pass, signed candidate, Store,
production, payment, deployment, merge or public action is claimed or enabled.

## S3Y support operational metrics and crash privacy

`S3Y_SUPPORT_OPERATIONAL_METRICS_CRASH_PRIVACY_GUARDS` is locally and CI-verified
at exact implementation commit
`c4a02ec441e85137187352c71a479f6ad3462bd2` for Drive scenarios `SUP-165`
through `SUP-167`. A new
Administrator/Staff-Step-up route computes only aggregate simulation/internal
testing metrics. Reopen rate uses the distinct closed-case cohort in a bounded
window; late-update rate is a labelled current active-case snapshot. The
response contains no row IDs, user fields or free text and has no external
analytics transport.

Crashlytics collection is centralized behind release mode plus the independent
persisted user choice. The bounded staging diagnostic can set only four
release-mapping keys through one allowlist helper, and Firebase user identifiers
remain absent. The Backend unit suite passes 496 tests with one expected
PostgreSQL-environment skip. The complete technical regression passes the
accepted analyzer baseline, 369 Flutter tests with one documented skip,
separate Google-only test, Web smoke and Android debug build. GitHub run
`32562949550` repeated those gates for PR merge snapshot
`92c6737e87b2dbdb4540002bf272c66153f7c61e` and passed all 497
Backend/PostgreSQL tests without skips. Signed-candidate construction and
API-image publication were skipped; Draft PR #7 remained open, mergeable and
unmerged. No live Firebase, production, payment, Store, signed candidate,
deployment, merge or public action is enabled.

## S3Z legacy support history migration

`S3Z_SUPPORT_LEGACY_HISTORY_MIGRATION` implements the non-live portion of Drive
scenarios `SUP-153` through `SUP-157` at exact commit
`c73cf25065c2c2ad568613e1b89cfee504969381`. It adds an aggregate preview and a
separate explicit, idempotent import from exactly
`local_shared_preferences_message_threads_v1`; the source is always treated as
unverified user-device data and is prohibited from decision-evidence use.
Open threads map to `acknowledged`; paused threads require an explicit reason
and supported target state. Archived, unsafe and already-canonical histories
are blocked.

Migration `050` records the source import and exact ordered history under
append-only database guards. A deterministic fingerprint and PostgreSQL
advisory lock converge sequential and concurrent retries on one canonical
simulation case. Reporter-only history, privacy export, count-only Retention
inventory and a privileged dry-run rollback preview are wired. The local old
thread is read-only with no generic template, presence or composer. The
feature defaults off and production startup rejects enablement.

Local verification passes 15 focused tests, exact PostgreSQL 16 migration and
integration coverage, all 504 Backend/PostgreSQL tests without skips, both
Privacy/Retention validators and 58 protection tests. The full local technical
regression passes the accepted analyzer baseline, 369 Flutter tests with one
documented skip, separate Google-only coverage, Web build/smoke and Android
debug APK. GitHub Actions run `32564821610` repeated all Backend and Flutter
gates successfully for PR merge snapshot
`c812fe5c53c326e8a3c1e5f81d55de68d71f88df`. Signed-candidate construction
and API-image publication were skipped; Draft PR #7 remained open, mergeable
and unmerged. No production data, external message, Payment, Store, Firebase
Console, Cloud/VPS/DNS, deployment, PR merge or public activation is authorized
or performed.

## S4A private support evidence security

`S4A_SUPPORT_EVIDENCE_SECURITY` is locally verified at exact implementation
commit `06cef70fda31e2f83e621fc367909366b7277390` for Drive scenarios
`SUP-099` through `SUP-105`. It accepts only magic-byte-detected JPEG/PNG/WebP,
ignores client filenames, rejects active markup, quarantines the deterministic
malware fixture and keeps an immutable hashed original separate from its
re-encoded WebP preview. Original bytes have no retrieval route.

Preview access requires one terminal clean result plus a digest-only token bound
to the exact active user/session, current case participation and a schema-capped
five-minute lifetime. Expired and forwarded tokens fail closed; every response
rechecks the preview bytes and SHA-256. Privacy export and Retention inventory
cover safe metadata without paths, filenames, tokens or invented purge periods.
External AI and external scanner traffic are structurally absent.

The intake flag defaults off and is rejected in production. Twelve focused
tests, 17 Privacy tests, 41 Retention tests, fresh PostgreSQL 16 migration/route
integration, the full backend unit run, accepted 220-issue analyzer baseline,
369 Flutter tests with one documented skip, the separate Google-only test, Web
build/smoke, Android debug build and secret scan are green locally. GitHub push
and CI are pending because the stored GitHub CLI HTTPS credential expired; no
new OAuth credential or SSH trust was created. Draft PR #7 remains unmerged and
no production, real scanner, external AI, Payment, Store, Firebase Console,
Cloud/VPS/DNS, signed candidate or public action was performed.

## S4B support Trust & Safety guards

`S4B_SUPPORT_TRUST_SAFETY_GUARDS` is locally verified at exact implementation
commit `baa5dcc568eb55964fbc7bf3d803a7e11d9b081a` for Drive scenarios
`SUP-106` through `SUP-112`. An elevated Administrator can record one bounded,
immutable impact review for the exact prohibited/dangerous-item case types. It
captures the linked listing and deterministic current/historical booking scope,
excludes address, amount and participant identity, and executes no measure.

A subsequent support decision must bind the newest review, exact case version
and recommendation identifier, recheck unchanged current scope and enumerate
the listing plus every action-relevant booking. Protected safety intake has a
separate bounded limiter; blocked direct messaging remains denied while the
canonical authenticated safety route works. Raw exception messages/objects are
removed from covered operational logs, and audit/review update or deletion is
rejected.

Local verification passed 60 focused tests, 106 Privacy/Retention tests and
validators, all 515 backend unit tests with one expected no-database skip, and
the separate isolated PostgreSQL 16 integration through migration `052`. The
complete technical regression passed the accepted analyzer baseline, 369
Flutter tests with one documented skip, separate Google-only coverage, Web
build/smoke and Android debug APK. GitHub push/CI remains pending because the
stored HTTPS credential expired; no new trust was created. Real measures,
authority/external delivery, production, Payment, Store, signed candidate,
deployment, merge and public activation remain closed.

## S4C support duplicate-case linking

`S4C_SUPPORT_DUPLICATE_CASE_LINKING` implements the non-live portion of Drive
scenario `SUP-015` at exact commit
`b0b5b77d4d793b82c71f40378eac7d0a9977753c`. An elevated Administrator must
confirm five explicit duplicate conditions and exact current scope/version
before migration `053` accepts one append-only `duplicate_of` relationship.
Privacy, DSA/moderation and legal-authority cases remain separate.

The link creates a user-visible leading-case reference and an internal reverse
reference but updates neither case, transfers no history and executes no action
or external delivery. `duplicate_merged` closure is guarded by the immutable
link and visible event; the leading case stays unchanged. Privacy export,
Retention inventory, SHA evidence, append-only triggers and rollback refusal
cover the durable relationship.

Local verification passes 35 focused tests, 58 Privacy/Retention protection
tests plus three S4C wiring tests, 521 backend tests with one expected
no-database skip, fresh PostgreSQL 16 migration/HTTP integration through `053`,
the accepted 220-issue analyzer baseline, 369 Flutter tests with one documented
skip, separate Google-only coverage, Web build/smoke and Android debug APK.
P0B PSP and invited-pilot evidence remains HOLD/NO-GO. GitHub push/CI is not
claimed here. No real merge, external message, production, Payment, Store,
signed candidate, deployment, PR merge or public activation is enabled.

## S4D support feedback priority

`S4D_SUPPORT_FEEDBACK_PRIORITY` implements the non-live portion of Drive
scenario `SUP-030` at exact commit
`523d987480c96c7f9cb2338057880680994282a7`. Explicitly non-urgent improvement
suggestions, explanations and general feedback use the canonical
`general_help/feedback_or_improvement` route with an exact versioned product
area context, P4, low severity and a 24-hour internal checkpoint.

Flutter presents ten bounded choices and verifies the exact server receipt.
Urgent risk signals fail closed into a dedicated route, while booking, listing,
payment, refund and payout links are prohibited. The receipt confirms capture
without promising escalation or a product decision. Migration `054` makes the
context immutable and database-enforced; audit, reporter export, Retention
inventory and guarded rollback preserve the evidence without an external
delivery or product-system adapter.

Local verification passes 59 focused Backend/wiring tests, 19 focused Flutter
tests, 61 Privacy/Retention protection tests and validators, fresh PostgreSQL
16 integration through migration `054`, and the complete Backend run with 524
passes plus one expected no-database skip. The full technical regression passes
the accepted 220-issue analyzer baseline, 370 Flutter tests with one documented
skip, separate Google-only coverage, Web build/loopback smoke and Android debug
APK. P0B PSP and invited-pilot gates remain HOLD/NO-GO. GitHub push/CI is not
claimed here. No live support, production, Payment, Store, Cloud/VPS/DNS,
signed candidate, deployment, PR merge or public activation is enabled.

## S4E reviewed support progress updates

`S4E_SUPPORT_PROGRESS_UPDATES` implements the non-live portion of Drive
scenarios `SUP-042` and `SUP-043` at exact commit
`018b39dd44dc25e2503982b8bec801282ceac770`. One version-bound proposal derives
`T-008` while the prior checkpoint is current and `T-010` after it is overdue.
It requires concrete progress, open work, user action/no action, provisional
impact, next action and a bounded later checkpoint without inventing an outcome.

Direct generic progress drafting and publication are blocked. An independent
Administrator must approve the immutable message hash; dedicated publication
then atomically updates the case, records the authenticated in-app message and
appends proposal/event/audit truth. Migration `055` is lifecycle-guarded and
append-only. Privacy export omits internal action/staff identity, Retention stays
draft/non-destructive and rollback refuses retained evidence. There is no
external delivery path.

Focused and Privacy/Retention tests, fresh PostgreSQL 16 integration, 533
Backend tests plus one expected skip, accepted analyzer baseline, 370 Flutter
tests with one documented skip, separate Google-only coverage, Web build/smoke
and Android debug APK are green locally. P0B remains HOLD/NO-GO. GitHub push/CI
is pending because the stored CLI credential is expired. No live support,
production, Payment, Store, Cloud/VPS/DNS, signed candidate, deployment, PR
merge or public activation is enabled.

## V2.4 portfolio checkpoint before the next gap

`docs/architecture/v2-4-portfolio-checkpoint-2026-08-22.md` is the authoritative
post-S4E portfolio audit. All twelve requested packages are `DONE` for their
bounded repository deliverables, with exact implementation and close commits.
The classification is deliberately separate from live readiness: G3L legal
approval, FI1 real assignments/delegates/absence tests, P0A external readiness
and P0B's ten `NO-GO` blockers remain open gates.

Because no Growth-Core package is `PARTIAL` or `OPEN`, the next package is the
highest-risk uncovered Support Matrix scenario that can be completed locally
without inventing an external fact or crossing a live boundary. Any newly
detected P0/P1 security, legal or data-integrity defect preempts that work.

## S4F support account-recovery guard

`S4F_SUPPORT_ACCOUNT_RECOVERY_GUARD` implements the non-live portion of Drive
scenarios `SUP-022` and `SUP-023` at exact commit
`67861699bfe2ee068130786ce3eadbfbc2445fa9`. The only draft path for `T-035`
is dedicated and server-bound. It requires the exact P0 account-takeover
reporter, active account, refresh-backed authenticated session and available
password reauthentication; client recovery instructions are not accepted.

The reviewed message points only to the authenticated in-app security area,
states that the reported email channel alone is not accepted and records no
recovery, revocation or external-send effect. Publication rechecks current
truth. Migration `056` mirrors the exact case, recipient, template, rendered
content and non-action bindings and refuses rollback with retained evidence.
Credential requests are blocked across support variables while protective
warnings stay available. Privacy and Retention inventories are updated without
approving a policy or destructive execution.

Focused tests, 71 final manifest/gate protection tests, fresh PostgreSQL 16
integration, the complete Backend run with 540 passes plus one expected skip,
accepted analyzer baseline, 370 Flutter tests with one documented skip,
Google-only coverage, Web build/smoke and Android debug APK pass locally. P0B
remains `HOLD` / `NO-GO`; GitHub push and CI are not claimed because the stored
CLI credential is expired. No live account action, external message,
production, Payment, Store, Cloud/VPS/DNS, signed candidate, deployment, PR
merge or public activation is enabled.

## S4G account-recovery session integrity

`S4G_ACCOUNT_RECOVERY_SESSION_INTEGRITY` implements the non-live portion of
Drive scenarios `SUP-097` and `SUP-098` at exact commit
`8e982a3dfb9032e69e61c78a0a6bbc25b023a842`. Shared target-account locking
serializes reset issuance and P0 account-takeover intake. The takeover path
invalidates prior live reset tokens; later email reset requests issue neither a
token nor an external message and preserve the enumeration-safe response.

Migration `057` enforces hashed, single-use, expiring and immutable reset-token
evidence and refuses destructive rollback. Password reset and authenticated
password change revoke only active target sessions/refresh tokens and delete
only target push registrations. Audit metadata records bounded effect counts,
target-only scope and no replacement session without raw credentials or tokens.

Focused coverage, fresh PostgreSQL 16 integration, 546 Backend passes plus one
expected skip, accepted analyzer baseline, 370 Flutter tests with one documented
skip, Google-only coverage, Web build/smoke and Android debug APK pass locally.
P0B remains `HOLD` / `NO-GO`; GitHub push and CI are not claimed because the
stored CLI credential is expired. No live recovery, production, Payment, Store,
Cloud/VPS/DNS, signed candidate, deployment, PR merge or public activation is
enabled.

`docs/operations/TECHNICAL_DEBT_RELEASE_READINESS.md` is now the mandatory open
register for local toolchain, test-parallelism, rate-limit isolation, timing,
temporary PostgreSQL and fixture-cleanup accommodations. These may support
development only and must be replaced by committed reproducible test paths
before release readiness is claimed.

## S4H provisional and approved account measures

`S4H_ACCOUNT_MEASURE_APPROVAL` implements the non-live portion of Drive
scenarios `SUP-095` and `SUP-096` at exact commit
`a8fcbf8f395e6ee3a5ede67c704c2120596af3c1`. The direct account route accepts
only finite provisional measures and uses server-owned wording that denies any
finding of guilt. A permanent effect requires an immutable proposal and exact
hash/version review by a different verified Administrator.

Approval rechecks current target truth and commits proposal review, structured
decision, unbounded suspension, account state, target session/refresh
revocation and audit atomically. Rejection has no account effect. Migration
`058` independently enforces the four-eyes and payload bindings, blocks legacy
unapproved permanent restrictions and refuses rollback with retained evidence.
Privacy export is minimized and Retention execution remains blocked.

Focused tests, fresh PostgreSQL 16 integration, 550 Backend passes plus one
expected skip, all bound validators, accepted analyzer baseline, 370 Flutter
tests with one documented skip, Google-only coverage, Web build/smoke and
Android debug APK pass locally. P0B remains `HOLD` / `NO-GO`; GitHub push and
CI are not claimed because the stored CLI credential is expired. No live
account action, production, Payment, Store, Cloud/VPS/DNS, signed candidate,
deployment, PR merge or public activation is enabled.

The added S4H HTTP-heavy test path exposed the suite-wide limiter bucket. It
was not papered over with IP rotation or higher limits: workflow integration
keeps S4H deterministic while `TD-RR-002` remains open until the HTTP harness
and real limiter thresholds are isolated and repeatedly reproducible.

## S4I minimized support-message content guard

`S4I_SUPPORT_MESSAGE_CONTENT_GUARD` implements the non-live portion of Drive
scenarios `SUP-044` and `SUP-045` at exact commit
`0f4ae3842b37945b31341ac1ae7d6c5265d185eb`. The versioned message guard
distinguishes Secret from personal-data patterns and rejects either before any
template render, message record, case event or delivery.

After the failed message transaction rolls back, the authenticated route
persists one separate minimized audit row. It contains no submitted value or
value hash. Migration `059` requires the exact class/field/template/version and
false input-storage, message and external-delivery flags; extra metadata,
unsupported actors, mutation and rollback with retained evidence fail closed.

Focused tests, Privacy/Retention validators, two fresh PostgreSQL 16 runs, 551
Backend passes plus one expected skip, accepted analyzer baseline, 370 Flutter
tests with one documented skip, Google-only coverage, Web build/smoke and
Android debug APK pass locally. P0B remains `HOLD` / `NO-GO`; GitHub push and
CI are not claimed because the stored CLI credential is expired. No live
support, external message, production, Payment, Store, Cloud/VPS/DNS, signed
candidate, deployment, PR merge or public activation is enabled.

The two additional HTTP checks passed without adding a limiter exemption or
request-source workaround. This does not close the pre-existing `TD-RR-002` or
manual-database `TD-RR-004` exit criteria.

## S4J atomic non-acute harassment block-report

`S4J_NON_ACUTE_HARASSMENT_BLOCK_REPORT` implements the non-live portion of
Drive scenario `SUP-094` at exact commit
`3aff92398633876605db1b51c29207cad99e1e84`. Immediate danger or uncertainty
is diverted to 110/112 guidance and rejected by the normal server path. A
literal non-acute confirmation uses a dedicated endpoint whose harassment
reason and normal priority are server-owned.

One transaction creates or safely reuses the open neutral report, activates
the reporter's direct-contact block and appends an exact minimized receipt.
The receipt asserts no guilt, moderation account measure or external action.
Generic user harassment reports cannot bypass the path; payload-bound replay
and active-report checks prevent duplication or silent loss of changed details
and evidence. Migration `060` enforces the linked report/block and exact
eight-key audit payload and refuses destructive rollback.

Focused tests, Privacy/Retention/P0B protections, two consecutive fresh
PostgreSQL 16 integrations, 553 Backend passes plus one expected skip, accepted
analyzer baseline, 372 Flutter tests with one documented skip, Google-only
coverage, Web build/smoke and Android debug APK pass locally. P0B remains
`HOLD` / `NO-GO`; GitHub push and CI are not claimed because the stored CLI
credential is expired. No live safety/account action, production, Payment,
Store, Cloud/VPS/DNS, signed candidate, deployment, PR merge or public
activation is enabled.

The initial monolithic run reproduced `TD-RR-002`. S4J now owns a fresh
app/limiter test instance rather than an IP, limit or timing workaround and
passed twice from fresh databases. Whole-suite limiter isolation, Flutter
parallelism and automated PostgreSQL lifecycle remain open release debt.

## S4K server-authoritative booking address reveal

`S4K_BOOKING_EXACT_ADDRESS_REVEAL` implements the non-live portion of Drive
scenarios `SUP-046` through `SUP-048` at exact commit
`59d8f1eee2d72111d1bc97034bf2114123897622`. One participant-only endpoint
decides pickup or return visibility from counterparty confirmation,
booking-local date, server clock, workflow state and safety truth. More than
six hours before the appointment remains hidden; late effective confirmation
inside the window reveals immediately. Outsider and missing booking are
indistinguishable.

Migration `061` requires minimized exact audit shapes, validates a successful
reveal against current database truth, prevents address/coordinate/party data
in metadata and refuses destructive rollback. Product UI no longer treats its
local clock or ongoing state as authority. Pickup and return use separate
segments, and structured chat location sharing fails closed with the same
server decision.

Focused tests, Privacy/Retention/P0B protections, successful fresh PostgreSQL
16 runs, 561 Backend passes plus one expected skip, accepted analyzer baseline,
373 Flutter tests with one documented skip, Google-only coverage, Web
build/smoke and Android debug APK pass locally. P0B remains `HOLD` / `NO-GO`;
GitHub push and CI are not claimed because the stored CLI credential is
expired. No production, Payment, Store, Cloud/VPS/DNS, signed candidate,
deployment, PR merge or public activation is enabled.

No timing, limiter or request-source workaround became a prerequisite. The
final gate used a fresh database and injected-clock boundary tests. Existing
temporary Node, Flutter serialism, manual PostgreSQL orchestration and bounded
fixture-cleanup proof stay in the open release-debt register.

## S4L server-owned handover exception intake

`S4L_HANDOVER_EXCEPTION_INTAKE` implements Drive Support Matrix scenarios
`SUP-052` through `SUP-054` at commit
`27b29e93ef02a987f6414eb780556137de03efcf`; `SUP-049` through `SUP-051`
remain covered by the pre-existing confirmation/evidence guards. The
participant-only endpoint server-routes item mismatch, off-platform deposit
demand and handover no-show into three exact P1 review cases.

Safe-abort, do-not-pay and chat-contact acknowledgements are kind-specific.
No-show additionally requires a reached counterparty-confirmed appointment and
database-visible message. Clients cannot choose the support route or any
status, money, guilt or moderation effect. Migration `062` enforces current
booking truth, exact minimized audit metadata and rollback refusal.

Focused, Privacy/Retention, P0B, fresh PostgreSQL, full Backend, two full
standard-parallel Flutter runs, Google-only, analyzer, Web smoke, Android debug,
syntax and secret checks pass locally. The Backend runner now owns safe test
module defaults and technical regression no longer defaults to concurrency
one at commit `487c34a862676607af47eaf767afcca3e174bf38`.

P0B remains `HOLD` / `NO-GO`. No production, Payment, Store, Cloud/VPS/DNS,
signed candidate, deployment, merge or public activation is enabled. Shared
limiter isolation, exact-commit CI and the remaining deterministic
release-readiness debt stay open.

## S4M server-owned return calendar deadlines

`S4M_RETURN_CALENDAR_DEADLINES` implements Drive Support Matrix scenarios
`SUP-055` through `SUP-065` at commit
`1f6481f2ce76febb38340cd8a4e49b480af2306f`. The server owns booking-timezone
calendar arithmetic for five/seven-day clarification, response and update
deadlines; exact T0+48h report semantics stay unchanged.

Changed T0 now requires complete distinct-participant proposal/confirmation
truth. Direct chat closes after the inclusive 48-hour window unless a
substantiated active return case remains open. Migration `063` versions and
enforces new calendar-bound V5.2 rows while grandfathering historical fixed-
duration evidence. Client local/QA projection mirrors Berlin DST only and does
not replace the server for backend-enabled operation.

Focused, Privacy/Retention, P0B, fresh PostgreSQL, full Backend,
standard-parallel Flutter, Google-only, analyzer, Web smoke, Android debug,
syntax and secret checks pass locally. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, signed candidate, deployment, merge
or public activation is enabled.

No new workaround became a prerequisite. Exact-commit CI, normal Node/pnpm
resolution, isolated limiter thresholds, automatic PostgreSQL lifecycle,
bounded fixture proof and the remaining release-readiness debt stay open.

## S4N bounded Safety rate-limit isolation

`S4N_BOUNDED_SAFETY_RATE_LIMIT_ISOLATION` implements Drive Support Matrix
scenario `SUP-109` at commit
`6da227ba2abaf3d5aa75e6f0f235b31bf655eb4f`. A central repository-owned
factory now creates fresh general, ordinary-support and Safety limiter stores
for every application. Exact protected Safety and handover-exception requests
skip only the general bucket and still enter the dedicated 30-attempt bucket
before authentication and database work.

Real 10/30/240 thresholds, general-starvation isolation and fresh-instance
repetition pass with one fixed request source. Focused, Privacy/Retention,
P0B, two fresh PostgreSQL, full Backend, standard-parallel Flutter,
Google-only, analyzer, Web smoke, Android debug, syntax, diff and secret checks
pass locally.

No sleep, reset, IP rotation, higher production limit or serial test mode was
accepted. `TD-RR-002` remains open for the historical monolithic integration
cleanup and exact-commit CI. P0B remains `HOLD` / `NO-GO`; no production,
Payment, Store, Cloud/VPS/DNS, deployment, signed candidate, merge or public
activation is enabled.

## S4O repository-owned PostgreSQL integration runner

`S4O_REPOSITORY_POSTGRES_RUNNER` replaces manual local database lifecycle work
with `pnpm run test:postgres:local`. Implementation commit
`ed0f94cc3e5378ee38abfde0e03269a9b818e85e` owns PostgreSQL 16 pinning, unique
cluster/database creation, an OS-selected loopback port, readiness, canonical
integration and guarded success/failure cleanup. The complete gate is green at
`b4194411779163f41197cd3d8325fcdb7a61847b`.

Six runner tests and two consecutive real fresh-cluster runs pass with zero
runner temp roots before and after. Full Backend and technical regressions,
standard-parallel Flutter, analyzer, Privacy/Retention/P0B validators,
Google-only, Web smoke, Android debug, syntax, diff and secret checks pass.

No fixed port, sleep, reused database, skipped migration or manual cleanup is a
prerequisite. `TD-RR-004` remains open only for exact-commit CI evidence under
the register closure rule; normal Node/pnpm resolution remains open under
`TD-RR-001`. P0B remains `HOLD` / `NO-GO`, with no live boundary changed.

## S4P normal Mac regression toolchain

`S4P_NORMAL_MAC_REGRESSION_TOOLCHAIN` replaces all copied/explicit local
runtime paths with repository-pinned normal-shell setup. Node 22 and exact pnpm
11.16.0 are implemented at `427232e`; Flutter 3.41.7, Dart 3.11.5 and Java 17
normal-shell setup at `0e65de3`; exact verified package head is
`3a2543118782429de38c7f81c63cf09449d90a17`.

A new login shell passes frozen install, full Backend, syntax, moderate audit,
secret scan, repository PostgreSQL and the complete technical regression with
standard Flutter parallelism and no PATH/JAVA_HOME override. The unused
Firebase Storage/Firestore optional trees are excluded, removing 123 packages
and the only moderate audit finding; runtime Auth/Messaging contracts remain
green.

No temporary Node copy, Codex pnpm fallback, skipped audit, serial Flutter mode,
fixed port or reused database is accepted. `TD-RR-001`, `TD-RR-003` and
`TD-RR-004` remain formally open for exact-commit CI evidence. P0B remains
`HOLD` / `NO-GO`; no production, Payment, Store, Cloud/VPS/DNS, deployment,
merge or public activation is enabled.

## S4Q deterministic test temporary fixtures

`S4Q_DETERMINISTIC_TEST_TEMP_FIXTURES` implements the local `TD-RR-005` exit
path at commit `6b15aac`. Twelve formerly leaking tool-test files now allocate
through one safe-prefix tracker with fail-closed `node:test` cleanup. The full
technical regression invokes a committed guard that runs all affected suites
together twice and rejects any tracked directory-count or KiB growth.

Before cleanup, the guard proved the remaining 1,605 historical fixtures
(731,460 KiB) no longer increased. They and the unused temporary Node copy were
moved recoverably to Trash. The guard then passed clean at `0/0 KiB -> 0/0
KiB`; full Backend passed 600 tests plus one expected skip, and two consecutive
complete technical regressions passed at standard parallelism with the same
zero-growth result.

No manual deletion, larger disk, alternate temp root, reduced suite, sleep or
serial execution is an acceptance condition. `TD-RR-005` remains formally open
only for exact-commit CI evidence. P0B remains `HOLD` / `NO-GO`; no production,
Payment, Store, Cloud/VPS/DNS, deployment, signed candidate, merge or public
activation is enabled.

## S4R PostgreSQL rate-limit scenario isolation

`S4R_POSTGRES_RATE_LIMIT_SCENARIO_ISOLATION` implements the local `TD-RR-002`
exit path at commit `0dffd6c`. The monolithic HTTP integration no longer rotates
reserved request sources to protect later scenarios from earlier rate-budget
consumption. Independent scenarios restart the loopback application and its
repository-owned limiter stores while keeping one continuous isolated
PostgreSQL database.

The only remaining forwarded source is an explicit security input: ten failed
credentials from ten distinct sources must still lock one account. A committed
source contract rejects any additional occurrence. Exact 10/30/240 focused
thresholds, two fresh PostgreSQL 16 runs, 602 Backend passes plus one expected
skip and two complete standard-parallel technical regressions pass locally.

No wait, reset hook, limiter bypass, higher product limit or unrelated IP
rotation is accepted. `TD-RR-002` remains formally open only for exact-commit
CI evidence. P0B remains `HOLD` / `NO-GO`; no production, Payment, Store,
Cloud/VPS/DNS, deployment, signed candidate, merge or public activation is
enabled.

## S4S Flutter standard-parallel stability

`S4S_FLUTTER_STANDARD_PARALLEL_STABILITY` implements the local retained-stress
exit path for `TD-RR-003` at commit `cea3a1f`. The canonical command requires a
clean exact-commit worktree and runs the complete Flutter suite five times at
Flutter's standard parallelism. It rejects a concurrency override and contains
no sleep, retry, failure rerun or reduced-suite path.

Five consecutive complete runs passed with 379 tests and one documented skip
each at exact commit `cea3a1f404f90cc4ae1ed8dd86c453245f97e331`. A committed
wiring test locks the repeat count and forbids timing accommodations. GitHub
exposes the same command only through an explicit manual input defaulting false,
so normal CI cost does not increase silently.

Concurrency one, timing waits and pass-on-rerun are not accepted. `TD-RR-003`
remains formally open only for retained green exact-commit CI with the stress
input enabled. P0B remains `HOLD` / `NO-GO`; no production, Payment, Store,
Cloud/VPS/DNS, deployment, signed candidate, merge or public activation is
enabled.

The complete local gate found and rejected stale P0B source bindings caused by
the earlier S4R integration change. Commits `109913d` and `8f8e496` update only
the exact hash chain; PSP stays `0/8 HOLD`, invited pilot stays `0/4 HOLD`, and
their negative tests remain green. The final complete run uses the already
documented CI-metadata-only branch because historical AAB `2026081509` is not
present locally; it is not claimed as actual CI, Store or device proof.

## S4T single-attempt Gradle wrapper verification

`S4T_SINGLE_ATTEMPT_GRADLE_WRAPPER_VERIFICATION` implements the local
`TD-RR-007` exit path at commit `84357c4`. The CI wrapper preflight now executes
exactly one `./android/gradlew --version` after the verified basic-cache action.
The former three-attempt loop and its five-/ten-second sleeps are removed.

The wiring contract locks step order, the single invocation and the pinned
Gradle 8.12 distribution URL/SHA-256; it rejects an attempt loop, sleep or retry.
Eight focused tests, the direct Gradle 8.12/Java 17 check and a complete clean
implementation-head technical gate pass locally.

Automatic retries, waits and pass-on-rerun are not accepted. `TD-RR-007`
remains formally open only for independent green exact-commit CI evidence with
the same single-attempt contract. P0B remains `HOLD` / `NO-GO`; no production,
Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public activation
is enabled.

## S4U reset-token single-clock boundary

`S4U_RESET_TOKEN_SINGLE_CLOCK_BOUNDARY` implements the local `TD-RR-006` exit
path at commit `db92a8c`. The canonical clean-head command runs the exact
single-clock reset-token unit five times and two complete fresh PostgreSQL 16
integrations. A committed static contract is part of the full technical gate.

The proof locks one persisted issuance timestamp, an exact 30-minute derived
expiry and migration `057`'s independently validated upper bound. Five focused
runs, two repository-owned PostgreSQL runs with temp roots `0 -> 0`, and the
complete clean implementation-head local metadata gate pass.

No sleep, retry, clock wait, relaxed constraint, reused database or manual
cleanup is accepted. `TD-RR-006` remains formally open only for exact-commit CI
evidence on PostgreSQL 16. P0B remains `HOLD` / `NO-GO`; no production,
Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public activation
is enabled.

## S4V P0A Web smoke bound readiness

`S4V_P0A_WEB_SMOKE_BOUND_READINESS` implements the local `TD-RR-008` exit path
at commit `1d6aeda`. The P0A Web smoke no longer starts a fixed-port server and
waits through twenty curl attempts with `sleep 0.1`. The repository-owned
helper binds an OS-selected loopback port before its serving thread starts and
fetches each required current-source artifact exactly once.

The committed three-test contract locks loopback-only binding, OS-selected
default port, one request per artifact, positive and fail-closed manifest
behavior, and the absence of sleep, retry, curl polling and the old port. Five
consecutive real smokes and the complete clean implementation-head local
metadata gate pass; analyzer baseline 220, 379 Flutter tests plus one documented
skip, Google-only, Web build/smoke and Android debug remain green.

The request timeout is a fail-closed bound, not a rerun path. No fixed default
port, startup wait, retry, pass-on-rerun or external server is accepted.
`TD-RR-008` remains formally open only for exact-commit CI evidence. P0B remains
`HOLD` / `NO-GO`; no production, Payment, Store, Cloud/VPS/DNS, deployment,
signing, merge or public activation is enabled.

## S4W CDP reload event boundary

`S4W_CDP_RELOAD_EVENT_BOUNDARY` implements the automated local `TD-RR-009`
exit path at commit `8bc4fed`. The booking-QA CDP helper no longer uses a
50-millisecond JavaScript timer, a two-second Python sleep or a reconnect to
guess that reload completed.

The tool now guards the current main-frame loader, preserves early CDP events,
accepts only a correlated new-loader `load` lifecycle event for that frame and
then verifies complete document state plus exact targeted storage equality.
WebSocket frames are assembled across split reads, and success output does not
echo stored values. The four-test contract passed five consecutive times; the
complete clean implementation-head local metadata gate also passed.

No real browser seed was applied. Sleep, timer, automatic reconnect/retry,
uncorrelated events and value-bearing verification output are not accepted.
`TD-RR-009` remains open for exact-commit CI and one controlled local-browser
observation in a dedicated QA profile. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.

## S4X exact Flutter analyzer debt ratchet

`S4X_EXACT_FLUTTER_ANALYZER_DEBT_RATCHET` implements the containment stage of
`TD-RR-010` at commit `5a1aba9`. The former `<= 220` analyzer ceiling is gone.
The repository now requires the exact total and normalized diagnostic
fingerprint, so neither a same-count replacement nor a reduction without an
immediate committed ratchet can pass.

The seven-test contract covers exact success, old-debt return, replacement
drift and parse/summary disagreement. The real 220-diagnostic output matched
fingerprint `3a2fcf242ac029bcf4e3f2b70a92660700f88b68a05e3a3fca7d81b94b5010bd`,
and the complete clean implementation-head local metadata gate passed.

The containment snapshot is not release closure. Every bounded source cleanup
must strictly lower and update it in the same reviewed commit until zero;
raising it, lint suppression or non-fatal analyzer configuration is forbidden.
`TD-RR-010` remains open for those ratchets and exact-commit CI. P0B remains
`HOLD` / `NO-GO`; no production, Payment, Store, Cloud/VPS/DNS, deployment,
signing, merge or public activation is enabled.

## S4Y Wishlist async-context ratchet

`S4Y_WISHLIST_ASYNC_CONTEXT_RATCHET` delivers the first downward
`TD-RR-010` source ratchet at commit `1958248`. Both Wishlist selector entry
points now fail closed after either async lookup if the original context was
disposed. The change uses no delay, retry or lint suppression and creates no
saved-item side effect on that path.

The exact debt snapshot moves `220 -> 214`, and only the intended
`use_build_context_synchronously` Wishlist bucket changes. Nine focused tests,
five related Flutter tests and the complete clean implementation-head local
metadata gate pass with the new exact fingerprint.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.
