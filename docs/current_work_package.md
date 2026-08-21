# Current Work Package: P0A - Closed-Pilot Technical Readiness

Status: **active under the V2.4 rolling-autonomy runway** on 21.08.2026.

## Authorization and boundary

Walid instructed Codex to follow `00_NEXT_COMMAND_G3A_APPROVED_V2.4.txt`.
FI1 is technically GREEN at commit
`a732ebaa257462fe2292232c779906d4331b0321`; GitHub Actions run
`32431950081` associated with that exact PR head passed with 333 backend and
321 Flutter tests, plus one documented Flutter skip. V2.4 therefore
auto-continues to P0A.

P0A is technical readiness evidence only. No public rollout and no real money
are authorized. No production, VPS/OpenClaw, Maximus, SSH, DNS, cloud-console,
Store, signing, provider-account, account-permission, live external-provider or
destructive action is authorized. PR #7 remains Draft and unmerged. Booking
groups, planner, supply enrichment and listing sets remain disabled by default
and unavailable in release mode.

## FI1 handover

- Four role-owned operational processes have explicit delegates, runbooks,
  audit sources and bounded escalation thresholds, but all remain `hold` until
  real company-system assignments and absence tests exist.
- Normal operations never route automatically to a named founder. The cockpit
  keeps operational funnel, founder hours and founder escalations separate.
- No runtime permission, account, provider, production, payment, Store or public
  activation changed. FI1 adds no migration or user-data category.

## P0A required result

- Produce an end-to-end technical matrix for the existing single-item path,
  disabled same-owner multi-item path and disabled project-cart/planner path.
- Prove payment remains synthetic/test-provider only, with Stripe livemode and
  real payment execution off and no live external-provider traffic.
- Cover account lifecycle, cancellation, withdrawal, handover/return,
  `needsReview`, export/deletion and recovery with focused regression plus the
  complete technical gate.
- Record current Pixel 7 Pro reachability and current-source device binding
  honestly. Do not overwrite or uninstall the installed app merely to force a
  green device cell. Historical device evidence must not be presented as proof
  for the current source head.
- Run current-source web smoke and Android/Web builds where relevant. Do not
  create a signed candidate or submit/upload any binary.
- Classify every matrix cell as passed, blocked, not applicable or historical;
  missing evidence must never become a pass.

## Package gate

Run focused single-item, multi-item, planner/cart, account, cancellation,
withdrawal, evidence/return, `needsReview`, export/deletion, recovery and
payment-boundary tests plus the complete backend and technical regression at
the exact package head. Validate the matrix mechanically and record current
device/web evidence without identifiers or secrets.

If a current-source physical-device cell remains blocked by the existing
signature-preservation boundary, close P0A as an honest technical-readiness
HOLD rather than changing device data or signing a release. The independent,
non-activating P0B-READINESS dossier may still proceed under V2.4 and must carry
that blocker forward. No pilot activation is authorized.
