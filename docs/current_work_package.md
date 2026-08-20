# Current Work Package: G4B - Real Inventory Resolution and Project Cart

Status: **active under the V2.4 rolling-autonomy runway** on 21.08.2026.

## Authorization and boundary

Walid instructed Codex to follow `00_NEXT_COMMAND_G3A_APPROVED_V2.4.txt`.
G4A is technically GREEN at commit
`c1350f30838e6584c53604312a11c1aea70b36a8`; exact GitHub Actions run
`32423242364` passed with 308 backend and 313 Flutter tests. V2.4 therefore
auto-continues to G4B even though professional G3 legal review remains open.

No production external generative AI is authorized. No production, public/live,
VPS/OpenClaw, Maximus, SSH, DNS, cloud-console, real-payment, Store, signing,
provider-account or destructive action is authorized. PR #7 remains Draft and
unmerged. G3 booking groups and every planner entry remain disabled by default
and unavailable in release mode.

## G4A handover

- The deterministic planner core has exactly five reviewed templates and asks
  four or five bounded questions before producing item-type guidance.
- All 468 possible bounded answer combinations are deterministic and contain
  required, recommended and optional items plus explicit assumptions,
  compatibility rules and safety boundaries.
- G4A contains no real listing, owner, availability, quote, price, reservation,
  route, public UI, persistence, telemetry or external generative-AI call.
- Backend and Flutter controls remain default-off and fail closed for
  production/release use. A hard stop remains before public/live activation.

## G4B required result

- Resolve planner item types only against real eligible listings and current
  server-owned availability and quote truth. Missing or stale facts fail
  closed; no result may be invented from category similarity.
- Produce deterministic `1-Stop`, price-efficient and top-rated variants from
  explicit ranking inputs. Labels must describe the verified ranking basis and
  must not imply availability, quality or savings beyond current server facts.
- Support bounded add, edit and remove actions on plan items and adding the
  selected result to the existing project cart. The cart remains
  non-reserving and creates no booking, request, hold, contract or payment.
- Revalidate listing eligibility, owner, period, availability and current quote
  before any later rental request. Changed or unavailable items remain visible
  as changed/unavailable rather than silently substituted.
- Add only internal, data-minimized project-funnel instrumentation. No ads,
  marketing analytics, general Firebase Analytics or external provider traffic
  is authorized.

## Package gate

Run focused resolver, ranking, revalidation, cart-safety and instrumentation
tests plus the complete technical regression at the exact package head. Record
server-truth boundaries, ranking inputs, non-reservation controls, privacy
impact and rollback. When G4B is technically GREEN, V2.4 auto-continues to G5A
without enabling the planner publicly or calling an external AI/provider.
