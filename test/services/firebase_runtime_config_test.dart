import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/services/firebase_runtime.dart';

void main() {
  group('FirebaseRuntimeConfig', () {
    test('requires all four platform identifiers', () {
      expect(
        FirebaseRuntimeConfig.hasCompleteValues(
          project: 'shareittoo-staging',
          sender: '123456789',
          appId: '1:123456789:android:abc',
          apiKey: 'api-key',
        ),
        isTrue,
      );
      expect(
        FirebaseRuntimeConfig.hasCompleteValues(
          project: 'shareittoo-staging',
          sender: '123456789',
          appId: '',
          apiKey: 'api-key',
        ),
        isFalse,
      );
    });

    test('stays safely disabled when no build-time Firebase values exist', () {
      expect(FirebaseRuntimeConfig.currentOptions, isNull);
    });
  });

  group('waitForApplePushToken', () {
    test('returns an immediately available APNs token', () async {
      var reads = 0;
      final token = await waitForApplePushToken(
        readToken: () async {
          reads += 1;
          return '  apns-token  ';
        },
        delay: (_) async {},
      );

      expect(token, 'apns-token');
      expect(reads, 1);
    });

    test('waits until APNs has produced a token', () async {
      var reads = 0;
      var delays = 0;
      final token = await waitForApplePushToken(
        readToken: () async {
          reads += 1;
          return reads < 3 ? null : 'apns-token';
        },
        delay: (_) async {
          delays += 1;
        },
        maxAttempts: 4,
      );

      expect(token, 'apns-token');
      expect(reads, 3);
      expect(delays, 2);
    });

    test('fails closed when APNs never produces a token', () async {
      var reads = 0;
      final token = await waitForApplePushToken(
        readToken: () async {
          reads += 1;
          return null;
        },
        delay: (_) async {},
        maxAttempts: 3,
      );

      expect(token, isNull);
      expect(reads, 3);
    });
  });

  group('foreground push message', () {
    test('normalizes visible copy and keeps a safe action URI', () {
      final message = parseForegroundPushMessage(
        title: '  Neue Nachricht  ',
        body: '  Deine Buchung wurde aktualisiert.  ',
        data: {'actionUrl': 'shareittoo://booking/synthetic-booking'},
      );

      expect(message, isNotNull);
      expect(message!.title, 'Neue Nachricht');
      expect(message.body, 'Deine Buchung wurde aktualisiert.');
      expect(
        message.actionUri,
        Uri.parse('shareittoo://booking/synthetic-booking'),
      );
    });

    test('drops empty notifications and invalid action URIs', () {
      expect(parseForegroundPushMessage(), isNull);

      final message = parseForegroundPushMessage(
        body: 'Hinweis',
        data: {'actionUrl': 'https://user:password@example.com/private'},
      );
      expect(message, isNotNull);
      expect(message!.title, 'ShareItToo');
      expect(message.actionUri, isNull);

      final unsupported = parseForegroundPushMessage(
        body: 'Hinweis',
        data: {'actionUrl': 'javascript:alert(1)'},
      );
      expect(unsupported!.actionUri, isNull);
    });
  });
}
