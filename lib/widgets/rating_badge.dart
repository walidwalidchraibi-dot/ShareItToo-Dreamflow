import 'package:flutter/material.dart';

import 'package:lendify/theme.dart';

/// Compact rating badge intended to be overlaid on top of listing images.
///
/// Design: glassy pill with star + value, readable on any photo.
class RatingBadge extends StatelessWidget {
  final double rating;
  final EdgeInsets padding;

  /// By default, matches the size of the on-image highlight chips (e.g. "Beliebt").
  const RatingBadge({super.key, required this.rating, this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 4)});

  @override
  Widget build(BuildContext context) {
    final baseLabelSize = (Theme.of(context).textTheme.labelSmall?.fontSize) ?? 11;
    // Keep in lockstep with the on-image highlight chips (Explore + Carousel).
    // Requested: +20% size.
    final chipFontSize = baseLabelSize * 0.78;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: chipFontSize);
    final iconSize = (chipFontSize + 5).clamp(11.0, 14.0);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: BrandColors.imageScrim.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.star_rounded, size: iconSize, color: BrandColors.highlight),
        const SizedBox(width: 3),
        Text(rating.toStringAsFixed(1), style: style),
      ]),
    );
  }
}
