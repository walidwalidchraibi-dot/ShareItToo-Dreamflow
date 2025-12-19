import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:lendify/theme.dart';
import 'package:lendify/widgets/outline_icon.dart';
import 'package:lendify/utils/category_label.dart';
import 'package:provider/provider.dart';
import 'package:lendify/widgets/scroll_edge_indicators.dart';
import 'package:lendify/services/localization_service.dart';

class CategoryIconDataModel {
  final String id;
  final IconData icon;
  final String label;
  const CategoryIconDataModel({required this.id, required this.icon, required this.label});
}

class CategoryIconRow extends StatefulWidget {
  final List<CategoryIconDataModel> categories;
  final ValueChanged<CategoryIconDataModel>? onSelected;
  final VoidCallback? onAllCategoriesTap;
  const CategoryIconRow({super.key, required this.categories, this.onSelected, this.onAllCategoriesTap});

  @override
  State<CategoryIconRow> createState() => _CategoryIconRowState();
}

class _CategoryIconRowState extends State<CategoryIconRow> {
  int _selectedIndex = -1;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Match page horizontal padding (aligns with "Neue Anzeige" button in SearchHeader)
    const horizontalPadding = 16.0;
    // Exactly 5 visible at once
    final itemWidth = (width - (horizontalPadding * 2)) / 5;
    // Increase spacing between circles by ~0.3mm total (previous +0.2mm, now +0.1mm more)
    const baseSpacing = 6.0;
    const extraMm = 0.3; // mm
    final spacing = baseSpacing + (extraMm * 160 / 25.4);

    final tiles = <Widget>[];
    tiles.add(_AllTile(width: itemWidth, onTap: widget.onAllCategoriesTap));
    for (int i = 0; i < widget.categories.length; i++) {
      final c = widget.categories[i];
      final isSelected = i == _selectedIndex;
      tiles.add(_CategoryTile(width: itemWidth, label: c.label, icon: c.icon, isSelected: isSelected, onTap: () {
        setState(() => _selectedIndex = i);
        widget.onSelected?.call(c);
      }));
    }
    // No artificial trailing spacer — we compute a precise scroll extension below
    // so that the last circle aligns directly under the filter button.

    // Ziel: Am linken Endanschlag soll der Mittelpunkt des letzten Kreises
    // exakt unter dem Filter‑Kreis stehen.
    // Der Filter hat 16px rechten Außenabstand und 44px Durchmesser ⇒ Center 22px
    // von seinem eigenen Rand. Daraus ergibt sich eine Ziel‑Konstante von 60px.
    //
    // Zwei Fälle:
    //  1) itemWidth > 60: Wir müssen FRÜHER stoppen (kleineres maxScrollExtent).
    //     Das erreichen wir per Cutoff‑Physik: cutoff = itemWidth - 60.
    //  2) itemWidth < 60: Wir brauchen MEHR Inhalt, um weiter nach links scrollen
    //     zu können. Das erreichen wir mit rechter Innen‑Padding: rightPad = 60 - itemWidth.
    //
    // Diese Kombination garantiert die exakte Ausrichtung über alle Displaybreiten.
    final double cutoffPx = math.max(0.0, itemWidth - 60.0);
    final double rightPadPx = math.max(0.0, 60.0 - itemWidth);

    return SizedBox(
      height: 90,
      child: ScrollEdgeIndicators.list(
        controller: _scrollController,
        showLeft: false,
        showRight: true,
        forceRightTranslucent: true,
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
            // Stoppe etwas FRÜHER nach links, sodass der letzte Kreis unter dem
            // Filter‑Kreis steht. Ein positives cutoff reduziert die maxScrollExtent.
            physics: TrailingCutoffScrollPhysics(
              cutoff: cutoffPx,
            ),
          // Align left edge with the surrounding card content
          padding: EdgeInsets.only(
            left: horizontalPadding,
            // Falls itemWidth < 60, erweitern wir den Inhalt rechts genau um
            // (60 - itemWidth), damit der letzte Kreis weiter nach links wandern kann.
            right: rightPadPx,
          ),
          itemBuilder: (context, index) => tiles[index],
          separatorBuilder: (_, __) => SizedBox(width: spacing),
          itemCount: tiles.length,
        ),
      ),
    );
  }
}

class _AllTile extends StatefulWidget {
  final double width; final VoidCallback? onTap;
  const _AllTile({required this.width, this.onTap});
  @override
  State<_AllTile> createState() => _AllTileState();
}

class _AllTileState extends State<_AllTile> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    final color = _hovering ? BrandColors.primary : BrandColors.inactiveNav;
    return FocusableActionDetector(
      onShowFocusHighlight: (hasFocus) => setState(() => _hovering = hasFocus),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: widget.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border.all(color: BrandColors.primary, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 4)),
                    BoxShadow(color: BrandColors.goldShadow.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                  child: Center(
                    child: AnimatedScale(
                      scale: _hovering ? 1.33 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: MaterialOutlineIcon(icon: Icons.apps, color: color, size: 20),
                    ),
                  ),
              ),
              const SizedBox(height: 6),
              Builder(builder: (context) {
                final l10n = context.watch<LocalizationController>();
                // Widen label to avoid truncation; keep visual center under the 44px circle
                const labelWidth = 66.0; // wider than 44 to show full text on 2 lines
                final dx = -((labelWidth - 44) / 2);
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: SizedBox(
                    width: labelWidth,
                    child: Text(
                      stackCategoryLabel(l10n.t('Alle Kategorien')),
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.visible, // keine „…“
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, height: 1.1, fontWeight: FontWeight.w600, color: color),
                    ),
                  ),
                );
              })
            ]),
          ),
        ),
      ),
    );
  }
}

/// Custom physics to limit the maximum left-ward scroll by a fixed trailing cutoff.
/// This reduces the effective maxScrollExtent by [cutoff] pixels, making the list
/// stop earlier when dragging to the left (revealing the end of the list).
class TrailingCutoffScrollPhysics extends ScrollPhysics {
  final double cutoff;
  const TrailingCutoffScrollPhysics({required this.cutoff, super.parent});

  @override
  TrailingCutoffScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return TrailingCutoffScrollPhysics(
      cutoff: cutoff,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Respect parent's boundaries first
    final parentResult = parent?.applyBoundaryConditions(position, value) ?? 0.0;
    if (parentResult != 0.0) return parentResult;

    // Compute an adjusted maximum extent reduced by the cutoff
    final double adjustedMax = math.max(
      position.minScrollExtent,
      position.maxScrollExtent - cutoff,
    );

    // If proposed value goes past our adjusted maximum, clamp it
    if (value > adjustedMax) {
      return value - adjustedMax;
    }
    // Also protect the min extent as usual
    if (value < position.minScrollExtent) {
      return value - position.minScrollExtent;
    }
    return 0.0;
  }
}

class _CategoryTile extends StatefulWidget {
  final double width; final String label; final IconData icon; final bool isSelected; final VoidCallback onTap;
  const _CategoryTile({required this.width, required this.label, required this.icon, required this.isSelected, required this.onTap});
  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected || _hovering;
    final color = active ? BrandColors.primary : BrandColors.inactiveNav;
    return FocusableActionDetector(
      onShowFocusHighlight: (hasFocus) => setState(() => _hovering = hasFocus),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: widget.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border.all(color: BrandColors.primary, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 4)),
                    BoxShadow(color: BrandColors.goldShadow.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Center(
                    child: AnimatedScale(
                      scale: _hovering ? 1.33 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: MaterialOutlineIcon(icon: widget.icon, size: 22, color: color),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Widen label to avoid truncation; keep visual center under the 44px circle
              Builder(builder: (_) {
                const labelWidth = 66.0;
                final dx = -((labelWidth - 44) / 2);
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: SizedBox(
                    width: labelWidth,
                    child: Text(
                      stackCategoryLabel(widget.label),
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.visible, // keine „…“
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: color, height: 1.1),
                    ),
                  ),
                );
              })
            ]),
          ),
        ),
      ),
    );
  }
}
