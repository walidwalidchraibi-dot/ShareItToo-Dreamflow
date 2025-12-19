import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/widgets/item_details_overlay.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/widgets/app_image.dart';

class WishlistsScreen extends StatefulWidget {
  const WishlistsScreen({super.key});

  @override
  State<WishlistsScreen> createState() => _WishlistsScreenState();
}

class _WishlistsScreenState extends State<WishlistsScreen> {
  Map<String, List<Item>> _byCity = {};
  List<String> _cities = [];
  String? _selectedCity;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await DataService.getItems();
    final saved = await DataService.getSavedItemIds();
    final savedItems = items.where((i) => saved.contains(i.id)).toList();
    final map = <String, List<Item>>{};
    for (final it in savedItems) {
      map.putIfAbsent(it.city, () => []).add(it);
    }
    final cities = map.keys.toList()..sort();
    setState(() {
      _byCity = map;
      _cities = cities;
      _selectedCity = cities.isNotEmpty ? cities.first : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
        title: Builder(builder: (context) => Text(context.watch<LocalizationController>().t('Wunschlisten'))),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: _cities.isEmpty
                  ? Center(child: Builder(builder: (context) => Text(context.watch<LocalizationController>().t('Noch keine gespeicherten Elemente'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white))))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.0),
                      itemCount: _cities.length,
                      itemBuilder: (context, index) {
                        final city = _cities[index];
                        final preview = _byCity[city]?.first;
                        final image = preview?.photos.isNotEmpty == true ? preview!.photos.first : 'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=800&h=800&fit=crop';
                        return _CityAlbumTile(city: city, image: image, count: _byCity[city]?.length ?? 0, onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => _CityWishlistScreen(city: city, items: _byCity[city] ?? [])));
                        });
                      },
                    ),
            ),
    );
  }
}

class _WishlistItemTile extends StatelessWidget {
  final Item item;
  const _WishlistItemTile({required this.item});
  bool get _isVerified => item.verificationStatus == 'approved' || item.verificationStatus == 'verified';
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ItemDetailsOverlay.showFullPage(context, item: item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Stack(children: [
                Positioned.fill(child: AppImage(url: item.photos.isNotEmpty ? item.photos.first : 'https://images.unsplash.com/photo-1520975661595-6453be3f7070?w=800&h=600&fit=crop', fit: BoxFit.cover)),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: _isVerified ? const Color(0xFF22C55E).withValues(alpha: 0.9) : Colors.grey.shade600.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_isVerified ? Icons.verified : Icons.help_outline, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Builder(builder: (context) => Text(context.watch<LocalizationController>().t('Verifiziert'), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)))
                    ]),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: Text(item.city, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70))),
                  Text('${item.pricePerDay.toStringAsFixed(0)} ${context.watch<LocalizationController>().t('€/Tag')}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
                ])
              ]),
            )
          ]),
        ),
      ),
    );
  }
}

class _CityAlbumTile extends StatelessWidget {
  final String city; final String image; final int count; final VoidCallback onTap;
  const _CityAlbumTile({required this.city, required this.image, required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(children: [
          Positioned.fill(child: AppImage(url: image, fit: BoxFit.cover)),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.2), Colors.black.withValues(alpha: 0.55)])))),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Row(children: [
              Expanded(child: Text(city, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)), child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CityWishlistScreen extends StatelessWidget {
  final String city; final List<Item> items;
  const _CityWishlistScreen({required this.city, required this.items});
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    return Scaffold(
      appBar: AppBar(title: Text('${l10n.t('Wunschliste')} · $city'), centerTitle: true),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.9),
        itemCount: items.length,
        itemBuilder: (_, i) => _WishlistItemTile(item: items[i]),
      ),
    );
  }
}
