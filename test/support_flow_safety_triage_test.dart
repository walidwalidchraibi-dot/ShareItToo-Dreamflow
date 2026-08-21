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

Map<String, dynamic> _canonicalCase() => {
      'id': 'case-1',
      'caseNumber': 'SIT-ABCDEFGHJKLM',
      'status': 'received',
      'nextUpdateAt': '2026-08-21T16:00:00.000Z',
      'nextUpdateDisplay': '21.08.2026, 18:00',
      'timezone': 'Europe/Berlin',
      'operatingMode': 'simulation',
    };

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

Future<void> _selectTechnicalSubmission(WidgetTester tester) async {
  await tester
      .tap(find.byKey(const ValueKey('support_safety_answer_no_danger')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('support_issue_scope_single')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Technisches Problem'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('App lädt nicht'));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.byType(TextField), 'Die App bleibt im Ladezustand.');
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

    expect(find.byKey(const ValueKey('support_issue_scope_question')),
        findsOneWidget);
    expect(find.text('Problem mit Übergabe'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('support_issue_scope_single')));
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
    expect(find.byKey(const ValueKey('support_issue_scope_question')),
        findsOneWidget);
    expect(find.text('Problem mit Übergabe'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('support_issue_scope_single')));
    await tester.pumpAndSettle();
    expect(find.text('Problem mit Übergabe'), findsOneWidget);
  });

  testWidgets('multiple independent problems require separation first',
      (tester) async {
    await _pumpFlow(tester);
    await tester.tap(
      find.byKey(const ValueKey('support_safety_answer_no_danger')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('support_issue_scope_multiple')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support_issue_separation_guidance')),
        findsOneWidget);
    expect(find.text('Problem mit Übergabe'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('support_issue_separation_continue')),
    );
    await tester.pumpAndSettle();
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

  test('intake maps user categories and linked context to backend taxonomy',
      () {
    const result = SupportFlowResult(
      mainCategory: 'handover',
      subCategory: 'QR-Code funktioniert nicht',
      userDescription: 'Der Code wird in der App nicht angenommen.',
      context: _context,
      safetyTriage: SupportSafetyTriage(
        immediateDanger: false,
        guidanceShown: false,
      ),
      issueScope: SupportIssueScope(
        singleIssueConfirmed: true,
        separationGuidanceShown: false,
      ),
    );

    expect(result.toBackendInput(), {
      'caseType': 'active_handover',
      'caseSubType': 'qr_or_code_failure',
      'summary':
          'Problem mit Übergabe: QR-Code funktioniert nicht. Der Code wird in der App nicht angenommen.',
      'immediateDanger': false,
      'safetyTriage': {
        'version': 'sit_support_safety_triage_v1',
        'packetVersion': 'SIT_SUPPORT_PACKET_V1_2026-08-20',
        'guidanceVersion': 'T-003@1.0.0',
        'immediateDanger': false,
        'guidanceShown': false,
      },
      'issueScope': {
        'version': 'sit_support_single_issue_scope_v1',
        'singleIssueConfirmed': true,
        'separationGuidanceShown': false,
      },
      'linkedBookingId': 'booking-1',
      'linkedListingId': 'listing-1',
    });
  });

  test('immediate danger overrides the normal category route', () {
    const result = SupportFlowResult(
      mainCategory: 'technical',
      subCategory: 'App lädt nicht',
      userDescription:
          'Ich bin unsicher und brauche zuerst Sicherheitshinweise.',
      context: _context,
      safetyTriage: SupportSafetyTriage(
        immediateDanger: true,
        guidanceShown: true,
      ),
      issueScope: SupportIssueScope(
        singleIssueConfirmed: true,
        separationGuidanceShown: true,
      ),
    );

    final intake = result.toBackendInput();
    expect(intake['caseType'], 'trust_safety');
    expect(intake['caseSubType'], 'immediate_physical_danger');
  });

  test('canonical receipt rejects unconfirmed or non-simulation responses', () {
    const result = SupportFlowResult(
      mainCategory: 'technical',
      subCategory: 'App lädt nicht',
      userDescription: '',
      context: _context,
      safetyTriage: SupportSafetyTriage(
        immediateDanger: false,
        guidanceShown: false,
      ),
      issueScope: SupportIssueScope(
        singleIssueConfirmed: true,
        separationGuidanceShown: false,
      ),
    );

    expect(
      () => result.withCanonicalCase({
        ..._canonicalCase(),
        'operatingMode': 'live',
      }),
      throwsFormatException,
    );
    expect(
      () => result.withCanonicalCase({
        ..._canonicalCase(),
        'caseNumber': 'SIT-not-canonical',
      }),
      throwsFormatException,
    );
    final confirmed = result.withCanonicalCase(_canonicalCase());
    expect(confirmed.canonicalCaseNumber, 'SIT-ABCDEFGHJKLM');
    expect(confirmed.canonicalReceiptMessage, contains('Status: Eingegangen'));
    expect(
      confirmed.canonicalReceiptMessage,
      contains('21.08.2026, 18:00 Uhr (Europe/Berlin)'),
    );
    expect(
        confirmed.canonicalReceiptMessage, contains('keine externe Nachricht'));
  });

  testWidgets('submission creates a canonical case before returning a result',
      (tester) async {
    SupportFlowResult? captured;
    Map<String, dynamic>? capturedIntake;
    String? capturedKey;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => FilledButton(
                onPressed: () async {
                  captured =
                      await Navigator.of(context).push<SupportFlowResult>(
                    MaterialPageRoute(
                      builder: (_) => SupportFlowScreen(
                        context: _context,
                        submitter: (intake, idempotencyKey) async {
                          capturedIntake = intake;
                          capturedKey = idempotencyKey;
                          return _canonicalCase();
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Support öffnen'),
              )),
    ));
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.tap(find.text('Support öffnen'));
    await tester.pumpAndSettle();
    await _selectTechnicalSubmission(tester);
    await tester.tap(find.text('An Support schicken'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('support_case_receipt')), findsOneWidget);
    expect(find.textContaining('SIT-ABCDEFGHJKLM'), findsWidgets);
    expect(capturedIntake?['caseType'], 'general_help');
    expect(capturedIntake?['caseSubType'], 'app_error_or_display');
    expect(capturedKey, startsWith('support_intake_'));
    expect(captured, isNull);

    await tester
        .tap(find.byKey(const ValueKey('support_case_receipt_continue')));
    await tester.pumpAndSettle();
    expect(captured?.canonicalCaseNumber, 'SIT-ABCDEFGHJKLM');
  });

  testWidgets('failed submission stays open and retry reuses the same key',
      (tester) async {
    final keys = <String>[];
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      home: SupportFlowScreen(
        context: _context,
        submitter: (intake, idempotencyKey) async {
          keys.add(idempotencyKey);
          attempts += 1;
          if (attempts == 1) throw StateError('controlled_failure');
          return _canonicalCase();
        },
      ),
    ));
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _selectTechnicalSubmission(tester);
    await tester.tap(find.text('An Support schicken'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('wurde nicht bestätigt'), findsOneWidget);
    expect(find.byKey(const ValueKey('support_case_receipt')), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('An Support schicken'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('support_case_receipt')), findsOneWidget);
    expect(keys, hasLength(2));
    expect(keys[1], keys[0]);
  });
}
