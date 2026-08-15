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
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    ForegroundPushMessage? opened;
    addTearDown(messages.close);

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messengerKey,
        home: ForegroundPushHost(
          messengerKey: messengerKey,
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
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Neue Nachricht'), findsOneWidget);
    expect(find.text('Deine Buchung wurde aktualisiert.'), findsOneWidget);
    expect(find.text('Öffnen'), findsOneWidget);
    expect(find.bySemanticsLabel('Schließen'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('Öffnen'));
    await tester.pump();
    expect(opened, same(message));
  });

  testWidgets('uses the root navigator when hosted by MaterialApp.builder',
      (tester) async {
    final messages = StreamController<ForegroundPushMessage>.broadcast();
    final navigatorKey = GlobalKey<NavigatorState>();
    addTearDown(messages.close);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => ForegroundPushHost(
          navigatorKey: navigatorKey,
          messages: messages.stream,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: Text('Start')),
      ),
    );

    messages.add(const ForegroundPushMessage(
      title: 'Neue Nachricht',
      body: 'Du hast eine neue Nachricht.',
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Neue Nachricht'), findsOneWidget);
    expect(find.text('Du hast eine neue Nachricht.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
