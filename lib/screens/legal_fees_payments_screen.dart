import 'package:flutter/material.dart';
import 'package:lendify/screens/legal_detail_scaffold.dart';

class LegalFeesPaymentsScreen extends StatelessWidget {
  const LegalFeesPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDetailScaffold(
      title: 'Gebühren & Zahlungsbedingungen',
      intro:
          'Hier erklären wir transparent, welche Gebühren anfallen können, wie Zahlungen abgewickelt werden und wie Auszahlungen an Vermieter funktionieren.',
      sections: [
        LegalSectionCard(
          icon: Icons.percent_outlined,
          title: 'Plattformgebühr',
          badge: 'Beispiel',
          children: const [
            LegalParagraph('ShareItToo erhebt eine Plattformgebühr von 10 % auf den Gesamtbetrag einer Buchung.'),
            SizedBox(height: 10),
            LegalParagraph('Diese Gebühr wird automatisch bei der Buchung berechnet und dient dem Betrieb, Support und der Weiterentwicklung der Plattform.'),
          ],
        ),
        LegalSectionCard(
          icon: Icons.credit_card_outlined,
          title: 'Zahlungsabwicklung',
          children: const [
            LegalBullets(items: [
              'Zahlungen werden im Rahmen des Buchungsprozesses abgewickelt.',
              'Bei späterer Zahlungsintegration kann ein Zahlungsdienstleister eingesetzt werden.',
              'Transaktionen und Belege werden in der App nachvollziehbar bereitgestellt.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Auszahlungen an Vermieter',
          children: const [
            LegalBullets(items: [
              'Auszahlungen erfolgen gemäß deiner gewählten Auszahlungsmethode (z.B. SEPA oder Wallet).',
              'Auszahlungen können aus Sicherheits- oder Prüfgründen verzögert werden (z.B. bei Streitfällen).',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.receipt_long_outlined,
          title: 'Steuerliche Hinweise',
          children: const [
            LegalParagraph('Nutzer sind grundsätzlich selbst dafür verantwortlich, ihre Einnahmen aus Vermietungen steuerlich korrekt anzugeben. Diese Hinweise ersetzen keine Steuerberatung.'),
          ],
        ),
      ],
    );
  }
}
