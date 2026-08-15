import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lendify/config/private_pilot_config.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:url_launcher/url_launcher.dart';

class SelectRentalDurationScreen extends StatefulWidget {
  final Item item;
  final DateTimeRange? initialRange;
  const SelectRentalDurationScreen(
      {super.key, required this.item, this.initialRange});

  @override
  State<SelectRentalDurationScreen> createState() =>
      _SelectRentalDurationScreenState();
}

class _SelectRentalDurationScreenState
    extends State<SelectRentalDurationScreen> {
  late DateTime _firstDate;
  late DateTime _lastDate;
  late DateTime _visibleMonth;
  List<DateTimeRange> _unavailable = const [];

  DateTime? _start;
  DateTime? _end;
  int _selectedDays = 1;
  bool _checking = false;
  bool _overlapsBlocked = false;
  bool _calendarExpanded = true;

  bool _hinwegLandlord = false;
  bool _rueckwegLandlord = false;

  final TextEditingController _deliveryAddressCtrl = TextEditingController();
  final TextEditingController _returnAddressCtrl = TextEditingController();

  String? _deliveryCity;
  double? _deliveryLat;
  double? _deliveryLng;
  String? _returnCity;
  double? _returnLat;
  double? _returnLng;

  static const _monthsDe = [
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember'
  ];

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
    }
    _loadUnavailable();
    _loadSavedDeliverySelection();
  }

  @override
  void dispose() {
    _deliveryAddressCtrl.dispose();
    _returnAddressCtrl.dispose();
    super.dispose();
  }

  DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _loadUnavailable() async {
    final ranges =
        await DataService.getUnavailableRangesForItem(widget.item.id);
    if (!mounted) return;
    setState(() => _unavailable = ranges);
    if (_start != null && _end != null) {
      setState(() => _overlapsBlocked = _rangeOverlapsBooked(_start!, _end!));
    }
  }

  Future<void> _loadSavedDeliverySelection() async {
    try {
      final saved = await DataService.getSavedDeliverySelection(widget.item.id);
      if (!mounted || saved == null) return;
      setState(() {
        _hinwegLandlord = PrivatePilotConfig.deliveryEnabled &&
            widget.item.offersDeliveryAtDropoff &&
            saved['hinweg'] == true;
        _rueckwegLandlord = PrivatePilotConfig.deliveryEnabled &&
            widget.item.offersPickupAtReturn &&
            saved['rueckweg'] == true;

        final sharedLine = (saved['addressLine'] as String?) ?? '';
        final sharedCity = saved['city'] as String?;
        final sharedLat = (saved['lat'] as num?)?.toDouble();
        final sharedLng = (saved['lng'] as num?)?.toDouble();

        final deliveryLine =
            ((saved['deliveryAddressLine'] as String?) ?? sharedLine).trim();
        final returnLine =
            ((saved['returnAddressLine'] as String?) ?? sharedLine).trim();

        _deliveryAddressCtrl.text = deliveryLine;
        _returnAddressCtrl.text = returnLine;

        _deliveryCity = (saved['deliveryCity'] as String?) ?? sharedCity;
        _deliveryLat = (saved['deliveryLat'] as num?)?.toDouble() ?? sharedLat;
        _deliveryLng = (saved['deliveryLng'] as num?)?.toDouble() ?? sharedLng;
        _returnCity = (saved['returnCity'] as String?) ?? sharedCity;
        _returnLat = (saved['returnLat'] as num?)?.toDouble() ?? sharedLat;
        _returnLng = (saved['returnLng'] as num?)?.toDouble() ?? sharedLng;
      });
      _persistDeliverySelection();
    } catch (_) {}
  }

  void _persistDeliverySelection() {
    final deliveryLine = _deliveryAddressCtrl.text.trim();
    final returnLine = _returnAddressCtrl.text.trim();
    _deliveryCity = deliveryLine.isEmpty
        ? null
        : DataService.deriveCityFromAddress(deliveryLine);
    _returnCity = returnLine.isEmpty
        ? null
        : DataService.deriveCityFromAddress(returnLine);
    DataService.setSavedDeliverySelection(
      widget.item.id,
      hinweg: PrivatePilotConfig.deliveryEnabled &&
          _hinwegLandlord &&
          widget.item.offersDeliveryAtDropoff,
      rueckweg: PrivatePilotConfig.deliveryEnabled &&
          _rueckwegLandlord &&
          widget.item.offersPickupAtReturn,
      addressCity: _deliveryCity,
      addressLine: deliveryLine,
      express: false,
      lat: _deliveryLat,
      lng: _deliveryLng,
      deliveryAddressLine: deliveryLine,
      deliveryCity: _deliveryCity,
      deliveryLat: _deliveryLat,
      deliveryLng: _deliveryLng,
      returnAddressLine: returnLine,
      returnCity: _returnCity,
      returnLat: _returnLat,
      returnLng: _returnLng,
    );
  }

  double? _estimatedKmFor({required bool isReturn}) {
    final line =
        (isReturn ? _returnAddressCtrl.text : _deliveryAddressCtrl.text).trim();
    final city = isReturn ? _returnCity : _deliveryCity;
    final lat = isReturn ? _returnLat : _deliveryLat;
    final lng = isReturn ? _returnLng : _deliveryLng;
    if (lat != null && lng != null) {
      return DataService.estimateDistanceKm(
          widget.item.lat, widget.item.lng, lat, lng);
    }
    if (line.isNotEmpty) {
      final derivedCity = DataService.deriveCityFromAddress(line);
      if (derivedCity.isNotEmpty) {
        return DataService.estimateDistanceKmToCity(
            widget.item.lat, widget.item.lng, derivedCity);
      }
    }
    if (city != null && city.isNotEmpty) {
      return DataService.estimateDistanceKmToCity(
          widget.item.lat, widget.item.lng, city);
    }
    return null;
  }

  bool _isAddressEstimateReady(bool isReturn) {
    final line =
        (isReturn ? _returnAddressCtrl.text : _deliveryAddressCtrl.text).trim();
    if (line.isEmpty) return false;
    return _estimatedKmFor(isReturn: isReturn) != null;
  }

  bool _hasAddressText(bool isReturn) =>
      (isReturn ? _returnAddressCtrl.text : _deliveryAddressCtrl.text)
          .trim()
          .isNotEmpty;

  String? _continueHint() {
    if (_start == null) return 'Bitte wähle mindestens einen Miettag.';
    if (_overlapsBlocked) return 'Bitte wähle einen verfügbaren Zeitraum.';
    if (_requiresDeliveryAddress && !_hasAddressText(false)) {
      return 'Bitte Lieferadresse eingeben.';
    }
    if (_requiresDeliveryAddress && !_isAddressEstimateReady(false)) {
      return 'Lieferkosten können aktuell nicht automatisch berechnet werden. Bitte wähle Selbstabholung oder prüfe die Adresse mit Stadtangabe.';
    }
    if (_requiresReturnAddress && !_hasAddressText(true)) {
      return 'Bitte Rückgabeadresse eingeben.';
    }
    if (_requiresReturnAddress && !_isAddressEstimateReady(true)) {
      return 'Abholkosten können aktuell nicht automatisch berechnet werden. Bitte wähle Rückgabe beim Vermieter oder prüfe die Adresse mit Stadtangabe.';
    }
    final preview = _pricePreview;
    if (_requiresDeliveryAddress && !preview.deliveryWithinMax) {
      return 'Die Lieferadresse liegt außerhalb des Lieferbereichs.';
    }
    if (_requiresReturnAddress && !preview.returnWithinMax) {
      return 'Die Rückgabeadresse liegt außerhalb des Abholbereichs.';
    }
    return null;
  }

  bool _isBookedDay(DateTime d) {
    final day = _strip(d);
    for (final r in _unavailable) {
      final s = _strip(r.start);
      final e = _strip(r.end);
      if (!day.isBefore(s) && day.isBefore(e)) return true;
    }
    return false;
  }

  bool _rangeOverlapsBooked(DateTime a, DateTime b) {
    final s = _strip(a);
    final e = _strip(b);
    final start = s.isBefore(e) ? s : e;
    final end = s.isBefore(e) ? e : s;
    for (final r in _unavailable) {
      final rs = _strip(r.start);
      final re = _strip(r.end);
      if (start.isBefore(re) && end.isAfter(rs)) return true;
    }
    return false;
  }

  void _onDayTap(DateTime day) {
    if (day.isBefore(_firstDate)) {
      final label = _formatShortDate(day);
      AppPopup.info(
        context,
        title: 'Datum nicht verfügbar',
        message: '$label liegt in der Vergangenheit.',
      );
      return;
    }
    if (day.isAfter(_lastDate) || _isBookedDay(day)) return;
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        _start = _strip(day);
        _end = null;
        _selectedDays = 1;
        _overlapsBlocked = false;
        _calendarExpanded = true;
      } else {
        if (day.isBefore(_start!)) {
          _start = _strip(day);
          _end = null;
          _overlapsBlocked = false;
          _calendarExpanded = true;
        } else {
          _end = _strip(day).add(const Duration(days: 1));
          _overlapsBlocked = _rangeOverlapsBooked(_start!, _end!);
          _selectedDays = max(1, _end!.difference(_start!).inDays);
          _calendarExpanded = false;
        }
      }
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
      if (!_rangeOverlapsBooked(cursor, end)) return (cursor, end);
      cursor = cursor.add(const Duration(days: 1));
    }
    return null;
  }

  List<_ThresholdChip> get _thresholdChips {
    if (!widget.item.autoApplyDiscounts ||
        widget.item.longRentalDiscounts.isEmpty) {
      return const [];
    }
    final tiers = List.of(widget.item.longRentalDiscounts)
      ..removeWhere((t) => t.days <= 1)
      ..sort((a, b) => a.days.compareTo(b.days));
    final maxPct = tiers.fold<double>(
        0, (p, e) => e.discountPercent > p ? e.discountPercent : p);
    return [
      for (final t in tiers)
        _ThresholdChip(
            days: t.days,
            label:
                'ab ${t.days} Tagen ${t.discountPercent.toStringAsFixed(0)}%',
            best: t.discountPercent == maxPct),
    ];
  }

  int get _previewDays {
    if (_start == null) return _selectedDays;
    final end = _end ?? _start!.add(const Duration(days: 1));
    return max(1, end.difference(_start!).inDays);
  }

  _PricePreview get _pricePreview {
    final tuple = DataService.computeTotalWithDiscounts(
        item: widget.item, days: _previewDays);
    final rentalSubtotal = tuple.$1;
    final baseTotal = tuple.$2;
    final discountAmt = tuple.$4;
    final platformFee =
        DataService.platformContributionForRental(rentalSubtotal);

    final deliveryKm = _estimatedKmFor(isReturn: false);
    final returnKm = _estimatedKmFor(isReturn: true);

    final deliveryAllowed = PrivatePilotConfig.deliveryEnabled &&
        widget.item.offersDeliveryAtDropoff &&
        _hinwegLandlord;
    final returnAllowed = PrivatePilotConfig.deliveryEnabled &&
        widget.item.offersPickupAtReturn &&
        _rueckwegLandlord;

    final deliveryWithinMax = !deliveryAllowed ||
        deliveryKm == null ||
        widget.item.maxDeliveryKmAtDropoff == null ||
        deliveryKm <= widget.item.maxDeliveryKmAtDropoff!;
    final returnWithinMax = !returnAllowed ||
        returnKm == null ||
        widget.item.maxPickupKmAtReturn == null ||
        returnKm <= widget.item.maxPickupKmAtReturn!;

    final deliveryFeePending = deliveryAllowed && deliveryKm == null;
    final pickupFeePending = returnAllowed && returnKm == null;

    final deliveryFee =
        deliveryAllowed && deliveryKm != null && deliveryWithinMax
            ? DataService.deliveryFeeForDistanceKm(deliveryKm)
            : 0.0;
    final pickupFee = returnAllowed && returnKm != null && returnWithinMax
        ? DataService.deliveryFeeForDistanceKm(returnKm)
        : 0.0;

    final total = double.parse(
        (rentalSubtotal + platformFee + deliveryFee + pickupFee)
            .toStringAsFixed(2));

    return _PricePreview(
      rentalSubtotal: double.parse(rentalSubtotal.toStringAsFixed(2)),
      baseTotal: double.parse(baseTotal.toStringAsFixed(2)),
      discountAmount: double.parse(discountAmt.toStringAsFixed(2)),
      platformFee: double.parse(platformFee.toStringAsFixed(2)),
      deliveryFee: double.parse(deliveryFee.toStringAsFixed(2)),
      pickupFee: double.parse(pickupFee.toStringAsFixed(2)),
      total: total,
      deliveryKm: deliveryKm,
      returnKm: returnKm,
      deliveryWithinMax: deliveryWithinMax,
      returnWithinMax: returnWithinMax,
      deliveryFeePending: deliveryFeePending,
      pickupFeePending: pickupFeePending,
    );
  }

  bool get _requiresDeliveryAddress =>
      PrivatePilotConfig.deliveryEnabled &&
      _hinwegLandlord &&
      widget.item.offersDeliveryAtDropoff;
  bool get _requiresReturnAddress =>
      PrivatePilotConfig.deliveryEnabled &&
      _rueckwegLandlord &&
      widget.item.offersPickupAtReturn;

  bool get _canContinue => !_checking && _continueHint() == null;

  Future<void> _openMapsSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(trimmed)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _confirm() async {
    if (!_canContinue) return;
    setState(() => _checking = true);
    try {
      final start = _start!;
      final end = _end ?? _start!.add(const Duration(days: 1));
      final ok = await DataService.checkAvailability(
          itemId: widget.item.id, start: start, end: end);
      if (!mounted) return;
      if (ok) {
        _persistDeliverySelection();
        Navigator.of(context).pop(DateTimeRange(start: start, end: end));
      } else {
        AppPopup.info(
          context,
          title: 'Zeitraum nicht verfügbar',
          message: 'Der Artikel ist in diesem Zeitraum bereits gebucht.',
        );
        setState(() => _overlapsBlocked = true);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String _formatShortDate(DateTime s) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(s.day)}. ${_monthsDe[s.month - 1]}';
  }

  String _dateSpanText() {
    if (_start == null || _end == null) return '';
    final s = _start!;
    final e = _end!.subtract(const Duration(days: 1));
    if (_isSameDay(s, e)) {
      return _formatShortDate(s);
    }
    return '${_formatShortDate(s)} – ${_formatShortDate(e)}';
  }

  String _singleDateText(DateTime s) => _formatShortDate(s);

  String _durationLabel() {
    final d = (_start != null && _end != null)
        ? max(1, _end!.difference(_start!).inDays)
        : _selectedDays;
    return d == 1 ? '1 Miettag' : '$d Miettage';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.black.withValues(alpha: 0.34)
        : AppTheme.surfaceMuted(context);
    final card = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : AppTheme.surfacePrimary(context);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppTheme.glassStroke(context);
    final sub = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : AppTheme.textSecondary(context);
    final primary = BrandColors.primary;
    final danger = BrandColors.danger;
    final chips = _thresholdChips;
    final preview = _pricePreview;
    final continueHint = _continueHint();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
              child: SizedBox(
                height: 40,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip:
                            MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.arrow_back,
                            color: isDark
                                ? Colors.white
                                : AppTheme.textPrimary(context)),
                      ),
                    ),
                    Center(
                      child: Text(
                        'Verfügbarkeit prüfen',
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : AppTheme.textPrimary(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.close,
                            color: isDark
                                ? Colors.white
                                : AppTheme.textPrimary(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 118),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StepCard(
                      step: '1',
                      title: 'Zeitraum',
                      subtitle:
                          'Wähle den Tag oder Zeitraum, an dem du den Artikel nutzen möchtest.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: border)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_durationLabel(),
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : AppTheme.textPrimary(context),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 22)),
                                  const SizedBox(height: 4),
                                  if (_start != null && _end != null)
                                    Text(_dateSpanText(),
                                        style:
                                            TextStyle(color: sub, fontSize: 13))
                                  else if (_start != null)
                                    Text(_singleDateText(_start!),
                                        style:
                                            TextStyle(color: sub, fontSize: 13))
                                  else
                                    Text('Noch kein Miettag ausgewählt',
                                        style: TextStyle(
                                            color: sub, fontSize: 13)),
                                  if (_start != null && _end == null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                        'Ein einzelner ausgewählter Tag zählt als 1 Miettag.',
                                        style: TextStyle(
                                            color: sub, fontSize: 12)),
                                  ],
                                ]),
                          ),
                          if (chips.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final chip in chips)
                                  _DiscountChip(
                                    chip: chip,
                                    isSelected: _previewDays >= chip.days &&
                                        chip.days ==
                                            chips
                                                .where((c) =>
                                                    _previewDays >= c.days)
                                                .map((c) => c.days)
                                                .fold<int?>(
                                                    null,
                                                    (p, e) => p == null || e > p
                                                        ? e
                                                        : p),
                                    onTap: () {
                                      setState(() {
                                        _selectedDays = chip.days;
                                        if (_start == null) {
                                          final found =
                                              _findEarliestRange(_selectedDays);
                                          if (found != null) {
                                            _start = found.$1;
                                            _end = found.$2;
                                            _overlapsBlocked = false;
                                            _visibleMonth = DateTime(
                                                _start!.year, _start!.month, 1);
                                          }
                                        } else {
                                          _end = _start!.add(
                                              Duration(days: _selectedDays));
                                          _overlapsBlocked =
                                              _rangeOverlapsBooked(
                                                  _start!, _end!);
                                        }
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => setState(
                                () => _calendarExpanded = !_calendarExpanded),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 12, 12, 12),
                              decoration: BoxDecoration(
                                  color: card,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: border)),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _calendarExpanded
                                              ? 'Kalender'
                                              : (_start == null
                                                  ? 'Kalender öffnen'
                                                  : 'Zeitraum ändern'),
                                          style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : AppTheme.textPrimary(
                                                      context),
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      Icon(
                                          _calendarExpanded
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                          color: isDark
                                              ? Colors.white70
                                              : AppTheme.textSecondary(
                                                  context)),
                                    ],
                                  ),
                                  AnimatedCrossFade(
                                    duration: const Duration(milliseconds: 180),
                                    crossFadeState: _calendarExpanded
                                        ? CrossFadeState.showFirst
                                        : CrossFadeState.showSecond,
                                    firstChild: Column(
                                      children: [
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () => _prevMonth(),
                                              icon: Icon(Icons.chevron_left,
                                                  color: isDark
                                                      ? Colors.white
                                                      : AppTheme.textPrimary(
                                                          context)),
                                            ),
                                            Expanded(
                                              child: Text(
                                                '${_monthsDe[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white
                                                        : AppTheme.textPrimary(
                                                            context),
                                                    fontWeight:
                                                        FontWeight.w800),
                                              ),
                                            ),
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () => _nextMonth(),
                                              icon: Icon(Icons.chevron_right,
                                                  color: isDark
                                                      ? Colors.white
                                                      : AppTheme.textPrimary(
                                                          context)),
                                            ),
                                          ],
                                        ),
                                        _WeekdayRow(color: sub),
                                        const SizedBox(height: 4),
                                        _MonthGrid(
                                          month: _visibleMonth,
                                          firstDate: _firstDate,
                                          lastDate: _lastDate,
                                          start: _start,
                                          end: _end,
                                          onTap: _onDayTap,
                                          isBooked: _isBookedDay,
                                          primary: primary,
                                          textColor: isDark
                                              ? Colors.white
                                              : AppTheme.textPrimary(context),
                                          subText: sub,
                                          danger: danger,
                                        ),
                                      ],
                                    ),
                                    secondChild: const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                              'Die genaue Übergabe- und Rückgabezeit stimmst du nach Annahme im Chat ab.',
                              style: TextStyle(color: sub, fontSize: 12)),
                          if (_overlapsBlocked) ...[
                            const SizedBox(height: 8),
                            Text(
                                'Der gewählte Zeitraum überschneidet sich mit einer bestehenden Buchung.',
                                style: TextStyle(
                                    color: danger,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (PrivatePilotConfig.deliveryEnabled) ...[
                      _StepCard(
                        step: '2',
                        title: 'Übergabe',
                        subtitle: 'Entscheide, wie du den Artikel bekommst.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ChoiceCard(
                              title: 'Beim Vermieter abholen',
                              subtitle: 'Du holst den Artikel selbst ab.',
                              selected: !_hinwegLandlord,
                              onTap: () {
                                setState(() => _hinwegLandlord = false);
                                _persistDeliverySelection();
                              },
                            ),
                            const SizedBox(height: 10),
                            _ChoiceCard(
                              title: widget.item.offersDeliveryAtDropoff
                                  ? 'Lieferung durch Vermieter'
                                  : 'Aktuell nicht verfügbar',
                              subtitle: widget.item.offersDeliveryAtDropoff
                                  ? 'Der Vermieter bringt den Artikel zu dir.'
                                  : 'Lieferung ist für diesen Artikel aktuell nicht verfügbar.',
                              selected: _hinwegLandlord,
                              enabled: widget.item.offersDeliveryAtDropoff,
                              onTap: () {
                                if (!widget.item.offersDeliveryAtDropoff) {
                                  return;
                                }
                                setState(() => _hinwegLandlord = true);
                                _persistDeliverySelection();
                              },
                            ),
                            if (_requiresDeliveryAddress) ...[
                              const SizedBox(height: 12),
                              _AddressSection(
                                label: 'Lieferadresse',
                                helper:
                                    'Sobald wir die Adresse grob zuordnen können, zeigen wir dir Entfernung und Lieferkosten an.',
                                controller: _deliveryAddressCtrl,
                                estimatedKm: preview.deliveryKm,
                                fee: preview.deliveryFee,
                                feeLabel: 'Liefergebühr',
                                overMax: !preview.deliveryWithinMax,
                                maxKm: widget.item.maxDeliveryKmAtDropoff,
                                onChanged: (_) {
                                  setState(() {
                                    _deliveryLat = null;
                                    _deliveryLng = null;
                                    _deliveryCity = null;
                                  });
                                  _persistDeliverySelection();
                                },
                                onCheckAddress: () =>
                                    _openMapsSearch(_deliveryAddressCtrl.text),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text(
                                'Die genaue Uhrzeit und der finale Treffpunkt werden nach Annahme im Chat abgestimmt.',
                                style: TextStyle(color: sub, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _StepCard(
                        step: '3',
                        title: 'Rückgabe',
                        subtitle: 'Entscheide, wie der Artikel zurückgeht.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ChoiceCard(
                              title: 'Zum Vermieter zurückbringen',
                              subtitle: 'Du bringst den Artikel selbst zurück.',
                              selected: !_rueckwegLandlord,
                              onTap: () {
                                setState(() => _rueckwegLandlord = false);
                                _persistDeliverySelection();
                              },
                            ),
                            const SizedBox(height: 10),
                            _ChoiceCard(
                              title: widget.item.offersPickupAtReturn
                                  ? 'Abholung durch Vermieter'
                                  : 'Aktuell nicht verfügbar',
                              subtitle: widget.item.offersPickupAtReturn
                                  ? 'Der Vermieter holt den Artikel bei dir ab.'
                                  : 'Abholung ist für diesen Artikel aktuell nicht verfügbar.',
                              selected: _rueckwegLandlord,
                              enabled: widget.item.offersPickupAtReturn,
                              onTap: () {
                                if (!widget.item.offersPickupAtReturn) return;
                                setState(() => _rueckwegLandlord = true);
                                _persistDeliverySelection();
                              },
                            ),
                            if (_requiresReturnAddress) ...[
                              const SizedBox(height: 12),
                              _AddressSection(
                                label: 'Rückgabeadresse',
                                helper:
                                    'Sobald wir die Adresse grob zuordnen können, zeigen wir dir Entfernung und Abholkosten an.',
                                controller: _returnAddressCtrl,
                                estimatedKm: preview.returnKm,
                                fee: preview.pickupFee,
                                feeLabel: 'Abholgebühr',
                                overMax: !preview.returnWithinMax,
                                maxKm: widget.item.maxPickupKmAtReturn,
                                onChanged: (_) {
                                  setState(() {
                                    _returnLat = null;
                                    _returnLng = null;
                                    _returnCity = null;
                                  });
                                  _persistDeliverySelection();
                                },
                                onCheckAddress: () =>
                                    _openMapsSearch(_returnAddressCtrl.text),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text(
                                'Die genaue Uhrzeit und der finale Treffpunkt werden nach Annahme im Chat abgestimmt.',
                                style: TextStyle(color: sub, fontSize: 12)),
                          ],
                        ),
                      ),
                    ] else
                      _StepCard(
                        step: '2',
                        title: 'Persönliche Abholung und Rückgabe',
                        subtitle:
                            'Lieferung und Versand sind im Privat-Pilot deaktiviert.',
                        child: Text(
                          'Du holst den Gegenstand beim Vermieter ab und bringst '
                          'ihn persönlich dorthin zurück. Den genauen Termin und '
                          'Treffpunkt stimmt ihr nach Annahme im Buchungschat ab.',
                          style: TextStyle(color: sub, height: 1.45),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _StepCard(
                      step: PrivatePilotConfig.deliveryEnabled ? '4' : '3',
                      title: 'Übersicht & Preis',
                      subtitle:
                          'Hier siehst du die preisrelevanten Bestandteile deiner Anfrage.',
                      child: Column(
                        children: [
                          _PriceRow(
                              label: 'Mietpreis',
                              value: preview.rentalSubtotal),
                          if (preview.discountAmount > 0)
                            _PriceRow(
                                label: 'Rabatt',
                                value: -preview.discountAmount,
                                positiveAccent: true),
                          _PriceRow(
                              label: 'Plattformgebühr',
                              value: preview.platformFee),
                          if (_hinwegLandlord)
                            _PriceRow(
                                label: 'Liefergebühr',
                                value: preview.deliveryFee,
                                pending: preview.deliveryFeePending),
                          if (_rueckwegLandlord)
                            _PriceRow(
                                label: 'Abholgebühr',
                                value: preview.pickupFee,
                                pending: preview.pickupFeePending),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Divider(
                                color: isDark
                                    ? Colors.white24
                                    : const Color(0xFFE2E8F0),
                                height: 1),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Preisrelevante Änderungen müssen später von beiden Seiten bestätigt werden.',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : AppTheme.textSecondary(context),
                                  fontSize: 12,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                  color:
                      isDark ? Colors.black : AppTheme.surfacePrimary(context),
                  border: Border(
                      top: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : AppTheme.glassStroke(context)))),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Gesamtbetrag',
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textPrimary(context),
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text('inkl. Plattformgebühr',
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : AppTheme.textSecondary(context),
                                      fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('${preview.total.toStringAsFixed(2)} €',
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textPrimary(context),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 148,
                          child: FilledButton(
                            onPressed: _canContinue ? _confirm : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: BrandColors.primary,
                              disabledBackgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.14)
                                  : AppTheme.surfaceSecondary(context),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: isDark
                                  ? Colors.white70
                                  : AppTheme.textSecondary(context),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _checking
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Text(_start == null ? 'Weiter' : 'Weiter'),
                          ),
                        ),
                      ],
                    ),
                    if (continueHint != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          continueHint,
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : AppTheme.textSecondary(context),
                              fontSize: 12,
                              height: 1.35),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PricePreview {
  final double rentalSubtotal;
  final double baseTotal;
  final double discountAmount;
  final double platformFee;
  final double deliveryFee;
  final double pickupFee;
  final double total;
  final double? deliveryKm;
  final double? returnKm;
  final bool deliveryWithinMax;
  final bool returnWithinMax;
  final bool deliveryFeePending;
  final bool pickupFeePending;

  const _PricePreview({
    required this.rentalSubtotal,
    required this.baseTotal,
    required this.discountAmount,
    required this.platformFee,
    required this.deliveryFee,
    required this.pickupFee,
    required this.total,
    required this.deliveryKm,
    required this.returnKm,
    required this.deliveryWithinMax,
    required this.returnWithinMax,
    required this.deliveryFeePending,
    required this.pickupFeePending,
  });
}

class _ThresholdChip {
  final int days;
  final String label;
  final bool best;
  const _ThresholdChip(
      {required this.days, required this.label, this.best = false});
}

class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final Widget child;
  const _StepCard(
      {required this.step,
      required this.title,
      required this.subtitle,
      required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = BrandColors.primary;
    final lineColor =
        isDark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFD7E3F4);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark
                            ? accent.withValues(alpha: 0.22)
                            : accent.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: 1.2),
                      ),
                      child: Text(step,
                          style: TextStyle(
                              color: isDark ? Colors.white : accent,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 1.5,
                      height: 28,
                      color: lineColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : AppTheme.textPrimary(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : AppTheme.textSecondary(context),
                            fontSize: 12,
                            height: 1.35)),
                  ])),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _ChoiceCard(
      {required this.title,
      required this.subtitle,
      required this.selected,
      this.enabled = true,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = BrandColors.primary;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? primary.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: selected
                      ? primary
                      : Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected
                        ? primary
                        : (isDark
                            ? Colors.white70
                            : AppTheme.textSecondary(context))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.textPrimary(context),
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : AppTheme.textSecondary(context),
                              fontSize: 12,
                              height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressSection extends StatelessWidget {
  final String label;
  final String helper;
  final TextEditingController controller;
  final double? estimatedKm;
  final double fee;
  final String feeLabel;
  final bool overMax;
  final double? maxKm;
  final ValueChanged<String> onChanged;
  final VoidCallback onCheckAddress;

  const _AddressSection({
    required this.label,
    required this.helper,
    required this.controller,
    required this.estimatedKm,
    required this.fee,
    required this.feeLabel,
    required this.overMax,
    required this.maxKm,
    required this.onChanged,
    required this.onCheckAddress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? Colors.white70 : AppTheme.textSecondary(context);
    final danger = BrandColors.danger;
    final canCheck = controller.text.trim().isNotEmpty;
    final hasEstimate = estimatedKm != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : AppTheme.surfacePrimary(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : AppTheme.glassStroke(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textPrimary(context),
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onChanged: onChanged,
            style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimary(context)),
            decoration: InputDecoration(
              hintText: 'z. B. Musterstraße 12, Stuttgart',
              hintStyle: TextStyle(
                  color:
                      isDark ? Colors.white54 : AppTheme.textDisabled(context)),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppTheme.surfaceSecondary(context),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : AppTheme.glassStroke(context))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : AppTheme.glassStroke(context))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: BrandColors.primary)),
            ),
          ),
          const SizedBox(height: 8),
          Text(helper, style: TextStyle(color: sub, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: canCheck ? onCheckAddress : null,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Adresse in Maps öffnen'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasEstimate
                      ? 'Entfernung: ca. ${estimatedKm!.toStringAsFixed(1)} km'
                      : 'Kosten können wir aktuell nur berechnen, wenn die Adresse einer bekannten Stadt zugeordnet werden kann.',
                  style: TextStyle(
                      color: hasEstimate
                          ? (isDark
                              ? Colors.white70
                              : AppTheme.textSecondary(context))
                          : (isDark
                              ? Colors.white60
                              : AppTheme.textSecondary(context)),
                      fontSize: 12,
                      height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasEstimate
                ? '$feeLabel: ${fee.toStringAsFixed(2)} €'
                : '$feeLabel: noch nicht berechnet',
            style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimary(context),
                fontWeight: FontWeight.w700),
          ),
          if (overMax) ...[
            const SizedBox(height: 8),
            Text(
              maxKm != null
                  ? 'Diese Adresse liegt außerhalb des angebotenen Bereichs (max. ${maxKm!.toStringAsFixed(0)} km).'
                  : 'Diese Adresse liegt außerhalb des angebotenen Bereichs.',
              style: TextStyle(
                  color: danger, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double value;
  final bool positiveAccent;
  final bool pending;
  const _PriceRow(
      {required this.label,
      required this.value,
      this.positiveAccent = false,
      this.pending = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = positiveAccent
        ? const Color(0xFF86EFAC)
        : (isDark ? Colors.white70 : AppTheme.textSecondary(context));
    final valueColor = positiveAccent
        ? const Color(0xFF86EFAC)
        : (isDark ? Colors.white : AppTheme.textPrimary(context));
    final pendingColor =
        isDark ? Colors.white60 : AppTheme.textSecondary(context);
    final prefix = value < 0 ? '- ' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: labelColor, fontSize: 13)),
          Text(
            pending
                ? 'noch nicht berechnet'
                : '$prefix${value.abs().toStringAsFixed(2)} €',
            style: TextStyle(
                color: pending ? pendingColor : valueColor,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DiscountChip extends StatelessWidget {
  final _ThresholdChip chip;
  final bool isSelected;
  final VoidCallback onTap;
  const _DiscountChip(
      {required this.chip, required this.isSelected, required this.onTap});

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
          color: isSelected
              ? primary.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: isSelected ? primary : border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(chip.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  final Color color;
  const _WeekdayRow({required this.color});
  static const _wdDe = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  @override
  Widget build(BuildContext context) => Row(children: [
        for (final d in _wdDe)
          Expanded(
              child: Center(
                  child: Text(d,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w600))))
      ]);
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? start;
  final DateTime? end;
  final void Function(DateTime) onTap;
  final bool Function(DateTime) isBooked;
  final Color primary;
  final Color textColor;
  final Color subText;
  final Color danger;
  const _MonthGrid(
      {required this.month,
      required this.firstDate,
      required this.lastDate,
      required this.start,
      required this.end,
      required this.onTap,
      required this.isBooked,
      required this.primary,
      required this.textColor,
      required this.subText,
      required this.danger});

  int _daysInMonth(DateTime m) => DateTime(m.year, m.month + 1, 0).day;
  int _mondayBasedWeekday(DateTime d) => (d.weekday + 6) % 7;

  @override
  Widget build(BuildContext context) {
    final days = _daysInMonth(month);
    final firstW = _mondayBasedWeekday(month);
    final totalCells = ((firstW + days + 6) ~/ 7) * 7;
    final cells = <DateTime?>[];
    for (int i = 0; i < firstW; i++) {
      cells.add(null);
    }
    for (int d = 1; d <= days; d++) {
      cells.add(DateTime(month.year, month.month, d));
    }
    while (cells.length < totalCells) {
      cells.add(null);
    }
    return Column(children: [
      for (int row = 0; row < cells.length / 7; row++)
        Row(children: [
          for (int col = 0; col < 7; col++)
            Expanded(
                child: _DayCell(
                    day: cells[row * 7 + col],
                    firstDate: firstDate,
                    lastDate: lastDate,
                    start: start,
                    end: end,
                    onTap: onTap,
                    primary: primary,
                    textColor: textColor,
                    subText: subText,
                    danger: danger,
                    isBooked: isBooked)),
        ]),
    ]);
  }
}

class _DayCell extends StatelessWidget {
  final DateTime? day;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? start;
  final DateTime? end;
  final void Function(DateTime) onTap;
  final bool Function(DateTime) isBooked;
  final Color primary;
  final Color textColor;
  final Color subText;
  final Color danger;
  const _DayCell(
      {required this.day,
      required this.firstDate,
      required this.lastDate,
      required this.start,
      required this.end,
      required this.onTap,
      required this.isBooked,
      required this.primary,
      required this.textColor,
      required this.subText,
      required this.danger});

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    if (day == null) return const SizedBox(height: 42);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final d = day!;
    final disabled = d.isBefore(firstDate) || d.isAfter(lastDate);
    final booked = isBooked(d);
    final isToday = _sameDay(d, todayOnly);
    final isStart = start != null && _sameDay(d, start!);
    final isEnd =
        end != null && _sameDay(d, end!.subtract(const Duration(days: 1)));
    final inRange =
        start != null && end != null && !d.isBefore(start!) && d.isBefore(end!);
    final selected = isStart || isEnd;

    Color bg = Colors.transparent;
    BoxBorder? border;
    Color fg = disabled
        ? (isDark ? const Color(0xFF9CA3AF) : AppTheme.textDisabled(context))
        : textColor;
    if (disabled) {
      bg = isDark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFF1F5F9);
      border = Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0));
    }
    if (booked) {
      bg = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : const Color(0xFFF8FAFC);
      fg = isDark ? const Color(0xFF9CA3AF) : AppTheme.textDisabled(context);
      border = Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE5E7EB));
    } else if (selected) {
      bg = primary;
      fg = Colors.white;
      border = Border.all(color: primary);
    } else if (inRange) {
      bg = primary.withValues(alpha: 0.18);
      fg = isDark ? Colors.white : AppTheme.textPrimary(context);
    } else if (isToday) {
      border = Border.all(
          color: primary.withValues(alpha: isDark ? 0.85 : 1.0), width: 1.2);
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: (booked || disabled) ? null : () => onTap(d),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: border,
          ),
          child: booked
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Text('${d.day}',
                        style:
                            TextStyle(color: fg, fontWeight: FontWeight.w500)),
                    Container(
                        width: 20,
                        height: 1.5,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : AppTheme.textDisabled(context)),
                  ],
                )
              : Text('${d.day}',
                  style: TextStyle(
                      color: fg,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w500)),
        ),
      ),
    );
  }
}
