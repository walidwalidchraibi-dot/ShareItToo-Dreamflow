# ShareItToo Current State

Verified: 2026-08-20 on the Mac mini.

## Repository baseline

- Checkout: `/Users/walidchraibi/Worktrees/SIT-master-workflow-20260808`
- Branch / PR: `codex/master-workflow-20260808`, draft PR #7 against `main`.
- Verified R0 product baseline: `df62700a4ead526abc5d84edb0139f17fb0c21bc`.
- At that baseline the local branch, remote branch and PR head are identical;
  the working tree is clean and the PR is cleanly mergeable.
- Required checks are green: GitGuardian, backend regression with PostgreSQL,
  and Flutter regression. Workflow run: `32339391645`.
- No rebase, force-push, history rewrite, branch deletion or PR merge occurred.

## Implemented system

- Flutter client version `1.0.0+2026081510` with Android, iOS and web targets.
- Node/Express backend with PostgreSQL migrations through `022`, deterministic
  server quotes, contract/acceptance evidence, booking lifecycle, messaging,
  moderation, financial-document and account-lifecycle foundations.
- Release and compliance state is machine-validated under `store/` and by
  `tool/` plus `test/tool/`; repository architecture/evidence is versioned under
  `docs/`.
- Mac-mini Android signing and Android/iOS Firebase configuration gates pass
  locally without exposing protected values. Pixel 7 Pro is ADB-authorized.

## Current safe operating state

- C2C private-adult pilot for Germany/server-approved regions only.
- Vehicles/transport, paid delivery, shipping, express, deposits, SIT
  insurance/protection and automatic damage collection are out of scope.
- Real money is off; payment execution remains test/memory only.
- Ads, marketing analytics, general Firebase Analytics and external generative
  AI are off. Transactional FCM and voluntary Crashlytics remain separately
  controlled and default off.
- Store submission is blocked (`store/submission.json`: draft,
  `submissionAllowed=false`). Device readiness is on hold/testing; the retained
  Store candidate remains historical evidence rather than a new release.
- Privacy, retention and legal manifests remain draft/fail-closed. Open owner,
  legal, provider, Apple/iOS, full device-matrix and final binary gates must not
  be silently closed.
- No production, VPS/OpenClaw, DNS, cloud-console, payment, Store or live-provider
  mutation was made during Mac-mini recovery and R0.

## Validation and rollback

- Complete local technical regression: 292 Flutter tests passed with 1
  intentional skip; Google-only profile, web build and Android debug build pass.
- Backend local suite: 213 passed with 1 expected PostgreSQL skip; GitHub CI
  supplies PostgreSQL and passes the integration flow.
- The verified migration package and Git bundle are retained as rollback
  evidence. The MacBook is not required for ongoing work; SSH is not used.

## Next source of truth

The active bounded task is `docs/current_work_package.md`. Older reports and
the root `architecture.md` are evidence/history, not permission to reopen a
closed launch boundary.
