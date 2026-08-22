# ShareItToo Current State

Verified: 2026-08-22 on the Mac mini.

## Repository baseline

- Checkout: `/Users/walidchraibi/Worktrees/SIT-master-workflow-20260808`
- Branch / PR: `codex/master-workflow-20260808`, draft PR #7 against `main`.
- Last verified formal P0B close head:
  `0c475e004218964681e4060b012432a6d8770c08`.
- That commit is contained in the local branch, remote branch and draft PR #7
  head at the recorded close; the PR remained open and unmerged.
- GitHub Actions run `32435774839`, associated with that exact close head, is
  green. Backend, Flutter, PostgreSQL integration, analyzer, web and Android
  debug gates passed; signed candidate and image publication were skipped.
- No rebase, force-push, history rewrite, branch deletion, PR merge, signed
  release or published artifact occurred.
- The later S1 support foundation is verified at exact commit
  `64874b9eba0b6b2fca85f1c4f3cdfed0d702f095`; GitHub Actions run
  `32491241853` is green and draft PR #7 remains open and unmerged.
- The S2 support decision ledger is verified at exact commit
  `072e2ba8029dc297bfcb3f9a25e2dd8bc59136fa`; GitHub Actions run
  `32496163016` passed Backend and Flutter regression including PostgreSQL 16
  migration `033`. Signed-candidate construction and image publication stayed
  skipped, and draft PR #7 remained open and unmerged.
- The S2A denied-access audit is verified at exact commit
  `3742f00b11366205abb79c10295e775d301325e8`; exact GitHub Actions run
  `32497715939` passed Backend and Flutter regression including PostgreSQL 16.
  Publication and signed-candidate construction stayed skipped, and draft PR
  #7 remained open and unmerged.
- The S3A safety-first intake is verified at exact commit
  `613adc06c9504b4778adf81b5ba5b892d3435825`; exact GitHub Actions run
  `32500301293` passed Backend including PostgreSQL 16 and the full
  Flutter/Web/Android debug regression. Publication and signed-candidate
  construction stayed skipped, and draft PR #7 remained open and unmerged.
- The S3B canonical support intake is verified at exact commit
  `0185b2a0f05f6181f8975a48a4f96d0811681e8b`; exact GitHub Actions run
  `32503031376` passed Backend including PostgreSQL 16 and the full
  Flutter/Web/Android debug regression. Publication and signed-candidate
  construction stayed skipped, and draft PR #7 remained open and unmerged.
- The S3C canonical Help Center entry is verified at exact commit
  `044c5e04522e0d1b5946b732a8090c3f3b2242b9`; exact GitHub Actions run
  `32504712378` passed Backend including PostgreSQL 16 and the full
  Flutter/Web/Android debug regression. Publication and signed-candidate
  construction stayed skipped, and draft PR #7 remained open and unmerged.
- The S3D user support-case list and detail surface is verified at exact commit
  `61cd3ad8ef6ab178eee5305d1654c291d8c5a40f`; exact GitHub Actions run
  `32506977131` passed Backend including PostgreSQL 16 and the full
  Flutter/Web/Android debug regression. Signed-candidate construction and image
  publication stayed skipped, and draft PR #7 remained open and unmerged.

## Post-P0B ordered continuation close

- Walid's five ordered post-P0B gate packages were processed to their maximum
  safe local state. Implementation/evidence head
  `cc4cf2454395acb4ab0202700ff4cb241ad0f43d` is synchronized to the draft PR.
- Exact GitHub Actions run `32461470531` is green for that head. Backend and
  Flutter regression passed, GitGuardian passed, and production publication
  remained skipped.
- The Drive control folder still contains no command newer than V2.4. The
  authorized runway is therefore closed at
  `docs/SIT_PENDING_GATE_P0B_NEXT_RUNWAY.md` rather than silently extended.
- Professional legal, real-operations, iOS-device and contracted-provider
  sandbox facts remain open. The Spiegelberg Cat8 envelope remains inactive and
  ineligible.

## Implemented system

- Flutter client version `1.0.0+2026081510` with Android, iOS and web targets.
- Node/Express backend with PostgreSQL migrations through `047`. Migration
  `046` is verified on PostgreSQL 16.14 at exact GitHub Actions run
  `32548790305`. The
  backend provides deterministic server quotes, immutable legal/acceptance
  evidence, checkout and booking
  lifecycle, withdrawal/cancellation and actual-loss rules, handover/return
  evidence, messaging and moderation foundations.
- S1 adds a simulation-only central support-case foundation from the current
  Drive Support Packet: exact taxonomy, guarded lifecycle, append-only events,
  red approval boundaries, authenticated user intake/read, Staff-Step-up queue
  and transitions, plus export/retention/erasure-preflight coverage. It sends
  no external message and executes no decision or measure.
- S2 separates immutable decision proposals, exact-hash four-eyes approval and
  verified implementation evidence. Staff access is assignment-bound, review
  is administrator-only, and the implementation endpoint records only
  simulation/internal-testing evidence without calling an external adapter.
- S3A adds a mandatory safety-first question before normal support intake,
  source-bound T-003 emergency guidance, versioned immutable intake evidence
  and fail-closed Trust & Safety routing for immediate danger. It places no
  call, sends no external message and activates no live support operation.
- S3B connects that intake to the authenticated canonical simulation-case
  route. The app accepts only a confirmed received-state receipt with opaque
  Case ID and server-computed next update before it opens the local support
  presentation; retries are idempotent and malformed/live receipts fail closed.
- S3C removes the Help Center's legacy local-only support success claim. The
  real Help Center now opens from `Mein SIT`, preserves the entered description
  and requires the same safety-first category flow and canonical receipt.
- S3D connects the authenticated support-case list and user-safe detail routes
  to the Help Center. It maps lifecycle data to simple German text, never
  reflects unknown internal codes, labels the simulation boundary and remains
  read-only.
- S3E requires a distinct
  server-confirmed user response deadline for `waiting_for_user`, persists it
  in the existing support evidence deadline field, and displays `Antwort bis`
  separately from the support team's `Nächstes Update`. It adds no automatic
  closure, reminder or external action.
- S3F and S3G are technically verified. S3F publishes only exact approved,
  implemented and communicated user-facing decision fields; S3G adds one
  reporter submission per explicitly configured closed-case appeal deadline.
  Neither package sends an external message or executes a live measure.
- S3H is technically verified at exact commit
  `cfb9a3377c432efb2d3c76620c35cb24623dd5e6` and successful GitHub Actions run
  `32520795019`. It adds P0-only,
  case-bound five-minute break-glass access for active support staff behind the
  exact current session and Staff-Step-up. Every grant queues an independent
  elevated Admin review, while privacy export omits internal reasons and staff
  identifiers. Dedicated bounded HTTP limits preserve exact idempotent replay,
  and the browser token header is CORS-allowlisted. Incident-wide access remains
  absent rather than inferred. PR #7 remains draft and unmerged; no live or
  signed-candidate path was used.
- S3I is technically verified at exact commit
  `f8c596f2c555b1431720d8240f23dffe8770e936` and successful GitHub Actions run
  `32525140426`. The exact 55-template Drive catalog is source-hash-bound;
  server-bound values and Berlin times cannot be replaced by client claims.
  GREEN publication is allowlisted, YELLOW requires independent exact-hash
  Admin review, and RED or money-bearing templates stay rejected from the
  generic path. Sent messages appear only as authenticated in-app records for
  their case recipient, with immutable correction history and no external
  delivery. All 426 Backend tests including PostgreSQL 16 and the complete
  Flutter/Web/Android debug regression passed. PR #7 remains draft and
  unmerged; no live, signed-candidate or publication path was used.
- S3J is technically verified at exact commit
  `7a8d7bb92f0c095a0561f0bb4e23500aa65f5866` and successful GitHub Actions run
  `32528304577`. It adds a non-live recurring watchdog for active P0 cases
  without an owner and overdue `next_update_at` commitments. Exact-condition
  idempotency records only internal append-only alerts; health/readiness fails
  closed on stale worker state or unresolved conditions. An authenticated
  elevated admin receives a minimized `private, no-store` queue, while S3I
  publication refuses an already-expired next-update promise. All 433 Backend
  tests including PostgreSQL 16 and the complete Flutter/Web/Android debug
  regression passed. No external notification, case mutation, signed
  candidate, publication or live path was used.
- S3K is technically verified at exact commit
  `ca3f952b2621441028e560b4b76f17ba43d2f2ba` and successful GitHub Actions run
  `32530748881`. It addresses Drive scenario `SUP-026` with a mandatory
  single-issue confirmation after safety triage and before categories. A
  multiple-problem answer requires separation guidance before one problem may
  continue. The server rejects missing, stale or false confirmation without
  text inference; migration `040` requires exact evidence for new cases and
  makes it immutable. All 435 Backend tests including PostgreSQL 16 and the
  complete 346-test Flutter suite with one documented skip, Web smoke/build
  and Android debug build passed. No automatic split/link, external delivery,
  production, payment, Store, signed candidate or live path was used.
- S3L is technically verified at exact commit
  `57ca7b016cae3447edaea352cb919dab99c390ae` and successful GitHub Actions run
  `32532443847`. It addresses Drive scenario `SUP-028` by exposing a dedicated
  `Datenschutz & Daten` route inside the normal support intake. All seven
  canonical Privacy subtypes create a separate `privacy_security` case with
  `privacy_owner`, red decision boundary and a server-derived operational
  next-update checkpoint. The receipt rejects a server response whose case
  type or subtype does not match the selected route and explicitly confirms
  the separate Privacy path. All 436 Backend tests and the complete 348-test
  Flutter suite with one documented skip, Web smoke/build and Android debug
  build passed. This adds no text inference, statutory deadline claim,
  external delivery, production, payment, Store, signed candidate or live path.
- S3M is technically verified at exact commit
  `6d8eb4856e46d6ce171ce8caa20479884a3d3498` and successful GitHub Actions run
  `32533886775`. It addresses Drive scenario `SUP-029` by
  separating account access from controlled support-case retention. An open
  support case is a disclosed retained record rather than a generic deletion
  blocker, while an active legal hold remains fail-closed. Account deletion
  invalidates user access and sessions but preserves the pseudonymous case and
  audit history; workflow checks and migration `041` reject creation or
  publication of any new in-app support message to the closed account. All 439
  Backend tests including PostgreSQL 16 and the complete 348-test Flutter suite
  with one documented skip, Web smoke/build and Android debug build passed.
  Production, external delivery, payment, Store, signed candidate and live
  paths remain closed.
- S3N is technically verified at exact implementation commit
  `c7b74ea0af919362a9706ebf23371a555b3986f5`, CI fixture-isolation commit
  `a5e33c3f2a6eb61b739018ef5d4ca15777602bba` and successful GitHub Actions run
  `32536618516`. It addresses Drive scenario `SUP-027` with a separate,
  authenticated illegal-content intake, versioned structured notice evidence,
  a server-authoritative reporter identity and an opaque Notice ID. Migration
  `042` stores immutable evidence; user, event and audit projections remain
  minimized, and only the reporter's privacy export receives full evidence.
  All 445 Backend tests including PostgreSQL 16 and the complete 352-test
  Flutter suite with one documented skip, Web smoke/build and Android debug
  build passed. Intake creates no automatic illegality finding or content
  measure: those remain behind explicit human red review. Public/guest access,
  legal/operator approval, production, payment, Store, signed candidate and
  live paths remain closed.
- S3O is technically verified at exact implementation commit
  `0c8724c3ba05b4b2afd8622087ae00970b573a8e` and successful GitHub Actions run
  `32539524697`. It addresses Drive scenarios `SUP-113` and `SUP-114` by
  creating the Notice ID and immutable original evidence before locator
  completeness review. Missing or descriptive locators remain retained as
  `needs_clarification`; the authenticated reporter can append an exact,
  version-bound locator without rewriting the original notice. Migration `043`
  makes amendments append-only and independently guards completion. All 449
  Backend tests including PostgreSQL 16.14 and the complete 354-test Flutter
  suite with one documented skip passed, together with Web smoke/build and
  Android debug build. Locator status remains a completeness signal only; no
  illegality decision, content measure, external delivery, production,
  payment, Store, signed candidate or live operation is enabled.
- S3P is technically verified at exact implementation commit
  `079dc0e139437a2c8b1732a5cd77a826b892d8c4`, follow-up rate-limit isolation
  commit `23b9cb84e0286215661e78ac67638eeedcd819d4` and successful GitHub Actions
  run `32542904176`. It requires a versioned, append-only Statement of Reasons
  for every new significant moderation measure and reversal. The Statement is
  action-duration-bound, Administrator-issued and human-reviewed; fully
  automated significant decisions fail closed. Authenticated affected users
  receive exact confirmed facts, basis, reasoning, scope, duration, origin and
  automation disclosure plus the existing free electronic review route.
  All 456 Backend tests passed without skips on PostgreSQL 16.14; 358 Flutter
  tests passed with one documented skip together with the separate Google-only
  test, Web smoke/build and Android debug build. The private signed-candidate
  step was not executed, so it adds no device, Store or release evidence.
  Legacy gaps remain explicit rather than being backfilled. Independent review
  assignment, correction, professional legal approval, external transparency
  reporting and every production, payment, Store, signed-candidate or live path
  remain separate closed gates.
- S3Q is technically verified at exact implementation commit
  `b3d122bb0dc0a4377d6311aa4798c5f3367bfabf`, migration-syntax correction
  `339db52e7577ac7f7711fbd963f7031a98934830`, privacy-export correction and
  verified head `6c58d33456885e2470e858a708297d7aa37832d8`, with successful GitHub Actions
  run `32545973414`. It adds an Administrator-only, Staff-Step-up
  protected review queue in which the original decision issuer cannot claim or
  resolve the review. Migration `045` requires append-only, human-only and
  independently assigned resolution evidence before terminal review state.
  `modified` and `reversed` outcomes apply a guarded correction and create a new
  S3P-complete moderation decision in the same transaction; users receive the
  exact result, reason and implementation truth without staff identity. The
  exact-head CI applied all migrations through `045` on PostgreSQL 16.14 and
  passed all 459 Backend tests without skips. Pinned Flutter 3.41.7 passed 359
  tests with one documented skip, plus the separate Google-only test, Web
  smoke/build and Android debug build. Dependency/history checks, Compose
  validation and the commit-labelled API image build passed. The signed
  candidate and API-image publication steps were skipped; Draft PR #7 remained
  open and unmerged. Unsupported correction semantics fail closed, and
  legal/operator approval, external delivery, production, payment, Store,
  signed-candidate and live paths remain separate gates.
- S3R is technically verified at exact implementation head
  `3497a887d31935560c1371a13e92fee2def21344` and successful GitHub Actions run
  `32548790305`. It adds a conservative non-live Article 18 candidate flag for
  exact P0 Trust & Safety taxonomy, an Administrator-only and Staff-Step-up
  protected queue, and append-only human assessment truth with explicit route,
  evidence references, minimum information scope and reviewer authorization.
  Migration `046` enforces the taxonomy, non-live mode, immutable evidence and
  guarded rollback. Normal support cannot assess or dispatch, and even an
  elevated Administrator receives a fail-closed disabled-dispatch response;
  there is no external transport, authority address or sent state. Restricted
  facts remain outside normal audit and automatic self-service export while
  retention inventory remains count-only. Dedicated rate-limit buckets keep
  support intake and Article 18 operations separate from unrelated account
  security. Exact-head CI passed all 468 Backend tests without skips on
  PostgreSQL 16.14 and all migrations through `046`; 359 Flutter tests passed
  with one documented skip plus the separate Google-only test, Web
  smoke/build and Android debug build. Dependency/history, Compose and the
  commit-labelled API image build passed. Signed-candidate construction and
  API-image publication were skipped. Legal approval, real role assignments,
  competent-recipient verification, approved disclosure scope, external
  reporting, production, payment, Store and every live path remain closed.
- S3S is a locally and CI-verified non-live package at exact implementation
  commit `60b8017c00a63d18dd3d6887cfab3baee1f0fafb` for the technical core of Drive
  scenarios `SUP-123` through `SUP-127`. It separates six exact
  privacy-rights request kinds, starts a conservative response deadline at
  receipt, keeps account-password identity verification deadline-neutral,
  creates idempotent internal 72-hour deadline alerts and permits only one
  reasoned pre-deadline extension behind Administrator Staff-Step-up.
  Migration `047` makes request, verification and extension truth guarded and
  rollback-protected. Privacy export is identifier-minimized, while the new
  retention category binds to a tenth explicitly open policy decision. Local
  focused tests, the complete Flutter/Web/Android regression and a
  CI-equivalent Backend run pass. The Backend run executed all 471 tests
  without skips against isolated PostgreSQL 16.15 and applied every migration
  through `047`. GitHub regression `32551835411` is green for head
  `60b8017c00a63d18dd3d6887cfab3baee1f0fafb`; Actions tested PR merge
  snapshot `57e987471a770e222b91d47ea8e1e141bf3ceb23`. CI passed 471 Backend
  tests, audit/secret checks, Compose validation, the commit-labelled API
  image, 359 Flutter tests with one documented skip, the separate Google-only
  test, Web smoke/build and Android debug build. Signed-candidate construction
  and API-image publication remained skipped. No
  rights execution, disclosure, erasure, external delivery,
  production, payment, Store, signed candidate or live path is enabled.
- S3T is a locally and CI-verified non-live package for the technical core of
  Drive scenarios `SUP-128` through `SUP-131` at exact implementation commit
  `cb8d378acf6cc2617386ed945e128aab41de5bff`. Migration `048`
  binds three exact Privacy incident subtypes to immutable awareness time,
  an exact 72-hour human decision deadline, idempotent internal alarms and
  append-only Administrator containment evidence behind active session and
  Staff Step-up. The account export now requires exact current-password
  re-authentication, derives its subject only from the authenticated session
  and minimizes inbound third-party structured exact locations. No assessment,
  authority/affected-person decision, external notification or live adapter is
  implemented. All 473 Backend tests passed without skips against isolated
  PostgreSQL 16.15 through migration `048`; the accepted analyzer baseline,
  359 Flutter tests with one documented skip, the separate Google-only test,
  Web smoke/build and Android debug build passed. Historical internal AAB
  `2026081509` is not present in this Mac mini's private archive, so no local
  byte-verification claim or signed artifact action is made. GitHub regression
  `32553740248` is green for the exact implementation head and PR merge
  snapshot `990015e391d38a26fe8e1f6682db3d219d4d0ae5`; the signed-candidate and
  API-publication stages remained skipped, and Draft PR #7 remained open and
  unmerged. Professional legal review, real staffing, production, payment,
  Store and every live path remain closed.
- C1G binds neutral transactional FCM, separate opt-in Crashlytics, fail-closed
  external provider activation and the privacy/retention inventories.
- C1H binds an immutable server category allowlist, private-marketplace and
  commercial-review eligibility, reasoned user-bound moderation decisions,
  snapshot-bound financial documents, fail-closed operator/provider facts and
  a non-activating EUR 5,000 professional-review signal.
- Release and compliance state remains machine-validated under `store/` and by
  `tool/` plus `test/tool/`; repository architecture/evidence is versioned
  under `docs/`.
- Mac-mini Android signing and Android/iOS Firebase configuration gates passed
  the local recovery checks without exposing protected values. Their presence
  is not permission to create or sign a release.
- C1I revalidated the canonical Android upload-signing gate and both protected
  Firebase platform configurations without disclosing protected values.
- FI0 removes the named personal GHCR namespace from critical CI, Docker and
  preflight configuration. Registry and source identity are repository- or
  role-configured; missing explicit preflight configuration fails closed.
- FI0 defines six unassigned functional roles, a critical-process schema, the
  existing append-only audit binding, manual monthly founder-hours aggregates
  and a reusable absence/delegate runbook. No account assignment was invented.
- G2A changes the five primary destinations to `Entdecken`, `Mietkorb`,
  `Buchungen`, `Nachrichten`, `Mein SIT` while preserving the established
  Bookings asset icon and profile-image affordance.
- Existing Wishlist data stays on `wishlists_meta_v1` and
  `wishlist_assign_v1` and is presented as `Mietkorb` > `Gemerkt` with an
  explicit non-binding/no-reservation notice. G2B does not reinterpret or
  destructively migrate these values.
- The old internal `WishlistsScreen` type remains a compatibility entry point;
  existing app/deep-link contracts are unchanged.
- G2L includes all three existing local `Gemerkt` stores in account export and
  removes exactly those stores after confirmed account deletion on the active
  device. Unrelated local preferences remain untouched.
- G2B adds a versioned account cart, project containers and idempotent cart
  lines in migration `027`. Cart quote previews reuse deterministic server
  pricing without persisting a booking quote and never create a booking,
  request, reservation, availability hold or payment.
- Guests can prepare bounded local cart/project state. Login and registration
  reconcile it project-first and remove the local copy only after every
  server upsert succeeds. A pending partial sync is bound to its account and
  hidden from other accounts and logged-out users.
- Server recheck exposes current, changed and unavailable lines before the
  existing single-item V5.2 checkout. Stored prices remain informative and
  direct single-item rental remains available.
- `store/g2-data-lifecycle.json` now records the active local/account lifecycle.
  Account and local exports, confirmed deletion and retention inventory cover
  all three new datasets before activation.
- Current Privacy terminology truthfully distinguishes `Gemerkt`, local guest
  intent and the account-bound non-reserving cart. Historical legal/privacy
  snapshots are unchanged.
- U0 adds the internal `GET /v1/admin/pilot-cockpit` endpoint. An active admin
  account and the existing Staff-Step-up are mandatory; the response is
  aggregate-only, `private, no-store` and has no write counterpart.
- Cash flows, normalized economics, project-funnel counts and FI0 aggregates
  carry evidence class, provenance and completeness. All monetary values use
  integer minor units and separate ISO-currency buckets without implicit FX.
- Missing VAT components, provider fees, cloud costs, founder-hour aggregates
  or founder-replacement rates remain `unavailable` and force normalized
  profitability to `undetermined`; they never become silent zeroes.
- KYC, fraud-provider, external AI and marketing costs are explicitly shown as
  configured disabled zeroes under the current pilot boundary. Cloud billing
  remains unavailable.
- FI0 now also defines a manual monthly aggregate for total, role-routed,
  founder-only and unrouted escalations. No case detail or automatic founder
  activity monitoring is permitted, and U0 adds no collection endpoint.

## Current safe operating state

- C2C private-adult pilot for Germany and only explicitly server-approved
  regions. Missing region facts fail closed.
- Vehicles/transport, drones, paid delivery, shipping, express, deposits, SIT
  insurance/protection and automatic damage collection are out of scope.
- Real money is off; payment execution remains disabled/test-only.
- Ads, marketing analytics, general Firebase Analytics and external generative
  AI are off. Transactional FCM and voluntary Crashlytics remain separately
  controlled and default off.
- Store submission is blocked (`store/submission.json`: draft,
  `submissionAllowed=false`). The retained Store candidate `2026081509` and
  its physical evidence are historical; source build `2026081510` has no new
  signed, commit-bound candidate.
- Privacy, retention, legal, operator/provider and final-binary manifests remain
  draft, incomplete or fail-closed. Open owner, legal, provider, Apple/iOS,
  full device-matrix and final-binary gates must not be silently closed.
- No production, VPS/OpenClaw, SSH, DNS, cloud-console, payment, Store or
  live-provider mutation was made. The MacBook is not required.

## P0B-L1 professional legal review intake

- Walid authorized ordered post-P0B continuation. The first token prepared
  `P0B-L1-LEGAL-REVIEW-2026-08-21.1` from exact V5.2, G3A/G3L, P0B and live
  Drive sources.
- Five hash-bound intake artifacts define the professional scope, eighteen
  open decisions, a 21.08.2026 official-primary-source baseline, an external
  approval-evidence schema and a hard release gate.
- This is counsel-ready preparation only. No professional reviewer, opinion,
  final legal text or authenticated approval evidence is present.
- Public, production, Store and real-money gates remain false. The unresolved
  external dependency is not bypassed; independent non-live operations work
  continues next.

## P0B operations role/delegate/absence gate

- The executable gate binds all six FI0 roles, all four FI1 processes and the
  current Drive Founder Independence/Support test sources.
- Four synthetic role/fallback configuration rehearsals pass. This proves the
  deterministic role design only; no real person participated.
- Zero role assignees, zero delegates, no company IAM/RBAC/MFA evidence and
  zero human 72-hour absence tests are available. Operations readiness and bus
  factor therefore remain false.
- The cockpit reports technical rehearsal and human readiness separately.
  Names, emails, credentials and personal device identifiers are neither
  stored nor exposed.
- No account, production, payment, provider, Store or public state changed.
  Independent work continues to current signed-device evidence.

## P0B current-source signed-device evidence

- A canonical signed internal-staging Android AAB/APK and binary privacy report
  are bound to commit `e8cd4a99d95f74c279afa86a24a9a61df6ee98c8` and stored
  in a verified owner-only private archive outside Git.
- The signed APK updated the authorized Pixel 7 Pro without uninstall, reset or
  downgrade. Installed bytes match the candidate, version is
  `1.0.0+2026081510`, and cold launch resumed successfully.
- Existing installed app data was preserved. No screenshot, account content or
  raw device identifier was recorded. This is direct internal-install evidence,
  not Play/Store-install evidence.
- Android and iOS protected Firebase configurations validate together and
  Analytics remains off. Full Xcode, `xcodebuild` and CocoaPods are absent, and
  no physical iOS evidence is verified; no iOS archive/signing was attempted.
- Exact GitHub Actions run `32459509278` is green for candidate source commit
  `e8cd4a99d95f74c279afa86a24a9a61df6ee98c8`.
- The combined device gate remains partial. No artifact upload, Store,
  production, Cloud, payment, provider or public mutation occurred.

## P0B marketplace-PSP sandbox E2E gate

- Live Drive searches bind V5.2, the current Rechtsmappe and the current money
  and Support Packet sources. They found governing/reference material but no
  standalone executed PSP contract or provider-sandbox acceptance artifact.
- The repository contains a Stripe-Connect-shaped server adapter and broad
  synthetic payment tests. Neither code naming nor a unit-test credential is
  treated as proof of provider selection, contract, licensed product, operator
  account, DPA, processing region or approved transfer model.
- The presence-only local check found only example environment files, no
  configured process payment transport, no test/webhook secret, no legal PSP
  facts and no provider CLI or equivalent. No values or secrets were recorded.
- Thirty-five focused tests passed. The executable gate still reports provider
  facts false, sandbox environment false, zero of eight provider scenarios
  passed, sandbox E2E false and real-money readiness false.
- No provider request, provider object, dashboard, production, Cloud, Store,
  public or real-money state changed. The exact gate state is
  `hold-provider-contract-credentials-and-sandbox-e2e`.

## P0B invited synthetic pilot envelope

- The conditional token is recorded as authorized, but its effect remains
  gated by the four prior machine results. Professional legal approval,
  operations readiness, complete Android+iOS device evidence and contracted
  provider-sandbox E2E are all false, so pilot prerequisites are zero of four.
- The future scope is frozen to 30 invited private adults, 30-50 synthetic
  flows, `Spiegelberg, Rems-Murr-Kreis`, code `spiegelberg`, and only Cat8
  Elektrowerkzeuge, Bohrmaschinen and Schleifer.
- Enabled product scope is V5.2 single-item plus G2 navigation, non-reserving
  Mietkorb and Gemerkt. G3-G5 expansion, SIT Business, external AI, public
  registration, live provider traffic and real money remain excluded.
- Growth values EUR 45-55 AOV, greater than 95 percent successful handover,
  less than 2 percent severe disputes and at least 25 percent 90-day repeat are
  stored as unobserved targets, never results.
- The region was not configured. No roster, personal data, account, invite,
  listing or participant flow was created; production, Cloud, provider, Store,
  public and real-money state remained unchanged.

## G3B booking-group foundation

- Walid selected G3A Variant A and authorized the V2.4 rolling-autonomy runway.
- G3B adds immutable group compatibility envelopes and normalized append-only
  item positions. Owner, renter, private context, Germany, currency, period,
  location, handover, legal, cancellation and payment configuration are bound
  at group level.
- Listing, quote, allocation and optional booking references are verified per
  position. Existing booking IDs remain the bridge to item-specific evidence,
  damage, refund and ledger truth; historical V5.2 objects are untouched.
- The G3B foundation has no route or public UI. G3C adds internal technical
  routes, but every route fails closed while the flag is false. The flag
  defaults false everywhere and production enabling is rejected.
- Migration 028 has a tested additive forward path. Rollback removes only G3B
  objects when empty and refuses to destroy existing group evidence.
- `docs/compliance/g3b-booking-group-foundation-2026-08-20.md` and ADR-028 are
  the detailed G3B evidence.

## G3C quote and state orchestration

- Fresh existing single-item server quotes are the only source for each group
  item allocation. The immutable group quote is their exact cent-based sum.
- The initial revision covers all positions. Owner accept-all and decline-all
  bind the exact current quote. A changed item-set counter-offer creates a new
  predecessor-linked immutable quote and requires the renter to accept its
  exact ID and hash.
- Append-only database events are the state source. Actor, group, revision,
  quote hash, initial membership and transition guards fail closed, while
  command records provide actor/request-hash-bound idempotent replay.
- Same-owner compatibility hashes the internal exact location text and
  coordinates, so city-level similarity cannot combine different handover
  places silently.
- Successful G3C transitions create no booking, rental request, availability
  hold, contract, payment or refund. Public/live use remains disabled and
  production enabling remains rejected.
- `docs/compliance/g3c-group-quote-state-orchestration-2026-08-20.md` and
  ADR-029 are the detailed G3C evidence. V2.4 auto-continues to G3D.

## G3D shared handover and item evidence

- An append-only bridge binds each final accepted group allocation to an
  already-valid V5.2 item booking, contract, underlying quote and both actor
  declarations. Historical group positions and V5.2 records are not updated.
- Exactly one pickup and one return appointment are derived from immutable
  group period and location compatibility truth. The technical group response
  exposes neither the internal location hash nor an exact address.
- Four required evidence slots, accessories, evidence IDs, confirmations,
  booking chat, return timers, damage cases and `needsReview` remain independent
  for every item booking.
- One disputed item does not poison other positions. Only an explicit active
  account-scope suspension for a participant is a whole-group system-risk hold.
- The binding seam is internal-only. Shared-appointment routes remain behind
  the disabled group flag, and production enabling is rejected.
- `docs/compliance/g3d-shared-handover-item-evidence-2026-08-20.md` and ADR-030
  are the detailed G3D evidence. V2.4 auto-continues to G3E.

## G3E disabled multi-item UX and end-to-end integration

- The existing `Mietkorb` gains a technical booking-group entry only for
  explicitly enabled non-release builds. Both technical and public-release
  controls default false; release-mode use and public activation fail closed.
- Candidate presentation permits only the same owner, project, period and
  currency and leaves the established single-item flow unchanged.
- The technical group view displays exact group totals, rent/service
  components and every item allocation. It compares predecessor and current
  counter-offers, including added, removed and changed positions.
- Renter consent starts unchecked and binds the exact current quote ID and
  hash. No client price or silent partial acceptance is introduced.
- Shared pickup and return are shown without an exact address. Required photos,
  accessories, confirmations, chat, deadlines, return/damage state and
  `needsReview` remain visible and independent per item.
- `docs/compliance/g3e-disabled-multi-item-ux-2026-08-20.md` and ADR-031 are
  the detailed G3E evidence. V2.4 auto-continues to G3L-DRAFT without granting
  legal approval or public/live activation.

## G3L-DRAFT legal/document delta preparation

- `G3L-DRAFT-2026-08-20.1` is an immutable internal technical identifier, not
  an effective or professionally approved legal version.
- The draft manifest binds the G3A/G3E source evidence, V5.2 Core/Rechtsmappe,
  Growth source, exact V5.2 parent-manifest hash and all nine A-I asset hashes.
  Any parent or draft byte drift fails validation.
- Four hash-bound artifacts cover the affected-scope matrix, future snapshot
  and receipt binding, a completely open professional-review checklist and a
  hard public/live release gate.
- Fourteen decisions remain open, including group contract structure,
  counter-offer/partial-performance effects, payment/refund allocation,
  receipts, evidence, privacy/export/retention and Business/global variants.
- The backend technical group policy uses the exact draft identifier through a
  fail-closed assertion. No G3 contract, declaration, receipt, payment, refund
  or public document is provisioned.
- Historical V5.2 assets, snapshots and records remain untouched. Backend and
  Flutter activation controls remain default-off and production/release use is
  rejected.
- `docs/compliance/g3l-multi-item-legal-document-draft-2026-08-20.md` and
  ADR-032 are the detailed evidence. V2.4 auto-continues to disabled G4A while
  retaining a hard stop before public/live G3 activation.

## G4A deterministic planner core

- `G4A-2026-08-21.1` is a pure deterministic rules engine with no network,
  database, persistence, route, public UI, telemetry or external-AI provider.
- Five reviewed templates cover terrace cleaning, renovation, garden, move and
  event/camping. Each asks four or five bounded single-choice questions and
  rejects missing, invalid or unexpected answers before creating a plan.
- Every possible bounded answer combination returns required, recommended and
  optional item types. Exact category/subcategory targets are validated at
  module load against the authoritative private-pilot allowlist.
- Plans include explicit assumptions plus compatibility and safety rules. They
  never invent a listing, owner, availability, quote, price or reservation;
  those server facts remain explicitly unresolved for G4B.
- Backend and Flutter technical controls default off. Production backend
  enabling is rejected, release-mode Flutter access is unavailable and there
  is no switch for external generative AI or inventory resolution in G4A.
- `docs/compliance/g4a-deterministic-planner-core-2026-08-21.md` and ADR-033
  are the detailed evidence. V2.4 auto-continues to disabled G4B.

## G4B real inventory planner and project cart

- `G4B-2026-08-21.1` resolves only exact G4A item targets against active,
  moderated, public-image-backed database listings and then reuses the
  authoritative booking quote preview for current eligibility, availability
  revision and EUR price truth.
- Exactly three deterministic variants are returned: `1-Stop` only when one
  actual owner covers every selected item, price-efficient from current EUR
  quote inputs, and top-rated only from published renter-to-owner ratings.
  Missing factual support makes the named variant unavailable.
- Item removal/restoration is bounded to the answer-bound G4A plan. Removing a
  required item blocks cart sync; an edited listing must be a current candidate
  for its exact item type and duplicate physical listings are rejected.
- The complete current candidate set is hash-bound. Cart sync re-resolves that
  snapshot in one transaction before mutation and every selected item is
  re-quoted by the existing cart writer. Drift aborts rather than silently
  substituting inventory.
- Only deterministic planner-owned lines in the named project are replaced.
  Manual cart content is preserved, and the cart creates no request, booking,
  hold, reservation, contract or payment.
- Internal funnel events are data-minimized and omit actor, answers, dates,
  location, listing/owner identifiers, quote hashes and prices. No external
  analytics or generative-AI provider is called.
- Backend and Compose controls default off, require the G4A core, reject
  production enabling and retain fixed false public-release/external-AI
  boundaries. `docs/compliance/g4b-real-inventory-project-cart-2026-08-21.md`
  and ADR-034 are the detailed evidence. V2.4 auto-continues to disabled G5A.

## G5A disabled supply enrichment

- `G5A-2026-08-21.1` deterministically derives at most three complementary
  suggestions from the exact category/subcategory of a successfully created
  listing. It does not inspect titles or photos, call external AI, or present
  a heuristic suggestion as a detected fact.
- The five bounded owner outcomes are included accessory, separate rental,
  standalone listing, not part and wrong detection. Sessions and outcomes are
  owner-scoped, active-listing-bound, revision-checked and server-owned.
- Included accessories become owner-confirmed documentation and an accessory
  handover slot. Separate/standalone outcomes return only safe prefill fields;
  price, description and photos are never copied or invented. A later link
  requires the same owner and exact target classification.
- Generation runs only after the primary listing transaction has succeeded.
  Its failure is caught independently and cannot roll back or block the main
  listing publication.
- Public listing shaping strips the private suggestion session and exposes
  only confirmed accessory labels. Account export already includes the
  server-owned listing payload; confirmed erasure drops the enrichment state.
  The count-only retention dataset remains under user intent.
- Backend and Flutter controls default off. Backend production enabling is
  rejected, release-mode UI access is unavailable, and there is no external-AI
  or public-release switch.
- `docs/compliance/g5a-deterministic-supply-enrichment-2026-08-21.md` and
  ADR-035 are the detailed evidence. V2.4 auto-continues to disabled G5B.

## G5B disabled versioned listing sets

- `G5B-2026-08-21.1` lets an owner version optional SIT Sets and 1-Stop Sets
  from two to twelve existing same-owner listings. Stable set identity,
  immutable revisions and normalized revision membership are server-owned.
- Every underlying listing stays independently bookable. Set creation,
  revision, discovery and resolution create no request, reservation, hold,
  booking, contract, payment or refund and do not rewrite item evidence.
- A set resolves only from current, active, moderated, public-image-backed
  members. Every required member must be eligible and available for the exact
  selected period; optional unavailable members are omitted rather than
  silently substituted.
- Current prices come only from the existing authoritative quote preview. The
  set total is the exact cent-based sum of item allocations and introduces no
  hidden set discount, deposit or client-authoritative amount.
- 1-Stop Sets require one exact internal handover-location hash. Renter-facing
  output omits that hash and owner identity. Ranking uses only fewer handovers
  plus a deterministic ID tie-break; Business status and price are excluded.
- Item booking, contract, handover/return, evidence, damage, `needsReview`,
  refund and audit truth remain under the established V5.2/G3 boundaries.
- Account export, erasure, retention, privacy inventory and migration rollback
  cover all set tables. Migration 031 rolls back only while empty and otherwise
  fails closed.
- Backend, Compose and Flutter controls default off. Production enabling and
  release-mode access are rejected, and no public navigation was added.
- `docs/compliance/g5b-versioned-listing-sets-2026-08-21.md` and ADR-036 are
  the detailed evidence. V2.4 auto-continues to FI1.

## FI1 operational delegation layer

- A machine-validated contract assigns role-level owners, delegate roles,
  audit sources, two bounded thresholds and a runbook to four process areas:
  booking groups/sets, project planner/cart, item evidence/`needsReview` and
  normal support escalation.
- Every process remains `hold`. Real assignees, delegates, company-account
  RBAC and absence tests are explicitly absent and were not inferred from local
  users, email addresses, devices or chat history.
- Normal failures route to FI0 functional roles and never automatically to a
  named founder. Strategy, existential risk and explicit owner authorization
  remain separate gates; missing routing is an operations defect.
- Four executable runbooks preserve server quote/inventory truth, item-level
  evidence, staff step-up, append-only audit, safe fallback and the existing
  disabled/public-release boundaries.
- The read-only admin cockpit exposes a role-only delegation summary. It maps
  normal operations to `projectFunnel`, founder hours to
  `founderIndependence.hoursByCategory` and founder escalations to
  `founderIndependence.escalations`, with blending explicitly false.
- Missing or invalid monthly founder aggregates remain unavailable and do not
  become silent zeroes. No invasive activity tracking, automatic founder
  monitoring, private evidence content or new telemetry was added.
- FI1 has no migration, provider, payment, production, Store, account or public
  activation change. `docs/compliance/fi1-operational-delegation-2026-08-21.md`
  and ADR-037 are the detailed evidence. V2.4 auto-continues to P0A.

## P0A closed-pilot technical readiness

- One machine-validated matrix separates 13 passed current-source technical
  cells, one blocked current-source Pixel cell, one historical Pixel evidence
  cell and one signed-candidate cell that is outside P0A authorization.
- Existing single-item, disabled same-owner multi-item and disabled
  planner/project-cart paths passed focused regression together with account,
  cancellation, withdrawal, handover/return, damage/`needsReview`,
  export/deletion, recovery and synthetic payment boundaries.
- Payment remains memory/disabled and Stripe livemode remains false. No real
  money, live provider traffic, capture, payout or refund was attempted.
- Current-source web debug passed a loopback HTTP smoke and current-source
  Android debug built locally and in CI. Neither artifact is a signed release
  candidate and neither was uploaded or submitted.
- The Pixel 7 Pro remains reachable on Android 16, but the installed historical
  shell build has a different signature. Installed data was preserved; no
  uninstall, force replacement or identifier capture occurred. Historical
  device evidence does not satisfy the current-source cell.
- Legal approval, real payment/provider approval, functional-role assignment,
  backup/absence proof, signed-candidate binding and public activation remain
  open external gates. P0A closes as an honest technical-readiness HOLD and
  V2.4 continues only to the non-activating P0B-READINESS dossier.

## P0B final pilot decision dossier

- P0B closes the V2.4 rolling-autonomy runway with **NO-GO now** and
  `hold-for-walid-decision`. It is a decision dossier, not pilot activation.
- The source-bound matrix covers 13 feature areas. V5.2 single item and the
  non-reserving G2 navigation/cart/Gemerkt surfaces are the only product scope
  recommended for a later bounded pilot. G3-G5, Business, multi-provider,
  external-AI, public-registration and real-money scope remain excluded.
- Ten blockers remain open: professional V5.2/G3 legal review; complete
  operator/provider facts; licensed marketplace PSP contract and sandbox E2E;
  explicit region configuration; current-source physical Pixel evidence;
  current signed Android/iOS evidence; operational assignments/delegates/
  absence tests; normalized unit economics; privacy/retention/Store approvals;
  and an explicit future activation decision.
- Operations remain blocked with six unassigned functional roles, no delegates
  and no passed absence test. Provider fees, VAT, cloud costs, founder hours
  and founder replacement rate remain unavailable, so profitability is
  `undetermined` rather than silently positive or zero-cost.
- The single recommended future candidate is 30 invited private adults, 30-50
  synthetic-payment flows, exactly Spiegelberg in Rems-Murr-Kreis and only
  `cat8/Elektrowerkzeuge`, `cat8/Bohrmaschinen` and `cat8/Schleifer`.
  This scope is not configured or activated.
- Five ordered next-authorization tokens are recorded as recommendations with
  `autoExecute=false`. The runway ends without starting any of them.
- Production, public registration, payment/provider, real money, Store,
  signing, Cloud/VPS, account permissions and all disabled feature flags remain
  unchanged. Draft PR #7 remains open, Draft and unmerged.

## Validation and rollback

- Exact G4B CI `32425415877` is green at
  `24f5f062e09e22de62f5b8dc0035c0a2cfc6840c`: 315 backend tests and 313
  Flutter tests passed, with the one documented Flutter skip. PostgreSQL
  integration, web debug and Android debug builds also passed; the publish
  job remained skipped.
- Local backend suite: 314 passed, 0 failed and one expected PostgreSQL skip
  without local `TEST_DATABASE_URL`.
- Complete local Flutter suite: 313 passed with one documented skip; the extra
  Google-only profile test, analyzer baseline, web debug build and Android
  debug APK passed.
- Analyzer remains at the accepted 223-item baseline. Dependency audit has no
  high or critical advisory; one transitive moderate `uuid` advisory remains
  recorded without an unsafe forced override.
- Privacy remains draft with 17 data types and nine services. Retention remains
  draft with nine open decisions and 20 stable execution blockers.
- The verified migration package and Git bundle remain rollback evidence.
- The Pixel 7 Pro is currently reachable and authorized through ADB. A G3E
  technical-flag debug APK built successfully, but a non-destructive update
  install was rejected because the existing app uses a different signature.
  The installed app and its data were left untouched; current-source physical
  UI evidence therefore remains open for P0A or a separately authorized
  candidate/device procedure.
- The historical Google-only candidate manifest remains internally valid, but
  its build `2026081510` binds commit `4cb0046`, not the current implementation
  head. Phone-verification readiness also fails current-source binding and is
  historical rather than a current release proof.
- FI0 role assignees, delegates, company-system ownership, account RBAC,
  absence tests and the normalized founder-replacement compensation amount
  remain explicit external gates. No personal activity monitoring is enabled.
- U0 has no migration. Its normal rollback is a revert of `d36dc09` together
  with the exact Privacy-/Retention-Quellhashbindungen for `backend/src/app.js`.
- G3B rollback removes only empty migration-028 objects and otherwise fails
  closed. It never rewrites or deletes historical V5.2 truth.
- G3C rollback removes only empty migration-029 quote, command and event
  objects and otherwise fails closed. Migration 028 and historical V5.2 truth
  stay intact.
- G3D rollback removes only empty migration-030 binding, appointment and
  command objects and otherwise fails closed. Migrations 028/029 and all
  historical V5.2 item evidence stay intact.
- G3E has no migration. Its rollback is a revert of `04c5122`; disabled entry
  points and historical V5.2/G3B-G3D evidence remain unchanged.
- G3L-DRAFT has no migration or external state. Its rollback is a revert of
  `5963ec5`; the V5.2 parent bytes and disabled G3 controls remain unchanged.
- G4A has no migration or external state. Its rollback is a revert of
  `c1350f3` plus restoration of the two exact config-source hash bindings; no
  stored plan, listing, quote, reservation or provider state exists.
- G4B has no migration or external provider state. Its rollback is a revert of
  `24f5f06` plus restoration of the exact Privacy/Retention source inventories;
  existing G2 project-cart data and all historical booking truth remain valid.
- Exact G5A CI `32428183285` is green at
  `2da5cc925619055f0f5decddb282af6ff694c641`: 323 backend tests passed,
  including PostgreSQL 16 integration, and 317 Flutter tests passed with one
  documented skip. The analyzer improved from 223 to 222 findings; web debug,
  Android debug, secret scan, dependency audit and Compose checks passed. The
  publication job remained skipped.
- G5A has no migration or external provider state. Its rollback is a revert of
  `2da5cc9` plus restoration of the exact Privacy/Retention source inventories;
  primary listings and historical G2-G4/V5.2 truth remain valid.
- G5B GitHub Actions run `32430660117` is green and is associated with exact PR
  head `21106645639c2c09334468817ca3e7b206ae411c`. GitHub checked the synthetic
  PR merge result `c9b41f6549bccc77008a631013cbfb8f75b27eee`: 331 backend tests
  passed with PostgreSQL 16, and 321 Flutter tests passed with one documented
  skip. Analyzer stayed at 222 findings; web debug, Android debug APK, secret
  scan, dependency audit, Compose validation and API image build passed. One
  transitive moderate advisory remains; there are no high/critical advisories.
  Signed-candidate build and publication remained skipped.
- G5B rollback removes migration-031 objects only when empty and otherwise
  fails closed. The normal source rollback is a revert of `2110664` plus exact
  restoration of Privacy/Retention source hashes; all underlying listings and
  historical G2-G5A/V5.2 truth remain valid.
- FI1 GitHub Actions run `32431950081` is green and associated with exact PR
  head `a732ebaa257462fe2292232c779906d4331b0321`. GitHub checked synthetic PR
  merge result `daae51624ab305bddee4d704fed37bc0271cfd08`: 333 backend
  tests passed with PostgreSQL 16, and 321 Flutter tests passed with one
  documented skip. The FI1 validator reported four hold processes, eight
  thresholds, no assignment readiness and no reporting blend. Analyzer stayed
  at 222 findings; web debug, Android debug APK, secret scan, dependency audit,
  Compose validation and API image build passed. Signed-candidate build and
  publication remained skipped.
- FI1 has no migration or external state. Its rollback is a revert of
  `a732eba`; FI0/U0, historical audit/evidence and disabled G3-G5 state remain
  intact.
- P0A GitHub Actions run `32433274526` is green and associated with exact PR
  head `540583829361a402066f85c81716ba60d7d475cc`. GitHub checked synthetic PR
  merge result `6bff2509868afd3be4f5ac8ad3829d589e7f186d`: all 333 backend
  tests passed with PostgreSQL 16, and 321 Flutter tests passed with one
  documented skip. The P0A validator reported 13 passed, one blocked, one
  historical and one not-applicable cell with real money and live provider
  traffic false. Analyzer stayed at 222 findings; loopback web smoke, web
  debug, Android debug APK, secret scan, dependency audit, Compose validation
  and API image build passed. One transitive moderate advisory remains; there
  are no high/critical advisories. Signed-candidate build and publication were
  skipped.
- P0A has no migration or external state. Its rollback is a revert of
  `5405838`; device data, provider/payment state, production and historical
  legal/device evidence remain untouched.
- P0B GitHub Actions run `32434902386` is green and associated with exact PR
  head `84ab2b587565baaf56b10791ea9b6bf3beb8591e`. GitHub checked synthetic PR
  merge result `65235f901c8fbc092394f2ca7da42562589a1c6c`: all 333 backend
  tests passed with PostgreSQL 16, and 321 Flutter tests passed with one
  documented skip plus the separate Google-only profile test. The P0B
  validator passed eight protection tests and reported 13 features, ten
  blockers, two residual risks, five recommended tokens, real money false and
  automatic continuation false. Analyzer stayed at 222 findings; loopback web
  smoke, web debug, Android debug APK, secret scan, dependency audit, Compose
  validation and API image build passed. One transitive moderate advisory
  remains; there are no high/critical advisories. Signed-candidate build and
  publication were skipped.
- P0B has no migration, runtime route or external state. Its rollback is a
  revert of `84ab2b5`; device data, provider/payment state, production and all
  historical evidence remain untouched.

## Next source of truth

`docs/current_work_package.md` records Walid's later exceptional, bounded
non-live continuation instruction. Codex continues safe launch-readiness lanes
without artificial pauses until Walid explicitly stops; missing external facts
block only their dependent lane. G3B, G2A, G2L, G2B and U0 remain technically
complete;
FI0 external role/account assignments and all C1I release/device gates remain
HOLD. Booking groups remain disabled and must not become public/live before the
later legal/release gate. The planner and supply-enrichment runway remain
disabled and non-public; listing sets also remain disabled and non-public.
S1 support foundations remain simulation-only and do not authorize live
support, automated messages or decision execution. Older reports and root
`architecture.md` are
evidence/history, not permission to reopen a closed launch boundary.

## S3E and S3F support continuation

- S3E is verified at exact commit
  `2d01bebb24c884cf1358bd0e1cc606d8ad8ec536` and successful GitHub Actions
  run `32508816204`. PostgreSQL migration `034`, Backend, Flutter, analyzer,
  Web and Android debug checks passed; signed-candidate and publication jobs
  remained skipped.
- S3F is verified at exact commit
  `1cff1763b316c1c0a3008219f7c88a0dc0028dac` and successful GitHub Actions
  run `32512521575`. It binds Drive scenario `SUP-145` to five explicit
  user-facing statements inside the immutable decision payload. It requires
  exact four-eyes approval, verified simulation implementation and an explicit
  administrator publication before a decision-backed case can resolve.
- Migration `035` and the application both enforce the publication boundary.
  The authenticated detail excludes internal decision codes, measure types,
  implementation references, hashes and staff identifiers.
- S3F sends no message and performs no external action. Appeal submission,
  reopen execution, live staffing and all production/payment/provider gates
  remain open separate work.
- S3G is verified at exact commit
  `966e374fe44af13bbbbfb92202e58b328e80a905` and successful GitHub Actions
  run `32515722756`. All 404 Backend tests passed, including PostgreSQL 16
  migration/integration coverage; all 343 Flutter tests passed with one
  documented skip plus the separate Google-only profile test. Web, loopback
  smoke, Android debug, secret scan, dependency audit, Compose and the
  commit-labelled API image build passed. The signed-candidate step and
  publication job remained skipped.
- S3G adds a reporter-only electronic review request for an explicitly
  configured, still-open server deadline on a published closed decision. It
  creates a separate `SIT-R-*` receipt and priority-bound next update without
  reopening the case, accepting evidence IDs, sending a message or executing
  an outcome. Reopen remains staff-only with an explicit owner.

## S3U external-AI and consumer-dispute gates

`S3U_SUPPORT_AI_VSBG_LAUNCH_GATES` is locally and CI-verified as a non-live
package at exact implementation commit
`4366a1b84d795d6c68a686284d9ae0ee74107b49` and successful GitHub Actions run
`32556439261`. Drive scenarios `SUP-132` through `SUP-136` are implemented
conservatively: direct/external AI has no runtime transport and
cannot be enabled; incomplete consumer-dispute facts keep app, Backend public
imprint and Store preflight in draft/HOLD; only exact T-053 may enter the
Administrator-only RED review path with server-bound data and in-app-only
publication; former EU ODR links fail static validation.

The complete Backend suite passed 482 tests on isolated PostgreSQL 16.15
through migration `048`. Flutter passed 361 tests with one documented skip and
the separate Google-only test; analyzer remained at the accepted 220-issue
baseline; Web build/smoke and Android debug APK passed. Privacy/Retention,
Legal and affected P0B hold validators remain green and fail closed. No
professional approval, production configuration, AI activation, external
message, payment, Store, signed artifact, deployment, merge or live action was
performed. CI tested PR merge snapshot
`4b8ba3ca718dfbea8c9a658a0ccff31eb764c3e3`; signed-candidate construction and
API-image publication remained skipped, and Draft PR #7 remained open and
unmerged. Detailed records:
`docs/architecture/s3u-support-ai-vsbg-launch-gates-2026-08-22.md` and
`docs/compliance/s3u-support-ai-vsbg-launch-gates-2026-08-22.md`.

## S3V product-safety contact and rapid triage

`S3V_SUPPORT_PRODUCT_SAFETY_CONTACT_TRIAGE` is locally and CI-verified as a
non-live package for Drive scenario `SUP-137` at exact implementation commit
`c71c263f785b5305800706a5129a321a00f76937` and successful GitHub Actions run
`32558511471`. Authenticated users can submit one versioned structured
notice for a possibly dangerous product or an accident/injury, acknowledge
emergency-first safety guidance and receive an opaque `SIT-P-*` receipt plus a
candidate triage checkpoint no later than 60 minutes after receipt. Migration
`049` independently enforces the exact Trust & Safety taxonomy, RED decision
boundary, immutable evidence and checkpoint.

The public product-safety contact remains separately default-closed until
approval, consumer contact, authority and Safety Gate registrations and the
internal process are all confirmed. Store-required preflight fails closed;
there is no authority/Safety Gate transport, external send, automatic listing
or account action. Optional injury information is now represented truthfully
as Health info in the prepared Data Safety matrix, which remains unsaved with
17 of 18 reviewed types selected. No Play Console mutation occurred.

Local final gates passed: 488 Backend unit tests with one environment-only
PostgreSQL skip, the isolated PostgreSQL 16.15 integration through migration
`049`, 363 Flutter tests with one documented skip, separate Google-only test,
accepted 220-issue analyzer baseline, Web build/smoke and Android debug APK.
P0B provider and invited-pilot gates remain HOLD/NO-GO. Professional legal
review, real registrations, named staffing, production, payment, Store, signed
candidate and every live path remain closed. CI passed all 489 Backend tests,
the complete Flutter regression and PR merge snapshot
`bdfea22d35d2cf6b39486318563d8fbd0f2ddaae`; signed-candidate construction
and API-image publication remained skipped, and Draft PR #7 remained open,
mergeable and unmerged. Detailed records:
`docs/architecture/s3v-support-product-safety-contact-triage-2026-08-22.md`,
`docs/compliance/s3v-support-product-safety-contact-triage-2026-08-22.md` and
`docs/decisions/ADR-059-product-safety-contact-and-external-action-separation.md`.

## S3W support notification and authenticated routing

`S3W_SUPPORT_NOTIFICATION_AUTHENTICATED_ROUTING` is locally and CI-verified for
Drive scenarios `SUP-138` through `SUP-142` at exact implementation commit
`452575c1c06aaf2502573fb1bf7d95724c9b024d`. The implementation
adds a duplicate-safe `support_case_update` outbox schedule only after a
user-visible support-message publication. FCM receives only the one-hour
allowlisted generic contract: `Neue ShareItToo-Aktualisierung`, `In der App
ansehen.`, `contract=v52` and `route=notifications`; it receives no case ID,
address, amount, damage detail, message text or action URL.

After login and authenticated feed retrieval, the support CTA re-fetches the
case from the canonical endpoint and requires the exact requested identity.
Revoked access, missing/malformed data and backend unavailability all render a
generic data-free fallback. Local focused tests, Privacy/Retention validators
and all 492 Backend unit tests pass; one PostgreSQL-environment test is the
intentional local skip. The complete local technical regression passes the
accepted 220-issue analyzer baseline, 365 Flutter tests with one documented
Google-profile skip, the separate Google-only profile test, Web build/loopback
smoke and Android debug APK build. GitHub run `32559993743` repeated these
gates for PR merge snapshot
`5f60270857e8417b59ed9a5b5b4a777f72128ad2`, including 493
Backend/PostgreSQL tests without skips. GitGuardian passed; the signed
candidate and API-image publication jobs were skipped. Draft PR #7 remained
open, mergeable and unmerged. No live Push, provider traffic, production,
payment, Store, signed candidate, deployment or merge occurred.

## S3X support case UI accessibility

`S3X_SUPPORT_CASE_UI_ACCESSIBILITY` is locally and CI-verified at exact
implementation commit `3f96e93e721dcf5daef948ca7370856511293829` for Drive
scenarios `SUP-143` through `SUP-152`. It preserves the
canonical support truth while strengthening German status/action/decision
copy, semantic heading and card order, text-only status meaning, keyboard
activation, two-times text layout, minimum case-card target size and the
existing conditional empty-`Blockiert` behavior. Focused verification passes
19 Flutter widget tests, three static contract tests and 58 Privacy/Retention
protection tests. Both source validators are green. The complete local
technical regression passes the accepted 220-issue analyzer baseline, 367
Flutter tests with one documented Google-profile skip, the separate
Google-only test, Web build/loopback smoke and Android debug APK.

GitHub regression run `32561101446` passed the same gates, including 493
Backend/PostgreSQL tests without skips, for PR merge snapshot
`051f0da94e4a7b81900b54429628ce3a489687c5`. Signed-candidate construction
and API-image publication were skipped; Draft PR #7 remained open, mergeable
and unmerged.
Automated checks are not represented as a manual TalkBack or VoiceOver pass;
signed-device evidence and every live, Store, production, payment, deployment
and merge action remain closed.

## S3Y support operational metrics and crash privacy

`S3Y_SUPPORT_OPERATIONAL_METRICS_CRASH_PRIVACY_GUARDS` is locally and CI-verified
at exact implementation commit
`c4a02ec441e85137187352c71a479f6ad3462bd2` for Drive scenarios `SUP-165`
through `SUP-167`. The new elevated
Administrator route returns only aggregate cohort/snapshot counts and integer
basis points. Reopen rate is limited to cases closed inside the bounded window;
late-update rate is explicitly a current active-case snapshot. No row ID,
user field, case text or external analytics event is returned or sent.

Crashlytics collection now shares one release-plus-independent-user-opt-in
predicate, and the controlled internal diagnostic has one exact four-key
release-mapping allowlist with no Firebase user identifier. The Backend unit
run passes 496 tests with one expected PostgreSQL-environment skip. The full
technical regression passes the accepted analyzer baseline, 369 Flutter tests
with one documented skip, separate Google-only test, Web smoke and Android
debug build. GitHub run `32562949550` repeated those gates for PR merge snapshot
`92c6737e87b2dbdb4540002bf272c66153f7c61e` and passed all 497
Backend/PostgreSQL tests without skips. Signed-candidate construction and
API-image publication were skipped; Draft PR #7 remained open, mergeable and
unmerged. Production, Firebase Console/provider traffic, real support
operations, payment, Store, signed candidate, deployment and merge remain
closed.
