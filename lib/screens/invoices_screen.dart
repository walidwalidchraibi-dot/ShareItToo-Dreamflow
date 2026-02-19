import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});
  @override
  Widget build(BuildContext context) {
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
          title: const Text('Rechnungen & Belege'),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 24),
          itemBuilder: (_, i) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
            child: Row(children: [
              const Icon(Icons.receipt_long_outlined, color: Colors.white70),
              const SizedBox(width: 12),
              const Expanded(child: Text('01.08.2025 · 39,90 € · Buchung #SIT-12345')),
              TextButton(onPressed: () {}, child: const Text('Details')),
            ]),
          ),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: 8,
        ),
      ),
    ]);
  }
}
