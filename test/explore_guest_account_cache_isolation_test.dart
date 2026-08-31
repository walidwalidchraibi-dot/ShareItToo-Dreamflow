import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/navigation/main_nav_controller.dart';
import 'package:lendify/screens/explore_screen.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/services/qa_runtime_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    QaRuntimeService.reset();
  });

  testWidgets(
    'guest catalog ignores and preserves a corrupt local account cache',
    (tester) async {
      const corruptUsers = '[{"id":"broken-local-account"}]';
      final listing = Item.fromJson(<String, dynamic>{
        ...buildTestItem(
          id: 'guest-visible-listing',
          ownerId: 'remote-owner',
          title: 'Guest visible listing',
        ).toJson(),
        'photos': const <String>[],
      });
      SharedPreferences.setMockInitialValues(<String, Object>{
        'items': jsonEncode(<Object>[listing.toJson()]),
        'users': corruptUsers,
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<LocalizationController>(
              create: (_) => LocalizationController(),
            ),
            ChangeNotifierProvider<MainNavController>(
              create: (_) => MainNavController(),
            ),
          ],
          child: const MaterialApp(home: ExploreScreen()),
        ),
      );
      for (var attempt = 0;
          attempt < 20 && find.text('Guest visible listing').evaluate().isEmpty;
          attempt += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Guest visible listing'), findsWidgets);
      expect(find.text('Anzeigen konnten nicht geladen werden.'), findsNothing);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('users'), corruptUsers);
    },
  );
}
