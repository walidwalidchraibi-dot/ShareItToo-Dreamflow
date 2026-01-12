import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/widgets/app_image.dart';

class ListingCarouselCard extends StatelessWidget {
  final Item item;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final String? badgeText;
  const ListingCarouselCard({super.key, required this.item, required this.isFavorite, required this.onFavoriteToggle, this.badgeText});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final captionStyle = Theme.of(context).textTheme.labelSmall;
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.18), blurRadius: 12, offset: const Offset(0, 6))],
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: Stack(children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: AppImage(url: item.photos.isNotEmpty ? item.photos.first : 'https://images.unsplash.com/photo-1520975661595-6453be3f7070?w=800&h=600&fit=crop', fit: BoxFit.cover),
            ),
            if (badgeText != null)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(10)),
                  child: Text(badgeText!, style: captionStyle?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            // Verified badge (simulated based on item verification)
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (item.verificationStatus == 'verified' || item.verificationStatus == 'approved') 
                      ? const Color(0xFF22C55E).withValues(alpha: 0.9)
                      : Colors.grey.shade600.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (item.verificationStatus == 'verified' || item.verificationStatus == 'approved') 
                          ? Icons.verified
                          : Icons.help_outline,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 2),
                    Builder(builder: (context) {
                      final l10n = context.watch<LocalizationController>();
                      final txt = (item.verificationStatus == 'verified' || item.verificationStatus == 'approved') ? l10n.t('Verifiziert') : l10n.t('Nicht verifiziert');
                      return Text(
                        txt,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: InkWell(
                onTap: onFavoriteToggle,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                  child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, size: 18, color: isFavorite ? Colors.pinkAccent : Colors.black54),
                ),
              ),
            )
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.white))),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Text('${item.pricePerDay.toStringAsFixed(0)} €', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
              const SizedBox(width: 4),
              Builder(builder: (context) => Text(context.watch<LocalizationController>().t('pro Tag'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.8)))), 
              const Spacer(),
              const Icon(Icons.star, size: 16, color: Color(0xFFFB923C)),
              const SizedBox(width: 2),
              Text('4.8', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
            ]),
            const SizedBox(height: 4),
            Text(item.city, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)))
          ]),
        )
      ]),
    );
  }
}
