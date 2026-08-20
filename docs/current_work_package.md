# Current Work Package: G3A - Same-owner Multi-item Decision

Status: **decision and architecture package complete; Walid decision required**
on 20.08.2026. No productive implementation is authorized or active.

## Authorization and boundary

Walid authorized exactly `G3A_FREIGABE`: inspect the current code, V5.2,
Rechtsmappe and Growth Master, present no more than three structures for several
items from the same owner, recommend one and stop for his decision.

No source runtime, database migration, API, Flutter flow, contract template,
payment, Store, cloud, VPS, production or provider state was changed. PR #7
must remain Draft and unmerged. G3B/G3C and every later package remain closed.

## Delivered decision package

The complete source/code analysis, three-variant comparison and legal/payment/
evidence/scaling impact record is:

`docs/architecture/g3a-same-owner-multi-item-decision-2026-08-20.md`

The current code is single-item end to end. The G2 cart can contain and recheck
several lines but deliberately creates no grouped request, reservation, booking
or payment.

## Preferred direction

**Variant A: one owner booking group with normalized item positions.**

- One renter, one owner and one immutable legal/country/currency/payment
  compatibility key define a group.
- One itemized group offer, acceptance decision and appointment provide the
  grouped experience.
- Existing booking semantics remain normalized positions with immutable quote,
  evidence, damage, refund and ledger allocation per item.
- An owner may accept all, reject all or send a partial counter-offer/new quote
  requiring active renter consent. There is no silent partial acceptance.
- Private/Business, owners, countries, currencies or legal/payment
  configurations are never mixed in one group.
- Historical V5.2 snapshots are not rewritten. A prospective legal/document
  version and professional review are mandatory before implementation.

## Alternatives retained for Walid's decision

1. `G3A_ENTSCHEIDUNG_A` - owner group plus item positions (**recommended**).
2. `G3A_ENTSCHEIDUNG_B` - process coordinator over N independent bookings.
3. `G3A_ENTSCHEIDUNG_C` - synthetic bundle listing (not recommended).

Variant B preserves more current code but cannot provide one real offer,
acceptance, payment or lifecycle. Variant C obscures individual inventory,
quotes, evidence, damage and refunds and is unsuitable for Business/global
scaling.

## Required next gate

Stop after G3A. Walid must choose one of the three decision tokens above. His
architecture choice does not itself authorize implementation or live changes;
a separately bounded implementation/legal package is required afterward.
