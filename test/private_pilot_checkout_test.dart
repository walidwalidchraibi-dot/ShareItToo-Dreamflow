import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/config/private_pilot_config.dart';
import 'package:lendify/screens/private_pilot_checkout_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opening checkout creates nothing and declarations gate submit',
      (tester) async {
    final item = buildTestItem(
      id: 'pilot-item',
      ownerId: 'owner',
      pricePerDay: 40,
    );
    SharedPreferences.setMockInitialValues({
      'items': jsonEncode([item.toJson()]),
      'rental_requests': jsonEncode([]),
    });

    await tester.pumpWidget(
      MaterialApp(
        home: PrivatePilotCheckoutScreen(
          item: item,
          range: DateTimeRange(
            start: DateTime(2026, 9, 1),
            end: DateTime(2026, 9, 2),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gesamtpreis'), findsOneWidget);
    expect(find.text('44,00 €'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('rental_requests')!) as List, isEmpty);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Zahlungspflichtige Buchungsanfrage senden'),
      300,
      scrollable: scrollable,
    );
    final submit = tester.widget<FilledButton>(
      find.widgetWithText(
        FilledButton,
        'Zahlungspflichtige Buchungsanfrage senden',
      ),
    );
    expect(submit.onPressed, isNull);

    for (final wording in <String>[
      PrivatePilotConfig.bookingPrivateDeclaration,
      PrivatePilotConfig.bindingRequestDeclaration,
      PrivatePilotConfig.platformTermsDeclaration,
      PrivatePilotConfig.earlyPerformanceDeclaration,
      PrivatePilotConfig.withdrawalKnowledgeDeclaration,
    ].reversed) {
      final text = find.text(wording);
      await tester.scrollUntilVisible(
        text,
        -260,
        scrollable: scrollable,
      );
      await tester.tap(text);
      await tester.pump();
    }

    await tester.scrollUntilVisible(
      find.text('Zahlungspflichtige Buchungsanfrage senden'),
      300,
      scrollable: scrollable,
    );
    final enabledSubmit = tester.widget<FilledButton>(
      find.widgetWithText(
        FilledButton,
        'Zahlungspflichtige Buchungsanfrage senden',
      ),
    );
    expect(enabledSubmit.onPressed, isNotNull);
  });
}
