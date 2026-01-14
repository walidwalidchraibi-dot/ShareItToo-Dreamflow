import 'package:flutter/material.dart';

/// Data model for a wishlist folder tile
class WishlistFolderOption {
  final String id;
  final String title;
  final String subtitle;
  final int count;
  final bool system;
  const WishlistFolderOption({
    required this.id,
    required this.title,
    required this.subtitle,
    this.count = 0,
    this.system = false,
  });
}

/// Reusable grid of wishlist folder tiles
class WishlistFolderGrid extends StatelessWidget {
  final List<WishlistFolderOption> options;
  final ValueChanged<String> onSelected;
  final int crossAxisCount;
  final bool onDark;
  const WishlistFolderGrid({super.key, required this.options, required this.onSelected, this.crossAxisCount = 2, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tileBg = onDark ? Colors.white.withValues(alpha: 0.14) : cs.surfaceContainerHighest;
    final tileBorder = onDark ? Colors.white.withValues(alpha: 0.20) : cs.onSurface.withValues(alpha: 0.08);
    final iconBg = onDark ? Colors.white.withValues(alpha: 0.12) : cs.primary.withValues(alpha: 0.10);
    final iconColor = onDark ? Colors.white : cs.primary;
    final titleStyle = onDark
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)
        : Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
    final subtitleStyle = onDark
        ? Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)
        : Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.72));

    return LayoutBuilder(builder: (context, constraints) {
      // Responsive: 1 column on narrow popups, 2 columns otherwise
      final isNarrow = constraints.maxWidth < 380;
      final cols = isNarrow ? 1 : crossAxisCount;
      final ratio = isNarrow ? 5.0 : 2.2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: ratio,
        ),
        itemCount: options.length,
        itemBuilder: (_, i) {
          final op = options[i];
          return InkWell(
            onTap: () => onSelected(op.id),
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: tileBg, border: Border.all(color: tileBorder)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                    // Für vom Nutzer erstellte Wunschlisten ein persönliches Icon anzeigen,
                    // für Systemlisten ein generisches Ordner-Icon beibehalten.
                    child: Icon(op.system ? Icons.folder : Icons.person_outline, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(op.title, maxLines: 2, softWrap: true, overflow: TextOverflow.ellipsis, style: titleStyle),
                      const SizedBox(height: 4),
                      Text(op.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: subtitleStyle),
                    ]),
                  ),
                  _CountBadge(count: op.count, onDark: onDark),
                ]),
              ),
            ),
          );
        },
      );
    });
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final bool onDark;
  const _CountBadge({required this.count, this.onDark = false});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = onDark ? Colors.white.withValues(alpha: 0.10) : cs.primary.withValues(alpha: 0.10);
    final fg = onDark ? Colors.white : cs.primary;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)), child: Text(count.toString(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w800)));
  }
}
