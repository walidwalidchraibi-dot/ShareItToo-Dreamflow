# RW19 profile and location mutation principal/epoch transaction closure

## Scope

RW19 closes the remaining repository-owned user profile and location mutation
surfaces after verified RW18 closure
`37c313a62daf79a34352fd3f34ba16b9db8dc4a4`. The protected surfaces are
address and coordinates, contact address, full and compact profile editing,
social links, biography, interests, photo/media selection, manual city and
permission-backed automatic location.

## Confirmed cause

The existing UI usually captured Account A's visible values, but after one or
more awaits it called `DataService.updateCurrentUserProfile`. That data-layer
path validated A and then `BackendRepository.updateCurrentProfile` acquired the
globally current token later. A precisely timed A-to-B transition could
therefore pair A's payload with B's credential. Several screens also surfaced
delayed success/error or navigation under B, and the contact map save reread a
mutable current user from widget state inside the sheet.

RW19 removes those paths from every repository-owned profile mutation screen.
The exact owner now flows through coordinator, data layer and backend
repository, while exact route identity and typed result truth protect every UI
boundary.

## Red-first and focused proof

The focused test was introduced before the coordinator/types and initially
failed to compile. It now proves:

- exact structured profile rejections and non-rejection of `408`,
  intermediary and unstructured failures;
- no remote call when Account A is stale immediately before mutation;
- accepted Account A truth remains accepted after a switch to B;
- local failure after server acceptance cannot become "not changed";
- exact context and action-epoch ownership;
- invalidating an A profile sheet preserves a newer B dialog;
- the A map sheet closes before a mutation can start under B; and
- a delayed accepted A address result cannot surface or navigate under B.

Permanent wiring tests additionally bind owner-only credential acquisition,
owner checks around remote and paired local commits, the exact rejection
allowlist, all seven screens, typed-before-generic result handling, exact route
identity, GPS/media await checks and supported-regression inclusion.

## Verification state

Focused verification is complete: nine RW19 Flutter tests and eight RW19
wiring tests pass, the retained RW9/RW18 compatibility matrix passes, and the
changed Dart sources analyze with zero issues. The implementation commit, full
standard-parallel regression, exact-head GitHub Regression and CodeQL evidence
are intentionally recorded only after they complete.

No timing relaxation, retry accommodation, test exclusion, order dependency or
parallelism reduction is an accepted release prerequisite.

## Ratchet cause

RW19 adds exact-owner propagation for profile mutation, typed result semantics,
screen-local action epochs and identity-owned route cleanup. It does not change
legal text, privacy-disclosure meaning, retention periods, backend route/schema,
provider selection or any external gate decision. Predecessor evidence hashes
and call-site inventories are refreshed mechanically only where protected
sources changed; predecessor implementation and closure heads remain unchanged.

## Residual boundary

No live backend, location-provider, device, release artifact, Store, Play,
payment or process-termination reconciliation proof is claimed. Those remain
external or later bounded gates after repository-owned closure.
