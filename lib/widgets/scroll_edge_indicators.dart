import 'dart:async';
import 'package:flutter/material.dart';

/// A reusable overlay that shows subtle left/right scroll indicators
/// for horizontal ListView/PageView content. Indicators fade in on scroll
/// and fade out after a short inactivity timeout. Optionally tappable to
/// scroll by one viewport width (or one page on PageView).
class ScrollEdgeIndicators extends StatefulWidget {
  final Widget child;
  final ScrollController? scrollController;
  final PageController? pageController;
  final int? pageCount;
  final bool tapToScroll;
  final bool showLeft;
  final bool showRight;
  // When true, the respective arrow remains translucent even if it can scroll
  final bool forceLeftTranslucent;
  final bool forceRightTranslucent;

  const ScrollEdgeIndicators.list({
    super.key,
    required this.child,
    required ScrollController controller,
    this.tapToScroll = true,
    this.showLeft = true,
    this.showRight = true,
    this.forceLeftTranslucent = false,
    this.forceRightTranslucent = false,
  })
      : scrollController = controller,
        pageController = null,
        pageCount = null;

  const ScrollEdgeIndicators.page({
    super.key,
    required this.child,
    required PageController controller,
    required this.pageCount,
    this.tapToScroll = true,
    this.showLeft = true,
    this.showRight = true,
    this.forceLeftTranslucent = false,
    this.forceRightTranslucent = false,
  })
      : pageController = controller,
        scrollController = null;

  @override
  State<ScrollEdgeIndicators> createState() => _ScrollEdgeIndicatorsState();
}

class _ScrollEdgeIndicatorsState extends State<ScrollEdgeIndicators>
    with SingleTickerProviderStateMixin {
  bool _canLeft = false;
  bool _canRight = false;
  bool _active = true; // kept true so arrows stay visible
  Timer? _hideTimer;
  late final AnimationController _flashController;
  late final Animation<double> _flashOpacity;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _flashOpacity = const AlwaysStoppedAnimation<double>(1.0);
    widget.scrollController?.addListener(_handleScrollChanged);
    widget.pageController?.addListener(_handleScrollChanged);
    // Compute initial state on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recomputeEdges();
    });
  }

  @override
  void didUpdateWidget(covariant ScrollEdgeIndicators oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_handleScrollChanged);
      widget.scrollController?.addListener(_handleScrollChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeEdges());
    }
    if (oldWidget.pageController != widget.pageController) {
      oldWidget.pageController?.removeListener(_handleScrollChanged);
      widget.pageController?.addListener(_handleScrollChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeEdges());
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_handleScrollChanged);
    widget.pageController?.removeListener(_handleScrollChanged);
    _hideTimer?.cancel();
    _flashController.dispose();
    super.dispose();
  }

  void _handleScrollChanged() {
    _setActive();
    _recomputeEdges();
  }

  void _setActive() {
    if (!_active) setState(() => _active = true);
  }

  void _scheduleHide() {
    // No-op: keep arrows visible at all times
  }

  void _recomputeEdges() {
    if (widget.pageController != null) {
      final ctrl = widget.pageController!;
      final count = widget.pageCount ?? 1;
      final pos = ctrl.positions.isNotEmpty ? ctrl.position : null;
      double page = 0;
      if (pos != null) {
        // page can be null briefly; guard with pixels/viewport
        final raw = ctrl.page;
        if (raw != null) {
          page = raw;
        } else if (pos.viewportDimension > 0) {
          page = pos.pixels / pos.viewportDimension;
        }
      }
      final canLeft = page > 0.01;
      final canRight = page < (count - 1) - 0.01;
      if (canLeft != _canLeft || canRight != _canRight) {
        setState(() {
          _canLeft = canLeft;
          _canRight = canRight;
        });
      }
      return;
    }

    if (widget.scrollController != null) {
      final ctrl = widget.scrollController!;
      if (!ctrl.hasClients) {
        if (_canLeft || _canRight) {
          setState(() {
            _canLeft = false;
            _canRight = false;
          });
        }
        return;
      }
      final pos = ctrl.position;
      final eps = 0.5;
      final canLeft = pos.pixels > eps;
      final canRight = pos.pixels < (pos.maxScrollExtent - eps);
      if (canLeft != _canLeft || canRight != _canRight) {
        setState(() {
          _canLeft = canLeft;
          _canRight = canRight;
        });
      }
    }
  }

  Future<void> _tapLeft(BuildContext context) async {
    if (!widget.tapToScroll) return;
    if (widget.pageController != null) {
      final ctrl = widget.pageController!;
      final pos = ctrl.page ?? 0;
      final target = (pos - 1).floor().clamp(0, (widget.pageCount ?? 1) - 1);
      await ctrl.animateToPage(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
      return;
    }
    final ctrl = widget.scrollController!;
    if (!ctrl.hasClients) return;
    final position = ctrl.position;
    final target = (position.pixels - position.viewportDimension).clamp(0.0, position.maxScrollExtent);
    await ctrl.animateTo(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  Future<void> _tapRight(BuildContext context) async {
    if (!widget.tapToScroll) return;
    if (widget.pageController != null) {
      final ctrl = widget.pageController!;
      final pos = ctrl.page ?? 0;
      final maxIndex = (widget.pageCount ?? 1) - 1;
      final target = (pos + 1).ceil().clamp(0, maxIndex);
      await ctrl.animateToPage(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
      return;
    }
    final ctrl = widget.scrollController!;
    if (!ctrl.hasClients) return;
    final position = ctrl.position;
    final target = (position.pixels + position.viewportDimension).clamp(0.0, position.maxScrollExtent);
    await ctrl.animateTo(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    // Keep arrows visible at all times; dim when scrolling isn't possible.
    final showLeft = widget.showLeft;
    final showRight = widget.showRight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final vCenter = h / 2;
        final leftActive = Colors.white.withValues(alpha: 0.85);
        final leftInactive = Colors.white.withValues(alpha: 0.25);
        final rightActive = Colors.white.withValues(alpha: 0.85);
        final rightInactive = Colors.white.withValues(alpha: 0.25);

        final leftColor = widget.forceLeftTranslucent
            ? leftInactive
            : (_canLeft ? leftActive : leftInactive);
        final rightColor = widget.forceRightTranslucent
            ? rightInactive
            : (_canRight ? rightActive : rightInactive);

        return Stack(
          children: [
            Positioned.fill(child: widget.child),

            // Optional subtle edge gradients
            if (showLeft)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (showRight)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Left arrow (nudged ~2mm outward to the left)
            if (showLeft)
              Positioned(
                left: -12, // ~2mm on mdpi (~12dp)
                top: vCenter - 18,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkResponse(
                    onTap: _canLeft ? () => _tapLeft(context) : null,
                    radius: 22,
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(Icons.chevron_left, size: 26, color: leftColor),
                    ),
                  ),
                ),
              ),

            // Right arrow (nudged ~2mm outward to the right)
            if (showRight)
              Positioned(
                right: -12, // ~2mm on mdpi (~12dp)
                top: vCenter - 18,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkResponse(
                    onTap: _canRight ? () => _tapRight(context) : null,
                    radius: 22,
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(Icons.chevron_right, size: 26, color: rightColor),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
