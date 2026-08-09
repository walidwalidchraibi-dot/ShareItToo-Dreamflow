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
}
