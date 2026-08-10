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
}
