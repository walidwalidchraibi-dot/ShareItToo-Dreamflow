# S3H support break-glass access - technical compliance record

Status: implementation complete locally; exact-commit GitHub CI verification
pending.

## Implemented controls

- Reversible migration `037` creates immutable, case-bound emergency access
  grants with database-enforced P0, non-live, actor, session, step-up and
  five-minute limits.
- Missing reason, invalid reason, unsafe justification, non-P0, closed, live or
  already-assigned cases fail closed.
- The access token is HMAC-derived for exact idempotent replay and only its
  SHA-256 digest is persisted.
- Support detail access remains assigned-owner-only unless the exact bounded
  grant validates. Queue access is not widened.
- Creation, denial and successful use are audited without token or internal
  justification disclosure.
- Automatic review is due at grant expiry. Completion requires a different
  active administrator and records that administrator's exact authenticated
  session and current Staff-Step-up elevation.
- Grant core, completed review and revocation truth are immutable; deletion and
  rollback with records present are blocked.
- User export exposes a safe transparency projection while excluding staff
  identifiers, internal reasons, notes and credential material. The retention
  inventory classifies the full table as `securityAudit` while all retention
  decisions remain open.

## Source binding

- Support test matrix `SUP-024`/`SUP-025`: Drive ID
  `1CcCqdsEVveiqoKJqZlA_iHKfZhttU5Le`, modified
  `2026-08-20T22:29:02.738Z`.
- Support technical/data-model/audit PDF: Drive ID
  `19rXQidltzp3jvEWqnz4zgppTnTgL0iCl`.
- Native Support Master Policy: Drive ID
  `15Ep_utCHp3B_b7z3_dLoVydvlTNYv8bHTRGvxMLDtts`.
- Architecture decision:
  `docs/architecture/s3h-support-break-glass-access-2026-08-21.md`.

## Verification state

- Focused domain, workflow, support access, retention and wiring tests pass
  locally.
- Privacy and retention validators and their negative-test suites pass while
  both manifests remain draft and fail closed.
- PostgreSQL 16 execution, complete Backend/Flutter/Web/Android regression,
  secret scan and dependency audit remain delegated to exact-commit GitHub CI
  because the Mac mini has no local Docker runtime.

## Persistent exclusions

- No canonical incident object or incident-wide access has been invented.
- No external message, automatic case reassignment, operational escalation or
  employment consequence is executed.
- No production, Cloud, VPS, Store, DNS, payment, refund, payout, public pilot,
  signed candidate or publication action is authorized by S3H.
