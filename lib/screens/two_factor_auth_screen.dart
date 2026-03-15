import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:lendify/models/security.dart';
import 'package:lendify/services/data_service.dart';

/// Optional demo screen for enabling two-factor authentication.
///
/// Backend is not connected in this project, so we persist the setting locally
/// via [DataService].
class TwoFactorAuthScreen extends StatefulWidget {
  const TwoFactorAuthScreen({super.key});

  @override
  State<TwoFactorAuthScreen> createState() => _TwoFactorAuthScreenState();
}

class _TwoFactorAuthScreenState extends State<TwoFactorAuthScreen> {
  bool _loading = true;
  bool _busy = false;

  bool _enabled = false;
  String _method = 'sms';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await DataService.getSecuritySettings();
      if (!mounted) return;
      setState(() {
        _enabled = s.enabled;
        _method = s.method;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[TwoFactorAuthScreen] load failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save({bool? enabled, String? method}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final next = SecuritySettings(enabled: enabled ?? _enabled, method: method ?? _method);
      await DataService.setSecuritySettings(next);
      if (!mounted) return;
      setState(() {
        _enabled = next.enabled;
        _method = next.method;
      });
    } catch (e) {
      debugPrint('[TwoFactorAuthScreen] save failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konnte 2FA nicht speichern.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMethodPicker() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TwoFactorMethodSheet(initialMethod: _method),
    );
    if (!mounted || chosen == null) return;
    await _save(method: chosen, enabled: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          title: const Text('Zwei‑Faktor‑Authentifizierung'),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 18, 16, 22),
                children: [
                  Text('Zwei‑Faktor‑Authentifizierung', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    'Schütze dein Konto mit einer zweiten Bestätigung. Diese Funktion ist aktuell als Demo implementiert (lokal gespeichert).',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            _enabled ? 'Aktiviert' : 'Deaktiviert',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Switch.adaptive(
                          value: _enabled,
                          onChanged: _busy
                              ? null
                              : (v) async {
                                  if (!v) return _save(enabled: false);
                                  await _openMethodPicker();
                                },
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Text(
                        'Beim Login musst du zusätzlich einen Code bestätigen – entweder per SMS oder über eine Authenticator‑App.',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: _enabled ? 1 : 0.55,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: Row(children: [
                            Icon(_method == 'sms' ? Icons.sms_outlined : Icons.shield_outlined, color: primary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _method == 'sms' ? 'Methode: SMS‑Code' : 'Methode: Authenticator‑App',
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.35),
                              ),
                            ),
                            TextButton(
                              onPressed: (!_enabled || _busy) ? null : _openMethodPicker,
                              child: const Text('Ändern', style: TextStyle(color: Colors.white)),
                            ),
                          ]),
                        ),
                      ),
                      if (_busy) ...[
                        const SizedBox(height: 12),
                        const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      ],
                    ]),
                  ),
                ],
              ),
      ),
    ]);
  }
}

class _TwoFactorMethodSheet extends StatefulWidget {
  final String initialMethod;
  const _TwoFactorMethodSheet({required this.initialMethod});

  @override
  State<_TwoFactorMethodSheet> createState() => _TwoFactorMethodSheetState();
}

class _TwoFactorMethodSheetState extends State<_TwoFactorMethodSheet> {
  late String _method;

  @override
  void initState() {
    super.initState();
    _method = widget.initialMethod;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
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
            Expanded(child: Text('Methode wählen', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            IconButton(
              tooltip: 'Schließen',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Wähle eine Methode für den Code beim Login.', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.4)),
          const SizedBox(height: 14),
          _MethodTile(
            title: 'SMS‑Code',
            subtitle: 'Code wird per SMS gesendet.',
            icon: Icons.sms_outlined,
            primary: primary,
            selected: _method == 'sms',
            onTap: () => setState(() => _method = 'sms'),
          ),
          const SizedBox(height: 10),
          _MethodTile(
            title: 'Authenticator‑App',
            subtitle: 'Bestätigung über z. B. Google Authenticator.',
            icon: Icons.shield_outlined,
            primary: primary,
            selected: _method == 'auth',
            onTap: () => setState(() => _method = 'auth'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_method),
            style: FilledButton.styleFrom(backgroundColor: primary),
            child: const Text('Aktivieren', style: TextStyle(color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color primary;
  final bool selected;
  final VoidCallback onTap;
  const _MethodTile({required this.title, required this.subtitle, required this.icon, required this.primary, required this.selected, required this.onTap});

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
