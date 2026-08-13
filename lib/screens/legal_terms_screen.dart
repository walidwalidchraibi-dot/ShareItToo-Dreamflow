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
              'Preise und Verfügbarkeit müssen klar angegeben sein.',
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
          icon: Icons.star_outline,
          title: 'Bewertungen & Bewertungssystem',
          children: const [
            LegalParagraph(
              'Bewertungen können grundsätzlich nur von Nutzern abgegeben werden, die an einer über SIT dokumentierten und abgeschlossenen Vermietung beteiligt waren. SIT überprüft die Berechtigung zur Bewertungsabgabe anhand der zugehörigen Buchung.',
            ),
            LegalParagraph(
              'Eine Bewertung umfasst die Kriterien Kommunikation, Zuverlässigkeit, Artikel wie beschrieben sowie Übergabe und Rückgabe. Die Kriterien werden gleich gewichtet. Die Gesamtbewertung einer einzelnen Vermietung entspricht dem arithmetischen Mittelwert der vier Kriterien und wird auf eine Nachkommastelle gerundet. Die öffentliche Gesamtbewertung eines Nutzers ergibt sich aus dem Durchschnitt aller gültigen, vollständigen und eindeutigen Einzelbewertungen.',
            ),
            LegalParagraph(
              'Beim Kriterium „Artikel wie beschrieben“ wird bewertet, ob der tatsächliche Zustand, die Ausstattung, die Funktionsfähigkeit, Gebrauchsspuren und bekannte Mängel mit den Angaben in der Anzeige übereinstimmen. Nicht maßgeblich ist, ob der Artikel neu, neuwertig oder optisch hochwertig ist. Ein zutreffend als gebraucht oder stark gebraucht beschriebener Artikel kann daher die höchste Bewertung erhalten.',
            ),
            LegalParagraph(
              'Das Kriterium „Übergabe und Rückgabe“ umfasst insbesondere den Ablauf, die Einhaltung vereinbarter Zeiten, Sauberkeit, Funktionsfähigkeit, vollständiges Zubehör sowie die ordnungsgemäße Rückgabe.',
            ),
            LegalParagraph(
              'Preis-Leistung ist kein Bestandteil der öffentlichen Bewertung und fließt nicht in die Gesamtbewertung ein.',
            ),
            LegalParagraph(
              'SIT kann Bewertungen prüfen und erforderlichenfalls ausblenden oder entfernen, wenn konkrete Anhaltspunkte für Manipulation, Mehrfachbewertungen, fehlenden Buchungsbezug, Beleidigungen, rechtswidrige Inhalte oder nachweislich falsche Tatsachenbehauptungen bestehen. Technisch fehlerhafte Berechnungen oder doppelt erfasste Bewertungen dürfen berichtigt werden. Eine inhaltliche Veränderung der persönlichen Meinung des Bewertenden erfolgt nicht.',
            ),
          ],
        ),
        LegalSectionCard(
          icon: Icons.payments_outlined,
          title: 'Gebührenstruktur',
          children: const [
            LegalParagraph(
                'ShareItToo kann für die Vermittlung und Zahlungsabwicklung Gebühren erheben. Details findest du unter „Gebühren & Zahlungsbedingungen“.')
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
