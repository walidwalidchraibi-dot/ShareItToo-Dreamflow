import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lendify/models/category.dart';
import 'package:lendify/services/data_service.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/utils/category_label.dart';

class FiltersOverlay {
  static Future<Map<String, dynamic>?> show(BuildContext context, {Map<String, dynamic>? initial}) async {
    return await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(children: [
                // Allow tap outside sheet to dismiss
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
                Align(alignment: Alignment.bottomCenter, child: _FiltersSheet(initial: initial)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _FiltersSheet({this.initial});
  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  IconData _iconFromName(String name) {
    switch (name) {
      case 'devices': return Icons.devices;
      case 'computer': return Icons.computer;
      case 'camera_alt': return Icons.camera_alt;
      case 'sports_esports': return Icons.sports_esports;
      case 'kitchen': return Icons.kitchen;
      case 'weekend': return Icons.weekend;
      case 'grass': return Icons.grass;
      case 'construction': return Icons.construction;
      case 'pedal_bike': return Icons.pedal_bike;
      case 'directions_car': return Icons.directions_car;
      case 'sports_soccer': return Icons.sports_soccer;
      case 'checkroom': return Icons.checkroom;
      case 'child_friendly': return Icons.child_friendly;
      case 'music_note': return Icons.music_note;
      case 'menu_book': return Icons.menu_book;
      case 'watch': return Icons.watch;
      case 'palette': return Icons.palette;
      case 'spa': return Icons.spa;
      case 'pets': return Icons.pets;
      case 'business_center': return Icons.business_center;
      case 'more_horiz': return Icons.more_horiz;
      default: return Icons.category;
    }
  }
  RangeValues _price = const RangeValues(0, 500);
  String _priceUnit = 'day'; // 'hour' | 'day' | 'week'
  double _distance = 25;
  bool _verifiedOnly = false;
  String _condition = 'egal'; // 'neu' | 'wie-neu' | 'gut' | 'akzeptabel' | 'egal' (label "Alle")
  // Delivery filters: multi-select list of codes: 'dropoff' | 'pickup' | 'express'
  final Set<String> _delivery = <String>{};
  final Set<String> _selectedCategories = {};
  String _sort = 'Preis';
  String _priceOrder = 'asc'; // 'asc' | 'desc'
  bool _priceOrderExpanded = true; // controls expand/collapse for Preis order options
  double _minRating = 0;
  // Coarse/top-level categories used in filters (labels only)
  List<String> _allCoarse = const [];
  final TextEditingController _minCtrl = TextEditingController(text: '0');
  final TextEditingController _maxCtrl = TextEditingController(text: '500');
  final FocusNode _minFocus = FocusNode();
  final FocusNode _maxFocus = FocusNode();
  bool _minCleared = false;
  bool _maxCleared = false;
  // Ort
  String _locationMode = 'registered'; // 'gps' | 'address' | 'registered'
  final TextEditingController _addressCtrl = TextEditingController();
  String? _registeredCity;
  String _distanceBias = 'near'; // 'near' | 'far'

  @override
  void initState() {
    super.initState();
    _load();
    final i = widget.initial;
    if (i != null) {
      _price = i['price'] ?? _price;
      _priceUnit = i['priceUnit'] ?? _priceUnit;
      _distance = i['distance'] ?? _distance;
      _verifiedOnly = i['verified'] ?? _verifiedOnly;
      _condition = i['condition'] ?? _condition;
      _selectedCategories.addAll((i['categories'] as List<String>? ?? const []));
      _delivery
        ..clear()
        ..addAll(((i['delivery'] as List?)?.cast<String>() ?? const <String>[]));
      _sort = i['sort'] ?? _sort;
      _minRating = (i['minRating'] as double?) ?? _minRating;
      _minCtrl.text = _price.start.round().toString();
      _maxCtrl.text = _price.end.round().toString();
    }
    // Clear default values on first focus so placeholder is readable and defaults vanish
    _minFocus.addListener(() {
      if (_minFocus.hasFocus && !_minCleared) {
        _minCleared = true;
        _minCtrl.clear();
        setState(() {});
      }
    });
    _maxFocus.addListener(() {
      if (_maxFocus.hasFocus && !_maxCleared) {
        _maxCleared = true;
        _maxCtrl.clear();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _addressCtrl.dispose();
    _minFocus.dispose();
    _maxFocus.dispose();
    super.dispose();
  }

  IconData _coarseIconForGroup(String group) {
    final g = group.toLowerCase();
    if (g.contains('technik')) return Icons.devices;
    if (g.contains('haushalt') || g.contains('wohnen')) return Icons.weekend;
    if (g.contains('fahrzeuge') || g.contains('mobil')) return Icons.directions_car;
    if (g.contains('mode') || g.contains('lifestyle')) return Icons.checkroom;
    if (g.contains('sport') || g.contains('hobby') || g.contains('hobb')) return Icons.sports_soccer;
    if (g.contains('werkzeuge') || g.contains('geräte') || g.contains('geraete')) return Icons.construction;
    if (g.contains('garten') || g.contains('hof')) return Icons.grass;
    if (g.contains('büro') || g.contains('buero') || g.contains('gewerbe')) return Icons.business_center;
    if (g.contains('baby') || g.contains('kinder')) return Icons.child_friendly;
    if (g.contains('haustier')) return Icons.pets;
    return Icons.category;
  }

  Future<void> _load() async {
    final cats = await DataService.getCategories();
    final user = await DataService.getCurrentUser();
    // Build unique coarse group set from categories and align to fixed order
    final present = <String>{
      for (final c in cats) DataService.coarseCategoryFor(c.name)
    };
    final ordered = [
      for (final g in DataService.coarseCategoryOrder)
        if (present.contains(g)) g
    ];
    if (!mounted) return;
    setState(() {
      _allCoarse = ordered.isNotEmpty ? ordered : DataService.coarseCategoryOrder;
      _registeredCity = user?.city;
    });
  }

  Future<void> _pickSort() async {
    final l10n = context.read<LocalizationController>();
    final sel = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        // Preis first as default/primary choice
        ListTile(leading: const Icon(Icons.euro, color: Colors.white70), title: Text(l10n.t('Preis'), style: TextStyle(color: Theme.of(context).colorScheme.primary)), onTap: () => Navigator.pop(context, 'Preis')),
        ListTile(leading: const Icon(Icons.place, color: Colors.white70), title: Text(l10n.t('Entfernung'), style: TextStyle(color: Theme.of(context).colorScheme.primary)), onTap: () => Navigator.pop(context, 'Entfernung')),
        ListTile(leading: const Icon(Icons.star, color: Colors.white70), title: Text(l10n.t('Bewertung'), style: TextStyle(color: Theme.of(context).colorScheme.primary)), onTap: () => Navigator.pop(context, 'Bewertung')),
        ListTile(leading: const Icon(Icons.schedule, color: Colors.white70), title: Text(l10n.t('Neueste'), style: TextStyle(color: Theme.of(context).colorScheme.primary)), onTap: () => Navigator.pop(context, 'Neueste')),
        const SizedBox(height: 8),
      ])),
    );
    if (sel == null) return;
    setState(() => _sort = sel);
  }

  void _syncPriceFromText() {
    final min = double.tryParse(_minCtrl.text.replaceAll(',', '.')) ?? _price.start;
    final max = double.tryParse(_maxCtrl.text.replaceAll(',', '.')) ?? _price.end;
    final clampedMin = min.clamp(0, 500);
    final clampedMax = max.clamp(0, 500);
    final orderedMin = clampedMin <= clampedMax ? clampedMin : clampedMax;
    final orderedMax = clampedMax >= clampedMin ? clampedMax : clampedMin;
    setState(() => _price = RangeValues(orderedMin.toDouble(), orderedMax.toDouble()));
  }

  IconData _sortIcon(String s) {
    switch (s) {
      case 'Preis': return Icons.euro;
      case 'Bewertung': return Icons.star;
      case 'Neueste': return Icons.schedule;
      case 'Entfernung':
      default: return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sheet = Container(
      constraints: const BoxConstraints(maxWidth: 720),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 44,
              child: Stack(children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)))),
                Positioned(
                  right: 12,
                  top: 6,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Center(child: Icon(Icons.close, color: Colors.white)),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            Center(child: Builder(builder: (context) => Text(context.watch<LocalizationController>().t('Filter'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)))),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Ort selector removed per request
                  const SizedBox.shrink(),

                  // 1) Sortieren nach
                  const SizedBox(height: 12),
                  _Section(label: context.watch<LocalizationController>().t('Sortieren nach'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SizedBox(
                      height: 44,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Expanded(child: _FieldButton(label: _sort, icon: _sortIcon(_sort), onTap: _pickSort)),
                        if (_sort == 'Preis')
                          InkWell(
                            onTap: () => setState(() => _priceOrderExpanded = !_priceOrderExpanded),
                            borderRadius: BorderRadius.circular(22),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: AnimatedRotation(
                                  duration: const Duration(milliseconds: 200),
                                  turns: _priceOrderExpanded ? 0.5 : 0.0, // arrow up when expanded
                                  child: const Icon(Icons.expand_more, color: Colors.white70, size: 22),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    if (_sort == 'Preis' && _priceOrderExpanded)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          Expanded(child: RadioListTile<String>(contentPadding: EdgeInsets.zero, title: const Text('aufsteigend', style: TextStyle(color: Colors.white)), value: 'asc', groupValue: _priceOrder, onChanged: (v) => setState(() => _priceOrder = v ?? 'asc'))),
                          Expanded(child: RadioListTile<String>(contentPadding: EdgeInsets.zero, title: const Text('absteigend', style: TextStyle(color: Colors.white)), value: 'desc', groupValue: _priceOrder, onChanged: (v) => setState(() => _priceOrder = v ?? 'desc'))),
                        ]),
                      ),
                  ])),

                  // 2) Verifizierung
                  const SizedBox(height: 12),
                  _Section(label: context.watch<LocalizationController>().t('Verifizierung'), child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Builder(builder: (context) => Text(context.watch<LocalizationController>().t('Nur verifiziert'), style: const TextStyle(color: Colors.white))),
                    value: _verifiedOnly,
                    onChanged: (v) => setState(() => _verifiedOnly = v),
                  )),

                  // 3) Preis pro
                  const SizedBox(height: 12),
                  _Section(label: context.watch<LocalizationController>().t('Preis pro'), labelColor: Theme.of(context).colorScheme.primary, child: Column(children: [
                    Row(children: [
                      Wrap(spacing: 8, children: [
                        _ChoiceChip(value: 'day', label: 'Tag', group: _priceUnit, onChanged: (v) => setState(() => _priceUnit = v)),
                        _ChoiceChip(value: 'week', label: 'Woche', group: _priceUnit, onChanged: (v) => setState(() => _priceUnit = v)),
                      ]),
                      const Spacer(),
                    ]),
                    const SizedBox(height: 8),
                    RangeSlider(values: _price, min: 0, max: 500, divisions: 100, labels: RangeLabels('${_price.start.round()} €', '${_price.end.round()} €'), onChanged: (v) {
                      setState(() {
                        _price = v;
                        _minCtrl.text = v.start.round().toString();
                        _maxCtrl.text = v.end.round().toString();
                      });
                    }), 
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _minCtrl,
                          focusNode: _minFocus,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Min',
                            hintText: '€ 0',
                            hintStyle: TextStyle(color: Colors.white70),
                          ),
                          onSubmitted: (_) => _syncPriceFromText(),
                          onEditingComplete: _syncPriceFromText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _maxCtrl,
                          focusNode: _maxFocus,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Max',
                            hintText: '€ 500',
                            hintStyle: TextStyle(color: Colors.white70),
                          ),
                          onSubmitted: (_) => _syncPriceFromText(),
                          onEditingComplete: _syncPriceFromText,
                        ),
                      ),
                    ])
                  ])),
                  // 4) Zustand
                  const SizedBox(height: 12),
                  _Section(label: context.watch<LocalizationController>().t('Zustand'), child: Wrap(spacing: 8, runSpacing: 8, children: [
                    _ChoiceChip(value: 'neu', label: context.watch<LocalizationController>().t('Neu'), group: _condition, onChanged: (v) => setState(() => _condition = v)),
                    _ChoiceChip(value: 'wie-neu', label: context.watch<LocalizationController>().t('wie Neu'), group: _condition, onChanged: (v) => setState(() => _condition = v)),
                    _ChoiceChip(value: 'gut', label: context.watch<LocalizationController>().t('Gut'), group: _condition, onChanged: (v) => setState(() => _condition = v)),
                    _ChoiceChip(value: 'akzeptabel', label: context.watch<LocalizationController>().t('Akzeptabel'), group: _condition, onChanged: (v) => setState(() => _condition = v)),
                    _ChoiceChip(value: 'egal', label: context.watch<LocalizationController>().t('Alle'), group: _condition, onChanged: (v) => setState(() => _condition = v)),
                  ])),
                  // 5) Entfernung (slightly thinner)
                  const SizedBox(height: 12),
                  _Section(label: context.watch<LocalizationController>().t('Entfernung (bis zu)'), dense: true, child: Column(children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(trackHeight: 2.0),
                      child: Slider(value: _distance, min: 0, max: 100, divisions: 20, label: '${_distance.round()} km', onChanged: (v) => setState(() => _distance = v)),
                    ),
                    Row(children: [
                      Expanded(child: Text('${_distance.round()} km', style: const TextStyle(color: Colors.white70))),
                      const SizedBox.shrink()
                    ])
                  ])),

                  // 6) Lieferung
                  const SizedBox(height: 12),
                  _Section(
                    label: context.watch<LocalizationController>().t('Lieferung'),
                    subtitle: Text(context.watch<LocalizationController>().t('Mehrfachauswahl möglich'), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _RoundCheckboxRow(
                        label: context.watch<LocalizationController>().t('Lieferung bei Abgabe'),
                        value: _delivery.contains('dropoff'),
                        onChanged: (v) => setState(() {
                          if (v) {
                            _delivery.add('dropoff');
                          } else {
                            _delivery.remove('dropoff');
                            _delivery.remove('express');
                          }
                        }),
                      ),
                      if (_delivery.contains('dropoff'))
                        Padding(
                          padding: const EdgeInsets.only(left: 38), // ~1cm Einzug
                          child: _RoundCheckboxRow(
                            label: context.watch<LocalizationController>().t('Prioritätslieferung (optional)'),
                            value: _delivery.contains('express'),
                            small: true,
                            onChanged: (v) => setState(() => v ? _delivery.add('express') : _delivery.remove('express')),
                          ),
                        ),
                      _RoundCheckboxRow(
                        label: context.watch<LocalizationController>().t('Abholung bei Rückgabe'),
                        value: _delivery.contains('pickup'),
                        onChanged: (v) => setState(() => v ? _delivery.add('pickup') : _delivery.remove('pickup')),
                      ),
                    ]),
                  ),

                  // 7) Bewertung
                  const SizedBox(height: 12),
                  // Bewertung stars
                  _Section(label: context.watch<LocalizationController>().t('Bewertung'), child: Row(children: [
                    for (int i = 1; i <= 5; i++)
                      IconButton(
                        onPressed: () => setState(() => _minRating = i.toDouble()),
                        icon: Icon(i <= _minRating ? Icons.star : Icons.star_border, color: i <= _minRating ? const Color(0xFFFB923C) : Colors.white24),
                      ),
                    const SizedBox.shrink(),
                  ])),

                  // 8) Kategorien (Top-Level/Oberkategorien)
                  const SizedBox(height: 12),
                  // Kategorien comes last
                  _Section(label: context.watch<LocalizationController>().t('Kategorien'), subtitle: Text(context.watch<LocalizationController>().t('Mehrfachauswahl möglich'), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w600)), child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    // Taller tiles so long second lines (e.g., "& Kleingeräte") fully fit
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.68),
                    itemCount: _allCoarse.length,
                    itemBuilder: (context, index) {
                      final raw = _allCoarse[index];
                      final label = stackCategoryLabel(raw);
                      final active = _selectedCategories.contains(raw);
                      return InkWell(
                        onTap: () => setState(() {
                          if (active) {
                            _selectedCategories.remove(raw);
                          } else {
                            _selectedCategories.add(raw);
                          }
                        }),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                            color: active ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: active ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.16)),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(_coarseIconForGroup(_allCoarse[index]), color: active ? Colors.black : Colors.white, size: 24),
                            const SizedBox(height: 6),
                            Text(
                              label,
                              maxLines: 2,
                              softWrap: true,
                              overflow: TextOverflow.clip,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: active ? Colors.black : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                                height: 1.15,
                                letterSpacing: -0.1,
                              ),
                            ),


                          ]),
                        ),
                      );
                    },
                  )),

                  const SizedBox(height: 8),
                ]),
              ),
            ),
            // Pinned footer actions
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(children: [
                Expanded(child: OutlinedButton(onPressed: () {
                  // Apply defaults and close immediately
                  final defaults = {
                    'price': const RangeValues(0, 500),
                    'priceUnit': 'day',
                    'distance': 25.0,
                    'distanceBias': 'near',
                    'verified': false,
                    'condition': 'egal',
                    'delivery': <String>[],
                    'categories': <String>[],
                    'sort': 'Preis',
                    'priceOrder': 'asc',
                    'minRating': 0.0,
                    'location': {
                      'mode': 'registered',
                      'address': '',
                      'registeredCity': _registeredCity,
                    }
                  };
                  Navigator.of(context).pop(defaults);
                }, child: Builder(builder: (context) => Text(context.watch<LocalizationController>().t('Zurücksetzen'))))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () {
                  _syncPriceFromText();
                  Navigator.of(context).pop({
                    'price': _price,
                    'priceUnit': _priceUnit,
                    'distance': _distance,
                    'distanceBias': _distanceBias,
                    'verified': _verifiedOnly,
                    'condition': _condition,
                    'delivery': _delivery.toList(),
                    'categories': _selectedCategories.toList(),
                    'sort': _sort,
                    'priceOrder': _priceOrder,
                    'minRating': _minRating,
                    'location': {
                      'mode': _locationMode,
                      'address': _addressCtrl.text.trim(),
                      'registeredCity': _registeredCity,
                    }
                  });
                }, child: Builder(builder: (context) => Text(context.watch<LocalizationController>().t('Anwenden'))))),
              ]),
            ),
          ],
        ),
      ),
    );

    return Padding(padding: const EdgeInsets.only(bottom: 8), child: sheet);
  }
}

class _Section extends StatelessWidget {
  final String label; final Widget child; final bool dense; final Color? labelColor; final Widget? subtitle;
  const _Section({required this.label, required this.child, this.dense = false, this.labelColor, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 6 : 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: labelColor ?? Colors.white70, fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[const SizedBox(height: 4), subtitle!],
        const SizedBox(height: 6),
        child,
      ]),
    );
  }
}

class _FieldButton extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const _FieldButton({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Row(children: [
      Icon(icon, size: 18, color: primary),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primary), overflow: TextOverflow.ellipsis)),
    ])));
  }
}

class _ChoiceChip extends StatelessWidget {
  final String value; final String label; final String group; final ValueChanged<String> onChanged;
  const _ChoiceChip({required this.value, required this.label, required this.group, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final selected = value == group;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: selected ? Colors.black : Colors.white)),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onChanged(value),
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.20))),
    );
  }
}

class _FilterToggleChip extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  final bool dense;
  const _FilterToggleChip({required this.label, required this.value, required this.onChanged, this.icon, this.dense = false});
  @override
  Widget build(BuildContext context) {
    final selected = value;
    final primary = Theme.of(context).colorScheme.primary;
    final iconSize = dense ? 12.0 : 14.0;
    final fontSize = dense ? 11.0 : 14.0;
    final hPad = dense ? 8.0 : 12.0;
    final vPad = dense ? 4.0 : 6.0;
    return FilterChip(
      label: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: selected ? Colors.black : Colors.white),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(color: selected ? Colors.black : Colors.white, fontSize: fontSize, fontWeight: FontWeight.w600)),
        ]),
      ),
      visualDensity: dense ? const VisualDensity(horizontal: -3, vertical: -3) : VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selected: selected,
      onSelected: (v) => onChanged(v),
      selectedColor: primary,
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      showCheckmark: false,
      shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.20))),
    );
  }
}

class _ClearPill extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final String label;
  const _ClearPill({required this.active, required this.onTap, required this.label});
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg = active ? primary : Colors.white.withValues(alpha: 0.08);
    final fg = active ? Colors.black : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.clear_all, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _RoundCheckboxRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool small;
  const _RoundCheckboxRow({required this.label, required this.value, required this.onChanged, this.small = false});
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final textStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: small ? 12 : 14,
      height: 1.25,
    );
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Transform.scale(
            scale: small ? 0.85 : 1.0,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              shape: const CircleBorder(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
              activeColor: primary,
              checkColor: Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: textStyle, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}
