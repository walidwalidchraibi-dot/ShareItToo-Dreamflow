# Current Work Package: C1G - V5.2 Privacy, Network, FCM and Crashlytics

Status: active after green C1F implementation and GitHub CI.

## Objective

Close only the technical privacy and network gaps proven open by C1A while
keeping every provider, contract, transfer, Store and live-environment fact
truthfully open:

- make every FCM notification transactional, neutral on the lock screen,
  free of sensitive payload data and bound to a short event-specific TTL;
- preserve FCM and Crashlytics as separate, voluntary, default-off choices so
  enabling push can never enable crash collection;
- keep Google Analytics, BigQuery delivery export, analytics breadcrumbs,
  advertising SDKs, marketing push and external generative AI disabled;
- complete code-level network allowlists and provider-bound feature gates for
  external maps/geocoding, fonts, image hosts and other launch traffic, with
  truthful manual or internal fallbacks;
- synchronize machine-readable privacy, retention, deletion and Store
  readiness artifacts without inventing or approving provider facts.

## Baseline and inputs

- Branch: `codex/master-workflow-20260808`; draft PR #7.
- C1F implementation: `a2ef9163ad3118a2dfba18e3335d877511daa8d1`;
  GitHub Actions run `32356255645` is green.
- Drive control `02_CODEX_WORK_PACKAGES_SIT_V2.3.md` maps C1G to privacy,
  network, FCM and Crashlytics.
- V5.2 Core section 11 requires neutral transactional FCM, shortest sensible
  per-message TTL, default-off voluntary Crashlytics and fail-closed external
  provider gates.
- C1A items 20-23 prove the remaining bounded gaps: current notification code
  exposes specific titles/item text and entity identifiers and has no
  event-specific TTL; provider/Store facts remain open; final full-device
  network evidence belongs to C1I.
- Existing Crashlytics consent, revocation, sanitization, no-user-ID and
  default-off controls are already green and must not be weakened or coupled
  to push.

## Allowed work

- Define one server-owned transactional notification contract with a neutral
  visible title/body, opaque authenticated in-app routing and an allowlisted,
  event-specific TTL shorter than the FCM four-week default.
- Remove chat text, exact address, payment data, photos, damage evidence,
  listing/item text and raw business/entity identifiers from push payloads.
- Keep detail retrieval behind normal authenticated SIT API access after the
  user opens the app; push refusal must not block registration, listings or
  bookings.
- Add focused tests for notification purpose, TTL, payload key allowlist,
  token cleanup, invalid-token handling and the absence of sensitive fields.
- Verify and harden local-font, controlled-image and disabled external
  AI/Places/Nominatim/OSM/analytics/ads paths with provider-bound fail-closed
  feature flags and functional manual/internal fallbacks.
- Preserve and test separate Crashlytics consent, default-off startup,
  revocation, unsent-report cleanup, sanitization allowlist and the prohibition
  on user identifiers.
- Update privacy/retention/Store readiness manifests only with locally proven
  implementation facts and stable open blocker codes.
- Add focused static/network-contract validators and wire them into the
  complete technical regression.

## Not allowed in C1G

- No Firebase, Google Cloud, provider or Store console action; no live push,
  crash upload, analytics event, network capture against live accounts or
  external provider traffic.
- No invented provider company, contract, DPT date, region, subprocessors,
  transfer mechanism, retention promise, deletion completion or Store answer.
- No closing FI0 owner/provider/transfer/retention/deletion gates based only on
  code configuration or documentation.
- No enabling Google Analytics, BigQuery export, analytics breadcrumbs,
  marketing push, advertising SDKs, external generative AI or arbitrary image
  hosts.
- No production, VPS/OpenClaw, DNS, payment, Store, signed-release,
  public-rollout or destructive Git action.

## Acceptance criteria

- Every FCM request uses the exact neutral lock-screen message and contains no
  sensitive or business-readable detail; its data payload is an allowlisted
  opaque navigation signal only.
- Each approved transactional event class has a documented shortest-sensible
  TTL; unknown, marketing or malformed event classes fail closed and no code
  path relies on FCM's default four-week TTL.
- Notification-token lifecycle and invalid-token cleanup stay green; denying
  or disabling push leaves all core flows available in-app.
- Crashlytics remains off before separate voluntary consent, sends no SIT user
  identifier or forbidden custom/log data, and stops new reports after
  revocation. Push cannot change this state.
- Google Analytics, FCM BigQuery export, analytics breadcrumbs, ads and
  marketing push are machine-verifiably disabled.
- Runtime font fetching, arbitrary production image hosts and unapproved
  external AI/maps/geocoding/tile traffic are absent or fail closed behind a
  provider-complete gate; the corresponding fallback remains functional.
- Privacy, retention, deletion and Store readiness files distinguish proven
  local controls from unresolved provider/account facts and remain
  draft/fail-closed where those facts are missing.
- Focused tests, complete local technical regression and GitHub CI are green
  for the bounded implementation commit. Full physical network/device proof is
  explicitly deferred to C1I rather than claimed early.

## Expected next transition

GREEN: C1H - V5.2 Categories, Moderation, Invoice/Receipt and Operator
fail-closed configuration.
YELLOW/RED: preserve evidence and stop at the exact privacy, provider,
notification, network, Store or consent conflict without enabling a service.
