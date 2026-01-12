import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/category.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/navigation/main_navigation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/utils/category_label.dart';
import 'package:lendify/services/ai_price_calculator_service.dart';
import 'package:lendify/openai/openai_config.dart';
import 'package:lendify/utils/cancellation_policy_text.dart';
import 'package:lendify/widgets/selection_controls.dart';

// Google Maps Places API key (configure in Dreamflow as environment variable)
const String kGoogleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

class CreateListingScreen extends StatefulWidget {
  final Item? existing; // when provided -> edit mode
  const CreateListingScreen({super.key, this.existing});
  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic fields
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();

  // Photos
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _pickedImages = [];
  // For edit mode: keep previously saved photos (non-removable for now)
  List<String> _existingPhotos = [];

  // Dropdowns / switches
  List<Category> _categories = [];
  String? _categoryId;
  // Coarse/top-level categories for selection UI
  List<String> _coarseCats = [];
  // Map coarse label -> fine categories in that group
  Map<String, List<Category>> _catsByCoarse = {};
  String _priceUnit = 'day'; // only 'day' is supported in UI
  String _condition = 'new'; // 'new' | 'like-new' | 'good' | 'acceptable'
  // Delivery options
  bool _offersDeliveryAtDropoff = false; // Lieferung bei Abgabe (Hinweg)
  bool _offersPickupAtReturn = false;    // Abholung bei Rückgabe (Rückweg)
  bool _offersExpressAtDropoff = false;  // Deprecated: Prioritäts-/Expresslieferung (nicht mehr angeboten)
  double? _maxDistanceKm; // applies to both delivery and pickup (simple model)
  // Master toggle for Liefer- & Abholoptionen (default disabled like requested)
  bool _deliveryOptionsEnabled = false;
  // Cancellation policy
  String _cancellationPolicy = 'flexible'; // 'flexible' | 'moderate' | 'strict'
 
  // Location (only address mode now)
  final TextEditingController _addressCtrl = TextEditingController();
  String? _registeredCity;
  double? _selectedAddrLat;
  double? _selectedAddrLng;
  bool get _isEdit => widget.existing != null;

  // Google Places API (Autocomplete)
  // resolved at runtime via env
  static const String _gmapsKey = kGoogleMapsApiKey;
  Timer? _debounce;
  List<_PlaceSuggestion> _addrSuggestions = const [];

  // AI Price Calculator
  PriceSuggestion? _priceSuggestion;
  String _priceStrategy = 'quick'; // 'quick' | 'premium'
  bool _hasCalculatedPrice = false;
  // Stable market-price truth (independent of mode)
  double? _marketPriceMin;
  double? _marketPriceMax;
  // Debounce for live AI recalculation
  Timer? _priceRecalcDebounce;
  // Long-term discount state (threshold-based: Ab X Tagen -> Y%)
  bool _autoApplyDiscounts = true; // acts as "Preisnachlass aktivieren"
  int _tier1Days = 3;
  double _tier1Pct = 10;
  int _tier2Days = 5;
  double _tier2Pct = 20;
  int _tier3Days = 8;
  double _tier3Pct = 30;
  bool _hasCalculatedDiscounts = false;
  bool _discountsTouched = false; // if user edits any tier, avoid overwriting with AI
  // If user manually edits the price, we stop all auto-adjustments
  bool _priceTouched = false;
  // Track whether any % input fields are currently empty so we can restore on mode toggle
  bool _tier1PctEmpty = false;
  bool _tier2PctEmpty = false;
  bool _tier3PctEmpty = false;
  // Force-refresh discount rows when switching strategy so focused inputs also update
  int _strategyEpoch = 0;

  @override
  void initState() {
    super.initState();
    _load();
    // Prefill when editing
    final ex = widget.existing;
    if (ex != null) {
      _titleCtrl.text = ex.title;
      _descCtrl.text = ex.description;
      _priceCtrl.text = ex.priceRaw.toStringAsFixed(ex.priceRaw.truncateToDouble() == ex.priceRaw ? 0 : 2);
      _categoryId = ex.categoryId;
      _priceUnit = ex.priceUnit;
      // Enforce day-only pricing unit in UI
      if (_priceUnit != 'day') {
        _priceUnit = 'day';
      }
      _condition = ex.condition;
      _offersDeliveryAtDropoff = ex.offersDeliveryAtDropoff;
      _offersPickupAtReturn = ex.offersPickupAtReturn;
      // Deprecated: no longer used, UI removed
      _offersExpressAtDropoff = false;
      _maxDistanceKm = ex.maxDeliveryKmAtDropoff ?? ex.maxPickupKmAtReturn;
      // Enable the section by default in edit mode only if any option had been set before
      _deliveryOptionsEnabled = _offersDeliveryAtDropoff || _offersPickupAtReturn || (_maxDistanceKm != null);
      _registeredCity = ex.city;
      _addressCtrl.text = ex.locationText;
      _selectedAddrLat = ex.lat;
      _selectedAddrLng = ex.lng;
      _existingPhotos = List<String>.from(ex.photos);
      _cancellationPolicy = ex.cancellationPolicy;
      // Prefill discount tiers: map first three thresholds ascending
      _autoApplyDiscounts = ex.autoApplyDiscounts;
      if (ex.longRentalDiscounts.isNotEmpty) {
        final tiers = [...ex.longRentalDiscounts]..sort((a, b) => a.days.compareTo(b.days));
        if (tiers.length >= 1) { _tier1Days = tiers[0].days; _tier1Pct = tiers[0].discountPercent; }
        if (tiers.length >= 2) { _tier2Days = tiers[1].days; _tier2Pct = tiers[1].discountPercent; }
        if (tiers.length >= 3) { _tier3Days = tiers[2].days; _tier3Pct = tiers[2].discountPercent; }
      }
    }
  }

  Future<void> _load() async {
    final cats = await DataService.getCategories();
    final user = await DataService.getCurrentUser();
    // Build coarse/top-level groups in fixed order, limited to those present
    final present = <String>{
      for (final c in cats) DataService.coarseCategoryFor(c.name)
    };
    final ordered = [
      for (final g in DataService.coarseCategoryOrder)
        if (present.contains(g)) g
    ];
    // Group fine categories by their coarse label
    final byCoarse = <String, List<Category>>{};
    for (final c in cats) {
      final g = DataService.coarseCategoryFor(c.name);
      (byCoarse[g] ??= <Category>[]).add(c);
    }
    setState(() {
      _categories = cats;
      _categoryId = cats.isNotEmpty ? (widget.existing?.categoryId ?? cats.first.id) : null;
      _coarseCats = ordered.isNotEmpty ? ordered : DataService.coarseCategoryOrder;
      _catsByCoarse = byCoarse;
      _registeredCity = user?.city ?? DataService.getCities().keys.first;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _addressCtrl.dispose();
    _debounce?.cancel();
    _priceRecalcDebounce?.cancel();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    // Always prefer camera when explicitly chosen, including on Web.
    // On Web, image_picker's web implementation may open a file dialog,
    // but on supported devices it can trigger camera capture.
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file != null) setState(() => _pickedImages.add(file));
    } catch (e) {
      // Keep experience consistent: avoid auto-switching to gallery on Web.
      // Some browsers will still show a file dialog even for ImageSource.camera.
      debugPrint('Camera pick failed or blocked: ' + e.toString());
    }
  }

  Future<void> _pickFromGallery() async {
    if (kIsWeb) {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.image,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() => _pickedImages.addAll(res.files.where((f) => f.bytes != null).map((f) => XFile.fromData(f.bytes!, name: f.name))));
      }
      return;
    }
    final List<XFile> files = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1600);
    if (files.isNotEmpty) setState(() => _pickedImages.addAll(files));
  }

  void _showPhotoSourceSheet() {
    // Centered popup for picking photos
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black.withValues(alpha: 0.90),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_camera, color: Colors.white),
                    title: const Text('Mit Kamera aufnehmen', style: TextStyle(color: Colors.white)),
                    onTap: () async {
                      Navigator.of(context).maybePop();
                      await _pickFromCamera();
                    },
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  ListTile(
                    leading: const Icon(Icons.photo_library, color: Colors.white),
                    title: const Text('Aus Galerie auswählen', style: TextStyle(color: Colors.white)),
                    onTap: () async {
                      Navigator.of(context).maybePop();
                      await _pickFromGallery();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

    String _inferMimeFromName(String name) {
      final lower = name.toLowerCase();
      if (lower.endsWith('.png')) return 'image/png';
      if (lower.endsWith('.webp')) return 'image/webp';
      if (lower.endsWith('.gif')) return 'image/gif';
      if (lower.endsWith('.bmp')) return 'image/bmp';
      if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
      return 'image/jpeg';
    }

  Future<void> _submit({bool forceInactive = false}) async {
    if (!_formKey.currentState!.validate()) {
      if (mounted) {
        await AppPopup.show(
          context,
          icon: Icons.info_outline,
          title: 'Bitte Felder prüfen',
          message: 'Einige Pflichtfelder sind noch unvollständig. Bitte fülle die markierten Felder aus.',
          plainCloseIcon: true,
        );
      }
      return;
    }

    final user = await DataService.getCurrentUser();
    if (user == null) {
      if (!mounted) return;
      await AppPopup.toast(context, icon: Icons.login, title: 'Bitte zuerst anmelden');
      return;
    }

    final allCities = DataService.getCities();
    String city = _registeredCity ?? allCities.keys.first;
    (double, double) pos = allCities[city] ?? (52.52, 13.405);

    // Always use address mode now
    String locationText = _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : 'Adresse';
    if (_selectedAddrLat != null && _selectedAddrLng != null) {
      pos = (_selectedAddrLat!, _selectedAddrLng!);
    }
    // Try to derive city name from the typed address; fall back to registered city
    final derived = DataService.deriveCityFromAddress(locationText);
    if (derived.isNotEmpty) city = derived;

    final raw = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
    double pricePerDay;
    switch (_priceUnit) {
      case 'week': pricePerDay = raw / 7; break;
      case 'day':
      default: pricePerDay = raw; break;
    }

    // Persist actual uploaded images. For web, store as data: URLs. For mobile, we also
    // store as data: URLs to keep things simple and fully offline.
    // Build photos from existing (edit) and newly picked images
    final List<String> photos = List<String>.from(_existingPhotos);
    if (_pickedImages.isNotEmpty) {
      for (final f in _pickedImages) {
        try {
          final bytes = await f.readAsBytes();
          final b64 = base64Encode(bytes);
          final mime = _inferMimeFromName(f.name);
          photos.add('data:' + mime + ';base64,' + b64);
        } catch (_) { /* skip */ }
      }
    }
    if (photos.isEmpty) {
      photos.add('https://picsum.photos/seed/new_listing_' + DateTime.now().millisecondsSinceEpoch.toString() + '/800/800');
    }

    if (!_isEdit) {
      final item = Item(
        id: 'new',
        ownerId: user.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        categoryId: _categoryId ?? (_categories.isNotEmpty ? _categories.first.id : 'cat1'),
        subcategory: '-',
        tags: const <String>[],
        pricePerDay: pricePerDay,
        currency: 'EUR',
        priceUnit: _priceUnit,
        priceRaw: raw,
        deposit: null,
        photos: photos,
        locationText: locationText,
        lat: pos.$1,
        lng: pos.$2,
        geohash: 'u${DateTime.now().millisecondsSinceEpoch}',
        condition: _condition,
        minDays: null,
        maxDays: null,
        createdAt: DateTime.now(),
        isActive: forceInactive ? false : true,
        verificationStatus: 'pending',
        city: city,
        country: 'Deutschland',
        status: forceInactive ? 'draft' : 'active',
        offersDeliveryAtDropoff: _offersDeliveryAtDropoff,
        offersPickupAtReturn: _offersPickupAtReturn,
        offersExpressAtDropoff: false, // deprecated option removed from UI
        maxDeliveryKmAtDropoff: _maxDistanceKm,
        maxPickupKmAtReturn: _maxDistanceKm,
        cancellationPolicy: 'unified',
        autoApplyDiscounts: _autoApplyDiscounts,
        longRentalDiscounts: ([
          LongRentalDiscount(days: _tier1Days, discountPercent: _tier1Pct),
          LongRentalDiscount(days: _tier2Days, discountPercent: _tier2Pct),
          LongRentalDiscount(days: _tier3Days, discountPercent: _tier3Pct),
        ]..sort((a, b) => a.days.compareTo(b.days))),
      );

      final saved = await DataService.addItem(item);
      if (!mounted) return;
      DataService.setLastCreateEvent(saved, draft: forceInactive);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (route) => false,
      );
      return;
    }

    // Edit flow: update existing item in place
    final ex = widget.existing!;
    final updated = Item(
      id: ex.id,
      ownerId: ex.ownerId,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      categoryId: _categoryId ?? ex.categoryId,
      subcategory: ex.subcategory,
      tags: ex.tags,
      pricePerDay: pricePerDay,
      currency: ex.currency,
      priceUnit: _priceUnit,
      priceRaw: raw,
      deposit: null,
      photos: photos,
      locationText: locationText,
      lat: pos.$1,
      lng: pos.$2,
      geohash: ex.geohash,
      condition: _condition,
      minDays: ex.minDays,
      maxDays: ex.maxDays,
      createdAt: ex.createdAt,
      isActive: !forceInactive,
      verificationStatus: ex.verificationStatus,
      city: city,
      country: ex.country,
      status: forceInactive ? 'draft' : 'active',
      endedAt: forceInactive ? null : ex.endedAt,
      timesLent: ex.timesLent,
      offersDeliveryAtDropoff: _offersDeliveryAtDropoff,
      offersPickupAtReturn: _offersPickupAtReturn,
      offersExpressAtDropoff: false, // deprecated option removed from UI
      maxDeliveryKmAtDropoff: _maxDistanceKm,
      maxPickupKmAtReturn: _maxDistanceKm,
      cancellationPolicy: 'unified',
      autoApplyDiscounts: _autoApplyDiscounts,
      longRentalDiscounts: ([
        LongRentalDiscount(days: _tier1Days, discountPercent: _tier1Pct),
        LongRentalDiscount(days: _tier2Days, discountPercent: _tier2Pct),
        LongRentalDiscount(days: _tier3Days, discountPercent: _tier3Pct),
      ]..sort((a, b) => a.days.compareTo(b.days))),
    );

    await DataService.updateItem(updated);
    if (!mounted) return;
    if (forceInactive) {
      // Save edits only: return to "Meine Anzeigen" → drafts.
      // We intentionally do NOT show a toast here because popping immediately after
      // opening a dialog would just close the dialog. The caller screen will
      // display the confirmation toast after navigation.
      Navigator.of(context).pop('drafts');
    } else {
      // Publish and show the same popup in Explore
      DataService.setLastCreateEvent(updated, draft: false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (route) => false,
      );
    }
  }

  // --- Address Autocomplete: debounced query ---
  void _onAddressQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      if (_gmapsKey.isEmpty) {
        setState(() => _addrSuggestions = const []);
        return;
      }
      if (q.trim().isEmpty) {
        setState(() => _addrSuggestions = const []);
        return;
      }
      final results = await _fetchAutocomplete(q);
      if (!mounted) return;
      setState(() => _addrSuggestions = results);
    });
  }

  void _schedulePriceRecalc() {
    _priceRecalcDebounce?.cancel();
    _priceRecalcDebounce = Timer(const Duration(milliseconds: 450), () async {
      await _calculatePriceSuggestion();
      if (!_discountsTouched) {
        _applyModeDiscountPreset();
      }
    });
  }

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

  // Coarse/top-level category icon mapping (keep in sync with filters overlay)
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

  String _currentCoarseLabel() {
    if (_categoryId == null || _categories.isEmpty) return 'Kategorie';
    final fine = _categories.firstWhere(
      (c) => c.id == _categoryId,
      orElse: () => _categories.first,
    );
    return DataService.coarseCategoryFor(fine.name);
  }

  Future<void> _pickCategory() async {
    if (_coarseCats.isEmpty) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (context) {
        return Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Stack(children: [
              // Dismiss when tapping outside the category grid
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
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.34), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 12),
                      Text('Kategorie wählen', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      LayoutBuilder(builder: (context, c) {
                        const crossAxisCount = 4;
                        const spacing = 12.0;
                        // Slightly taller tiles so second line (e.g., "& Kleingeräte") is fully visible
                        // Make tiles a bit taller so long labels like "& Kleingeräte" fit on line 2
                        const aspect = 0.68;
                        final totalWidth = c.maxWidth;
                        final tileWidth = (totalWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
                        final tileHeight = tileWidth / aspect;
                        final rows = (_coarseCats.length / crossAxisCount).ceil();
                        final gridHeight = rows * tileHeight + (rows - 1) * spacing;
                        return SizedBox(
                          height: gridHeight,
                          child: GridView.builder(
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: spacing, mainAxisSpacing: spacing, childAspectRatio: aspect),
                            itemCount: _coarseCats.length,
                            itemBuilder: (context, index) {
                              final label = _coarseCats[index];
                              final active = _currentCoarseLabel() == label;
                              return InkWell(
                                onTap: () => Navigator.of(context).pop(label),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: active ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: active ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.16)),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Icon(_coarseIconForGroup(label), color: active ? Colors.black : Colors.white, size: 24),
                                    const SizedBox(height: 6),
                                    Text(
                                      stackCategoryLabel(label),
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
                          ),
                        );
                      })
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        );
      }
    );
    if (selected != null) {
      // Map back from coarse label to a representative fine category id (first in group)
      final list = _catsByCoarse[selected] ?? const <Category>[];
      if (list.isNotEmpty) {
        setState(() => _categoryId = list.first.id);
        _schedulePriceRecalc();
      }
    }
  }

  Future<void> _calculatePriceSuggestion() async {
    // Only calculate if all required fields are filled
    if (_titleCtrl.text.trim().isEmpty || _categoryId == null || _addressCtrl.text.trim().isEmpty) {
      return;
    }
    
    // Get category name
    final cat = _categories.firstWhere((c) => c.id == _categoryId, orElse: () => _categories.first);
    final categoryName = DataService.coarseCategoryFor(cat.name);
    
    // Use ChatGPT for intelligent price suggestion
    final result = await OpenAIConfig.suggestPrice(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: categoryName,
      condition: _condition,
      location: _addressCtrl.text.trim(),
    );
    
    setState(() {
      // Be defensive: values may come back as int on web → cast via num
      final dailyPrice = (result['dailyPrice'] as num).toDouble();
      final weeklyPrice = (result['weeklyPrice'] as num).toDouble();
      final reasoning = (result['reasoning'] as String);

      // IMPORTANT: One market-price truth (independent of mode)
      final mMin = (dailyPrice * 0.9);
      final mMax = (dailyPrice * 1.1);
      _marketPriceMin = mMin;
      _marketPriceMax = mMax;

      _priceSuggestion = PriceSuggestion(
        dailyPriceMin: mMin,
        dailyPriceMax: mMax,
        weeklyPriceMin: weeklyPrice * 0.9,
        weeklyPriceMax: weeklyPrice * 1.1,
        reasoning: reasoning,
        // Keep messaging neutral and factual – no % promises
        optimizationTip: 'Richte den Preis an der Marktspanne aus und nutze Rabatte sinnvoll.',
      );
      _hasCalculatedPrice = true;
    });

    // Auto-fill the price field based on selected mode unless user has manually edited
    if (!_priceTouched) {
      _autofillPriceFromMarket();
    }

    // Also set discount presets based on mode unless manually edited
    if (!_hasCalculatedDiscounts || !_discountsTouched) {
      _applyModeDiscountPreset();
    }
  }

  // Apply fixed, mode-based discount presets unless user touched them
  void _applyModeDiscountPreset({bool force = false}) {
    if (_discountsTouched && !force) return;
    setState(() {
      if (_priceStrategy == 'quick') {
        // Schnell vermieten – aggressive Rabatte
        _tier1Days = 3; _tier1Pct = 15;
        _tier2Days = 5; _tier2Pct = 25;
        _tier3Days = 8; _tier3Pct = 35;
      } else {
        // Maximaler Gewinn – moderate Rabatte
        _tier1Days = 3; _tier1Pct = 8;
        _tier2Days = 5; _tier2Pct = 15;
        _tier3Days = 8; _tier3Pct = 25;
      }
      _hasCalculatedDiscounts = true;
      // After presetting, consider inputs no longer empty
      _tier1PctEmpty = false;
      _tier2PctEmpty = false;
      _tier3PctEmpty = false;
    });
  }

  // Compute price from market range according to current mode
  void _autofillPriceFromMarket() {
    final min = _marketPriceMin;
    final max = _marketPriceMax;
    if (min == null || max == null) return;
    // Small offset to avoid exact boundary numbers
    const double offset = 1.0;
    double price = _priceStrategy == 'quick' ? (min + offset) : (max - offset);
    // Clamp to [min, max]
    if (price < min) price = min;
    if (price > max) price = max;
    _priceCtrl.text = price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Auto-calculate price suggestion when all required fields are filled (only once)
    if (!_hasCalculatedPrice && _titleCtrl.text.trim().isNotEmpty && _categoryId != null && _addressCtrl.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculatePriceSuggestion());
    }
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Anzeige bearbeiten' : 'Neue Anzeige')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Theme(
            data: Theme.of(context).copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  filled: true,
                  fillColor: Color(0x1FFFFFFF),
                  labelStyle: TextStyle(color: Colors.white),
                  floatingLabelStyle: TextStyle(color: Colors.lightBlueAccent),
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  hintStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24), borderRadius: BorderRadius.all(Radius.circular(12))),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24), borderRadius: BorderRadius.all(Radius.circular(12))),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.lightBlueAccent), borderRadius: BorderRadius.all(Radius.circular(12))),
                  prefixStyle: TextStyle(color: Colors.white),
                ),
                dropdownMenuTheme: const DropdownMenuThemeData(menuStyle: MenuStyle(backgroundColor: MaterialStatePropertyAll(Color(0xE6000000))))
              ),
            child: Form(
              key: _formKey,
              child: Column(children: [
                _Section(
                  title: 'Kategorie',
                  leading: const Icon(Icons.widgets_outlined, color: Colors.lightBlueAccent, size: 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  InkWell(
                    onTap: _pickCategory,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(hintText: 'Kategorie wählen'),
                      child: Row(children: [
                        Icon(_coarseIconForGroup(_currentCoarseLabel()), color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            // In "Neue Anzeige" show the selected category on a single line
                            _currentCoarseLabel(),
                            style: const TextStyle(color: Colors.white),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      ]),
                    ),
                  )
                ])),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                _Section(
                  title: 'Details',
                  leading: const Icon(Icons.description_outlined, color: Colors.lightBlueAccent, size: 18),
                  child: Column(children: [
                  TextFormField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Titel', hintText: 'Was bietest du an?'),
                    onChanged: (_) => _schedulePriceRecalc(),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Titel ist erforderlich' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Beschreibung', hintText: 'Beschreibe Zustand, Zubehör, Abholung …'),
                    onChanged: (_) => _schedulePriceRecalc(),
                    validator: (v) => (v == null || v.trim().length < 10) ? 'Mindestens 10 Zeichen' : null,
                  ),
                ])),
                const SizedBox(height: 12),
                // Fotos kommt vor Zustand
                _Section(
                  title: 'Fotos',
                  leading: const Icon(Icons.photo_library_outlined, color: Colors.lightBlueAccent, size: 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Builder(builder: (context) {
                      final hasAnyPhotos = _existingPhotos.isNotEmpty || _pickedImages.isNotEmpty;
                      if (!hasAnyPhotos) {
                        // Center the + photo button horizontally (and give the card some height) when there are no images yet
                        return SizedBox(
                          height: 120,
                          child: Center(child: _AddPhotoTile(onTap: _showPhotoSourceSheet)),
                        );
                      }
                      // When there are photos, show the grid-like wrap (the + button stays inline)
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        runAlignment: WrapAlignment.center,
                        children: [
                          // Show existing photos (non-removable) when editing
                          if (_existingPhotos.isNotEmpty)
                            for (final url in _existingPhotos)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(width: 84, height: 84, child: AppImage(url: url, fit: BoxFit.cover)),
                              ),
                          for (int i = 0; i < _pickedImages.length; i++)
                            _PickedThumb(file: _pickedImages[i], onRemove: () => setState(() => _pickedImages.removeAt(i))),
                          _AddPhotoTile(onTap: _showPhotoSourceSheet),
                        ],
                      );
                    }),
                  const SizedBox(height: 6),
                  const Text('Füge Fotos hinzu. Tippe auf +, um Kamera oder Galerie zu wählen.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  _Accordion(
                    title: '💬 Tipp',
                    initiallyExpanded: false,
                    bare: true,
                    child: const Text(
                      'Hochwertige, klare Bilder erhöhen die Chance, dass deine Anzeige öfter gemietet wird.\n'
                      'Zeig den Artikel aus verschiedenen Winkeln – hell, scharf und komplett.',
                      style: TextStyle(color: Colors.white70, height: 1.45),
                    ),
                  ),
                ])),
                const SizedBox(height: 12),
                _Section(
                  title: 'Zustand',
                  leading: const Icon(Icons.workspace_premium_outlined, color: Colors.lightBlueAccent, size: 18),
                  child: _ConditionPager(
                    selected: _condition,
                    onChanged: (v) {
                      setState(() => _condition = v);
                      _schedulePriceRecalc();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _Section(
                  title: 'Adresse',
                  leading: const Icon(Icons.place_outlined, color: Colors.lightBlueAccent, size: 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _AddressAutocompleteField(
                    controller: _addressCtrl,
                    onPlaceChosen: (d) {
                      setState(() {
                        _addressCtrl.text = d.formattedAddress ?? d.description;
                        _selectedAddrLat = d.lat;
                        _selectedAddrLng = d.lng;
                      });
                      _schedulePriceRecalc();
                    },
                    onQueryChanged: (q) {
                      _onAddressQueryChanged(q);
                      _schedulePriceRecalc();
                    },
                    suggestions: _addrSuggestions,
                    apiKeyConfigured: _gmapsKey.isNotEmpty,
                  ),
                  if (_gmapsKey.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Adresse-Vorschläge benötigen einen Google Maps API Key. Bitte im Projekt als GOOGLE_MAPS_API_KEY konfigurieren.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  const SizedBox(height: 8),
                  _Accordion(
                    title: 'Datenschutz & Adresse',
                    initiallyExpanded: false,
                    bare: true,
                    child: const Text(
                      'Die genaue Adresse wird nur zur Berechnung der Entfernung genutzt und erst nach bestätigter Anfrage angezeigt, wenn der Mieter Selbstabholer ist.',
                      style: TextStyle(color: Colors.white70, height: 1.45),
                    ),
                  ),
                ])),
                const SizedBox(height: 12),
                _Section(
                  title: 'Liefer- & Abholoptionen',
                  leading: const Icon(Icons.local_shipping_outlined, color: Colors.lightBlueAccent, size: 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Activation switch like the Preisnachlass section (switch on the right)
                    SwitchListTile(
                      value: _deliveryOptionsEnabled,
                      onChanged: (v) => setState(() {
                        _deliveryOptionsEnabled = v;
                        if (!v) {
                          // Reset inner options when disabled to avoid accidental persistence
                          _offersDeliveryAtDropoff = false;
                          _offersPickupAtReturn = false;
                          _offersExpressAtDropoff = false;
                          _maxDistanceKm = null;
                        }
                      }),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _deliveryOptionsEnabled
                            ? 'Liefer- & Abholoptionen deaktivieren'
                            : 'Liefer- & Abholoptionen aktivieren',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    if (_deliveryOptionsEnabled) ...[
                      const SizedBox(height: 4),
                      ToggleTextOption(
                        label: 'Lieferung bei Abgabe anbieten',
                        selected: _offersDeliveryAtDropoff,
                        onTap: () => setState(() {
                          _offersDeliveryAtDropoff = !_offersDeliveryAtDropoff;
                          if (!_offersDeliveryAtDropoff) _offersExpressAtDropoff = false;
                        }),
                      ),
                      // Removed: Prioritätslieferung anbieten (no longer supported)
                      ToggleTextOption(
                        label: 'Abholung bei Rückgabe anbieten',
                        selected: _offersPickupAtReturn,
                        onTap: () => setState(() => _offersPickupAtReturn = !_offersPickupAtReturn),
                      ),
                      if (_offersDeliveryAtDropoff || _offersPickupAtReturn) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: _maxDistanceKm?.toStringAsFixed(1),
                          onChanged: (v) => _maxDistanceKm = double.tryParse(v.replaceAll(',', '.')),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Maximale Entfernung (einfache Fahrt) in km',
                            // Make the label more subtle/smaller when the field appears
                            labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                            floatingLabelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      const Text('Wenn nichts aktiviert ist, muss der Mieter selbst abholen und zurückbringen.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 8),
                      _Accordion(
                        title: 'Vergütung für Fahrtaufwand',
                        initiallyExpanded: false,
                        bare: true,
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Vergütung: 0,30 € pro tatsächlich zu fahrendem Kilometer (Hin- und Rückfahrt).', style: TextStyle(color: Colors.white70, height: 1.4)),
                            SizedBox(height: 6),
                            Text('Die Mindestvergütung für eine Lieferung oder Abholung beträgt jeweils 3,00 €.', style: TextStyle(color: Colors.white70, height: 1.4)),
                            SizedBox(height: 6),
                            Text('Die Vergütung für Lieferung und/oder Abholung wird automatisch anhand der Entfernung berechnet.', style: TextStyle(color: Colors.white70, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ]),
                ),
                // Removed per request: Preisberechnung & Gebühren infocard
                const SizedBox(height: 12),
                _Section(
                  title: 'Preis',
                  leading: const Icon(Icons.euro_outlined, color: Colors.lightBlueAccent, size: 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // AI Price Calculator Card
                  _AIPriceCalculatorCard(
                    suggestion: _priceSuggestion,
                    strategy: _priceStrategy,
                    onStrategyChanged: (v) {
                      // Always re-apply mode defaults when switching strategy
                      setState(() {
                        _priceStrategy = v;
                        // bump epoch to recreate discount inputs, ensuring visible values refresh even if focused
                        _strategyEpoch++;
                        // Reset manual override so the mode can take full effect
                        _priceTouched = false;
                      });
                      _autofillPriceFromMarket();
                      // Always reset the discount preset for the chosen mode
                      _applyModeDiscountPreset(force: true);
                    },
                    onRecalculate: _calculatePriceSuggestion,
                    canCalculate: _titleCtrl.text.trim().isNotEmpty && _categoryId != null && _addressCtrl.text.trim().isNotEmpty,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Preis',
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      suffixText: ' Euro/Tag',
                    ),
                    onChanged: (_) => setState(() { _priceTouched = true; }),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                      if (n == null || n <= 0) return 'Gültigen Preis eingeben';
                      return null;
                    },
                  ),
                  if (_priceTouched)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('Du hast den Preis manuell angepasst.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  const SizedBox(height: 12),
                  // Long-term discount editor
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.discount_outlined, color: Colors.lightBlueAccent, size: 18),
                        const SizedBox(width: 8),
                        const Text('Preisnachlass bei längerer Mietdauer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 6),
                      // Switch on top: Preisnachlass – toggles label based on state
                      SwitchListTile(
                        value: _autoApplyDiscounts,
                        onChanged: (v) => setState(() => _autoApplyDiscounts = v),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _autoApplyDiscounts ? 'Preisnachlass deaktivieren' : 'Preisnachlass aktivieren',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      if (_autoApplyDiscounts) ...[
                        const SizedBox(height: 4),
                        const SizedBox(height: 6),
                        _ThresholdDiscountRow(
                           key: ValueKey('tier1_'+_strategyEpoch.toString()),
                          days: _tier1Days,
                          percent: _tier1Pct,
                          pricePerDay: double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0,
                          onDaysChanged: (v) => setState(() { _tier1Days = v; _discountsTouched = true; }),
                           onPercentChanged: (v) => setState(() { _tier1Pct = v; _tier1PctEmpty = false; _discountsTouched = true; }),
                           onPercentEmptyChanged: (isEmpty) => setState(() { _tier1PctEmpty = isEmpty; }),
                        ),
                        const SizedBox(height: 6),
                        _ThresholdDiscountRow(
                           key: ValueKey('tier2_'+_strategyEpoch.toString()),
                          days: _tier2Days,
                          percent: _tier2Pct,
                          pricePerDay: double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0,
                          onDaysChanged: (v) => setState(() { _tier2Days = v; _discountsTouched = true; }),
                           onPercentChanged: (v) => setState(() { _tier2Pct = v; _tier2PctEmpty = false; _discountsTouched = true; }),
                           onPercentEmptyChanged: (isEmpty) => setState(() { _tier2PctEmpty = isEmpty; }),
                        ),
                        const SizedBox(height: 6),
                        _ThresholdDiscountRow(
                           key: ValueKey('tier3_'+_strategyEpoch.toString()),
                          days: _tier3Days,
                          percent: _tier3Pct,
                          pricePerDay: double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0,
                          onDaysChanged: (v) => setState(() { _tier3Days = v; _discountsTouched = true; }),
                           onPercentChanged: (v) => setState(() { _tier3Pct = v; _tier3PctEmpty = false; _discountsTouched = true; }),
                           onPercentEmptyChanged: (isEmpty) => setState(() { _tier3PctEmpty = isEmpty; }),
                        ),
                        const SizedBox(height: 8),
                        const Text('Rabattstaffel wird automatisch in allen Preisvorschauen berücksichtigt.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.lightBlueAccent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.25)),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('AI‑Tipp', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w700)),
                            SizedBox(height: 6),
                             Text('Für ähnliche Objekte in dieser Kategorie sind Rabatte wie oben angegeben zu empfehlen, um Mietfrequenz und Mietdauer zu erhöhen. Du kannst den Preis und die Staffelung anpassen oder komplett deaktivieren.', style: TextStyle(color: Colors.white70)),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                ])),
                // Preis-Section Ende – ab hier Inhalte außerhalb der Preis-Karte
                // Stornierungsbedingungen außerhalb der Preis-Karte und oberhalb des Erstellen-Buttons
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: _OwnerCancellationInfoCard(body: CancellationPolicyText.bodyForOwnerListingCard),
                ),
                const SizedBox(height: 20),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  FilledButton.icon(
                    onPressed: () => _submit(),
                    icon: const Icon(Icons.add_business),
                    label: Text(_isEdit ? 'Anzeige veröffentlichen' : 'Anzeige erstellen'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _submit(forceInactive: true),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_isEdit ? 'Bearbeitung speichern' : 'Für später speichern'),
                  ),
                ])
              ]),
            ),
          ),
        ),
      ),
      backgroundColor: isDark ? Colors.transparent : null,
    );
  }
}

// Unit selector removed: pricing is fixed per Tag and indicated inline as suffix

class _BlueChoice extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _BlueChoice({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.20)),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _ConditionPager extends StatefulWidget {
  final String selected; final ValueChanged<String> onChanged;
  const _ConditionPager({required this.selected, required this.onChanged});
  @override
  State<_ConditionPager> createState() => _ConditionPagerState();
}

class _ConditionPagerState extends State<_ConditionPager> {
  late final PageController _controller;
  int _currentIndex = 0;
  static const List<String> _labels = ['Wie neu', 'Gut gepflegt', 'Gebrauchsspuren'];
  static const List<String> _keys = ['like-new', 'good', 'acceptable'];

  int _indexFor(String sel) {
    switch (sel) {
      case 'like-new': return 0;
      case 'good': return 1;
      case 'acceptable': return 2;
      case 'new': return 0; // map legacy "Neu" to "Wie neu"
      default: return 1;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = _indexFor(widget.selected);
    _controller = PageController(initialPage: _currentIndex, viewportFraction: 0.5);
  }

  @override
  void didUpdateWidget(covariant _ConditionPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIndex = _indexFor(widget.selected);
    if (newIndex != _currentIndex) {
      _currentIndex = newIndex;
      // Jump without animation to reflect external change
      if (_controller.hasClients) {
        _controller.jumpToPage(_currentIndex);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: 56,
      child: PageView.builder(
        controller: _controller,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) {
          setState(() => _currentIndex = i);
          if (i >= 0 && i < _keys.length) widget.onChanged(_keys[i]);
        },
        itemCount: _labels.length,
        itemBuilder: (context, i) {
          final selected = i == _currentIndex;
          // Ensure each page consumes exactly half of the card width to reveal half-neighbors
          final itemWidth = width * 0.5;
          return Center(
            child: SizedBox(
              width: itemWidth - 16, // slight breathing space so the chip isn't full-bleed
              child: Center(
                child: _BlueChoice(
                  label: _labels[i],
                  selected: selected,
                  onTap: () {
                    if (_controller.hasClients) {
                      _controller.animateToPage(i, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
                    }
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CityAutocompleteField extends StatefulWidget {
  final TextEditingController controller; final String? initialValue; final ValueChanged<String> onChanged;
  const _CityAutocompleteField({required this.controller, required this.initialValue, required this.onChanged});
  @override
  State<_CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends State<_CityAutocompleteField> {
  late final List<String> _cities = DataService.getCities().keys.toList();
  @override
  void initState() {
    super.initState();
    if ((widget.initialValue ?? '').isNotEmpty) {
      widget.controller.text = widget.initialValue!;
    }
  }

  void _showAllCities() async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Größstädte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 360,
            child: ListView.separated(
              itemBuilder: (context, i) {
                final name = _cities[i];
                return ListTile(title: Text(name, style: const TextStyle(color: Colors.white)), onTap: () => Navigator.of(context).pop(name));
              },
              separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
              itemCount: _cities.length,
            ),
          ),
        ]),
      )),
    );
    if (sel != null) {
      widget.controller.text = sel;
      widget.onChanged(sel);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final q = textEditingValue.text.toLowerCase();
        if (q.isEmpty) return _cities; // show all when empty so nothing "red"
        return _cities.where((e) => e.toLowerCase().startsWith(q));
      },
      displayStringForOption: (opt) => opt,
      fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textCtrl,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: 'Stadt', suffixIcon: IconButton(onPressed: _showAllCities, icon: const Icon(Icons.arrow_drop_down, color: Colors.white))),
          onChanged: widget.onChanged,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Stadt ist erforderlich' : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final opts = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 280),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: opts.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                itemBuilder: (context, index) {
                  final opt = opts[index];
                  return ListTile(
                    dense: true,
                    title: Text(opt, style: const TextStyle(color: Colors.white)),
                    onTap: () => onSelected(opt),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (v) => widget.onChanged(v),
    );
  }
}

class _Section extends StatelessWidget {
  final String title; final Widget child; final Widget? leading; final Widget? trailing;
  const _Section({required this.title, required this.child, this.leading, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (leading == null && trailing == null)
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700))
        else
          Row(children: [
            if (leading != null) leading!,
            if (leading != null) const SizedBox(width: 8),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700))),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ]),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPhotoTile({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16), style: BorderStyle.solid, width: 1),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.add_a_photo, color: Colors.lightBlueAccent),
      ),
    );
  }
}

// Compact toggle tile with a blue circular indicator (no check glyph)
// _BlueDotToggleTile removed in favor of shared ToggleTextOption for consistent design.

class _PickedThumb extends StatelessWidget {
  final XFile file; final VoidCallback onRemove;
  const _PickedThumb({required this.file, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      InkWell(
        onTap: () async {
          final bytes = await file.readAsBytes();
          showDialog(context: context, builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: Colors.black,
            child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
          ));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done || !snap.hasData) {
                return const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
              }
              return Image.memory(snap.data!, fit: BoxFit.cover);
            },
          ),
        ),
      ),
      Positioned(
        right: 0,
        top: 0,
        child: InkWell(
          onTap: onRemove,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.close, size: 14, color: Colors.white),
          ),
        ),
      ),
    ]);
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 6, color: Colors.white70),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70))),
      ]),
    );
  }
}

// ---------- Simple Accordion (Chevron + smooth height animation) ----------
class _Accordion extends StatefulWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;
  // When true, renders without its own card container (inline, text-only toggle)
  final bool bare;
  // Center the title horizontally inside the header area
  final bool centerTitle;
  // Allow custom paddings per use-case
  final EdgeInsets? headerPadding;
  final EdgeInsets? bodyPadding;
  const _Accordion({
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
    this.bare = false,
    this.centerTitle = false,
    this.headerPadding,
    this.bodyPadding,
  });
  @override
  State<_Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<_Accordion> with SingleTickerProviderStateMixin {
  late bool _expanded = widget.initiallyExpanded;
  @override
  Widget build(BuildContext context) {
    final titleStyle = widget.bare
        ? const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)
        : const TextStyle(color: Colors.white, fontWeight: FontWeight.w700);

    final header = InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(widget.bare ? 8 : 12),
      child: Padding(
        padding: widget.headerPadding ?? EdgeInsets.symmetric(horizontal: widget.bare ? 0 : 12, vertical: 12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!widget.centerTitle)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(widget.title, style: titleStyle),
              ),
            if (widget.centerTitle)
              Center(child: Text(widget.title, style: titleStyle)),
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedRotation(
                turns: _expanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: const Icon(Icons.expand_more, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );

    final body = ClipRect(
      child: AnimatedAlign(
        heightFactor: _expanded ? 1.0 : 0.0,
        alignment: Alignment.topCenter,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: widget.bodyPadding ?? EdgeInsets.fromLTRB(widget.bare ? 0 : 12, 0, widget.bare ? 0 : 12, 12),
          child: widget.child,
        ),
      ),
    );

    if (widget.bare) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        header,
        body,
      ]);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(children: [header, body]),
    );
  }
}

// ---------- Owner-facing Cancellation Info Card (centered title, tap-to-expand) ----------
class _OwnerCancellationInfoCard extends StatefulWidget {
  final String body;
  const _OwnerCancellationInfoCard({required this.body});
  @override
  State<_OwnerCancellationInfoCard> createState() => _OwnerCancellationInfoCardState();
}

class _OwnerCancellationInfoCardState extends State<_OwnerCancellationInfoCard> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.policy_outlined, color: Colors.white70),
                const SizedBox(width: 8),
                const Text('Stornierungsbedingungen', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
        ),
        AnimatedCrossFade(
          crossFadeState: _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(widget.body, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35)),
          ),
          secondChild: const SizedBox(height: 0),
        ),
      ],
    );
  }
}

// ---------- Address Autocomplete with Google Places API ----------
class _PlaceSuggestion {
  final String description;
  final String placeId;
  const _PlaceSuggestion({required this.description, required this.placeId});
}

class _PlaceDetails {
  final String? formattedAddress;
  final double? lat;
  final double? lng;
  final String description;
  const _PlaceDetails({this.formattedAddress, this.lat, this.lng, required this.description});
}

class _AddressAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final List<_PlaceSuggestion> suggestions;
  final bool apiKeyConfigured;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_PlaceDetails> onPlaceChosen;
  const _AddressAutocompleteField({
    required this.controller,
    required this.onQueryChanged,
    required this.suggestions,
    required this.onPlaceChosen,
    required this.apiKeyConfigured,
  });
  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<_PlaceSuggestion>(
      textEditingController: controller,
      focusNode: FocusNode(),
      optionsBuilder: (TextEditingValue tev) {
        final text = tev.text.trim();
        if (text.isEmpty) return const Iterable<_PlaceSuggestion>.empty();
        // onQueryChanged is debounced by parent
        onQueryChanged(text);
        return suggestions;
      },
      displayStringForOption: (o) => o.description,
      fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textCtrl,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Adresse eingeben'),
          onChanged: onQueryChanged,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.black,
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, minWidth: 320),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemBuilder: (context, i) {
                  final s = list[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, color: Colors.white70),
                    title: Text(s.description, style: const TextStyle(color: Colors.white)),
                    onTap: () async {
                      // Fetch place details for lat/lng
                      final d = await _fetchPlaceDetails(s.placeId);
                      onSelected(s);
                      onPlaceChosen(_PlaceDetails(
                        formattedAddress: d?.formattedAddress ?? s.description,
                        lat: d?.lat,
                        lng: d?.lng,
                        description: s.description,
                      ));
                    },
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                itemCount: list.length,
              ),
            ),
          ),
        );
      },
      onSelected: (_) {},
    );
  }
}

// --- Google Places API Calls ---
Future<List<_PlaceSuggestion>> _fetchAutocomplete(String input) async {
  if (kGoogleMapsApiKey.isEmpty) return const [];
  final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
    'input': input,
    'types': 'address',
    'language': 'de',
    'components': 'country:de',
    'key': kGoogleMapsApiKey,
  });
  try {
    final res = await http.get(uri);
    if (res.statusCode != 200) return const [];
    final data = json.decode(utf8.decode(res.bodyBytes));
    final preds = (data['predictions'] as List?) ?? [];
    return preds.map<_PlaceSuggestion>((p) => _PlaceSuggestion(description: p['description'], placeId: p['place_id'])).toList();
  } catch (_) {
    return const [];
  }
}

Future<_PlaceDetails?> _fetchPlaceDetails(String placeId) async {
  if (kGoogleMapsApiKey.isEmpty) return null;
  final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
    'place_id': placeId,
    'fields': 'formatted_address,geometry',
    'language': 'de',
    'key': kGoogleMapsApiKey,
  });
  try {
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = json.decode(utf8.decode(res.bodyBytes));
    final r = data['result'];
    final addr = r['formatted_address'] as String?;
    final loc = r['geometry']?['location'];
    final lat = (loc?['lat'] as num?)?.toDouble();
    final lng = (loc?['lng'] as num?)?.toDouble();
    return _PlaceDetails(formattedAddress: addr, lat: lat, lng: lng, description: addr ?? '');
  } catch (_) {
    return null;
  }
}

// ---------- AI Price Calculator Card ----------
class _AIPriceCalculatorCard extends StatelessWidget {
  final PriceSuggestion? suggestion;
  final String strategy;
  final ValueChanged<String> onStrategyChanged;
  final VoidCallback onRecalculate;
  final bool canCalculate;
  const _AIPriceCalculatorCard({
    required this.suggestion,
    required this.strategy,
    required this.onStrategyChanged,
    required this.onRecalculate,
    required this.canCalculate,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome, color: Colors.lightBlueAccent, size: 20),
          const SizedBox(width: 8),
          const Text('KI-Preisberechnung', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          const Spacer(),
          // Live recalculation enabled – manual refresh removed
        ]),
        if (!canCalculate) ...[
          const SizedBox(height: 8),
          const Text('Bitte fülle Titel, Kategorie und Adresse aus, um eine Preisempfehlung zu erhalten.', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
        if (canCalculate && suggestion == null) ...[
          const SizedBox(height: 8),
          const Text('Berechne Preisvorschlag…', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
        if (suggestion != null) ...[
          const SizedBox(height: 12),
          // Strategy toggle
          Row(children: [
            Expanded(
              child: _StrategyChip(
                label: 'Schnell vermieten',
                icon: Icons.speed,
                selected: strategy == 'quick',
                onTap: () => onStrategyChanged('quick'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StrategyChip(
                label: 'Maximaler Gewinn',
                icon: Icons.trending_up,
                selected: strategy == 'premium',
                onTap: () => onStrategyChanged('premium'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // Price suggestions
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                const Text('Aktueller Marktpreis (€/Tag):', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${suggestion!.dailyPriceMin.toStringAsFixed(0)}–${suggestion!.dailyPriceMax.toStringAsFixed(0)} €', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          // Mode-specific helper text
          Builder(builder: (context) {
            final help = strategy == 'quick'
                ? 'Preis im unteren Marktbereich – erhöht die Buchungswahrscheinlichkeit.'
                : 'Preis im oberen Marktbereich – optimiert Ertrag pro Vermietung.';
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(help, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4))),
            ]);
          }),
          const SizedBox(height: 8),
          // Reasoning
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, color: Colors.white54, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(suggestion!.reasoning, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4))),
          ]),
          const SizedBox(height: 8),
          // Optimization tip
          Container(
            decoration: BoxDecoration(
              color: Colors.lightBlueAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.3)),
            ),
            padding: const EdgeInsets.all(10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lightbulb_outline, color: Colors.lightBlueAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(suggestion!.optimizationTip, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4))),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _StrategyChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _StrategyChip({required this.label, required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? Colors.lightBlueAccent : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? Colors.lightBlueAccent : Colors.white.withValues(alpha: 0.16)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: selected ? Colors.black : Colors.white70, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.black : Colors.white70, fontWeight: FontWeight.w600, fontSize: 12))),
        ]),
      ),
    );
  }
}

class _DiscountRow extends StatelessWidget {
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  const _DiscountRow({required this.label, required this.value, required this.onChanged, this.enabled = true});
  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1));
    return Row(children: [
      SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: ctrl,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(suffixText: '%', labelText: 'Rabatt', isDense: true),
          onChanged: (v) {
            final n = double.tryParse(v.replaceAll(',', '.'));
            if (n != null) onChanged(n.clamp(0.0, 95.0).toDouble());
          },
        ),
      ),
    ]);
  }
}

class _ThresholdDiscountRow extends StatefulWidget {
  final int days; final double percent; final double pricePerDay; final ValueChanged<int> onDaysChanged; final ValueChanged<double> onPercentChanged; final ValueChanged<bool>? onPercentEmptyChanged;
  const _ThresholdDiscountRow({super.key, required this.days, required this.percent, required this.pricePerDay, required this.onDaysChanged, required this.onPercentChanged, this.onPercentEmptyChanged});
  @override
  State<_ThresholdDiscountRow> createState() => _ThresholdDiscountRowState();
}

class _ThresholdDiscountRowState extends State<_ThresholdDiscountRow> {
  late final TextEditingController _daysCtrl = TextEditingController(text: widget.days.toString());
  late final TextEditingController _pctCtrl = TextEditingController(text: _formatPercent(widget.percent));
  late final FocusNode _daysFocus = FocusNode();
  late final FocusNode _pctFocus = FocusNode();

  String _formatPercent(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

  @override
  void didUpdateWidget(covariant _ThresholdDiscountRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync controllers when field is NOT focused to avoid overriding user typing
    final newDaysText = widget.days.toString();
    if (!_daysFocus.hasFocus && _daysCtrl.text != newDaysText) {
      _daysCtrl.text = newDaysText;
    }
    final newPctText = _formatPercent(widget.percent);
    if (!_pctFocus.hasFocus && _pctCtrl.text != newPctText) {
      _pctCtrl.text = newPctText;
    }
  }

  @override
  void dispose() {
    _daysCtrl.dispose();
    _pctCtrl.dispose();
    _daysFocus.dispose();
    _pctFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discountEuroPerDay = ((widget.pricePerDay) * (widget.percent / 100)).clamp(0.0, double.infinity).toDouble();
    return Row(children: [
      // Mietdauer: slightly narrower so Rabatt gets a bit more space (~0.5 cm)
      Flexible(
        flex: 6, // give Mietdauer more breathing room so it stays tappable/editable
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 120), // ensure a minimum interactive width
          child: TextField(
            controller: _daysCtrl,
            focusNode: _daysFocus,
            keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Mietdauer',
              labelStyle: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w700),
              floatingLabelStyle: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w700),
              floatingLabelAlignment: FloatingLabelAlignment.center,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              prefixText: 'Ab ',
              suffixText: ' Tagen',
              isDense: true,
            ),
            onChanged: (v) {
              final n = int.tryParse(v.replaceAll(',', '.'));
              if (n != null) widget.onDaysChanged(n.clamp(1, 365));
            },
          ),
        ),
      ),
      const SizedBox(width: 12),
      // Rabatt: behave like a single input (like Mietdauer). Tap to edit percent; right side shows computed €/Tag.
      // Widen the editable area so multiple digits remain fully visible.
      Flexible(
        flex: 10,
        child: TextField(
          controller: _pctCtrl,
          focusNode: _pctFocus,
          keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Rabatt',
            labelStyle: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w700),
            floatingLabelStyle: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w700),
            floatingLabelAlignment: FloatingLabelAlignment.center,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            isDense: true,
            // Place '%' on the left, before the entered value, aligned across rows
            // Ensure the prefix does not intercept taps so the field stays editable
            prefixIcon: const IgnorePointer(child: _PercentPrefix()),
            prefixIconConstraints: _PercentPrefix.constraints,
            // Keep the computed "€/Tag" as a compact suffix that only takes its intrinsic width
            // so the editable area remains wide enough to show the typed number.
            suffix: IgnorePointer(child: _ComputedDiscountSuffix(value: discountEuroPerDay)),
          ),
          onChanged: (v) {
            final n = double.tryParse(v.replaceAll(',', '.'));
            widget.onPercentEmptyChanged?.call(v.trim().isEmpty);
            if (n != null) widget.onPercentChanged(n.clamp(0.0, 95.0).toDouble());
          },
        ),
      ),
    ]);
  }
}

class _PercentPrefix extends StatelessWidget {
  const _PercentPrefix();

  // Fixed width so '%' aligns vertically across all Rabatt rows
  static const double _width = 24; // slimmer to free space for input
  static final BoxConstraints constraints = const BoxConstraints(
    minWidth: _width,
    maxWidth: _width,
    minHeight: 0,
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: constraints.maxWidth,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          // Keep a small left inset; keep gap to the input minimal
          padding: const EdgeInsets.only(left: 8, right: 2),
          child: Text('%', style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

class _ComputedDiscountSuffix extends StatelessWidget {
  final double value;
  const _ComputedDiscountSuffix({required this.value});

  // Compact layout sizes. This widget is used as InputDecoration.suffix (not suffixIcon)
  // so it will shrink-wrap to its intrinsic width and avoid stealing space from the input text.
  static const double _dividerWidth = 1;
  static const double _gapBeforeDivider = 6; // pull divider closer to reclaim input width
  static const double _gapAfterDivider = 6;
  static const double _endPadding = 12; // ~2mm from the field's right edge

  @override
  Widget build(BuildContext context) {
    final text = (value.isFinite ? value.toStringAsFixed(2) : '0.00') + ' €/Tag';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: _gapBeforeDivider),
      Container(width: _dividerWidth, height: 24, color: Colors.white24),
      const SizedBox(width: _gapAfterDivider),
      // Let the euro text size itself but keep it from growing too tall and clip if needed
      Flexible(
        fit: FlexFit.loose,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, maxWidth: 96),
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(text, style: const TextStyle(color: Colors.white), maxLines: 1, softWrap: false),
            ),
          ),
        ),
      ),
      const SizedBox(width: _endPadding),
    ]);
  }
}
