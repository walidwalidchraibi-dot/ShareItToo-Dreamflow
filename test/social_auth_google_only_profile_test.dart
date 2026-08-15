import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/services/auth_service.dart';

const _googleOnlyProfileUnderTest = bool.fromEnvironment(
  'SIT_TEST_GOOGLE_ONLY_PROFILE',
  defaultValue: false,
);

void main() {
  test(
    'next consolidated social profile enables only Google',
    () {
      expect(_googleOnlyProfileUnderTest, isTrue);
      expect(
        AuthService.socialProviderEnabled(AuthSocialProvider.google),
        isTrue,
      );
      expect(
        AuthService.socialProviderEnabled(AuthSocialProvider.apple),
        isFalse,
      );
      expect(
        AuthService.socialProviderEnabled(AuthSocialProvider.facebook),
        isFalse,
      );
    },
    skip: !_googleOnlyProfileUnderTest,
  );
}
