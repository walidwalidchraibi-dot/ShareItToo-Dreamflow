import 'package:flutter/material.dart';

class _PinnedCategoriesHeader extends SliverPersistentHeaderDelegate {
  final WidgetBuilder builder;
  _PinnedCategoriesHeader({required this.builder});

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 64;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(color: Colors.transparent, child: builder(context)),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedCategoriesHeader oldDelegate) => false;
}
