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
}
