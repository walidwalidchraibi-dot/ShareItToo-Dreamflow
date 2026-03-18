import 'package:flutter/material.dart';
import 'package:lendify/screens/legal_detail_scaffold.dart';

class LegalDisclaimerScreen extends StatelessWidget {
  const LegalDisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDetailScaffold(
      title: 'Haftungsausschluss',
      intro:
          'ShareItToo stellt eine Plattform bereit, auf der Nutzer Gegenstände vermieten und mieten können. Die Verantwortung für Zustand und Nutzung liegt bei den jeweiligen Nutzern.',
      sections: [
        LegalSectionCard(
          icon: Icons.handshake_outlined,
          title: 'Rolle der Plattform',
          badge: 'Wichtig',
          children: const [
            LegalParagraph(
              'ShareItToo ist eine Vermittlungsplattform. ShareItToo ist nicht Eigentümer der angebotenen Gegenstände und übernimmt keine Verantwortung für deren Zustand, Sicherheit oder Eignung für einen bestimmten Zweck.',
            ),
          ],
        ),
        LegalSectionCard(
          icon: Icons.person_outline,
          title: 'Verantwortung der Nutzer',
          children: const [
            LegalBullets(items: [
              'Vermieter müssen Artikel korrekt beschreiben und in einem sicheren Zustand übergeben.',
              'Mieter müssen Artikel sorgfältig und entsprechend der Vereinbarung nutzen.',
              'Übergabe/Rückgabe sollten dokumentiert werden (z.B. Fotos), um Missverständnisse zu vermeiden.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.report_outlined,
          title: 'Meldung von Problemen',
          children: const [
            LegalParagraph('Bei Verdacht auf Betrug, gefährliche Artikel oder Verstöße gegen Community‑Regeln kontaktiere bitte den Support und nutze die Meldefunktionen.'),
          ],
        ),
      ],
    );
  }
}
