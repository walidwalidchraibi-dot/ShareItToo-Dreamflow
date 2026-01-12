import 'package:flutter/material.dart';

/// A hollow circular indicator with a centered dot when selected.
/// Matches the filter sheet's "blue dot in circle" design.
class DotCircleIndicator extends StatelessWidget {
  final bool selected;
  final Color dotColor;
  final double size;
  const DotCircleIndicator({super.key, required this.selected, required this.dotColor, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.white54;
    final innerSize = size * 0.44;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor, width: 1.6)),
        ),
        if (selected)
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
      ]),
    );
  }
}

/// Text option with a DotCircleIndicator. Use for radio/toggle-like selections.
class ToggleTextOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final EdgeInsets padding;
  const ToggleTextOption({super.key, required this.label, required this.selected, required this.onTap, this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6)});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: padding,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          DotCircleIndicator(selected: selected, dotColor: primary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: selected ? primary : Colors.white, fontWeight: selected ? FontWeight.w700 : FontWeight.w600), overflow: TextOverflow.ellipsis, softWrap: false),
        ]),
      ),
    );
  }
}
