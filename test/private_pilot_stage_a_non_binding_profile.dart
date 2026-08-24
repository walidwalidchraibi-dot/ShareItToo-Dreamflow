import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/config/private_pilot_config.dart';
import 'package:lendify/screens/private_pilot_checkout_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Stage-A shows price preview but cannot create a rental request',
      (tester) async {
    expect(PrivatePilotConfig.stageANonBindingPilotEnabled, isTrue);
    expect(PrivatePilotConfig.bindingCheckoutEnabled, isFalse);

    final item = buildTestItem(
      id: 'stage-a-item',
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

    expect(find.text('Unverbindliche Stage-A-Vorschau'), findsOneWidget);
    expect(find.text('Unverbindliche Preisvorschau'), findsOneWidget);
    expect(find.text('Simulierte Gesamtsumme'), findsOneWidget);
    expect(
      find.text(PrivatePilotConfig.blueOceanStageANonBindingNotice),
      findsOneWidget,
    );
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(
        find.textContaining('verbindliche Buchungsanfrage ab'), findsNothing);

    final buttonFinder = find.widgetWithText(
      FilledButton,
      'Mietanfrage im Stage-A-Pilot gesperrt',
    );
    await tester.scrollUntilVisible(
      buttonFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final button = tester.widget<FilledButton>(buttonFinder);
    expect(button.onPressed, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('rental_requests')!) as List, isEmpty);
  });
}
