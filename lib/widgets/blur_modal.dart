import 'dart:ui';
import 'package:flutter/material.dart';

/// Shows a blurred-background bottom sheet with a glassy container.
/// The [child] should include its own padding and (optionally) a sticky footer.
Future<T?> showBlurBottomSheet<T>(BuildContext context, {required Widget child, double maxHeightFactor = 0.9}) {
  final media = MediaQuery.of(context);
  final maxH = media.size.height * maxHeightFactor;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) {
      return Stack(children: [
        Positioned.fill(
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: const SizedBox()),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: _GlassSheet(child: child),
          ),
        ),
      ]);
    },
  );
}

/// A glassy container with rounded top corners and a top handle.
class _GlassSheet extends StatelessWidget {
  final Widget child;
  const _GlassSheet({required this.child});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(99))),
        const SizedBox(height: 8),
        Flexible(child: child),
      ])),
    );
  }
}

/// Standardized structure for modals: title, optional actions, body, and a sticky bottom area.
class SheetScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? bottomBar;
  final List<Widget>? actions;
  const SheetScaffold({super.key, required this.title, required this.body, this.bottomBar, this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
        child: Row(children: [
          Expanded(child: Text(title, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface))),
          ...?actions,
        ]),
      ),
      const Divider(height: 1, thickness: 1, color: Colors.white24),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: body,
        ),
      ),
      if (bottomBar != null) ...[
        const Divider(height: 1, thickness: 1, color: Colors.white24),
        SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: bottomBar!)),
      ],
    ]);
  }
}
