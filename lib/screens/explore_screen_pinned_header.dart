import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class PinnedCategoriesHeader extends SliverPersistentHeaderDelegate {
  final WidgetBuilder builder;
  PinnedCategoriesHeader({required this.builder});

  // Thickness adjustments (~1 mm ≈ 6 dp) applied on top and bottom
  static const double _topGapAfterSeparator = 10; // was 16, reduced by ~6
  static const double _iconsHeight = 84; // CategoryIconRow reduced by ~1mm from bottom
  static const double _separatorHeight = 1;
  static const double _bottomPad = 0; // was 6, reduced by ~6

  static const double _totalHeight =
      _topGapAfterSeparator +
      _iconsHeight +
      _separatorHeight +
      _bottomPad;

  @override
  double get minExtent => _totalHeight;
  @override
  double get maxExtent => _totalHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final line = Container(
      height: _separatorHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.white.withValues(alpha: 0.04),
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.04),
        ]),
      ),
    );

    return Stack(children: [
      // Paint the same global background as the app so content below is fully hidden
      Positioned.fill(child: _PinnedHeaderBackgroundReplica()),
      // Foreground content: separators + icons
      Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Top gap (upper separator removed)
          const SizedBox(height: _topGapAfterSeparator),
          // Icons row provided by caller
          Material(color: Colors.transparent, child: SizedBox(height: _iconsHeight, child: builder(context))),
          // Bottom separator (pinned)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: line),
          const SizedBox(height: _bottomPad),
        ],
      ),
    ]);
  }

  @override
  bool shouldRebuild(covariant PinnedCategoriesHeader oldDelegate) => false;
}

class _PinnedHeaderBackgroundReplica extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 36, sigmaY: 36),
          child: Image.asset('assets/images/fulllogo.jpg', fit: BoxFit.cover),
        ),
      ),
      Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.30))),
    ]);
  }
}
