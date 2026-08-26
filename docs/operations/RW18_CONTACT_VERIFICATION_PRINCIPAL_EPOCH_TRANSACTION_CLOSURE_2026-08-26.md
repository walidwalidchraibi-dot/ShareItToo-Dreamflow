# RW18 contact and verification principal/epoch transaction closure

## Scope

RW18 closes the four remaining repository-owned security-action inventory
entries: `contact.email-change`, `contact.phone-verification`,
`contact.email-verification` and `login.email-verification`. Its verified
predecessor is RW17 closure
`3f1f6aae4e66356712230ecd6b2a560bf6d72680`.

## Red-first proof

The focused RW18 test initially failed to compile because the repository had no
principal-bound contact coordinator, no owner-bound phone challenge and
attempt epoch, no exact modal-sheet route helper, no login email/action owner
and no identity-bound Firebase cleanup predicate. This pinned the missing
contract before implementation.

The deterministic matrix now proves:

- email change rejects only exact structured server contracts;
- `408`, intermediary and unstructured email outcomes remain unknown;
- email-verification request has its own narrower rejection allowlist;
- Account A is rechecked immediately before email-change mutation;
- accepted A truth remains accepted after an A-to-B transition;
- automatic A phone confirmation retains confirmed truth after an A-to-B transition;
- every phone challenge carries its exact owner and attempt epoch;
- temporary Firebase cleanup cannot sign out a newer same-UID attempt;
- phone backend rejection uses the exact checked-in server contracts;
- `408`, intermediary and unstructured phone outcomes remain unknown;
- confirmed and unconfirmed local Firebase cleanup failures stay distinct;
- changed login email or action epoch invalidates resend ownership;
- exact removal of an A modal sheet preserves a newer B dialog;
- delayed A email request cannot open a result sheet under B;
- A phone consent closes before any provider request can run under B;
- closing A phone consent preserves a separately owned B dialog.

The legacy bool/generic `AuthService.requestEmailChange` and
`AuthService.requestEmailVerification` entry points are removed, leaving no
unguarded call site that can reintroduce result collapse.

## Verification state

Focused RW18 and adjacent RW16/RW17/phone-contract tests and changed-file
analysis pass. Full technical regression and exact-head GitHub
Regression/CodeQL are recorded only after their commands complete.

No retry, timing relaxation, exclusion, test-order dependency or parallelism
reduction is an accepted release prerequisite.

## Ratchet cause

RW18 changes client action ownership, result semantics, phone-provider cleanup
and the durable security-action inventory. It does not change legal wording,
retention periods, provider selection, external gate state or any predecessor
verified implementation/closure head. Historical source hashes and call-site
inventories are refreshed mechanically where current protected sources moved
behind the new coordinator.

## Residual boundary

No live email, SMS, Firebase, backend, device or process-termination proof is
claimed. Provider enablement, deliverability, release candidate creation and
owner/live gates remain separate later work.
