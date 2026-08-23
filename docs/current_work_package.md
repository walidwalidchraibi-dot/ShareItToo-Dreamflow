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

## S4Z popup auto-close lifecycle ratchet

`S4Z_POPUP_AUTO_CLOSE_LIFECYCLE_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at commit `e7b7f8f`. Standard popup and toast timers
no longer resolve a navigator from a `BuildContext` after their delay. The
captured root navigator must still be mounted, and completing the popup disarms
its timer so a later route cannot be popped accidentally.

The exact debt snapshot moves `214 -> 212`, and only the intended
`use_build_context_synchronously` popup bucket changes. Two focused widget tests
and the complete clean implementation-head local metadata gate pass with the
new exact fingerprint and 381 Flutter tests plus one documented skip.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.

## S4AA image-gallery async-context ratchet

`S4AA_IMAGE_GALLERY_ASYNC_CONTEXT_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at commit `4522bb2`. Wishlist completion now requires
the gallery State to remain mounted before UI refresh. Wishlist and Share
failure require the exact captured build context to remain mounted before an
error popup may open.

The exact debt snapshot moves `212 -> 210`, and only the intended
`use_build_context_synchronously` gallery bucket changes. Three focused widget
tests and the complete clean implementation-head local metadata gate pass with
the new exact fingerprint and 384 Flutter tests plus one documented skip.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.

## S4AB item-card async-state ratchet

`S4AB_ITEM_CARD_ASYNC_STATE_RATCHET` delivers the next downward `TD-RR-010`
source ratchet at commit `84dcc07`. Every asynchronous Wishlist continuation in
the listing card now proves that its State remains mounted before later UI or
context access. The Move path validates a captured nullable list ID.

The exact debt snapshot moves `210 -> 207`, and only the intended
`use_build_context_synchronously` ItemCard bucket changes. Four focused
contracts, five related Flutter tests and the complete clean implementation
gate pass with the new exact fingerprint.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
live boundary changed.

## S4AC Gradle single-attempt cache contract

`S4AC_GRADLE_SINGLE_ATTEMPT_CACHE_CONTRACT` implements the local deterministic
path for `TD-RR-011` at commit `1d9816e`. It keeps failed GitHub run
`32592388940` as failure evidence, permits the draft PR to write only its scoped
open-source Basic Cache, and replaces Flutter's retrying APK command with one
direct checksum-bound Gradle `assembleDebug` invocation.

Ten focused contracts, the direct build and the complete clean implementation
gate pass locally. Exact GitHub run `32593274378` also passed without rerun,
wrote its cold PR-scoped Basic Cache (`0 restored, 1 saved`) and executed one
direct `:app:assembleDebug` with no Flutter APK retry path.

Exact later GitHub run `32594060058` then restored that same PR-scoped entry
(`1 restored, 0 saved`) and passed without rerun. Its log again contains one
direct `:app:assembleDebug`, zero `flutter build apk` and zero
`Retrying Gradle Build`. This closes `TD-RR-011` without a sleep, retry loop,
alternate mirror, manual cache injection or paid provider. P0B remains `HOLD` /
`NO-GO`; no production, Payment, Store, Cloud/VPS/DNS, deployment, signing,
merge or public activation is enabled.

## S4AD listing-options async-context ratchet

`S4AD_LISTING_OPTIONS_ASYNC_CONTEXT_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at commit `1299518`. Listing-option add, move and
removal callbacks now recheck their exact caller lifecycle after every relevant
asynchronous boundary before later UI or callback access.

The exact debt snapshot moves `207 -> 204`, and only the intended
`use_build_context_synchronously` listing-options bucket changes. Ten combined
Wishlist lifecycle contracts, five related Flutter tests and the complete clean
implementation gate pass with the new exact fingerprint.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.

## S4AE profile-info async-lifecycle ratchet

`S4AE_PROFILE_INFO_ASYNC_LIFECYCLE_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at commit `42a2982`. Profile save rechecks lifecycle
after its toast before navigation, and late load failures stop before disposed
State access.

The exact debt snapshot moves `204 -> 203`, and only the intended
`use_build_context_synchronously` profile-info bucket changes. Three focused
contracts, 15 related Flutter tests and the complete clean implementation gate
pass with the new exact fingerprint.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.

## S4AF listing-photo async-lifecycle ratchet

`S4AF_LISTING_PHOTO_ASYNC_LIFECYCLE_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at implementation commit `a2d0ac1`, with the exact
privacy/retention source binding at `eb413d1`. The picked-photo preview now
rechecks its own `BuildContext` after asynchronous file access and stops before
opening a dialog when the thumbnail has been removed.

The exact debt snapshot moves `203 -> 202`, and only the intended
`use_build_context_synchronously` create-listing bucket changes. Four focused
photo/lifecycle contracts and the complete clean local metadata gate pass with
the new exact fingerprint. The privacy and retention source inventories were
rebound to the changed reviewed source without changing any disclosure,
retention decision or release state.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.

## S4AG public-profile async-context ratchet

`S4AG_PUBLIC_PROFILE_ASYNC_CONTEXT_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at commit `4f8a150`. Profile sharing now proves its
exact screen context after clipboard access before opening a toast. The block
action proves the same context immediately before entering its asynchronous
confirmation flow.

The exact debt snapshot moves `202 -> 200`, and only the intended
`use_build_context_synchronously` public-profile bucket changes. Three focused
source contracts, 16 public-profile/blocking/large-text Flutter tests and the
complete clean local metadata gate pass with the new exact fingerprint.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.

## S4AH request-detail async-navigation ratchet

`S4AH_REQUEST_DETAIL_ASYNC_NAVIGATION_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at commit `c8c2a56`. Owner acceptance and decline
now prove the exact request-detail context after their respective asynchronous
mutation before navigating away. Contract, quote, declaration, deadline,
status and notification behavior are unchanged.

The exact debt snapshot moves `200 -> 198`, and only the intended
`use_build_context_synchronously` request-detail bucket changes. Twenty combined
request-detail/acceptance source-contract assertions, nine focused pricing and
checkout Flutter tests and the complete clean local metadata gate pass with the
new exact fingerprint.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.

## S4AI bookings async-context ratchet

`S4AI_BOOKINGS_ASYNC_CONTEXT_RATCHET` delivers the next downward `TD-RR-010`
source ratchet at commit `4a050fc`. Booking-card navigation now proves the exact
card context after its read mutation, and the inline renter review stops after
user lookup when its owning State has been disposed. Booking state, read
semantics, review eligibility, quote and navigation destinations are unchanged.

The exact debt snapshot moves `198 -> 196`, and only the intended
`use_build_context_synchronously` bookings bucket changes. Twenty combined
booking/quote/privacy source-contract assertions, 55 focused booking/review
Flutter tests, 73 privacy/retention contracts and the complete clean local
metadata gate pass with the new exact fingerprint. The privacy inventory is
rebound to the reviewed source without changing any disclosure or release
state.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.

## S4AJ owner-requests async-context ratchet

`S4AJ_OWNER_REQUESTS_ASYNC_CONTEXT_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at commit `9727cf6`. Owner decline now rechecks its
screen lifecycle after both status mutation and list refresh before opening
result UI. Inline owner review stops after current-user lookup when its owning
State has been disposed. Acceptance, decline, review, quote and status rules are
unchanged.

The exact debt snapshot moves `196 -> 194`, and only the intended
`use_build_context_synchronously` owner-requests bucket changes. Twenty-one
combined owner-request/acceptance source-contract assertions, 15 focused
owner-request/pricing/checkout/review Flutter tests and the complete clean local
metadata gate pass with the new exact fingerprint.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.

## S4AK search-results async-context ratchet

`S4AK_SEARCH_RESULTS_ASYNC_CONTEXT_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at commit `204e60f`. Search-result Wishlist actions
now recheck their screen lifecycle after the initial Wishlist lookup and after
manage-option selection before opening add, manage or move UI. Wishlist data,
filtering, search results and navigation behavior are unchanged.

The exact debt snapshot moves `194 -> 191`, and only the intended
`use_build_context_synchronously` search-results bucket changes. Five focused
Wishlist/search lifecycle source contracts, nine focused catalog/saved-item
Flutter tests and the complete clean local metadata gate pass with the new exact
fingerprint.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.

## S4AL explore async-context ratchet

`S4AL_EXPLORE_ASYNC_CONTEXT_RATCHET` delivers the next downward `TD-RR-010`
source ratchet at commit `79b0a1e`. Explore Wishlist actions now recheck their
screen lifecycle after the initial Wishlist lookup and after manage-option
selection before opening add, manage or move UI. Wishlist data, catalog
filtering, listing display, supply enrichment and navigation behavior are
unchanged.

The exact debt snapshot moves `191 -> 188`, and only the intended
`use_build_context_synchronously` Explore bucket changes. Eleven focused
Wishlist/Explore/display/supply source contracts, 21 focused catalog,
saved-item, display, accessibility and navigation Flutter tests, the privacy and
retention validators and the complete clean local metadata gate pass with the
new exact fingerprint. Both source inventories are rebound to the reviewed
Explore source without changing any disclosure, retention or release state.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.

## S4AM message-thread async-context ratchet

`S4AM_MESSAGE_THREAD_ASYNC_CONTEXT_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at commit `d481515`. Chat owner acceptance now uses
the owning State lifecycle after declaration selection. Booking-detail routing,
time proposals and other-party profile navigation each stop after their
asynchronous data lookup if the chat screen was disposed. Chat state,
acceptance, quote, appointment, handover/return, profile and navigation rules
are unchanged.

The exact debt snapshot moves `188 -> 182`, and only the intended
`use_build_context_synchronously` message-thread bucket changes. Eighteen
focused message-thread/acceptance source contracts, 17 privacy contracts, 96
focused chat/booking/acceptance/handover Flutter tests and the complete clean
local metadata gate pass with the new exact fingerprint. The privacy inventory
is rebound to the reviewed message-thread source without changing any
disclosure or release state.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.

## S4AN owner-detail time/overflow async-context ratchet

`S4AN_OWNER_DETAIL_TIME_OVERFLOW_ASYNC_CONTEXT_RATCHET` delivers the next
downward `TD-RR-010` source ratchet at commit `b4ac1d1`. Owner appointment
management now checks its owning State after loading flow state and after
persisting an accepted or newly requested time. The owner overflow route checks
its exact builder context after menu selection and after cancellation status
and timeline mutations. Appointment, cancellation, timeline, quote, booking,
handover/return, item-detail and navigation rules are unchanged.

The exact debt snapshot moves `182 -> 175`, and only the intended
`use_build_context_synchronously` owner-detail bucket changes. Thirty-four
focused source/analyzer/privacy contracts, 96 focused Flutter tests, the
privacy and retention validators and the complete clean local metadata gate
pass with the new exact fingerprint. The privacy inventory is rebound to the
reviewed owner-detail source without changing any disclosure or release state.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.

## S4AO owner-request result async-context ratchet

`S4AO_OWNER_REQUEST_RESULT_ASYNC_CONTEXT_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at commit `5c09b02`. Owner-detail decline and
acceptance now prove their exact body context after screen refresh and before
result UI. The existing product auto-close callbacks prove the same exact
context before root-navigator access. Acceptance, decline, timeline, refresh,
popup destinations and timer durations are unchanged.

The exact debt snapshot moves `175 -> 171`, and only the intended
`use_build_context_synchronously` owner-detail bucket changes. Twenty-nine
focused source/analyzer/privacy contracts, 96 focused Flutter tests, the
privacy and retention validators and the complete clean local metadata gate
pass with the new exact fingerprint. The privacy inventory is rebound to the
reviewed owner-detail source without changing any disclosure or release state.

This package does not close `TD-RR-010`; further reviewed source reductions to
zero plus exact-commit CI remain required. P0B remains `HOLD` / `NO-GO`; no
production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public
activation is enabled.

## S4AP owner handover/maps async-context ratchet

`S4AP_OWNER_HANDOVER_MAPS_ASYNC_CONTEXT_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at commit `921d185`. Pickup and return starters,
Maps failure feedback, return completion and pickup-challenge handoff now prove
their exact State or caller context after asynchronous work. Time confirmation,
Maps destination, challenge, stepper, completion and `needsReview` behavior are
unchanged.

The exact debt snapshot moves `171 -> 165`, and only the intended
`use_build_context_synchronously` owner-detail bucket changes from `6 -> 0`.
Thirty-four focused source/analyzer/privacy contracts, 96 focused Flutter
tests, the privacy and retention validators and the complete clean local
metadata gate pass with the new exact fingerprint. The privacy inventory is
rebound without changing any disclosure or release state.

This package clears the owner-detail context bucket but does not close
`TD-RR-010`; the remaining booking-detail and item-overlay context findings
still require reviewed reductions to zero plus exact-commit CI. P0B remains
`HOLD` / `NO-GO`; no production, Payment, Store, Cloud/VPS/DNS, deployment,
signing, merge or public activation is enabled.

## S4AQ booking-detail primary async-context ratchet

`S4AQ_BOOKING_DETAIL_PRIMARY_ASYNC_CONTEXT_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at commit `1cb7489`. Time management, listing lookup,
overflow selection and completed-renter review now prove their owning State and
exact callback contexts after asynchronous work. Appointment, listing-match,
menu destinations, review, Payment and `needsReview` behavior are unchanged.

The exact debt snapshot moves `165 -> 155`, and only the intended
`use_build_context_synchronously` booking-detail bucket changes from `22 -> 12`.
Thirty-nine focused source/analyzer/privacy contracts, 96 focused Flutter
tests, the privacy and retention validators and the complete clean local
metadata gate pass with the new exact fingerprint. The privacy inventory is
rebound without changing any disclosure or release state.

This package does not close `TD-RR-010`; the remaining 12 booking-detail and 21
item-overlay context findings still require reviewed reductions to zero plus
exact-commit CI. P0B remains `HOLD` / `NO-GO`; no production, Payment, Store,
Cloud/VPS/DNS, deployment, signing, merge or public activation is enabled.

## S4AR booking-detail handover/return async-context ratchet

`S4AR_BOOKING_DETAIL_HANDOVER_RETURN_ASYNC_CONTEXT_RATCHET` delivers the next
downward `TD-RR-010` source ratchet at commit `5658f10`. Stepper, QR and
manual-code pickup/return paths now prove their owning State after challenge,
identity, transition, synchronization, notification and banner work. Secure
roles, evidence, transitions, review reminders and `needsReview` are unchanged.

The exact debt snapshot moves `155 -> 143`, and only the intended
`use_build_context_synchronously` booking-detail bucket changes from `12 -> 0`.
Forty-five focused source/analyzer/privacy contracts, 96 focused Flutter tests,
the privacy and retention validators and the complete clean local metadata gate
pass with the new exact fingerprint. The privacy inventory is rebound without
changing any disclosure or release state.

This package clears the booking-detail context bucket but does not close
`TD-RR-010`; the remaining 21 item-overlay context findings still require
reviewed reductions to zero plus exact-commit CI. P0B remains `HOLD` / `NO-GO`;
no production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or
public activation is enabled.

## S4AS item-details reservation async-context ratchet

`S4AS_ITEM_DETAILS_RESERVATION_ASYNC_CONTEXT_RATCHET` delivers the next
downward `TD-RR-010` source ratchet at commit `be95424`. Listing-sheet,
listing-page and bottom-action reservation completion now prove their State,
exact caller context and mounted root navigator after asynchronous work. The
confirmation helper proves its own context after lookup. Three fixed
120-millisecond waits and one 80-millisecond booking-navigation wait are
removed without a substitute timer or retry.

Request persistence and the existing availability, edit, checkout, saved-state,
confirmation and booking destinations are unchanged. The exact debt snapshot
moves `143 -> 132`, and only the intended
`use_build_context_synchronously` item-overlay bucket changes from `21 -> 10`.
Forty-nine focused source/analyzer/privacy contracts, 96 focused Flutter tests,
the privacy and retention validators and a complete
application-source-identical pre-registration gate pass with the new exact
fingerprint. The final clean-head run stopped emitting Flutter output after 293
green results until a terminal interrupt was requested; it then continued and
returned success, but is not accepted as deterministic evidence. No retry,
reduced parallelism, timeout or alternate command was used. Exact-commit CI is
required. The privacy inventory is rebound without changing any disclosure or
release state.

This package does not close `TD-RR-010`; the remaining ten item-overlay context
findings require a further reviewed reduction to zero plus exact-commit CI.
P0B remains `HOLD` / `NO-GO`; no production, Payment, Store, Cloud/VPS/DNS,
deployment, signing, merge or public activation is enabled.

## S4AT item-details secondary async-context ratchet

`S4AT_ITEM_DETAILS_SECONDARY_ASYNC_CONTEXT_RATCHET` delivers the final
`use_build_context_synchronously` source ratchet at commit `1a41bc4`.
Item-sheet sharing, range selection and Wishlist management, full-page sharing,
the listing overflow/support path and express feedback now prove their owning
State or exact callback context after asynchronous work.

The exact debt snapshot moves `132 -> 122`, and only the intended item-overlay
context bucket changes from `10 -> 0`. Fifty-four focused
source/analyzer/privacy contracts, 96 focused Flutter tests and all exact
privacy, retention and analyzer validators pass. The privacy inventory is
rebound without changing disclosure or release state.

The standard-parallel clean-head gate reproducibly stopped after 293 green
Flutter results and was terminated after more than six minutes without a test
worker. A diagnostic-only serial run passed all 384 tests plus one documented
skip; it is not an acceptance gate and no permanent accommodation was added.
Exact-commit CI and the retained five-run default-parallel proof remain open
under `TD-RR-003`.

This package clears every async-context analyzer finding but does not close
`TD-RR-010`; 122 diagnostics in the remaining categories still require
reviewed downward ratchets to zero plus exact-commit CI. P0B remains `HOLD` /
`NO-GO`; no production, Payment, Store, Cloud/VPS/DNS, deployment, signing,
merge or public activation is enabled.

## S4AU item-details RadioGroup ratchet

`S4AU_ITEM_DETAILS_RADIO_GROUP_RATCHET` delivers the complete deprecation
ratchet at commit `618916e`. Seven typed group owners replace all deprecated
per-tile value/change ownership across both delivery layouts and the express
fallback. Four unavailable Vermieter choices remain explicitly disabled and
all four delivery-group callbacks retain local selection persistence.

The exact debt snapshot moves `122 -> 86`, and only
`deprecated_member_use` changes from `36 -> 0`. Fifty-nine focused
source/analyzer/privacy contracts, 96 focused Flutter tests and all exact
privacy, retention and analyzer validators pass. The privacy inventory is
rebound without changing disclosure or release state.

The standard-parallel clean-head gate stopped after 192 green Flutter results
and was terminated after more than six minutes without a test worker. It is not
an acceptance gate; no retry, serial replacement or permanent accommodation
was added. Exact-commit CI and the retained five-run default-parallel proof
remain open under `TD-RR-003`.

This package clears every analyzer deprecation but does not close `TD-RR-010`;
86 diagnostics in the remaining unused-code categories still require reviewed
downward ratchets to zero plus exact-commit CI. P0B remains `HOLD` / `NO-GO`;
no production, Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or
public activation is enabled.

## S4AV item-details dead-code ratchet

`S4AV_ITEM_DETAILS_DEAD_CODE_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at implementation commit `4632aac`. It removes the
uncalled sheet request duplicate and twelve analyzer-confirmed unreferenced
private item-detail helpers. The active page and bottom reservation paths,
delivery entitlements, no-delivery presentation, category/profile/Wishlist
actions and booking cancellation card remain permanently guarded.

The exact debt snapshot moves `86 -> 71`: `unused_element` changes
`56 -> 43`, `unused_element_parameter` changes `24 -> 22`, `unused_field`
remains `6`, and item-overlay findings reach zero. Seventy-seven focused
source/analyzer/privacy contracts, 96 focused Flutter tests and all exact
privacy, retention, G2 lifecycle and analyzer validators pass. The complete
standard-parallel gate passed in one execution on `4632aac` with 384 Flutter
tests plus one documented skip, Google-only, Web build/smoke and one direct
448-task Android debug build. The privacy inventory is rebound without changing
disclosure or release state.

The first focused Flutter selection failed with a full data volume after 15
tests. Only regenerable caches were cleared; the identical selection then
passed. `TD-RR-012` prevents this cleanup from becoming an undocumented
standing prerequisite and requires deterministic release-host capacity proof.

This package does not close `TD-RR-010`; 71 diagnostics in the remaining
unused-code categories still require reviewed downward ratchets to zero plus
exact-commit CI. P0B remains `HOLD` / `NO-GO`; no production, Payment, Store,
Cloud/VPS/DNS, deployment, signing, merge or public activation is enabled.

## S4AW Explore dead-code ratchet

`S4AW_EXPLORE_DEAD_CODE_RATCHET` delivers the next downward `TD-RR-010`
source ratchet at implementation commit `3df03c0`. It removes unreferenced
Explore helpers, never-started timer machinery and default-only presentation
branches. Active long-press owners, search/category filtering, item details,
listing options, Wishlist/favorite behavior and G5A enrichment remain
permanently guarded.

The exact debt snapshot moves `71 -> 59`: `unused_element` changes `43 -> 36`,
`unused_element_parameter` changes `22 -> 17`, `unused_field` remains `6`, and
Explore findings reach zero. Seventy-nine focused
source/analyzer/privacy/retention contracts, 125 focused Flutter tests and all
exact privacy, retention, G2 lifecycle and analyzer validators pass. The
complete standard-parallel gate passed in one execution on `3df03c0` with 384
Flutter tests plus one documented skip, Google-only, Web build/smoke and one
direct 448-task Android debug build. Both release inventories are rebound to
the exact Explore source without changing disclosure or release state.

The complete S4AW gate passed with the unchanged command, no retry or cleanup
and 999 MiB to 994 MiB available capacity. This does not close `TD-RR-012`:
deterministic release-host capacity and bounded-growth evidence remain open.

This package does not close `TD-RR-010`; 59 diagnostics in the remaining
unused-code categories still require reviewed downward ratchets to zero plus
exact-commit CI. P0B remains `HOLD` / `NO-GO`; no production, Payment, Store,
Cloud/VPS/DNS, deployment, signing, merge or public activation is enabled.

## S4AX DataService dead demo-code ratchet

`S4AX_DATA_SERVICE_DEAD_DEMO_CODE_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at implementation commit `0fcf3dd`. It removes four
unreferenced DataService demo remnants and their orphaned prefix. Active
debug-only QA fixtures, category initialization, real requests, express
timeouts, participant threads and canonical-receipt support remain permanently
guarded.

The exact debt snapshot moves `59 -> 55`: `unused_element` changes `36 -> 32`,
`unused_element_parameter` remains `17`, `unused_field` remains `6`, and
DataService findings reach zero. Ninety-eight focused
source/analyzer/privacy/retention/data-integrity contracts, 125 focused Flutter
tests and all exact privacy, retention, G2 lifecycle and analyzer validators
pass. The complete standard-parallel gate passed in one execution on
`0fcf3dd` with 384 Flutter tests plus one documented skip, Google-only, Web
build/smoke and one direct 448-task Android debug build. Both release
inventories are rebound without changing disclosure or release state.

The complete S4AX gate passed with the unchanged command, no retry or cleanup
and 980 MiB to 984 MiB available capacity. This does not close `TD-RR-012`:
deterministic release-host capacity and bounded-growth evidence remain open.

This package does not close `TD-RR-010`; 55 diagnostics in the remaining
screen-only unused-code categories still require reviewed downward ratchets to
zero plus exact-commit CI. P0B remains `HOLD` / `NO-GO`; no production,
Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public activation
is enabled.

## S4AY owner-detail dead-code ratchet

`S4AY_OWNER_DETAIL_DEAD_CODE_RATCHET` delivers the next downward `TD-RR-010`
source ratchet at implementation commit `a61cb4d`. It removes the seven
analyzer-confirmed unreferenced owner-detail elements and the private toast
wrapper exposed as their transitive orphan. Active server-issued pickup
challenges, return challenge verification, four-photo evidence, authenticated
return transition, cancellation and owner-to-renter review behavior remain
permanently guarded.

The exact debt snapshot moves `55 -> 48`: `unused_element` changes `32 -> 26`,
`unused_element_parameter` remains `17`, `unused_field` changes `6 -> 5`, and
the owner-detail analyzer bucket reaches zero. One hundred fifty-four focused
source/analyzer/privacy/retention/data-integrity contracts, 125 focused Flutter
tests and all exact privacy, retention, G2 lifecycle and analyzer validators
pass. The complete standard-parallel gate passed in one execution on
`a61cb4d` with 384 Flutter tests plus one documented skip, the separate
Google-only test, Web build/smoke and one direct 448-task Android debug build.
The privacy inventory is rebound to the exact source without changing its
draft or release state.

The complete S4AY gate passed with the unchanged command, no retry or cleanup
and 979 MiB to 978 MiB available capacity. This does not close `TD-RR-012`:
deterministic release-host capacity and bounded-growth evidence remain open.

This package does not close `TD-RR-010`; 48 diagnostics in booking-detail and
message-thread unused-code categories still require reviewed downward ratchets
to zero plus exact-commit CI. P0B remains `HOLD` / `NO-GO`; no production,
Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public activation
is enabled.

## S4AZ booking presentation-helper dead-code ratchet

`S4AZ_BOOKING_PRESENTATION_HELPER_DEAD_CODE_RATCHET` delivers the next
downward `TD-RR-010` source ratchet at implementation commit `c283b59`. It
removes six analyzer-confirmed unreferenced booking-detail presentation
helpers: the dead call and calendar actions, obsolete local handover-code
calculator, two unused deadline formatters and an unused completion-card text
closure. Active Maps/directions, server challenge issue/verification, booking
facts, cancellation policy and completion summary remain permanently guarded.

The exact debt snapshot moves `48 -> 42`: `unused_element` changes `26 -> 20`,
`unused_element_parameter` remains `17`, `unused_field` remains `5`, and the
booking-detail element bucket changes `12 -> 6`. One hundred forty-four
focused source/analyzer/privacy/retention/booking/legal contracts, 125 focused
Flutter tests and all exact privacy, retention, G2 lifecycle and analyzer
validators pass. The complete standard-parallel gate passed in one execution
on `c283b59` with 384 Flutter tests plus one documented skip, the separate
Google-only test, Web build/smoke and one direct 448-task Android debug build.
The privacy inventory is rebound to the exact source without changing its
draft or release state.

The complete S4AZ gate passed with the unchanged command, no retry or cleanup
and 972 MiB to 963 MiB available capacity. This does not close `TD-RR-012`:
deterministic release-host capacity and bounded-growth evidence remain open.

This package does not close `TD-RR-010`; 42 diagnostics in booking-detail and
message-thread unused-code categories still require reviewed downward ratchets
to zero plus exact-commit CI. P0B remains `HOLD` / `NO-GO`; no production,
Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public activation
is enabled.

## S4BA booking dead manual-pickup ratchet

`S4BA_BOOKING_DEAD_MANUAL_PICKUP_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at implementation commit `ebd0cf3`. It removes the
unreachable direct renter pickup QR/manual chain, its unused failure/manual
state and its transitive local gate helpers. Active pickup remains one
server-verified stepper flow with authenticated renter verification and four
role-bound evidence photos. Active return QR/manual confirmation remains
renter-presenter bound and transition guarded.

The exact debt snapshot moves `42 -> 33`: `unused_element` changes `20 -> 14`,
`unused_element_parameter` remains `17`, `unused_field` changes `5 -> 2`, and
the booking-detail element/field buckets reach zero. One hundred fifty-three
focused source/analyzer/privacy/retention/booking/legal contracts, 125 focused
Flutter tests and all exact privacy, retention, G2 lifecycle and analyzer
validators pass. The complete standard-parallel gate passed in one execution
on `ebd0cf3` with 384 Flutter tests plus one documented skip, the separate
Google-only test, Web build/smoke and one direct 448-task Android debug build.
The privacy inventory is rebound to the exact source without changing its
draft or release state.

The complete S4BA gate passed with the unchanged command, no retry, cleanup or
network switch and 981 MiB to 975 MiB available capacity. This does not close
`TD-RR-012`: deterministic release-host capacity and bounded-growth evidence
remain open.

This package does not close `TD-RR-010`; 33 diagnostics in booking-detail and
message-thread unused-code categories still require reviewed downward ratchets
to zero plus exact-commit CI. P0B remains `HOLD` / `NO-GO`; no production,
Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public activation
is enabled.

## S4BB booking fixed-default parameter ratchet

`S4BB_BOOKING_FIXED_DEFAULT_PARAMETER_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at implementation commit `efa5a8d`. It represents
seven never-selected modern-card variants and the never-selected initially
open cancellation state directly as their existing defaults. Active protected
pickup/return address surfaces, Maps actions and central cancellation copy
remain permanently guarded.

The exact debt snapshot moves `33 -> 25`: `unused_element` remains `14`,
`unused_element_parameter` changes `17 -> 9`, `unused_field` remains `2`, and
all booking-detail analyzer buckets reach zero. One hundred fifty-eight
focused source/analyzer/privacy/retention/booking/legal contracts, 125 focused
Flutter tests and all exact privacy, retention, G2 lifecycle and analyzer
validators pass. The complete standard-parallel gate passed in one execution
on `efa5a8d` with 384 Flutter tests plus one documented skip, the separate
Google-only test, Web build/smoke and one direct 448-task Android debug build.
The privacy inventory is rebound to the exact source without changing its
draft or release state.

The complete S4BB gate passed with the unchanged command, no retry, cleanup or
network switch and 977 MiB to 1147 MiB available capacity. This does not close
`TD-RR-012`: deterministic release-host capacity and bounded-growth evidence
remain open.

This package does not close `TD-RR-010`; the remaining 25 message-thread
diagnostics still require reviewed downward ratchets to zero plus exact-commit
CI. P0B remains `HOLD` / `NO-GO`; no production, Payment, Store,
Cloud/VPS/DNS, deployment, signing, merge or public activation is enabled.

## S4BC message-thread dead-helper ratchet

`S4BC_MESSAGE_THREAD_DEAD_HELPER_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at implementation commit `7cde3ea`. It removes six
uncalled message-thread helpers, including the translation picker exposed as a
transitive orphan. Active translation settings/menu, protected location
acceptance/reuse, time coordination, `needsReview` and canonical support remain
permanently guarded.

The exact debt snapshot moves `25 -> 20`: `unused_element` changes `14 -> 9`,
while `unused_element_parameter` remains `9` and `unused_field` remains `2`.
One hundred focused source/analyzer/privacy/retention/data-integrity contracts,
42 focused Flutter tests and all exact privacy, retention, G2 lifecycle and
analyzer validators pass. The complete standard-parallel gate passed in one
execution on `7cde3ea` with 384 Flutter tests plus one documented skip, the
separate Google-only test, Web build/smoke and one direct 448-task Android
debug build. The privacy inventory is rebound to the exact source without
changing its draft or release state.

The complete S4BC gate passed with the unchanged command, no retry, cleanup,
network switch or Pixel dependency and 1139 MiB to 1136 MiB available
capacity. This does not close `TD-RR-012`: deterministic release-host capacity
and bounded-growth evidence remain open.

This package does not close `TD-RR-010`; the remaining 20 message-thread
diagnostics still require reviewed downward ratchets to zero plus exact-commit
CI. P0B remains `HOLD` / `NO-GO`; no production, Payment, Store,
Cloud/VPS/DNS, deployment, signing, merge or public activation is enabled.

## S4BD message-thread legacy-UI ratchet

`S4BD_MESSAGE_THREAD_LEGACY_UI_RATCHET` delivers the next downward
`TD-RR-010` source ratchet at implementation commit `7c93081`. It removes nine
analyzer-confirmed unreachable Legacy-UI widgets and their two transitive
helpers. Active transaction composer, combined booking/time actions, confirmed
handover countdown, text/photo/file/location/time actions and compact booking
summary remain permanently guarded.

The exact debt snapshot moves `20 -> 3`: `unused_element` changes `9 -> 0`,
`unused_element_parameter` changes `9 -> 1` and `unused_field` remains `2`.
One hundred five focused source/analyzer/privacy/retention/data-integrity
contracts, 42 focused Flutter tests and all exact privacy, retention, G2
lifecycle and analyzer validators pass. The complete standard-parallel gate
passed in one execution on `7c93081` with 384 Flutter tests plus one documented
skip, the separate Google-only test, Web build/smoke and one direct 448-task
Android debug build. The privacy inventory is rebound to the exact source
without changing its draft or release state.

The complete S4BD gate passed with the unchanged command, no retry, cleanup,
network switch or Pixel dependency and 1136 MiB to 1143 MiB available
capacity. This does not close `TD-RR-012`: deterministic release-host capacity
and bounded-growth evidence remain open.

This package does not close `TD-RR-010`; two unused animation values and one
never-selected location-map loading variant require the final reviewed ratchet
to zero plus exact-commit CI. P0B remains `HOLD` / `NO-GO`; no production,
Payment, Store, Cloud/VPS/DNS, deployment, signing, merge or public activation
is enabled.

## S4BE Flutter analyzer-zero ratchet

`S4BE_FLUTTER_ANALYZER_ZERO_RATCHET` delivers the final downward
`TD-RR-010` source ratchet at implementation commit `2fd646b`. It removes the
disconnected message-input composition animation values and the never-selected
location-map loading branch. Active focus transitions, text/focus listener
lifecycle and the reachable map fallback remain permanently guarded.

The exact debt snapshot moves `3 -> 0`: `unused_element_parameter` changes
`1 -> 0`, `unused_field` changes `2 -> 0`, and every analyzer bucket is empty.
One hundred eleven focused source/analyzer/privacy/retention/data-integrity
contracts, 42 focused Flutter tests and all exact privacy, retention, G2
lifecycle and analyzer validators pass. The complete standard-parallel gate
passed in one execution on `2fd646b` with 384 Flutter tests plus one documented
skip, the separate Google-only test, Web build/smoke and one direct 448-task
Android debug build. The privacy inventory is rebound to the exact source
without changing its draft or release state.

The complete S4BE gate passed with the unchanged command, no retry, cleanup,
network switch or Pixel dependency and 1135 MiB to 1144 MiB available
capacity. This does not close `TD-RR-012`: deterministic release-host capacity
and bounded-growth evidence remain open.

The local source and deterministic-gate requirements of `TD-RR-010` are now
satisfied. Exact S4BE CI run `32608792863` is green at documentation commit
`4d914ed`: Backend passed in 1:31, Flutter passed in 6:36 and publishing was
skipped. `TD-RR-010` is closed while the exact-zero gate remains permanent.
P0B remains `HOLD` / `NO-GO`; no production, Payment, Store, Cloud/VPS/DNS,
deployment, signing, merge or public activation is enabled.

## S4BF release-readiness determinism closeout

`S4BF_RELEASE_READINESS_DETERMINISM_CLOSEOUT` is technically verified at exact
implementation commit `891ecdc414df1d1a6097608cb8dd05b8221361c3`. The
complete technical gate now enforces fixed release-host capacity and generated
footprint bounds before any work and after Android without cleanup, sleep,
retry or environment override.

The unchanged local gate passed with 384 Flutter tests plus one documented
skip, Google-only, analyzer zero, Web build/smoke and one direct 448-task
Android debug build. Exact automatic CI run `32609567488` passed Backend in
1:39 and Flutter in 6:38 with publication skipped. Manual exact-head run
`32609858706` passed five complete default-parallel Flutter suites, Backend in
1:13 and Flutter in 14:42; signed-candidate construction and publication were
skipped.

The separately required S4W controlled browser observation also passed in a
dedicated temporary Chrome profile against the loopback Web build with
`readyState: complete` and nine verified keys. No stored values, credentials
or profile path were retained, the normal profile was untouched and temporary
artifacts were moved to Trash.

This closes `TD-RR-001`, `TD-RR-002`, `TD-RR-003`, `TD-RR-005`, `TD-RR-006`,
`TD-RR-007`, `TD-RR-008`, `TD-RR-009` and `TD-RR-012`. `TD-RR-004` remains
open for exact CI execution of the repository-owned PostgreSQL-16 fresh-cluster
runner; service-container integration is not substituted for that proof. P0B
remains `HOLD` / `NO-GO`; no production, Payment, Store, Cloud/VPS/DNS,
deployment, signing, merge or public activation is enabled.

## S4BG PostgreSQL runner CI closeout

`S4BG_POSTGRES_RUNNER_CI_CLOSEOUT` is technically verified at exact source head
`72adea23b38eb56528f257f1980b6d9c44c1c44e`. A separate Ubuntu-24.04 CI job
now runs the repository-owned PostgreSQL-16 fresh-cluster runner without a
service, caller database, port, bin override or lifecycle commands. Later
API-image publication is gated on this proof.

First exact run `32610811354` correctly failed because Ubuntu's default Unix
socket directory is not writable by the hosted runner. No retry or privilege
workaround was accepted. The runner source now disables unused Unix sockets
and retains its isolated loopback-TCP transport. Nine focused local contracts
and a real local PostgreSQL-16 run pass with zero remaining temp roots.

Exact run `32610904963` passed the independent runner in 32 seconds with
`passed-and-cleaned`, Backend in 1:20 and Flutter in 6:21. Signed-candidate
construction and publication stayed skipped. `TD-RR-004` is closed; the
release-readiness Technical-Debt register is now 12/12 closed. P0B and every
legal, staffing, device/iOS, PSP, privacy/retention, Store and activation gate
remain fail-closed.

## S4BH external gate technical setup

`S4BH_EXTERNAL_GATE_TECHNICAL_SETUP` is technically verified at exact
implementation head `6f48a0be40e77a3ff0f5cc12581bb7820d0ef2cd`. One
machine-readable manifest and an ordered runbook now bind the ten remaining
external launch gates to their canonical repository evidence. All technical
preparations are complete, while external readiness remains exactly `0/10`.

The ordinary validator returns `prepared-hold`; strict readiness intentionally
fails with all ten unresolved gate IDs. It cross-checks Legal, Operations,
Android/iOS, Firebase, PSP, Privacy/Retention, Store, Economics, pilot and P0B
truth, rejects credential-shaped fields and permits no missing or unsafe
evidence reference. The Store documentation now also reflects the already
recorded machine truth that Google Play account setup is ready while Apple
membership and Firebase owner terms remain open.

Six focused contracts and the complete unchanged local gate passed with
analyzer zero, 384 Flutter tests plus one documented skip, Google-only, Web
build/smoke and one direct 448-task Android debug build. The capacity guard
recorded only 4 KiB generated growth. Exact CI run `32611637355` passed Backend
in 1:15, the repository PostgreSQL-16 runner in 0:33 and Flutter/Web/Android in
6:30; signed-candidate construction and publication stayed skipped.

No login, external account, paid service, production, Payment, Store,
Cloud/VPS/DNS, pilot or activation state changed. S4BH is complete, but the ten
authentic professional/owner/provider/device decisions and Walid's final
activation decision remain external. P0B remains `HOLD` / `NO-GO`.

## S4BI PostgreSQL single-client serialization

`S4BI_POSTGRES_SINGLE_CLIENT_SERIALIZATION` is technically verified at exact
implementation head `76cb6368af8e8d50e4db7d6e11ac38b2211ffe1c`. A real
PostgreSQL warning identified transaction-scoped `Promise.all` query batches
that `pg` 8 serialized internally but `pg` 9 will reject. A retained red
diagnostic with `--throw-deprecation` failed at the first affected booking
query; it was neither suppressed nor retried.

Six transactional workflow sources now issue those same reads in explicit
order on their existing checked-out client. The canonical fresh-cluster runner
always enables hard deprecations, and a source contract rejects reintroduced
parallel same-client batches. Privacy and retention hashes were rebound to the
exact reviewed sources without changing their draft/HOLD decisions.

The real PostgreSQL-16 runner returned `passed-and-cleaned`, Backend passed 605
tests with one documented no-database skip, and the complete unchanged local
gate passed with analyzer zero, 384 Flutter tests plus one documented skip,
Google-only, Web build/smoke, one direct 448-task Android build and zero
generated-footprint growth. Exact CI `32612314131` passed the independent
PostgreSQL proof in 31 seconds, Backend in 1:19 and Flutter/Web/Android;
the latter completed in 6:23, while signing and publication stayed skipped.

This closes `TD-RR-013`; all 13/13 deterministic release-readiness debt exits
are retained. No external or live state changed, external readiness remains
0/10 and P0B remains `HOLD` / `NO-GO`.

## S4BJ file-picker security floor

`S4BJ_FILE_PICKER_SECURITY_FLOOR` is technically verified at exact
implementation head `95b0ead45c6a7706b4a65a1f054cd2a87403b289`. The
client now requires and locks `file_picker` 11.0.3, above the upstream 11.0.2
Android path-traversal fix and including 11.0.3's removal of Apache Tika from
MIME detection. Listing, chat and handover/return consumers use the reviewed
static API with unchanged selection policy. A source contract rejects a floor
or lock regression, the removed instance API and any unreviewed call count.

Four focused contracts, analyzer zero, 384 Flutter tests plus one documented
skip and exact Privacy/Retention validation pass. A first complete gate
correctly refused the Mac's 4,161,440-KiB effective capacity. The fixed limit
was not changed; obsolete diagnostic output and one unused old package-cache
entry were handled as recoverable, regenerable local data. The identical gate
then passed from 4,211,432 KiB effective capacity through Web and one direct
448-task Android build, ending with 1,011,156 KiB free.

Exact clean-host CI `32613104943` passed PostgreSQL in 35 seconds, Backend in
1:22 and Flutter/Web/Android in 6:24. Signing and publication stayed skipped.
The cache action is not acceptance evidence; `TD-RR-012` remains closed by the
retained guard and exact CI. Remaining third-party Wasm/Android warnings stay
visible for separate bounded packages. External readiness remains 0/10 and
P0B remains `HOLD` / `NO-GO`.

## S4BK PDF, WebAssembly and offline-font hardening

`S4BK_PDF_WASM_OFFLINE_FONT_HARDENING` is technically verified at exact
implementation head `52aa41f8807c5a36f251e4bad1a32c2120fa4454`. A bounded
`pdf`/`printing` update locks `pdf` 3.12.0, `printing` 5.14.3 and transitive
`image` 4.9.2, removing the prior WebAssembly findings without disabling
Flutter's dry run or broadly updating the dependency tree.

The complete regression runner now fails on a Web build error or either former
finding signature while preserving visible success output. The first real
financial-PDF compatibility test also found unsupported en-dash glyphs in the
default Helvetica path. Financial documents now use bundled, hash-bound Roboto
Regular/Bold assets from the official v3.015 release with the SIL OFL 1.1
license shipped offline. No amount or immutable server snapshot is
recalculated.

Focused contracts, real PDF generation, Privacy, analyzer zero and the
complete local gate pass with 385 Flutter tests plus one documented skip,
Google-only, Web build/smoke and one direct 448-task Android build. The gate
started at 4,230,920 KiB effective capacity and ended with 878,200 KiB free,
3,307,728 KiB generated and 100,968 KiB growth. Four unused Pub-cache versions
were moved recoverably off the constrained data volume before the run; that is
not acceptance evidence.

Exact clean-host CI `32613968872` passed PostgreSQL in 39 seconds, Backend in
1:19 and Flutter/Web/Android in 6:39. The CI log proves 385 passes plus one
documented skip, analyzer zero, positive WebAssembly dry-run success, no former
finding signature and Android success. Signing and publication stayed
skipped. `TD-RR-014` is closed and all 14/14 deterministic exits are retained.
Android vendor warnings remain visible for separate bounded assessment.
External readiness remains 0/10 and P0B remains `HOLD` / `NO-GO`.

## S4BL Android lifecycle Gradle floor

`S4BL_ANDROID_LIFECYCLE_GRADLE_FLOOR` is technically verified at exact
implementation head `fcd2a0d761c6b1e70011c29b1561eac4f47a09e1`. The bounded
package changes only the transitive Android lifecycle bridge from 2.0.30 to
2.0.35. Its exact checksum and compatible Flutter 3.41.7 local/CI floors are
guarded. A direct 448-task `--warning-mode all` build confirms that the former
lifecycle Groovy syntax deprecation is absent without patching the Pub cache
or suppressing the remaining vendor/SDK warnings.

The complete runner now permanently executes the S4BJ file-picker security,
S4BK PDF/WebAssembly and S4BL lifecycle contracts; each contract rejects its
own removal. Eleven focused tests, the unchanged complete local gate and exact
clean-host CI `32614834455` pass. CI completed PostgreSQL in 39 seconds,
Backend in 1:22 and Flutter/Web/Android in 6:48; signing and publication stayed
skipped.

This closes `TD-RR-015`; all 15/15 deterministic release-readiness debt exits
are retained. Remaining lifecycle-manifest, SDK XML and third-party Android
warnings stay visible for later bounded compatibility work. External readiness
remains 0/10 and P0B remains `HOLD` / `NO-GO`.

## S4BM Android Gradle warning visibility

`S4BM_ANDROID_GRADLE_WARNING_VISIBILITY` is technically verified at exact
implementation head `1ad3410bd144be6fe5c5af65f1dd6a586573ad3d`. The complete
gate keeps one direct Android build, now with `--warning-mode all`. It captures
and prints the full output, preserves any build failure and rejects warning
locations from the checked-out SIT Android Build or Settings files. It neither
adds a second build nor treats current vendor warnings as an accepted
fingerprint.

Eleven focused contracts and the unchanged complete local gate pass. The
single Android build completes 448 tasks; every local warning source is outside
the repository-owned Android scripts. Exact clean-host CI `32615539334` passes
PostgreSQL in 40 seconds, Backend in 1:23 and Flutter/Web/Android in 6:27. Its
full warning locations are resolved Pub-cache plugin paths and no SIT-owned
warning passed. Signing and publication remain skipped.

This closes `TD-RR-016`; all 16/16 deterministic release-readiness debt exits
are retained. Vendor warnings remain visible for separately reviewed compatible
dependency work. External readiness remains 0/10 and P0B remains `HOLD` /
`NO-GO`.

## S4BN Android Gradle-9 bridge floors

`S4BN_ANDROID_GRADLE9_BRIDGE_FLOORS` is technically verified at exact
implementation head `09094df2d74c68293866160289179413830a627f`. The newest
resolvable three-bridge probe failed honestly because its AndroidX artifacts
require compile SDK 36 and AGP 8.9.1 or later. The retained package instead
locks only the earliest compatible upstream Gradle-9 corrections for
ImagePicker Android 0.8.13+4, SharedPreferences Android 2.4.15 and URL-Launcher
Android 6.3.24, with exact checksums and no direct API or toolchain change.

Fourteen focused contracts, a direct 448-task all-warning build and the
complete local gate pass. The three updated plugin warning paths are absent;
the same single Android build is followed by a real `aapt` inspection that
requires merged minSdk 24. Analyzer zero, 385 Flutter tests plus one documented
skip, Google-only, Web/Wasm and loopback smoke remain green with only 4 KiB
generated growth.

Exact clean-host CI `32616408339` passes PostgreSQL in 31 seconds, Backend in
1:28 and Flutter/Web/Android in 6:37;
signing and publication remain skipped. This closes `TD-RR-017`; all 17/17
deterministic exits are retained. Other vendor warnings remain visible for
separate bounded packages. External readiness remains 0/10 and P0B remains
`HOLD` / `NO-GO`.

## S4BO PathProvider Android Gradle floor

`S4BO_PATH_PROVIDER_ANDROID_GRADLE_FLOOR` is technically verified at exact
implementation head `620b7298847fc2732b789be731a17adfb027adfd`. The package
locks only transitive `path_provider_android` 2.2.19 with its exact checksum
and retains the compatible Flutter 3.41.7 floors. It removes that package's
former Gradle-9/10 Build-file warning without a dependency override, Pub-cache
patch, warning suppression, retry, broad Android toolchain change or the later
2.3.x JNI migration.

Seventeen focused contracts, a direct 448-task all-warning build and the
complete local gate pass. The new contract is permanently registered, the
PathProvider warning path is absent, and real `aapt` inspection keeps the
merged APK floor at minSdk 24. Analyzer zero, 385 Flutter tests plus one
documented skip, Google-only, Web/Wasm and loopback smoke remain green with
zero generated growth.

Exact clean-host CI `32616929359` passes PostgreSQL in 39 seconds, Backend in
1:23 and Flutter/Web/Android in 7:07; signing and publication remain skipped.
This closes `TD-RR-018`; all 18/18 deterministic exits are retained. Other
vendor warnings remain visible for separately reviewed packages. External
readiness remains 0/10 and P0B remains `HOLD` / `NO-GO`.

## S4BP Printing Web PDF.js reachability guard

`S4BP_PRINTING_WEB_PDFJS_REACHABILITY_GUARD` is technically verified at exact
implementation head `0ec4d0a37e633d9759d3120c3b26b36bfbabbbf7`. The reviewed
Printing Web adapter embeds PDF.js 3.2.146, below Mozilla's patched floor for
CVE-2024-4367. Printing 5.15.0 is not a safe bounded update on the pinned Dart
3.11.5 toolchain and its PDF.js 5.7.284 is below the later CVE-2026-16633
patched floor. No false patched-version claim or incompatible dependency
update was accepted.

The retained fail-closed contract instead binds the exact package checksum and
resolved adapter hashes, and proves that the application's three `layoutPdf`
and one `sharePdf` calls do not initialize the PDF.js loader. Any preview,
raster, conversion, direct-print, printer-discovery, platform-level or
additional Printing use fails the complete gate.

Eighteen focused assertions and the complete local gate pass with analyzer
zero, 385 Flutter tests plus one documented skip, Google-only, Web/Wasm,
loopback smoke, Android 448 tasks and binary minSdk 24. Exact clean-host CI
`32617626521` passes PostgreSQL in 54 seconds, Backend in 1:18 and
Flutter/Web/Android in 6:32 with all four reachability subtests and 445 Android
tasks. Signing and publication remain skipped. This closes `TD-RR-019`; all
19/19 deterministic exits are retained. External readiness remains 0/10 and
P0B remains `HOLD` / `NO-GO`.

## S4BQ MobileScanner iPhone 17 floor

`S4BQ_MOBILE_SCANNER_IPHONE17_FLOOR` is technically verified at exact
implementation head `910e88824784a4a5127e36d82be47356e052f577`. The bounded
package pins only MobileScanner 7.1.4, the immediate patch after 7.1.3, and
retains the upstream Apple correction for an iPhone 17 scanner-start crash.
Later 7.2 through 7.4 scanner behavior, Web-backend and Android-toolchain
changes remain excluded.

The permanent contract binds the exact Pub checksum and resolved Swift,
Android and public-Dart-API hashes. It requires selection from available Apple
pixel formats before configuring video output, rejects the former unconditional
BGRA assignment, retains assignment-safe Android compileSdk-36/minSdk-23/Java-
17 fields and keeps application scope at the two pickup/return scanner surfaces.

The first complete gate correctly rejected the stale Privacy source hash for
the changed dependency declaration. Exact rebinding changed no Privacy or
Retention decision; all 58 contracts then passed. The identical complete local
gate passes analyzer zero, 385 Flutter tests plus one documented skip,
Google-only, Web/Wasm, loopback smoke, Android 448 tasks and binary minSdk 24.
The MobileScanner warning path is absent.

Exact clean-host CI `32618368745` passes PostgreSQL in 29 seconds, Backend in
1:33 and Flutter/Web/Android in 7:01 with all four scanner contracts, 445
Android tasks and no MobileScanner warning path. Signing and publication remain
skipped. This closes `TD-RR-020`; all 20/20 deterministic exits are retained.
Physical Apple-device validation remains external. External readiness remains
0/10 and P0B remains `HOLD` / `NO-GO`.

## S4BR GitGuardian RFC 5737 false-positive review

`S4BR_GITGUARDIAN_RFC5737_FALSE_POSITIVE_REVIEW` closes the four newly surfaced
GitGuardian Generic Password incidents from historical commit `8e982a3` as
reviewed false positives. Redacted inspection proves that all four candidates
are RFC 5737 documentation-only IPv4 addresses used only as `forwardedFor`
arguments in the PostgreSQL integration test. They are not credentials, none
is present in the current file, and GitGuardian shows zero files requiring a
code fix with the source tagged as a test file.

Incidents `36505639`, `36505640`, `36505641` and `36505642` are individually
`Ignored` with reason `This is not a secret (false positive)`. Each state was
verified. Detector and integration rules remain active and unchanged; no
history rewrite, force push, credential-rotation claim or secret disclosure
was used.

GitHub Actions run `32618862277` passes the exact preceding head `355ec324`
with PostgreSQL in 37 seconds, Backend in 1:14 and Flutter/Web/Android in 6:26;
signing and publication remain skipped. This documentation push supplies the
new-head GitGuardian re-evaluation without an empty commit. External readiness
remains 0/10 and P0B remains `HOLD` / `NO-GO`.

## S4BS/S4BT canonical support workflow closeout

`S4BS_SUPPORT_STATUS_MACHINE_V1_ALIGNMENT` at
`daf7a79e6bdb36926dce46fea37756af0fb89b58` now binds the canonical Drive
status source exactly: 11 statuses, 18 transitions, no active
`implementation_pending` compatibility state. Migration `064` is fail-closed
for incompatible stored history and retains the old column as NULL-only rather
than deleting it.

`S4BT_SUPPORT_DIRECT_DECISION_PATH` at
`5e6f99cf074b66d3dd9119f30903894bcb224350` completes the source-defined
green/yellow route using one active Administrator and an immutable direct
approval hash. Red decisions retain a distinct Administrator reviewer and the
four-eyes path. Application, migration wiring, unit tests and fresh PostgreSQL
integration all enforce that split.

The exact S4BT head passes 605 backend tests plus one expected no-database
skip, fresh PostgreSQL 16 and the full local Flutter/Web/Android gate. GitHub
Actions run `32620871777` is green for S4BS; run `32621468236` is the exact S4BT
clean-host run and passes PostgreSQL in 35 seconds, Backend in 1:30 and
Flutter/Web/Android in 6:37. No production, provider, Payment, Store,
Cloud/VPS/DNS, pilot, signing or merge gate changed. The next bounded package
is the fail-closed traceability mapping for all 167 unique Support Packet
matrix scenarios before selecting further support hardening.

## S4BU Support Packet matrix traceability gate

`S4BU_SUPPORT_MATRIX_TRACEABILITY_GATE` at exact commit
`a4fbb280d6908c5f8c8be7b758664bdc563a834f` closes the S1 traceability backlog.
It binds the exact current Drive matrix source and maps every one of its 167
unique scenarios once to executable, anchored repository tests across ten
functional areas.

The validator requires the canonical 112/20/8/27 gate distribution and keeps
all technical coverage explicitly non-live. Every Public Launch and Real Money
scenario is simultaneously held open for external evidence: 47 required, zero
present, strict release readiness false. Missing, duplicate or overlapping
IDs, source drift, gate drift, missing tests or changed anchors all fail the
complete regression.

Six focused tests and the full local Flutter/Web/Android gate pass, including
385 Flutter tests plus one documented skip, analyzer zero, WebAssembly dry-run,
loopback smoke, 448 Android tasks and only 8 KiB generated growth. Clean-host
run `32622192273` passes PostgreSQL in 58 seconds, Backend in 1:18 and
Flutter/Web/Android in 6:30; signing and publication remain skipped. No
production, provider, Payment, Store, Cloud/VPS/DNS, pilot or merge state
changed. P0B remains `HOLD` / `NO-GO`.

## S4BV external-gate Support Matrix linkage

`S4BV_EXTERNAL_GATE_SUPPORT_MATRIX_LINKAGE` at exact commit
`66f022e5d823d7d96bd6747e0096208cd71f0f7c` closes the aggregate traceability
gap between S4BH's ten prepared external gates and S4BU's canonical 167-row
Support Matrix map.

The external setup preflight now executes the full Support traceability
validator, reproduces the exact 167/47/0 scenario state and requires the
common evidence reference on exactly Legal/operator, PSP sandbox,
Privacy/Retention, Store and explicit activation. Count/source drift,
misplaced references and premature ready states all fail closed. The setup
remains 10/10 technically prepared, 0/10 externally ready and `hold-no-go`;
the strict Support and external-gate checks remain intentionally red.

Fourteen focused tests and the unchanged full local Flutter/Web/Android gate
pass with analyzer zero, 385 Flutter tests plus one documented skip, Google-
only, WebAssembly, loopback smoke, Android 448 tasks, minSdk 24 and 12 KiB
generated growth. Clean-host run `32622784481` passes PostgreSQL in 38 seconds,
Backend in 1:39 and Flutter/Web/Android in 7:17. Signing and publication stay
skipped. No external account, contract, production, Payment, Store,
Cloud/VPS/DNS, pilot, real-money, activation or merge state changed. P0B
remains `HOLD` / `NO-GO`.

## S4BW Support evidence scanner and upload-policy gate

`S4BW_SUPPORT_EVIDENCE_SCANNER_UPLOAD_POLICY_GATE` at exact commit
`7f81757abe39bc50d3dc2af8fd7cc9464f7bf1f8` closes the missing technical gate
for the Support source's mandatory upload-limit configuration and no-silent-
defaults rule.

The package adds a source-bound readiness manifest, an eight-decision
fail-closed validator, seven permanent tests and a final setup runbook. It also
promotes the aggregate external setup from ten to 11 required gates and binds
the new state into its validator, tests and permanent regression. Production
intake stays disabled, scanner transport remains `none`, external AI remains
off and the current 8 MiB value remains explicitly unapproved.

All 22 direct tooling contracts and 70 related workflow/security/privacy/
retention contracts pass. The complete local gate passes analyzer zero, 385
Flutter tests plus one documented skip, Google-only, WebAssembly, loopback
smoke, Android 448 tasks, minSdk 24 and zero generated growth. Clean-host run
`32623897547` passes PostgreSQL in 26 seconds, Backend in 1:16 and
Flutter/Web/Android in 7:03; signing and publication remain skipped.

External readiness is 0/11, scanner/upload-policy decisions are 0/8 and the
Support Matrix external-evidence hold is 0/47 present. No external provider,
contract, paid service, upload, production, Payment, Store, Cloud/VPS/DNS,
pilot, real-money, activation or merge action occurred. The next autonomous
step is another bounded source-to-code external-gate audit before selecting a
new non-live technical preparation package. P0B remains `HOLD` / `NO-GO`.

## S4BX active infrastructure and mail provider gate

`S4BX_ACTIVE_INFRASTRUCTURE_MAIL_PROVIDER_GATE` at exact commit
`aa1b821a940ac5a8cb808ec1dd5599086360995c` closes the inventory gap between
the classified active hosting/SMTP processors and the Privacy/Retention
external-service lists.

Hostinger VPS and Google Workspace SMTP relay are now explicit, fail-closed
processor entries. Privacy lists eleven external services; Retention lists six
processors and exposes the missing official, service-readiness and owner
evidence for the two new entries. Ten authentic external decisions remain
open. A dedicated source/hash-bound validator and seven permanent tests reject
hidden processors, source drift, invented review, partial approval, sensitive
data and external mutation claims.

The aggregate external setup references the provider readiness from exactly
Legal/operator and Privacy/Retention. It remains 11/11 technically prepared,
0/11 externally ready and `hold-no-go`; active-provider decisions are 0/10.
The 81 focused and 58 adjacent contracts pass. The complete local gate passes
analyzer zero, 385 Flutter tests plus one documented skip, Google-only,
WebAssembly, loopback smoke, Android 448 tasks, minSdk 24 and 12 KiB generated
growth. Clean-host run `32625380409` passes PostgreSQL in 30 seconds, Backend
in 1:51 and Flutter/Web/Android in 6:36. Signing and publication remain
skipped.

No account inspection, provider/contract/cost action, VPS/mail/production,
Payment, Store, Cloud/DNS, pilot, real-money, activation or merge occurred.
The next autonomous step is another bounded external-gate source-to-code audit
for a technically preparable gap. P0B remains `HOLD` / `NO-GO`.

## S4BY CodeQL backend security gate

`S4BY_CODEQL_BACKEND_SECURITY_GATE` at exact implementation head
`992af57cbf555534c6db03898b3a4aac61cbd996` closes the repository's missing
semantic code-scanning path. The public repository already had locked Backend
dependency audit and secret detection, but no CodeQL analysis.

The new workflow runs CodeQL v4 with the `security-extended`
JavaScript/TypeScript query suite on pull requests, direct `main` pushes, a
weekly schedule and explicit manual dispatch. Feature branches are not scanned
twice. Workflow permissions are read-only except for the required
`security-events: write`; no secret, artifact publication, deployment or
continue-on-error route exists. Three permanent wiring tests bind this
contract into every complete technical regression.

Exact CodeQL run `32626620094` passes in 1:50, evaluates 103 rules and reports
zero open code-scanning alerts. Exact clean-host regression `32626620177`
passes PostgreSQL in 27 seconds, Backend in 1:27 and Flutter/Web/Android in
6:37. Local metadata-only regression passes analyzer zero, 385 Flutter tests
plus one documented skip, Google-only, Web/WebAssembly, loopback smoke,
Android 448 tasks, binary minSdk 24 and zero generated growth. Local
`pnpm audit --prod` reports zero vulnerabilities at every severity.

The ordinary local Store handoff first stopped fail-closed because the exact
protected AAB is unavailable in the private release archive. The package does
not replace it and makes no Store, signing or device claim. No repository
visibility, production, provider, Payment, Store, Cloud/VPS/DNS, pilot,
real-money, activation or merge state changed. The next autonomous step is a
fresh source-to-code audit for another independently implementable security or
launch-readiness gap. PR #7 remains draft and P0B remains `HOLD` / `NO-GO`.

## PF0 — pilot-freeze baseline

`PF0_PILOT_FREEZE_BASELINE` freezes the product scope from exact verified
source HEAD `e1c69a6ad3086061cfaedf14d2bc63537ad82650`. GitHub regression
`32627029742` and CodeQL `32627029780` are both successful on that HEAD; the
Working Tree was clean and synchronized, and PR #7 remained open, Draft and
unmerged at verification.

The permanent record `docs/operations/PILOT_FREEZE_BASELINE.md` separates
technical implementation/test evidence from external evidence, professional
approval, pilot approval, real-money approval and public-launch approval. It
restricts future PR #7 work to P0/P1 defects, pilot blockers, reproducible
release failures, existing external gates and authentic pilot/device findings.
P2-P4 findings are backlog-only. No live or external state changed.

Next package: PF1 creates the human-readable and machine-readable three-stage
pilot/launch matrix while keeping every activation boundary closed.

## PF1 — three-stage pilot and launch matrix

`PF1_PILOT_AND_LAUNCH_TIERS` adds
`docs/operations/PILOT_AND_LAUNCH_TIERS.md` and the machine contract
`docs/evidence/external-gates/pilot-launch-tier-matrix.json`. Stage A is the
smallest invited Android candidate without real money; Stage B adds the full
Marketplace-PSP and Echtgeld evidence chain; Stage C adds every public regional
launch gate. The levels technically implemented, technically tested,
externally evidenced, professionally approved, pilot approved, real-money
approved and public-launch approved remain distinct.

The validator binds Stage A to at most 30 invited adults, 30-50 planned flows,
Spiegelberg, the three Cat8 paths, V5.2 single-item plus Discover/cart/Gemerkt,
and synthetic/test payment. It also enforces all G3-G5 conditional entry gates,
the eight open Stage B sandbox proofs and a fully disabled Stage C. Eight
focused tests pass; strict Stage A mode correctly stops on missing external
evidence and the explicit decision.

Next package: PF2 classifies the existing eleven external gates by their first
blocking tier and prepares the execution board without satisfying any gate.

## PF2 — external gate execution board

`PF2_EXTERNAL_GATE_EXECUTION_BOARD` adds the human-readable execution board
and a matching machine contract. Every one of the eleven canonical lanes now
contains its objective, current state, existing technical evidence, missing
external evidence, responsible role, unknown/known cost state, contract need,
Walid-presence flag, exact next action, dependency list, stop condition and a
unique unissued release token.

The classification is fail-closed: seven lanes block Stage A; PSP blocks only
Stage B and later; authentic economics blocks only Stage C; iOS and arbitrary
Support file intake may be deferred for Stage A only under their named disabled
capability conditions. Store work for Stage A is limited to proving the exact
private Android distribution candidate and is not public submission.

Eight focused tests pass. The validator reconciles the board against the
canonical 11/11 technically prepared and 0/11 externally ready manifest and
current Legal, Operations, signing/device, scanner, PSP, Privacy/Retention,
Store, economics and pilot sources. It rejects cycles, unsafe deferrals,
sensitive fields, issued tokens and any external mutation claim. Strict Stage
A readiness correctly fails on all seven blockers.

Next package: PF3 turns these lanes into a minimal ordered Walid action pack
without starting cost, contract, account, signing, Store or pilot activity.

## PF3 — Walid external gate action pack

`PF3_WALID_EXTERNAL_GATE_ACTION_PACK` creates twelve short, sequential blocks
under A closed Android/no money, B closed real money, C public regional launch
and D iOS/later platforms. Each block contains exactly the seven requested
operational fields and copyable response tokens.

Costs remain honest: known prior Google registration is separated from every
unknown future amount, quote-only permission does not authorize engagement,
and a separate maximum-EUR response pattern is required before paid Legal or
PSP work. Read-only owner-console readiness does not authorize login handling,
terms, billing, keys, permissions, signing, upload or Store action.

The validator reconciles the pack against PF2's eleven open gates and requires
all canonical release tokens, Stage A/B/C decision choices and the Android-only
and disabled-upload deferrals. Eight focused tests pass; strict mode correctly
stops at A1 with only `PF3_A1_QUOTE_REQUEST_PACK_GO` or `PF3_A1_HOLD` as the
next bounded answer.

Next package: PF4 freezes the exact PR #7 integration and pilot-candidate path
without merge, history rewrite, signing, upload or publication.

## PF6 — current-head Android release candidate

`PF6_CURRENT_HEAD_ANDROID_RELEASE_CANDIDATE` closes the previously missing
exact current-head signed direct-install evidence under the later maximum
non-public launch-readiness authorization. Source commit
`76e6565cdb20d6a49fb417e87b044b237a1ae6c1` produced canonical signed
`1.0.0+2026082301` AAB/APK artifacts, passed final-binary privacy validation
and is retained in a verified owner-only private archive. Regression
`32633048693` and CodeQL `32633048658` pass on the exact source.

The preserving Pixel 7 Pro update passes signature, version, installed-byte,
first-install-time, app-data-inode and launch checks. No uninstall, reset,
downgrade, screenshot, user content or raw identifier was used or retained.
The result is direct internal installation only; Google Play distribution,
closed testing, submission and public release remain false.

`TD-PF6-001` records the initial low-disk build failure and rejected external
scratch experiment. It is closed by a successful deterministic internal-APFS
rerun, a fixed 5 GiB effective-capacity floor enforced by the release builder,
configured-SDK discovery through `android/local.properties` and permanent
tests. Cache deletion, external scratch storage and an exported SDK path are
not durable prerequisites.

The next autonomous lane is another source-bound Stage A gap that can be
improved without Store upload, external account decisions, cost, contract,
production or activation. External readiness remains 0/11 and P0B remains
`HOLD` / `NO-GO`.

## PF7 — current-head Android restart diagnostic

`PF7_CURRENT_HEAD_ANDROID_RESTART_DIAGNOSTIC` adds a reusable, source-bound
physical-device command for the exact PF6 candidate. It revalidates the
repository record and owner-only archive, matches the installed APK bytes and
version, verifies process absence after force-stop, launches once and proves
the process returned. First-install time and the credential-encrypted app-data
inode remain unchanged.

The checked evidence records no screen, UI hierarchy, account content, raw
device/process identifier, private path or opaque marker. Tests reject a
locked phone, binary mismatch, marker drift, sensitive output and every A14,
Store or live overclaim. The diagnostic leaves the app running.

PF7 is deliberately narrower than PF5 A14: it does not claim authenticated
session restore, delayed acknowledgement or server reconciliation, and A14
therefore remains `not-run` as a complete pilot scenario. No Store, pilot,
participant, production, Payment, Cloud/VPS/DNS, provider, contract, cost,
real-money, public activation or merge action occurred.

The next autonomous lane is the remaining source-bound functional preparation
that can use isolated synthetic state without external accounts, live traffic
or a pilot claim. Stage A remains `HOLD` / `NO-GO`.

## PF8 — current-head Android authenticated cold start

`PF8_CURRENT_HEAD_ANDROID_AUTHENTICATED_SESSION` adds a source-bound
`--current-head` route to the reusable authenticated-session diagnostic. It
cannot accept a candidate-directory override and validates the PF6 evidence,
owner-only archive and exact installed APK before device interaction.

Two physical Pixel force-stop/launcher cycles restored the existing
authenticated profile actions and excluded the guest actions. Temporary UI
hierarchies were deleted after each read; evidence contains no hierarchy,
screen content, identity, credentials, tokens, review account data, raw device
identifier or private path. The diagnostic leaves the app on Explore and now
also uses the current Android keyguard fields and a bounded failure cleanup.

PF8 is not complete PF5 A14 evidence. Pending-submission acknowledgement,
duplicate prevention and authoritative server reconciliation remain open, as
do authenticated deep links, booking roles, real push, TalkBack and Store
delivery. No login/logout, account mutation, network change, participant,
Store, production, Payment, Cloud/VPS/DNS, provider, contract, cost,
real-money, public activation or merge action occurred.

The next autonomous lane is a current-head guest or isolated-synthetic
functional surface that can be proven without altering the preserved account,
using a live provider or claiming a pilot pass. Stage A remains
`HOLD` / `NO-GO`.

## PF9 — current-head Android offline cold start and recovery

`PF9_CURRENT_HEAD_ANDROID_OFFLINE_SESSION` extends the exact PF6/PF8 physical
route with a fail-closed offline boundary. It requires a genuinely reachable
Internet connection before changing anything, disables both Android network
transports, proves no connectivity, runs two authenticated cold starts and
restores the original transports in a `finally` path. Recovery succeeds only
after Internet reachability returns.

The machine evidence and validator bind the source, protected archive,
installed direct APK, Pixel class, two session observations, disconnect and
reconnect results while excluding WLAN/account identifiers and all live or
Store claims. Focused tests reject a missing online precondition, unproven
offline state, toggle-only recovery, sensitive network data and any functional
or Store overclaim.

PF9 is narrower than full PF5 A15. It does not use a second WLAN or exercise a
safe pending mutation and authoritative reconciliation, so full A15 remains
`not-run`. No account mutation, participant, Store, production, Payment,
Cloud/VPS/DNS, provider, contract, cost, real-money, public activation or merge
action occurred.

The next autonomous lane is another current-head, session-preserving Stage A
surface that can be proven without account mutation, external credentials,
live providers or Store upload. Stage A remains `HOLD` / `NO-GO`.

## PF10 — current-head Android authenticated safe links

`PF10_CURRENT_HEAD_ANDROID_AUTHENTICATED_SAFE_LINKS` adds a paired,
non-overridable current-head and authenticated-session-preservation mode to the
existing app-link diagnostic. It revalidates the exact PF6 candidate and
direct-installed APK, accepts no vault and refuses current Android lock states.

The physical Pixel run proves authenticated read-only notification routing
before and after the probe, a fail-closed missing listing, rejection of an
encoded path separator and absence of a ShareItToo association for a foreign
host. It returns the app to the launcher and retains no hierarchy, content,
identity, credential, token, private path, network identifier or raw device
identifier.

The result intentionally does not close authenticated fixture links, booking
flow, Play delivery, real push or the full device matrix. No login, logout,
account mutation, participant, Store, production, Payment, Cloud/VPS/DNS,
provider, contract, cost, real-money, public activation or merge occurred.

The next autonomous lane is the highest remaining current-source Android or
source-level gap that can be closed without credentials, fixture mutation,
external providers or Store upload. Stage A remains `HOLD` / `NO-GO`.

## PF11 — current-head Android main navigation

`PF11_CURRENT_HEAD_ANDROID_MAIN_NAVIGATION` adds a source-bound physical
diagnostic for the five primary authenticated destinations. It accepts only
`--current-head` plus an optional ADB binary, validates the exact PF6
direct-installed APK and refuses current Android lock states before UI access.

The Pixel run opened Entdecken, Mietkorb, Buchungen, Nachrichten and Mein SIT,
verified a destination-specific sanitized surface for each and returned to
Entdecken. The tool only taps the bottom navigation. It never invokes a
booking, message, cart or account action and retains no hierarchy or personal
content. Entity-decoded compound Android semantics are handled with exact line
boundaries and deterministic tests, not a device-specific workaround.

PF11 remains narrower than the full PF5 functional/device matrix. Booking
roles, request/acceptance, handover/return, message delivery, cart mutation,
real push, manual TalkBack and Google Play delivery remain unclaimed. No
login/logout, participant, Store, production, Payment, Cloud/VPS/DNS,
provider, contract, cost, real-money, public activation or merge occurred.

The next autonomous lane is another isolated current-source or source-level
launch gap that can be closed without mutating the preserved account, using
external providers or crossing a Store/live gate. Stage A remains
`HOLD` / `NO-GO`.

## PF12 — current-head Android legal routes

`PF12_CURRENT_HEAD_ANDROID_LEGAL_ROUTES` adds an exact-candidate, read-only
physical route for seven informational Legal/Privacy documents. It reaches the
legal root through the authenticated profile search, opens a document-specific
surface for Impressum, Datenschutz, AGB, Community-Regeln, Gebühren &
Zahlungsbedingungen, Stornierungsbedingungen and Haftungsausschluss, then
returns to Entdecken.

The diagnostic reuses the PF11 installed-byte, current-lock and semantic-line
guards. It excludes the platform-withdrawal route and never invokes Contact,
Support, booking, Payment or account actions. UI hierarchies remain transient;
no document content, legal contact value or personal/secret identifier enters
evidence.

PF12 makes no professional Legal, substantive correctness, Store, public or
Stage A claim. P0B professional review remains an authentic external gate. No
login/logout, participant, Store, production, Payment, Cloud/VPS/DNS,
provider, contract, cost, real-money, public activation or merge occurred.

The next autonomous lane is the highest remaining non-mutating exact-candidate
or source-level launch gap that does not cross Legal, Store, provider or live
boundaries. Stage A remains `HOLD` / `NO-GO`.

## PF13 — current-head Android large-text main navigation

`PF13_CURRENT_HEAD_ANDROID_LARGE_TEXT_MAIN_NAVIGATION` adds a source-bound
physical accessibility diagnostic for the five authenticated primary
destinations at an Android system font scale of at least 200%. It verifies the
exact PF6 direct-installed APK and unlocked state before changing the setting,
uses only bottom-navigation taps and bounded ordinary scrolling, then restores
the exact previous scale on success or failure.

The Pixel run proved Entdecken, Mietkorb, Buchungen, Nachrichten and Mein SIT
semantically reachable at `2.0`. It restored the original `0.85`, independently
confirmed after the run. Deterministic tests cover refusal before mutation,
failure to apply the target, destination failure and failed restoration. The
current device now reports Android 17/API 37/security patch 2026-07-05; Codex
did not initiate an OS update and older evidence is not rewritten.

PF13 is not a human visual/clipping review and does not claim TalkBack, Store
delivery, a booking flow, message send, cart/account mutation or a full device
matrix. No hierarchy, screenshot, participant, identity, credential, token,
private path, network identifier or raw device identifier was retained. No
login/logout, production, Payment, Cloud/VPS/DNS, provider, contract, cost,
real-money, public activation or merge occurred.

The next autonomous lane is the highest remaining non-mutating current-source
or source-level accessibility/device gap that stays below Legal, Store,
provider and live boundaries. Stage A remains `HOLD` / `NO-GO`.

## PF14A — main-navigation touch-target remediation

The PF13 physical hierarchy was evaluated against Android's 48dp interactive
target recommendation. Four custom 20dp icon destinations exposed clickable
semantic heights of about 43dp at 200% text, while the central 32dp asset
exposed about 55dp. This produced a reproducible source-level accessibility
gap rather than a manual visual assumption.

`PF14A_MAIN_NAVIGATION_TOUCH_TARGET_REMEDIATION` places every inactive and
active icon path inside one `kMinInteractiveDimension` wrapper. The visual icon
sizes stay unchanged. Focused Flutter coverage composes five destinations at
200% and requires every semantic target to be at least 48dp in both dimensions;
a permanent source ratchet proves that all ten production icon paths use the
same wrapper and forbids timing, lint and platform accommodations.

PF14A does not claim physical remediation because the installed PF6 binary
predates the source change. The next bounded package is PF14B: create a newer
signed internal Staging candidate, perform only a signature-preserving direct
update and remeasure sanitized target geometry at 200%, with exact setting and
app-state restoration. Store, TalkBack, manual visual review, production,
Payment, provider, cost, public activation and merge remain outside scope.
