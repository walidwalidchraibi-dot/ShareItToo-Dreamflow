import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lendify/screens/login_screen.dart';
import 'package:lendify/screens/register_screen.dart';
import 'package:lendify/theme.dart';

class ProfileLoggedOutScreen extends StatelessWidget {
  const ProfileLoggedOutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text('Profil', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: const [
                _LoggedOutHeroCard(),
                SizedBox(height: 16),
                _ValuePreviewSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoggedOutHeroCard extends StatelessWidget {
  const _LoggedOutHeroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [theme.colorScheme.primary, BrandColors.logoAccent],
    );

    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0.06)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 10))],
            ),
            child: const Icon(Icons.person_outline, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Starte jetzt mit ShareItToo', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.2)),
              const SizedBox(height: 6),
              Text(
                'Miete, vermiete und verbinde dich mit Menschen in deiner Nähe.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.82), height: 1.45),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        _PressScale(
          child: HoverScale(
            scale: 1.02,
            child: _CtaButton(
              variant: _CtaVariant.primary,
              icon: Icons.person_add_alt_1,
              label: 'Konto erstellen',
              gradient: primaryGradient,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _PressScale(
          child: HoverScale(
            scale: 1.02,
            child: _CtaButton(
              variant: _CtaVariant.secondary,
              icon: Icons.login,
              label: 'Anmelden',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Column(children: [
            Text('Sicher. Transparent. Fair.', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Verifizierte Profile • Bewertungen • Sichere Übergaben',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.72), height: 1.35),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ValuePreviewSection extends StatelessWidget {
  const _ValuePreviewSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Das bekommst du', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      const _ValueRow(icon: Icons.lock_outline, text: 'Sicher mieten & vermieten'),
      const SizedBox(height: 10),
      const _ValueRow(icon: Icons.chat_bubble_outline, text: 'Direkter Chat nach Annahme'),
      const SizedBox(height: 10),
      const _ValueRow(icon: Icons.photo_camera_outlined, text: 'Übergabe mit Foto-Dokumentation'),
    ]);
  }
}

class _ValueRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ValueRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 16,
      blurSigma: 14,
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.35))),
      ]),
    );
  }
}

enum _CtaVariant { primary, secondary }

class _CtaButton extends StatelessWidget {
  final _CtaVariant variant;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Gradient? gradient;
  const _CtaButton({required this.variant, required this.icon, required this.label, required this.onTap, this.gradient});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrimary = variant == _CtaVariant.primary;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        hoverColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        splashColor: Colors.transparent,
        child: Container(
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: isPrimary ? (gradient ?? appBackgroundGradient) : null,
            color: isPrimary ? null : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isPrimary ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.14)),
            boxShadow: isPrimary
                ? [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 14)),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: isPrimary ? FontWeight.w900 : FontWeight.w800),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.85), size: 22),
          ]),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final double blurSigma;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.blurSigma = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 26, offset: const Offset(0, 18))],
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  final Widget child;
  final double pressedScale;
  final Duration duration;
  const _PressScale({required this.child, this.pressedScale = 0.985, this.duration = const Duration(milliseconds: 120)});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
