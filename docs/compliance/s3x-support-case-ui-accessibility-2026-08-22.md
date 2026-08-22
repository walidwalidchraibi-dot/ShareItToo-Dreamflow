# S3X support case UI accessibility - technical compliance record

Status: locally verified, non-live candidate on 22.08.2026. Commit and exact CI
evidence remain pending.

## Matrix result

- `SUP-143`: supported case states are rendered as simple German user text;
  raw internal lifecycle codes are absent.
- `SUP-144`: `Deine Antwort ist nötig` and the authoritative `Antwort bis`
  deadline are presented as a prominent separate block.
- `SUP-145`: a published final decision keeps decision, effect, reason,
  implementation and review as separate labelled sections.
- `SUP-146`: case cards, statuses and information headings have explicit,
  ordered semantics; decorative elements are excluded.
- `SUP-147`: the complete case detail is covered at two-times text scaling and
  can be scrolled without clipping or overflow.
- `SUP-148`: every status has a textual label and accessibility description;
  color is supplementary only.
- `SUP-149`: a case card can be reached by Tab and opened with Enter on Web.
- `SUP-150`: the tested case-card target is at least 48 by 48 logical pixels.
- `SUP-151`: the published closed outcome and its bounded review path remain
  explicit when server eligibility permits it.
- `SUP-152`: `Blockiert` is not offered for an empty blocked-user set, and an
  invalid empty selection is normalized to the active view.

## Verification observed so far

- Changed Dart analysis passes with no issue.
- 19 focused Flutter support-case widget tests pass.
- Three static accessibility/matrix wiring tests pass.
- Privacy and Retention source hashes were refreshed for the changed support
  screen; 58 protection tests and both validators pass.
- Complete local technical regression: accepted 220-issue analyzer baseline,
  367 Flutter tests passed with one documented Google-profile skip, the
  separate Google-only test passed, Web build/loopback smoke passed and the
  Android debug APK built.

No professional accessibility audit, manual screen-reader/device pass, Store
action, signed build, production mutation, payment, deployment, PR merge or
public communication was performed.
