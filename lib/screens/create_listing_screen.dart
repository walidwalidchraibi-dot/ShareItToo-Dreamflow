import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/category.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/backend_config.dart';
import 'package:lendify/services/backend_repository.dart';
import 'package:lendify/services/qa_runtime_service.dart';
import 'package:lendify/navigation/main_navigation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/widgets/all_categories_overlay.dart';
import 'package:lendify/services/ai_price_calculator_service.dart';
import 'package:lendify/openai/openai_config.dart';
import 'package:lendify/utils/cancellation_policy_text.dart';
import 'package:lendify/widgets/selection_controls.dart';
import 'package:lendify/theme.dart';

// Google Maps Places API key (configure as a build-time environment variable).
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
  String _condition =
      'new'; // 'new' | 'like-new' | 'good' | 'acceptable' | 'worn'
  // Delivery options
  bool _offersDeliveryAtDropoff = false; // Lieferung bei Abgabe (Hinweg)
  bool _offersPickupAtReturn = false; // Abholung bei Rückgabe (Rückweg)
  bool _offersExpressAtDropoff =
      false; // Deprecated: Prioritäts-/Expresslieferung (nicht mehr angeboten)
  double? _maxDistanceKm; // applies to both delivery and pickup (simple model)
  // Master toggle for Lieferung / Abholung anbieten (default disabled like requested)
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
  bool _addrSuggestionsUnavailable = _gmapsKey.isEmpty;

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
  bool _autoApplyDiscounts = true; // acts as "Rabatt aktivieren"
  int _tier1Days = 3;
  double _tier1Pct = 10;
  int _tier2Days = 5;
  double _tier2Pct = 20;
  int _tier3Days = 8;
  double _tier3Pct = 30;
  bool _hasCalculatedDiscounts = false;
  bool _discountsTouched =
      false; // if user edits any tier, avoid overwriting with AI
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
      _priceCtrl.text = ex.priceRaw.toStringAsFixed(
          ex.priceRaw.truncateToDouble() == ex.priceRaw ? 0 : 2);
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
      _deliveryOptionsEnabled = _offersDeliveryAtDropoff ||
          _offersPickupAtReturn ||
          (_maxDistanceKm != null);
      _registeredCity = ex.city;
      _addressCtrl.text = ex.locationText;
      _selectedAddrLat = ex.lat;
      _selectedAddrLng = ex.lng;
      _existingPhotos = List<String>.from(ex.photos);
      _cancellationPolicy = ex.cancellationPolicy;
      // Prefill discount tiers: map first three thresholds ascending
      _autoApplyDiscounts = ex.autoApplyDiscounts;
      if (ex.longRentalDiscounts.isNotEmpty) {
        final tiers = [...ex.longRentalDiscounts]
          ..sort((a, b) => a.days.compareTo(b.days));
        if (tiers.length >= 1) {
          _tier1Days = tiers[0].days;
          _tier1Pct = tiers[0].discountPercent;
        }
        if (tiers.length >= 2) {
          _tier2Days = tiers[1].days;
          _tier2Pct = tiers[1].discountPercent;
        }
        if (tiers.length >= 3) {
          _tier3Days = tiers[2].days;
          _tier3Pct = tiers[2].discountPercent;
        }
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
      _categoryId = cats.isNotEmpty
          ? (widget.existing?.categoryId ?? cats.first.id)
          : null;
      _coarseCats =
          ordered.isNotEmpty ? ordered : DataService.coarseCategoryOrder;
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
        setState(() => _pickedImages.addAll(res.files
            .where((f) => f.bytes != null)
            .map((f) => XFile.fromData(f.bytes!, name: f.name))));
      }
      return;
    }
    final List<XFile> files =
        await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1600);
    if (files.isNotEmpty) setState(() => _pickedImages.addAll(files));
  }

  void _showPhotoSourceSheet() {
    // Centered popup for picking photos with blurred background
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (context) {
        return Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Stack(children: [
              // Blurred backdrop
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
              // Dialog content
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withValues(alpha: 0.34)
                          : AppTheme.surfacePrimary(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE2E8F0)),
                      boxShadow: Theme.of(context).brightness == Brightness.dark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Icon(Icons.photo_camera,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.primary),
                          title: Text('Mit Kamera aufnehmen',
                              style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : AppTheme.textPrimary(context))),
                          onTap: () async {
                            Navigator.of(context).maybePop();
                            await _pickFromCamera();
                          },
                        ),
                        Divider(
                            height: 1,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white12
                                    : const Color(0xFFE2E8F0)),
                        ListTile(
                          leading: Icon(Icons.photo_library,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : AppTheme.textBody(context)),
                          title: Text('Aus Galerie auswählen',
                              style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : AppTheme.textPrimary(context))),
                          onTap: () async {
                            Navigator.of(context).maybePop();
                            await _pickFromGallery();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
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
          message:
              'Einige Pflichtfelder sind noch unvollständig. Bitte fülle die markierten Felder aus.',
          plainCloseIcon: true,
        );
      }
      return;
    }

    final user = await DataService.getCurrentUser();
    if (user == null) {
      if (!mounted) return;
      await AppPopup.toast(context,
          icon: Icons.login, title: 'Bitte zuerst anmelden');
      return;
    }
    final productionBackend =
        BackendConfig.enabled && !QaRuntimeService.isEnabled;
    final acceptedExistingPhotos = productionBackend
        ? _existingPhotos.where(BackendConfig.isManagedListingImageUrl).toList()
        : List<String>.from(_existingPhotos);
    if (!forceInactive &&
        acceptedExistingPhotos.isEmpty &&
        _pickedImages.isEmpty) {
      if (!mounted) return;
      await AppPopup.show(
        context,
        icon: Icons.add_photo_alternate_outlined,
        title: 'Mindestens ein Foto erforderlich',
        message:
            'Füge ein echtes Foto des Artikels hinzu, bevor du die Anzeige veröffentlichst.',
        plainCloseIcon: true,
      );
      return;
    }

    final allCities = DataService.getCities();
    String city = _registeredCity ?? allCities.keys.first;
    (double, double) pos = allCities[city] ?? (52.52, 13.405);

    // Always use address mode now
    String locationText = _addressCtrl.text.trim().isNotEmpty
        ? _addressCtrl.text.trim()
        : 'Übergabeort';
    if (_selectedAddrLat != null && _selectedAddrLng != null) {
      pos = (_selectedAddrLat!, _selectedAddrLng!);
    }
    // Try to derive city name from the typed address; fall back to registered city
    final derived = DataService.deriveCityFromAddress(locationText);
    if (derived.isNotEmpty) city = derived;

    final raw = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
    double pricePerDay;
    switch (_priceUnit) {
      case 'week':
        pricePerDay = raw / 7;
        break;
      case 'day':
      default:
        pricePerDay = raw;
        break;
    }

    // Production uploads images to the central backend. Debug/QA keeps the
    // existing local data-URL behavior for deterministic offline fixtures.
    final List<String> photos = List<String>.from(acceptedExistingPhotos);
    if (_pickedImages.isNotEmpty) {
      for (final f in _pickedImages) {
        try {
          final bytes = await f.readAsBytes();
          if (productionBackend) {
            photos.add(
              await BackendRepository.uploadImage(
                bytes: bytes,
                filename: f.name,
              ),
            );
          } else {
            final b64 = base64Encode(bytes);
            final mime = _inferMimeFromName(f.name);
            photos.add('data:$mime;base64,$b64');
          }
        } catch (error) {
          if (productionBackend) rethrow;
          debugPrint('Local image processing failed: $error');
        }
      }
    }
    if (!_isEdit) {
      final item = Item(
        id: 'new',
        ownerId: user.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        categoryId: _categoryId ??
            (_categories.isNotEmpty ? _categories.first.id : 'cat1'),
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
        minDays: 1,
        maxDays: 30,
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
        protectionModel: 'standard',
        availabilityMode: 'calendar',
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
      protectionModel: ex.protectionModel,
      availabilityMode: ex.availabilityMode,
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
        setState(() {
          _addrSuggestions = const [];
          _addrSuggestionsUnavailable = true;
        });
        return;
      }
      if (q.trim().isEmpty) {
        setState(() {
          _addrSuggestions = const [];
          _addrSuggestionsUnavailable = false;
        });
        return;
      }
      try {
        final results = await _fetchAutocomplete(q);
        if (!mounted) return;
        setState(() {
          _addrSuggestions = results;
          _addrSuggestionsUnavailable = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _addrSuggestions = const [];
          _addrSuggestionsUnavailable = true;
        });
      }
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
      case 'devices':
        return Icons.devices;
      case 'computer':
        return Icons.computer;
      case 'camera_alt':
        return Icons.camera_alt;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'kitchen':
        return Icons.kitchen;
      case 'weekend':
        return Icons.weekend;
      case 'grass':
        return Icons.grass;
      case 'construction':
        return Icons.construction;
      case 'pedal_bike':
        return Icons.pedal_bike;
      case 'directions_car':
        return Icons.directions_car;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'checkroom':
        return Icons.checkroom;
      case 'child_friendly':
        return Icons.child_friendly;
      case 'music_note':
        return Icons.music_note;
      case 'menu_book':
        return Icons.menu_book;
      case 'watch':
        return Icons.watch;
      case 'palette':
        return Icons.palette;
      case 'spa':
        return Icons.spa;
      case 'pets':
        return Icons.pets;
      case 'business_center':
        return Icons.business_center;
      case 'celebration':
        return Icons.celebration;
      case 'travel_explore':
        return Icons.travel_explore;
      case 'more_horiz':
        return Icons.more_horiz;
      default:
        return Icons.category;
    }
  }

  // Coarse/top-level category icon mapping (keep in sync with filters overlay)
  IconData _coarseIconForGroup(String group) {
    final g = group.toLowerCase();
    if (g.contains('technik')) return Icons.devices;
    if (g.contains('haushalt') || g.contains('wohnen')) return Icons.weekend;
    if (g.contains('fahrzeuge') || g.contains('mobil'))
      return Icons.directions_car;
    if (g.contains('mode') || g.contains('lifestyle')) return Icons.checkroom;
    if (g.contains('sport') || g.contains('hobby') || g.contains('hobb'))
      return Icons.sports_soccer;
    if (g.contains('werkzeuge') ||
        g.contains('geräte') ||
        g.contains('geraete')) return Icons.construction;
    if (g.contains('garten') || g.contains('hof')) return Icons.grass;
    if (g.contains('event') || g.contains('feier') || g.contains('party'))
      return Icons.celebration;
    if (g.contains('reise') || g.contains('camping'))
      return Icons.travel_explore;
    if (g.contains('büro') || g.contains('buero') || g.contains('gewerbe'))
      return Icons.business_center;
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
    final tiles = _coarseCats.map((label) {
      final list = _catsByCoarse[label] ?? const <Category>[];
      final id = list.isNotEmpty ? list.first.id : label;
      return CategoryChipData(
          id: id, label: label, icon: _coarseIconForGroup(label));
    }).toList();

    final selected = await AllCategoriesOverlay.show(context, tiles);
    if (selected != null) {
      // Map back from coarse label to a representative fine category id (first in group)
      final list = _catsByCoarse.entries
          .firstWhere((e) => (e.value).any((c) => c.id == selected),
              orElse: () => MapEntry('', const <Category>[]))
          .value;
      final target = list.isNotEmpty ? list.first.id : selected;
      setState(() => _categoryId = target);
      _schedulePriceRecalc();
    }
  }

  Future<void> _calculatePriceSuggestion() async {
    // Only calculate if all required fields are filled
    if (_titleCtrl.text.trim().isEmpty ||
        _categoryId == null ||
        _addressCtrl.text.trim().isEmpty) {
      return;
    }

    // Get category name
    final cat = _categories.firstWhere((c) => c.id == _categoryId,
        orElse: () => _categories.first);
    final categoryName = DataService.coarseCategoryFor(cat.name);

    if (!OpenAIConfig.isAvailable) {
      await AppPopup.toast(
        context,
        icon: Icons.info_outline,
        title: 'KI-Hilfe ist vorübergehend deaktiviert',
        message: 'Bitte gib die Details manuell ein.',
      );
      return;
    }

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
        optimizationTip:
            'Richte den Preis an der Marktspanne aus und nutze Rabatte sinnvoll.',
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
        _tier1Days = 3;
        _tier1Pct = 15;
        _tier2Days = 5;
        _tier2Pct = 25;
        _tier3Days = 8;
        _tier3Pct = 35;
      } else {
        // Maximaler Gewinn – moderate Rabatte
        _tier1Days = 3;
        _tier1Pct = 8;
        _tier2Days = 5;
        _tier2Pct = 15;
        _tier3Days = 8;
        _tier3Pct = 25;
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
    _priceCtrl.text =
        price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    // Auto-calculate price suggestion when all required fields are filled (only once)
    if (!_hasCalculatedPrice &&
        _titleCtrl.text.trim().isNotEmpty &&
        _categoryId != null &&
        _addressCtrl.text.trim().isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _calculatePriceSuggestion());
    }
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? 'Anzeige bearbeiten' : 'Neue Anzeige'),
          centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Theme(
            data: theme.copyWith(
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: isDark
                      ? const Color(0x1FFFFFFF)
                      : const Color(0xFFFFFFFF),
                  labelStyle: TextStyle(
                      color: isDark
                          ? Colors.white
                          : AppTheme.textSecondary(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                  floatingLabelStyle: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white70
                          : AppTheme.textDisabled(context),
                      fontSize: 14),
                  border: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: isDark
                              ? Colors.white24
                              : AppTheme.glassStroke(context)),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(12))),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: isDark
                              ? Colors.white24
                              : AppTheme.glassStroke(context)),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(12))),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.primary),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(12))),
                  prefixStyle: TextStyle(
                      color:
                          isDark ? Colors.white : AppTheme.textBody(context)),
                ),
                dropdownMenuTheme: DropdownMenuThemeData(
                    menuStyle: MenuStyle(
                        backgroundColor: WidgetStatePropertyAll(isDark
                            ? const Color(0xE6000000)
                            : const Color(0xFFFFFFFF))))),
            child: Form(
              key: _formKey,
              child: Column(children: [
                _Section(
                    title: 'Kategorie',
                    leading: Icon(Icons.widgets_outlined,
                        color: colorScheme.primary, size: 18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            onTap: _pickCategory,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  hintText: 'Kategorie wählen'),
                              child: Row(children: [
                                Icon(_coarseIconForGroup(_currentCoarseLabel()),
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textPrimary(context)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    // In "Neue Anzeige" show the selected category on a single line
                                    _currentCoarseLabel(),
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : AppTheme.textBody(context),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500),
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
                    leading: Icon(Icons.description_outlined,
                        color: colorScheme.primary, size: 18),
                    child: Column(children: [
                      TextFormField(
                        controller: _titleCtrl,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : AppTheme.textBody(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                            labelText: 'Titel', hintText: 'Was bietest du an?'),
                        onChanged: (_) => _schedulePriceRecalc(),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Titel ist erforderlich'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 5,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : AppTheme.textBody(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                            labelText: 'Beschreibung',
                            hintText:
                                'Beschreibe Zustand, Zubehör, Abholung …'),
                        onChanged: (_) => _schedulePriceRecalc(),
                        validator: (v) => (v == null || v.trim().length < 10)
                            ? 'Mindestens 10 Zeichen'
                            : null,
                      ),
                    ])),
                const SizedBox(height: 12),
                // Fotos kommt vor Zustand
                _Section(
                    title: 'Fotos',
                    leading: Icon(Icons.photo_library_outlined,
                        color: colorScheme.primary, size: 18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(builder: (context) {
                            final hasAnyPhotos = _existingPhotos.isNotEmpty ||
                                _pickedImages.isNotEmpty;
                            if (!hasAnyPhotos) {
                              // Center the + photo button horizontally (and give the card some height) when there are no images yet
                              return SizedBox(
                                height: 120,
                                child: Center(
                                    child: _AddPhotoTile(
                                        onTap: _showPhotoSourceSheet)),
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
                                      child: SizedBox(
                                          width: 84,
                                          height: 84,
                                          child: AppImage(
                                              url: url, fit: BoxFit.cover)),
                                    ),
                                for (int i = 0; i < _pickedImages.length; i++)
                                  _PickedThumb(
                                      file: _pickedImages[i],
                                      onRemove: () => setState(
                                          () => _pickedImages.removeAt(i))),
                                _AddPhotoTile(onTap: _showPhotoSourceSheet),
                              ],
                            );
                          }),
                          const SizedBox(height: 6),
                          Text(
                              'Füge Fotos hinzu. Tippe auf +, um Kamera oder Galerie zu wählen.',
                              style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white70
                                      : AppTheme.textSecondary(context),
                                  fontSize: 13,
                                  height: 1.35)),
                          const SizedBox(height: 8),
                          _Accordion(
                            title: '💬 Tipp',
                            initiallyExpanded: false,
                            bare: true,
                            child: Text(
                              'Hochwertige, klare Bilder erhöhen die Chance, dass deine Anzeige öfter gemietet wird.\n'
                              'Zeig den Artikel aus verschiedenen Winkeln – hell, scharf und komplett.',
                              style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white70
                                      : AppTheme.textSecondary(context),
                                  fontSize: 13.5,
                                  height: 1.45),
                            ),
                          ),
                        ])),
                const SizedBox(height: 12),
                _Section(
                  title: 'Zustand',
                  leading: Icon(Icons.workspace_premium_outlined,
                      color: colorScheme.primary, size: 18),
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
                    title: 'Übergabeort',
                    leading: Icon(Icons.place_outlined,
                        color: colorScheme.primary, size: 18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AddressAutocompleteField(
                            controller: _addressCtrl,
                            onPlaceChosen: (d) {
                              setState(() {
                                _addressCtrl.text =
                                    d.formattedAddress ?? d.description;
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
                          if (_addrSuggestionsUnavailable)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  'Vorschläge sind gerade nicht verfügbar. Du kannst den Ort trotzdem manuell eingeben.',
                                  style: TextStyle(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white70
                                          : AppTheme.textSecondary(context),
                                      fontSize: 13,
                                      height: 1.35)),
                            ),
                          const SizedBox(height: 8),
                          _Accordion(
                            title: 'Datenschutz & Übergabeort',
                            initiallyExpanded: false,
                            bare: true,
                            child: Text(
                              'Der genaue Übergabeort wird nur zur Berechnung der Entfernung genutzt und erst nach bestätigter Anfrage angezeigt, wenn der Mieter Selbstabholer ist.',
                              style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white70
                                      : AppTheme.textSecondary(context),
                                  fontSize: 13.5,
                                  height: 1.45),
                            ),
                          ),
                        ])),
                const SizedBox(height: 12),
                _Section(
                  title: 'Lieferung / Abholung anbieten',
                  leading: Icon(Icons.local_shipping_outlined,
                      color: colorScheme.primary, size: 18),
                  trailing: Switch.adaptive(
                    value: _deliveryOptionsEnabled,
                    onChanged: (v) => setState(() {
                      _deliveryOptionsEnabled = v;
                      if (!v) {
                        _offersDeliveryAtDropoff = false;
                        _offersPickupAtReturn = false;
                        _offersExpressAtDropoff = false;
                        _maxDistanceKm = null;
                      }
                    }),
                    activeColor: colorScheme.primary,
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_deliveryOptionsEnabled) ...[
                          ToggleTextOption(
                            label: 'Lieferung',
                            selected: _offersDeliveryAtDropoff,
                            onTap: () => setState(() {
                              _offersDeliveryAtDropoff =
                                  !_offersDeliveryAtDropoff;
                              if (!_offersDeliveryAtDropoff)
                                _offersExpressAtDropoff = false;
                            }),
                          ),
                          ToggleTextOption(
                            label: 'Abholung',
                            selected: _offersPickupAtReturn,
                            onTap: () => setState(() =>
                                _offersPickupAtReturn = !_offersPickupAtReturn),
                          ),
                          const SizedBox(height: 8),
                          _Accordion(
                            title: 'Was bedeutet das?',
                            initiallyExpanded: false,
                            bare: true,
                            bodyPadding: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Wenn du Lieferung anbietest und der Mieter diese Option bei der Buchung auswählt, bringst du den Artikel zum vereinbarten Übergabeort des Mieters.\n\n'
                                'Wenn Abholung aktiviert ist und der Mieter diese Option für die Rückgabe auswählt, holst du den Artikel nach der Miete wieder beim Mieter ab.\n\n'
                                'Wenn Lieferung oder Abholung nicht aktiviert sind, holt der Mieter den Artikel selbst am Übergabeort ab und bringt ihn nach der Miete selbst wieder zurück.',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : AppTheme.textSecondary(context),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w400,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ),
                          if (_offersDeliveryAtDropoff ||
                              _offersPickupAtReturn) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: _maxDistanceKm?.toStringAsFixed(1),
                              onChanged: (v) => _maxDistanceKm =
                                  double.tryParse(v.replaceAll(',', '.')),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textBody(context),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                labelText:
                                    'Maximale Liefer-/Abholentfernung in km',
                                // Make the label more subtle/smaller when the field appears
                                labelStyle: TextStyle(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white70
                                        : AppTheme.textSecondary(context),
                                    fontSize: 13),
                                floatingLabelStyle: TextStyle(
                                    color: colorScheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          _Accordion(
                            title: 'Vergütung für Fahrtaufwand',
                            initiallyExpanded: false,
                            bare: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Die Vergütung wird automatisch anhand der Entfernung berechnet.',
                                    style: TextStyle(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white70
                                            : AppTheme.textSecondary(context),
                                        fontSize: 13.5,
                                        height: 1.4)),
                                SizedBox(height: 6),
                                Text(
                                    'Aktuell: 0,30 € pro km für Hin- und Rückfahrt, mindestens 3,00 € pro Lieferung oder Abholung.',
                                    style: TextStyle(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white70
                                            : AppTheme.textSecondary(context),
                                        fontSize: 13.5,
                                        height: 1.4)),
                                SizedBox(height: 6),
                                Text(
                                    'Der Mieter sieht die Kosten vor dem Absenden der Anfrage.',
                                    style: TextStyle(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white70
                                            : AppTheme.textSecondary(context),
                                        fontSize: 13.5,
                                        height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ]),
                ),
                // Removed per request: Preisberechnung & Gebühren infocard
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? const LinearGradient(
                            colors: [Color(0xFF0C1222), Color(0xFF0A152B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight)
                        : const LinearGradient(
                            colors: [Color(0xFFFFFFFF), Color(0xFFF6FBFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : AppTheme.glassStroke(context)),
                    boxShadow: isDark
                        ? [
                            BoxShadow(
                                color: Colors.lightBlueAccent
                                    .withValues(alpha: 0.14),
                                blurRadius: 22,
                                spreadRadius: 1,
                                offset: const Offset(0, 10)),
                          ]
                        : [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 18,
                                offset: const Offset(0, 8)),
                          ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const _CircleBadge(
                              icon: Icons.euro_rounded,
                              color: Colors.lightBlueAccent,
                              diameter: 38),
                          const SizedBox(width: 12),
                          Text('Preis pro Tag',
                              style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : AppTheme.textPrimary(context),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                        ]),
                        const SizedBox(height: 14),
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
                          canCalculate: _titleCtrl.text.trim().isNotEmpty &&
                              _categoryId != null &&
                              _addressCtrl.text.trim().isNotEmpty,
                        ),
                        const SizedBox(height: 14),
                        _PricePerDayInput(
                          controller: _priceCtrl,
                          onChanged: (_) => setState(() {
                            _priceTouched = true;
                          }),
                          validator: (v) {
                            final n =
                                double.tryParse((v ?? '').replaceAll(',', '.'));
                            if (n == null || n <= 0)
                              return 'Gültigen Preis eingeben';
                            return null;
                          },
                        ),
                        if (_priceTouched)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('Du hast den Preis manuell angepasst.',
                                style: TextStyle(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white70
                                        : AppTheme.textSecondary(context),
                                    fontSize: 13)),
                          ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            gradient: isDark
                                ? const LinearGradient(
                                    colors: [
                                        Color(0xFF11192B),
                                        Color(0xFF0D1424)
                                      ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight)
                                : const LinearGradient(
                                    colors: [
                                        Color(0xFFFFFFFF),
                                        Color(0xFFF8FAFC)
                                      ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.10)
                                    : AppTheme.glassStroke(context)),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 10),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const _CircleBadge(
                                      icon: Icons.discount_outlined,
                                      color: Colors.lightBlueAccent,
                                      diameter: 24),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Text(
                                          'Rabatt bei längerer Mietdauer',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors.white
                                                  : AppTheme.textPrimary(
                                                      context),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15))),
                                  Transform.scale(
                                    scale: 0.7,
                                    alignment: Alignment.centerRight,
                                    child: Switch.adaptive(
                                      value: _autoApplyDiscounts,
                                      onChanged: (v) => setState(
                                          () => _autoApplyDiscounts = v),
                                      activeColor: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('Rabatt aktiv',
                                      style: TextStyle(
                                          color: _autoApplyDiscounts
                                              ? (isDark
                                                  ? Colors.white
                                                  : AppTheme.textBody(context))
                                              : (isDark
                                                  ? Colors.white54
                                                  : AppTheme.textDisabled(
                                                      context)),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11)),
                                ]),
                                const SizedBox(height: 6),
                                if (_autoApplyDiscounts) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6, horizontal: 4),
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                              child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text('Mietdauer',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white60
                                                        : AppTheme
                                                            .textSecondary(
                                                                context),
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          )),
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.center,
                                              child: Text('Rabatt',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      color: isDark
                                                          ? Colors.white60
                                                          : AppTheme
                                                              .textSecondary(
                                                                  context),
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ),
                                          ),
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Text('Preis pro Tag',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                      color: isDark
                                                          ? Colors.white60
                                                          : AppTheme
                                                              .textSecondary(
                                                                  context),
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ),
                                          ),
                                        ]),
                                  ),
                                  _ThresholdDiscountRow(
                                    key: ValueKey(
                                        'tier1_' + _strategyEpoch.toString()),
                                    days: _tier1Days,
                                    percent: _tier1Pct,
                                    pricePerDay: double.tryParse(_priceCtrl.text
                                            .replaceAll(',', '.')) ??
                                        0.0,
                                    onDaysChanged: (v) => setState(() {
                                      _tier1Days = v;
                                      _discountsTouched = true;
                                    }),
                                    onPercentChanged: (v) => setState(() {
                                      _tier1Pct = v;
                                      _tier1PctEmpty = false;
                                      _discountsTouched = true;
                                    }),
                                    onPercentEmptyChanged: (isEmpty) =>
                                        setState(() {
                                      _tier1PctEmpty = isEmpty;
                                    }),
                                  ),
                                  const SizedBox(height: 6),
                                  _ThresholdDiscountRow(
                                    key: ValueKey(
                                        'tier2_' + _strategyEpoch.toString()),
                                    days: _tier2Days,
                                    percent: _tier2Pct,
                                    pricePerDay: double.tryParse(_priceCtrl.text
                                            .replaceAll(',', '.')) ??
                                        0.0,
                                    onDaysChanged: (v) => setState(() {
                                      _tier2Days = v;
                                      _discountsTouched = true;
                                    }),
                                    onPercentChanged: (v) => setState(() {
                                      _tier2Pct = v;
                                      _tier2PctEmpty = false;
                                      _discountsTouched = true;
                                    }),
                                    onPercentEmptyChanged: (isEmpty) =>
                                        setState(() {
                                      _tier2PctEmpty = isEmpty;
                                    }),
                                  ),
                                  const SizedBox(height: 6),
                                  _ThresholdDiscountRow(
                                    key: ValueKey(
                                        'tier3_' + _strategyEpoch.toString()),
                                    days: _tier3Days,
                                    percent: _tier3Pct,
                                    pricePerDay: double.tryParse(_priceCtrl.text
                                            .replaceAll(',', '.')) ??
                                        0.0,
                                    onDaysChanged: (v) => setState(() {
                                      _tier3Days = v;
                                      _discountsTouched = true;
                                    }),
                                    onPercentChanged: (v) => setState(() {
                                      _tier3Pct = v;
                                      _tier3PctEmpty = false;
                                      _discountsTouched = true;
                                    }),
                                    onPercentEmptyChanged: (isEmpty) =>
                                        setState(() {
                                      _tier3PctEmpty = isEmpty;
                                    }),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(children: [
                                    const Icon(Icons.autorenew,
                                        color: Colors.lightBlueAccent,
                                        size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                        child: Text(
                                            'Rabatte greifen automatisch in Preisvorschauen.',
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? Colors.white70
                                                    : AppTheme.textSecondary(
                                                        context),
                                                fontSize: 13)))
                                  ]),
                                ],
                              ]),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            gradient: isDark
                                ? const LinearGradient(
                                    colors: [
                                        Color(0xFF0F1C33),
                                        Color(0xFF0B1527)
                                      ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight)
                                : const LinearGradient(
                                    colors: [
                                        Color(0xFFF0F9FF),
                                        Color(0xFFE0F2FE)
                                      ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: isDark
                                    ? Colors.lightBlueAccent
                                        .withValues(alpha: 0.30)
                                    : AppTheme.glassStroke(context)),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  _CircleBadge(
                                      icon: Icons.lightbulb_outline,
                                      color: Colors.lightBlueAccent,
                                      diameter: 32,
                                      backgroundAlpha: 0.18),
                                  SizedBox(width: 10),
                                  Text('SIT-Tipp',
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.lightBlueAccent
                                              : colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16))
                                ]),
                                SizedBox(height: 8),
                                Text(
                                    'Für ähnliche Objekte in dieser Kategorie sind Rabatte wie oben angegeben zu empfehlen, um Mietfrequenz und Mietdauer zu erhöhen. Du kannst den Preis und die Staffelung anpassen oder komplett deaktivieren.',
                                    style: TextStyle(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white70
                                            : AppTheme.textSecondary(context),
                                        fontSize: 13.5,
                                        height: 1.45))
                              ]),
                        ),
                      ]),
                ),
                // Preis-Section Ende – ab hier Inhalte außerhalb der Preis-Karte
                // Stornierungsbedingungen außerhalb der Preis-Karte und oberhalb des Erstellen-Buttons
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.20)
                        : AppTheme.surfacePrimary(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : AppTheme.glassStroke(context)),
                  ),
                  child: _OwnerCancellationInfoCard(
                      body: CancellationPolicyText.bodyForOwnerListingCard),
                ),
                const SizedBox(height: 20),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _submit(),
                        icon: const Icon(Icons.add_business),
                        label: Text(_isEdit
                            ? 'Anzeige veröffentlichen'
                            : 'Anzeige erstellen'),
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            textStyle: const TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 16)),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _submit(forceInactive: true),
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_isEdit
                            ? 'Bearbeitung speichern'
                            : 'Für später speichern'),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            foregroundColor: isDark
                                ? Colors.white
                                : AppTheme.textBody(context),
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF8FAFC),
                            side: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : AppTheme.glassStroke(context)),
                            textStyle: const TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 15)),
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

Color _listingPanelSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFFFFFFF);

Color _listingPanelBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.16)
        : const Color(0xFFE2E8F0);

class _ConditionPager extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _ConditionPager({required this.selected, required this.onChanged});
  @override
  State<_ConditionPager> createState() => _ConditionPagerState();
}

class _ConditionPagerState extends State<_ConditionPager> {
  static const List<String> _labels = [
    'Wie neu',
    'Gut gepflegt',
    'Normale Gebrauchsspuren',
    'Stark gebraucht'
  ];
  static const List<String> _keys = ['like-new', 'good', 'acceptable', 'worn'];
  bool _expanded = false;

  int _indexFor(String sel) {
    switch (sel) {
      case 'like-new':
        return 0;
      case 'good':
        return 1;
      case 'acceptable':
        return 2;
      case 'worn':
        return 3;
      case 'new':
        return 0;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedIndex = _indexFor(widget.selected);
    final selectedLabel = _labels[selectedIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _listingPanelSurface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _listingPanelBorder(context)),
            ),
            child: Row(children: [
              Expanded(
                  child: Text(selectedLabel,
                      style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : AppTheme.textPrimary(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 15.5))),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: Icon(Icons.expand_more,
                    color: isDark
                        ? Colors.white70
                        : AppTheme.textSecondary(context)),
              ),
            ]),
          ),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: _expanded
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                    children: List.generate(_labels.length, (i) {
                  final selected = i == selectedIndex;
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: i == _labels.length - 1 ? 0 : 8),
                    child: _ConditionOption(
                        label: _labels[i],
                        selected: selected,
                        onTap: () => widget.onChanged(_keys[i])),
                  );
                })),
              )
            : const SizedBox.shrink(),
      ),
    ]);
  }
}

class _ConditionOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ConditionOption(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.10)
              : _listingPanelSurface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : _listingPanelBorder(context)),
        ),
        child: Row(children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected
                ? colorScheme.primary
                : (isDark ? Colors.white70 : AppTheme.textSecondary(context)),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.textBody(context),
                      fontWeight: FontWeight.w500,
                      fontSize: 15))),
        ]),
      ),
    );
  }
}

class _CityAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String? initialValue;
  final ValueChanged<String> onChanged;
  const _CityAutocompleteField(
      {required this.controller,
      required this.initialValue,
      required this.onChanged});
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
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
          child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Text('Größstädte',
              style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppTheme.textPrimary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
          const SizedBox(height: 8),
          SizedBox(
            height: 360,
            child: ListView.separated(
              itemBuilder: (context, i) {
                final name = _cities[i];
                return ListTile(
                    title: Text(name,
                        style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : AppTheme.textBody(context),
                            fontSize: 15)),
                    onTap: () => Navigator.of(context).pop(name));
              },
              separatorBuilder: (_, __) =>
                  const Divider(color: Colors.white12, height: 1),
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
          style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : AppTheme.textBody(context),
              fontSize: 15),
          decoration: InputDecoration(
              labelText: 'Stadt',
              suffixIcon: IconButton(
                  onPressed: _showAllCities,
                  icon: Icon(Icons.arrow_drop_down,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppTheme.textSecondary(context)))),
          onChanged: widget.onChanged,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Stadt ist erforderlich' : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final opts = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : AppTheme.surfacePrimary(context),
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 280),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: opts.length,
                separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white12
                        : const Color(0xFFE2E8F0)),
                itemBuilder: (context, index) {
                  final opt = opts[index];
                  return ListTile(
                    dense: true,
                    title: Text(opt,
                        style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : AppTheme.textBody(context),
                            fontSize: 14.5)),
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

class _CircleBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double diameter;
  final double backgroundAlpha;
  const _CircleBadge(
      {required this.icon,
      required this.color,
      this.diameter = 36,
      this.backgroundAlpha = 0.14});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: backgroundAlpha),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Icon(icon, color: color, size: diameter * 0.58),
    );
  }
}

class _PricePerDayInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? Function(String?)? validator;
  const _PricePerDayInput(
      {required this.controller,
      required this.onChanged,
      required this.validator});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
        controller: controller,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: false),
        style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : AppTheme.textPrimary(context),
            fontWeight: FontWeight.w700,
            fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.euro,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : AppTheme.textSecondary(context),
              size: 18),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 38, minHeight: 24),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text('pro Tag',
                style: TextStyle(
                    color: isDark
                        ? Colors.white60
                        : AppTheme.textSecondary(context),
                    fontWeight: FontWeight.w500,
                    fontSize: 14)),
          ),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 72, minHeight: 24),
          hintText: '0,00',
          hintStyle: TextStyle(
              color: isDark ? Colors.white38 : AppTheme.textDisabled(context),
              fontWeight: FontWeight.w500),
          filled: true,
          fillColor: _listingPanelSurface(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _listingPanelBorder(context))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.8))),
        ),
        onChanged: onChanged,
        validator: validator,
      ),
    ]);
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  const _Section(
      {required this.title, required this.child, this.leading, this.trailing});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.30)
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppTheme.glassStroke(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (leading == null && trailing == null)
          Text(title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppTheme.textPrimary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 16))
        else
          Row(children: [
            if (leading != null) leading!,
            if (leading != null) const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : AppTheme.textPrimary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 16))),
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
    return Semantics(
      button: true,
      label: 'Foto hinzufügen',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: _listingPanelSurface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _listingPanelBorder(context),
                style: BorderStyle.solid,
                width: 1),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.add_a_photo,
              color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}

// Compact toggle tile with a blue circular indicator (no check glyph)
// _BlueDotToggleTile removed in favor of shared ToggleTextOption for consistent design.

class _PickedThumb extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;
  const _PickedThumb({required this.file, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      InkWell(
        onTap: () async {
          final bytes = await file.readAsBytes();
          showDialog(
              context: context,
              builder: (_) => Dialog(
                    insetPadding: const EdgeInsets.all(16),
                    backgroundColor: Colors.black,
                    child: InteractiveViewer(
                        child: Image.memory(bytes, fit: BoxFit.contain)),
                  ));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: _listingPanelSurface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _listingPanelBorder(context)),
          ),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done ||
                  !snap.hasData) {
                return const Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)));
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
            decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.6)
                    : AppTheme.surfacePrimary(context),
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.close,
                size: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppTheme.textPrimary(context)),
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
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(Icons.circle,
              size: 6,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : AppTheme.textSecondary(context)),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : AppTheme.textSecondary(context),
                    fontSize: 13.5))),
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
    this.initiallyExpanded = false,
    this.bare = false,
    this.centerTitle = false,
    this.headerPadding,
    this.bodyPadding,
  });
  @override
  State<_Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<_Accordion>
    with SingleTickerProviderStateMixin {
  late bool _expanded = widget.initiallyExpanded;
  @override
  Widget build(BuildContext context) {
    final titleStyle = widget.bare
        ? TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : AppTheme.textSecondary(context),
            fontWeight: FontWeight.w600,
            fontSize: 13.5)
        : TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : AppTheme.textPrimary(context),
            fontWeight: FontWeight.w600,
            fontSize: 15.5);

    final header = InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(widget.bare ? 8 : 12),
      child: Padding(
        padding: widget.headerPadding ??
            EdgeInsets.symmetric(
                horizontal: widget.bare ? 0 : 12, vertical: 12),
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
                child: Icon(Icons.expand_more,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : AppTheme.textSecondary(context)),
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
          padding: widget.bodyPadding ??
              EdgeInsets.fromLTRB(
                  widget.bare ? 0 : 12, 0, widget.bare ? 0 : 12, 12),
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
        color: _listingPanelSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _listingPanelBorder(context)),
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
  State<_OwnerCancellationInfoCard> createState() =>
      _OwnerCancellationInfoCardState();
}

class _OwnerCancellationInfoCardState
    extends State<_OwnerCancellationInfoCard> {
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
                Icon(Icons.policy_outlined,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : AppTheme.textSecondary(context)),
                const SizedBox(width: 8),
                Text('Stornierungsbedingungen',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15.5,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : AppTheme.textPrimary(context))),
              ]),
            ),
          ),
        ),
        AnimatedCrossFade(
          crossFadeState:
              _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(widget.body,
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : AppTheme.textSecondary(context),
                    fontSize: 13,
                    height: 1.4)),
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
  const _PlaceDetails(
      {this.formattedAddress, this.lat, this.lng, required this.description});
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
          style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : AppTheme.textBody(context),
              fontSize: 15),
          decoration: InputDecoration(
              prefixIcon: Icon(Icons.search,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : AppTheme.textSecondary(context)),
              hintText: 'Übergabeort eingeben'),
          onChanged: onQueryChanged,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : AppTheme.surfacePrimary(context),
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
                    leading: Icon(Icons.place_outlined,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : AppTheme.textSecondary(context)),
                    title: Text(s.description,
                        style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : AppTheme.textBody(context))),
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
                separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white12
                        : const Color(0xFFE2E8F0)),
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
  final uri =
      Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
    'input': input,
    'types': 'address',
    'language': 'de',
    'components': 'country:de',
    'key': kGoogleMapsApiKey,
  });
  try {
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('gmaps_unavailable');
    final data = json.decode(utf8.decode(res.bodyBytes));
    final status = (data['status'] ?? '').toString();
    if (status != 'OK') {
      if (status == 'ZERO_RESULTS') return const [];
      throw Exception('gmaps_unavailable');
    }
    final preds = (data['predictions'] as List?) ?? [];
    return preds
        .map<_PlaceSuggestion>((p) => _PlaceSuggestion(
            description: p['description'], placeId: p['place_id']))
        .toList();
  } catch (_) {
    // Propagate unavailability so UI can show a friendly fallback message.
    throw Exception('gmaps_unavailable');
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
    return _PlaceDetails(
        formattedAddress: addr, lat: lat, lng: lng, description: addr ?? '');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF111C2F), Color(0xFF0C1424)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : const LinearGradient(
                colors: [Color(0xFFF8FCFF), Color(0xFFF0F9FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark
                ? Colors.lightBlueAccent.withValues(alpha: 0.18)
                : const Color(0xFFBAE6FD)),
        boxShadow: [
          BoxShadow(
              color: isDark
                  ? Colors.lightBlueAccent.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const _CircleBadge(
              icon: Icons.auto_awesome,
              color: Colors.lightBlueAccent,
              diameter: 28,
              backgroundAlpha: 0.22),
          SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('KI-Preisberechnung',
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : AppTheme.textPrimary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                SizedBox(height: 4),
                Text(
                    'Bitte fülle Titel, Kategorie und Übergabeort aus, um eine Preisempfehlung zu erhalten.',
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : AppTheme.textSecondary(context),
                        fontSize: 13,
                        height: 1.35))
              ])),
        ]),
        if (canCalculate && suggestion == null) ...[
          const SizedBox(height: 8),
          Text('Berechne Preisvorschlag…',
              style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : AppTheme.textSecondary(context),
                  fontSize: 13)),
        ],
        if (suggestion != null) ...[
          const SizedBox(height: 9),
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
          const SizedBox(height: 9),
          // Price suggestions
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFDBEAFE)),
            ),
            padding: const EdgeInsets.all(9),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.calendar_today,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : AppTheme.textSecondary(context),
                    size: 14),
                const SizedBox(width: 4),
                Text('Aktueller Marktpreis (€/Tag):',
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : AppTheme.textSecondary(context),
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5)),
                const Spacer(),
                Text(
                    '${suggestion!.dailyPriceMin.toStringAsFixed(0)}–${suggestion!.dailyPriceMax.toStringAsFixed(0)} €',
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : AppTheme.textPrimary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5)),
              ]),
            ]),
          ),
          const SizedBox(height: 9),
          // Mode-specific helper text
          Builder(builder: (context) {
            final help = strategy == 'quick'
                ? 'Preis im unteren Marktbereich – erhöht die Buchungswahrscheinlichkeit.'
                : 'Preis im oberen Marktbereich – optimiert Ertrag pro Vermietung.';
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline,
                  color:
                      isDark ? Colors.white54 : AppTheme.textSecondary(context),
                  size: 14),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(help,
                      style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : AppTheme.textSecondary(context),
                          fontSize: 13,
                          height: 1.35))),
            ]);
          }),
          const SizedBox(height: 7),
          // Reasoning
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline,
                color:
                    isDark ? Colors.white54 : AppTheme.textSecondary(context),
                size: 14),
            const SizedBox(width: 4),
            Expanded(
                child: Text(suggestion!.reasoning,
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : AppTheme.textSecondary(context),
                        fontSize: 13,
                        height: 1.35))),
          ]),
          const SizedBox(height: 7),
          // Optimization tip
          Container(
            decoration: BoxDecoration(
              color: Colors.lightBlueAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.lightBlueAccent.withValues(alpha: 0.3)),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lightbulb_outline,
                  color: Colors.lightBlueAccent, size: 14),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(suggestion!.optimizationTip,
                      style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : AppTheme.textBody(context),
                          fontSize: 13,
                          height: 1.35))),
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
  const _StrategyChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? Colors.lightBlueAccent
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected
                  ? Colors.lightBlueAccent
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : AppTheme.glassStroke(context))),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              color: selected
                  ? Colors.black
                  : (isDark ? Colors.white70 : AppTheme.textSecondary(context)),
              size: 14),
          const SizedBox(width: 5),
          Expanded(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: selected
                          ? Colors.black
                          : (isDark
                              ? Colors.white70
                              : AppTheme.textBody(context)),
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5))),
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
  const _DiscountRow(
      {required this.label,
      required this.value,
      required this.onChanged,
      this.enabled = true});
  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(
        text: value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1));
    return Row(children: [
      SizedBox(
          width: 140,
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w600))),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: ctrl,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
              suffixText: '%', labelText: 'Rabatt', isDense: true),
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
  final int days;
  final double percent;
  final double pricePerDay;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<double> onPercentChanged;
  final ValueChanged<bool>? onPercentEmptyChanged;
  const _ThresholdDiscountRow(
      {super.key,
      required this.days,
      required this.percent,
      required this.pricePerDay,
      required this.onDaysChanged,
      required this.onPercentChanged,
      this.onPercentEmptyChanged});
  @override
  State<_ThresholdDiscountRow> createState() => _ThresholdDiscountRowState();
}

class _ThresholdDiscountRowState extends State<_ThresholdDiscountRow> {
  late final TextEditingController _daysCtrl =
      TextEditingController(text: widget.days.toString());
  late final TextEditingController _pctCtrl =
      TextEditingController(text: _formatPercent(widget.percent));
  late final FocusNode _daysFocus = FocusNode();
  late final FocusNode _pctFocus = FocusNode();

  String _formatPercent(double v) =>
      v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

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
    final primary = Colors.lightBlueAccent;
    final discountedPerDay = (widget.pricePerDay * (1 - widget.percent / 100))
        .clamp(0.0, double.infinity)
        .toDouble();
    final discountedText =
        '${discountedPerDay.toStringAsFixed(2).replaceAll('.', ',')} € / Tag';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Row(children: [
            Text('Ab',
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : AppTheme.textSecondary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const SizedBox(width: 4),
            IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 13, maxWidth: 42),
                child: TextField(
                  controller: _daysCtrl,
                  focusNode: _daysFocus,
                  cursorColor: primary,
                  keyboardType: const TextInputType.numberWithOptions(
                      signed: false, decimal: false),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                  textAlign: TextAlign.left,
                  decoration: InputDecoration(
                      isDense: true,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      hintText: '0',
                      hintStyle: TextStyle(
                          color: primary.withOpacity(0.35), fontSize: 14)),
                  onChanged: (v) {
                    final n = int.tryParse(v.replaceAll(',', '.'));
                    if (n != null) widget.onDaysChanged(n.clamp(1, 365));
                  },
                ),
              ),
            ),
            const SizedBox(width: 2),
            Text('Tagen',
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : AppTheme.textSecondary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ]),
        ),
        Expanded(
          child: Center(
            child: SizedBox(
              width: 73,
              child: TextField(
                controller: _pctCtrl,
                focusNode: _pctFocus,
                keyboardType: const TextInputType.numberWithOptions(
                    signed: false, decimal: false),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : AppTheme.textPrimary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFFFFFFF),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.16)
                              : const Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide:
                          BorderSide(color: primary.withValues(alpha: 0.9))),
                  suffixText: '%',
                  suffixStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : AppTheme.textSecondary(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  hintText: '0',
                  hintStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white38
                          : AppTheme.textDisabled(context),
                      fontSize: 13),
                ),
                onChanged: (v) {
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  widget.onPercentEmptyChanged?.call(v.trim().isEmpty);
                  if (n != null) {
                    widget.onPercentChanged(n.clamp(0.0, 95.0).toDouble());
                  }
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                  width: 1,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.18)
                      : const Color(0xFFE2E8F0)),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(discountedText,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : AppTheme.textPrimary(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
              )
            ],
          ),
        )
      ]),
    );
  }
}
