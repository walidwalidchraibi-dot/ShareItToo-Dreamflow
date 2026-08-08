import 'package:flutter/material.dart';
import 'package:lendify/screens/legal_detail_scaffold.dart';

class LegalImprintScreen extends StatelessWidget {
  const LegalImprintScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDetailScaffold(
      title: 'Impressum',
      intro:
          'Hier findest du die Anbieterkennzeichnung sowie Kontaktinformationen. Tippe auf E‑Mail/Telefon/Link, um sie zu kopieren.',
      sections: [
        LegalSectionCard(
          icon: Icons.apartment_outlined,
          title: 'Anbieter',
          children: const [
            LegalParagraph('ShareItToo GmbH\nBernhaldenweg 37\n71579 Spiegelberg‑Jux\nDeutschland'),
            SizedBox(height: 12),
            LegalParagraph('Geschäftsführer: Walid Chraibi'),
          ],
        ),
        LegalSectionCard(
          icon: Icons.contact_mail_outlined,
          title: 'Kontakt',
          children: const [
            CopyableLine(icon: Icons.mail_outline, label: 'E‑Mail', value: 'contact@shareittoo.com', toastTitle: 'E‑Mail kopiert'),
            SizedBox(height: 10),
            CopyableLine(icon: Icons.phone_outlined, label: 'Telefon', value: '+49 176 47105994', toastTitle: 'Telefonnummer kopiert'),
          ],
        ),
        LegalSectionCard(
          icon: Icons.edit_document,
          title: 'Verantwortlich für den Inhalt',
          children: const [
            LegalParagraph('Verantwortlich für den Inhalt nach § 18 Abs. 2 MStV:'),
            SizedBox(height: 10),
            LegalParagraph('Walid Chraibi\nBernhaldenweg 37\n71579 Spiegelberg‑Jux\nDeutschland'),
          ],
        ),
        LegalSectionCard(
          icon: Icons.balance_outlined,
          title: 'Verbraucherstreitbeilegung',
          children: const [
            LegalParagraph('Wir sind zur Teilnahme an einem Streitbeilegungsverfahren vor einer Verbraucherschlichtungsstelle weder verpflichtet noch bereit.'),
          ],
        ),
      ],
    );
  }
}
