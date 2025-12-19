import 'package:flutter/material.dart';
import 'dart:ui';

class ModernRangePickerSheet extends StatefulWidget {
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange? initialRange;
  // When true, the user may pick the same calendar day for start and end.
  // Useful for hourly rentals.
  final bool allowSameDayEnd;
  // New: mark days that are already booked (start inclusive, end exclusive)
  final List<DateTimeRange> unavailableRanges;
  const ModernRangePickerSheet({super.key, required this.firstDate, required this.lastDate, this.initialRange, this.allowSameDayEnd = false, this.unavailableRanges = const []});

  @override
  State<ModernRangePickerSheet> createState() => _ModernRangePickerSheetState();
}

class _ModernRangePickerSheetState extends State<ModernRangePickerSheet> {
  late DateTime _visibleMonth; // first day of month
  DateTime? _start;
  DateTime? _end;
  bool _overlapsBlocked = false;

  static const _monthsDe = [
    'Januar','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember'
  ];
  static const _wdDe = ['Mo','Di','Mi','Do','Fr','Sa','So']; // Monday start

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    if (widget.initialRange != null) {
      _start = _stripTime(widget.initialRange!.start);
      _end = _stripTime(widget.initialRange!.end);
      _visibleMonth = DateTime(_start!.year, _start!.month, 1);
    }
  }

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _isSameOrAfter(DateTime a, DateTime b) => !a.isBefore(b);
  bool _isStrictBefore(DateTime a, DateTime b) => a.isBefore(b);
  String _fmtFull(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isDisabled(DateTime day) => day.isBefore(_stripTime(widget.firstDate)) || day.isAfter(_stripTime(widget.lastDate));

  bool _isBookedDay(DateTime day) {
    final d = _stripTime(day);
    for (final r in widget.unavailableRanges) {
      final s = _stripTime(r.start);
      final e = _stripTime(r.end);
      // booked covers [s, e) days
      if (_isSameOrAfter(d, s) && _isStrictBefore(d, e)) return true;
    }
    return false;
  }

  bool _rangeOverlapsBooked(DateTime a, DateTime b) {
    final s = _stripTime(a);
    final e = _stripTime(b);
    final start = s.isBefore(e) ? s : e;
    final end = s.isBefore(e) ? e : s;
    for (final r in widget.unavailableRanges) {
      final rs = _stripTime(r.start);
      final re = _stripTime(r.end);
      // Overlap for day-ranges when requestedStart < bookedEnd && requestedEnd > bookedStart
      if (start.isBefore(re) && end.isAfter(rs)) return true;
    }
    return false;
  }

  void _onDayTap(DateTime day) {
    if (_isDisabled(day) || _isBookedDay(day)) return;
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        _start = day; _end = null; _overlapsBlocked = false;
      } else {
        // Allow choosing the same day as end only when enabled
        final same = _isSameDay(day, _start!);
        if (day.isBefore(_start!) || (same && !widget.allowSameDayEnd)) {
          _start = day; _end = null; _overlapsBlocked = false;
        } else {
          _end = day; // Do not auto-close; user confirms via "Fertig"
          _overlapsBlocked = _rangeOverlapsBooked(_start!, _end!);
        }
      }
    });
  }

  void _prevMonth() {
    final prev = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    if (!prev.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month, 1))) {
      setState(() => _visibleMonth = prev);
    }
  }

  void _nextMonth() {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    final lastBound = DateTime(widget.lastDate.year, widget.lastDate.month, 1);
    if (!next.isAfter(lastBound)) {
      setState(() => _visibleMonth = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = Colors.black.withValues(alpha: 0.5);
    final border = Colors.white.withValues(alpha: 0.10);
    final headerText = Colors.white;
    final subText = Colors.white.withValues(alpha: 0.64);
    final primary = const Color(0xFF0EA5E9);
    final danger = const Color(0xFFF43F5E);

    return Stack(
      children: [
        // Blurred, tinted backdrop behind the calendar
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            // Keep the backdrop mostly just blurred with a very subtle tint
            child: Container(color: Colors.black.withValues(alpha: 0.08)),
          ),
        ),
        SafeArea(
          top: false,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: border),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header row with month navigation and a close button
                    Row(
                      children: [
                        IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left, color: Colors.white)),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${_monthsDe[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                        ),
                        IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right, color: Colors.white)),
                        const SizedBox(width: 4),
                        // Close without selection
                        IconButton(
                          tooltip: 'Schließen',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _WeekdayRow(color: subText),
                    const SizedBox(height: 6),
                    _MonthGrid(
                      month: _visibleMonth,
                      firstDate: widget.firstDate,
                      lastDate: widget.lastDate,
                      start: _start,
                      end: _end,
                      onTap: _onDayTap,
                      primary: primary,
                      textColor: headerText,
                      subText: subText,
                      danger: danger,
                      isBooked: _isBookedDay,
                    ),
                    const SizedBox(height: 8),
                    _HintRow(
                      start: _start,
                      end: _end,
                      primary: primary,
                      textColor: headerText,
                      subText: subText,
                      blocked: _overlapsBlocked,
                    ),
                    const SizedBox(height: 12),
                    // Footer with left "Löschen" and right "Fertig" buttons only
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: (_start != null || _end != null)
                              ? () {
                                  setState(() {
                                    _start = null;
                                    _end = null;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.delete_outline, color: Colors.white),
                          label: const Text('Löschen', style: TextStyle(color: Colors.white)),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: (_start != null && _end != null && !_overlapsBlocked)
                              ? () {
                                  final range = DateTimeRange(start: _start!, end: _end!);
                                  Navigator.of(context).pop(range);
                                }
                              : null,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Fertig'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Legacy header removed; header now lives inline to allow a close button.

class _WeekdayRow extends StatelessWidget {
  final Color color;
  const _WeekdayRow({required this.color});
  static const _wdDe = ['Mo','Di','Mi','Do','Fr','Sa','So'];
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final d in _wdDe) Expanded(child: Center(child: Text(d, style: TextStyle(color: color, fontWeight: FontWeight.w600))))
    ]);
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month; // first day
  final DateTime firstDate; final DateTime lastDate;
  final DateTime? start; final DateTime? end;
  final void Function(DateTime) onTap;
  final Color primary; final Color textColor; final Color subText; final Color danger;
  final bool Function(DateTime) isBooked;
  const _MonthGrid({required this.month, required this.firstDate, required this.lastDate, required this.start, required this.end, required this.onTap, required this.primary, required this.textColor, required this.subText, required this.danger, required this.isBooked});

  int _daysInMonth(DateTime m) => DateTime(m.year, m.month + 1, 0).day;
  int _mondayBasedWeekday(DateTime d) => (d.weekday + 6) % 7; // 0..6, 0=Mon

  @override
  Widget build(BuildContext context) {
    final days = _daysInMonth(month);
    final firstW = _mondayBasedWeekday(month);
    final totalCells = ((firstW + days + 6) ~/ 7) * 7; // round up to full weeks

    final cells = <DateTime?>[];
    // Leading empty cells
    for (int i = 0; i < firstW; i++) { cells.add(null); }
    // Current month
    for (int d = 1; d <= days; d++) { cells.add(DateTime(month.year, month.month, d)); }
    // Trailing to fill grid
    while (cells.length < totalCells) { cells.add(null); }

    return Column(children: [
      for (int row = 0; row < cells.length / 7; row++)
        Row(children: [
          for (int col = 0; col < 7; col++)
            Expanded(child: _DayCell(
              day: cells[row * 7 + col],
              firstDate: firstDate, lastDate: lastDate,
              start: start, end: end,
              onTap: onTap,
              primary: primary, textColor: textColor, subText: subText, danger: danger, isBooked: isBooked,
            )),
        ]),
    ]);
  }
}

class _DayCell extends StatelessWidget {
  final DateTime? day; final DateTime firstDate; final DateTime lastDate; final DateTime? start; final DateTime? end; final void Function(DateTime) onTap; final Color primary; final Color textColor; final Color subText; final Color danger; final bool Function(DateTime) isBooked;
  const _DayCell({required this.day, required this.firstDate, required this.lastDate, required this.start, required this.end, required this.onTap, required this.primary, required this.textColor, required this.subText, required this.danger, required this.isBooked});

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _disabled(DateTime d) => d.isBefore(_strip(firstDate)) || d.isAfter(_strip(lastDate));
  bool _inRange(DateTime d) {
    if (start == null || end == null) return false;
    final s = _strip(start!); final e = _strip(end!);
    return (d.isAfter(s) && d.isBefore(e)) || _isSameDay(d, s) || _isSameDay(d, e);
  }

  @override
  Widget build(BuildContext context) {
    if (day == null) return const SizedBox(height: 44);
    final d = day!;
    final isStart = start != null && _isSameDay(d, start!);
    final isEnd = end != null && _isSameDay(d, end!);
    final isRange = _inRange(d);
    final disabled = _disabled(d) || isBooked(d);

    final bgRange = primary.withValues(alpha: 0.18);
    final bgSE = primary; // start/end solid
    final bgBooked = danger.withValues(alpha: 0.20);
    final txtOnPrimary = Colors.white;
    final txtDefault = (isBooked(d)) ? danger : (disabled ? subText.withValues(alpha: 0.4) : textColor);

    Widget content = Center(child: Text('${d.day}', style: TextStyle(color: (isStart || isEnd) ? txtOnPrimary : txtDefault, fontWeight: FontWeight.w600)));

    Widget decorated = Container(height: 44, alignment: Alignment.center, child: content);

    if (isRange && !(isStart || isEnd)) {
      decorated = Container(height: 44, decoration: BoxDecoration(color: bgRange), child: content);
    }

    if (isStart || isEnd) {
      decorated = Container(height: 44, decoration: BoxDecoration(color: bgSE, borderRadius: BorderRadius.circular(12)), child: content);
    }

    // Booked days: red tinted background, disabled tap
    if (isBooked(d)) {
      decorated = Container(height: 44, decoration: BoxDecoration(color: bgBooked, borderRadius: BorderRadius.circular(8)), child: content);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: disabled ? null : () => onTap(_strip(d)),
          child: decorated,
        ),
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  final DateTime? start; final DateTime? end; final Color primary; final Color textColor; final Color subText; final bool blocked;
  const _HintRow({required this.start, required this.end, required this.primary, required this.textColor, required this.subText, this.blocked = false});

  @override
  Widget build(BuildContext context) {
    String text;
    if (start == null) {
      text = 'Wähle Startdatum';
    } else if (end == null) {
      text = 'Wähle Enddatum';
    } else {
      text = blocked ? 'In diesem Zeitraum bereits gebucht' : 'Bereit zur Bestätigung';
    }
    // Centered hint only; no date summaries inside the sheet
    return Center(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(blocked ? Icons.block : Icons.date_range, color: blocked ? const Color(0xFFF43F5E) : Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: blocked ? const Color(0xFFF43F5E) : subText)),
      ]),
    );
  }

  String _fmtFull(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }
}
