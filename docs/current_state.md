# ShareItToo Current State

Verified: 2026-08-21 on the Mac mini.

## Repository baseline

- Checkout: `/Users/walidchraibi/Worktrees/SIT-master-workflow-20260808`
- Branch / PR: `codex/master-workflow-20260808`, draft PR #7 against `main`.
- Current G4A implementation head:
  `c1350f30838e6584c53604312a11c1aea70b36a8`.
- The G4A implementation commit is contained in the local branch, remote
  branch and PR head; the PR remains cleanly mergeable.
- Exact GitHub Actions run `32423242364` is green: backend regression and
  Flutter regression passed, while the signed candidate and image publication
  were skipped.
- No rebase, force-push, history rewrite, branch deletion, PR merge, signed
  release or published artifact occurred.

## Implemented system

- Flutter client version `1.0.0+2026081510` with Android, iOS and web targets.
- Node/Express backend with PostgreSQL migrations through `030`, deterministic
  server quotes, immutable legal/acceptance evidence, checkout and booking
  lifecycle, withdrawal/cancellation and actual-loss rules, handover/return
  evidence, messaging and moderation foundations.
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

## Validation and rollback

- Exact G4A CI `32423242364` is green at
  `c1350f30838e6584c53604312a11c1aea70b36a8`: 308 backend tests and 313
  Flutter tests passed, with the one documented Flutter skip. PostgreSQL
  migration/integration, web debug and Android debug builds also passed.
- Local backend suite: 307 passed, 0 failed and one expected PostgreSQL skip
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

## Next source of truth

`docs/current_work_package.md` records active G4B under the V2.4
rolling-autonomy runway. G3B, G2A, G2L, G2B and U0 remain technically complete;
FI0 external role/account assignments and all C1I release/device gates remain
HOLD. Booking groups remain disabled and must not become public/live before the
later legal/release gate. The planner remains disabled and non-public. Older
reports and root `architecture.md` are evidence/history, not permission to
reopen a closed launch boundary.
