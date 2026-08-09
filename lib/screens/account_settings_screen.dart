import 'package:flutter/material.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/models/user.dart';
import 'package:provider/provider.dart';
import 'package:lendify/screens/profile_info_screen.dart';
import 'package:lendify/screens/contact_data_screen.dart';
import 'package:lendify/screens/change_password_screen.dart';
import 'package:lendify/screens/payment_methods_screen.dart';
import 'package:lendify/screens/stripe_payout_account_screen.dart';
import 'package:lendify/screens/invoices_screen.dart';
import 'package:lendify/screens/notifications_screen.dart';
import 'package:lendify/screens/privacy_info_screen.dart';
import 'package:lendify/navigation/main_nav_controller.dart';
import 'package:lendify/screens/account_deleted_screen.dart';
import 'package:lendify/services/account_deletion_service.dart';
import 'package:lendify/widgets/account_deletion_dialog.dart';
import 'package:lendify/screens/background_settings_screen.dart';
import 'package:lendify/screens/blocked_users_screen.dart';
import 'package:lendify/screens/moderation_admin_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  User? _user;
  bool _loading = true;
  bool _deleteBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await DataService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _user = u;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
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
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _GroupTitle('PROFIL'),
                    _SectionCard(children: [
                      _RowTile(
                        icon: Icons.badge_outlined,
                        label: l10n.t('Profilinformationen'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ProfileInfoScreen())),
                      ),
                      const _Divider(),
                      _RowTile(
                        icon: Icons.mail_outline,
                        label: l10n.t('account.item.contactData'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ContactDataScreen())),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    const _GroupTitle('SICHERHEIT'),
                    _SectionCard(children: [
                      _RowTile(
                        icon: Icons.verified_user_outlined,
                        label: 'Identitätsprüfung',
                        subtitle:
                            'Noch nicht verfügbar – ein geprüfter Anbieter wird vor dem Produktionsstart angebunden.',
                      ),
                      const _Divider(),
                      _RowTile(
                        icon: Icons.lock_outline,
                        label: l10n.t('account.item.changePassword'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ChangePasswordScreen())),
                      ),
                      const _Divider(),
                      _RowTile(
                        icon: Icons.phonelink_lock_outlined,
                        label: 'Zwei‑Faktor‑Authentifizierung',
                        subtitle:
                            'Noch nicht verfügbar – die sichere Server-Anbindung folgt vor dem Produktionsstart.',
                      ),
                    ]),
                    const SizedBox(height: 28),
                    const _GroupTitle('ZAHLUNGEN'),
                    _SectionCard(children: [
                      _RowTile(
                        icon: Icons.credit_card,
                        label: l10n.t('account.item.paymentMethods'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const PaymentMethodsScreen())),
                      ),
                      const _Divider(),
                      _RowTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: l10n.t('account.item.payoutMethods'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const StripePayoutAccountScreen())),
                      ),
                      const _Divider(),
                      _RowTile(
                        icon: Icons.receipt_long_outlined,
                        label: l10n.t('account.item.invoices'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const InvoicesScreen())),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    const _GroupTitle('BENACHRICHTIGUNGEN'),
                    _SectionCard(children: [
                      _RowTile(
                        icon: Icons.notifications_active_outlined,
                        label: l10n.t('account.item.notifications'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const NotificationsScreen())),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    const _GroupTitle('DESIGN'),
                    _SectionCard(children: [
                      _RowTile(
                        icon: Icons.wallpaper_outlined,
                        label: 'Hintergrund',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const BackgroundSettingsScreen()),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    if (const {'support', 'admin'}.contains(_user?.role)) ...[
                      const _GroupTitle('BETRIEB'),
                      _SectionCard(children: [
                        _RowTile(
                          icon: Icons.admin_panel_settings_outlined,
                          label: _user?.role == 'admin'
                              ? 'Administration & Moderation'
                              : 'Support & Moderation',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ModerationAdminScreen(
                                role: _user?.role ?? 'support',
                              ),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 28),
                    ],
                    const _GroupTitle('DATENSCHUTZ'),
                    _SectionCard(children: [
                      _RowTile(
                        icon: Icons.block_outlined,
                        label: 'Blockierte Nutzer',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BlockedUsersScreen(),
                          ),
                        ),
                      ),
                      const _Divider(),
                      _RowTile(
                        icon: Icons.shield_outlined,
                        label: l10n.t('account.item.dataPrivacyInfo'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const PrivacyInfoScreen())),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    const _GroupTitle('KONTO'),
                    _SectionCard(children: [
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
    if (_deleteBusy) return;
    _showDeleteDialogStep1();
  }

  Future<void> _showDeleteDialogStep1() async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Konto wirklich löschen?',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, a1, a2) {
        return AccountDeletionDialog(
          icon: Icons.delete_outline,
          title: 'Konto wirklich löschen?',
          body: const _DeleteAccountStep1Body(),
          leftAction: AccountDeletionDialogAction(
              label: 'Abbrechen',
              onPressed: () =>
                  Navigator.of(ctx, rootNavigator: true).maybePop()),
          rightAction: AccountDeletionDialogAction(
            label: 'Konto endgültig löschen',
            isDestructive: true,
            onPressed: () {
              Navigator.of(ctx, rootNavigator: true).maybePop();
              _showDeleteDialogStep2();
            },
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        final t = Curves.easeOutCubic.transform(anim.value);
        return Opacity(
            opacity: anim.value,
            child: Transform.scale(scale: 0.96 + (0.04 * t), child: child));
      },
    );
  }

  Future<void> _showDeleteDialogStep2() async {
    if (!mounted) return;
    final ctrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool confirmed = false;
    String confirmedPassword = '';

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Bist du sicher?',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, a1, a2) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AccountDeletionDialog(
              icon: Icons.warning_amber_rounded,
              title: 'Bist du sicher?',
              body: _DeleteAccountStep2Body(
                controller: ctrl,
                passwordController: passwordCtrl,
                onChanged: (_) => setLocalState(() {}),
              ),
              leftAction: AccountDeletionDialogAction(
                  label: 'Zurück',
                  onPressed: () =>
                      Navigator.of(ctx, rootNavigator: true).maybePop()),
              rightAction: AccountDeletionDialogAction(
                label: 'Ja, Konto endgültig löschen',
                isDestructive: true,
                onPressed: ctrl.text.trim().toUpperCase() == 'LÖSCHEN' &&
                        passwordCtrl.text.isNotEmpty
                    ? () {
                        confirmed = true;
                        confirmedPassword = passwordCtrl.text;
                        Navigator.of(ctx, rootNavigator: true).maybePop();
                      }
                    : null,
              ),
            );
          },
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        final t = Curves.easeOutCubic.transform(anim.value);
        return Opacity(
            opacity: anim.value,
            child: Transform.scale(scale: 0.96 + (0.04 * t), child: child));
      },
    );

    ctrl.dispose();
    passwordCtrl.dispose();
    if (!mounted || !confirmed) return;
    await _runPreflightAndDelete(confirmedPassword);
  }

  Future<void> _runPreflightAndDelete(String currentPassword) async {
    final user = _user ?? await DataService.getCurrentUser();
    if (user == null) return;
    setState(() => _deleteBusy = true);
    try {
      final result = await AccountDeletionService.preflightCheck(user);
      if (!mounted) return;

      if (!result.canDelete) {
        await _showDeleteBlockedDialog(result.blockers);
        return;
      }

      await AccountDeletionService.deleteAccount(
        user: user,
        currentPassword: currentPassword,
      );
      if (!mounted) return;

      // After deletion: jump to success screen and reset tab to Explore.
      context.read<MainNavController>().setIndex(0);
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AccountDeletedScreen()),
        (r) => r.isFirst,
      );
    } catch (e) {
      // Keep error visible but not overly technical.
      if (!mounted) return;
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Fehler',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (ctx, a1, a2) {
          return AccountDeletionDialog(
            icon: Icons.error_outline,
            title: 'Löschen nicht möglich',
            body: const Text(
              'Es ist ein Fehler aufgetreten. Bitte versuche es später erneut.',
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
            leftAction: AccountDeletionDialogAction(
                label: 'OK',
                onPressed: () =>
                    Navigator.of(ctx, rootNavigator: true).maybePop()),
            rightAction: AccountDeletionDialogAction(
                label: 'Schließen',
                onPressed: () =>
                    Navigator.of(ctx, rootNavigator: true).maybePop()),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _deleteBusy = false);
    }
  }

  Future<void> _showDeleteBlockedDialog(
      List<AccountDeletionBlocker> blockers) async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Konto kann aktuell nicht gelöscht werden',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, a1, a2) {
        return AccountDeletionDialog(
          icon: Icons.info_outline,
          title: 'Konto kann aktuell nicht gelöscht werden',
          body: _DeleteBlockedBody(blockers: blockers),
          leftAction: AccountDeletionDialogAction(
              label: 'Schließen',
              onPressed: () =>
                  Navigator.of(ctx, rootNavigator: true).maybePop()),
          rightAction: AccountDeletionDialogAction(
            label: 'Zu meinen Buchungen',
            onPressed: () {
              Navigator.of(ctx, rootNavigator: true).maybePop();
              context.read<MainNavController>().setIndex(2);
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        final t = Curves.easeOutCubic.transform(anim.value);
        return Opacity(
            opacity: anim.value,
            child: Transform.scale(scale: 0.96 + (0.04 * t), child: child));
      },
    );
  }
}

class _DeleteAccountStep1Body extends StatelessWidget {
  const _DeleteAccountStep1Body();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final style =
        t.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.5);
    final bulletStyle = t.textTheme.bodyMedium?.copyWith(
        color: Colors.white, height: 1.5, fontWeight: FontWeight.w700);

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Du kannst dein Konto nur löschen, wenn:',
            style: style,
          ),
          const SizedBox(height: 10),
          _Bullet(
              text: 'keine laufenden Buchungen bestehen', style: bulletStyle),
          _Bullet(
              text: 'keine kommenden Buchungen geplant sind',
              style: bulletStyle),
          _Bullet(
              text: 'keine laufenden Anmietungen bestehen', style: bulletStyle),
          _Bullet(
              text: 'keine offenen Zahlungen oder Auszahlungen vorhanden sind',
              style: bulletStyle),
          const SizedBox(height: 12),
          Text(
            'Nach der Löschung wird dein Konto dauerhaft deaktiviert. Deine personenbezogenen Daten werden gemäß unseren Datenschutzrichtlinien gelöscht oder anonymisiert, sofern keine gesetzlichen Aufbewahrungspflichten bestehen.\n\nDiese Aktion kann nicht rückgängig gemacht werden.',
            style: style,
          ),
        ]);
  }
}

class _DeleteAccountStep2Body extends StatelessWidget {
  final TextEditingController controller;
  final TextEditingController passwordController;
  final ValueChanged<String> onChanged;
  const _DeleteAccountStep2Body(
      {required this.controller,
      required this.passwordController,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final style =
        t.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.5);
    final bulletStyle = t.textTheme.bodyMedium?.copyWith(
        color: Colors.white, height: 1.5, fontWeight: FontWeight.w700);
    final enabled = controller.text.trim().toUpperCase() == 'LÖSCHEN';

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Wenn du dein Konto löschst:', style: style),
          const SizedBox(height: 10),
          _Bullet(text: 'wird dein Profil deaktiviert', style: bulletStyle),
          _Bullet(
              text: 'deine aktiven Angebote werden entfernt',
              style: bulletStyle),
          _Bullet(
              text: 'du kannst dich nicht mehr einloggen', style: bulletStyle),
          _Bullet(
              text: 'Bewertungen bleiben anonymisiert erhalten',
              style: bulletStyle),
          const SizedBox(height: 12),
          Text('Diese Aktion ist endgültig.', style: style),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: 'Zum Bestätigen „LÖSCHEN“ eingeben',
                hintStyle: const TextStyle(
                    color: Colors.white60, fontWeight: FontWeight.w600),
                prefixIcon: Icon(enabled ? Icons.check : Icons.lock_outline,
                    color: enabled ? t.colorScheme.primary : Colors.white70),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.02),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: TextField(
              controller: passwordController,
              onChanged: onChanged,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                hintText: 'Aktuelles Passwort',
                prefixIcon: const Icon(Icons.password_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.02),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
              'Das Passwort schützt vor einer Löschung durch eine fremde Person mit offenem Gerät.',
              style: t.textTheme.labelSmall
                  ?.copyWith(color: Colors.white60, height: 1.4)),
        ]);
  }
}

class _DeleteBlockedBody extends StatelessWidget {
  final List<AccountDeletionBlocker> blockers;
  const _DeleteBlockedBody({required this.blockers});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final style =
        t.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.5);
    final bulletStyle = t.textTheme.bodyMedium?.copyWith(
        color: Colors.white, height: 1.5, fontWeight: FontWeight.w700);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Du hast noch aktive Aktivitäten auf ShareItToo:', style: style),
          const SizedBox(height: 10),
          for (final b in blockers.take(6))
            _Bullet(text: b.label, style: bulletStyle),
          if (blockers.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('… und weitere',
                  style:
                      t.textTheme.labelSmall?.copyWith(color: Colors.white60)),
            ),
          const SizedBox(height: 12),
          Text('Bitte schließe diese zuerst ab.', style: style),
        ]);
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const _Bullet({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: SizedBox(
              width: 6,
              height: 6,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: Colors.white70, shape: BoxShape.circle))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: style)),
      ]),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final String title;
  const _GroupTitle(this.title);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        title,
        style: style?.copyWith(
          color: Colors.white70,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: Colors.white24);
}

class _RowTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback? onTap;
  const _RowTile(
      {required this.icon,
      required this.label,
      this.subtitle,
      this.onTap,
      this.isDestructive = false});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading:
          Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white70),
      title: Text(label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDestructive
                  ? Colors.redAccent
                  : (onTap == null ? Colors.white60 : Colors.white))),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white54),
            ),
      trailing: onTap == null
          ? const Icon(Icons.info_outline, color: Colors.white38)
          : const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }
}
