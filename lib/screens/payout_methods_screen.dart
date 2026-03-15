import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lendify/models/payout_method.dart';
import 'package:lendify/services/payout_methods_service.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/blur_modal.dart';

class PayoutMethodsScreen extends StatefulWidget {
  const PayoutMethodsScreen({super.key});
  @override
  State<PayoutMethodsScreen> createState() => _PayoutMethodsScreenState();
}

class _PayoutMethodsScreenState extends State<PayoutMethodsScreen> {
  bool _loading = true;
  List<PayoutMethod> _methods = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final methods = await PayoutMethodsService.getPayoutMethods();
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[PayoutMethodsScreen] load failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openAddFlow() async {
    final choice = await showBlurBottomSheet<_AddPayoutChoice>(
      context,
      child: SheetScaffold(
        title: 'Auszahlungsmethode hinzufügen',
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _ChoiceTile(
            icon: Icons.account_balance_outlined,
            title: 'Bankkonto hinzufügen',
            subtitle: 'SEPA (IBAN)',
            onTap: () => Navigator.of(context).pop(_AddPayoutChoice.bank),
          ),
          const SizedBox(height: 10),
          _ChoiceTile(
            icon: Icons.paypal,
            title: 'PayPal verbinden',
            subtitle: 'E-Mail Adresse',
            onTap: () => Navigator.of(context).pop(_AddPayoutChoice.paypal),
          ),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _AddPayoutChoice.bank:
        await showBlurBottomSheet<void>(context, child: _AddBankAccountSheet(onSaved: _handleSaved));
        break;
      case _AddPayoutChoice.paypal:
        await showBlurBottomSheet<void>(context, child: _AddPaypalSheet(onSaved: _handleSaved));
        break;
    }
  }

  Future<void> _handleSaved(PayoutMethod method) async {
    try {
      final updated = await PayoutMethodsService.add(method);
      if (!mounted) return;
      setState(() => _methods = updated);
      if (Navigator.of(context).canPop()) Navigator.of(context).maybePop();
      await AppPopup.toast(context, icon: Icons.check_circle_outline, title: 'Auszahlungsmethode hinzugefügt');
    } catch (e) {
      debugPrint('[PayoutMethodsScreen] save failed: $e');
      if (!mounted) return;
      await AppPopup.toast(context, icon: Icons.error_outline, title: 'Speichern fehlgeschlagen');
    }
  }

  Future<void> _setDefault(String id) async {
    try {
      final updated = await PayoutMethodsService.setDefault(id);
      if (!mounted) return;
      setState(() => _methods = updated);
    } catch (e) {
      debugPrint('[PayoutMethodsScreen] setDefault failed: $e');
    }
  }

  Future<void> _remove(String id) async {
    final method = _methods.where((m) => m.id == id).cast<PayoutMethod?>().firstOrNull;
    await AppPopup.show(
      context,
      icon: Icons.delete_outline,
      title: 'Entfernen?',
      message: method == null ? 'Diese Auszahlungsmethode wird entfernt.' : '„${method.label}“ wird entfernt.',
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(), child: const Text('Abbrechen')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Colors.white),
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).maybePop();
            try {
              final updated = await PayoutMethodsService.remove(id);
              if (!mounted) return;
              setState(() => _methods = updated);
              await AppPopup.toast(context, icon: Icons.check_circle_outline, title: 'Entfernt');
            } catch (e) {
              debugPrint('[PayoutMethodsScreen] remove failed: $e');
              if (!mounted) return;
              await AppPopup.toast(context, icon: Icons.error_outline, title: 'Entfernen fehlgeschlagen');
            }
          },
          child: const Text('Entfernen'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

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
          title: const Text(''),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SizedBox(height: 4),
                    Text('Auszahlungsmethoden', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: onSurface)),
                    const SizedBox(height: 12),

                    if (_methods.isEmpty) ...[
                      _EmptyStateCard(onAdd: _openAddFlow),
                    ] else ...[
                      for (final m in _methods) ...[
                        _PayoutMethodCard(
                          method: m,
                          onSetDefault: m.isDefault ? null : () => _setDefault(m.id),
                          onRemove: () => _remove(m.id),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],

                    const SizedBox(height: 6),
                    _InfoCard(
                      title: 'Auszahlungen',
                      text: 'Einnahmen aus deinen Vermietungen werden automatisch auf deine Standard-Auszahlungsmethode überwiesen.',
                      subtext: 'Auszahlungen erfolgen in der Regel innerhalb von 1–3 Werktagen nach abgeschlossener Buchung.',
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Auszahlungen erfolgen nur auf verifizierte Auszahlungsmethoden.',
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 14),

                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _openAddFlow,
                        icon: const Icon(Icons.add),
                        label: const Text('Auszahlungsmethode hinzufügen'),
                      ),
                    ),
                  ]),
                ),
        ),
      ),
    ]);
  }
}

enum _AddPayoutChoice { bank, paypal }

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ChoiceTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 10))],
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primary.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Colors.white70),
        ]),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyStateCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: primary.withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.account_balance_outlined, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text('Keine Auszahlungsmethode hinterlegt', textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Füge eine Auszahlungsmethode hinzu, um Einnahmen aus deinen Vermietungen zu erhalten.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onAdd,
            child: const Text('Auszahlungsmethode hinzufügen'),
          ),
        ),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String text;
  final String subtext;
  const _InfoCard({required this.title, required this.text, required this.subtext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.30)),
            ),
            child: const Icon(Icons.info_outline, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 10),
        Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white)),
        const SizedBox(height: 6),
        Text(subtext, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70)),
      ]),
    );
  }
}

class _PayoutMethodCard extends StatelessWidget {
  final PayoutMethod method;
  final VoidCallback? onSetDefault;
  final VoidCallback onRemove;
  const _PayoutMethodCard({required this.method, required this.onSetDefault, required this.onRemove});

  IconData get _icon {
    switch (method.type) {
      case PayoutMethodType.paypal:
        return Icons.paypal;
      case PayoutMethodType.sepa:
        return Icons.account_balance_outlined;
    }
  }

  String get _title => method.type == PayoutMethodType.paypal ? 'PayPal' : 'Bankkonto';

  String get _details {
    if (method.type == PayoutMethodType.paypal) {
      final mail = (method.paypalEmail ?? '').trim();
      return mail.isEmpty ? '—' : mail;
    }
    final iban = (method.iban ?? '').trim();
    if (iban.isEmpty) return '—';
    final last4 = method.last4 ?? (iban.length >= 4 ? iban.substring(iban.length - 4) : iban);
    final cc = iban.length >= 2 ? iban.substring(0, 2).toUpperCase() : '—';
    return '$cc•••••••• $last4';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final danger = theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primary.withValues(alpha: 0.35)),
          ),
          child: Icon(_icon, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(_details, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (method.isDefault)
            _Badge(text: 'Standard', color: primary)
          else
            TextButton(
              onPressed: onSetDefault,
              style: TextButton.styleFrom(
                foregroundColor: primary,
                textStyle: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              child: const Text('Als Standard festlegen'),
            ),
          TextButton(
            onPressed: onRemove,
            style: TextButton.styleFrom(
              foregroundColor: danger,
              textStyle: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            child: const Text('Entfernen'),
          ),
        ]),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }
}

typedef _OnSaved = Future<void> Function(PayoutMethod method);

class _AddBankAccountSheet extends StatefulWidget {
  final _OnSaved onSaved;
  const _AddBankAccountSheet({required this.onSaved});
  @override
  State<_AddBankAccountSheet> createState() => _AddBankAccountSheetState();
}

class _AddBankAccountSheetState extends State<_AddBankAccountSheet> {
  final _holderCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _bicCtrl = TextEditingController();
  bool _saving = false;
  String? _holderErr;
  String? _ibanErr;
  String? _bicErr;

  @override
  void dispose() {
    _holderCtrl.dispose();
    _ibanCtrl.dispose();
    _bicCtrl.dispose();
    super.dispose();
  }

  String _cleanIban(String v) => v.replaceAll(' ', '').toUpperCase();

  bool _isValidBic(String v) {
    final s = v.trim().toUpperCase();
    if (s.isEmpty) return true; // optional
    // ISO 9362: 8 or 11 chars
    return RegExp(r'^[A-Z]{4}[A-Z]{2}[A-Z0-9]{2}([A-Z0-9]{3})?$').hasMatch(s);
  }

  bool _isValidIban(String ibanInput) {
    final iban = _cleanIban(ibanInput);
    if (iban.length < 15 || iban.length > 34) return false;
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(iban)) return false;

    // Country length map for common EU countries (enough for validation UX).
    const lengths = <String, int>{
      'DE': 22,
      'AT': 20,
      'CH': 21,
      'NL': 18,
      'BE': 16,
      'FR': 27,
      'ES': 24,
      'IT': 27,
      'PT': 25,
      'IE': 22,
      'LU': 20,
    };
    final cc = iban.substring(0, 2);
    final expected = lengths[cc];
    if (expected != null && iban.length != expected) return false;

    // MOD-97 check: move first 4 chars to end, convert letters to numbers (A=10..Z=35), then mod 97 == 1.
    final rearranged = iban.substring(4) + iban.substring(0, 4);
    final buf = StringBuffer();
    for (final codeUnit in rearranged.codeUnits) {
      final ch = String.fromCharCode(codeUnit);
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      if (isDigit) {
        buf.write(ch);
      } else {
        final n = codeUnit - 55; // 'A'(65)->10
        if (n < 10 || n > 35) return false;
        buf.write(n.toString());
      }
    }
    final digits = buf.toString();
    int mod = 0;
    for (int i = 0; i < digits.length; i++) {
      mod = (mod * 10 + int.parse(digits[i])) % 97;
    }
    return mod == 1;
  }

  Future<void> _save() async {
    if (_saving) return;
    final holder = _holderCtrl.text.trim();
    final iban = _cleanIban(_ibanCtrl.text);
    final bic = _bicCtrl.text.trim().toUpperCase();

    setState(() {
      _holderErr = holder.isEmpty ? 'Kontoinhaber fehlt' : null;
      _ibanErr = iban.isEmpty
          ? 'IBAN fehlt'
          : (_isValidIban(iban) ? null : 'IBAN ist ungültig');
      _bicErr = _isValidBic(bic) ? null : 'BIC ist ungültig';
    });
    if (_holderErr != null || _ibanErr != null || _bicErr != null) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final last4 = iban.length >= 4 ? iban.substring(iban.length - 4) : iban;
      final method = PayoutMethod(
        id: 'po_${now.microsecondsSinceEpoch}',
        type: PayoutMethodType.sepa,
        isDefault: false,
        label: 'Bankkonto',
        last4: last4,
        holderName: holder,
        iban: iban,
        bic: bic.isEmpty ? null : bic,
        createdAt: now,
        updatedAt: now,
      );
      await widget.onSaved(method);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SheetScaffold(
      title: 'Bankkonto hinzufügen',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _SheetField(
          label: 'Kontoinhaber',
          controller: _holderCtrl,
          errorText: _holderErr,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        _SheetField(
          label: 'IBAN',
          controller: _ibanCtrl,
          errorText: _ibanErr,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.text,
          onChanged: (v) {
            final cleaned = _cleanIban(v);
            if (cleaned != v) {
              final sel = _ibanCtrl.selection;
              _ibanCtrl.value = TextEditingValue(text: cleaned, selection: sel);
            }
          },
        ),
        const SizedBox(height: 10),
        _SheetField(
          label: 'BIC (optional)',
          controller: _bicCtrl,
          errorText: _bicErr,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
      ]),
      bottomBar: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.check),
          label: Text(_saving ? 'Speichere…' : 'Speichern', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _AddPaypalSheet extends StatefulWidget {
  final _OnSaved onSaved;
  const _AddPaypalSheet({required this.onSaved});
  @override
  State<_AddPaypalSheet> createState() => _AddPaypalSheetState();
}

class _AddPaypalSheetState extends State<_AddPaypalSheet> {
  final _emailCtrl = TextEditingController();
  bool _saving = false;
  String? _emailErr;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

  Future<void> _save() async {
    if (_saving) return;
    final mail = _emailCtrl.text.trim();
    setState(() {
      _emailErr = mail.isEmpty ? 'E-Mail fehlt' : (_isValidEmail(mail) ? null : 'E-Mail ist ungültig');
    });
    if (_emailErr != null) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final method = PayoutMethod(
        id: 'po_${now.microsecondsSinceEpoch}',
        type: PayoutMethodType.paypal,
        isDefault: false,
        label: 'PayPal',
        paypalEmail: mail,
        createdAt: now,
        updatedAt: now,
      );
      await widget.onSaved(method);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SheetScaffold(
      title: 'PayPal verbinden',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _SheetField(
          label: 'PayPal E-Mail',
          controller: _emailCtrl,
          errorText: _emailErr,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
      ]),
      bottomBar: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.check),
          label: Text(_saving ? 'Speichere…' : 'Speichern', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  const _SheetField({
    required this.label,
    required this.controller,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
    );
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
      cursorColor: Colors.white,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.70))),
        errorText: errorText,
        errorStyle: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
