import 'package:flutter/material.dart';
import 'package:lendify/screens/legal_detail_scaffold.dart';

class LegalTermsScreen extends StatelessWidget {
  const LegalTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDetailScaffold(
      title: 'AGB',
      intro:
          'Diese Nutzungsbedingungen regeln die Verwendung von ShareItToo (SIT). SIT stellt die technische Vermittlungsplattform bereit, wird aber weder Eigentümer der angebotenen Gegenstände noch Vertragspartei des Mietvertrags zwischen den Nutzern.',
      sections: [
        LegalSectionCard(
          icon: Icons.assignment_ind_outlined,
          title: 'Konto und Teilnahme',
          children: const [
            LegalBullets(items: [
              'Für die aktive Nutzung ist ein persönliches Konto erforderlich.',
              'Zum Start richtet sich SIT ausschließlich an volljährige Personen ab 18 Jahren.',
              'Name, Kontaktangaben und sonstige Kontodaten müssen wahrheitsgemäß und aktuell sein.',
              'Zugangsdaten dürfen nicht weitergegeben werden. Verdächtige Kontonutzung ist dem Support unverzüglich zu melden.',
              'Pro Person darf grundsätzlich nur ein Konto geführt werden, soweit SIT nicht ausdrücklich etwas anderes erlaubt.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.handshake_outlined,
          title: 'Rolle von SIT und Vertragsschluss',
          badge: 'Wichtig',
          children: const [
            LegalParagraph(
              'SIT ermöglicht Anzeigen, Buchungsanfragen, Kommunikation sowie die dokumentierte Übergabe und Rückgabe. Der Mietvertrag kommt ausschließlich zwischen Vermieter und Mieter zustande, sobald der Vermieter eine Buchungsanfrage annimmt.',
            ),
            LegalParagraph(
              'Gegenstand, Zeitraum, Mietpreis, Übergabeort, Lieferumfang und besondere Vereinbarungen ergeben sich aus der angenommenen Buchung und dem zugehörigen Chat. SIT übernimmt Gegenstände nicht selbst, prüft nicht jede Anzeige vorab und gibt keine Garantie für Zustand, Verfügbarkeit oder Eignung eines Artikels.',
            ),
            LegalParagraph(
              'Wer gewerblich handelt, muss diesen Status und die gesetzlich erforderlichen Anbieterinformationen korrekt offenlegen. Gesetzliche Verbraucherrechte können insbesondere bei Verträgen mit gewerblichen Anbietern gelten; bei rein privaten Verträgen gelten sie nicht automatisch. Zwingende gesetzliche Rechte bleiben stets unberührt.',
            ),
          ],
        ),
        LegalSectionCard(
          icon: Icons.verified_user_outlined,
          title: 'Pflichten der Nutzer',
          children: const [
            LegalBullets(items: [
              'wahrheitsgemäße Angaben im Profil, in Anzeigen und im Buchungsablauf',
              'rechtmäßige Nutzung der Plattform und Einhaltung der Community‑Regeln',
              'respektvolle Kommunikation ohne Druck, Täuschung oder Belästigung',
              'sorgfältiger und bestimmungsgemäßer Umgang mit gemieteten Gegenständen',
              'Einhaltung vereinbarter Zeiten, Orte und Übergabe- sowie Rückgabeprozesse',
              'unverzügliche Information des Vertragspartners bei Verlust, Schaden, Verspätung oder Sicherheitsproblemen',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.post_add_outlined,
          title: 'Anzeigen erstellen & verwalten',
          children: const [
            LegalBullets(items: [
              'Es dürfen nur Gegenstände angeboten werden, über die der Vermieter rechtmäßig verfügen darf.',
              'Beschreibung und Fotos müssen den tatsächlichen Zustand, bekannte Mängel, Funktionsumfang und Lieferumfang zutreffend wiedergeben.',
              'Preis, Verfügbarkeit, Nutzungsbeschränkungen und besondere Sicherheitsanforderungen müssen vor der Buchung klar erkennbar sein.',
              'Rechte Dritter, insbesondere Urheber-, Marken-, Persönlichkeits- und Datenschutzrechte, sind zu beachten.',
              'Verbotene oder gesetzlich beschränkte Angebote richten sich nach den jeweils aktuellen Community‑Regeln.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.event_available_outlined,
          title: 'Buchungen & Mietvorgänge',
          children: const [
            LegalBullets(items: [
              'Buchungen entstehen durch Anfrage und Annahme durch den Vermieter.',
              'Vor der Übergabe müssen Identität des Vertragspartners, Gegenstand, Zeitraum und Lieferumfang geprüft werden.',
              'Der in SIT geführte QR‑Ablauf und die vorgesehenen Zustandsfotos dokumentieren Übergabe und Rückgabe, ersetzen aber keine eigenständige Prüfung des Gegenstands.',
              'Fotos dürfen nur den Mietgegenstand, dessen Zubehör und unmittelbar erforderliche Zustandsdetails zeigen. Unbeteiligte Personen und fremde persönliche Daten sind zu vermeiden.',
              'Bei Konflikten, Schäden oder Sicherheitsproblemen sind Beweise zu sichern, der Vertragspartner zu informieren und die Meldefunktion beziehungsweise der Support frühzeitig zu nutzen.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.payments_outlined,
          title: 'Preise, Zahlungen und Leistungsstand',
          children: const [
            LegalParagraph(
              'Der aktuelle interne Kandidat verarbeitet keine echten Zahlungen und löst keine Auszahlungen aus. Angezeigte Beträge dienen in dieser Phase nur der Darstellung und Vorbereitung des Buchungsablaufs.',
            ),
            LegalParagraph(
              'Sobald echte Zahlungen oder Plattformgebühren aktiviert werden, werden Betrag, Fälligkeit, Zahlungsdienst, Stornierungsfolgen und gegebenenfalls die SIT‑Servicegebühr vor einer kostenpflichtigen Bestätigung transparent angezeigt. Eine Aktivierung erfolgt nicht rückwirkend.',
            ),
            LegalParagraph(
              'SIT bietet im aktuellen Leistungsstand keine Versicherung, Garantie oder eigene Schadensregulierung. Gesetzliche Ansprüche zwischen Vermieter und Mieter bleiben davon unberührt.',
            ),
          ],
        ),
        LegalSectionCard(
          icon: Icons.event_busy_outlined,
          title: 'Stornierung und gesetzliche Rechte',
          children: const [
            LegalParagraph(
              'Die in der App ausgewiesenen Stornierungsregeln gelten nur, soweit sie wirksam vereinbart wurden und zwingendem Recht nicht widersprechen. Der aktuelle interne Kandidat nimmt keine echten Zahlungen oder Erstattungen vor.',
            ),
            LegalParagraph(
              'Bei Verträgen zwischen Privatpersonen besteht nicht allein wegen des Online-Abschlusses ein gesetzliches Verbraucherwiderrufsrecht. Handelt ein Vermieter gewerblich gegenüber einem Verbraucher, können gesetzliche Informations- und Widerrufsrechte bestehen. Der gewerbliche Vermieter ist für deren Erfüllung verantwortlich.',
            ),
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
          icon: Icons.report_outlined,
          title: 'Meldungen, Moderation und Beschwerden',
          children: const [
            LegalParagraph(
              'Rechtswidrige oder regelwidrige Inhalte können über die Meldefunktion oder den Support gemeldet werden. Eine Meldung soll den betroffenen Inhalt eindeutig bezeichnen und nachvollziehbar erklären, weshalb er rechtswidrig oder regelwidrig sein soll.',
            ),
            LegalParagraph(
              'SIT kann Inhalte prüfen, ihre Sichtbarkeit einschränken, Anzeigen entfernen, Funktionen begrenzen oder Konten vorübergehend beziehungsweise dauerhaft sperren. Dabei werden insbesondere Schwere, Häufigkeit, Kontext, mögliche Gefahren und die Rechte der Beteiligten berücksichtigt. Soweit erforderlich, erhält der betroffene Nutzer eine verständliche Begründung und eine Möglichkeit zur Beschwerde.',
            ),
          ],
        ),
        LegalSectionCard(
          icon: Icons.delete_outline,
          title: 'Laufzeit, Kontolöschung und Änderungen',
          children: const [
            LegalParagraph(
              'Das Nutzungsverhältnis läuft auf unbestimmte Zeit. Nutzer können ihr Konto über die Kontoeinstellungen löschen. Offene Buchungen, Sicherheitsfälle oder gesetzliche Aufbewahrungspflichten können eine sofortige vollständige Löschung einzelner Daten verhindern.',
            ),
            LegalParagraph(
              'SIT kann das Nutzungsverhältnis aus wichtigem Grund beenden, insbesondere bei erheblichen oder wiederholten Rechts- beziehungsweise Regelverstößen. Weniger einschneidende Maßnahmen werden berücksichtigt, soweit sie zumutbar und ausreichend sind.',
            ),
            LegalParagraph(
              'Wesentliche Änderungen dieser Bedingungen werden transparent und mit angemessener Vorlaufzeit bekanntgegeben. Soweit eine erneute Zustimmung erforderlich ist, wird SIT sie ausdrücklich einholen.',
            ),
          ],
        ),
        LegalSectionCard(
          icon: Icons.balance_outlined,
          title: 'Haftung und anwendbares Recht',
          children: const [
            LegalParagraph(
              'SIT haftet nach den gesetzlichen Vorschriften. Unbeschränkte Haftung gilt insbesondere bei Vorsatz, grober Fahrlässigkeit sowie bei Verletzung von Leben, Körper oder Gesundheit. Zwingende gesetzliche Haftungsregeln und Verbraucherrechte werden nicht eingeschränkt.',
            ),
            LegalParagraph(
              'Es gilt deutsches Recht. Bei Verbrauchern gilt diese Rechtswahl nur, soweit dadurch zwingender Schutz des Staates ihres gewöhnlichen Aufenthalts nicht entzogen wird. Gesetzliche Gerichtsstände bleiben unberührt.',
            ),
          ],
        ),
      ],
    );
  }
}
