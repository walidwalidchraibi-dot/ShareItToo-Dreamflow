import 'package:flutter/material.dart';

class VerificationIntroScreen extends StatelessWidget {
  const VerificationIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Verifizierung')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Warum verifizieren?', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                  'Verifizierte Nutzer erhalten mehr Vertrauen, mehr Anfragen und eine höhere Annahmequote. Außerdem werden Buchungen schneller bestätigt und deine Sichtbarkeit steigt.',
                  style: TextStyle(color: Colors.white70, height: 1.35),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Text('So läuft die Verifizierung ab', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _StepTile(icon: Icons.badge_outlined, title: '1. Identitätsnachweis', subtitle: 'Gültiger Personalausweis oder Reisepass bereit halten.'),
            _StepTile(icon: Icons.face_retouching_natural_outlined, title: '2. Selfie-Abgleich', subtitle: 'Kurzes Selfie zur Überprüfung, dass du es wirklich bist.'),
            _StepTile(icon: Icons.account_balance_wallet_outlined, title: '3. Zahlungsprofil', subtitle: 'Zahlungsmethode hinzufügen (für Auszahlungen/Absicherungen).'),
            _StepTile(icon: Icons.sms_outlined, title: '4. Telefonnummer bestätigen', subtitle: 'Wir senden dir einen Code per SMS.'),
            _StepTile(icon: Icons.home_work_outlined, title: '5. Adresse bestätigen', subtitle: 'Anschrift angeben, um lokale Angebote zu verbessern.'),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Später'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    // Demo: no backend connected here
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Verifizierung starten?', style: TextStyle(color: Colors.white)),
                        content: const Text('Dies ist eine Demo. In der echten App wirst du durch einen kurzen Prozess geführt.', style: TextStyle(color: Colors.white)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
                          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Jetzt starten'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final IconData icon; final String title; final String subtitle;
  const _StepTile({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}