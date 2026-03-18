import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/widgets/rating_badge.dart';

class ListingCarouselCard extends StatelessWidget {
  final Item item;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final String? badgeText;
  final double? distanceKm;
  final double? rating;
  final int? rentals;
  const ListingCarouselCard({
    super.key,
    required this.item,
    required this.isFavorite,
    required this.onFavoriteToggle,
    this.badgeText,
    this.distanceKm,
    this.rating,
    this.rentals,
  });

  static double _deriveRating(Item item) {
    // Deterministic and stable without backend.
    final base = 4.4 + ((item.id.hashCode.abs() % 40) / 100); // 4.40 - 4.79
    final boost = (item.timesLent.clamp(0, 30) / 300); // up to +0.10
    return (base + boost).clamp(4.3, 5.0);
  }

  static String? _deriveHighlightTag(Item item, LocalizationController l10n, double derivedRating) {
    if (item.timesLent >= 20) return l10n.t('Beliebt');
    if (derivedRating >= 4.8) return l10n.t('Top bewertet');
    if (item.status == 'active') return l10n.t('Sofort verfügbar');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.watch<LocalizationController>();
    final derivedRating = rating ?? _deriveRating(item);
    final derivedRentals = rentals ?? item.timesLent;
    final highlight = badgeText ?? _deriveHighlightTag(item, l10n, derivedRating);
    final isVerified = item.verificationStatus == 'verified' || item.verificationStatus == 'approved';
    // Keep in lockstep with RatingBadge + on-image highlight chips.
    // Requested: +20% size.
    final tagFontSize = ((Theme.of(context).textTheme.labelSmall?.fontSize) ?? 11) * 0.78;

    return Container(
      decoration: BoxDecoration(
        color: BrandColors.glassSurface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrandColors.glassStroke),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(fit: StackFit.expand, children: [
            AppImage(
              url: item.photos.isNotEmpty ? item.photos.first : 'https://images.unsplash.com/photo-1520975661595-6453be3f7070?w=1200&h=900&fit=crop',
              fit: BoxFit.cover,
            ),
            // Bottom scrim for readability
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, BrandColors.imageScrim.withValues(alpha: 0.55)],
                  ),
                ),
              ),
            ),
            // Verified symbol only (top-left): green if verified, grey otherwise.
            Positioned(
              top: 10,
              left: 10,
              child: Icon(Icons.verified, size: 18, color: isVerified ? BrandColors.success : Colors.grey),
            ),
            if (highlight != null)
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Text(
                    highlight,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: tagFontSize),
                  ),
                ),
              ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: onFavoriteToggle,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), shape: BoxShape.circle),
                  child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, size: 16, color: isFavorite ? BrandColors.danger : Colors.black54),
                ),
              ),
            ),

            // Rating badge (bottom-right on image)
            Positioned(
              right: 10,
              bottom: 10,
              child: RatingBadge(rating: derivedRating),
            ),
          ]),
        ),
        Padding(
          // Keep this section ultra-compact so the card visually ends right under the price.
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 3),
            _TrustRow(distanceKm: distanceKm, rentals: derivedRentals),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${item.pricePerDay.toStringAsFixed(0)} €', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text('/ ${l10n.t('Tag')}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.80), fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _TrustRow extends StatelessWidget {
  final double? distanceKm;
  final int rentals;
  const _TrustRow({required this.distanceKm, required this.rentals});

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.86), fontWeight: FontWeight.w700);

    final parts = <Widget>[
      const Icon(Icons.place_outlined, size: 14, color: Colors.white70),
      const SizedBox(width: 4),
      Text(distanceKm == null ? l10n.t('in deiner Nähe') : '${distanceKm!.toStringAsFixed(distanceKm! < 10 ? 1 : 0)} km', style: style),
      const SizedBox(width: 10),
      const Icon(Icons.loop, size: 14, color: Colors.white70),
      const SizedBox(width: 4),
      Text('${rentals.clamp(0, 999)}', style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(children: parts),
    );
  }
}
