import 'package:flutter/material.dart';
import 'package:lendify/screens/legal_detail_scaffold.dart';

class LegalFeesPaymentsScreen extends StatelessWidget {
  const LegalFeesPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDetailScaffold(
      title: 'Gebühren & Zahlungsbedingungen',
      intro:
          'Hier erklären wir transparent das geplante Gebührenmodell und den aktuellen technischen Stand. Im aktuellen Store-Kandidaten werden keine Echtgeldzahlungen oder Auszahlungen ausgeführt.',
      sections: [
        LegalSectionCard(
          icon: Icons.percent_outlined,
          title: 'Plattformgebühr',
          badge: 'Startmodell',
          children: const [
            LegalParagraph(
              'ShareItToo berechnet im vorgesehenen Startmodell eine Plattformgebühr von 10 % auf den Mietbetrag einer Buchung.',
            ),
            SizedBox(height: 10),
            LegalParagraph(
              'Der aktuelle interne Store-Kandidat zeigt diese Berechnung transparent an, belastet aber kein echtes Zahlungsmittel. Vor Aktivierung wird das Gebührenmodell verbindlich freigegeben.',
            ),
          ],
        ),
        LegalSectionCard(
          icon: Icons.credit_card_outlined,
          title: 'Zahlungsabwicklung',
          children: const [
            LegalBullets(items: [
              'Der aktuelle Store-Kandidat führt keine Echtgeldzahlung aus.',
              'Bei einer späteren Aktivierung wird ein gesondert geprüfter Zahlungsdienstleister eingesetzt.',
              'Preis, Gebühr und Zahlungsstatus werden vor einer verbindlichen Zahlung transparent angezeigt.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Auszahlungen an Vermieter',
          children: const [
            LegalBullets(items: [
              'Im aktuellen Store-Kandidaten erfolgen keine Auszahlungen.',
              'Vor einer späteren Aktivierung werden Auszahlungsweg, Zeitpunkt, Prüfungen und Streitfalllogik verbindlich festgelegt.',
            ]),
          ],
        ),
        const LegalSectionCard(
          icon: Icons.shield_outlined,
          title: 'Keine Kaution und kein Schutzprodukt',
          badge: 'Zum Start',
          children: [
            LegalParagraph(
              'ShareItToo verlangt zum Start keine Kaution und bietet keine Versicherung, Garantie oder eigene Schutzleistung an. Übergabe- und Rückgabefotos unterstützen lediglich die Dokumentation zwischen den Nutzern.',
            ),
          ],
        ),
        LegalSectionCard(
          icon: Icons.receipt_long_outlined,
          title: 'Steuerliche Hinweise',
          children: const [
            LegalParagraph(
                'Nutzer sind grundsätzlich selbst dafür verantwortlich, ihre Einnahmen aus Vermietungen steuerlich korrekt anzugeben. Diese Hinweise ersetzen keine Steuerberatung.'),
          ],
        ),
      ],
    );
  }
}
