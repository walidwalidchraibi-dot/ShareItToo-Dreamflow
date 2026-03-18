import 'package:flutter/material.dart';
import 'package:lendify/screens/legal_detail_scaffold.dart';

class LegalCommunityRulesScreen extends StatelessWidget {
  const LegalCommunityRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDetailScaffold(
      title: 'Community‑Regeln',
      intro:
          'Damit ShareItToo sicher und fair bleibt, gelten klare Regeln für Inhalte, Kommunikation und angebotene Artikel. Verstöße können zur Sperrung des Kontos führen.',
      sections: [
        LegalSectionCard(
          icon: Icons.check_circle_outline,
          title: 'Erlaubte Inhalte',
          children: const [
            LegalBullets(items: [
              'Rechtmäßige Artikel mit ehrlicher Beschreibung',
              'Realistische Fotos des tatsächlichen Zustands',
              'Respektvolle Kommunikation',
              'Klare Angaben zu Übergabe/Rückgabe und Lieferumfang',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.block_outlined,
          title: 'Verbotene Inhalte',
          badge: 'Nicht erlaubt',
          children: const [
            LegalParagraph('Insbesondere verboten sind:'),
            SizedBox(height: 10),
            LegalBullets(items: [
              'gestohlene Gegenstände',
              'illegale Produkte',
              'Waffen',
              'gefährliche Gegenstände',
              'betrügerische Anzeigen',
              'falsche Angaben in Listings',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.security_outlined,
          title: 'Konsequenzen bei Verstößen',
          children: const [
            LegalBullets(items: [
              'Entfernung von Anzeigen oder Inhalten',
              'Einschränkung einzelner Funktionen',
              'temporäre oder dauerhafte Sperrung des Kontos',
            ]),
            SizedBox(height: 10),
            LegalParagraph('Wenn du problematische Inhalte siehst, melde sie bitte über die Support‑Funktion.'),
          ],
        ),
      ],
    );
  }
}
