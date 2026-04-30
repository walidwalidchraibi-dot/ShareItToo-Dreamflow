# Local QA seed tool notes

`tool/seed_booking_qa_cdp.py` is for local Flutter-web QA only.

## Single-profile limitation

Two tabs in the same Chrome profile do **not** isolate Walid and Laura.
They share the same `localStorage`, so login/logout/session changes in one tab affect the other.

Use the standard sequential QA flow:
1. seed
2. login as Walid
3. logout
4. login as Laura

If you need true parallel Walid/Laura testing, use separate Chrome profiles and separate CDP/debugging ports.

## Default auth behavior

Default seed behavior writes QA users + QA auth accounts, then clears:
- `flutter.auth_session_v1`
- `flutter.currentUser`

That leaves the app in guest state so login can be tested normally.

## QA credentials

- Walid: `walid.qa@shareittoo.local` / `walid123`
- Laura: `laura.qa@shareittoo.local` / `laura123`
