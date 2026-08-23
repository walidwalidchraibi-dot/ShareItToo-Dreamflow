# PF14A main-navigation touch-target remediation

Status: **SOURCE REMEDIATION PASSED — NEW SIGNED CANDIDATE AND PHYSICAL RECHECK PENDING**

Observed: 2026-08-23

PF14A remediates a physical accessibility finding from the exact PF6 Android
candidate. At 200% text on the Pixel, four clickable primary-navigation
semantics nodes exposed an effective height of about 43dp; only the central
32dp asset exposed about 55dp. Android recommends a focusable or touch target
of at least 48dp by 48dp for every interactive element.

## Durable implementation

Every inactive and active icon supplied to the five-item
`BottomNavigationBar` now uses one shared `kMinInteractiveDimension` wrapper.
The visual search, cart, booking, message and profile icons retain their
existing size and appearance; only the transparent interactive layout floor is
expanded. No delay, platform exception, lint suppression or device-specific
constant is used.

A 200%-text widget test requires every composed semantics node to remain at
least 48dp in both dimensions and separately proves that a 20dp visual child
stays 20dp. A source wiring ratchet requires both inactive and active icons for
all five real destinations to use the wrapper.

## Remaining package gate

The direct-installed PF6 binary predates this source change and therefore
cannot prove the remediation. PF14B must create a strictly newer, signed,
commit-bound internal Staging candidate, preserve the Pixel app data during a
direct diagnostic update and repeat the sanitized 200%-text geometry check.
Google Play, manual TalkBack and manual visual review remain separate external
gates. No Store, provider, production, Payment, public or real-money state may
change.
