import 'package:flutter/material.dart';
import 'package:lendify/widgets/app_image.dart';

/// A modern wishlist card showing a 2x2 mosaic of recent item photos and
/// a clean text section with title, optional subtitle and item count.
/// Inspired by Airbnb's wishlist tiles; styled for SIT.
class WishlistMosaicCard extends StatelessWidget {
  final String id;
  final String title;
  final String? subtitle;
  final int count;
  final List<String> photoUrls; // Most recent photos; up to 4 are shown
  final VoidCallback? onTap;

  const WishlistMosaicCard({super.key, required this.id, required this.title, this.subtitle, required this.count, required this.photoUrls, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardBg = cs.surface.withValues(alpha: 0.72);
    final border = cs.onSurface.withValues(alpha: 0.06);
    // Make wishlist titles slightly smaller per request while keeping strong weight
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: cs.primary);
    final metaStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.68));

    Widget content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Mosaic(urls: photoUrls, empty: count == 0),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
          const SizedBox(height: 8),
          Text('$count Artikel', style: metaStyle),
          const SizedBox(height: 10),
        ]),
      ),
    ]);

    // No splash effects; use InkWell disabled splash via Theme override
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
          clipBehavior: Clip.antiAlias,
          child: content,
        ),
      ),
    );
  }
}

class _Mosaic extends StatelessWidget {
  final List<String> urls;
  final bool empty;
  const _Mosaic({required this.urls, required this.empty});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = 16.0;

    if (empty) {
      // Single calm placeholder
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.06), borderRadius: BorderRadius.only(topLeft: Radius.circular(radius), topRight: Radius.circular(radius))),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.favorite_border, color: cs.onSurface.withValues(alpha: 0.42), size: 28),
              const SizedBox(height: 6),
              Text('Noch keine Artikel', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.56))),
            ]),
          ),
        ),
      );
    }

    final list = urls.where((e) => e.trim().isNotEmpty).toList(growable: false);
    final a = list.isNotEmpty ? list[0] : '';
    final b = list.length > 1 ? list[1] : '';
    final c = list.length > 2 ? list[2] : '';
    final d = list.length > 3 ? list[3] : '';

    Widget tile(String url, {BorderRadius? r}) => url.isEmpty
        ? Container(decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.06), borderRadius: r))
        : AppImage(url: url, borderRadius: r);

    return AspectRatio(
      aspectRatio: 1,
      child: Row(children: [
        Expanded(child: Column(children: [
          Expanded(child: tile(a, r: BorderRadius.only(topLeft: Radius.circular(radius)))),
          const SizedBox(height: 2),
          Expanded(child: tile(c)),
        ])),
        const SizedBox(width: 2),
        Expanded(child: Column(children: [
          Expanded(child: tile(b, r: BorderRadius.only(topRight: Radius.circular(radius)))),
          const SizedBox(height: 2),
          Expanded(child: tile(d, r: BorderRadius.only(bottomRight: Radius.circular(radius)))),
        ])),
      ]),
    );
  }
}
