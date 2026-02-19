import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:provider/provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _r1 = true, _r2 = true, _r3 = true, _r4 = true, _r5 = false;

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
          title: Text(l10n.t('account.item.notifications')),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SwitchListTile(value: _r1, onChanged: (v) => setState(() => _r1 = v), title: const Text('Mietanfragen')),
            SwitchListTile(value: _r2, onChanged: (v) => setState(() => _r2 = v), title: const Text('Buchungen')),
            SwitchListTile(value: _r3, onChanged: (v) => setState(() => _r3 = v), title: const Text('Nachrichten')),
            SwitchListTile(value: _r4, onChanged: (v) => setState(() => _r4 = v), title: const Text('Übergabe/Rückgabe Erinnerungen')),
            SwitchListTile(value: _r5, onChanged: (v) => setState(() => _r5 = v), title: const Text('App-Updates & Tipps')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
              child: Row(children: const [
                Icon(Icons.info_outline, color: Colors.white70),
                SizedBox(width: 8),
                Expanded(child: Text('System-Push sind evtl. deaktiviert. Bitte in den OS-Einstellungen prüfen.')),
              ]),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.of(context).maybePop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('Gespeichert'))));
              },
              child: Text(l10n.t('Speichern')),
            ),
          ]),
        ),
      ),
    ]);
  }
}
