import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/services/app_link_service.dart';

void main() {
  test('parses secure booking and chat links', () {
    final booking = AppLinkParser.parse(
      Uri.parse('https://shareittoo.com/api/v1/open/booking/booking-123'),
    );
    expect(booking?.kind, AppLinkKind.booking);
    expect(booking?.id, 'booking-123');

    final chat = AppLinkParser.parse(
      Uri.parse('shareittoo://chat/thread_456'),
    );
    expect(chat?.kind, AppLinkKind.chat);
    expect(chat?.id, 'thread_456');

    final payment = AppLinkParser.parse(
      Uri.parse(
          'https://shareittoo.com/api/v1/open/payment/booking-123?result=success'),
    );
    expect(payment?.kind, AppLinkKind.paymentReturn);
    expect(payment?.id, 'booking-123');
  });

  test('builds and parses canonical listing and profile links', () {
    final listingUri = AppLinkBuilder.listing('item-123');
    expect(
      listingUri.toString(),
      'https://shareittoo.com/api/v1/open/listing/item-123',
    );
    final listing = AppLinkParser.parse(listingUri);
    expect(listing?.kind, AppLinkKind.listing);
    expect(listing?.id, 'item-123');

    final profileUri = AppLinkBuilder.profile('user_456');
    expect(
      profileUri.toString(),
      'https://shareittoo.com/api/v1/open/profile/user_456',
    );
    final profile = AppLinkParser.parse(profileUri);
    expect(profile?.kind, AppLinkKind.profile);
    expect(profile?.id, 'user_456');
  });

  test('refuses unsafe public link identifiers', () {
    expect(() => AppLinkBuilder.listing('not/safe'), throwsArgumentError);
    expect(() => AppLinkBuilder.profile(''), throwsArgumentError);
  });

  test('accepts auth actions only with a token', () {
    final valid = AppLinkParser.parse(
      Uri.parse(
        'https://shareittoo.com/api/v1/auth/email-verification/confirm?token=secret',
      ),
    );
    expect(valid?.kind, AppLinkKind.emailVerification);

    expect(
      AppLinkParser.parse(
        Uri.parse(
          'https://shareittoo.com/api/v1/auth/email-verification/confirm',
        ),
      ),
      isNull,
    );
  });

  test('rejects foreign hosts, credentials and unsafe identifiers', () {
    expect(
      AppLinkParser.parse(
        Uri.parse('https://attacker.example/open/booking/booking-123'),
      ),
      isNull,
    );
    expect(
      AppLinkParser.parse(
        Uri.parse('https://user:pass@shareittoo.com/open/booking/booking-123'),
      ),
      isNull,
    );
    expect(
      AppLinkParser.parse(
        Uri.parse('shareittoo://booking/not%2Fsafe'),
      ),
      isNull,
    );
  });

  test('accepts only the bounded custom-scheme Crashlytics diagnostic link',
      () {
    final diagnostic = AppLinkParser.parse(
      Uri.parse('shareittoo://qa/crashlytics/b11-android-2026081027'),
    );
    expect(diagnostic?.kind, AppLinkKind.crashDiagnostic);
    expect(diagnostic?.id, 'b11-android-2026081027');

    expect(
      AppLinkParser.parse(
        Uri.parse(
            'https://staging.shareittoo.com/qa/crashlytics/b11-android-2026081027'),
      ),
      isNull,
    );
    expect(
      AppLinkParser.parse(Uri.parse('shareittoo://qa/crashlytics/unsafe%2Fid')),
      isNull,
    );
  });

  test('keeps one pending target and suppresses duplicate push ingress', () {
    var now = DateTime.utc(2026, 8, 11, 8);
    final inbox = AppLinkTargetInbox(now: () => now);
    const raw =
        'https://staging.shareittoo.com/api/v1/open/booking/booking-123';

    expect(inbox.accept(raw), isTrue);
    expect(inbox.takePending()?.id, 'booking-123');

    now = now.add(const Duration(seconds: 1));
    expect(inbox.accept(raw), isFalse);
    expect(inbox.takePending(), isNull);

    now = now.add(AppLinkTargetInbox.duplicateWindow);
    expect(inbox.accept(raw), isTrue);
    expect(inbox.takePending()?.kind, AppLinkKind.booking);
  });

  test('does not let an invalid link replace a valid pending target', () {
    final inbox = AppLinkTargetInbox();
    expect(
      inbox.accept('shareittoo://chat/thread_456'),
      isTrue,
    );
    expect(
      inbox.accept('https://attacker.example/open/booking/booking-123'),
      isFalse,
    );
    expect(inbox.takePending()?.id, 'thread_456');
  });

  testWidgets('replays a pending Android notification link when app resumes',
      (tester) async {
    final controller = AppLinkController(
      takeNativePendingActionLink: () async => Uri.parse(
        'https://staging.shareittoo.com/api/v1/open/booking/booking-resumed',
      ),
    );
    addTearDown(controller.dispose);
    controller.initialize();

    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();

    final target = controller.takePending();
    expect(target?.kind, AppLinkKind.booking);
    expect(target?.id, 'booking-resumed');
  });
}
