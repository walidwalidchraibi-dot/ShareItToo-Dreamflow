import 'dart:ui' show SemanticsAction, SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/navigation/main_nav_controller.dart';
import 'package:lendify/screens/login_screen.dart';
import 'package:lendify/services/developer_preview_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'login fields stay named and password visibility stays a separate action',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MainNavController()),
            ChangeNotifierProvider(
              create: (_) => DeveloperPreviewController(
                initialState: DeveloperUserState.loggedOut,
              ),
            ),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in ['E-Mail', 'Passwort']) {
        final field = find.bySemanticsLabel(label);
        expect(field, findsAtLeastNWidgets(1));
        final node = tester.getSemantics(field.last);
        expect(node.hasFlag(SemanticsFlag.isTextField), isTrue);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.focus),
          isTrue,
        );
      }

      final visibility = find.bySemanticsLabel('Passwort anzeigen');
      expect(visibility, findsAtLeastNWidgets(1));
      expect(
        tester.getSemantics(visibility.last).hasFlag(SemanticsFlag.isButton),
        isTrue,
      );
      semantics.dispose();
    },
  );
}
