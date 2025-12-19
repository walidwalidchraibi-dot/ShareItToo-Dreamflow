import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lendify/widgets/outline_icon.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/utils/category_label.dart';

class AllCategoriesOverlay {
  static Future<void> show(BuildContext context, List<CategoryChipData> categories) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(children: [
                // Tap outside to close categories overlay
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
                Align(alignment: Alignment.bottomCenter, child: _CategoriesSheet(categories: categories)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class CategoryChipData {
  final String id; final String label; final IconData icon;
  const CategoryChipData({required this.id, required this.label, required this.icon});
}

class _CategoriesSheet extends StatelessWidget {
  final List<CategoryChipData> categories;
  const _CategoriesSheet({required this.categories});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.34), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(top: false, child: LayoutBuilder(builder: (context, c) {
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
        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const SizedBox(width: 4),
            Expanded(child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2))))),
            IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white))
          ]),
          const SizedBox(height: 4),
          Builder(builder: (context) {
            final l10n = context.watch<LocalizationController>();
            return Text(l10n.t('Alle Kategorien'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.white));
          }),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, childAspectRatio: 3/2, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemBuilder: (context, i) {
              final c = categories[i];
              return _CategoryTile(icon: c.icon, label: stackCategoryLabel(c.label));
            },
          ),
        ]);
      })),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final IconData icon; final String label;
  const _CategoryTile({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).maybePop(),
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