import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/theme.dart';

class SelectRentalDurationScreen extends StatefulWidget {
  final Item item;
  final DateTimeRange? initialRange;
  const SelectRentalDurationScreen({super.key, required this.item, this.initialRange});

  @override
  State<SelectRentalDurationScreen> createState() => _SelectRentalDurationScreenState();
}

class _SelectRentalDurationScreenState extends State<SelectRentalDurationScreen> {
  late DateTime _firstDate;
  late DateTime _lastDate;
  late DateTime _visibleMonth; // first of month
  List<DateTimeRange> _unavailable = const [];

  DateTime? _start;
  DateTime? _end; // end-exclusive
  int _selectedDays = 1;
  bool _checking = false;
  bool _overlapsBlocked = false;

  double _activeDiscountPct = 0.0; // kept for internal sync but not shown in UI

  // Delivery/pickup choices to be selected directly on this screen
  bool _hinwegLandlord = false; // Lieferung bei Übergabe durch Vermieter
  bool _rueckwegLandlord = false; // Abholung bei Rückgabe durch Vermieter
  // Persisted address info (from previous step/page) to estimate distance
  String _addressLine = '';
  String? _addressCity;
  double? _addressLat;
  double? _addressLng;
  // Express choice for delivery at dropoff
  bool _wantExpress = false;

  static const _monthsDe = ['Januar','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _firstDate = DateTime(now.year, now.month, now.day);
    _lastDate = DateTime(now.year + 1, now.month, now.day);
    _visibleMonth = DateTime(_firstDate.year, _firstDate.month, 1);
    final r = widget.initialRange;
    if (r != null) {
      _start = _strip(r.start);
      _end = _strip(r.end);
      _selectedDays = max(1, _end!.difference(_start!).inDays);
      _visibleMonth = DateTime(_start!.year, _start!.month, 1);
      _recomputeDiscount();
    }
    _loadUnavailable();
    _loadSavedDeliverySelection();
  }

  DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _loadUnavailable() async {
    final ranges = await DataService.getUnavailableRangesForItem(widget.item.id);
    if (!mounted) return;
    setState(() => _unavailable = ranges);
    if (_start != null && _end != null) {
      setState(() => _overlapsBlocked = _rangeOverlapsBooked(_start!, _end!));
    }
  }

  Future<void> _loadSavedDeliverySelection() async {
    try {
      final saved = await DataService.getSavedDeliverySelection(widget.item.id);
      if (!mounted) return;
      setState(() {
        _hinwegLandlord = saved != null ? (saved['hinweg'] == true) : false;
        _rueckwegLandlord = saved != null ? (saved['rueckweg'] == true) : false;
        _addressLine = saved != null ? ((saved['addressLine'] as String?) ?? '') : '';
        _addressCity = saved != null ? (saved['city'] as String?) : null;
        _addressLat = saved != null ? (saved['lat'] as num?)?.toDouble() : null;
        _addressLng = saved != null ? (saved['lng'] as num?)?.toDouble() : null;
        _wantExpress = (saved != null ? (saved['express'] == true) : false) && widget.item.offersExpressAtDropoff;
        // Respect item capabilities
        if (!widget.item.offersDeliveryAtDropoff) _hinwegLandlord = false;
        if (!widget.item.offersPickupAtReturn) _rueckwegLandlord = false;
      });
    } catch (e) {
      // ignore but keep defaults
    }
  }

  void _persistDeliverySelection() {
    DataService.setSavedDeliverySelection(
      widget.item.id,
      hinweg: _hinwegLandlord && widget.item.offersDeliveryAtDropoff,
      rueckweg: _rueckwegLandlord && widget.item.offersPickupAtReturn,
      addressCity: _addressCity,
      addressLine: _addressLine,
      // Persist express choice regardless of item flag so UI can restore user intent
      express: _wantExpress,
      lat: _addressLat,
      lng: _addressLng,
    );
  }

  double? _savedDistanceKm() {
    if (_addressLat != null && _addressLng != null) {
      return DataService.estimateDistanceKm(widget.item.lat, widget.item.lng, _addressLat!, _addressLng!);
    }
    if (_addressLine.trim().isNotEmpty) {
      return DataService.estimateDistanceKmFromAddressLine(widget.item.lat, widget.item.lng, _addressLine);
    }
    if ((_addressCity != null) && _addressCity!.isNotEmpty) {
      return DataService.estimateDistanceKmToCity(widget.item.lat, widget.item.lng, _addressCity!);
    }
    return null;
  }

  bool _isBookedDay(DateTime d) {
    final day = _strip(d);
    for (final r in _unavailable) {
      final s = _strip(r.start);
      final e = _strip(r.end);
      if (!day.isBefore(s) && day.isBefore(e)) return true; // [s, e)
    }
    return false;
  }

  bool _rangeOverlapsBooked(DateTime a, DateTime b) {
    final s = _strip(a); final e = _strip(b);
    final start = s.isBefore(e) ? s : e; final end = s.isBefore(e) ? e : s;
    for (final r in _unavailable) {
      final rs = _strip(r.start); final re = _strip(r.end);
      if (start.isBefore(re) && end.isAfter(rs)) return true;
    }
    return false;
  }

  void _recomputeDiscount() {
    if (_start == null || _end == null) {
      setState(() => _activeDiscountPct = 0.0);
      return;
    }
    final d = max(1, _end!.difference(_start!).inDays);
    final tuple = DataService.computeTotalWithDiscounts(item: widget.item, days: d);
    setState(() => _activeDiscountPct = tuple.$3);
  }

  // 0 = Abgabe, 1 = Rückgabe (Chrome-style tabs within one card)
  int _deliveryTabIndex = 0;

  void _onDayTap(DateTime day) {
    if (day.isBefore(_firstDate) || day.isAfter(_lastDate) || _isBookedDay(day)) return;
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        // Start a fresh selection and allow the user to pick the end manually,
        // regardless of any selected chip.
        _start = _strip(day);
        _end = null;
        _selectedDays = 1; // single day by default until end is chosen
        _overlapsBlocked = false;
      } else {
        if (day.isBefore(_start!)) {
          _start = _strip(day);
          _end = null;
          _overlapsBlocked = false;
        } else {
          // Include the tapped end day fully by using end-exclusive semantics (end = tapped + 1 day)
          _end = _strip(day).add(const Duration(days: 1));
          _overlapsBlocked = _rangeOverlapsBooked(_start!, _end!);
          _selectedDays = max(1, _end!.difference(_start!).inDays);
        }
      }
      _recomputeDiscount();
    });
  }

  void _prevMonth() {
    final prev = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    if (!prev.isBefore(DateTime(_firstDate.year, _firstDate.month, 1))) {
      setState(() => _visibleMonth = prev);
    }
  }

  void _nextMonth() {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    final lastBound = DateTime(_lastDate.year, _lastDate.month, 1);
    if (!next.isAfter(lastBound)) {
      setState(() => _visibleMonth = next);
    }
  }

  (DateTime, DateTime)? _findEarliestRange(int days) {
    final cap = _lastDate;
    DateTime cursor = _start ?? _firstDate;
    while (!cursor.isAfter(cap)) {
      final end = cursor.add(Duration(days: days));
      if (end.isAfter(_lastDate.add(const Duration(days: 1)))) break;
      if (!_rangeOverlapsBooked(cursor, end)) {
        return (cursor, end);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return null;
  }

  List<_ThresholdChip> get _thresholdChips {
    if (!widget.item.autoApplyDiscounts || widget.item.longRentalDiscounts.isEmpty) return const [];
    final tiers = List.of(widget.item.longRentalDiscounts)
      ..removeWhere((t) => t.days <= 1)
      ..sort((a, b) => a.days.compareTo(b.days));
    final maxPct = tiers.fold<double>(0, (p, e) => e.discountPercent > p ? e.discountPercent : p);
    return [
      for (final t in tiers)
        _ThresholdChip(days: t.days, label: 'ab ${t.days} Tagen ${t.discountPercent.toStringAsFixed(0)}%', best: t.discountPercent == maxPct),
    ];
  }

  Future<void> _confirm() async {
    if (_start == null || _overlapsBlocked) return;
    setState(() => _checking = true);
    try {
      final start = _start!;
      final end = (_end ?? _start!.add(const Duration(days: 1)));
      final ok = await DataService.checkAvailability(itemId: widget.item.id, start: start, end: end);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(DateTimeRange(start: start, end: end));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('In diesem Zeitraum bereits gebucht')));
        setState(() => _overlapsBlocked = true);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showExpressInfoSheet(BuildContext context) {
    final primary = BrandColors.primary;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.flash_on_outlined, color: primary),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Expresslieferung', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
                  IconButton(
                    tooltip: 'Schließen',
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ]),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '- Lieferung innerhalb von 2 Std. nach Bestätigung der Anfrage.\n'
                    '- Wenn die Anfrage nicht innerhalb von 30 Min. bestätigt wird, erhältst du den Expresszuschlag zurück und die Anfrage wird automatisch als Standardlieferung weitergeführt.\n'
                    '- Solange deine Anfrage noch nicht bestätigt worden ist, kannst du sie jederzeit zurückziehen.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _dateSpanText() {
    if (_start == null || _end == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    final s = _start!; final e = _end!.subtract(const Duration(days: 1));
    if (s.year == e.year && s.month == e.month && s.day == e.day) {
      return '${two(s.day)}. ${_monthsDe[s.month - 1].substring(0, 3)}';
    }
    return '${two(s.day)}. ${_monthsDe[s.month - 1].substring(0, 3)} → ${two(e.day)}. ${_monthsDe[e.month - 1].substring(0, 3)}';
  }

  String _singleDateText(DateTime s) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(s.day)}. ${_monthsDe[s.month - 1].substring(0, 3)}';
  }

  String _durationLabel() {
    final d = (_start != null && _end != null) ? max(1, _end!.difference(_start!).inDays) : _selectedDays;
    return d == 1 ? '1 Tag' : '$d Tage';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Semi-transparent dark to let the blurred background show through (SIT style)
    final bg = Colors.black.withValues(alpha: 0.34);
    final card = Colors.white.withValues(alpha: 0.06);
    final border = Colors.white.withValues(alpha: 0.12);
    final text = Colors.white;
    final sub = Colors.white.withValues(alpha: 0.64);
    final primary = BrandColors.primary;
    final danger = BrandColors.danger;

    final chips = _thresholdChips;
    // Determine if we should show the encouragement inside the Mietdauer card:
    // show only if there are at least 3 tiers and the highest tier is not yet reached.
    final currentDays = (_start != null && _end != null) ? max(1, _end!.difference(_start!).inDays) : _selectedDays;
    final int? maxTierDays = chips.isNotEmpty ? chips.map((c) => c.days).reduce(max) : null;
    final bool showCardExtendTip = (chips.length >= 3) && (maxTierDays != null) && (currentDays < maxTierDays);

    // Price preview numbers
    final int previewDays = (() {
      if (_start == null) return _selectedDays;
      final s = _start!;
      final e = (_end ?? _start!.add(const Duration(days: 1)));
      return max(1, e.difference(s).inDays);
    })();
    final tuple = DataService.computeTotalWithDiscounts(item: widget.item, days: previewDays);
    final double finalTotal = tuple.$1;
    final double baseTotal = tuple.$2;
    final double appliedPct = tuple.$3;
    final double discountAmt = tuple.$4;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          // Header: centered month title, back left, close right (absolute centered)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            child: SizedBox(
              height: 40,
              child: Stack(children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                // Centered month title with small left/right chevrons to navigate months
                Center(
                  child: Builder(builder: (context) {
                    final prev = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
                    final next = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
                    final minMonth = DateTime(_firstDate.year, _firstDate.month, 1);
                    final maxMonth = DateTime(_lastDate.year, _lastDate.month, 1);
                    final canPrev = !prev.isBefore(minMonth);
                    final canNext = !next.isAfter(maxMonth);
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: canPrev ? _prevMonth : null,
                        icon: Icon(Icons.chevron_left, color: canPrev ? Colors.white : Colors.white54, size: 20),
                      ),
                      Text(
                        '${_monthsDe[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      IconButton(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: canNext ? _nextMonth : null,
                        icon: Icon(Icons.chevron_right, color: canNext ? Colors.white : Colors.white54, size: 20),
                      ),
                    ]);
                  }),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ]),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Rental summary
                const Text('Mietdauer', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(_durationLabel(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22))),
                    ]),
                    const SizedBox(height: 0),
                    if (_start != null && _end != null)
                      Text(_dateSpanText(), style: TextStyle(color: sub, fontSize: 13))
                    else if (_start != null && _end == null)
                      Text(_singleDateText(_start!), style: TextStyle(color: sub, fontSize: 13))
                    else
                      Text('Wähle Zeitraum', style: TextStyle(color: sub, fontSize: 13)),
                    const SizedBox(height: 6),
                    if (showCardExtendTip)
                      Text('Verlängere und spare automatisch', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 8),

                // Rabatt‑Schwellenchips direkt unter der Mietdauer‑Karte
                if (chips.isNotEmpty) ...[
                  Row(children: [
                    for (int i = 0; i < chips.length && i < 3; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                          child: _DiscountChip(
                            chip: chips[i],
                            isSelected: () {
                              final eligibleDays = chips.where((cc) => _selectedDays >= cc.days).map((cc) => cc.days);
                              final int? maxEligible = eligibleDays.isEmpty ? null : eligibleDays.reduce(max);
                              return maxEligible != null && chips[i].days == maxEligible;
                            }(),
                            onTap: () {
                              setState(() {
                                _selectedDays = chips[i].days;
                                if (_start == null) {
                                  final found = _findEarliestRange(_selectedDays);
                                  if (found != null) { _start = found.$1; _end = found.$2; _overlapsBlocked = false; }
                                } else {
                                  _end = _start!.add(Duration(days: _selectedDays));
                                  _overlapsBlocked = _rangeOverlapsBooked(_start!, _end!);
                                }
                                _recomputeDiscount();
                              });
                            },
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 10),
                ],

                // Liefer- und Abholoptionen direkt hier wählen
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // Floating segmented rounded tabs (Chrome-like, exact look from reference)
                    _FloatingSegmentedTabs(
                      segments: const [
                        _Segment(label: 'Abgabe'),
                        _Segment(label: 'Rückgabe'),
                      ],
                      selectedIndex: _deliveryTabIndex,
                      onChanged: (i) => setState(() => _deliveryTabIndex = i),
                    ),
                    const SizedBox(height: 10),
                    // Content area depends on selected tab
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _deliveryTabIndex == 0
                          ? LayoutBuilder(
                              key: const ValueKey('abgabe'),
                              builder: (context, constraints) {
                                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Abgabe (Artikel zu dir):', style: TextStyle(color: sub, fontSize: 12)),
                              const SizedBox(height: 6),
                              Row(children: [
                                Expanded(child: _OptionPill(
                                  label: 'Selbst abholen',
                                  selected: !_hinwegLandlord,
                                  onTap: () { setState(() { _hinwegLandlord = false; }); _persistDeliverySelection(); },
                                )),
                                const SizedBox(width: 8),
                                Expanded(child: _OptionPill(
                                  label: widget.item.offersDeliveryAtDropoff ? 'Vom Vermieter liefern lassen' : 'Lieferung nicht verfügbar',
                                  selected: _hinwegLandlord,
                                  disabled: !widget.item.offersDeliveryAtDropoff,
                                  onTap: () {
                                    if (!widget.item.offersDeliveryAtDropoff) return;
                                    setState(() { _hinwegLandlord = true; });
                                    _persistDeliverySelection();
                                  },
                                )),
                              ]),
                              // Always show Standard/Express choices when delivery by landlord is selected
                              if (_hinwegLandlord) ...[
                                const SizedBox(height: 8),
                                // Standard & Express as rounded pills in one horizontal row with "?" between
                                Row(children: [
                                  Expanded(child: _OptionPill(
                                    label: 'Standard',
                                    selected: !_wantExpress,
                                    onTap: () { setState(() { _wantExpress = false; }); _persistDeliverySelection(); },
                                  )),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => _showExpressInfoSheet(context),
                                    behavior: HitTestBehavior.opaque,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 2),
                                      child: Icon(Icons.help_outline, color: Colors.white70, size: 16),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(child: _OptionPill(
                                    label: 'Express',
                                    selected: _wantExpress,
                                    onTap: () { setState(() { _wantExpress = true; }); _persistDeliverySelection(); },
                                  )),
                                ]),
                              ],
                              const SizedBox(height: 6),
                              if (_hinwegLandlord) Builder(builder: (context) {
                                final km = _savedDistanceKm();
                                final maxKm = widget.item.maxDeliveryKmAtDropoff;
                                final overMax = (km != null && maxKm != null && km > maxKm);
                                final kmLabel = km != null ? km.toStringAsFixed(1) : '...';
                                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Liefergebühr: $kmLabel Km${_wantExpress ? ' + Expresszuschlag' : ''}', style: TextStyle(color: sub, fontSize: 12)),
                                  if (overMax) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Der Vermieter liefert nur bis zu ${maxKm!.toStringAsFixed(0)} km. Bitte organisieren Sie die Abholung selbst.',
                                      style: TextStyle(color: danger, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ]);
                              }),
                                ]);
                              },
                            )
                          : Column(key: const ValueKey('rueckgabe'), crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Rückgabe (Artikel zurückgeben):', style: TextStyle(color: sub, fontSize: 12)),
                              const SizedBox(height: 6),
                              Row(children: [
                                Expanded(child: _OptionPill(
                                  label: 'Selbst zurückbringen',
                                  selected: !_rueckwegLandlord,
                                  onTap: () { setState(() { _rueckwegLandlord = false; }); _persistDeliverySelection(); },
                                )),
                                const SizedBox(width: 8),
                                Expanded(child: _OptionPill(
                                  label: widget.item.offersPickupAtReturn ? 'Vom Vermieter abholen lassen' : 'Abholung nicht verfügbar',
                                  selected: _rueckwegLandlord,
                                  disabled: !widget.item.offersPickupAtReturn,
                                  onTap: () {
                                    if (!widget.item.offersPickupAtReturn) return;
                                    setState(() { _rueckwegLandlord = true; });
                                    _persistDeliverySelection();
                                  },
                                )),
                              ]),
                              const SizedBox(height: 6),
                              if (_rueckwegLandlord) Builder(builder: (context) {
                                final km = _savedDistanceKm();
                                final maxKm = widget.item.maxPickupKmAtReturn;
                                final overMax = (km != null && maxKm != null && km > maxKm);
                                final kmLabel = km != null ? km.toStringAsFixed(1) : '...';
                                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Liefergebühr: $kmLabel Km', style: TextStyle(color: sub, fontSize: 12)),
                                  if (overMax) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Der Vermieter holt nur bis zu ${maxKm!.toStringAsFixed(0)} km ab. Bitte organisieren Sie die Rückgabe selbst.',
                                      style: TextStyle(color: danger, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ]);
                              }),
                            ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                // Calendar vertically centered in remaining space (with month swipe)
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onHorizontalDragEnd: (details) {
                        final v = details.primaryVelocity ?? 0;
                        if (v < -100) { _nextMonth(); }
                        if (v > 100) { _prevMonth(); }
                      },
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        // Chips moved under Mietdauer card per spec
                        _WeekdayRow(color: sub),
                        const SizedBox(height: 6),
                        _MonthGrid(
                          month: _visibleMonth,
                          firstDate: _firstDate,
                          lastDate: _lastDate,
                          start: _start,
                          end: _end,
                          onTap: _onDayTap,
                          isBooked: _isBookedDay,
                          primary: primary,
                          textColor: text,
                          subText: sub,
                          danger: danger,
                        ),
                        const SizedBox(height: 8),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // Sticky CTA
          Container(
            decoration: BoxDecoration(color: Colors.black, border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SafeArea(
              top: false,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                // Price preview – single total only, includes conditional Plattformbeitrag per spec
                if (_start != null) ...[
                  Builder(builder: (context) {
                    final rentalPrice = finalTotal; // after any discount
                    // Delivery and pickup fees per leg
                    final kmOpt = _savedDistanceKm();
                    final bool hasKm = kmOpt != null;
                    final double km = kmOpt ?? 0.0; // assume 0 km until we know better
                    final bool dropSelected = _hinwegLandlord && widget.item.offersDeliveryAtDropoff;
                    final bool pickSelected = _rueckwegLandlord && widget.item.offersPickupAtReturn;
                    // If distance is unknown yet, treat it as within max so the total updates immediately.
                    final bool dropWithinMax = !hasKm ? true : (widget.item.maxDeliveryKmAtDropoff == null || km <= widget.item.maxDeliveryKmAtDropoff!);
                    final bool pickWithinMax = !hasKm ? true : (widget.item.maxPickupKmAtReturn == null || km <= widget.item.maxPickupKmAtReturn!);
                    final bool dropChargeable = dropSelected && dropWithinMax;
                    final bool pickChargeable = pickSelected && pickWithinMax;

                    double deliveryFee = 0.0; // Abgabe
                    double pickupFee = 0.0;   // Rückgabe
                    if (dropChargeable) {
                      deliveryFee = double.parse((km * 0.30).toStringAsFixed(2));
                      if (_wantExpress) deliveryFee = double.parse((deliveryFee + 5.0).toStringAsFixed(2));
                    }
                    if (pickChargeable) {
                      pickupFee = double.parse((km * 0.30).toStringAsFixed(2));
                    }

                    final subtotalBeforePlatform = double.parse((rentalPrice + deliveryFee + pickupFee).toStringAsFixed(2));
                    // Platform fee: always 10% of subtotal (rental after discount + delivery + pickup + express)
                    // Minimum fee rule: if subtotal < 10 €, platform fee is always 1 €
                    double platformFee;
                    if (subtotalBeforePlatform < 10.0) {
                      platformFee = 1.0;
                    } else {
                      platformFee = double.parse((subtotalBeforePlatform * 0.10).toStringAsFixed(2));
                    }
                    final total = double.parse((subtotalBeforePlatform + platformFee).toStringAsFixed(2));

                    String subtitle = 'inkl. Plattformbeitrag';
                    if (dropSelected && pickSelected) {
                      // Exact requested copy when both are selected
                      subtitle = 'Inkl. Lieferung/Abholung und Plattformbeitrag';
                    } else if (dropSelected || pickSelected) {
                      final single = dropSelected ? 'Lieferung' : 'Abholung';
                      subtitle = 'inkl. $single und Plattformbeitrag';
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        const Expanded(child: Text('Gesamtbetrag', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${total.toStringAsFixed(2)} €', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                          const SizedBox(height: 2),
                          if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ]),
                      ]),
                    );
                  }),
                  const SizedBox(height: 10),
                ],
                // Hinweistext zwischen Gesamtbetrag und Button
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Nach Annahme deiner Anfrage vereinbarst du im Chat die Abhol- und Rückgabezeit mit dem Vermieter',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: (_start != null && !_overlapsBlocked && !_checking) ? _confirm : null,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _checking
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_start != null ? 'Weiter' : 'Mietdauer wählen'),
                ),
                const SizedBox(height: 6),
              ]),
            ),
          ),
        ]),
      ),
      // No floating duplicate month nav; month title stays perfectly centered in header
      floatingActionButtonLocation: null,
      floatingActionButton: null,
    );
  }
}

class _ThresholdChip {
  final int days; final String label; final bool best;
  const _ThresholdChip({required this.days, required this.label, this.best = false});
}

class _DiscountChip extends StatelessWidget {
  final _ThresholdChip chip;
  final bool isSelected;
  final VoidCallback onTap;
  const _DiscountChip({required this.chip, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = BrandColors.primary;
    final border = Colors.white.withValues(alpha: 0.12);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? primary.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: isSelected ? primary : border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(chip.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ),
    );
  }
}

class _Segment {
  final IconData? icon; // icon optional to match reference design (no icons)
  final String label;
  const _Segment({this.icon, required this.label});
}

class _FloatingSegmentedTabs extends StatelessWidget {
  final List<_Segment> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  const _FloatingSegmentedTabs({super.key, required this.segments, required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final primary = BrandColors.primary;
    final base = Colors.white.withValues(alpha: 0.08);
    final border = Colors.white.withValues(alpha: 0.12);

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final count = segments.length;
      final inset = 3.0; // slimmer insets for a flatter control
      final pillWidth = (width - inset * 2) / count;
        return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
          height: 36,
        decoration: BoxDecoration(
          color: base,
            borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
          boxShadow: [
            // even subtler floating effect
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(children: [
          // Moving highlight pill
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: inset + pillWidth * selectedIndex,
            top: inset,
            bottom: inset,
            width: pillWidth,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
          ),
          // Tap areas + labels
          Row(children: [
            for (int i = 0; i < count; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      style: TextStyle(
                        color: i == selectedIndex ? Colors.black : Colors.white,
                        fontWeight: i == selectedIndex ? FontWeight.w800 : FontWeight.w600,
                      ),
                      child: Text(segments[i].label),
                    ),
                  ),
                ),
              ),
          ]),
        ]),
      );
    });
  }
}

class _ChromeTab extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  const _ChromeTab({required this.label, this.icon, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = BrandColors.primary;
    final base = Colors.white.withValues(alpha: 0.06);
    final border = Colors.white.withValues(alpha: 0.12);
    final selBorder = primary;

    // Slight gradient for selected state to match SIT polish
    final BoxDecoration deco = selected
        ? BoxDecoration(
            gradient: LinearGradient(colors: [primary.withValues(alpha: 0.28), primary.withValues(alpha: 0.20)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: selBorder),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
          )
        : BoxDecoration(
            color: base,
            border: Border.all(color: border),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
          );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: deco,
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _OptionPill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;
  const _OptionPill({required this.label, required this.selected, this.disabled = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = BrandColors.primary;
    final base = Colors.white.withValues(alpha: 0.06);
    final border = Colors.white.withValues(alpha: 0.12);
    final selBg = primary.withValues(alpha: 0.22);
    final selBorder = primary;
    final fg = disabled ? Colors.white54 : Colors.white;
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? selBg : base,
            border: Border.all(color: selected ? selBorder : border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

class _CheckChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget? beforeLabel;
  final VoidCallback? onTap;
  const _CheckChoice({required this.label, required this.selected, this.beforeLabel, this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = BrandColors.primary;
    final base = Colors.white.withValues(alpha: 0.06);
    final border = Colors.white.withValues(alpha: 0.12);
    final selBg = primary.withValues(alpha: 0.16);
    final selBorder = primary;
    final iconColor = selected ? primary : Colors.white70;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? selBg : base,
          border: Border.all(color: selected ? selBorder : border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: iconColor, size: 18),
          const SizedBox(width: 10),
          if (beforeLabel != null) beforeLabel!,
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  final Color color;
  const _WeekdayRow({required this.color});
  static const _wdDe = ['Mo','Di','Mi','Do','Fr','Sa','So'];
  @override
  Widget build(BuildContext context) => Row(children: [for (final d in _wdDe) Expanded(child: Center(child: Text(d, style: TextStyle(color: color, fontWeight: FontWeight.w600))))]);
}

class _MonthGrid extends StatelessWidget {
  final DateTime month; final DateTime firstDate; final DateTime lastDate; final DateTime? start; final DateTime? end; final void Function(DateTime) onTap; final bool Function(DateTime) isBooked; final Color primary; final Color textColor; final Color subText; final Color danger;
  const _MonthGrid({required this.month, required this.firstDate, required this.lastDate, required this.start, required this.end, required this.onTap, required this.isBooked, required this.primary, required this.textColor, required this.subText, required this.danger});

  int _daysInMonth(DateTime m) => DateTime(m.year, m.month + 1, 0).day;
  int _mondayBasedWeekday(DateTime d) => (d.weekday + 6) % 7; // 0..6, 0=Mon

  @override
  Widget build(BuildContext context) {
    final days = _daysInMonth(month);
    final firstW = _mondayBasedWeekday(month);
    final totalCells = ((firstW + days + 6) ~/ 7) * 7;
    final cells = <DateTime?>[];
    for (int i = 0; i < firstW; i++) { cells.add(null); }
    for (int d = 1; d <= days; d++) { cells.add(DateTime(month.year, month.month, d)); }
    while (cells.length < totalCells) { cells.add(null); }
    return Column(children: [
      for (int row = 0; row < cells.length / 7; row++)
        Row(children: [
          for (int col = 0; col < 7; col++)
            Expanded(child: _DayCell(day: cells[row * 7 + col], firstDate: firstDate, lastDate: lastDate, start: start, end: end, onTap: onTap, primary: primary, textColor: textColor, subText: subText, danger: danger, isBooked: isBooked)),
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
    final s = _strip(start!);
    final eInclusive = _strip(end!.subtract(const Duration(days: 1)));
    if (_isSameDay(s, eInclusive)) {
      return _isSameDay(d, s);
    }
    return (d.isAfter(s) && d.isBefore(eInclusive)) || _isSameDay(d, s) || _isSameDay(d, eInclusive);
  }

  @override
  Widget build(BuildContext context) {
    if (day == null) return const SizedBox(height: 44);
    final d = day!;
    final isStart = start != null && _isSameDay(d, start!);
    final DateTime? endInclusive = end == null ? null : _strip(end!.subtract(const Duration(days: 1)));
    final isEnd = endInclusive != null && _isSameDay(d, endInclusive);
    final isRange = _inRange(d);
    final disabled = _disabled(d) || isBooked(d);

    final bgRange = primary.withValues(alpha: 0.18);
    final bgSE = primary;
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
