import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lendify/models/payment_method.dart';
import 'package:lendify/services/payment_methods_service.dart';
import 'package:lendify/services/sit_credit_service.dart';
import 'package:lendify/theme.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  bool _loading = true;
  List<PaymentMethod> _methods = const [];

  bool _sitCreditEnabled = false;
  double _sitBalance = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        PaymentMethodsService.getPaymentMethods(),
        SitCreditService.getStatus(),
      ]);

      final items = results[0] as List<PaymentMethod>;
      final sit = results[1] as SitCreditStatus;
      if (!mounted) return;
      setState(() {
        _methods = items;
        _sitCreditEnabled = sit.enabled;
        _sitBalance = sit.balance;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[PaymentMethodsScreen] load failed: $e');
      if (!mounted) return;
      setState(() {
        _methods = const [];
        _sitCreditEnabled = false;
        _sitBalance = 0;
        _loading = false;
      });
    }
  }

  Future<void> _toggleSitCredit(bool value) async {
    if (value && _sitBalance <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Du hast aktuell kein SIT-Guthaben.')),
      );
      return;
    }
    setState(() => _sitCreditEnabled = value);
    await SitCreditService.setEnabled(value);
  }

  String _formatCurrency(double value) {
    final v = value.isFinite ? value : 0.0;
    return '${v.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  Future<void> _setDefault(String id) async {
    final updated = await PaymentMethodsService.setDefault(id);
    if (!mounted) return;
    setState(() => _methods = updated);
  }

  Future<void> _remove(String id) async {
    final updated = await PaymentMethodsService.remove(id);
    if (!mounted) return;
    setState(() => _methods = updated);
  }

  Future<void> _openAddFlow() async {
    final added = await Navigator.of(context).push<PaymentMethod>(
      MaterialPageRoute(builder: (_) => const AddPaymentMethodScreen()),
    );
    if (!mounted || added == null) return;
    final updated = await PaymentMethodsService.add(added);
    if (!mounted) return;
    setState(() => _methods = updated);
  }

  Future<void> _addSimple({required PaymentMethodType type, required String label}) async {
    final now = DateTime.now();
    final id = 'pm_${type.name}_${now.millisecondsSinceEpoch}';
    final updated = await PaymentMethodsService.add(
      PaymentMethod(id: id, type: type, isDefault: false, label: label, createdAt: now, updatedAt: now),
    );
    if (!mounted) return;
    setState(() => _methods = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(children: [
      Positioned.fill(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(color: Colors.black.withValues(alpha: 0.28)),
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
          title: Text('Zahlungsmethoden', style: theme.textTheme.titleMedium),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                  color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surface,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 24),
                  children: [
                    _SitCreditCard(
                      enabled: _sitCreditEnabled,
                      balanceLabel: _formatCurrency(_sitBalance),
                      onChanged: _toggleSitCredit,
                    ),
                    const SizedBox(height: 12),
                    if (_methods.isEmpty) ...[
                      const SizedBox(height: 40),
                      _EmptyState(
                        onAdd: _openAddFlow,
                      ),
                    ] else ...[
                      ..._methods.map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PaymentMethodCard(
                              method: m,
                              onSetDefault: m.isDefault ? null : () => _setDefault(m.id),
                              onRemove: () => _remove(m.id),
                            ),
                          )),
                      const SizedBox(height: 18),
                      _AddMethodButton(onPressed: _openAddFlow),
                    ],
                  ],
                ),
              ),
      ),
    ]);
  }
}

class PaymentMethodCard extends StatelessWidget {
  final PaymentMethod method;
  final VoidCallback? onSetDefault;
  final VoidCallback onRemove;

  const PaymentMethodCard({super.key, required this.method, required this.onSetDefault, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _iconForType(method.type);
    final title = method.label;
    final subtitle = _subtitleForMethod(method);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.70))),
              ],
            ]),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 128),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (method.isDefault)
                  _DefaultBadge()
                else
                  TextButton(
                    onPressed: onSetDefault,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: const Size(44, 36),
                      foregroundColor: theme.colorScheme.primary,
                      textStyle: theme.textTheme.labelSmall,
                    ),
                    child: const Text('Als Standard festlegen'),
                  ),
                const SizedBox(height: 2),
                TextButton(
                  onPressed: onRemove,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: const Size(44, 36),
                    foregroundColor: BrandColors.danger,
                    textStyle: theme.textTheme.labelSmall,
                  ),
                  child: const Text('Entfernen'),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  static IconData _iconForType(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.visa:
      case PaymentMethodType.mastercard:
      case PaymentMethodType.amex:
        return Icons.credit_card;
      case PaymentMethodType.applePay:
        return Icons.phone_iphone;
      case PaymentMethodType.googlePay:
        return Icons.android;
      case PaymentMethodType.paypal:
        return Icons.account_balance_wallet_outlined;
      case PaymentMethodType.sepa:
        return Icons.account_balance_outlined;
    }
  }

  static String? _subtitleForMethod(PaymentMethod m) {
    if (m.type == PaymentMethodType.sepa && (m.last4 ?? '').isNotEmpty) {
      return 'IBAN •••• ${m.last4}';
    }
    if ((m.type == PaymentMethodType.visa || m.type == PaymentMethodType.mastercard || m.type == PaymentMethodType.amex) && (m.last4 ?? '').isNotEmpty) {
      return '${m.label} •••• ${m.last4}';
    }
    return null;
  }
}

class _DefaultBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text('Standard', style: theme.textTheme.labelSmall?.copyWith(color: accent)),
    );
  }
}

class _AddMethodButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AddMethodButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
      ),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add, size: 20, color: Colors.white),
        SizedBox(width: 10),
        Text('Zahlungsmethode hinzufügen'),
      ]),
    );
  }
}

class _SitCreditCard extends StatelessWidget {
  final bool enabled;
  final String balanceLabel;
  final ValueChanged<bool> onChanged;

  const _SitCreditCard({required this.enabled, required this.balanceLabel, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final titleStyle = theme.textTheme.titleMedium;
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.72));
    final captionStyle = theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.62));

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('SIT-Guthaben verwenden', style: titleStyle)),
                const SizedBox(width: 10),
                _ActivePill(active: enabled),
              ]),
              const SizedBox(height: 4),
              Text('Aktuelles SIT-Guthaben: $balanceLabel', style: bodyStyle),
              const SizedBox(height: 2),
              Text('Wenn aktiv, wird Guthaben automatisch beim Bezahlen genutzt.', style: captionStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 10),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: primary,
            activeTrackColor: primary.withValues(alpha: 0.40),
            inactiveThumbColor: Colors.white.withValues(alpha: 0.78),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
    );
  }
}

class _ActivePill extends StatelessWidget {
  final bool active;
  const _ActivePill({required this.active});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final bg = active ? primary.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06);
    final border = active ? primary.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.10);
    final fg = active ? primary : Colors.white.withValues(alpha: 0.70);
    final text = active ? 'Aktiv' : 'Nicht aktiv';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(text, style: theme.textTheme.labelSmall?.copyWith(color: fg)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Icon(Icons.credit_card_outlined, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 16),
        Text('Noch keine Zahlungsmethode hinzugefügt', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Füge eine Zahlungsmethode hinzu, um Buchungen schnell und sicher zu bezahlen.',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.70)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        SizedBox(width: min(MediaQuery.of(context).size.width - 32, 360), child: _AddMethodButton(onPressed: onAdd)),
      ],
    );
  }
}

class _AddOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _AddOptionTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.white.withValues(alpha: 0.06),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
          Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.6)),
        ]),
      ),
    );
  }
}

class _SITFullScreenScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? bottomBar;

  const _SITFullScreenScaffold({required this.title, required this.body, this.bottomBar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(children: [
      Positioned.fill(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(color: Colors.black.withValues(alpha: 0.28)),
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
          title: Text(title, style: theme.textTheme.titleMedium),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        bottomNavigationBar: bottomBar == null
            ? null
            : SafeArea(
                top: false,
                child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 16), child: bottomBar!),
              ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            children: [body],
          ),
        ),
      ),
    ]);
  }
}

class AddPaymentMethodScreen extends StatelessWidget {
  const AddPaymentMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SITFullScreenScaffold(
      title: 'Zahlungsmethode hinzufügen',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 6),
        Text(
          'Wähle aus, welche Zahlungsmethode du verbinden möchtest.',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.72)),
        ),
        const SizedBox(height: 16),
        _AddOptionTile(
          icon: Icons.credit_card,
          title: 'Kredit- oder Debitkarte hinzufügen',
          onTap: () async {
            final added = await Navigator.of(context).push<PaymentMethod>(
              MaterialPageRoute(builder: (_) => const AddCardScreen()),
            );
            if (context.mounted && added != null) Navigator.of(context).pop(added);
          },
        ),
        const SizedBox(height: 10),
        _AddOptionTile(
          icon: Icons.phone_iphone,
          title: 'Apple Pay verbinden',
          onTap: () {
            final now = DateTime.now();
            Navigator.of(context).pop(
              PaymentMethod(
                id: 'pm_applePay_${now.millisecondsSinceEpoch}',
                type: PaymentMethodType.applePay,
                isDefault: false,
                label: 'Apple Pay',
                createdAt: now,
                updatedAt: now,
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _AddOptionTile(
          icon: Icons.android,
          title: 'Google Pay verbinden',
          onTap: () {
            final now = DateTime.now();
            Navigator.of(context).pop(
              PaymentMethod(
                id: 'pm_googlePay_${now.millisecondsSinceEpoch}',
                type: PaymentMethodType.googlePay,
                isDefault: false,
                label: 'Google Pay',
                createdAt: now,
                updatedAt: now,
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _AddOptionTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'PayPal verbinden',
          onTap: () {
            final now = DateTime.now();
            Navigator.of(context).pop(
              PaymentMethod(
                id: 'pm_paypal_${now.millisecondsSinceEpoch}',
                type: PaymentMethodType.paypal,
                isDefault: false,
                label: 'PayPal',
                createdAt: now,
                updatedAt: now,
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _AddOptionTile(
          icon: Icons.account_balance_outlined,
          title: 'Bankkonto (SEPA) hinzufügen',
          onTap: () async {
            final added = await Navigator.of(context).push<PaymentMethod>(
              MaterialPageRoute(builder: (_) => const AddSepaScreen()),
            );
            if (context.mounted && added != null) Navigator.of(context).pop(added);
          },
        ),
      ]),
    );
  }
}

@Deprecated('Use AddCardScreen (full page) instead of bottom sheet.')
enum _AddMethodAction { addCard, applePay, googlePay, paypal, sepa }

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();

  final _holderCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvcCtrl = TextEditingController();

  CardBrand _brand = CardBrand.unknown;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _numberCtrl.addListener(_onNumberChanged);
  }

  void _onNumberChanged() {
    final digits = _numberCtrl.text.replaceAll(RegExp(r'\D'), '');
    final next = detectBrand(digits);
    if (next != _brand && mounted) setState(() => _brand = next);
  }

  @override
  void dispose() {
    _holderCtrl.dispose();
    _numberCtrl.removeListener(_onNumberChanged);
    _numberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvcCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final digits = _numberCtrl.text.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
    final now = DateTime.now();

    PaymentMethodType? type;
    String label;
    switch (_brand) {
      case CardBrand.visa:
        type = PaymentMethodType.visa;
        label = 'Visa';
        break;
      case CardBrand.mastercard:
        type = PaymentMethodType.mastercard;
        label = 'Mastercard';
        break;
      case CardBrand.amex:
        type = PaymentMethodType.amex;
        label = 'American Express';
        break;
      case CardBrand.unknown:
        type = null;
        label = 'Karte';
        break;
    }
    if (type == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktuell werden nur Visa, Mastercard und American Express unterstützt.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final id = 'pm_${type.name}_${now.millisecondsSinceEpoch}';
      final pm = PaymentMethod(
        id: id,
        type: type,
        isDefault: false,
        label: label,
        last4: last4,
        holderName: _holderCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      );
      if (!mounted) return;
      Navigator.of(context).pop(pm);
    } catch (e) {
      debugPrint('[AddCardSheet] save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SITFullScreenScaffold(
      title: 'Karte hinzufügen',
      bottomBar: FilledButton(
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
        child: _saving
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Speichern'),
      ),
      body: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _BrandPill(brand: _brand),
            const SizedBox(width: 10),
            Text(
              _brand == CardBrand.unknown ? 'Kartentyp automatisch' : brandLabel(_brand),
              style: theme.textTheme.captionStyle,
            ),
          ]),
          const SizedBox(height: 14),
          _SITTextField(
            controller: _holderCtrl,
            label: 'Karteninhaber',
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Bitte Karteninhaber angeben' : null,
          ),
          const SizedBox(height: 10),
          _SITTextField(
            controller: _numberCtrl,
            label: 'Kartennummer',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, CardNumberFormatter()],
            validator: (_) {
              final digits = _numberCtrl.text.replaceAll(RegExp(r'\D'), '');
              if (digits.isEmpty) return 'Bitte Kartennummer eingeben';
              if (digits.length < 12) return 'Kartennummer ist zu kurz';
              return null;
            },
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _SITTextField(
                controller: _expiryCtrl,
                label: 'Ablaufdatum',
                hintText: 'MM/JJ',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, ExpiryDateFormatter()],
                validator: (_) {
                  final v = _expiryCtrl.text.trim();
                  if (v.isEmpty) return 'Bitte Ablaufdatum eingeben';
                  final parts = v.split('/');
                  if (parts.length != 2) return 'Format MM/JJ';
                  final mm = int.tryParse(parts[0]);
                  final yy = int.tryParse(parts[1]);
                  if (mm == null || yy == null || mm < 1 || mm > 12) return 'Ungültiges Datum';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SITTextField(
                controller: _cvcCtrl,
                label: 'CVC',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                validator: (_) {
                  final v = _cvcCtrl.text.trim();
                  if (v.isEmpty) return 'Bitte CVC eingeben';
                  if (v.length < 3) return 'CVC ist zu kurz';
                  return null;
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            'Alle Zahlungen sind durch sichere Verschlüsselung und 3D-Secure geschützt.',
            style: theme.textTheme.captionStyle,
          ),
        ]),
      ),
    );
  }
}

class AddSepaScreen extends StatefulWidget {
  const AddSepaScreen({super.key});

  @override
  State<AddSepaScreen> createState() => _AddSepaScreenState();
}

class _AddSepaScreenState extends State<AddSepaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _holderCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _holderCtrl.dispose();
    _ibanCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);
    try {
      final raw = _ibanCtrl.text.replaceAll(RegExp(r'\s+'), '').toUpperCase();
      final last4 = raw.length >= 4 ? raw.substring(raw.length - 4) : raw;
      final now = DateTime.now();
      final id = 'pm_sepa_${now.millisecondsSinceEpoch}';
      final pm = PaymentMethod(
        id: id,
        type: PaymentMethodType.sepa,
        isDefault: false,
        label: 'SEPA Bankkonto',
        last4: last4,
        holderName: _holderCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      );
      if (!mounted) return;
      Navigator.of(context).pop(pm);
    } catch (e) {
      debugPrint('[AddSepaSheet] save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SITFullScreenScaffold(
      title: 'Bankkonto hinzufügen',
      bottomBar: FilledButton(
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
        child: _saving
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Speichern'),
      ),
      body: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _SITTextField(
            controller: _holderCtrl,
            label: 'Kontoinhaber',
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Bitte Kontoinhaber angeben' : null,
          ),
          const SizedBox(height: 10),
          _SITTextField(
            controller: _ibanCtrl,
            label: 'IBAN',
            hintText: 'DE00 0000 0000 0000 0000 00',
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.text,
            inputFormatters: [IbanFormatter()],
            validator: (_) {
              final raw = _ibanCtrl.text.replaceAll(RegExp(r'\s+'), '').toUpperCase();
              if (raw.isEmpty) return 'Bitte IBAN eingeben';
              if (raw.length < 15) return 'IBAN ist zu kurz';
              if (!RegExp(r'^[A-Z]{2}').hasMatch(raw)) return 'IBAN muss mit Länderkennung beginnen';
              return null;
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Alle Zahlungen sind durch sichere Verschlüsselung und 3D-Secure geschützt.',
            style: theme.textTheme.captionStyle,
          ),
        ]),
      ),
    );
  }
}

class _SITTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _SITTextField({
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
      cursorColor: Colors.white,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.45)),
        labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.75)),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: BrandColors.danger.withValues(alpha: 0.8))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: BrandColors.danger.withValues(alpha: 0.95))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

enum CardBrand { visa, mastercard, amex, unknown }

CardBrand detectBrand(String digits) {
  if (digits.isEmpty) return CardBrand.unknown;
  if (digits.startsWith('4')) return CardBrand.visa;
  if (digits.length >= 2) {
    final p2 = int.tryParse(digits.substring(0, 2));
    if (p2 == 34 || p2 == 37) return CardBrand.amex;
    if (p2 != null && p2 >= 51 && p2 <= 55) return CardBrand.mastercard;
  }
  if (digits.length >= 4) {
    final p4 = int.tryParse(digits.substring(0, 4));
    if (p4 != null && p4 >= 2221 && p4 <= 2720) return CardBrand.mastercard;
  }
  return CardBrand.unknown;
}

String brandLabel(CardBrand brand) {
  switch (brand) {
    case CardBrand.visa:
      return 'Visa';
    case CardBrand.mastercard:
      return 'Mastercard';
    case CardBrand.amex:
      return 'American Express';
    case CardBrand.unknown:
      return 'Unbekannt';
  }
}

class _BrandPill extends StatelessWidget {
  final CardBrand brand;
  const _BrandPill({required this.brand});

  @override
  Widget build(BuildContext context) {
    final label = brand == CardBrand.unknown ? 'Auto' : brandLabel(brand);
    final icon = switch (brand) {
      CardBrand.visa => Icons.credit_card,
      CardBrand.mastercard => Icons.credit_card,
      CardBrand.amex => Icons.credit_card,
      CardBrand.unknown => Icons.auto_awesome,
    };
    final color = brand == CardBrand.unknown ? Colors.white.withValues(alpha: 0.65) : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      ]),
    );
  }
}

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > 4 ? digits.substring(0, 4) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i == 2) buf.write('/');
      buf.write(trimmed[i]);
    }
    final text = buf.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class IbanFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final filtered = raw.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final buf = StringBuffer();
    for (var i = 0; i < filtered.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(filtered[i]);
    }
    final text = buf.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

extension on TextTheme {
  TextStyle? get captionStyle => labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.65), fontWeight: FontWeight.w500);
}
