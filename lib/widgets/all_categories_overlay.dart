import 'package:flutter/material.dart';
import 'package:lendify/widgets/outline_icon.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/utils/category_label.dart';

class AllCategoriesOverlay {
  /// Shows the categories picker as a full screen page.
  ///
  /// Returns the tapped category id (or null if dismissed).
  static Future<String?> show(BuildContext context, List<CategoryChipData> categories) async {
    return Navigator.of(context, rootNavigator: true).push<String>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (context, a1, a2) => AllCategoriesScreen(categories: categories),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}

class CategoryChipData {
  final String id; final String label; final IconData icon;
  const CategoryChipData({required this.id, required this.label, required this.icon});
}

class AllCategoriesScreen extends StatelessWidget {
  final List<CategoryChipData> categories;
  const AllCategoriesScreen({super.key, required this.categories});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: true,
        leading: const SizedBox.shrink(),
        leadingWidth: 0,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
          const SizedBox(width: 4),
        ],
        title: Builder(builder: (context) {
          final l10n = context.watch<LocalizationController>();
          return Text(
            l10n.t('Alle Kategorien'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
          );
        }),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              int crossAxisCount;
              if (w >= 1000) {
                crossAxisCount = 6;
              } else if (w >= 800) {
                crossAxisCount = 5;
              } else if (w >= 600) {
                crossAxisCount = 4;
              } else if (w >= 400) {
                crossAxisCount = 3;
              } else {
                crossAxisCount = 2;
              }

              const crossAxisSpacing = 12.0;
              const mainAxisSpacing = 12.0;
              const aspectRatio = 3 / 2;

              // If the last row would contain a single item (e.g. “Sonstiges”),
              // render it centered as a dedicated row.
              final shouldCenterLast = categories.length > 1 && (categories.length % crossAxisCount == 1);
              final mainCount = shouldCenterLast ? categories.length - 1 : categories.length;

              final centeredTileWidth = (w - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.only(bottom: shouldCenterLast ? mainAxisSpacing : (8 + media.viewPadding.bottom)),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: aspectRatio,
                        crossAxisSpacing: crossAxisSpacing,
                        mainAxisSpacing: mainAxisSpacing,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final c = categories[i];
                          return _CategoryTile(
                            icon: c.icon,
                            label: stackCategoryLabel(c.label),
                            onTap: () => Navigator.of(context).pop(c.id),
                          );
                        },
                        childCount: mainCount,
                      ),
                    ),
                  ),
                  if (shouldCenterLast)
                    SliverPadding(
                      padding: EdgeInsets.only(bottom: 8 + media.viewPadding.bottom),
                      sliver: SliverToBoxAdapter(
                        child: Center(
                          child: SizedBox(
                            width: centeredTileWidth,
                            child: AspectRatio(
                              aspectRatio: aspectRatio,
                              child: _CategoryTile(
                                icon: categories.last.icon,
                                label: stackCategoryLabel(categories.last.label),
                                onTap: () => Navigator.of(context).pop(categories.last.id),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final IconData icon; final String label;
  final VoidCallback onTap;
  const _CategoryTile({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.26), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 4))]),
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          MaterialOutlineIcon(icon: icon, size: 28, color: Colors.white),
          const SizedBox(height: 8),
          const SizedBox.shrink(),
          Text(label, textAlign: TextAlign.center, maxLines: 2, softWrap: true, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 12, height: 1.15)),

        ]),
      ),
    );
  }
}