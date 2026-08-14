import 'package:flutter/material.dart';
import 'package:lendify/screens/legal_detail_scaffold.dart';

class LegalCancellationPolicyScreen extends StatelessWidget {
  const LegalCancellationPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDetailScaffold(
      title: 'Stornierungsbedingungen',
      intro:
          'Stornierungen sollen fair für beide Seiten sein. Diese Übersicht beschreibt den aktuellen Buchungsablauf. Verbindliche Gebühren- und Erstattungsregeln werden vor der Aktivierung von Echtgeldzahlungen gesondert freigegeben.',
      sections: [
        LegalSectionCard(
          icon: Icons.event_busy_outlined,
          title: 'Wann kann storniert werden?',
          children: const [
            LegalBullets(items: [
              'Vor Buchungsbeginn: in der Regel möglich, je nach Frist und Status.',
              'Während einer laufenden Buchung: nur bei besonderen Umständen und nach Abstimmung.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.payments_outlined,
          title: 'Mögliche Gebühren',
          children: const [
            LegalBullets(items: [
              'Der aktuelle Store-Kandidat belastet bei einer Stornierung kein echtes Zahlungsmittel.',
              'Spätere Stornogebühren müssen vor der Buchung klar angezeigt und verbindlich freigegeben werden.',
              'Bei wiederholtem Missbrauch kann das Konto eingeschränkt werden.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.currency_exchange_outlined,
          title: 'Rückerstattungen',
          children: const [
            LegalBullets(items: [
              'Ohne aktivierte Echtgeldzahlung gibt es im aktuellen Store-Kandidaten keine reale Rückerstattung.',
              'Bei späterer Zahlungsabwicklung hängen Erstattungsweg und Bearbeitungszeit von der dann freigegebenen Regel und dem Zahlungsdienstleister ab.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.support_agent_outlined,
          title: 'Probleme zwischen Nutzern',
          children: const [
            LegalParagraph(
                'Wenn Probleme auftreten (z.B. Artikel nicht wie beschrieben, verspätete Rückgabe, Streit über Schäden), kontaktiere den Support so früh wie möglich. Foto‑Dokumentation bei Übergabe/Rückgabe hilft, Fälle fair zu klären.'),
          ],
        ),
      ],
    );
  }
}
