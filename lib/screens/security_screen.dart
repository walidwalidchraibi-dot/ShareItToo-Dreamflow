import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:lendify/models/security.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/screens/verification_intro_screen.dart';
import 'package:lendify/screens/verification_screen.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/theme.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  User? _user;
  bool _loading = true;

  // Password
  final _currentCtrl = TextEditingController();
  final _nextCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _pwBusy = false;
  bool _pwObscureCurrent = true;
  bool _pwObscureNext = true;
  bool _pwObscureConfirm = true;

  // 2FA
  bool _twoFactorEnabled = false;
  String _twoFactorMethod = 'sms';
  bool _twoFactorBusy = false;

  // Devices
  List<SecurityDevice> _devices = const [];
  bool _devicesBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _nextCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final u = await DataService.getCurrentUser();
      final s = await DataService.getSecuritySettings();
      final d = await DataService.getSignedInDevices();
      if (!mounted) return;
      setState(() {
        _user = u;
        _twoFactorEnabled = s.enabled;
        _twoFactorMethod = s.method;
        _devices = d;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[SecurityScreen] load failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool get _passwordValid {
    final current = _currentCtrl.text;
    final next = _nextCtrl.text;
    final confirm = _confirmCtrl.text;
    return current.isNotEmpty && _validateNewPassword(next) == null && next == confirm;
  }

  String? _validateNewPassword(String v) {
    final s = v.trim();
    if (s.length < 8) return 'Mindestens 8 Zeichen';
    final hasNumber = RegExp(r'\d').hasMatch(s);
    // Raw-string regex to avoid escaping hell; include common special chars.
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>\[\]\\/\-_=+;`~]').hasMatch(s);
    if (!hasNumber) return 'Mindestens eine Zahl';
    if (!hasSpecial) return 'Mindestens ein Sonderzeichen';
    return null;
  }

  Future<void> _changePassword() async {
    if (!_passwordValid || _pwBusy) return;
    setState(() => _pwBusy = true);
    try {
      // No backend connected – this is a demo flow.
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      _currentCtrl.clear();
      _nextCtrl.clear();
      _confirmCtrl.clear();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwort geändert (Demo).')),
      );
    } catch (e) {
      debugPrint('[SecurityScreen] changePassword failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwort konnte nicht geändert werden.')),
      );
    } finally {
      if (mounted) setState(() => _pwBusy = false);
    }
  }

  Future<void> _toggleTwoFactor(bool enabled) async {
    if (_twoFactorBusy) return;
    setState(() => _twoFactorBusy = true);
    try {
      final next = SecuritySettings(enabled: enabled, method: _twoFactorMethod);
      await DataService.setSecuritySettings(next);
      if (!mounted) return;
      setState(() => _twoFactorEnabled = enabled);
    } catch (e) {
      debugPrint('[SecurityScreen] setSecuritySettings failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konnte 2FA nicht speichern.')));
    } finally {
      if (mounted) setState(() => _twoFactorBusy = false);
    }
  }

  Future<void> _openTwoFactorSetupSheet() async {
    if (_twoFactorBusy) return;
    final theme = Theme.of(context);
    final chosen = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _TwoFactorSetupSheet(
          initialMethod: _twoFactorMethod,
          primary: theme.colorScheme.primary,
        );
      },
    );
    if (!mounted || chosen == null) return;
    await _setTwoFactorMethod(chosen);
    if (!mounted) return;
    await _toggleTwoFactor(true);
  }

  Future<void> _setTwoFactorMethod(String method) async {
    if (_twoFactorBusy) return;
    setState(() {
      _twoFactorMethod = method;
      _twoFactorBusy = true;
    });
    try {
      await DataService.setSecuritySettings(SecuritySettings(enabled: _twoFactorEnabled, method: method));
    } catch (e) {
      debugPrint('[SecurityScreen] setTwoFactorMethod failed: $e');
    } finally {
      if (mounted) setState(() => _twoFactorBusy = false);
    }
  }

  Future<void> _signOutDevice(SecurityDevice device) async {
    if (_devicesBusy) return;
    final ok = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            title: const Text('Gerät abmelden?'),
            content: Text('Du wirst auf „${device.name}“ abgemeldet.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abmelden')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    setState(() => _devicesBusy = true);
    try {
      final next = _devices.where((d) => d.id != device.id).toList();
      await DataService.setSignedInDevices(next);
      if (!mounted) return;
      setState(() => _devices = next);
    } catch (e) {
      debugPrint('[SecurityScreen] signOutDevice failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerät konnte nicht abgemeldet werden.')));
    } finally {
      if (mounted) setState(() => _devicesBusy = false);
    }
  }

  void _openVerification() {
    final verified = _user?.isVerified == true;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => verified ? const VerificationScreen() : const VerificationIntroScreen()),
    );
  }

  String _deviceNameThisPlatform() {
    if (kIsWeb) return 'Browser';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'iPhone';
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.macOS:
        return 'Mac';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Gerät';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verified = _user?.isVerified == true;
    final primary = theme.colorScheme.primary;

    return Stack(children: [
      Positioned.fill(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(color: Colors.black.withValues(alpha: 0.35)),
        ),
      ),
      Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text('Sicherheit'),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                top: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 18, 16, 22),
                  children: [
                    Text('Sicherheit', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      'Schütze dein Konto und bestätige deine Identität, um Vertrauen auf der Plattform aufzubauen.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.45),
                    ),
                    const SizedBox(height: 18),

                    _SectionHeader(title: 'Identitätsverifizierung', icon: Icons.verified_user_outlined),
                    const SizedBox(height: 10),
                    _SectionCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _StatusPill(
                          icon: verified ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          label: verified ? 'Verifiziert' : 'Nicht verifiziert',
                          tone: verified ? _PillTone.success : _PillTone.danger,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Eine verifizierte Identität erhöht das Vertrauen zwischen Mietern und Vermietern.',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.45),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _openVerification,
                          icon: const Icon(Icons.badge_outlined, color: Colors.white),
                          label: Text(verified ? 'Verifizierung ansehen' : 'Identität verifizieren', style: const TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(height: 10),
                        _MiniBullets(items: const [
                          'Ausweisdokument hochladen',
                          'Selfie‑Verifizierung',
                          'Automatische Identitätsprüfung',
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 18),

                    _SectionHeader(title: 'Passwort', icon: Icons.lock_outline),
                    const SizedBox(height: 10),
                    _SectionCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        TextField(
                          controller: _currentCtrl,
                          obscureText: _pwObscureCurrent,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                            labelText: 'Aktuelles Passwort',
                            suffixIcon: IconButton(
                              tooltip: _pwObscureCurrent ? 'Anzeigen' : 'Verbergen',
                              onPressed: () => setState(() => _pwObscureCurrent = !_pwObscureCurrent),
                              icon: Icon(_pwObscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nextCtrl,
                          obscureText: _pwObscureNext,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.password_outlined),
                            labelText: 'Neues Passwort',
                            errorText: _nextCtrl.text.isEmpty ? null : _validateNewPassword(_nextCtrl.text),
                            suffixIcon: IconButton(
                              tooltip: _pwObscureNext ? 'Anzeigen' : 'Verbergen',
                              onPressed: () => setState(() => _pwObscureNext = !_pwObscureNext),
                              icon: Icon(_pwObscureNext ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmCtrl,
                          obscureText: _pwObscureConfirm,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.check_circle_outline),
                            labelText: 'Neues Passwort bestätigen',
                            errorText: _confirmCtrl.text.isEmpty
                                ? null
                                : (_confirmCtrl.text == _nextCtrl.text ? null : 'Passwörter stimmen nicht überein'),
                            suffixIcon: IconButton(
                              tooltip: _pwObscureConfirm ? 'Anzeigen' : 'Verbergen',
                              onPressed: () => setState(() => _pwObscureConfirm = !_pwObscureConfirm),
                              icon: Icon(_pwObscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _MiniBullets(items: const ['Mindestens 8 Zeichen', 'Mindestens eine Zahl', 'Mindestens ein Sonderzeichen']),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _passwordValid && !_pwBusy ? _changePassword : null,
                          style: FilledButton.styleFrom(backgroundColor: primary),
                          child: _pwBusy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Passwort ändern', style: TextStyle(color: Colors.white)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 18),

                    _SectionHeader(title: 'Zwei‑Faktor‑Authentifizierung', icon: Icons.phonelink_lock_outlined),
                    const SizedBox(height: 10),
                    _SectionCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text(
                          'Aktiviere eine zusätzliche Sicherheitsebene für dein Konto.',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.45),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: _StatusPill(
                              icon: _twoFactorEnabled ? Icons.check_circle_rounded : Icons.remove_circle_outline,
                              label: _twoFactorEnabled ? 'Aktiviert' : 'Deaktiviert',
                              tone: _twoFactorEnabled ? _PillTone.success : _PillTone.neutral,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_twoFactorEnabled)
                            TextButton(
                              onPressed: _twoFactorBusy ? null : () => _toggleTwoFactor(false),
                              child: const Text('Deaktivieren', style: TextStyle(color: Colors.white)),
                            ),
                        ]),
                        const SizedBox(height: 12),
                        if (_twoFactorEnabled)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                            ),
                            child: Row(children: [
                              Icon(
                                _twoFactorMethod == 'sms' ? Icons.sms_outlined : Icons.shield_outlined,
                                color: primary,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _twoFactorMethod == 'sms' ? 'Methode: SMS‑Code' : 'Methode: Authenticator‑App',
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.35),
                                ),
                              ),
                              TextButton(
                                onPressed: _twoFactorBusy
                                    ? null
                                    : () async {
                                        final method = await showModalBottomSheet<String>(
                                          context: context,
                                          useSafeArea: true,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (ctx) => _TwoFactorSetupSheet(
                                            initialMethod: _twoFactorMethod,
                                            primary: primary,
                                            showEnableButton: false,
                                          ),
                                        );
                                        if (!mounted || method == null) return;
                                        await _setTwoFactorMethod(method);
                                      },
                                child: const Text('Ändern', style: TextStyle(color: Colors.white)),
                              ),
                            ]),
                          )
                        else
                          FilledButton.icon(
                            onPressed: _twoFactorBusy ? null : _openTwoFactorSetupSheet,
                            icon: const Icon(Icons.verified_user_outlined, color: Colors.white),
                            label: const Text('2‑Faktor‑Authentifizierung aktivieren', style: TextStyle(color: Colors.white)),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 18),

                    _SectionHeader(title: 'Angemeldete Geräte', icon: Icons.devices_outlined),
                    const SizedBox(height: 10),
                    _SectionCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text(
                          'Hier siehst du, auf welchen Geräten dein Konto aktuell angemeldet ist.',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.45),
                        ),
                        const SizedBox(height: 12),
                        if (_devices.isEmpty)
                          Text('Keine Geräte gefunden.', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60))
                        else
                          for (final d in _devices) ...[
                            _DeviceTile(
                              device: d,
                              isThisDevice: d.isThisDevice,
                              onSignOut: (d.isThisDevice || _devicesBusy) ? null : () => _signOutDevice(d),
                            ),
                            if (d.id != _devices.last.id)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.10)),
                              ),
                          ],
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Dieses Gerät: ${_deviceNameThisPlatform()}',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.info_outline_rounded, color: primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Teile dein Passwort niemals mit anderen und überprüfe regelmäßig deine Sicherheits­einstellungen.',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.45),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
      ),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Icon(icon, size: 18, color: theme.colorScheme.primary),
      const SizedBox(width: 10),
      Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
    ]);
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: child,
    );
  }
}

enum _PillTone { success, danger, neutral }

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final _PillTone tone;
  const _StatusPill({required this.icon, required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color bg;
    final Color border;
    final Color fg;
    switch (tone) {
      case _PillTone.success:
        bg = BrandColors.success.withValues(alpha: 0.18);
        border = BrandColors.success.withValues(alpha: 0.35);
        fg = BrandColors.success;
        break;
      case _PillTone.danger:
        bg = BrandColors.danger.withValues(alpha: 0.18);
        border = BrandColors.danger.withValues(alpha: 0.35);
        fg = BrandColors.danger;
        break;
      case _PillTone.neutral:
        bg = Colors.white.withValues(alpha: 0.08);
        border = Colors.white.withValues(alpha: 0.14);
        fg = theme.colorScheme.primary;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 8),
        Flexible(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
      ]),
    );
  }
}

class _MiniBullets extends StatelessWidget {
  final List<String> items;
  const _MiniBullets({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final t in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.check_rounded, size: 16, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(t, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.35))),
            ]),
          ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final SecurityDevice device;
  final bool isThisDevice;
  final VoidCallback? onSignOut;
  const _DeviceTile({required this.device, required this.isThisDevice, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.22)),
        ),
        child: Center(child: Icon(device.icon, color: theme.colorScheme.primary, size: 18)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                device.name + (isThisDevice ? ' (Dieses Gerät)' : ''),
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            if (onSignOut != null)
              TextButton(
                onPressed: onSignOut,
                child: const Text('Abmelden', style: TextStyle(color: Colors.white)),
              ),
          ]),
          const SizedBox(height: 2),
          Text(
            '${device.location} · ${device.lastActiveLabel}',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ]),
      ),
    ]);
  }
}

class _TwoFactorSetupSheet extends StatefulWidget {
  final String initialMethod;
  final Color primary;
  final bool showEnableButton;
  const _TwoFactorSetupSheet({required this.initialMethod, required this.primary, this.showEnableButton = true});

  @override
  State<_TwoFactorSetupSheet> createState() => _TwoFactorSetupSheetState();
}

class _TwoFactorSetupSheetState extends State<_TwoFactorSetupSheet> {
  late String _method;

  @override
  void initState() {
    super.initState();
    _method = widget.initialMethod;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: MediaQuery.viewInsetsOf(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('2‑Faktor‑Authentifizierung', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            IconButton(
              tooltip: 'Schließen',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Wähle eine Methode. Beim Login musst du dann zusätzlich einen Code bestätigen.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 14),
          _TwoFactorMethodTile(
            title: 'SMS‑Code',
            subtitle: 'Code wird per SMS gesendet.',
            icon: Icons.sms_outlined,
            primary: widget.primary,
            selected: _method == 'sms',
            onTap: () => setState(() => _method = 'sms'),
          ),
          const SizedBox(height: 10),
          _TwoFactorMethodTile(
            title: 'Authenticator‑App',
            subtitle: 'Bestätigung über z. B. Google Authenticator.',
            icon: Icons.shield_outlined,
            primary: widget.primary,
            selected: _method == 'auth',
            onTap: () => setState(() => _method = 'auth'),
          ),
          const SizedBox(height: 16),
          if (widget.showEnableButton)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_method),
              style: FilledButton.styleFrom(backgroundColor: widget.primary),
              child: const Text('Aktivieren', style: TextStyle(color: Colors.white)),
            )
          else
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_method),
              style: FilledButton.styleFrom(backgroundColor: widget.primary),
              child: const Text('Speichern', style: TextStyle(color: Colors.white)),
            ),
        ]),
      ),
    );
  }
}

class _TwoFactorMethodTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color primary;
  final bool selected;
  final VoidCallback onTap;
  const _TwoFactorMethodTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primary,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? primary.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? primary.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? primary.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? primary.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.10)),
              ),
              child: Center(child: Icon(icon, color: selected ? primary : Colors.white70, size: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.35)),
              ]),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              child: selected
                  ? const Icon(Icons.check_circle_rounded, key: ValueKey('on'), color: Colors.white)
                  : Icon(Icons.circle_outlined, key: const ValueKey('off'), color: Colors.white.withValues(alpha: 0.35)),
            ),
          ]),
        ),
      ),
    );
  }
}


