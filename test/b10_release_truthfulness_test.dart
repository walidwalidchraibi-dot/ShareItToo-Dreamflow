import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/screens/language_screen.dart';
import 'package:lendify/screens/privacy_info_screen.dart';
import 'package:lendify/services/auth_service.dart';
import 'package:lendify/services/backend_http.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('language selector offers only maintained app translations',
      (tester) async {
    final localization = LocalizationController();
    await tester.pumpWidget(
      ChangeNotifierProvider<LocalizationController>.value(
        value: localization,
        child: const MaterialApp(home: LanguageScreen()),
      ),
    );

    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Español'), findsNothing);
    expect(find.text('Français'), findsNothing);
    expect(find.text('العربية'), findsNothing);
  });

  test('transient refresh failures preserve the stored session for retry', () {
    expect(
      AuthService.shouldClearStoredSessionAfterRefreshFailure(
        const BackendException(401, 'invalid_refresh_token'),
      ),
      isTrue,
    );
    expect(
      AuthService.shouldClearStoredSessionAfterRefreshFailure(
        const BackendException(503, 'service_unavailable'),
      ),
      isFalse,
    );
    expect(
      AuthService.shouldClearStoredSessionAfterRefreshFailure(
        const FormatException('temporary malformed response'),
      ),
      isFalse,
    );
  });

  test('release client contains no AI proxy secret and all helpers fail closed',
      () async {
    final source = await File('lib/openai/openai_config.dart').readAsString();

    expect(source, isNot(contains('OPENAI_PROXY_API_KEY')));
    expect(source, isNot(contains("'Authorization': 'Bearer")));
    expect(RegExp(r'if \(!isAvailable\)').allMatches(source).length, 5);
  });

  test('account security copy does not present demo 2FA as real protection',
      () async {
    final account =
        await File('lib/screens/account_settings_screen.dart').readAsString();
    final help =
        await File('lib/screens/help_center_screen.dart').readAsString();
    final profile =
        await File('lib/screens/profile_screen.dart').readAsString();
    final security =
        await File('lib/screens/security_screen.dart').readAsString();
    final notifications =
        await File('lib/screens/notifications_screen.dart').readAsString();

    expect(account, isNot(contains('TwoFactorAuthScreen')));
    expect(account, isNot(contains('VerificationIntroScreen')));
    expect(account, isNot(contains('VerificationScreen')));
    expect(account, contains('Noch nicht verfügbar'));
    expect(help, contains('Identitätsprüfung ist noch nicht verfügbar'));
    expect(help, contains('noch nicht verfügbar'));
    for (final source in [profile, security, notifications]) {
      expect(source, isNot(contains('VerificationIntroScreen')));
      expect(source, isNot(contains('VerificationScreen')));
    }
    expect(security, contains('Keine lokale Demo-Verifizierung'));
    expect(security, contains('!BackendConfig.enabled && !kReleaseMode'));
  });

  test('authenticated empty states do not present invented marketplace data',
      () async {
    final profile =
        await File('lib/screens/profile_screen.dart').readAsString();
    final profileHeader =
        await File('lib/widgets/profile_header_card.dart').readAsString();
    final publicProfile =
        await File('lib/screens/public_profile_screen.dart').readAsString();
    final ownProfile =
        await File('lib/screens/own_profile_screen.dart').readAsString();
    final ownerRequests =
        await File('lib/screens/owner_requests_screen.dart').readAsString();
    final messageThread =
        await File('lib/screens/message_thread_screen.dart').readAsString();
    final accountSettings =
        await File('lib/screens/account_settings_screen.dart').readAsString();
    final maps = await File('lib/services/maps_service.dart').readAsString();
    final appRoot = await File('lib/main.dart').readAsString();
    final navigation =
        await File('lib/navigation/main_navigation.dart').readAsString();
    final explore =
        await File('lib/screens/explore_screen.dart').readAsString();
    final backendHttp =
        await File('lib/services/backend_http.dart').readAsString();
    final securityScreen =
        await File('lib/screens/security_screen.dart').readAsString();

    expect(profile, isNot(contains('walid.placeholder')));
    expect(profile, isNot(contains('responseTimeMinutes: 42')));
    expect(profileHeader, isNot(contains('_estimatedBookings')));
    expect(profileHeader, isNot(contains('images.unsplash.com/photo')));
    expect(publicProfile, isNot(contains('_mockResponseTimeMin')));
    expect(publicProfile, isNot(contains('responseTimeMinutes')));
    expect(ownProfile, isNot(contains('responseTimeMin = 42')));
    expect(ownProfile, isNot(contains('DJI Mavic Air 2')));
    expect(ownProfile, isNot(contains('Makita Akkuschrauber')));
    expect(
        RegExp(r'if \(QaRuntimeService\.isEnabled\)')
            .allMatches(ownerRequests)
            .length,
        greaterThanOrEqualTo(2));
    expect(messageThread, contains('QaRuntimeService.isEnabled &&'));
    expect(messageThread, contains('_thread?.id == _translationDemoThreadId'));
    expect(accountSettings, contains('const SecurityScreen()'));
    expect(accountSettings, isNot(contains('const ChangePasswordScreen()')));
    expect(maps, isNot(contains('Musterstraße 1')));
    expect(appRoot,
        contains('final accessToken = await AuthService.accessToken()'));
    expect(appRoot, contains('if (BackendConfig.enabled || kReleaseMode)'));
    expect(navigation,
        contains('(BackendConfig.enabled || kReleaseMode || preview.isGuest)'));
    expect(
        explore, contains('_savedIds = hasRealSession ? saved : <String>{}'));
    expect(profileHeader, contains('if (user.isVerified)'));
    expect(
        backendHttp,
        contains(
            "'User-Agent': 'ShareItToo (\${defaultTargetPlatform.name})'"));
    expect(securityScreen, contains("rawName == 'Unbekanntes Gerät'"));
  });

  testWidgets(
      'privacy export remains usable with large text and keyboard focus',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: PrivacyInfoScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('privacy-data-export-button'));
    await tester.scrollUntilVisible(
      button,
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(button, findsOneWidget);
    expect(find.text('Meine Daten exportieren'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
