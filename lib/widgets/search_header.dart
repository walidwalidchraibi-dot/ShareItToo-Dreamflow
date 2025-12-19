import 'package:flutter/material.dart';
import 'package:lendify/theme.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/screens/create_listing_screen.dart';

class SearchHeader extends StatelessWidget {
  final VoidCallback onFiltersPressed;
  final VoidCallback onSearchTap;
  final Future<void> Function(Item created)? onListingCreated;

  const SearchHeader({super.key, required this.onFiltersPressed, required this.onSearchTap, this.onListingCreated});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: LayoutBuilder(builder: (context, constraints) {
        const gap = 8.0;
        const filterSize = 44.0;
        const logoSize = filterSize;
        return Row(children: [
          InkWell(
            onTap: () async {
              final created = await Navigator.of(context).push<Item?>(MaterialPageRoute(builder: (_) => const CreateListingScreen()));
              if (created != null && onListingCreated != null) {
                await onListingCreated!(created);
              }
            },
            borderRadius: BorderRadius.circular(logoSize / 2),
            child: Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                borderRadius: BorderRadius.circular(logoSize / 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.06), blurRadius: 12, offset: const Offset(0, 6)),
                ],
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add_business, size: 22, color: BrandColors.primary),
            ),
          ),
          const SizedBox(width: gap),
          Expanded(
            child: InkWell(
              onTap: onSearchTap,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.06), blurRadius: 12, offset: const Offset(0, 6)),
                  ],
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search, color: BrandColors.primary),
                    const SizedBox(width: 10),
                    Builder(builder: (context) {
                      final l10n = context.watch<LocalizationController>();
                      return Text(l10n.t('Jetzt suchen'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: BrandColors.primary));
                    })
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: gap),
          InkWell(
            onTap: onFiltersPressed,
            borderRadius: BorderRadius.circular(filterSize / 2),
            child: Container(
              width: filterSize,
              height: filterSize,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                borderRadius: BorderRadius.circular(filterSize / 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.06), blurRadius: 12, offset: const Offset(0, 6)),
                ],
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.tune, size: 22, color: BrandColors.primary),
            ),
          ),
        ]);
      }),
    );
  }
}


