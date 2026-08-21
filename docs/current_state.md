# ShareItToo Current State

Verified: 2026-08-21 on the Mac mini.

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
- Node/Express backend with verified PostgreSQL migrations through `033`,
  deterministic
  server quotes, immutable legal/acceptance evidence, checkout and booking
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
