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
      'timezone': 'Europe/Berlin',
      'userFacingSummary': 'Wir benötigen noch eine konkrete Angabe von dir.',
      'appealAvailable': false,
      'closureReason': null,
      'createdAt': '2026-08-21T10:00:00.000Z',
      'updatedAt': '2026-08-21T11:00:00.000Z',
      'version': 2,
    };

Map<String, dynamic> _detail() => {
      'supportCase': _supportCase(),
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
    expect(
      find.text(
          'Bitte ergänze die genaue App-Version und den letzten Schritt.'),
      findsOneWidget,
    );
    expect(find.text('Fall eingegangen'), findsOneWidget);
    expect(find.text('Testmodus'), findsOneWidget);
    expect(find.text('case.transitioned'), findsNothing);
    expect(find.text('waiting_for_user'), findsNothing);
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
