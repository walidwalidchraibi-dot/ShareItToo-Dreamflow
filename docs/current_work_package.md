# Current Work Package: G5A - Supply Enrichment During Listing Creation

Status: **active under the V2.4 rolling-autonomy runway** on 21.08.2026.

## Authorization and boundary

Walid instructed Codex to follow `00_NEXT_COMMAND_G3A_APPROVED_V2.4.txt`.
G4B is technically GREEN at commit
`24f5f062e09e22de62f5b8dc0035c0a2cfc6840c`; exact GitHub Actions run
`32425415877` passed with 315 backend and 313 Flutter tests. V2.4 therefore
auto-continues to G5A even though every planner/public release gate remains
closed.

No production external generative AI is authorized. No production, public/live,
VPS/OpenClaw, Maximus, SSH, DNS, cloud-console, real-payment, Store, signing,
provider-account or destructive action is authorized. PR #7 remains Draft and
unmerged. Booking groups, the planner and G5 supply enrichment remain disabled
by default and unavailable in release mode.

## G4B handover

- Real inventory is resolved only through exact catalog targets and the current
  authoritative booking quote preview; absent or stale facts fail closed.
- The deterministic variants expose only verified ranking bases and no owner
  identifier. Cart sync is snapshot-bound, transactional and re-quotes every
  selected item.
- Planner cart lines stay non-reserving and create no request, booking, hold,
  contract or payment. Internal events are data-minimized.
- The feature is default-off, rejected in production and has no external-AI or
  public-release switch.

## G5A required result

- Only after the main listing has been created successfully, show at most three
  relevant complementary suggestions. Suggestion failure must never roll back,
  delay or block the primary listing publication.
- First-version detection may use deterministic category/template heuristics.
  It must not call production external AI, invent a detected object or claim
  certainty beyond the input facts.
- Support the five explicit owner outcomes from the Growth source:
  included accessory with required documentation; shortened linked separate
  rental; prefilled standalone new listing; not part of the offer with a
  clarity reminder; and wrong-detection feedback without treating the
  suggestion as truth.
- Preserve the existing private-pilot category allowlist and primary listing
  validation. Do not change price, contract, payment, availability, Store or
  production behavior.
- Keep any feedback/audit data bounded, owner-scoped, export/deletion/retention
  covered and disabled with the feature. No general Firebase Analytics,
  marketing analytics or external provider traffic is authorized.

## Package gate

Run focused heuristic, maximum-count, outcome, linking, fail-open-primary and
feature-gate tests plus the complete technical regression at the exact package
head. Record the detection limits, data lifecycle, non-blocking boundary,
privacy impact and rollback. When G5A is technically GREEN, V2.4 auto-continues
to G5B without enabling supply enrichment publicly or calling external AI.
