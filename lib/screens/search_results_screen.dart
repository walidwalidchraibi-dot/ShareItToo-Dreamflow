import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/category.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/widgets/filters_overlay.dart';
import 'package:lendify/widgets/item_details_overlay.dart';
import 'package:lendify/widgets/scroll_edge_indicators.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:provider/provider.dart';
import 'package:lendify/widgets/wishlist_selection_sheet.dart';

class SearchResultsScreen extends StatefulWidget {
  final String queryText; // e.g., "Bohrmaschine in Stuttgart"
  final String? dateText; // e.g., "11. Jan – 18. Jan"
  final List<Item> results; // prefiltered search-relevant items

  const SearchResultsScreen({super.key, required this.queryText, required this.results, this.dateText});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? _filters;
  Set<String> _savedIds = {};
  Map<String, String> _coarseByCatId = {};
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final saved = await DataService.getSavedItemIds();
    final cats = await DataService.getCategories();
    final coarseMap = <String, String>{for (final c in cats) c.id: DataService.coarseCategoryFor(c.name)};
    if (!mounted) return;
    setState(() {
      _savedIds = saved;
      _categories = cats;
      _coarseByCatId = coarseMap;
    });
  }

  Future<void> _showFilters() async {
    final result = await FiltersOverlay.show(context, initial: _filters);
    if (result != null) setState(() => _filters = result);
  }

  Future<void> _toggleFavorite(String id) async {
    // Manual wishlist selection flow
    final current = await DataService.getWishlistForItem(id);
    if (current == null) {
      final sel = await WishlistSelectionSheet.showAdd(context);
      if (sel != null && sel.isNotEmpty) {
        await DataService.setItemWishlist(id, sel);
      }
    } else {
      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  leading: Icon(Icons.swap_horiz, color: cs.primary),
                  title: const Text('In andere Wunschliste verschieben'),
                  onTap: () => Navigator.of(ctx).pop('move'),
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: cs.error),
                  title: const Text('Aus Wunschliste entfernen'),
                  onTap: () => Navigator.of(ctx).pop('remove'),
                ),
              ]),
            ),
          );
        },
      );
      if (choice == 'move') {
        final sel = await WishlistSelectionSheet.showMove(context, currentListId: current);
        if (sel != null && sel.isNotEmpty) {
          await DataService.setItemWishlist(id, sel);
        }
      } else if (choice == 'remove') {
        await DataService.removeItemFromWishlist(id);
      }
    }
    final saved = await DataService.getSavedItemIds();
    if (!mounted) return;
    setState(() => _savedIds = saved);
  }

  bool _matches(Item it) {
    final f = _filters;
    if (f == null) return true;
    final RangeValues price = f['price'] ?? const RangeValues(0, 500);
    final String priceUnit = f['priceUnit'] ?? 'day';
    final bool verifiedOnly = f['verified'] == true;
    final String condition = (f['condition'] as String?) ?? 'egal';
    final List<String> catGroups = (f['categories'] as List<String>?) ?? const [];
    final double minRating = (f['minRating'] as double?) ?? 0;
    final List<String> delivery = (f['delivery'] as List<String>?) ?? const [];

    final double minPerDay = priceUnit == 'week' ? price.start / 7 : price.start;
    final double maxPerDay = priceUnit == 'week' ? price.end / 7 : price.end;
    if (it.pricePerDay < minPerDay || it.pricePerDay > maxPerDay) return false;
    if (verifiedOnly) {
      final ok = it.verificationStatus == 'approved' || it.verificationStatus == 'verified';
      if (!ok) return false;
    }
    if (condition != 'egal') {
      String mapped;
      switch (condition) {
        case 'neu':
          mapped = 'new';
          break;
        case 'wie-neu':
          mapped = 'like-new';
          break;
        case 'gut':
          mapped = 'good';
          break;
        case 'akzeptabel':
          mapped = 'acceptable';
          break;
        default:
          mapped = condition;
          break;
      }
      if (it.condition != mapped) return false;
    }
    if (catGroups.isNotEmpty) {
      final g = _coarseByCatId[it.categoryId] ?? '';
      if (!catGroups.contains(g)) return false;
    }
    if (delivery.isNotEmpty) {
      bool matchesAny = false;
      for (final opt in delivery) {
        switch (opt) {
          case 'dropoff':
            matchesAny = matchesAny || it.offersDeliveryAtDropoff;
            break;
          case 'pickup':
            matchesAny = matchesAny || it.offersPickupAtReturn;
            break;
          case 'express':
            matchesAny = matchesAny || it.offersExpressAtDropoff;
            break;
        }
        if (matchesAny) break;
      }
      if (!matchesAny) return false;
    }
    // rating check is owner-based in Explore; here we skip owner lookup for brevity and assume items meet rating when >0
    if (minRating > 0) {
      // Without user lookup, treat rating filter as pass-through for now
    }
    return true;
  }

  List<Item> get _filteredItems {
    final src = [...widget.results];
    if (_filters == null) return _sorted(src);
    final filtered = src.where(_matches).toList();
    return _sorted(filtered);
  }

  List<Item> _sorted(List<Item> list) {
    final sort = _filters?['sort'] as String? ?? 'Entfernung';
    switch (sort) {
      case 'Preis':
        final order = (_filters?['priceOrder'] as String?) ?? 'asc';
        list.sort((a, b) => a.pricePerDay.compareTo(b.pricePerDay));
        if (order == 'desc') list = list.reversed.toList();
        break;
      case 'Neueste':
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Bewertung':
      case 'Entfernung':
      default:
        // No extra data here; keep as-is
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isTablet = width >= 600 && width < 900;
          final isDesktop = width >= 900;

          const horizontalPadding = 16.0;
          const gridGap = 8.0;
          final cols = isDesktop ? 4 : (isTablet ? 3 : 3);
          final cardSize = (width - (horizontalPadding * 2) - (gridGap * (cols - 1))) / cols;

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: _ResultsHeader(
                  queryText: widget.queryText,
                  dateText: widget.dateText,
                  onBack: () => Navigator.of(context).maybePop(),
                  onFilters: _showFilters,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (items.isEmpty) ...[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Es gibt noch keinen Artikel zu deiner Suche. Komm bald wieder!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Nur Suchergebnisse
                SliverToBoxAdapter(child: Builder(builder: (context) {
                  final l10n = context.watch<LocalizationController>();
                  return _SectionHeader(title: l10n.t('Suchergebnisse'), padding: const EdgeInsets.fromLTRB(16, 0, 16, 8));
                })),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: gridGap,
                      mainAxisSpacing: gridGap,
                      childAspectRatio: 1,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = items[index];
                        final isFav = _savedIds.contains(item.id);
                        return _SquareTitleOnlyCard(
                          item: item,
                          isFavorite: isFav,
                          onFavoriteToggle: () => _toggleFavorite(item.id),
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  final String queryText;
  final String? dateText;
  final VoidCallback onBack;
  final VoidCallback onFilters;
  const _ResultsHeader({required this.queryText, this.dateText, required this.onBack, required this.onFilters});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(children: [
        // Back button
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 6),
        // Search field look-alike
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Left-aligned search icon, vertically centered
                Positioned.fill(
                  left: 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Icon(Icons.search, size: 18, color: primary),
                    ),
                  ),
                ),
                // Centered texts (query and date)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Text(queryText, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                    if (dateText != null && dateText!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Text(dateText!, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Filters button
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            onPressed: onFilters,
            icon: const Icon(Icons.tune),
            color: Colors.white,
          ),
        ),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool showSeeAll;
  final EdgeInsets? padding;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.showSeeAll = false, this.padding, this.onSeeAll});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white))),
        if (showSeeAll)
          TextButton(onPressed: onSeeAll, child: const Text('Alle ansehen')),
      ]),
    );
  }
}

class _SeeAllLike extends StatelessWidget {
  final String title;
  final List<Item> items;
  const _SeeAllLike({required this.title, required this.items});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(title), backgroundColor: Colors.black),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
        itemCount: items.length,
        itemBuilder: (context, i) => _SquareTitleOnlyCard(item: items[i], isFavorite: false),
      ),
    );
  }
}

class _SquareTitleOnlyCard extends StatefulWidget {
  final Item item;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  const _SquareTitleOnlyCard({required this.item, this.isFavorite = false, this.onFavoriteToggle});
  @override
  State<_SquareTitleOnlyCard> createState() => _SquareTitleOnlyCardState();
}

class _SquareTitleOnlyCardState extends State<_SquareTitleOnlyCard> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ItemDetailsOverlay.showFullPage(context, item: widget.item, fresh: true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(children: [
          Positioned.fill(child: AppImage(url: widget.item.photos.isNotEmpty ? widget.item.photos.first : 'https://picsum.photos/seed/titleonly/800/800', fit: BoxFit.cover)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: 0.10)), borderRadius: BorderRadius.circular(18)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.55),
                ]),
              ),
              child: Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          if (widget.onFavoriteToggle != null)
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                onTap: widget.onFavoriteToggle,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                  child: Icon(widget.isFavorite ? Icons.favorite : Icons.favorite_border, size: 16, color: widget.isFavorite ? Colors.pinkAccent : Colors.black54),
                ),
              ),
            ),
          Positioned(
            top: 8,
            left: 8,
            child: (widget.item.verificationStatus == 'approved' || widget.item.verificationStatus == 'verified')
                ? const Icon(Icons.verified, size: 16, color: Color(0xFF22C55E))
                : const Tooltip(message: 'Nicht verifiziert', child: Icon(Icons.verified_outlined, size: 16, color: Colors.grey)),
          ),
        ]),
      ),
    );
  }
}
