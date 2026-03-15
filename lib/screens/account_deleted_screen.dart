import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lendify/navigation/main_nav_controller.dart';
import 'package:provider/provider.dart';

class AccountDeletedScreen extends StatelessWidget {
  const AccountDeletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const SizedBox.shrink(),
      ),
      body: Stack(children: [
        Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent))),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: t.colorScheme.primary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                        ),
                        child: Icon(Icons.check_circle_outline, color: t.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Dein Konto wurde gelöscht',
                          style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                      'Dein ShareItToo-Konto wurde erfolgreich entfernt.\nDu kannst jederzeit ein neues Konto erstellen.',
                      style: t.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.5),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        // Jump to start page (Explore tab) and clear the stack.
                        context.read<MainNavController>().setIndex(0);
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                      child: const Text('Zur Startseite'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
