# 48H R9 database migration, backup and restore

Status: **LOCAL VERIFIED — FULL REGRESSION GREEN; EXACT GITHUB CI PENDING**

R9 runs only against a repository-owned PostgreSQL 16 cluster bound to
`127.0.0.1`. It creates four temporary databases for the current source,
fresh restore target, representative older state and empty rollback control.
It does not connect to Production or VPS PostgreSQL.

## Migration and complete-schema proof

The source database starts with zero public tables. The canonical bootstrap and
all 69 checksum-bound migrations from `001_b3_foundation.up.sql` through
`069_regional_price_engine_r6_hardening.up.sql` apply successfully. A second
run changes no migration ledger row. The complete public schema fingerprint is
`ba28af73746f6456a96583951c5212b8784063ba6fac569d3d91b53667e8b497`,
covering 136 tables, 1,918 columns, 1,559 constraints, 517 indexes, 303
functions and 163 non-internal triggers.

## Backup, restore and integrity

The bounded fixture contains 12 synthetic accounts, six synthetic listings,
one support-policy snapshot, one Listing-AI draft and one R6 hardened price
snapshot. It contains no real person, real payment or stored synthetic
credential. A PostgreSQL custom-format archive is list-validated and restored
into a separately created empty database. Source and restored schema
fingerprints, migration inventory and data digests match exactly.

The restored database has zero unvalidated constraints, missing migration rows,
checksum mismatches or tested owner/draft/price-snapshot orphans. The retained
archive hash is
`38e18e02eec0d0e6aee08e006d8f896894e14972f10fb25cb12561cf83244c0a`;
the archive itself is deliberately removed with the temporary cluster.

## Older-state upgrade and rollback guards

A representative state at migration 027 contains four synthetic legacy users,
two listings and one persistent cart item. Upgrade through migration 069 and a
second migration run preserve every row and produce the same complete-schema
fingerprint as the fresh source.

The R6 down migration succeeds only in the empty rollback-control database and
is rolled back inside its surrounding transaction. Against restored retained
evidence, the Support 032, Listing-AI 066 and Price Engine 069 down migrations
all refuse with their exact fail-closed errors. The restored data digest stays
unchanged after all attempts.

Implementation head `bfbbc94629b60f7df0862de3dc60ef6376cda959`, three
runner contract tests, three CI wiring tests, five evidence-validator tests and
the artifact validator are green. The complete candidate-rollover technical
regression is also green in CI-metadata mode: analyzer zero, 393 Flutter passes
plus one documented skip, the separate Google-only profile, Web/Wasm, loopback
smoke and the 448-task Android debug build all pass. Exact GitHub
Regression/CodeQL verification remains pending. No Production, VPS, Cloud,
Payment, real-user, real-money, PR-merge or history-rewrite action is part of
R9. After exact local and GitHub verification, R9 closes and R10 begins.
