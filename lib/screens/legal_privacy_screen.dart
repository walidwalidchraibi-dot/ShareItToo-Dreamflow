import 'package:flutter/material.dart';
import 'package:lendify/screens/legal_detail_scaffold.dart';

class LegalPrivacyScreen extends StatelessWidget {
  const LegalPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDetailScaffold(
      title: 'Datenschutz',
      intro:
          'Wir verarbeiten personenbezogene Daten nur, soweit dies für die Bereitstellung und Sicherheit der Plattform erforderlich ist. Diese Übersicht erklärt dir, welche Daten typischerweise anfallen, warum wir sie benötigen und welche Rechte du nach DSGVO hast.',
      sections: [
        LegalSectionCard(
          icon: Icons.inventory_2_outlined,
          title: 'Welche Daten Nutzer angeben',
          children: const [
            LegalParagraph('Je nach Nutzung können u.a. folgende Angaben erforderlich sein:'),
            SizedBox(height: 10),
            LegalBullets(items: [
              'Kontodaten (z.B. Name, E‑Mail, ggf. Telefonnummer)',
              'Profilangaben (z.B. Bild, Kurzbeschreibung, Stadt)',
              'Verifizierungsdaten (nur wenn du eine Verifizierung startest)',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.storage_outlined,
          title: 'Welche Daten gespeichert werden',
          children: const [
            LegalParagraph('Im Rahmen des Plattformbetriebs können u.a. folgende Daten gespeichert werden:'),
            SizedBox(height: 10),
            LegalBullets(items: [
              'Kontodaten',
              'Buchungsdaten (z.B. Zeitraum, Artikel, Status, Übergabe/Rückgabe)',
              'Zahlungsdaten (z.B. Buchungsbeträge, Gebühren, Auszahlungen)',
              'Nachrichten zwischen Nutzern (zur Abwicklung der Buchung)',
              'Standortdaten (nur Stadt/Region – keine Live‑Ortung)',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.manage_search_outlined,
          title: 'Warum Daten verarbeitet werden',
          children: const [
            LegalBullets(items: [
              'um Buchungen zu ermöglichen und abzuwickeln',
              'um Kommunikation zwischen Mietern und Vermietern bereitzustellen',
              'um Zahlungen/Auszahlungen zu verarbeiten (später auch via Zahlungsdienstleister)',
              'um Missbrauch, Betrug und Sicherheitsfälle zu verhindern',
              'um Supportfälle bearbeiten zu können',
            ]),
            SizedBox(height: 10),
            LegalParagraph('Personenbezogene Daten werden nicht zu Werbezwecken „verkauft“. Sie werden ausschließlich zur Bereitstellung der Plattform verarbeitet.'),
          ],
        ),
        LegalSectionCard(
          icon: Icons.schedule_outlined,
          title: 'Speicherdauer',
          children: const [
            LegalParagraph(
              'Daten werden nur so lange gespeichert, wie sie für den jeweiligen Zweck erforderlich sind. Bestimmte Informationen (z.B. buchungs- oder abrechnungsrelevante Daten) können aufgrund gesetzlicher Aufbewahrungspflichten länger gespeichert werden.',
            ),
          ],
        ),
        LegalSectionCard(
          icon: Icons.gavel_outlined,
          title: 'Deine Rechte nach DSGVO',
          children: const [
            LegalParagraph('Du hast – je nach Fall – insbesondere folgende Rechte:'),
            SizedBox(height: 10),
            LegalBullets(items: [
              'Auskunft über gespeicherte Daten',
              'Berichtigung unrichtiger Daten',
              'Löschung (soweit keine Pflichten entgegenstehen)',
              'Einschränkung der Verarbeitung',
              'Datenübertragbarkeit',
              'Widerspruch gegen Verarbeitung in bestimmten Fällen',
            ]),
          ],
        ),
      ],
    );
  }
}
