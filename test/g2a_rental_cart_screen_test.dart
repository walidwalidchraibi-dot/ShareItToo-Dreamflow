import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/screens/wishlists_screen.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Mietkorb exposes Gemerkt as non-binding and accessible',
      (tester) async {
    final item = buildTestItem(id: 'item-1', ownerId: 'owner-1');
    SharedPreferences.setMockInitialValues(<String, Object>{
      'items': jsonEncode(<Object>[item.toJson()]),
      'wishlists_meta_v1': jsonEncode(<Map<String, Object>>[
        <String, Object>{
          'id': 'wl_soon',
          'name': 'Demnächst benötigt',
          'system': true,
        },
        <String, Object>{
          'id': 'wl_later',
          'name': 'Für später',
          'system': true,
        },
        <String, Object>{
          'id': 'wl_again',
          'name': 'Wieder mieten',
          'system': true,
        },
      ]),
      'wishlist_assign_v1': '{}',
    });

    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ChangeNotifierProvider<LocalizationController>(
        create: (_) => LocalizationController(),
        child: const MaterialApp(home: RentalCartScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mietkorb'), findsOneWidget);
    expect(find.text('Gemerkt'), findsOneWidget);
    expect(
      find.textContaining('Unverbindlich gespeichert – keine Reservierung.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Gemerkt. Unverbindlich gespeichert. Keine Reservierung.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Projektkorb'), findsNothing);
    semantics.dispose();
  });
}
