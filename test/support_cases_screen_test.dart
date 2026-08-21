import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/screens/help_center_screen.dart';
import 'package:lendify/screens/support_cases_screen.dart';

Map<String, dynamic> _supportCase({
  String status = 'waiting_for_user',
}) =>
    {
      'id': '11111111-1111-4111-8111-111111111111',
      'caseNumber': 'SIT-ABCDEFGHJKLM',
      'caseType': 'general_help',
      'caseSubType': 'app_error_or_display',
      'status': status,
      'priority': 'p3',
      'sourceChannel': 'app',
      'operatingMode': 'simulation',
      'locale': 'de-DE',
      'waitingOn': status == 'waiting_for_user' ? 'reporter' : 'support_owner',
      'nextAction':
          'Bitte ergänze die genaue App-Version und den letzten Schritt.',
      'nextUpdateAt': '2026-08-22T10:00:00.000Z',
      'nextUpdateDisplay': '22.08.2026, 12:00',
      'userActionDueAt':
          status == 'waiting_for_user' ? '2026-08-23T18:00:00.000Z' : null,
      'userActionDueDisplay':
          status == 'waiting_for_user' ? '23.08.2026, 20:00' : null,
      'timezone': 'Europe/Berlin',
      'userFacingSummary': 'Wir benötigen noch eine konkrete Angabe von dir.',
      'finalDecisionAvailable': false,
      'appealAvailable': false,
      'closureReason': null,
      'createdAt': '2026-08-21T10:00:00.000Z',
      'updatedAt': '2026-08-21T11:00:00.000Z',
      'version': 2,
    };

Map<String, dynamic> _detail() => {
      'supportCase': _supportCase(),
      'finalDecision': null,
      'events': [
        {
          'id': 'event-created',
          'eventType': 'case.created',
          'fromStatus': null,
          'toStatus': 'received',
          'createdAt': '2026-08-21T10:00:00.000Z',
        },
        {
          'id': 'event-waiting',
          'eventType': 'case.transitioned',
          'fromStatus': 'acknowledged',
          'toStatus': 'waiting_for_user',
          'createdAt': '2026-08-21T11:00:00.000Z',
        },
      ],
    };

void main() {
  testWidgets('case list and detail show only simple user-facing status text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SupportCasesScreen(
        listLoader: () async => [_supportCase()],
        detailLoader: (_) async => _detail(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('SIT-ABCDEFGHJKLM'), findsOneWidget);
    expect(find.text('Antwort von dir nötig'), findsOneWidget);
    expect(find.text('waiting_for_user'), findsNothing);
    expect(find.text('app_error_or_display'), findsNothing);
    await tester.tap(find.text('SIT-ABCDEFGHJKLM'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support_user_action')), findsOneWidget);
    expect(find.text('Antwort bis: 23.08.2026, 20:00'), findsOneWidget);
    expect(find.text('Nächstes Update: 22.08.2026, 12:00'), findsOneWidget);
    expect(
      find.text(
          'Bitte ergänze die genaue App-Version und den letzten Schritt.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Fall eingegangen'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Fall eingegangen'), findsOneWidget);
    expect(find.text('Testmodus'), findsOneWidget);
    expect(find.text('case.transitioned'), findsNothing);
    expect(find.text('waiting_for_user'), findsNothing);
  });

  testWidgets(
      'published final decision shows the five approved user fields only',
      (tester) async {
    final resolved = {
      ..._supportCase(status: 'resolved'),
      'waitingOn': 'none',
      'nextAction': null,
      'nextUpdateAt': null,
      'nextUpdateDisplay': null,
      'finalDecisionAvailable': true,
      'userFacingSummary': 'Die interne Prüfung wurde abgeschlossen.',
    };
    final finalDecision = {
      'decision': 'Die interne Prüfung ist abgeschlossen.',
      'effect': 'Dein Konto und deine Zahlung bleiben unverändert.',
      'reason': 'Der bestätigte technische Stand wurde geprüft.',
      'implementationResult':
          'Das bestätigte Ergebnis wurde im internen Testfall dokumentiert.',
      'redressRoute': 'Eine menschliche Überprüfung kann angefordert werden.',
      'implementedAt': '2026-08-21T14:30:00.000Z',
      'implementedDisplay': '21.08.2026, 16:30',
      'communicatedAt': '2026-08-21T14:35:00.000Z',
      'timezone': 'Europe/Berlin',
      'decisionCode': 'support.internal_code_must_not_render',
      'implementationReference': 'internal-ledger-reference',
    };
    await tester.pumpWidget(MaterialApp(
      home: SupportCasesScreen(
        listLoader: () async => [resolved],
        detailLoader: (_) async => {
          'supportCase': resolved,
          'finalDecision': finalDecision,
          'events': const [],
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIT-ABCDEFGHJKLM'));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('support_final_decision')), findsOneWidget);
    for (final text in [
      'Die interne Prüfung ist abgeschlossen.',
      'Dein Konto und deine Zahlung bleiben unverändert.',
      'Der bestätigte technische Stand wurde geprüft.',
      'Das bestätigte Ergebnis wurde im internen Testfall dokumentiert.',
      'Eine menschliche Überprüfung kann angefordert werden.',
    ]) {
      await tester.scrollUntilVisible(
        find.text(text),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(text), findsWidgets);
    }
    expect(find.text('support.internal_code_must_not_render'), findsNothing);
    expect(find.text('internal-ledger-reference'), findsNothing);
  });

  testWidgets('incomplete published final decision fails closed',
      (tester) async {
    final resolved = {
      ..._supportCase(status: 'resolved'),
      'waitingOn': 'none',
      'nextAction': null,
      'nextUpdateAt': null,
      'nextUpdateDisplay': null,
      'finalDecisionAvailable': true,
    };
    await tester.pumpWidget(MaterialApp(
      home: SupportCasesScreen(
        listLoader: () async => [resolved],
        detailLoader: (_) async => {
          'supportCase': resolved,
          'finalDecision': {
            'decision': 'Die interne Prüfung ist abgeschlossen.',
            'reason': 'Der bestätigte technische Stand wurde geprüft.',
            'implementationResult': 'Das Ergebnis wurde dokumentiert.',
            'redressRoute': 'Menschliche Überprüfung ist möglich.',
            'implementedAt': '2026-08-21T14:30:00.000Z',
            'implementedDisplay': '21.08.2026, 16:30',
            'communicatedAt': '2026-08-21T14:35:00.000Z',
            'timezone': 'Europe/Berlin',
          },
          'events': const [],
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIT-ABCDEFGHJKLM'));
    await tester.pumpAndSettle();

    expect(
      find.text('Support-Fälle konnten nicht sicher geladen werden.'),
      findsOneWidget,
    );
  });

  testWidgets('unknown server status fails closed without exposing its code',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SupportCasesScreen(
        listLoader: () async => [_supportCase(status: 'paused_internal')],
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text('Support-Fälle konnten nicht sicher geladen werden.'),
      findsOneWidget,
    );
    expect(find.text('paused_internal'), findsNothing);
  });

  testWidgets('detail identity mismatch fails closed', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SupportCasesScreen(
        listLoader: () async => [_supportCase()],
        detailLoader: (_) async => {
          ..._detail(),
          'supportCase': {
            ..._supportCase(),
            'id': '22222222-2222-4222-8222-222222222222',
          },
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIT-ABCDEFGHJKLM'));
    await tester.pumpAndSettle();

    expect(
      find.text('Support-Fälle konnten nicht sicher geladen werden.'),
      findsOneWidget,
    );
  });

  testWidgets('active case without next update fails closed', (tester) async {
    final incomplete = _supportCase()..remove('nextUpdateDisplay');
    await tester.pumpWidget(MaterialApp(
      home: SupportCasesScreen(
        listLoader: () async => [incomplete],
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text('Support-Fälle konnten nicht sicher geladen werden.'),
      findsOneWidget,
    );
  });

  testWidgets('waiting case without a confirmed user deadline fails closed',
      (tester) async {
    final incomplete = _supportCase()..remove('userActionDueDisplay');
    await tester.pumpWidget(MaterialApp(
      home: SupportCasesScreen(
        listLoader: () async => [incomplete],
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text('Support-Fälle konnten nicht sicher geladen werden.'),
      findsOneWidget,
    );
    expect(find.textContaining('Antwort bis:'), findsNothing);
  });

  testWidgets('support cases remain usable at 200 percent text size',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
        ),
        child: child!,
      ),
      home: SupportCasesScreen(
        listLoader: () async => [_supportCase()],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('SIT-ABCDEFGHJKLM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('help center opens the authenticated case list', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: HelpCenterScreen(
        sessionCheck: () async => true,
        caseListLoader: () async => [],
      ),
    ));
    final openCases = find.byKey(const ValueKey('support_cases_open'));
    await tester.scrollUntilVisible(
      openCases,
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(openCases);
    await tester.pumpAndSettle();

    expect(find.text('Meine Support-Fälle'), findsOneWidget);
    expect(find.text('Noch keine Support-Fälle'), findsOneWidget);
  });
}
