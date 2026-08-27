# RW20C — OnePlus owner-window smoke readiness

Status: **PREPARED — NOT RUN — RELEASE AND OWNER WINDOW GATED**

## Decision

RW20B proved that the useful next evidence cannot come from another broad
source hardening package. It must come from the exact Google Play Internal
candidate on the owner's OnePlus. RW20C therefore prepares the smallest safe
device action that can be run from the owner's MacBook after the later Play
release and Wireless-ADB pairing.

This package does not activate the Play draft and does not contact a phone.
It only turns the already classified `R4_LIFECYCLE_CORE` subset into a
deterministic command whose real output remains `NOT_RUN` today.

## Two independent gates

The future runner rejects its arguments before the first ADB query unless both
literal values are present:

1. `GOOGLE_PLAY_INTERNAL_RELEASE_GO`
2. `ONEPLUS_PERSONAL_DEVICE_NONDESTRUCTIVE_TEST_GO`

The first confirms that candidate `2026082601` may be active. The second
confirms that Walid is present, the personal phone is unlocked and a bounded
process lifecycle may temporarily launch, stop and background ShareItToo.
Neither gate is currently granted.

Prepared future command:

```text
node tool/run_oneplus_play_internal_owner_smoke.mjs --confirm-release-go GOOGLE_PLAY_INTERNAL_RELEASE_GO --confirm-owner-window ONEPLUS_PERSONAL_DEVICE_NONDESTRUCTIVE_TEST_GO
```

## Exact prepared scope

After both gates, exactly one physical OnePlus over Wireless ADB must pass the
RW20B read-only preflight for:

- package `com.shareittoo.app`;
- version `1.0.0+2026082601`;
- minSdk 24 and targetSdk 35;
- Google Play installer identity;
- an already unlocked phone.

Only then may the runner perform one bounded lifecycle:

- force-stop and prove process absence;
- cold-start and prove foreground state;
- warm-start and prove the same process;
- press Home and prove background state with the same process;
- resume and prove foreground state with the same process;
- re-read installation time and app-data inode and require both unchanged.

The result records booleans and semantic outcomes only. It never records the
ADB address, raw device identifier or process identifiers.

## Deliberate exclusions

The runner cannot install, update, uninstall or clear app data. It cannot
change WLAN, permissions or global settings, enter credentials, inspect
account content, tap application controls, type text, capture screenshots,
dump the UI hierarchy or read logcat. It cannot claim functional screens,
authentication, Account-A-to-B isolation, accessibility, network recovery,
repeated stability, clean-install behavior, AAB byte equivalence or Play
app-signing certificate verification.

Authenticated navigation, large text, network transitions and any destructive
clean-install test retain their separate RW20B gates. A failed lifecycle run
emits no pass evidence and makes only a best-effort relaunch so the personal
phone is not deliberately left with ShareItToo stopped.

## Current truth and next action

- The uploaded candidate remains a Play Internal draft.
- `GOOGLE_PLAY_INTERNAL_RELEASE_GO` is not granted.
- The OnePlus is expected to contain active build `2026081509`, not candidate
  `2026082601`.
- Wireless pairing and every RW20C check are `NOT_RUN`.
- No Store, tester-list, device, production, Payment, provider, Firebase,
  Cloud/VPS/DNS or PR-merge action occurred.

After Walid returns, the order remains: release decision, Play update on the
OnePlus, Wireless-ADB pairing, RW20B read-only preflight, explicit owner-window
gate, then this bounded smoke. No later matrix lane is inferred from its result.

## Deterministic CI correction

The first implementation commit used a literal credential-shaped property only
inside a negative sanitizer test. GitHub's unchanged full-history secret scan
correctly rejected that synthetic fixture. The current test constructs the key
at runtime, so the working tree contains no finding. Because pushed history is
immutable and history rewrite is prohibited, the exact old commit, rule and
test path are recorded in the existing reviewed-history baseline. The scanner
rule is unchanged, working-tree findings remain impossible to baseline, and no
broad path, rule or value exception was added.
