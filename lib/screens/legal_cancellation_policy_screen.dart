import 'package:flutter/material.dart';
import 'package:lendify/screens/legal_detail_scaffold.dart';

class LegalCancellationPolicyScreen extends StatelessWidget {
  const LegalCancellationPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDetailScaffold(
      title: 'Stornierungsbedingungen',
      intro:
          'Stornierungen sollen fair für beide Seiten sein. Diese Übersicht erklärt, wann storniert werden kann, welche Gebühren entstehen können und wie Rückerstattungen funktionieren.',
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
              'Je kurzfristiger die Stornierung, desto eher können Gebühren anfallen.',
              'Bei wiederholtem Missbrauch kann das Konto eingeschränkt werden.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.currency_exchange_outlined,
          title: 'Rückerstattungen',
          children: const [
            LegalBullets(items: [
              'Erstattungen erfolgen abhängig von Stornozeitpunkt, Gebühren und ggf. Streitfällen.',
              'Bei späterer Zahlungsabwicklung kann die Bearbeitungszeit vom Zahlungsdienstleister abhängen.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.support_agent_outlined,
          title: 'Probleme zwischen Nutzern',
          children: const [
            LegalParagraph('Wenn Probleme auftreten (z.B. Artikel nicht wie beschrieben, verspätete Rückgabe, Streit über Schäden), kontaktiere den Support so früh wie möglich. Foto‑Dokumentation bei Übergabe/Rückgabe hilft, Fälle fair zu klären.'),
          ],
        ),
      ],
    );
  }
}
