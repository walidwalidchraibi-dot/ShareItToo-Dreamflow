import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/screens/privacy_info_screen.dart';

void main() {
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
