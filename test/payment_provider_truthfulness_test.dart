import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/screens/payment_methods_screen.dart';
import 'package:lendify/screens/stripe_payout_account_screen.dart';

void main() {
  testWidgets('unavailable provider never presents Stripe or a payment action',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PaymentMethodsScreen(
        loadCapabilities: () async => const {
          'provider': null,
          'providerBacked': false,
          'checkoutAvailable': false,
          'mode': 'unavailable',
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Noch nicht freigeschaltet'), findsOneWidget);
    expect(
      find.textContaining('kein echter Marketplace-Zahlungsdienstleister'),
      findsOneWidget,
    );
    expect(find.textContaining('Stripe'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('provider test mode is explicit and promises no real money',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PaymentMethodsScreen(
        loadCapabilities: () async => const {
          'provider': 'stripe',
          'providerBacked': true,
          'checkoutAvailable': true,
          'mode': 'test',
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Zahlungstest verfügbar'), findsOneWidget);
    expect(find.textContaining('kein echtes Geld'), findsOneWidget);
    expect(find.text('Sicher über Stripe'), findsNothing);
  });

  testWidgets('live provider may be named only after server capability',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PaymentMethodsScreen(
        loadCapabilities: () async => const {
          'provider': 'stripe',
          'providerBacked': true,
          'checkoutAvailable': true,
          'mode': 'live',
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sicher über Stripe'), findsOneWidget);
  });

  testWidgets('unavailable payout provider shows no onboarding action',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StripePayoutAccountScreen(
        loadCapabilities: () async => const {
          'provider': null,
          'providerBacked': false,
          'payoutOnboardingAvailable': false,
          'mode': 'unavailable',
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text('Auszahlungen noch nicht freigeschaltet'),
      findsOneWidget,
    );
    expect(find.textContaining('Stripe'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('payout test mode is explicit and does not claim real money',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StripePayoutAccountScreen(
        loadCapabilities: () async => const {
          'provider': 'stripe',
          'providerBacked': true,
          'payoutOnboardingAvailable': true,
          'mode': 'test',
        },
        loadConnectStatus: () async => const {
          'exists': false,
          'ready': false,
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Auszahlungstest verfügbar'), findsOneWidget);
    expect(find.textContaining('Es fließt kein echtes Geld'), findsOneWidget);
    expect(find.text('Test-Onboarding öffnen'), findsOneWidget);
    expect(find.text('Sicher bei Stripe fortfahren'), findsNothing);
  });
}
