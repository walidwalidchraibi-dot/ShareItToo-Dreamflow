import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/models/user.dart';
import 'package:provider/provider.dart';
import 'package:lendify/screens/profile_info_screen.dart';
import 'package:lendify/widgets/blur_modal.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  User? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await DataService.getCurrentUser();
    if (!mounted) return;
    setState(() { _user = u; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final user = _user;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.t('profile.menu.accountSettings')),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _SectionCard(children: [
            _RowTile(
              icon: Icons.badge_outlined,
              label: l10n.t('Profilinformationen'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileInfoScreen())),
            ),
          ]),
          const SizedBox(height: 16),
          _SectionCard(children: [
            _RowTile(
              icon: Icons.mail_outline,
              label: l10n.t('account.item.contactData'),
              onTap: () => _openContactDataSheet(context),
            ),
          ]),
          const SizedBox(height: 16),
          if ((user?.isVerified ?? false)) _SectionCard(children: [
            _RowTile(
              icon: Icons.verified_outlined,
              label: l10n.t('account.item.verification'),
              onTap: () => _openVerificationSheet(context),
            ),
          ]),
          if ((user?.isVerified ?? false)) const SizedBox(height: 16),
          _SectionCard(children: [
            _RowTile(
              icon: Icons.lock_outline,
              label: l10n.t('account.item.changePassword'),
              onTap: () => _openChangePasswordSheet(context),
            ),
          ]),
          const SizedBox(height: 16),
          _SectionCard(children: [
            _RowTile(
              icon: Icons.credit_card,
              label: l10n.t('account.item.paymentMethods'),
              onTap: () => _openPaymentMethodsSheet(context),
            ),
            const _Divider(),
            _RowTile(
              icon: Icons.account_balance_wallet_outlined,
              label: l10n.t('account.item.payoutMethods'),
              onTap: () => _openPayoutMethodsSheet(context),
            ),
            const _Divider(),
            _RowTile(
              icon: Icons.receipt_long_outlined,
              label: l10n.t('account.item.invoices'),
              onTap: () => _openInvoicesFullscreen(context),
            ),
          ]),
          const SizedBox(height: 16),
          _SectionCard(children: [
            _RowTile(
              icon: Icons.notifications_active_outlined,
              label: l10n.t('account.item.notifications'),
              onTap: () => _openNotificationsSheet(context),
            ),
          ]),
          const SizedBox(height: 16),
          _SectionCard(children: [
            _RowTile(
              icon: Icons.shield_outlined,
              label: l10n.t('account.item.dataPrivacyInfo'),
              onTap: () => _openPrivacyInfoSheet(context),
            ),
            const _Divider(),
            _RowTile(
              icon: Icons.delete_outline,
              label: l10n.t('account.item.deleteAccount'),
              isDestructive: true,
              onTap: () => _confirmDeleteAccount(context),
            ),
          ]),
        ]),
      ),
    );
  }

  // Profileinformationen entfernt

  void _openContactDataSheet(BuildContext context) {
    final l10n = context.read<LocalizationController>();
    final u = _user;
    if (u == null) return;
    showBlurBottomSheet(context, child: SheetScaffold(
      title: l10n.t('account.item.contactData'),
      body: Column(children: [
        _InfoRow(icon: Icons.alternate_email, label: 'E‑Mail', value: u.email, actionLabel: 'Ändern', onAction: () => _openChangeEmailFlow(context)),
        const SizedBox(height: 8),
        _InfoRow(icon: Icons.phone_outlined, label: 'Telefon', value: u.phone ?? '—', actionLabel: 'Ändern', onAction: () => _openChangePhoneFlow(context)),
        const SizedBox(height: 8),
        _InfoRow(icon: Icons.place_outlined, label: 'Adresse', value: _addressDisplay(u), actionLabel: 'Ändern', onAction: () => _openChangeAddressFlow(context)),
        const SizedBox(height: 12),
        Text('E‑Mail, Telefon und Adresse sind niemals öffentlich sichtbar.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
      ]),
    ));
  }

  String _addressDisplay(User u) {
    final line = (u.homeLocation ?? '').trim();
    if (line.isNotEmpty) return line;
    final city = (u.city ?? '').trim();
    final country = (u.country ?? '').trim();
    if (city.isEmpty && country.isEmpty) return '—';
    if (city.isEmpty) return country;
    if (country.isEmpty) return city;
    return '$city, $country';
  }

  void _openVerificationSheet(BuildContext context) {
    final l10n = context.read<LocalizationController>();
    showBlurBottomSheet(context, child: SheetScaffold(
      title: l10n.t('account.item.verification'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        ListTile(leading: Icon(Icons.verified, color: Colors.greenAccent), title: Text('Verifiziert ✅'), subtitle: Text('Deine Identität wurde bestätigt.')),
      ]),
      bottomBar: Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Support kontaktieren')))]),
    ));
  }

  void _openChangePasswordSheet(BuildContext context) {
    final l10n = context.read<LocalizationController>();
    final currentCtrl = TextEditingController();
    final nextCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showBlurBottomSheet(context, child: StatefulBuilder(builder: (context, setStateSheet) {
      bool valid = nextCtrl.text.isNotEmpty && nextCtrl.text == confirmCtrl.text && currentCtrl.text.isNotEmpty;
      return SheetScaffold(
        title: l10n.t('account.item.changePassword'),
        body: Column(children: [
          TextField(controller: currentCtrl, obscureText: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline), labelText: 'Aktuelles Passwort')),
          const SizedBox(height: 12),
          TextField(controller: nextCtrl, obscureText: true, onChanged: (_) => setStateSheet(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.password_outlined), labelText: 'Neues Passwort')),
          const SizedBox(height: 12),
          TextField(controller: confirmCtrl, obscureText: true, onChanged: (_) => setStateSheet(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.check_circle_outline), labelText: 'Passwort bestätigen')),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: Text('Mind. 8 Zeichen, eine Zahl, ein Sonderzeichen.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70))),
        ]),
        bottomBar: Row(children: [Expanded(child: FilledButton(onPressed: valid ? () { Navigator.of(context).maybePop(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('Gespeichert')))); } : null, child: Text(l10n.t('Speichern'))))]),
      );
    }));
  }

  void _openPaymentMethodsSheet(BuildContext context) {
    final l10n = context.read<LocalizationController>();
    showBlurBottomSheet(context, child: SheetScaffold(
      title: l10n.t('account.item.paymentMethods'),
      body: Column(children: const [
        _PaymentMethodRow(brand: 'Visa', last4: '4242', isDefault: true),
        SizedBox(height: 8),
        _PaymentMethodRow(brand: 'Mastercard', last4: '4444', isDefault: false),
      ]),
      bottomBar: Row(children: [Expanded(child: FilledButton(onPressed: () {}, child: const Text('Zahlungsmethode hinzufügen')))]),
    ));
  }

  void _openPayoutMethodsSheet(BuildContext context) {
    final l10n = context.read<LocalizationController>();
    showBlurBottomSheet(context, child: SheetScaffold(
      title: l10n.t('account.item.payoutMethods'),
      body: Column(children: const [
        ListTile(leading: Icon(Icons.account_balance_outlined), title: Text('Bankkonto'), subtitle: Text('DE•• •• •••• •••• •••• ••')),
      ]),
      bottomBar: Row(children: [Expanded(child: FilledButton(onPressed: () {}, child: const Text('Auszahlungsmethode hinzufügen')))]),
    ));
  }

  void _openInvoicesFullscreen(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(pageBuilder: (ctx, a1, a2) => const _InvoicesPage(), opaque: false, barrierDismissible: true, transitionsBuilder: (ctx, anim, _, child) {
      return FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut), child: child);
    }));
  }

  void _openNotificationsSheet(BuildContext context) {
    final l10n = context.read<LocalizationController>();
    bool r1 = true, r2 = true, r3 = true, r4 = true, r5 = false;
    showBlurBottomSheet(context, child: StatefulBuilder(builder: (context, setStateSheet) {
      return SheetScaffold(
        title: l10n.t('account.item.notifications'),
        body: Column(children: [
          SwitchListTile(value: r1, onChanged: (v) => setStateSheet(() => r1 = v), title: const Text('Mietanfragen')),
          SwitchListTile(value: r2, onChanged: (v) => setStateSheet(() => r2 = v), title: const Text('Buchungen')),
          SwitchListTile(value: r3, onChanged: (v) => setStateSheet(() => r3 = v), title: const Text('Nachrichten')),
          SwitchListTile(value: r4, onChanged: (v) => setStateSheet(() => r4 = v), title: const Text('Übergabe/Rückgabe Erinnerungen')),
          SwitchListTile(value: r5, onChanged: (v) => setStateSheet(() => r5 = v), title: const Text('App-Updates & Tipps')),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)), child: Row(children: const [
            Icon(Icons.info_outline, color: Colors.white70), SizedBox(width: 8), Expanded(child: Text('System-Push sind evtl. deaktiviert. Bitte in den OS-Einstellungen prüfen.')),
          ])),
        ]),
        bottomBar: Row(children: [Expanded(child: FilledButton(onPressed: () { Navigator.of(context).maybePop(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('Gespeichert')))); }, child: Text(l10n.t('Speichern'))))]),
      );
    }));
  }

  void _openPrivacyInfoSheet(BuildContext context) {
    showBlurBottomSheet(context, child: const SheetScaffold(
      title: 'Datenschutz-Infos',
      body: _PrivacyText(),
    ));
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(context: context, barrierDismissible: true, builder: (_) {
      return AlertDialog(
        title: const Text('Konto löschen?'),
        content: const Text('Nur möglich, wenn keine laufenden/kommenden Buchungen und keine offenen Zahlungen.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Abbrechen')),
          FilledButton(style: FilledButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.redAccent), onPressed: () { Navigator.of(context).pop(); }, child: const Text('Endgültig löschen')),
        ],
      );
    });
  }

  void _openChangeEmailFlow(BuildContext context) {
    final ctrl = TextEditingController();
    showBlurBottomSheet(context, child: SheetScaffold(
      title: 'E‑Mail ändern',
      body: Column(children: [
        TextField(controller: ctrl, decoration: const InputDecoration(prefixIcon: Icon(Icons.alternate_email), labelText: 'Neue E‑Mail')),
        const SizedBox(height: 8),
        const _Badge(text: 'Unbestätigt'),
      ]),
      bottomBar: Row(children: const [Expanded(child: FilledButton(onPressed: null, child: Text('Bestätigungslink senden')))]),
    ));
  }

  void _openChangePhoneFlow(BuildContext context) {
    final phoneCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    showBlurBottomSheet(context, child: StatefulBuilder(builder: (context, setStateSheet) {
      bool sent = false;
      return SheetScaffold(
        title: 'Telefonnummer ändern',
        body: Column(children: [
          if (!sent) TextField(controller: phoneCtrl, decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_outlined), labelText: 'Neue Telefonnummer')),
          if (sent) TextField(controller: codeCtrl, decoration: const InputDecoration(prefixIcon: Icon(Icons.sms_outlined), labelText: 'Code (6‑stellig)')),
        ]),
        bottomBar: Row(children: [
          Expanded(child: FilledButton(onPressed: () { if (!sent) { setStateSheet(() => sent = true); } else { Navigator.of(context).maybePop(); } }, child: Text(sent ? 'Bestätigen' : 'Code senden'))),
        ]),
      );
    }));
  }

  void _openChangeAddressFlow(BuildContext context) {
    final u = _user;
    if (u == null) return;
    final addrCtrl = TextEditingController(text: _addressDisplay(u) == '—' ? '' : _addressDisplay(u));
    showBlurBottomSheet(context, child: StatefulBuilder(builder: (context, setStateSheet) {
      String error = '';
      bool _hasStreetNumber(String input) {
        // Validate: first segment (before first comma) must contain at least one digit
        final raw = input.trim();
        if (raw.isEmpty) return false;
        final first = raw.split(',').first.trim();
        // Typical formats: "Musterstraße 12", "12 Musterweg", "Musterstr. 12a"
        return RegExp(r"\d").hasMatch(first);
      }
      return SheetScaffold(
        title: 'Adresse ändern',
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: addrCtrl,
            keyboardType: TextInputType.streetAddress,
            autofillHints: const [AutofillHints.streetAddressLine1, AutofillHints.streetAddressLine2, AutofillHints.postalCode, AutofillHints.addressCity],
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.place_outlined),
              labelText: 'Adresse (Straße und Hausnummer, PLZ, Stadt)',
              hintText: 'z. B. Musterstraße 12, 12345 Berlin'
            )
          ),
          const SizedBox(height: 8),
          Text('Nur du und deine Gegenpartei nach Annahme sehen diese Adresse.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
          if (error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(error, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.redAccent)),
          ],
        ]),
        bottomBar: Row(children: [
          Expanded(child: FilledButton(
            onPressed: () async {
              final line = addrCtrl.text.trim();
              if (line.isEmpty) {
                setStateSheet(() { error = 'Bitte gib eine Adresse ein'; });
                return;
              }
              if (!_hasStreetNumber(line)) {
                setStateSheet(() { error = 'Bitte gib Straße und Hausnummer an (z. B. Musterstraße 12)'; });
                return;
              }
              try {
                final current = await DataService.getCurrentUser();
                if (current == null) { Navigator.of(context).maybePop(); return; }
                // Heuristic: derive city from address; keep existing country if not present
                final derivedCity = DataService.deriveCityFromAddress(line);
                final updated = current.copyWith(
                  homeLocation: line,
                  city: derivedCity.isNotEmpty ? derivedCity : current.city,
                );
                await DataService.setCurrentUser(updated);
                if (!mounted) return;
                setState(() => _user = updated);
                Navigator.of(context).maybePop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gespeichert')));
              } catch (e) {
                debugPrint('[AccountSettings] change address failed: '+e.toString());
                if (!mounted) return;
                setStateSheet(() { error = 'Speichern fehlgeschlagen'; });
              }
            },
            child: const Text('Speichern'),
          )),
        ]),
      );
    }));
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 1, color: Colors.white24);
}

class _RowTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;
  final VoidCallback onTap;
  const _RowTile({required this.icon, required this.label, required this.onTap, this.isDestructive = false});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white70),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDestructive ? Colors.redAccent : Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String label; final String value; final String actionLabel; final VoidCallback onAction;
  const _InfoRow({required this.icon, required this.label, required this.value, required this.actionLabel, required this.onAction});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, color: Colors.white70), const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
        ])),
        const SizedBox(width: 12),
        OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
      ]),
    );
  }
}

class _Badge extends StatelessWidget { final String text; const _Badge({required this.text}); @override Widget build(BuildContext context) { return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(8)), child: Text(text)); } }

class _PaymentMethodRow extends StatelessWidget {
  final String brand; final String last4; final bool isDefault;
  const _PaymentMethodRow({required this.brand, required this.last4, required this.isDefault});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.credit_card, color: Colors.white70), const SizedBox(width: 8),
        Expanded(child: Text('$brand •••• $last4')),
        if (isDefault) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8)), child: const Text('Standard')),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: () {}, child: const Text('Entfernen')),
      ]),
    );
  }
}

class _InvoicesPage extends StatelessWidget {
  const _InvoicesPage();
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: Container(color: Colors.black.withValues(alpha: 0.35)))),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Rechnungen & Belege'),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (_, i) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
            child: Row(children: [
              const Icon(Icons.receipt_long_outlined, color: Colors.white70), const SizedBox(width: 12),
              const Expanded(child: Text('01.08.2025 · 39,90 € · Buchung #SIT-12345')),
              TextButton(onPressed: () {}, child: const Text('Details')),
            ]),
          ),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: 8,
        ),
      ),
    ]);
  }
}

class _PrivacyText extends StatelessWidget {
  const _PrivacyText();
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.5);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('• Profil ist öffentlich sichtbar (wie im Screenshot).'),
      const SizedBox(height: 8),
      Text('• E‑Mail und Telefonnummer sind niemals öffentlich.'),
      const SizedBox(height: 8),
      Text('• Chat wird erst nach angenommener Anfrage freigeschaltet.'),
      const SizedBox(height: 8),
      Text('• Foto-Doku Übergabe/Rückgabe ist verpflichtend.'),
      const SizedBox(height: 8),
      Text('• Später: Datenexport anfordern.'),
    ].map((w) => DefaultTextStyle(style: style!, child: w)).toList());
  }
}
