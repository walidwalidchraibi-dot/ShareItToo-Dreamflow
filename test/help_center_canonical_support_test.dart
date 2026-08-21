import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/screens/help_center_screen.dart';

Map<String, dynamic> _canonicalCase() => {
      'id': 'case-help-center',
      'caseNumber': 'SIT-ABCDEFGHJKLM',
      'status': 'received',
      'nextUpdateAt': '2026-08-21T16:00:00.000Z',
      'nextUpdateDisplay': '21.08.2026, 18:00',
      'timezone': 'Europe/Berlin',
      'operatingMode': 'simulation',
    };

void main() {
  testWidgets('help center creates a canonical case instead of local feedback',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? capturedIntake;
    await tester.pumpWidget(MaterialApp(
      home: HelpCenterScreen(
        sessionCheck: () async => true,
        submitter: (intake, idempotencyKey) async {
          capturedIntake = intake;
          return _canonicalCase();
        },
      ),
    ));

    final openSupport = find.text('Support-Fall sicher melden');
    await tester.scrollUntilVisible(
      openSupport,
      600,
      scrollable: find.byType(Scrollable).first,
    );
    const description =
        'Die App bleibt nach dem Öffnen dauerhaft im Ladezustand.';
    await tester.enterText(find.byType(TextField).last, description);
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(of: openSupport, matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(openSupport);
    await tester.pumpAndSettle();

    expect(
        find.text('Bist du gerade in unmittelbarer Gefahr?'), findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('support_safety_answer_no_danger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('support_issue_scope_single')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Technisches Problem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('App lädt nicht'));
    await tester.pumpAndSettle();

    final descriptionField = tester.widget<TextField>(find.byType(TextField));
    expect(descriptionField.controller?.text, description);
    await tester.tap(find.text('An Support schicken'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('support_case_receipt')), findsOneWidget);
    expect(capturedIntake?['caseType'], 'general_help');
    expect(capturedIntake?['summary'], contains(description));
    expect(capturedIntake?.containsKey('linkedBookingId'), isFalse);
    expect(capturedIntake?.containsKey('linkedListingId'), isFalse);

    await tester
        .tap(find.byKey(const ValueKey('support_case_receipt_continue')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      isEmpty,
    );
  });

  testWidgets('help center keeps guest text and requires an account',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: HelpCenterScreen(sessionCheck: () async => false),
    ));
    final openSupport = find.text('Support-Fall sicher melden');
    await tester.scrollUntilVisible(
      openSupport,
      600,
      scrollable: find.byType(Scrollable).first,
    );
    const description =
        'Ich brauche Hilfe und möchte mein Anliegen nach der Anmeldung senden.';
    await tester.enterText(find.byType(TextField).last, description);
    await tester.pump();
    await tester.tap(openSupport);
    await tester.pumpAndSettle();

    expect(find.text('Support-Fall melden'), findsOneWidget);
    expect(find.textContaining('Serverbestätigte Case-ID'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      description,
    );
  });

  test('profile help tile opens the real help center', () {
    final source = File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(
      source,
      contains(
        "case 'Hilfe-Center':\n          case 'Help Center':\n            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpCenterScreen()));",
      ),
    );
  });
}
