# Current Work Package: C1C - V5.2 Legal Registry and Immutable Assets

Status: active after green C1B implementation and GitHub CI.

## Objective

Create the V5.2 legal registry proven open by
`docs/compliance/c1a-v52-delta-audit-2026-08-20.md`:

- generate nine separate, accessible and immutable user assets for source
  parts A-I;
- bind the source and every generated asset by exact SHA-256, version and page
  range in a new V5.2 manifest;
- keep all documents and the manifest fail-closed while operator, provider and
  URL facts remain open, while disclosing that no professional review occurred;
- exclude internal source parts J-L from every user asset.

## Baseline and inputs

- Branch: `codex/master-workflow-20260808`; draft PR #7.
- C1B implementation: `8976a5f82ae42337ad0ada27a1ca4645949ac85b`;
  GitHub Actions run `32342731231` is green.
- Authoritative legal source: `ShareItToo Rechtsmappe Privat-Launch V5.2`,
  Drive file `1kKuZl9OJ4nb9F02E8fepTxY8O-GZBkn2`, 55 pages, SHA-256
  `aa6f631457c9b73fdae3c5d4415ba6681b86f63b51df3fd5937c50f80a27b8a8`.
- User source parts: A pages 8-18, B 19-23, C 24-25, D 26-28,
  E 29-31, F 32, G 33-34, H 35-41 and I 42-45.
- Existing V5.1 assets and `assets/legal/de/legal_manifest_v5.json` are
  immutable historical evidence and remain active inputs to their validators.

## Allowed work

- Add a new V5.2 asset directory and a separate V5.2 manifest.
- Add deterministic source-to-HTML build tooling that rejects a wrong source
  hash or page count.
- Add a fail-closed validator and focused mutation tests for source binding,
  asset hashes, page ranges, open facts, inactive status and exclusion of J-L.
- Wire the focused validator into the complete technical regression.

## Not allowed in C1C

- No V5.1 asset or manifest overwrite.
- No change to checkout declarations, contract persistence, public legal URLs,
  database legal provisioning or app activation; those belong to later gates.
- No invented company, register, tax, contact, supervisory, provider, region,
  contract, transfer, retention or professional-review fact.
- No production, VPS/OpenClaw, DNS, cloud, payment, Store, provider or live
  traffic action.
- No real-money enablement, signed release upload, public rollout or
  destructive Git action.

## Acceptance criteria

- Exactly nine A-I user assets are generated from the reviewed 55-page source;
  J-L content is absent.
- Builder and manifest bind the exact source hash, Drive identity, byte size,
  page count, version and A-I page ranges.
- Every asset is bound by SHA-256, contains no executable or remote content and
  remains `draft-blocked` with null public/download URLs.
- Required operator, provider, Firebase and publication facts remain explicit
  open gates; activation and production provisioning remain false.
- Existing V5.1 validation and all non-live product boundaries remain green.
- Full local technical regression and GitHub CI are green after the bounded
  commit.

## Expected next transition

GREEN: C1D - V5.2 Checkout, Contract and Declaration Binding.
YELLOW/RED: preserve evidence and stop at the exact source, asset or legal-fact
conflict.
