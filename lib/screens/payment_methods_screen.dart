import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:provider/provider.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    return Stack(children: [
      Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: Container(color: Colors.black.withValues(alpha: 0.35)))),
      Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(l10n.t('account.item.paymentMethods')),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
            _PaymentMethodRow(brand: 'Visa', last4: '4242', isDefault: true),
            SizedBox(height: 12),
            _PaymentMethodRow(brand: 'Mastercard', last4: '4444', isDefault: false),
            SizedBox(height: 24),
            FilledButton(onPressed: null, child: Text('Zahlungsmethode hinzufügen')),
          ]),
        ),
      ),
    ]);
  }
}

class _PaymentMethodRow extends StatelessWidget {
  final String brand;
  final String last4;
  final bool isDefault;
  const _PaymentMethodRow({required this.brand, required this.last4, required this.isDefault});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.credit_card, color: Colors.white70),
        const SizedBox(width: 8),
        Expanded(child: Text('$brand •••• $last4')),
        if (isDefault) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8)), child: const Text('Standard')),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: () {}, child: const Text('Entfernen')),
      ]),
    );
  }
}
