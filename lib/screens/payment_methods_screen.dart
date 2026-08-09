import 'package:flutter/material.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zahlungsmethoden')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 42,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Sicher über Stripe',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Eine Zahlungsmethode wird erst beim Bezahlen einer angenommenen Buchung direkt im sicheren Stripe-Checkout verwendet.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ShareItToo speichert keine vollständigen Karten-, Sicherheitscode- oder Kontodaten in der App.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'So funktioniert es',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  SizedBox(height: 10),
                  Text('1. Der Vermieter nimmt deine Buchungsanfrage an.'),
                  Text('2. Du öffnest in der Buchung „Zahlung & Kaution“.'),
                  Text('3. Du prüfst Betrag und Gebühr.'),
                  Text(
                      '4. Die Eingabe der Zahlungsdaten erfolgt ausschließlich bei Stripe.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
