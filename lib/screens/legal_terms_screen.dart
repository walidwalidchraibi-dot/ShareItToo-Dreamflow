import 'package:flutter/material.dart';
import 'package:lendify/screens/legal_detail_scaffold.dart';

class LegalTermsScreen extends StatelessWidget {
  const LegalTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDetailScaffold(
      title: 'AGB',
      intro:
          'Diese Übersicht beschreibt die wichtigsten Grundprinzipien zur Nutzung von ShareItToo. ShareItToo ist eine Vermittlungsplattform und wird nicht Eigentümer der angebotenen Gegenstände.',
      sections: [
        LegalSectionCard(
          icon: Icons.storefront_outlined,
          title: 'Nutzung der Plattform',
          children: const [
            LegalBullets(items: [
              'ShareItToo ermöglicht das Erstellen von Anzeigen und die Vermittlung von Mietvorgängen.',
              'Nutzer sind für ihre Angaben und Inhalte (z.B. Bilder, Beschreibungen) verantwortlich.',
              'Die Nutzung setzt ein Konto und die Einhaltung der Community‑Regeln voraus.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.verified_user_outlined,
          title: 'Rechte & Pflichten der Nutzer',
          children: const [
            LegalBullets(items: [
              'Wahrheitsgemäße Angaben im Profil und in Listings',
              'Sorgfältiger Umgang mit gemieteten Gegenständen',
              'Respektvolle Kommunikation',
              'Einhaltung der Buchungsbedingungen und Übergabeprozesse',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.post_add_outlined,
          title: 'Anzeigen erstellen & verwalten',
          children: const [
            LegalBullets(items: [
              'Artikel müssen rechtmäßig sein und dürfen nicht gegen Community‑Regeln verstoßen.',
              'Beschreibungen sollen Zustand, Lieferumfang und Besonderheiten transparent darstellen.',
              'Preise, Kaution (falls vorgesehen) und Verfügbarkeit müssen klar angegeben sein.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.event_available_outlined,
          title: 'Buchungen & Mietvorgänge',
          children: const [
            LegalBullets(items: [
              'Buchungen entstehen durch Anfrage und Annahme durch den Vermieter.',
              'Übergabe/Rückgabe sollen nachvollziehbar dokumentiert werden (z.B. Fotos).',
              'Bei Konflikten oder Schäden sollen Nutzer den Support frühzeitig kontaktieren.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.payments_outlined,
          title: 'Gebührenstruktur',
          children: const [
            LegalParagraph('ShareItToo kann für die Vermittlung und Zahlungsabwicklung Gebühren erheben. Details findest du unter „Gebühren & Zahlungsbedingungen“.')
          ],
        ),
        LegalSectionCard(
          icon: Icons.handshake_outlined,
          title: 'Wichtiger Hinweis zur Rolle von ShareItToo',
          badge: 'Wichtig',
          children: const [
            LegalParagraph(
              'ShareItToo ist eine Vermittlungsplattform. ShareItToo ist nicht Eigentümer der vermieteten Gegenstände und wird nicht Vertragspartei der Mietvereinbarung zwischen Nutzern. Die Verantwortung für Zustand, Nutzung und Rückgabe liegt bei den jeweiligen Nutzern.',
            ),
          ],
        ),
      ],
    );
  }
}
