import 'package:flutter/material.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:provider/provider.dart';

class MarqueeBanner extends StatefulWidget {
  const MarqueeBanner({super.key});
  @override
  State<MarqueeBanner> createState() => _MarqueeBannerState();
}

class _MarqueeBannerState extends State<MarqueeBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  double _textWidth = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final text = l10n.t('Erstelle eine neue Anzeige');
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700);
    return LayoutBuilder(builder: (context, constraints) {
      final screenW = constraints.maxWidth;
      if (_textWidth == 0) {
        final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
        _textWidth = tp.width + 32; // padding
      }
      return Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final total = screenW + _textWidth;
            final dx = screenW - (_c.value * total);
            return Stack(children: [
              Positioned(
                left: dx,
                top: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    const Icon(Icons.add_business, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(text, style: style),
                  ]),
                ),
              )
            ]);
          },
        ),
      );
    });
  }
}
