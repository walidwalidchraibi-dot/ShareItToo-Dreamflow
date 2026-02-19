import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:provider/provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _nextCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _currentCtrl.dispose();
    _nextCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _valid => _nextCtrl.text.isNotEmpty && _nextCtrl.text == _confirmCtrl.text && _currentCtrl.text.isNotEmpty;

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
          title: Text(l10n.t('account.item.changePassword')),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: _currentCtrl,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline), labelText: 'Aktuelles Passwort'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nextCtrl,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.password_outlined), labelText: 'Neues Passwort'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.check_circle_outline), labelText: 'Passwort bestätigen'),
            ),
            const SizedBox(height: 12),
            Text('Mind. 8 Zeichen, eine Zahl, ein Sonderzeichen.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _valid
                  ? () {
                      Navigator.of(context).maybePop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('Gespeichert'))));
                    }
                  : null,
              child: Text(l10n.t('Speichern')),
            ),
          ]),
        ),
      ),
    ]);
  }
}
