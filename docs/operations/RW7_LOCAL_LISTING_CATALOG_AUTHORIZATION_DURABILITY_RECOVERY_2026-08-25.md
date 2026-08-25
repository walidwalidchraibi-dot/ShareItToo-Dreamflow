# RW7 local listing-catalog authorization, durability and recovery

Date: 2026-08-25
Run mode: synthetic local implementation and verification only

## Supported checks

```bash
flutter analyze \
  lib/screens/create_listing_screen.dart \
  lib/screens/my_listings_screen.dart \
  lib/screens/own_profile_screen.dart \
  lib/screens/privacy_info_screen.dart \
  lib/services/data_service.dart \
  lib/services/shared_persistence_sync.dart \
  test/rw7_local_listing_catalog_authorization_durability_test.dart
flutter test --reporter expanded \
  test/rw7_local_listing_catalog_authorization_durability_test.dart
flutter test --reporter expanded
node --test \
  test/tool/validate_g2_data_lifecycle.test.mjs \
  test/tool/validate_privacy_disclosures.test.mjs \
  test/tool/validate_retention_deletion_readiness.test.mjs \
  test/tool/validate_active_infrastructure_mail_provider_readiness.test.mjs \
  test/tool/rw7_local_listing_catalog_authorization_durability_wiring.test.mjs \
  test/tool/validate_rw7_local_listing_catalog_authorization_durability.test.mjs
node tool/validate_g2_data_lifecycle.mjs
node tool/validate_privacy_disclosures.mjs
node tool/validate_retention_deletion_readiness.mjs
node tool/validate_active_infrastructure_mail_provider_readiness.mjs
node tool/validate_rw7_local_listing_catalog_authorization_durability.mjs
CI=true SIT_ALLOW_CANDIDATE_ROLLOVER=1 \
  bash scripts/technical_regression_check.sh
```

## Current evidence

- Focused RW7 Flutter matrix: 14 passed.
- Default Flutter matrix: 485 passed with three documented exact-profile skips.
- Changed-file analyzer: zero issues.
- G2 lifecycle, privacy, retention and provider-readiness validators: passed;
  provider result remains `prepared-hold`, 0/10 decisions and not externally
  ready.
- Full technical regression and GitHub Regression/CodeQL remain pending until
  the implementation commit exists.

## Operational behavior

- Public catalog reads remain available without an owner session.
- Local owner mutations require matching current profile, auth session and
  stored owner.
- Corrupt or duplicate entries preserve the exact raw document and fail closed.
- The catalog accepts at most 1,000 entries; overflow rejects without pruning.
- Storage failure preserves prior bytes and a rejected operation does not poison
  the serialized queue.
- Ended listings are not automatically deleted after 60 days.
- Privacy export includes only current-owner local listings.
- Confirmed local deletion ends current-owner listings but does not invent a
  deletion deadline.
- Owner screens clear stale content, recheck account identity and expose retry.

## Recovery and rollback

Do not normalize or delete a malformed listing document. Keep the affected
owner UI closed, preserve the exact bytes and perform separately reviewed
recovery. Capacity exhaustion requires explicit storage/lifecycle remediation;
silently stripping photos or dropping listings is forbidden.

Rollback is a normal Git revert of the bounded RW7 implementation before a
successor depends on it. Revert code, lifecycle, privacy, retention, validator
and evidence changes together. Do not reset, rebase or rewrite history.

## Open gates

The GitGuardian owner-history review remains open and its finding contents were
not inspected. BUILD_READY, Play upload, human pilot activation, PR #7 merge,
production/provider/AI, real money and every VPS/DNS/Cloud/Store/legal-owner
gate remain ungranted.
