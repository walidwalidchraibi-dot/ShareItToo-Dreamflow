import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/services/firebase_runtime.dart';
import 'package:lendify/widgets/foreground_push_host.dart';

void main() {
  testWidgets('shows a foreground notification and opens its safe action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final messages = StreamController<ForegroundPushMessage>.broadcast();
    ForegroundPushMessage? opened;
    addTearDown(messages.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForegroundPushHost(
          messages: messages.stream,
          onOpen: (message) => opened = message,
          child: const Scaffold(body: Text('Start')),
        ),
      ),
    );

    final message = ForegroundPushMessage(
      title: 'Neue Nachricht',
      body: 'Deine Buchung wurde aktualisiert.',
      actionUri: Uri.parse('shareittoo://booking/synthetic-booking'),
    );
    messages.add(message);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Neue Nachricht'), findsOneWidget);
    expect(find.text('Deine Buchung wurde aktualisiert.'), findsOneWidget);
    expect(find.text('Öffnen'), findsOneWidget);

    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    expect(opened, same(message));
  });
}
