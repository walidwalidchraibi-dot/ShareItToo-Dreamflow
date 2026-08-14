import 'package:flutter/material.dart';
import 'package:lendify/screens/legal_detail_scaffold.dart';

class LegalCancellationPolicyScreen extends StatelessWidget {
  const LegalCancellationPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDetailScaffold(
      title: 'Stornierungsbedingungen',
      intro:
          'V4-Zwischenregel für den privaten Pilot. Die Werte sind zentral änderbar und werden vor Echtgeldaktivierung nochmals rechtlich freigegeben.',
      sections: [
        LegalSectionCard(
          icon: Icons.event_busy_outlined,
          title: 'Wann kann storniert werden?',
          children: const [
            LegalBullets(items: [
              'Mindestens 24 Stunden vor Mietbeginn: 100 % Erstattung des Gesamtbetrags.',
              'Weniger als 24 Stunden vor Mietbeginn: vorläufig 50 % Erstattung; 50 % des Mietpreises und der darauf entfallende Plattformbeitrag verbleiben.',
              'Ab Mietbeginn oder bei Mieter-No-Show: vorläufig keine vertragliche Erstattung.',
              'Storniert der Vermieter oder scheitert die Übergabe aus seiner Sphäre: grundsätzlich 100 % Erstattung.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.payments_outlined,
          title: '60-Minuten-Karenz',
          children: const [
            LegalParagraph(
              'Entsteht der Mietvertrag weniger als 24 Stunden vor Mietbeginn, kann der Mieter innerhalb von 60 Minuten nach der Buchungsbestätigung kostenlos stornieren, höchstens bis Mietbeginn. Die App zeigt den genauen Zeitpunkt.',
            ),
          ],
        ),
        LegalSectionCard(
          icon: Icons.currency_exchange_outlined,
          title: 'Rückerstattungen',
          children: const [
            LegalBullets(items: [
              'Ohne aktivierte Echtgeldzahlung gibt es im aktuellen Store-Kandidaten keine reale Rückerstattung.',
              'Bei aktivierter Zahlungsabwicklung folgt der Plattformbeitrag demselben Erstattungsverhältnis wie der Mietpreis.',
              'Ersparte Aufwendungen, Ersatzvermietung und der Nachweis eines geringeren Schadens werden berücksichtigt.',
              'Rückerstattungen erfolgen über die ursprüngliche Zahlungsart und den freigegebenen Marketplace-Zahlungsdienstleister.',
            ]),
          ],
        ),
        LegalSectionCard(
          icon: Icons.support_agent_outlined,
          title: 'Probleme zwischen Nutzern',
          children: const [
            LegalParagraph(
                'Ein No-Show liegt grundsätzlich erst 30 Minuten nach der beidseitig bestätigten Zeit, ohne andere Vereinbarung und nach zwei dokumentierten Kontaktversuchen vor. Sicherheits-, Notfall- und nachweisbare technische Fälle werden einzeln geprüft.'),
          ],
        ),
      ],
    );
  }
}
