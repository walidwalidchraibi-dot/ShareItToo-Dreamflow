import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/user.dart' as app_user;
import 'package:lendify/services/data_service.dart';
import 'package:lendify/widgets/modern_range_picker_sheet.dart';
import 'package:lendify/widgets/item_details_overlay.dart';
import 'package:lendify/screens/see_all_screen.dart';
import 'package:lendify/screens/search_results_screen.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/openai/openai_config.dart';

class SearchOverlay {
  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
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
                Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: Container(color: Colors.transparent))),
                Positioned.fill(child: _SearchSheet()),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _BlurLayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: Container(color: Colors.transparent));
  }
}

class _SearchSheet extends StatefulWidget {
  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final TextEditingController _aiCtrl = TextEditingController();
  final FocusNode _aiFocus = FocusNode();
  final TextEditingController _whatCtrl = TextEditingController();
  final FocusNode _whatFocus = FocusNode();
  final TextEditingController _whereCtrl = TextEditingController();
  final FocusNode _whereFocus = FocusNode();
  // Floating suggestion overlays so the fields below don't move
  final LayerLink _whatLink = LayerLink();
  final LayerLink _whereLink = LayerLink();
  final GlobalKey _whatFieldKey = GlobalKey();
  final GlobalKey _whereFieldKey = GlobalKey();
  OverlayEntry? _whatOverlay;
  OverlayEntry? _whereOverlay;
  DateTime? _pickup;
  DateTime? _return;
  
  Future<void> _openDateTimeFlow() async {
    // Use a simple calendar range picker for an easier flow (like availability check)
    final now = DateTime.now();
    final initialRange = (_pickup != null && _return != null) ? DateTimeRange(start: _pickup!, end: _return!) : null;
    final picked = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      // Make barrier transparent so our in-sheet BackdropFilter can blur the page content
      barrierColor: Colors.transparent,
      builder: (context) => ModernRangePickerSheet(
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 2, now.month, now.day),
        initialRange: initialRange,
        allowSameDayEnd: true,
        unavailableRanges: const [],
      ),
    );
    if (picked != null) {
      setState(() {
        _pickup = picked.start;
        _return = picked.end;
      });
    }
  }

  List<String> _suggestions = [];
  List<String> _locSuggestions = [];
  List<Item> _nearby = [];
  // Live-updated grid suggestions based on Was/Wo/Datum
  List<Item> _displayNearby = [];
  Set<String> _verifiedOwnerIds = {};
  Map<String, app_user.User> _usersById = {};
  app_user.User? _currentUser;
  // Recent section removed per request – keep local var for minimal code churn but unused
  List<String> _recent = [];
  bool _loading = true;
  bool _recomputing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _whatFocus.addListener(() {
      if (_whatFocus.hasFocus) {
        _updateWhatOverlay();
      } else {
        _hideWhatOverlay();
      }
    });
    _whereFocus.addListener(() {
      if (_whereFocus.hasFocus) {
        _updateWhereOverlay();
      } else {
        _hideWhereOverlay();
      }
    });
  }

  Future<void> _loadData() async {
    final items = await DataService.getItems();
    final users = await DataService.getUsers();
    final me = await DataService.getCurrentUser();
    final byId = {for (final u in users) u.id: u};
    final verifiedIds = users.where((u) => u.isVerified).map((u) => u.id).toSet();
    final itemTitles = items.map((e) => e.title).where((e) => e.trim().isNotEmpty).toList();
    setState(() {
      _nearby = items;
      _usersById = byId;
      _verifiedOwnerIds = verifiedIds;
      _currentUser = me;
      _suggestions = itemTitles.take(12).toList();
      _recent = itemTitles.take(12).toList();
      _loading = false;
    });
    // Compute initial grid suggestions
    await _recomputeNearbySuggestions();
  }

  @override
  void dispose() {
    _hideWhatOverlay();
    _hideWhereOverlay();
    _aiCtrl.dispose();
    _aiFocus.dispose();
    _whatCtrl.dispose();
    _whatFocus.dispose();
    _whereCtrl.dispose();
    _whereFocus.dispose();
    super.dispose();
  }

  double? _priceMin;
  double? _priceMax;
  String? _categoryFilter;

  Future<void> _parseAIPrompt(String prompt) async {
    if (prompt.trim().isEmpty) return;
    
    // Use ChatGPT to intelligently parse the user's natural language input
    final result = await OpenAIConfig.parseSearchQuery(prompt);
    
    setState(() {
      // Update "Was" field
      if (result['what'] != null && result['what'].toString().isNotEmpty) {
        _whatCtrl.text = result['what'].toString();
      }
      
      // Update "Wo" field
      if (result['where'] != null && result['where'].toString().isNotEmpty) {
        _whereCtrl.text = result['where'].toString();
      }
      
      // Update "Wann" fields
      if (result['whenStart'] != null && result['whenStart'].toString().isNotEmpty) {
        try {
          final startDate = DateTime.parse(result['whenStart'].toString());
          _pickup = startDate;
          
          // Set end date if provided, otherwise same as start
          if (result['whenEnd'] != null && result['whenEnd'].toString().isNotEmpty) {
            _return = DateTime.parse(result['whenEnd'].toString());
          } else {
            _return = startDate;
          }
        } catch (e) {
          debugPrint('Failed to parse dates: $e');
        }
      }

      // Update price filters
      if (result['priceMin'] != null) {
        _priceMin = result['priceMin'] as double?;
      }
      if (result['priceMax'] != null) {
        _priceMax = result['priceMax'] as double?;
      }

      // Update category filter
      if (result['category'] != null && result['category'].toString().isNotEmpty) {
        _categoryFilter = result['category'].toString();
      }
    });
    // Refresh live grid after AI updated fields
    await _recomputeNearbySuggestions();
  }

  

  void _onQueryChangedWhat(String v) async {
    final items = await DataService.getItems();
    final q = v.toLowerCase();
    final titles = items.map((e) => e.title).where((t) => t.trim().isNotEmpty).toSet();
    final tags = items.expand((e) => e.tags).where((t) => t.trim().isNotEmpty).toSet();
    final all = <String>{...titles, ...tags};
    final matches = all.where((t) => t.toLowerCase().contains(q)).toList()..sort((a, b) => a.toLowerCase().indexOf(q).compareTo(b.toLowerCase().indexOf(q)));
    setState(() => _suggestions = matches.take(10).toList());
    _updateWhatOverlay();
    await _recomputeNearbySuggestions();
  }

  void _onQueryChangedWhere(String v) async {
    final q = v.toLowerCase();
    final cities = DataService.getCities().keys;
    final items = await DataService.getItems();
    final fromItems = <String>{...items.map((e) => e.city), ...items.map((e) => e.country), ...items.map((e) => e.locationText)};
    final all = <String>{...cities, ...fromItems}.where((e) => e.trim().isNotEmpty).toSet();
    final matches = all.where((t) => t.toLowerCase().contains(q)).toList()..sort((a, b) => a.toLowerCase().indexOf(q).compareTo(b.toLowerCase().indexOf(q)));
    setState(() => _locSuggestions = matches.take(10).toList());
    _updateWhereOverlay();
    await _recomputeNearbySuggestions();
  }

  void _addToRecentWhat(String term) {
    if (term.trim().isEmpty) return;
    setState(() {
      _recent.removeWhere((e) => e.toLowerCase() == term.toLowerCase());
      _recent.insert(0, term);
      if (_recent.length > 12) _recent = _recent.take(12).toList();
    });
  }

  bool _isReturnValid(DateTime from, DateTime to) => to.isAfter(from);

  String _fmt(DateTime? dt) => dt == null ? 'Datum wählen' : '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

  List<Item> _filteredResults() {
    final q = _whatCtrl.text.trim().toLowerCase();
    final w = _whereCtrl.text.trim().toLowerCase();
    return _nearby.where((it) {
      final inTitleOrTags = it.title.toLowerCase().contains(q) || it.tags.any((t) => t.toLowerCase().contains(q));
      final inPlace = w.isEmpty || it.city.toLowerCase().contains(w) || it.country.toLowerCase().contains(w) || it.locationText.toLowerCase().contains(w) || it.tags.any((t) => t.toLowerCase().contains(w));
      final matchesWhat = q.isEmpty || inTitleOrTags;
      
      // Price filters
      final matchesPriceMin = _priceMin == null || it.pricePerDay >= _priceMin!;
      final matchesPriceMax = _priceMax == null || it.pricePerDay <= _priceMax!;
      
      // Category filter (basic string matching)
      final matchesCategory = _categoryFilter == null || 
        it.title.toLowerCase().contains(_categoryFilter!.toLowerCase()) ||
        it.tags.any((t) => t.toLowerCase().contains(_categoryFilter!.toLowerCase()));
      
      return matchesWhat && inPlace && matchesPriceMin && matchesPriceMax && matchesCategory;
    }).toList();
  }

  // Live compute suggestions grid near user's city or typed "Wo"
  Future<void> _recomputeNearbySuggestions() async {
    if (!mounted) return;
    try {
      setState(() => _recomputing = true);
      final pool = List<Item>.from(_nearby);
      final what = _whatCtrl.text.trim().toLowerCase();
      final whereRaw = _whereCtrl.text.trim();

      // Resolve target city text
      String targetCity = '';
      if (whereRaw.isNotEmpty) {
        final extracted = DataService.deriveCityFromAddress(whereRaw);
        targetCity = extracted.isNotEmpty ? extracted : whereRaw;
      } else {
        targetCity = (_currentUser?.city ?? '').toString();
      }

      // Find coordinates for target city
      (double lat, double lng)? targetCoords;
      if (targetCity.trim().isNotEmpty) {
        final cities = DataService.getCities();
        for (final e in cities.entries) {
          if (e.key.toLowerCase() == targetCity.toLowerCase()) { targetCoords = (e.value.$1, e.value.$2); break; }
        }
        if (targetCoords == null) {
          for (final e in cities.entries) {
            if (targetCity.toLowerCase().contains(e.key.toLowerCase()) || e.key.toLowerCase().contains(targetCity.toLowerCase())) { targetCoords = (e.value.$1, e.value.$2); break; }
          }
        }
      }

      // Filter by what/price/category
      List<Item> candidates = pool.where((it) {
        final matchWhat = what.isEmpty || it.title.toLowerCase().contains(what) || it.tags.any((t) => t.toLowerCase().contains(what));
        final matchesPriceMin = _priceMin == null || it.pricePerDay >= _priceMin!;
        final matchesPriceMax = _priceMax == null || it.pricePerDay <= _priceMax!;
        final matchesCategory = _categoryFilter == null ||
            it.title.toLowerCase().contains(_categoryFilter!.toLowerCase()) ||
            it.tags.any((t) => t.toLowerCase().contains(_categoryFilter!.toLowerCase()));
        return matchWhat && matchesPriceMin && matchesPriceMax && matchesCategory;
      }).toList();

      // Sort by distance to target or by recency
      if (targetCoords != null) {
        candidates.sort((a, b) {
          final da = DataService.estimateDistanceKm(a.lat, a.lng, targetCoords!.$1, targetCoords!.$2);
          final db = DataService.estimateDistanceKm(b.lat, b.lng, targetCoords!.$1, targetCoords!.$2);
          return da.compareTo(db);
        });
        // Keep items within ~60km for "in der Nähe"
        candidates = candidates.where((it) => DataService.estimateDistanceKm(it.lat, it.lng, targetCoords!.$1, targetCoords!.$2) <= 60).toList();
      } else {
        candidates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      // Optional availability filter when a date range is set
      List<Item> available = candidates;
      if (_pickup != null && _return != null) {
        final start = _pickup!;
        final end = _return!;
        final subset = candidates.take(80).toList();
        final checks = await Future.wait(subset.map((it) => DataService.checkAvailability(itemId: it.id, start: start, end: end)));
        available = [for (int i = 0; i < subset.length; i++) if (checks[i]) subset[i]];
      }

      setState(() {
        _displayNearby = available.take(16).toList();
      });
    } catch (e) {
      debugPrint('[_SearchSheet] recompute suggestions failed: ' + e.toString());
    } finally {
      if (mounted) setState(() => _recomputing = false);
    }
  }

  void _openResults() {
    final items = _filteredResults();
    String buildQueryText() {
      final w = _whatCtrl.text.trim();
      final loc = _whereCtrl.text.trim();
      if (w.isNotEmpty && loc.isNotEmpty) return '$w in $loc';
      if (w.isNotEmpty) return w;
      if (loc.isNotEmpty) return loc;
      return 'Suche';
    }
    String? buildDateText() {
      if (_pickup == null || _return == null) return null;
      final months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
      final s = _pickup!;
      final e = _return!;
      final left = '${s.day}. ${months[s.month - 1]}';
      final right = '${e.day}. ${months[e.month - 1]}';
      return '$left – $right';
    }
    final query = buildQueryText();
    final date = buildDateText();
    // Push results as a full screen above the overlay so Back returns to KI-Suche
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(queryText: query, dateText: date, results: items),
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _aiCtrl.clear();
      _whatCtrl.clear();
      _whereCtrl.clear();
      _pickup = null;
      _return = null;
      _priceMin = null;
      _priceMax = null;
      _categoryFilter = null;
    });
    _hideWhatOverlay();
    _hideWhereOverlay();
    // Reset suggestions to defaults near user's city
    _recomputeNearbySuggestions();
  }

  Size? _sizeOf(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final render = ctx.findRenderObject();
    if (render is RenderBox) return render.size;
    return null;
  }

  void _updateWhatOverlay() {
    if (!mounted) return;
    if (!_whatFocus.hasFocus || _whatCtrl.text.isEmpty || _suggestions.isEmpty) {
      _hideWhatOverlay();
      return;
    }
    final overlay = Overlay.of(context);
    if (overlay == null) return;
    // We want the suggestions panel to span from the very left to the very right of the screen.
    // Therefore use the full screen width and horizontally shift the follower so its left aligns with the screen edge.
    final screenSize = MediaQuery.of(context).size;
    final fullWidth = screenSize.width;
    // Compute available height to the bottom so the panel can stretch "bis ganz unten".
    double maxHeight = 320;
    double horizontalShift = 0; // negative dx of field to align left edge to screen
    try {
      final box = _whatFieldKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final fieldSize = box.size;
        final fieldOffset = box.localToGlobal(Offset.zero);
        final panelTop = fieldOffset.dy + fieldSize.height + 8; // follower offset
        final screenH = MediaQuery.of(context).size.height;
        final bottomPad = MediaQuery.of(context).padding.bottom + 16;
        maxHeight = (screenH - panelTop - bottomPad).clamp(120.0, 600.0);
        horizontalShift = -fieldOffset.dx; // move panel to screen's left edge
      }
    } catch (_) {
      // keep default
    }
    if (_whatOverlay == null) {
      _whatOverlay = OverlayEntry(builder: (ctx) {
        return CompositedTransformFollower(
          link: _whatLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: Offset(horizontalShift, 8),
          child: _FloatingSuggestionsPanel(
            width: fullWidth,
            panelMaxHeight: maxHeight,
            icon: Icons.search,
            query: _whatCtrl.text,
            suggestions: _suggestions,
            onTap: (s) async {
              setState(() => _whatCtrl.text = s);
              _whatCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _whatCtrl.text.length));
              _addToRecentWhat(s);
              _hideWhatOverlay();
              _whatFocus.unfocus();
              await _recomputeNearbySuggestions();
            },
            onClose: _hideWhatOverlay,
          ),
        );
      });
      overlay.insert(_whatOverlay!);
    } else {
      _whatOverlay!.markNeedsBuild();
    }
  }

  void _hideWhatOverlay() {
    _whatOverlay?.remove();
    _whatOverlay = null;
  }

  void _updateWhereOverlay() {
    if (!mounted) return;
    if (!_whereFocus.hasFocus || _whereCtrl.text.isEmpty || _locSuggestions.isNotEmpty == false) {
      _hideWhereOverlay();
      return;
    }
    final overlay = Overlay.of(context);
    if (overlay == null) return;
    // Full-width suggestions panel for the location field as well
    final screenSize = MediaQuery.of(context).size;
    final fullWidth = screenSize.width;
    // Compute dynamic maxHeight to allow suggestions down to the screen bottom
    double maxHeight = 320;
    double horizontalShift = 0;
    try {
      final box = _whereFieldKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final fieldSize = box.size;
        final fieldOffset = box.localToGlobal(Offset.zero);
        final panelTop = fieldOffset.dy + fieldSize.height + 8;
        final screenH = MediaQuery.of(context).size.height;
        final bottomPad = MediaQuery.of(context).padding.bottom + 16;
        maxHeight = (screenH - panelTop - bottomPad).clamp(120.0, 700.0);
        horizontalShift = -fieldOffset.dx;
      }
    } catch (_) {}
    if (_whereOverlay == null) {
      _whereOverlay = OverlayEntry(builder: (ctx) {
        return CompositedTransformFollower(
          link: _whereLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: Offset(horizontalShift, 8),
          child: _FloatingSuggestionsPanel(
            width: fullWidth,
            panelMaxHeight: maxHeight,
            icon: Icons.place_outlined,
            query: _whereCtrl.text,
            suggestions: _locSuggestions,
            onTap: (s) async {
              setState(() => _whereCtrl.text = s);
              _whereCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _whereCtrl.text.length));
              _hideWhereOverlay();
              _whereFocus.unfocus();
              await _recomputeNearbySuggestions();
            },
            onClose: _hideWhereOverlay,
          ),
        );
      });
      overlay.insert(_whereOverlay!);
    } else {
      _whereOverlay!.markNeedsBuild();
    }
  }

  void _hideWhereOverlay() {
    _whereOverlay?.remove();
    _whereOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    Widget _offsetOnSuggest({required Widget child, required bool active}) {
      // 0.5 mm ~ ~2 logical px. Apply subtle upward shift when suggestions are visible.
      final dy = active ? -2.0 : 0.0;
      return AnimatedSlide(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        offset: Offset(0, dy / 56.0), // normalize against field height for consistency
        child: child,
      );
    }

    final header = Column(children: [
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
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
      ),
      const SizedBox(height: 4),
      Center(child: Text('Suche', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.white))),
      const SizedBox(height: 8),
    ]);

    final scroller = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // KI-Suche Feld (ganz oben)
        Container(
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primary.withValues(alpha: 0.25)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.auto_awesome, color: primary, size: 16),
                const SizedBox(width: 6),
                Text('KI-Suche', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primary)),
              ]),
              const SizedBox(height: 6),
              TextField(
                controller: _aiCtrl,
                focusNode: _aiFocus,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 2,
                minLines: 1,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                   hintText: 'z. B. „Bohrmaschine in Berlin ab heute für 3 Tage“',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                ),
                onChanged: (v) {
                  _parseAIPrompt(v);
                },
                onSubmitted: (v) {
                  _parseAIPrompt(v);
                  _aiFocus.unfocus();
                },
              ),
              // Beispieltext entfernt – bewusst minimaler Platz unter dem Feld
            ],
          ),
        ),
        const SizedBox(height: 10),
        _offsetOnSuggest(
          active: _whatOverlay != null,
          child: CompositedTransformTarget(
            link: _whatLink,
            child: _FieldShell(
              key: _whatFieldKey,
              label: 'Was',
              trailingIcon: Icons.widgets_outlined,
              child: TextField(
              controller: _whatCtrl,
              focusNode: _whatFocus,
              onChanged: _onQueryChangedWhat,
              onSubmitted: (v) => _addToRecentWhat(v),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlignVertical: TextAlignVertical.center,
              maxLines: 1,
              minLines: 1,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'Was möchtest du ausleihen?',
                hintStyle: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _offsetOnSuggest(
          active: _whereOverlay != null,
          child: CompositedTransformTarget(
            link: _whereLink,
            child: _FieldShell(
              key: _whereFieldKey,
              label: 'Wo',
              trailingIcon: Icons.place_outlined,
              child: TextField(
              controller: _whereCtrl,
              focusNode: _whereFocus,
              onChanged: _onQueryChangedWhere,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlignVertical: TextAlignVertical.center,
              maxLines: 1,
              minLines: 1,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'Ort oder Adresse',
                hintStyle: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _FieldShell(
          label: 'Wann',
          trailingIcon: Icons.event_available_rounded,
          child: InkWell(
            onTap: () async { await _openDateTimeFlow(); await _recomputeNearbySuggestions(); },
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 56,
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      (_pickup == null || _return == null)
                          ? 'Datum wählen'
                          : '${_fmt(_pickup)} → ${_fmt(_return)}',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Show active filters from AI
        if (_priceMin != null || _priceMax != null || _categoryFilter != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              if (_priceMin != null)
                Chip(
                  label: Text('Ab ${_priceMin!.toStringAsFixed(0)}€', style: const TextStyle(fontSize: 11)),
                  onDeleted: () => setState(() => _priceMin = null),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                ),
              if (_priceMax != null)
                Chip(
                  label: Text('Bis ${_priceMax!.toStringAsFixed(0)}€', style: const TextStyle(fontSize: 11)),
                  onDeleted: () => setState(() => _priceMax = null),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                ),
              if (_categoryFilter != null)
                Chip(
                  label: Text(_categoryFilter!, style: const TextStyle(fontSize: 11)),
                  onDeleted: () => setState(() => _categoryFilter = null),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                ),
            ]),
          ),
        // "Zuletzt gesucht" Abschnitt entfernt
        const SizedBox(height: 12),
        Text('Vorschläge in der Nähe', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 8),
        (_loading || _recomputing)
            ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
            : (_displayNearby.isEmpty
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Keine passenden Vorschläge', style: TextStyle(color: Colors.white70, fontSize: 12)))
                : LayoutBuilder(builder: (context, constraints) {
                    // Grid: 3 Anzeigen pro Zeile, 5 Zeilen max (=> bis zu 15 Items)
                    final itemCount = _displayNearby.length > 15 ? 15 : _displayNearby.length;
                    const crossAxisCount = 3;
                    const spacing = 10.0;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        childAspectRatio: 1,
                      ),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        final it = _displayNearby[index];
                        final ownerVerified = _verifiedOwnerIds.contains(it.ownerId);
                        final owner = _usersById[it.ownerId];
                        return _MiniItem(
                          item: it,
                          ownerVerified: ownerVerified,
                          rating: 0,
                          reviews: 0,
                          onTap: () => ItemDetailsOverlay.showFullPage(context, item: it, owner: owner),
                        );
                      },
                    );
                  })),
        const SizedBox(height: 0),
      ]),
    );

    final bottomBar = SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(children: [
          Expanded(child: OutlinedButton(onPressed: _clearAll, style: OutlinedButton.styleFrom(foregroundColor: Colors.white), child: const Text('Alles löschen'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton(onPressed: _openResults, child: const Text('Suchen'))),
        ]),
      ),
    );

    final content = SafeArea(
      top: true,
      bottom: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        Expanded(child: scroller),
        bottomBar,
      ]),
    );

    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.34), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: content,
    );
  }
}

class _FieldShell extends StatelessWidget {
  final String label; 
  final Widget child;
  final IconData? trailingIcon;
  const _FieldShell({Key? key, required this.label, required this.child, this.trailingIcon}) : super(key: key);
  static const double _labelWidth = 64; // ensures first letters align vertically
  static const double _iconSlotWidth = 28; // fixed slot for icon alignment
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Leading label with fixed width so first letters align
          SizedBox(
            width: _labelWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Field/content area
          Expanded(
            child: SizedBox(
              height: 56,
              child: Align(
                alignment: Alignment.centerLeft,
                child: child,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Trailing icon slot so text ends exactly before the icon
          SizedBox(
            width: _iconSlotWidth,
            child: trailingIcon == null
                ? const SizedBox.shrink()
                : Center(child: Icon(trailingIcon, size: 20, color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _InnerFieldShell extends StatelessWidget {
  final String label; final Widget child;
  const _InnerFieldShell({Key? key, required this.label, required this.child}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        child,
      ]),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const _PickerButton({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: Row(children: [
      Icon(icon, size: 18, color: Colors.white),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis)),
    ])));
  }
}

class _MiniItem extends StatelessWidget {
  final Item item;
  final bool ownerVerified;
  final double rating;
  final int reviews;
  final VoidCallback? onTap;
  const _MiniItem({required this.item, required this.ownerVerified, required this.rating, required this.reviews, this.onTap});
  @override
  Widget build(BuildContext context) {
    final bool isVerified = ownerVerified;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.32), border: Border.all(color: Colors.white.withValues(alpha: 0.08)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 6))]),
          child: Stack(children: [
            Positioned.fill(child: AppImage(url: item.photos.isNotEmpty ? item.photos.first : '', fit: BoxFit.cover)),
            // Verification badge moved to top-right and reduced to half size
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: isVerified ? const Color(0xFF22C55E) : Colors.grey, shape: BoxShape.circle),
                child: Icon(isVerified ? Icons.verified : Icons.verified_outlined, size: 8, color: Colors.white),
              ),
            ),
              // Title overlay at the bottom for better discoverability
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.20),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      // Slightly increased (~+1/6 of original ~11.5 => ~9.6)
                      fontSize: 9.6,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  final Item item;
  final bool verified;
  final VoidCallback? onTap;
  const _NearbyCard({required this.item, required this.verified, this.onTap});

  String _shorten(String s, {int max = 26}) {
    if (s.length <= max) return s;
    // Try to cut on word boundary before max; else hard cut
    final cut = s.substring(0, max);
    final lastSpace = cut.lastIndexOf(' ');
    final base = lastSpace > 12 ? cut.substring(0, lastSpace) : cut;
    return '$base…';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Image 4:3
            AspectRatio(aspectRatio: 4 / 3, child: AppImage(url: item.photos.isNotEmpty ? item.photos.first : '', fit: BoxFit.cover)),
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(children: [
                Expanded(child: Text(_shorten(item.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle)),
                if (verified)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.45)),
                    ),
                    child: const Center(child: Icon(Icons.verified, size: 10, color: Colors.white)),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MapResultsOverlay extends StatelessWidget {
  final List<Item> items;
  const _MapResultsOverlay({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Karte', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final minLat = items.isEmpty ? 0.0 : items.map((e) => e.lat).reduce(min);
        final maxLat = items.isEmpty ? 1.0 : items.map((e) => e.lat).reduce(max);
        final minLng = items.isEmpty ? 0.0 : items.map((e) => e.lng).reduce(min);
        final maxLng = items.isEmpty ? 1.0 : items.map((e) => e.lng).reduce(max);
        final pad = 24.0;
        return Stack(children: [
          // Simple decorative "map" background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B1223), Color(0xFF0F1A34)],
              ),
            ),
          ),
          CustomPaint(
            painter: _GridPainter(color: Colors.white.withValues(alpha: 0.06)),
            size: Size.infinite,
          ),
          ...List.generate(items.length, (i) {
            final it = items[i];
            final nx = (maxLng - minLng).abs() < 1e-6 ? 0.5 : (it.lng - minLng) / ((maxLng - minLng).abs());
            final ny = (maxLat - minLat).abs() < 1e-6 ? 0.5 : 1 - (it.lat - minLat) / ((maxLat - minLat).abs());
            final left = pad + nx * (constraints.maxWidth - 2 * pad);
            final top = pad + ny * (constraints.maxHeight - 2 * pad);
            final price = it.pricePerDay.toStringAsFixed(0);
            final symbol = (it.currency == 'EUR') ? '€' : (it.currency == 'USD') ? r'$' : '€';
            return Positioned(
              left: left - 30,
              top: top - 18,
              child: _PriceMarker(text: '$price$symbol'),
            );
          }),
        ]);
      }),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

class _PriceMarker extends StatelessWidget {
  final String text;
  const _PriceMarker({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.lightBlueAccent, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.place, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _SuggestionsPanel extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onTap;
  final IconData? icon;
  const _SuggestionsPanel({required this.suggestions, required this.onTap, this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
        itemBuilder: (context, i) => ListTile(
          dense: true,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          leading: Icon(icon ?? Icons.search, color: Colors.white70, size: 18),
          title: Text(suggestions[i], style: const TextStyle(color: Colors.white, fontSize: 13)),
          onTap: () => onTap(suggestions[i]),
        ),
      ),
    );
  }
}

class _FloatingSuggestionsPanel extends StatelessWidget {
  final double width;
  final double? panelMaxHeight;
  final List<String> suggestions;
  final void Function(String) onTap;
  final VoidCallback? onClose;
  final IconData icon;
  final String query;
  const _FloatingSuggestionsPanel({
    required this.width,
    required this.suggestions,
    required this.onTap,
    required this.icon,
    required this.query,
    this.onClose,
    this.panelMaxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Blur the content behind this panel so underlying text is not readable.
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(color: Colors.black.withValues(alpha: 0.45)),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: max(180.0, (panelMaxHeight ?? 260))),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: suggestions.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                    itemBuilder: (context, i) {
                      final s = suggestions[i];
                      return InkWell(
                        onTap: () => onTap(s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: Row(children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.18), shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.35))),
                              child: Icon(icon, size: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: _Highlighted(query: query, text: s)),
                          ]),
                        ),
                      );
                    },
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

class _Highlighted extends StatelessWidget {
  final String query;
  final String text;
  const _Highlighted({required this.query, required this.text});

  @override
  Widget build(BuildContext context) {
    final q = query.trim();
    if (q.isEmpty) return Text(text, style: const TextStyle(color: Colors.white, fontSize: 13));
    final lower = text.toLowerCase();
    final idx = lower.indexOf(q.toLowerCase());
    if (idx < 0) return Text(text, style: const TextStyle(color: Colors.white, fontSize: 13));
    final before = text.substring(0, idx);
    final match = text.substring(idx, idx + q.length);
    final after = text.substring(idx + q.length);
    return RichText(
      text: TextSpan(children: [
        TextSpan(text: before, style: const TextStyle(color: Colors.white, fontSize: 13)),
        TextSpan(text: match, style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w700, fontSize: 13)),
        TextSpan(text: after, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ]),
      overflow: TextOverflow.ellipsis,
    );
  }
}
