import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lendify/models/category.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/user.dart' as model;
import 'package:lendify/services/data_service.dart';
import 'package:lendify/widgets/search_header.dart';
import 'package:lendify/widgets/category_icon_row.dart';
import 'package:lendify/widgets/home_banner_card.dart';
import 'package:lendify/widgets/search_overlay.dart';
import 'package:lendify/widgets/all_categories_overlay.dart';
import 'package:lendify/widgets/filters_overlay.dart';
import 'package:lendify/widgets/item_details_overlay.dart';
import 'package:lendify/screens/owner_requests_screen.dart';
import 'package:lendify/screens/see_all_screen.dart';
import 'package:lendify/screens/bookings_screen.dart';
import 'package:lendify/screens/profile_screen.dart';
import 'package:lendify/screens/my_listings_screen.dart';
import 'package:provider/provider.dart';
import 'package:lendify/widgets/wishlist_selection_sheet.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/screens/explore_screen_pinned_header.dart';
import 'package:lendify/widgets/scroll_edge_indicators.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/widgets/app_popup.dart';

class ExploreScreen extends StatefulWidget {
const ExploreScreen({super.key});
@override
State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
final ScrollController _scrollController = ScrollController();
  final PageController _pageTopBooked = PageController(viewportFraction: 1);
  final ScrollController _ctrlNeue = ScrollController();
  final ScrollController _ctrlGuests = ScrollController();

List<Item> _items = [];
List<Category> _categories = [];
// Map fine category id -> coarse/top-level category label
Map<String, String> _coarseByCatId = {};
Map<String, model.User> _usersById = {};
bool _isLoading = true;
String? _currentUserName;
String? _currentUserCity;
Set<String> _savedIds = {};

// Extra curated cards with fresh images (used for Guests row)
List<Item> _extraGuests = [];
// Extra curated cards for "Am meisten gebucht" to add two full rows (3 under 3)
List<Item> _extraTopBooked = [];


Map<String, dynamic>? _filters;

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

// Coarse/top-level category icon mapping
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

// Build the top-level categories in fixed order for the home header
List<CategoryIconDataModel> get _homeCategories => [
  for (final label in DataService.coarseCategoryOrder)
    CategoryIconDataModel(id: label, icon: _coarseIconForGroup(label), label: label)
];


@override
void initState() {
super.initState();
_loadData();
}

  @override
  void dispose() {
    _scrollController.dispose();
    _pageTopBooked.dispose();
    _ctrlNeue.dispose();
    _ctrlGuests.dispose();
    super.dispose();
  }

Future<void> _loadData() async {
try {
final items = await DataService.getPublicItems();
final categories = await DataService.getCategories();
final users = await DataService.getUsers();
final user = await DataService.getCurrentUser();
final saved = await DataService.getSavedItemIds();

// Build extra curated items with unique images for Guests row
List<Item> buildExtras(int count, String seedPrefix) {
final berlin = DataService.getCities()['Berlin'] ?? (52.52, 13.405);
final owner = users.isNotEmpty ? users.first : null;
final rnd = Random(seedPrefix.hashCode);
return [
for (int i = 0; i < count; i++)
Item(
id: '${seedPrefix}_$i',
ownerId: owner?.id ?? 'u1',
title: 'Neu ${i + 1}',
description: 'Frisch eingestellt in Berlin',
categoryId: categories.isNotEmpty ? categories[rnd.nextInt(categories.length)].id : 'cat1',
subcategory: 'Highlights',
tags: const ['highlight', 'neu'],
pricePerDay: 10 + rnd.nextInt(60) + rnd.nextDouble(),
currency: 'EUR',
deposit: null,
photos: ['https://picsum.photos/seed/${seedPrefix}_$i/800/800'],
locationText: 'Berlin-Mitte',
lat: berlin.$1,
lng: berlin.$2,
geohash: 'u130f$i',
condition: 'new',
minDays: null,
maxDays: 7,
createdAt: DateTime.now().subtract(Duration(hours: i)),
isActive: true,
verificationStatus: 'approved',
city: 'Berlin',
country: 'Deutschland',
)
];
}

// No extra fillers for the five-item showcase
final extrasGuests = <Item>[];
final extrasTop = <Item>[];

 // Precompute mapping: fine category id -> coarse label for filters and display
 final coarseMap = <String, String>{
   for (final c in categories) c.id: DataService.coarseCategoryFor(c.name)
 };
 setState(() {
   _items = items;
   _categories = categories;
   _coarseByCatId = coarseMap;
   _usersById = {for (final u in users) u.id: u};
   _currentUserName = user?.displayName;
   _currentUserCity = user?.city ?? 'Berlin';
   _savedIds = saved;
   _extraGuests = extrasGuests;
   _extraTopBooked = extrasTop;
   _isLoading = false;
 });
      // After data is loaded, check if we have a freshly created/saved listing event to show a popup
      final ev = DataService.takeLastCreateEvent();
      if (ev != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCreatedPopup(ev.$1, ev.$2);
        });
      }
} catch (e) {
setState(() => _isLoading = false);
}
}

  Future<void> _showCreatedPopup(Item item, bool draft) async {
    final message = draft ? 'Anzeige wurde für später gespeichert' : 'Anzeige wurde erstellt';
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black.withValues(alpha: 0.90),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.check_circle, color: Colors.lightGreenAccent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
                    IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white70)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    draft ? 'Du findest den Entwurf unter „Meine Anzeigen“.' : 'Deine Anzeige ist jetzt sichtbar.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.check),
                        label: const Text('Schließen'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.of(context).maybePop();
                          await Future<void>.delayed(const Duration(milliseconds: 50));
                          if (!mounted) return;
                          ItemDetailsOverlay.showFullPage(context, item: item);
                        },
                        icon: const Icon(Icons.visibility),
                        label: Text(draft ? 'Vorschau ansehen' : 'Anzeige ansehen'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleListingCreated(Item created) async {
    await _loadData();
    if (!mounted) return;
    final l10n = context.read<LocalizationController>();
    await AppPopup.show(
      context,
      icon: Icons.check_circle_outline,
      title: l10n.t('Anzeige veröffentlicht'),
      actions: [
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).maybePop();
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyListingsScreen()));
          },
          icon: const Icon(Icons.dashboard_customize_outlined),
          label: Text(l10n.t('Meine Anzeigen')),
        ),
      ],
    );
  }

Future<void> _showFilters() async {
final result = await FiltersOverlay.show(context, initial: _filters);
if (result != null) setState(() => _filters = result);
}

void _openSearch() => SearchOverlay.show(context);

void _openAllCategories() {
final l10n = context.read<LocalizationController>();
final cats = _homeCategories.map((e) => CategoryChipData(id: e.id, label: l10n.t(e.label), icon: e.icon)).toList();
AllCategoriesOverlay.show(context, cats);
}

Future<bool?> _showCategoryConfirm(String label) {
final l10n = context.read<LocalizationController>();
return showModalBottomSheet<bool>(
context: context,
isScrollControlled: false,
backgroundColor: Colors.transparent,
barrierColor: Colors.black.withValues(alpha: 0.25),
shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
builder: (_) {
return SafeArea(
top: false,
child: Center(
child: Container(
decoration: BoxDecoration(
color: Colors.black.withValues(alpha: 0.34),
borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
),
padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
child: Column(mainAxisSize: MainAxisSize.min, children: [
Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
const SizedBox(height: 12),
Row(children: [
Container(
decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
padding: const EdgeInsets.all(10),
child: const Icon(Icons.category, color: Colors.white),
),
const SizedBox(width: 12),
Expanded(child: Text(l10n.t('Kategorie auswählen'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
IconButton(onPressed: () => Navigator.of(context).pop(false), icon: const Icon(Icons.close, color: Colors.white70))
]),
const SizedBox(height: 8),
Text('${l10n.t('Gefiltert nach:')} $label', style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
const SizedBox(height: 16),
Row(children: [
Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(context).pop(false), icon: const Icon(Icons.arrow_back), label: Text(l10n.t('Abbrechen')))),
const SizedBox(width: 12),
Expanded(child: FilledButton.icon(onPressed: () => Navigator.of(context).pop(true), icon: const Icon(Icons.check_circle), label: Text(l10n.t('Bestätigen')))),
])
]),
),
),
);
},
);
}

Future<void> _openLocationUpdate() async {
final list = DataService.getCities().keys.toList();
final cities = ['Automatisch', ...list];
final selected = await showModalBottomSheet<String>(
context: context,
backgroundColor: Colors.black.withValues(alpha: 0.7),
shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
builder: (context) => SafeArea(
child: Column(mainAxisSize: MainAxisSize.min, children: [
const SizedBox(height: 12),
Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
const SizedBox(height: 12),
Text('Standort aktualisieren', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
const SizedBox(height: 8),
ConstrainedBox(
constraints: const BoxConstraints(maxHeight: 420),
child: ListView.separated(
shrinkWrap: true,
itemCount: cities.length,
separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
itemBuilder: (context, i) {
final c = cities[i];
return ListTile(
leading: c == 'Automatisch' ? const Icon(Icons.my_location, color: Colors.white70) : const SizedBox.shrink(),
title: Text(c, style: const TextStyle(color: Colors.white)),
trailing: (_currentUserCity == c) ? const Icon(Icons.check, color: Colors.lightBlueAccent) : null,
onTap: () => Navigator.of(context).pop(c),
);
},
),
),
const SizedBox(height: 12),
]),
),
);
if (selected == null || selected.isEmpty) return;

if (selected == 'Automatisch') {
await _useAutomaticLocation();
return;
}

await _persistCity(selected);
}

Future<void> _persistCity(String selected) async {
setState(() => _currentUserCity = selected);
final user = await DataService.getCurrentUser();
  if (user != null) {
final updated = model.User(
id: user.id,
displayName: user.displayName,
email: user.email,
phone: user.phone,
photoURL: user.photoURL,
bio: user.bio,
city: selected,
country: user.country,
preferredLanguage: user.preferredLanguage,
isVerified: user.isVerified,
isBanned: user.isBanned,
role: user.role,
payoutAccountId: user.payoutAccountId,
avgRating: user.avgRating,
reviewCount: user.reviewCount,
createdAt: user.createdAt,
languages: user.languages,
interests: user.interests,
);
await DataService.setCurrentUser(updated);
if (!mounted) return;
  AppPopup.toast(context, icon: Icons.place, title: 'Standort aktualisiert: $selected');
}
}

Future<void> _useAutomaticLocation() async {
try {
LocationPermission perm = await Geolocator.checkPermission();
if (perm == LocationPermission.denied) {
perm = await Geolocator.requestPermission();
}
if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
  if (!mounted) return;
  AppPopup.toast(context, icon: Icons.location_off, title: 'Standortzugriff verweigert.', message: 'Bitte erlaube den Zugriff in den Einstellungen.');
return;
}
final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
final nearest = DataService.nearestCityName(pos.latitude, pos.longitude);
await _persistCity(nearest);
} catch (e) {
if (!mounted) return;
  AppPopup.toast(context, icon: Icons.location_disabled, title: 'Standort konnte nicht ermittelt werden.');
}
}

Future<void> _toggleFavorite(String id) async {
  final current = await DataService.getWishlistForItem(id);
  if (current == null) {
    final sel = await WishlistSelectionSheet.showAdd(context);
    if (sel != null && sel.isNotEmpty) {
      await DataService.setItemWishlist(id, sel);
    }
  } else {
    final choice = await WishlistSelectionSheet.showManageOptions(context);
    if (choice == 'move') {
      final sel = await WishlistSelectionSheet.showMove(context, currentListId: current);
      if (sel != null && sel.isNotEmpty) {
        await DataService.setItemWishlist(id, sel);
      }
    } else if (choice == 'remove') {
      await DataService.removeItemFromWishlist(id);
    }
  }
  final saved = await DataService.getSavedItemIds();
  if (!mounted) return;
  setState(() => _savedIds = saved);
}

bool _matches(Item it) {
  final f = _filters;
  final RangeValues price = f?['price'] ?? const RangeValues(0, 500);
  final String priceUnit = f?['priceUnit'] ?? 'day';
  final double maxDistance = (f?['distance'] as double?) ?? 100;
  final bool verifiedOnly = f?['verified'] == true;
  final String condition = (f?['condition'] as String?) ?? 'egal';
  // Now stores coarse/top-level category labels (not fine-grained IDs)
  final List<String> catGroups = (f?['categories'] as List<String>?) ?? const [];
  final double minRating = (f?['minRating'] as double?) ?? 0;
    final List<String> delivery = (f?['delivery'] as List<String>?) ?? const [];

  final double minPerDay = priceUnit == 'week' ? price.start / 7 : price.start;
  final double maxPerDay = priceUnit == 'week' ? price.end / 7 : price.end;
  if (it.pricePerDay < minPerDay || it.pricePerDay > maxPerDay) return false;
  if (verifiedOnly) {
    final ok = it.verificationStatus == 'approved' || it.verificationStatus == 'verified';
    if (!ok) return false;
  }
  if (condition != 'egal') {
    String mapped;
    switch (condition) {
      case 'neu': mapped = 'new'; break;
      case 'wie-neu': mapped = 'like-new'; break;
      case 'gut': mapped = 'good'; break;
      case 'akzeptabel': mapped = 'acceptable'; break;
      default: mapped = condition; break;
    }
    if (it.condition != mapped) return false;
  }
  if (catGroups.isNotEmpty) {
    final g = _coarseByCatId[it.categoryId] ?? '';
    if (!catGroups.contains(g)) return false;
  }
    if (delivery.isNotEmpty) {
      bool matchesAny = false;
      for (final opt in delivery) {
        switch (opt) {
          case 'dropoff':
            matchesAny = matchesAny || it.offersDeliveryAtDropoff;
            break;
          case 'pickup':
            matchesAny = matchesAny || it.offersPickupAtReturn;
            break;
          case 'express':
            matchesAny = matchesAny || it.offersExpressAtDropoff;
            break;
        }
        if (matchesAny) break;
      }
      if (!matchesAny) return false;
    }
  final d = _distanceFromUserKm(it);
  if (d != null && d > maxDistance) return false;
  final ownerRating = _usersById[it.ownerId]?.avgRating ?? 0.0;
  if (ownerRating < minRating) return false;
  return true;
}

List<Item> get _filteredItems {
  final src = [..._items];
  if (_filters == null) return _sorted(src);
  final filtered = src.where(_matches).toList();
  return _sorted(filtered);
}


List<Item> _sorted(List<Item> list) {
final sort = _filters?['sort'] as String? ?? 'Preis';
switch (sort) {
case 'Preis':
final order = (_filters?['priceOrder'] as String?) ?? 'asc';
list.sort((a, b) => a.pricePerDay.compareTo(b.pricePerDay));
if (order == 'desc') {
  list = list.reversed.toList();
}
break;
case 'Bewertung':
double ratingOf(String ownerId) => _usersById[ownerId]?.avgRating ?? 0.0;
list.sort((a, b) => ratingOf(b.ownerId).compareTo(ratingOf(a.ownerId)));
break;
case 'Neueste':
list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
break;
case 'Entfernung':
default:
double dist(Item i) => _distanceFromUserKm(i) ?? double.infinity;
list.sort((a, b) => dist(a).compareTo(dist(b)));
break;
}
return list;
}

double? _distanceFromUserKm(Item item) {
final cities = DataService.getCities();
final city = _currentUserCity ?? 'Berlin';
final origin = cities[city];
if (origin == null) return null;
return _haversine(origin.$1, origin.$2, item.lat, item.lng);
}

double _haversine(double lat1, double lon1, double lat2, double lon2) {
const R = 6371.0;
double dLat = _deg2rad(lat2 - lat1);
double dLon = _deg2rad(lon2 - lon1);
double a =
sin(dLat / 2) * sin(dLat / 2) + cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
double c = 2 * atan2(sqrt(a), sqrt(1 - a));
return R * c;
}

double _deg2rad(double deg) => deg * (pi / 180.0);

@override
Widget build(BuildContext context) {
final itemsFiltered = _filteredItems;
final now = DateTime.now();
final latest = [...itemsFiltered]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
final recent = latest.where((e) => e.createdAt.isAfter(now.subtract(const Duration(days: 14)))).toList();
final neueQuelle = (recent.isNotEmpty ? recent : latest);

return Scaffold(
backgroundColor: Colors.transparent,
body: SafeArea(
child: _isLoading
? const Center(child: CircularProgressIndicator())
: LayoutBuilder(builder: (context, constraints) {
final width = constraints.maxWidth;
final isTablet = width >= 600 && width < 900;
final isDesktop = width >= 900;

// Grid sizing (phones/tablets): base 3 columns
const horizontalPadding = 16.0;
const gridGap = 8.0;
final cols = isDesktop ? 4 : (isTablet ? 3 : 3);
final cardSize = (width - (horizontalPadding * 2) - (gridGap * (cols - 1))) / cols;

// Height for 'Am meisten gebucht' horizontal list (1:1 tiles)
final gridHeight = cardSize;

// Neue Angebote row: exactly 3 tiles visible
final neueTile = (width - (horizontalPadding * 2) - (2 * 8)) / 3;

// Guests row: keep previous style
const guestsViewportFraction = 0.24; // ~24–25%
final guestsRowHeight = width * guestsViewportFraction; // 1:1 tile

return CustomScrollView(
controller: _scrollController,
slivers: [
const SliverToBoxAdapter(child: SizedBox(height: 0)),

// New Header with greeting and rotating logo
SliverToBoxAdapter(
child: Padding(
padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
child: Builder(builder: (context) {
final l10n = context.watch<LocalizationController>();
final userName = _currentUserName != null ? _currentUserName!.split(' ').first : 'Walid';
return Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
InkWell(
onTap: () {
setState(() => _currentUserName = 'Walid');
Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
},
child: Text(
'Hi $userName! 👋',
style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
),
),
const SizedBox(height: 4),
Row(children: [
InkWell(
onTap: _openLocationUpdate,
borderRadius: BorderRadius.circular(12),
child: const Padding(
padding: EdgeInsets.all(4.0),
child: Icon(Icons.location_on, size: 16, color: Colors.white70),
),
),
const SizedBox(width: 4),
Text(
_currentUserCity ?? 'Nicht verfügbar',
style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70, fontSize: 14),
),
]),
],
),
),
Transform.translate(offset: const Offset(0, 4), child: _HoverSpinAppLogo(size: 48)),
],
);
}),
),
),

const SliverToBoxAdapter(child: SizedBox(height: 16)),
SliverToBoxAdapter(
  child: SearchHeader(
    onFiltersPressed: () async {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OwnerRequestsScreen(initialTabIndex: 2),
        ),
      );
    },
    onSearchTap: _openSearch,
    onListingCreated: _handleListingCreated,
  ),
),



SliverPersistentHeader(
pinned: true,
delegate: PinnedCategoriesHeader(
builder: (context) {
final l10n = context.watch<LocalizationController>();
final localized = _homeCategories.map((e) => CategoryIconDataModel(id: e.id, icon: e.icon, label: l10n.t(e.label))).toList();
return Container(
color: Colors.transparent,
child: CategoryIconRow(
categories: localized,
onSelected: (c) async {
// Apply immediately without confirmation popup
if (!mounted) return;
setState(() => _filters = { ...?_filters, 'categories': [c.id] });
      AppPopup.toast(context, icon: Icons.filter_alt_outlined, title: '${l10n.t('Gefiltert nach:')} ${c.label}', duration: const Duration(seconds: 1));
},
onAllCategoriesTap: () {
setState(() {
if (_filters == null) {
_filters = {};
}
final f = Map<String, dynamic>.from(_filters!);
f.remove('categories');
_filters = f;
});
      final l10n = context.read<LocalizationController>();
      AppPopup.toast(context, icon: Icons.category_outlined, title: l10n.t('Alle Kategorien'), duration: const Duration(seconds: 1));
},
),
);
},
),
),
const SliverToBoxAdapter(child: SizedBox(height: 0)),

// Am meisten gebucht (horizontally paged 3x3)
SliverToBoxAdapter(child: Builder(builder: (context) {
final l10n = context.watch<LocalizationController>();
  return _SectionHeader(title: l10n.t('Am meisten gebucht'), showSeeAll: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), onSeeAll: () {
final extrasFiltered = _extraTopBooked.where(_matches).toList();
final combinedSrc = [...itemsFiltered, ...extrasFiltered];
final ensured = combinedSrc.isEmpty
? combinedSrc
: List<Item>.from(combinedSrc)..addAll(List<Item>.from(combinedSrc));
Navigator.of(context).push(MaterialPageRoute(builder: (_) => SeeAllScreen(title: l10n.t('Am meisten gebucht'), items: ensured)));
});
})),


SliverToBoxAdapter(
child: Builder(builder: (context) {
  List<Item> combined = [...itemsFiltered, ..._extraTopBooked];
const amCols = 3;
const amRows = 3;
const amGap = 8.0;
final amCardSize = (width - (horizontalPadding * 2) - (amGap * (amCols - 1))) / amCols;
final amHeight = amCardSize * amRows + amGap * (amRows - 1);
    if (combined.length <= 5) {
      final visible = combined;
    final tile = (width - (horizontalPadding * 2) - (8.0 * (visible.length - 1))) / max(1, visible.length);
    return SizedBox(
      height: tile,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(children: [
          for (int i = 0; i < visible.length; i++) ...[
            SizedBox(
              width: tile,
              height: tile,
              child: _SquareTitleOnlyCard(
                item: visible[i],
                isFavorite: _savedIds.contains(visible[i].id),
                onFavoriteToggle: () => _toggleFavorite(visible[i].id),
              ),
            ),
            if (i != visible.length - 1) const SizedBox(width: 8),
          ]
        ]),
      ),
    );
  }
  final pageCount = max(1, (combined.length / 9).ceil());
      return SizedBox(
        height: amHeight,
        child: ScrollEdgeIndicators.page(
          controller: _pageTopBooked,
          pageCount: pageCount,
          showLeft: false,
          showRight: true,
          child: PageView.builder(
            padEnds: true,
            controller: _pageTopBooked,
            itemCount: pageCount,
            itemBuilder: (context, pageIndex) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(children: [
  for (int r = 0; r < amRows; r++) ...[
  Row(children: [
  for (int c = 0; c < amCols; c++) ...[
  Builder(builder: (context) {
  if (combined.isEmpty) return const SizedBox();
  final idx = pageIndex * 9 + r * 3 + c;
  if (idx >= combined.length) return const SizedBox();
  final item = combined[idx];
  final isFav = _savedIds.contains(item.id);
  return SizedBox(
  width: amCardSize,
  height: amCardSize,
  child: _SquareTitleOnlyCard(
  item: item,
  isFavorite: isFav,
  onFavoriteToggle: () => _toggleFavorite(item.id),
  ),
  );
  }),
  if (c != amCols - 1) const SizedBox(width: amGap),
  ],
  ]),
  if (r != amRows - 1) const SizedBox(height: amGap),
  ],
                ]),
              );
            },
          ),
        ),
  );
}),
),

// Neue Angebote (horizontal, 3 visible)
SliverToBoxAdapter(child: Builder(builder: (context) {
final l10n = context.watch<LocalizationController>();
 return _SectionHeader(title: l10n.t('Neue Angebote'), showSeeAll: true, padding: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 8), onSeeAll: () {
Navigator.of(context).push(MaterialPageRoute(builder: (_) => SeeAllScreen(title: l10n.t('Neue Angebote'), items: neueQuelle)));
});
})),

SliverToBoxAdapter(
  child: SizedBox(
    height: neueTile,
    child: ScrollEdgeIndicators.list(
      controller: _ctrlNeue,
        showLeft: false,
        showRight: true,
      child: Builder(builder: (context) {
        final list = neueQuelle;
        // Show the full list horizontally instead of capping at 5
        if (list.isEmpty) return const SizedBox();
        return ListView.separated(
          controller: _ctrlNeue,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
          itemBuilder: (context, index) {
            final item = list[index];
            final isFav = _savedIds.contains(item.id);
            return SizedBox(
              width: neueTile,
              height: neueTile,
              child: _SquareTitleOnlyCard(
                item: item,
                isFavorite: isFav,
                onFavoriteToggle: () => _toggleFavorite(item.id),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemCount: list.length,
        );
      }),
),
),
),

 const SliverToBoxAdapter(child: SizedBox(height: 8)),

// Kunden gefällt auch … (horizontal row with See All link)
SliverToBoxAdapter(child: Builder(builder: (context) {
final l10n = context.watch<LocalizationController>();
 return _SectionHeader(title: l10n.t('Kunden gefällt auch'), showSeeAll: false);
})),

 // Kunden gefällt auch: vertical grid fills available scroll area
 SliverPadding(
   padding: const EdgeInsets.symmetric(horizontal: 16),
     sliver: SliverGrid(
     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
       crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : 3),
       mainAxisSpacing: 8,
       crossAxisSpacing: 8,
     ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final liked = itemsFiltered.where((it) => _savedIds.contains(it.id) || it.timesLent > 5).toList();
        if (liked.isEmpty) return const SizedBox();
        final item = liked[index % liked.length];
        final isFav = _savedIds.contains(item.id);
        return _SmallGridCard(
          item: item,
          isFavorite: isFav,
          onFavoriteToggle: () => _toggleFavorite(item.id),
          compact: false,
        );
      }, childCount: itemsFiltered.where((it) => _savedIds.contains(it.id) || it.timesLent > 5).length),
   ),
 ),

 const SliverToBoxAdapter(child: SizedBox(height: 16)),
],
);
}),
),
);
}
}

class _SectionHeader extends StatelessWidget {
final String title; final bool showSeeAll; final EdgeInsets? padding; final VoidCallback? onSeeAll;
const _SectionHeader({required this.title, this.showSeeAll = false, this.padding, this.onSeeAll});
@override
Widget build(BuildContext context) {
return Padding(
padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
child: Row(children: [
Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white))),
if (showSeeAll)
Builder(builder: (context) {
final l10n = context.watch<LocalizationController>();
return TextButton(onPressed: onSeeAll, child: Text(l10n.t('Alle ansehen')));
})
]),
);
}
}

class _HoverResponsiveTopGrid extends StatefulWidget {
final List<Item> items;
final Set<String> savedIds;
final ValueChanged<String> onFavoriteToggle;
const _HoverResponsiveTopGrid({required this.items, required this.savedIds, required this.onFavoriteToggle});
@override
State<_HoverResponsiveTopGrid> createState() => _HoverResponsiveTopGridState();
}

class _HoverResponsiveTopGridState extends State<_HoverResponsiveTopGrid> {
static const double _gap = 8.0;
OverlayEntry? _hoverEntry;
int? _hoveredIndex;

@override
void dispose() {
_removeHoverOverlay();
super.dispose();
}

void _showHoverOverlay(int index, Rect rect) {
_removeHoverOverlay();
_hoveredIndex = index;
final item = widget.items.length > index ? widget.items[index] : null;
if (item == null) return;
final isFav = widget.savedIds.contains(item.id);
final overlay = Overlay.of(context);
if (overlay == null) return;

const scale = 1.33;
final media = MediaQuery.of(context);
final screenSize = media.size;
final scaledW = rect.width * scale;
final scaledH = rect.height * scale;
final center = rect.center;
double left = center.dx - scaledW / 2;
double top = center.dy - scaledH / 2;
const margin = 8.0;
left = left.clamp(margin, screenSize.width - scaledW - margin);
top = top.clamp(margin, screenSize.height - scaledH - margin);

_hoverEntry = OverlayEntry(builder: (_) {
return Stack(children: [
Positioned.fill(
child: GestureDetector(
behavior: HitTestBehavior.opaque,
onTap: _removeHoverOverlay,
child: BackdropFilter(
filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
child: Container(color: Colors.black.withValues(alpha: 0.06)),
),
),
),
Positioned(
left: left,
top: top,
width: scaledW,
height: scaledH,
child: MouseRegion(
onExit: (_) => _removeHoverOverlay(),
child: Material(
elevation: 16,
borderRadius: BorderRadius.circular(18),
clipBehavior: Clip.antiAlias,
child: _SquareItemCard(
item: item,
isFavorite: isFav,
onFavoriteToggle: () {
widget.onFavoriteToggle(item.id);
WidgetsBinding.instance.addPostFrameCallback((_) {
_rebuildHoverOverlay(index, Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height));
});
},
),
),
),
),
]);
});
overlay.insert(_hoverEntry!);
}

void _rebuildHoverOverlay(int index, Rect rect) {
if (_hoverEntry == null) return;
_showHoverOverlay(index, rect);
}

void _removeHoverOverlay() {
_hoverEntry?.remove();
_hoverEntry = null;
_hoveredIndex = null;
}

@override
Widget build(BuildContext context) {
final items = widget.items.length > 9 ? widget.items.take(9).toList() : widget.items;
if (items.isEmpty) return const SizedBox();

return LayoutBuilder(builder: (context, constraints) {
final maxWidth = constraints.maxWidth;
final rows = (items.length / 3).ceil();
return Column(children: [
for (int r = 0; r < rows; r++) ...[
_AnimatedHoverRow(
rowIndex: r,
maxWidth: maxWidth,
items: items,
start: r * 3,
end: (r * 3 + 3).clamp(0, items.length),
onHoverEnter: (i, rect) => _showHoverOverlay(i, rect),
onHoverExit: (i) {
if (_hoveredIndex == i) _removeHoverOverlay();
},
savedIds: widget.savedIds,
onFavoriteToggle: widget.onFavoriteToggle,
),
if (r != rows - 1) const SizedBox(height: _gap),
]
]);
});
}
}

class _AnimatedHoverRow extends StatelessWidget {
final int rowIndex;
final double maxWidth;
final List<Item> items;
final int start;
final int end; // exclusive
final void Function(int, Rect) onHoverEnter;
final ValueChanged<int> onHoverExit;
final Set<String> savedIds;
final ValueChanged<String> onFavoriteToggle;

static const double gap = 8.0;

const _AnimatedHoverRow({
required this.rowIndex,
required this.maxWidth,
required this.items,
required this.start,
required this.end,
required this.onHoverEnter,
required this.onHoverExit,
required this.savedIds,
required this.onFavoriteToggle,
});

@override
Widget build(BuildContext context) {
final count = end - start;
final totalGap = (count - 1) * gap;
final tileWidth = count > 0 ? (maxWidth - totalGap) / count : 0.0;

return SizedBox(
width: maxWidth,
child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
for (int j = 0; j < count; j++) ...[
_HoverTile(
globalIndex: start + j,
width: tileWidth,
item: items[start + j],
isFavorite: savedIds.contains(items[start + j].id),
onFavoriteToggle: () => onFavoriteToggle(items[start + j].id),
onHoverEnter: onHoverEnter,
onHoverExit: onHoverExit,
),
if (j != count - 1) const SizedBox(width: gap),
]
]),
);
}
}

class _HoverTile extends StatefulWidget {
final int globalIndex;
final double width;
final Item item;
final bool isFavorite;
final VoidCallback onFavoriteToggle;
final void Function(int, Rect) onHoverEnter;
final ValueChanged<int> onHoverExit;

const _HoverTile({
required this.globalIndex,
required this.width,
required this.item,
required this.isFavorite,
required this.onFavoriteToggle,
required this.onHoverEnter,
required this.onHoverExit,
});

@override
State<_HoverTile> createState() => _HoverTileState();
}

class _HoverTileState extends State<_HoverTile> {
final GlobalKey _tileKey = GlobalKey();
Timer? _pressTimer;
bool _pointerDown = false;

void _startPressTimer() {
_pressTimer?.cancel();
_pressTimer = Timer(const Duration(seconds: 1), () {
if (!_pointerDown) return;
final ctx = _tileKey.currentContext;
if (ctx != null) {
final box = ctx.findRenderObject() as RenderBox;
final pos = box.localToGlobal(Offset.zero);
final size = box.size;
widget.onHoverEnter(widget.globalIndex, Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height));
} else {
widget.onHoverEnter(widget.globalIndex, Rect.fromLTWH(0, 0, widget.width, widget.width));
}
});
}

void _cancelPressTimer() {
_pressTimer?.cancel();
_pressTimer = null;
}

@override
void dispose() {
_cancelPressTimer();
super.dispose();
}

@override
Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) {
          _pointerDown = true;
          _startPressTimer();
        },
        onTapUp: (_) {
          _pointerDown = false;
          _cancelPressTimer();
        },
        onTapCancel: () {
          _pointerDown = false;
          _cancelPressTimer();
        },
        child: SizedBox(
key: _tileKey,
width: widget.width,
height: widget.width,
child: _SquareItemCard(item: widget.item, isFavorite: widget.isFavorite, onFavoriteToggle: widget.onFavoriteToggle),
),
),
);
}
}

class _OverlayPresenter {
static void showEnlarged(BuildContext context, Item item, Rect anchorRect, {bool isFavorite = false, VoidCallback? onFavoriteToggle}) {
final overlay = Overlay.of(context);
if (overlay == null) return;
const scale = 1.33;
final media = MediaQuery.of(context);
final screenSize = media.size;
final scaledW = anchorRect.width * scale;
final scaledH = anchorRect.height * scale;
final center = anchorRect.center;
double left = center.dx - scaledW / 2;
double top = center.dy - scaledH / 2;
const margin = 8.0;
left = left.clamp(margin, screenSize.width - scaledW - margin);
top = top.clamp(margin, screenSize.height - scaledH - margin);

late OverlayEntry entry;
entry = OverlayEntry(builder: (_) {
return Stack(children: [
Positioned.fill(
child: GestureDetector(
behavior: HitTestBehavior.opaque,
onTap: () => entry.remove(),
child: BackdropFilter(
filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
child: Container(color: Colors.black.withValues(alpha: 0.06)),
),
),
),
Positioned(
left: left,
top: top,
width: scaledW,
height: scaledH,
child: Material(
elevation: 16,
borderRadius: BorderRadius.circular(18),
clipBehavior: Clip.antiAlias,
child: _SquareItemCard(
item: item,
isFavorite: isFavorite,
onFavoriteToggle: () {
if (onFavoriteToggle != null) onFavoriteToggle();
},
),
),
),
]);
});
overlay.insert(entry);
}
}

 class _SquareItemCard extends StatefulWidget {
 final Item item; final bool isFavorite; final VoidCallback onFavoriteToggle; final bool showFavorite; final bool showInfo;
 const _SquareItemCard({required this.item, required this.isFavorite, required this.onFavoriteToggle, this.showFavorite = true, this.showInfo = true});
@override
State<_SquareItemCard> createState() => _SquareItemCardState();
}

class _SquareItemCardState extends State<_SquareItemCard> {
final GlobalKey _key = GlobalKey();
Timer? _pressTimer; bool _pointerDown = false;
bool get _isVerified => widget.item.verificationStatus == 'approved' || widget.item.verificationStatus == 'verified';

void _startPressTimer() {
_pressTimer?.cancel();
_pressTimer = Timer(const Duration(seconds: 1), () {
if (!_pointerDown) return;
final ctx = _key.currentContext;
if (ctx != null) {
final box = ctx.findRenderObject() as RenderBox;
final pos = box.localToGlobal(Offset.zero);
final size = box.size;
_OverlayPresenter.showEnlarged(context, widget.item, Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height), isFavorite: widget.isFavorite, onFavoriteToggle: widget.onFavoriteToggle);
}
});
}

void _cancelTimer() { _pressTimer?.cancel(); _pressTimer = null; }

@override
void dispose() { _cancelTimer(); super.dispose(); }

@override
Widget build(BuildContext context) {
  return MouseRegion(
    cursor: SystemMouseCursors.basic,
    child: GestureDetector(
      onTapDown: (_) { _pointerDown = true; _startPressTimer(); },
      onTapUp: (_) { _pointerDown = false; _cancelTimer(); },
      onTapCancel: () { _pointerDown = false; _cancelTimer(); },
      child: GestureDetector(
key: _key,
                onTap: () => ItemDetailsOverlay.showFullPage(context, item: widget.item, fresh: true),
child: ClipRRect(
borderRadius: BorderRadius.circular(18),
child: Stack(children: [
Positioned.fill(
child: LayoutBuilder(builder: (context, c) {
final dpr = MediaQuery.of(context).devicePixelRatio;
final cache = (c.maxWidth * dpr).round();
          return AppImage(
            url: widget.item.photos.isNotEmpty ? widget.item.photos.first : 'https://picsum.photos/seed/fallback_1/800/800',
            fit: BoxFit.cover,
            // cacheWidth ignored by AppImage; kept simple
          );
}),
),
Positioned.fill(
child: DecoratedBox(
decoration: BoxDecoration(
border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
borderRadius: BorderRadius.circular(18),
),
),
),
 if (widget.showInfo)
 Positioned(
 left: 0, right: 0, bottom: 0,
 child: Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
 Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.55),
 ]),
 ),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
 Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
 const SizedBox(height: 2),
 Row(children: [
 Expanded(child: Builder(builder: (context) {
 final unit = widget.item.priceUnit;
 final perDay = widget.item.pricePerDay;
 final price = unit == 'week' ? perDay * 7 : perDay;
 final suffix = unit == 'week' ? '€/Woche' : '€/Tag';
 return Text('${price.toStringAsFixed(0)} $suffix', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white));
 })),
 const Icon(Icons.star, size: 12, color: Color(0xFFFB923C)),
 const SizedBox(width: 2),
 Text('4.8', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
 ]),
 ]),
 ),
 ),
if (widget.showFavorite)
Positioned(
top: 8,
right: 8,
child: InkWell(
onTap: widget.onFavoriteToggle,
borderRadius: BorderRadius.circular(16),
mouseCursor: SystemMouseCursors.basic,
child: Container(
padding: const EdgeInsets.all(6),
decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
 child: Icon(widget.isFavorite ? Icons.favorite : Icons.favorite_border, size: 16, color: widget.isFavorite ? Colors.pinkAccent : Colors.black54),
),
),
),
Positioned(
top: 8,
left: 8,
child: _isVerified
? const Icon(Icons.verified, size: 16, color: Color(0xFF22C55E))
: Tooltip(message: context.watch<LocalizationController>().t('Nicht verifiziert'), child: const Icon(Icons.verified_outlined, size: 16, color: Colors.white70)),
),
]),
),
),
),
);
}
}

class _SmallScrollCard extends StatefulWidget {
final Item item; final bool isFavorite; final VoidCallback onFavoriteToggle;
const _SmallScrollCard({required this.item, required this.isFavorite, required this.onFavoriteToggle});
@override
State<_SmallScrollCard> createState() => _SmallScrollCardState();
}

class _SmallScrollCardState extends State<_SmallScrollCard> {
final GlobalKey _key = GlobalKey();
Timer? _pressTimer; bool _pointerDown = false;
bool get _isVerified => widget.item.verificationStatus == 'approved' || widget.item.verificationStatus == 'verified';

double _iconSizeFor(double width) => (width * 0.10).clamp(14.0, 20.0);

void _startPressTimer() {
_pressTimer?.cancel();
_pressTimer = Timer(const Duration(seconds: 1), () {
if (!_pointerDown) return;
final ctx = _key.currentContext;
if (ctx != null) {
final box = ctx.findRenderObject() as RenderBox;
final pos = box.localToGlobal(Offset.zero);
final size = box.size;
_OverlayPresenter.showEnlarged(context, widget.item, Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height));
}
});
}

void _cancelTimer() { _pressTimer?.cancel(); _pressTimer = null; }

@override
void dispose() { _cancelTimer(); super.dispose(); }

@override
Widget build(BuildContext context) {
  return MouseRegion(
    cursor: SystemMouseCursors.basic,
    child: GestureDetector(
      onTapDown: (_) { _pointerDown = true; _startPressTimer(); },
      onTapUp: (_) { _pointerDown = false; _cancelTimer(); },
      onTapCancel: () { _pointerDown = false; _cancelTimer(); },
      child: GestureDetector(
key: _key,
            onTap: () => ItemDetailsOverlay.showFullPage(context, item: widget.item, fresh: true),
child: ClipRRect(
borderRadius: BorderRadius.circular(14),
child: LayoutBuilder(builder: (context, c) {
final iconSize = _iconSizeFor(c.maxWidth);
return Stack(children: [
Positioned.fill(
child: LayoutBuilder(builder: (context, c2) {
final dpr = MediaQuery.of(context).devicePixelRatio;
final cache = (c2.maxWidth * dpr).round();
      return AppImage(
        url: widget.item.photos.isNotEmpty ? widget.item.photos.first : 'https://picsum.photos/seed/fallback_2/600/600',
        fit: BoxFit.cover,
      );
}),
),
Positioned.fill(
child: DecoratedBox(
decoration: BoxDecoration(
border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
borderRadius: BorderRadius.circular(14),
),
),
),
Positioned(
left: 0, right: 0, bottom: 0,
child: Container(
padding: const EdgeInsets.all(6),
decoration: BoxDecoration(
gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.55),
]),
),
child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
const SizedBox(height: 2),
Row(children: [
Expanded(child: Builder(builder: (context) {
final unit = widget.item.priceUnit;
final perDay = widget.item.pricePerDay;
final price = unit == 'week' ? perDay * 7 : perDay;
final suffix = unit == 'week' ? '€/Woche' : '€/Tag';
return Text('${price.toStringAsFixed(0)} $suffix', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white));
})),
const Icon(Icons.star, size: 12, color: Color(0xFFFB923C)),
const SizedBox(width: 2),
Text('4.8', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
])
]),
),
),
// Favorite heart (top-right)
Positioned(
top: 8,
right: 8,
child: InkWell(
onTap: widget.onFavoriteToggle,
borderRadius: BorderRadius.circular(16),
mouseCursor: SystemMouseCursors.basic,
child: Container(
padding: EdgeInsets.all(iconSize * 0.35),
decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
child: Icon(widget.isFavorite ? Icons.favorite : Icons.favorite_border, size: iconSize, color: widget.isFavorite ? Colors.red : Colors.black54),
),
),
),
// Verified (top-left)
Positioned(
top: 8,
left: 8,
child: _isVerified
? Icon(Icons.verified, size: iconSize, color: const Color(0xFF22C55E))
: Tooltip(message: context.watch<LocalizationController>().t('Nicht verifiziert'), child: Icon(Icons.verified_outlined, size: iconSize, color: Colors.grey)),
),
]);
}),
),
),
),
);
}
}

class _SmallGridCard extends StatefulWidget {
  final Item item; final bool isFavorite; final VoidCallback onFavoriteToggle; final bool compact;
  const _SmallGridCard({required this.item, required this.isFavorite, required this.onFavoriteToggle, this.compact = false});
  @override
  State<_SmallGridCard> createState() => _SmallGridCardState();
}

class _SmallGridCardState extends State<_SmallGridCard> {
  final GlobalKey _key = GlobalKey();
  Timer? _pressTimer; bool _pointerDown = false;
  bool get _isVerified => widget.item.verificationStatus == 'approved' || widget.item.verificationStatus == 'verified';

  double _iconSizeFor(double width) {
    final base = widget.compact ? 0.08 : 0.10;
    final min = widget.compact ? 12.0 : 14.0;
    final max = widget.compact ? 18.0 : 20.0;
    return (width * base).clamp(min, max);
  }

  void _startPressTimer() {
    _pressTimer?.cancel();
    _pressTimer = Timer(const Duration(seconds: 1), () {
      if (!_pointerDown) return;
      final ctx = _key.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox;
        final pos = box.localToGlobal(Offset.zero);
        final size = box.size;
        _OverlayPresenter.showEnlarged(context, widget.item, Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height));
      }
    });
  }

  void _cancelTimer() { _pressTimer?.cancel(); _pressTimer = null; }

  @override
  void dispose() { _cancelTimer(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) { _pointerDown = true; _startPressTimer(); },
        onTapUp: (_) { _pointerDown = false; _cancelTimer(); },
        onTapCancel: () { _pointerDown = false; _cancelTimer(); },
        child: GestureDetector(
          key: _key,
          onTap: () => ItemDetailsOverlay.showFullPage(context, item: widget.item, fresh: true),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LayoutBuilder(builder: (context, c) {
              final iconSize = _iconSizeFor(c.maxWidth);
              return Stack(children: [
                Positioned.fill(
                  child: LayoutBuilder(builder: (context, c2) {
                    final dpr = MediaQuery.of(context).devicePixelRatio;
                    final cache = (c2.maxWidth * dpr).round();
                    return AppImage(
                      url: widget.item.photos.isNotEmpty ? widget.item.photos.first : 'https://picsum.photos/seed/fallback_3/600/600',
                      fit: BoxFit.cover,
                    );
                  }),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                // Title overlay at bottom (like Neue Angebote)
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
                        Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.55),
                      ]),
                    ),
                    child: Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                // Favorite heart (top-right)
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    onTap: widget.onFavoriteToggle,
                    borderRadius: BorderRadius.circular(16),
                    mouseCursor: SystemMouseCursors.basic,
                    child: Container(
                      padding: EdgeInsets.all(iconSize * 0.35),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                      child: Icon(widget.isFavorite ? Icons.favorite : Icons.favorite_border, size: iconSize, color: widget.isFavorite ? Colors.pinkAccent : Colors.black54),
                    ),
                  ),
                ),
                // Verified (top-left)
                Positioned(
                  top: 6,
                  left: 6,
                  child: _isVerified
                      ? Icon(Icons.verified, size: iconSize, color: const Color(0xFF22C55E))
                      : Tooltip(message: context.watch<LocalizationController>().t('Nicht verifiziert'), child: Icon(Icons.verified_outlined, size: iconSize, color: Colors.grey)),
                ),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}

class _SquareTitleOnlyCard extends StatefulWidget {
  final Item item;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  const _SquareTitleOnlyCard({required this.item, this.isFavorite = false, this.onFavoriteToggle});
  @override
  State<_SquareTitleOnlyCard> createState() => _SquareTitleOnlyCardState();
}

class _SquareTitleOnlyCardState extends State<_SquareTitleOnlyCard> {
  final GlobalKey _key = GlobalKey();
  Timer? _pressTimer; bool _pointerDown = false;
  bool get _isVerified => widget.item.verificationStatus == 'approved' || widget.item.verificationStatus == 'verified';

void _startPressTimer() {
_pressTimer?.cancel();
_pressTimer = Timer(const Duration(seconds: 1), () {
if (!_pointerDown) return;
final ctx = _key.currentContext;
if (ctx != null) {
final box = ctx.findRenderObject() as RenderBox;
final pos = box.localToGlobal(Offset.zero);
final size = box.size;
_OverlayPresenter.showEnlarged(context, widget.item, Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height));
}
});
}

void _cancelTimer() { _pressTimer?.cancel(); _pressTimer = null; }

@override
void dispose() { _cancelTimer(); super.dispose(); }

@override
Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) { _pointerDown = true; _startPressTimer(); },
        onTapUp: (_) { _pointerDown = false; _cancelTimer(); },
        onTapCancel: () { _pointerDown = false; _cancelTimer(); },
            child: GestureDetector(
key: _key,
          onTap: () => ItemDetailsOverlay.showFullPage(context, item: widget.item, fresh: true),
child: ClipRRect(
borderRadius: BorderRadius.circular(18),
child: Stack(children: [
Positioned.fill(
child: LayoutBuilder(builder: (context, c) {
final dpr = MediaQuery.of(context).devicePixelRatio;
final cache = (c.maxWidth * dpr).round();
        return AppImage(
          url: widget.item.photos.isNotEmpty ? widget.item.photos.first : 'https://picsum.photos/seed/titleonly/800/800',
          fit: BoxFit.cover,
        );
}),
),
Positioned.fill(
child: DecoratedBox(
decoration: BoxDecoration(
border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
borderRadius: BorderRadius.circular(18),
),
),
),
Positioned(
left: 0, right: 0, bottom: 0,
child: Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.55),
]),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisSize: MainAxisSize.min,
children: [
Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
  // Date removed per request
],
),
),
),
// Favorite heart (top-right)
if (widget.onFavoriteToggle != null)
Positioned(
top: 8,
right: 8,
child: InkWell(
onTap: widget.onFavoriteToggle,
borderRadius: BorderRadius.circular(16),
mouseCursor: SystemMouseCursors.basic,
child: Container(
padding: const EdgeInsets.all(6),
decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
 child: Icon(widget.isFavorite ? Icons.favorite : Icons.favorite_border, size: 16, color: widget.isFavorite ? Colors.pinkAccent : Colors.black54),
),
),
),
Positioned(
top: 8,
left: 8,
child: _isVerified
? const Icon(Icons.verified, size: 16, color: Color(0xFF22C55E))
: const Tooltip(message: 'Nicht verifiziert', child: Icon(Icons.verified_outlined, size: 16, color: Colors.grey)),
),
]),
),
),
),
);
}
}

class _ShimmerBox extends StatefulWidget {
const _ShimmerBox();
@override
State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
late final AnimationController _c;
@override
void initState() {
super.initState();
_c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
}

@override
void dispose() {
_c.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return AnimatedBuilder(
animation: _c,
builder: (context, _) {
return DecoratedBox(
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(8),
gradient: LinearGradient(
begin: Alignment(-1 + 2 * _c.value, -1),
end: Alignment(0 + 2 * _c.value, 1),
colors: [
Colors.white.withValues(alpha: 0.08),
Colors.white.withValues(alpha: 0.20),
Colors.white.withValues(alpha: 0.08),
],
),
),
child: const SizedBox.expand(),
);
},
);
}
}

class _HoverSpinAppLogo extends StatefulWidget {
final double size;
const _HoverSpinAppLogo({required this.size});
@override
State<_HoverSpinAppLogo> createState() => _HoverSpinAppLogoState();
}

class _HoverSpinAppLogoState extends State<_HoverSpinAppLogo> with SingleTickerProviderStateMixin {
late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
late final Animation<double> _turns = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

void _spinOnce() {
// Restart from 0 so each hover completes a single rotation
_controller.forward(from: 0);
}

@override
void dispose() {
_controller.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return SizedBox(
width: widget.size,
height: widget.size,
child: MouseRegion(
onEnter: (_) => _spinOnce(),
child: Center(
child: RotationTransition(
turns: _turns,
child: Image.asset('assets/images/icononly_transparent_nobuffer.png', fit: BoxFit.contain),
),
),
),
);
}
}
