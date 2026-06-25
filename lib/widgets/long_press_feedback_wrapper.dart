import 'dart:async';

import 'package:flutter/material.dart';

class LongPressFeedbackWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double pressedScale;

  const LongPressFeedbackWrapper({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 130),
    this.pressedScale = 0.985,
  });

  @override
  State<LongPressFeedbackWrapper> createState() => _LongPressFeedbackWrapperState();
}

class _LongPressFeedbackWrapperState extends State<LongPressFeedbackWrapper> {
  bool _active = false;
  Timer? _holdTimer;
  static const _feedbackDelay = Duration(milliseconds: 230);

  void _setActive(bool value) {
    if (_active == value || !mounted) return;
    setState(() => _active = value);
  }

  void _scheduleHoldFeedback() {
    _holdTimer?.cancel();
    _holdTimer = Timer(_feedbackDelay, () => _setActive(true));
  }

  void _clearHoldFeedback() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _setActive(false);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _scheduleHoldFeedback(),
      onTapUp: (_) => _clearHoldFeedback(),
      onTapCancel: _clearHoldFeedback,
      onLongPress: () {},
      onLongPressEnd: (_) => _clearHoldFeedback(),
      onLongPressCancel: _clearHoldFeedback,
      child: AnimatedScale(
        scale: _active ? widget.pressedScale : 1,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            boxShadow: _active
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.07),
                      blurRadius: 14,
                      spreadRadius: 0.5,
                    ),
                  ]
                : const [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
