import 'package:flutter/material.dart';

/// SITLogoHeader renders the ShareItToo app icon + title and optional slogan.
///
/// Use this across auth/onboarding screens to keep the brand header consistent.
class SitLogoHeader extends StatelessWidget {
  const SitLogoHeader({super.key, this.textColor, this.sloganColor, this.showSlogan = true, this.shiftX = -8});

  final Color? textColor;
  final Color? sloganColor;
  final bool showSlogan;

  /// Subtle optical left shift (device-dependent). Matches prior login styling.
  final double shiftX;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedText = textColor ?? Colors.white;
    final resolvedSlogan = sloganColor ?? Colors.white.withValues(alpha: 0.80);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: Offset(shiftX, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Image.asset(
                    'assets/images/icononly_transparent_nobuffer.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.all_inclusive, color: resolvedText, size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Text('ShareItToo', style: theme.textTheme.titleMedium?.copyWith(color: resolvedText, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          if (showSlogan) ...[
            const SizedBox(height: 2),
            Transform.translate(
              offset: const Offset(0, -8),
              child: Text(
                'SICHER. LOKAL. VERTRAUT.',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w900, color: resolvedSlogan, letterSpacing: 1.1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
