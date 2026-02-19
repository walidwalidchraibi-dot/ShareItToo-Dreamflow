import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:provider/provider.dart';

class PayoutMethodsScreen extends StatelessWidget {
  const PayoutMethodsScreen({super.key});
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
          title: Text(l10n.t('account.item.payoutMethods')),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
            ListTile(leading: Icon(Icons.account_balance_outlined), title: Text('Bankkonto'), subtitle: Text('DE•• •• •••• •••• •••• ••')),
            SizedBox(height: 24),
            FilledButton(onPressed: null, child: Text('Auszahlungsmethode hinzufügen')),
          ]),
        ),
      ),
    ]);
  }
}
