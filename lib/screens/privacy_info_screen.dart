import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

class PrivacyInfoScreen extends StatelessWidget {
  const PrivacyInfoScreen({super.key});
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
          title: const Text('Datenschutz-Infos'),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
            _PrivacyText(),
          ]),
        ),
      ),
    ]);
  }
}

class _PrivacyText extends StatelessWidget {
  const _PrivacyText();
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.5);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('• Profil ist öffentlich sichtbar (wie im Screenshot).'),
      const SizedBox(height: 8),
      Text('• E‑Mail und Telefonnummer sind niemals öffentlich.'),
      const SizedBox(height: 8),
      Text('• Chat wird erst nach angenommener Anfrage freigeschaltet.'),
      const SizedBox(height: 8),
      Text('• Foto-Doku Übergabe/Rückgabe ist verpflichtend.'),
      const SizedBox(height: 8),
      Text('• Später: Datenexport anfordern.'),
    ].map((w) => DefaultTextStyle(style: style!, child: w)).toList());
  }
}
