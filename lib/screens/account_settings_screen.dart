import 'package:flutter/material.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/models/user.dart';
import 'package:provider/provider.dart';
import 'package:lendify/screens/profile_info_screen.dart';
import 'package:lendify/screens/contact_data_screen.dart';
import 'package:lendify/screens/verification_screen.dart';
import 'package:lendify/screens/change_password_screen.dart';
import 'package:lendify/screens/payment_methods_screen.dart';
import 'package:lendify/screens/payout_methods_screen.dart';
import 'package:lendify/screens/invoices_screen.dart';
import 'package:lendify/screens/notifications_screen.dart';
import 'package:lendify/screens/privacy_info_screen.dart';

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
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactDataScreen())),
            ),
          ]),
          const SizedBox(height: 16),
          if ((user?.isVerified ?? false)) _SectionCard(children: [
            _RowTile(
              icon: Icons.verified_outlined,
              label: l10n.t('account.item.verification'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VerificationScreen())),
            ),
          ]),
          if ((user?.isVerified ?? false)) const SizedBox(height: 16),
          _SectionCard(children: [
            _RowTile(
              icon: Icons.lock_outline,
              label: l10n.t('account.item.changePassword'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
            ),
          ]),
          const SizedBox(height: 16),
          _SectionCard(children: [
            _RowTile(
              icon: Icons.credit_card,
              label: l10n.t('account.item.paymentMethods'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentMethodsScreen())),
            ),
            const _Divider(),
            _RowTile(
              icon: Icons.account_balance_wallet_outlined,
              label: l10n.t('account.item.payoutMethods'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayoutMethodsScreen())),
            ),
            const _Divider(),
            _RowTile(
              icon: Icons.receipt_long_outlined,
              label: l10n.t('account.item.invoices'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvoicesScreen())),
            ),
          ]),
          const SizedBox(height: 16),
          _SectionCard(children: [
            _RowTile(
              icon: Icons.notifications_active_outlined,
              label: l10n.t('account.item.notifications'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
          ]),
          const SizedBox(height: 16),
          _SectionCard(children: [
            _RowTile(
              icon: Icons.shield_outlined,
              label: l10n.t('account.item.dataPrivacyInfo'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyInfoScreen())),
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
