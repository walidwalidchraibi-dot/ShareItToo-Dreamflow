import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/screens/support_flow_screen.dart';

const _context = SupportFlowContext(
  itemTitle: 'Testartikel',
  itemId: 'listing-1',
  requestId: 'booking-1',
  bookingStatus: 'active',
  source: SupportFlowSource.bookingDetail,
  role: SupportFlowRole.renter,
);

Future<void> _pumpFlow(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    const MaterialApp(home: SupportFlowScreen(context: _context)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('immediate danger shows emergency guidance before categories',
      (tester) async {
    await _pumpFlow(tester);

    expect(
        find.byKey(const ValueKey('support_safety_question')), findsOneWidget);
    expect(find.text('Problem mit Übergabe'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('support_safety_answer_danger')),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('support_safety_guidance')), findsOneWidget);
    expect(find.textContaining('Polizei 110'), findsOneWidget);
    expect(find.textContaining('Rettungsdienst/Feuerwehr 112'), findsOneWidget);
    expect(find.textContaining('SIT ist kein Notfalldienst'), findsWidgets);
    expect(find.text('Problem mit Übergabe'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('support_safety_continue')));
    await tester.pumpAndSettle();

    expect(find.text('Problem mit Übergabe'), findsOneWidget);
  });

  testWidgets('no immediate danger continues without emergency guidance',
      (tester) async {
    await _pumpFlow(tester);

    await tester.tap(
      find.byKey(const ValueKey('support_safety_answer_no_danger')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support_safety_guidance')), findsNothing);
    expect(find.text('Problem mit Übergabe'), findsOneWidget);
  });

  test('safety evidence uses the backend-bound immutable versions', () {
    const triage = SupportSafetyTriage(
      immediateDanger: true,
      guidanceShown: true,
    );

    expect(triage.toMap(), {
      'version': 'sit_support_safety_triage_v1',
      'packetVersion': 'SIT_SUPPORT_PACKET_V1_2026-08-20',
      'guidanceVersion': 'T-003@1.0.0',
      'immediateDanger': true,
      'guidanceShown': true,
    });
  });
}
