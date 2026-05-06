import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// SIT-styled Glass Time Picker
/// - Runde Uhr zum Antippen: erst Stunden, dann Minuten
/// - Blurred transparent Glass-Card Hintergrund (wie Onboarding)
/// - 24h-Format, kein AM/PM
class SitGlassTimePicker extends StatefulWidget {
  final String title;
  final int initialHour;
  final int initialMinute;

  const SitGlassTimePicker({
    super.key,
    required this.title,
    this.initialHour = 12,
    this.initialMinute = 0,
  });

  /// Shows the picker and returns the selected TimeOfDay, or null if cancelled.
  static Future<TimeOfDay?> show(
    BuildContext context, {
    required String title,
    TimeOfDay? initialTime,
  }) async {
    final init = initialTime ?? TimeOfDay.now();
    return showGeneralDialog<TimeOfDay>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) => SitGlassTimePicker(
        title: title,
        initialHour: init.hour,
        initialMinute: init.minute,
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<SitGlassTimePicker> createState() => _SitGlassTimePickerState();
}

class _SitGlassTimePickerState extends State<SitGlassTimePicker> {
  late int _selectedHour;
  late int _selectedMinute;
  bool _selectingHour = true; // true = Stunden, false = Minuten

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialHour;
    _selectedMinute = widget.initialMinute;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _ClockFace(
                              hour: _selectedHour,
                              minute: _selectedMinute,
                              selectingHour: _selectingHour,
                              onHourSelected: (h) {
                                setState(() {
                                  _selectedHour = h;
                                  _selectingHour = false;
                                });
                              },
                              onMinuteSelected: (m) {
                                setState(() => _selectedMinute = m);
                              },
                              onModeSwitch: () => setState(() => _selectingHour = !_selectingHour),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: _ScrollableTimeDisplay(
                                hour: _selectedHour,
                                minute: _selectedMinute,
                                selectingHour: _selectingHour,
                                onHourChanged: (h) => setState(() {
                                  _selectedHour = h;
                                  _selectingHour = true;
                                }),
                                onMinuteChanged: (m) => setState(() {
                                  _selectedMinute = m;
                                  _selectingHour = false;
                                }),
                                onHourTapped: () => setState(() => _selectingHour = true),
                                onMinuteTapped: () => setState(() => _selectingHour = false),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                              ),
                              child: Text(
                                'Abbrechen',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(
                                  TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: Colors.white.withValues(alpha: 0.18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.30)),
                                ),
                              ),
                              child: const Text(
                                'Uhrzeit anfragen',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollableTimeDisplay extends StatefulWidget {
  final int hour;
  final int minute;
  final bool selectingHour;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;
  final VoidCallback onHourTapped;
  final VoidCallback onMinuteTapped;

  const _ScrollableTimeDisplay({
    required this.hour,
    required this.minute,
    required this.selectingHour,
    required this.onHourChanged,
    required this.onMinuteChanged,
    required this.onHourTapped,
    required this.onMinuteTapped,
  });

  @override
  State<_ScrollableTimeDisplay> createState() => _ScrollableTimeDisplayState();
}

class _ScrollableTimeDisplayState extends State<_ScrollableTimeDisplay> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  bool _isJumping = false;

  @override
  void initState() {
    super.initState();
    _hourController = FixedExtentScrollController(initialItem: widget.hour);
    _minuteController = FixedExtentScrollController(initialItem: widget.minute);
  }

  @override
  void didUpdateWidget(_ScrollableTimeDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hour != widget.hour && _hourController.hasClients) {
      _isJumping = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hourController.hasClients) {
          _hourController.jumpToItem(widget.hour);
        }
        _isJumping = false;
      });
    }
    if (oldWidget.minute != widget.minute && _minuteController.hasClients) {
      _isJumping = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _minuteController.hasClients) {
          _minuteController.jumpToItem(widget.minute);
        }
        _isJumping = false;
      });
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: widget.onHourTapped,
            child: _buildScrollWheel(
              controller: _hourController,
              itemCount: 24,
              onChanged: widget.onHourChanged,
              currentValue: widget.hour,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              ':',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          GestureDetector(
            onTap: widget.onMinuteTapped,
            child: _buildScrollWheel(
              controller: _minuteController,
              itemCount: 60,
              onChanged: widget.onMinuteChanged,
              currentValue: widget.minute,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required ValueChanged<int> onChanged,
    required int currentValue,
  }) {
    return SizedBox(
      width: 44,
      height: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 32,
          diameterRatio: 10.0,
          perspective: 0.001,
          physics: const BouncingScrollPhysics(),
          overAndUnderCenterOpacity: 1.0,
          onSelectedItemChanged: (value) {
            if (!_isJumping) onChanged(value);
          },
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: itemCount,
            builder: (context, index) {
              final isSelected = index == currentValue;
              return Center(
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: isSelected ? 20 : 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ClockFace extends StatefulWidget {
  final int hour;
  final int minute;
  final bool selectingHour;
  final ValueChanged<int> onHourSelected;
  final ValueChanged<int> onMinuteSelected;
  final VoidCallback onModeSwitch;

  const _ClockFace({
    required this.hour,
    required this.minute,
    required this.selectingHour,
    required this.onHourSelected,
    required this.onMinuteSelected,
    required this.onModeSwitch,
  });

  @override
  State<_ClockFace> createState() => _ClockFaceState();
}

class _ClockFaceState extends State<_ClockFace> {
  double _clockSize = 0;
  double _clockCenter = 0;
  double _clockRadius = 0;

  int _calculateHourFromPosition(Offset localPosition) {
    final dx = localPosition.dx - _clockCenter;
    final dy = localPosition.dy - _clockCenter;
    final distance = math.sqrt(dx * dx + dy * dy);
    var angle = math.atan2(dx, -dy);
    if (angle < 0) angle += 2 * math.pi;
    final isInnerRing = distance < _clockRadius * 0.65;
    final position = ((angle / (2 * math.pi) * 12) + 0.5).floor() % 12;
    if (isInnerRing) return position == 0 ? 12 : position;
    return position == 0 ? 0 : position + 12;
  }

  int _calculateMinuteFromPosition(Offset localPosition) {
    final dx = localPosition.dx - _clockCenter;
    final dy = localPosition.dy - _clockCenter;
    var angle = math.atan2(dx, -dy);
    if (angle < 0) angle += 2 * math.pi;
    var m = ((angle / (2 * math.pi) * 60) + 0.5).floor() % 60;
    m = ((m + 2) ~/ 5) * 5;
    if (m >= 60) m = 0;
    return m;
  }

  void _handleTap(Offset localPosition) {
    final dx = localPosition.dx - _clockCenter;
    final dy = localPosition.dy - _clockCenter;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < 20) {
      widget.onModeSwitch();
      return;
    }
    if (widget.selectingHour) {
      widget.onHourSelected(_calculateHourFromPosition(localPosition));
    } else {
      widget.onMinuteSelected(_calculateMinuteFromPosition(localPosition));
    }
  }

  void _handlePan(Offset localPosition) {
    if (widget.selectingHour) {
      widget.onHourSelected(_calculateHourFromPosition(localPosition));
    } else {
      widget.onMinuteSelected(_calculateMinuteFromPosition(localPosition));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _clockSize = constraints.maxWidth;
          _clockCenter = _clockSize / 2;
          _clockRadius = (_clockSize / 2) - 8;
          return GestureDetector(
            onTapDown: (details) => _handleTap(details.localPosition),
            onPanStart: (details) => _handlePan(details.localPosition),
            onPanUpdate: (details) => _handlePan(details.localPosition),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  CustomPaint(
                    size: Size(_clockSize, _clockSize),
                    painter: _ClockHandPainter(
                      hour: widget.hour,
                      minute: widget.minute,
                      selectingHour: widget.selectingHour,
                      radius: _clockRadius,
                    ),
                  ),
                  if (widget.selectingHour) ...[
                    for (int i = 0; i <= 11; i++)
                      _buildHourNumber(i == 0 ? 0 : i + 12, i, _clockRadius * 0.82, false),
                    for (int i = 1; i <= 12; i++)
                      _buildHourNumber(i, i % 12, _clockRadius * 0.52, true),
                  ] else ...[
                    for (int i = 0; i < 12; i++) _buildMinuteNumber(i * 5, _clockCenter, _clockRadius * 0.82),
                  ],
                  Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHourNumber(int hour, int position, double r, bool isInner) {
    final displayValue = hour == 0 ? '00' : hour.toString();
    final angle = position * (2 * math.pi / 12) - math.pi / 2;
    final x = _clockCenter + r * math.cos(angle);
    final y = _clockCenter + r * math.sin(angle);
    final isSelected = widget.selectingHour && hour == widget.hour;
    return Positioned(
      left: x - 14,
      top: y - 14,
      child: Container(
        width: 28,
        height: 28,
        decoration: isSelected
            ? BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.25))
            : null,
        child: Center(
          child: Text(
            displayValue,
            style: TextStyle(
              fontSize: isInner ? 11 : 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: isInner ? 0.5 : 0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinuteNumber(int value, double center, double r) {
    final displayValue = value.toString().padLeft(2, '0');
    final angle = value * (2 * math.pi / 60) - math.pi / 2;
    final x = center + r * math.cos(angle);
    final y = center + r * math.sin(angle);
    final isSelected = !widget.selectingHour && value == widget.minute;
    return Positioned(
      left: x - 14,
      top: y - 14,
      child: Container(
        width: 28,
        height: 28,
        decoration: isSelected
            ? BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.25))
            : null,
        child: Center(
          child: Text(
            displayValue,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClockHandPainter extends CustomPainter {
  final int hour;
  final int minute;
  final bool selectingHour;
  final double radius;

  _ClockHandPainter({
    required this.hour,
    required this.minute,
    required this.selectingHour,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    double angle;
    double handLength;
    if (selectingHour) {
      final isInner = hour >= 1 && hour <= 12;
      angle = (hour % 12) * (2 * math.pi / 12) - math.pi / 2;
      handLength = isInner ? radius * 0.35 : radius * 0.62;
    } else {
      angle = minute * (2 * math.pi / 60) - math.pi / 2;
      handLength = radius * 0.62;
    }

    final endPoint = Offset(
      center.dx + handLength * math.cos(angle),
      center.dy + handLength * math.sin(angle),
    );

    canvas.drawLine(center, endPoint, paint);
    canvas.drawCircle(endPoint, 4, Paint()..color = Colors.white.withValues(alpha: 0.8));
    canvas.drawCircle(center, 4, Paint()..color = Colors.white.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(covariant _ClockHandPainter oldDelegate) =>
      hour != oldDelegate.hour ||
      minute != oldDelegate.minute ||
      selectingHour != oldDelegate.selectingHour;
}
