import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/screens/register_screen.dart';

void main() {
  testWidgets('registration shows three separate unchecked confirmations',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('Ich bestätige, dass ich mindestens 18 Jahre alt bin.'),
      findsOneWidget,
    );
    expect(find.text('Ich akzeptiere die AGB.'), findsOneWidget);
    expect(
      find.text('Ich akzeptiere die Datenschutzbestimmungen.'),
      findsOneWidget,
    );

    final confirmations = tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    );
    expect(confirmations, hasLength(3));
    expect(confirmations.every((checkbox) => checkbox.value == false), isTrue);
  });
}
