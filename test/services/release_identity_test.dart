import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/services/release_identity.dart';

void main() {
  group('ReleaseIdentity', () {
    const validCommit = '399d867912afc217fde4ae815192667c50cd5175';

    test('accepts a complete internal release identity', () {
      expect(
        ReleaseIdentity.validationError(
          releaseMode: true,
          commit: validCommit,
          build: '2026080901',
          channel: 'internal',
          applicationId: 'com.shareittoo.app',
          apiBaseUrl: 'https://staging.shareittoo.com/api/v1',
        ),
        isNull,
      );
    });

    test('does not require release metadata in developer builds', () {
      expect(
        ReleaseIdentity.validationError(
          releaseMode: false,
          commit: '',
          build: '',
          channel: 'development',
          applicationId: 'com.shareittoo.app',
          apiBaseUrl: 'http://127.0.0.1:8080/api/v1',
        ),
        isNull,
      );
    });

    test('rejects incomplete commit, unsafe URL, and unknown channel', () {
      expect(
        ReleaseIdentity.validationError(
          releaseMode: true,
          commit: '399d867',
          build: '1',
          channel: 'preview',
          applicationId: 'com.example.app',
          apiBaseUrl: 'http://example.test/api/v1',
        ),
        isNotNull,
      );
    });
  });
}
