# PF14B signed-candidate archive lifecycle

Status: **TECHNICAL FIX PASSED LOCALLY — EXACT CI AND SIGNED RERUN PENDING**

Observed: 2026-08-23

PF14B's first signed internal Staging build for build `2026082302` completed
the AAB, APK and privacy scan. It then failed closed with `ENOSPC` while
copying the exact artifacts into the owner-only private archive. The incomplete
archive was removed by the existing archival transaction, so no candidate from
that attempt is eligible for installation or evidence.

## Durable correction

The signed Android builder now owns its generated Flutter lifecycle. After the
fixed capacity preflight it performs one cold `flutter clean`, builds and
verifies both artifacts, creates the private archive and only then removes the
generated tree. A fail-closed exit trap performs the same generated cleanup
after any failure without hiding the original failure. The private archive is
outside Flutter's generated tree and is never removed by this lifecycle.

A source contract fixes that ordering and rejects cleanup by `rm`, capacity
environment overrides, sleeps or retries. The shared capacity limits remain
unchanged. Manual cleanup after the failed attempt is incident hygiene only,
not release evidence.

## Pending deterministic exit

`TD-RR-021` remains open until all of the following pass on one clean commit:

1. the unchanged complete local regression;
2. exact-head GitHub regression and CodeQL;
3. the same signed internal Staging build with a complete validated private
   archive and the fixed end-capacity check; and
4. the strict data-preserving Pixel update plus sanitized 200%-font navigation
   geometry proof.

No Store upload, production/provider change, Payment action, public release,
manual TalkBack claim or manual visual-review claim is part of this package.
