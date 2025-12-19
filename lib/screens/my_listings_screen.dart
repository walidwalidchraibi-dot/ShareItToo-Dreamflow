import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/screens/create_listing_screen.dart';
import 'package:lendify/widgets/item_details_overlay.dart';

import 'package:provider/provider.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/widgets/app_popup.dart';

class MyListingsScreen extends StatefulWidget {
  final int initialTabIndex;
  const MyListingsScreen({super.key, this.initialTabIndex = 0});
  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Item> _items = [];
  bool _canCreateListings = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialTabIndex.clamp(0, 1);
    _tabController = TabController(length: 2, vsync: this, initialIndex: init);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = await DataService.getCurrentUser();
    final all = await DataService.getItems();
    setState(() {
      _canCreateListings = user != null && !user.isBanned;
      final owned = all.where((e) => e.ownerId == user?.id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _items = owned;
    });
  }

  Future<void> _startCreateListing() async {
    if (!_canCreateListings) return;
    final created = await Navigator.of(context).push<Item?>(
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
    if (!mounted) return;
    if (created != null) {
      await _load();
      if (!mounted) return;
      AppPopup.toast(context, icon: Icons.check_circle_outline, title: 'Anzeige erstellt', message: created.title);
    }
  }

  // All listed items except drafts
  List<Item> _listedItems(List<Item> src) => src.where((e) => e.status != 'draft').toList();
  List<Item> _draftItems(List<Item> src) => src.where((e) => e.status == 'draft').toList();

  Future<void> _changeStatus(Item it, String status) async {
    await DataService.updateItemStatus(itemId: it.id, status: status);
    setState(() {
      _items = _items.map((e) {
        if (e.id != it.id) return e;
        return Item(
          id: e.id,
          ownerId: e.ownerId,
          title: e.title,
          description: e.description,
          categoryId: e.categoryId,
          subcategory: e.subcategory,
          tags: e.tags,
          pricePerDay: e.pricePerDay,
          currency: e.currency,
          priceUnit: e.priceUnit,
          priceRaw: e.priceRaw,
          deposit: e.deposit,
          photos: e.photos,
          locationText: e.locationText,
          lat: e.lat,
          lng: e.lng,
          geohash: e.geohash,
          condition: e.condition,
          minDays: e.minDays,
          maxDays: e.maxDays,
          createdAt: e.createdAt,
          isActive: status == 'active',
          verificationStatus: e.verificationStatus,
          city: e.city,
          country: e.country,
          status: status,
          endedAt: status == 'ended' ? DateTime.now() : e.endedAt,
          timesLent: e.timesLent,
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final tabsStyle = Theme.of(context).textTheme.bodySmall;
    final showLabel = MediaQuery.of(context).size.width >= 420;
    final tooltipText = _canCreateListings ? l10n.t('Neue Anzeige erstellen') : l10n.t('Nicht verfügbar');
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
        title: Text(l10n.t('Meine Anzeigen')),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: tooltipText,
              waitDuration: const Duration(milliseconds: 400),
              child: FilledButton(
                onPressed: _canCreateListings ? _startCreateListing : null,
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: EdgeInsets.symmetric(horizontal: showLabel ? 16 : 12),
                ),
                child: showLabel
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.t('Neue Anzeige erstellen')),
                      ])
                    : const Icon(Icons.add, size: 20),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          labelPadding: const EdgeInsets.symmetric(horizontal: 10),
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.white70,
          labelStyle: tabsStyle,
          unselectedLabelStyle: tabsStyle,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: [
            Tab(text: l10n.t('Meine Anzeigen')),
            Tab(text: l10n.t('für später gespeichert')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildItemsGrid(_listedItems(_items), l10n),
          _buildItemsGrid(_draftItems(_items), l10n),
        ],
      ),
    );
  }

  Widget _buildItemsGrid(List<Item> visible, LocalizationController l10n) {
    return visible.isEmpty
        ? Center(child: Text(l10n.t('Keine Anzeigen'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)))
        : GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.02),
            itemCount: visible.length,
            itemBuilder: (_, i) {
              final it = visible[i];
              String statusLabel = switch (it.status) { 'active' => 'Aktiv', 'paused' => 'Pausiert', 'ended' => 'Beendet', 'draft' => 'Entwurf', _ => 'Aktiv' };
              Color chipColor = switch (it.status) { 'active' => const Color(0x3322C55E), 'paused' => const Color(0x33F59E0B), 'ended' => const Color(0x33F43F5E), 'draft' => Colors.white54, _ => Colors.white54 };
              return InkWell(
                onTap: () => ItemDetailsOverlay.showFullPage(
                  context,
                  item: it,
                  isOwnerPreview: true,
                  overrideAppBarTitle: it.status == 'draft' ? 'Für Später gespeichert' : 'Meine Anzeigen (Vorschau)',
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: AspectRatio(aspectRatio: 16 / 9, child: AppImage(url: it.photos.isNotEmpty ? it.photos.first : '', fit: BoxFit.cover))),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Text('${it.pricePerDay.toStringAsFixed(0)} €', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
                          const SizedBox(width: 4),
                          Text(l10n.t('pro Tag'), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(8)), child: Text(statusLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white))),
                          const Spacer(),
                          PopupMenuButton<String>(
                            tooltip: 'Status ändern',
                            onSelected: (v) async {
                              if (it.status == 'draft') {
                                switch (v) {
                                  case 'publish':
                                    await _changeStatus(it, 'active');
                                    if (mounted) AppPopup.toast(context, icon: Icons.check_circle, title: 'Anzeige veröffentlicht');
                                    break;
                                  case 'edit':
                                    final res = await Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => CreateListingScreen(existing: it)),
                                    );
                                    if (!mounted) return;
                                    await _load();
                                    if (!mounted) return;
                                    if (res == 'drafts') {
                                      // Jump to the "für später gespeichert" tab first
                                      _tabController.animateTo(3);
                                      // Ensure UI has settled before showing the popup
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (!mounted) return;
                                        AppPopup.toast(
                                          context,
                                          icon: Icons.check_circle_outline,
                                          title: 'Änderungen wurden gespeichert',
                                          // Use the same blurred background style for consistency
                                          useExploreBackground: true,
                                        );
                                      });
                                    }
                                    break;
                                  case 'delete':
                                    await DataService.deleteItemById(it.id);
                                    await _load();
                                    if (mounted) AppPopup.toast(context, icon: Icons.delete_outline, title: 'Entwurf gelöscht');
                                    break;
                                }
                              } else {
                                _changeStatus(it, v);
                              }
                            },
                            itemBuilder: (context) {
                              if (it.status == 'draft') {
                                return const [
                                  PopupMenuItem(value: 'publish', child: Text('Veröffentlichen')),
                                  PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                                  PopupMenuItem(value: 'delete', child: Text('Löschen')),
                                ];
                              }
                              return [
                                if (it.status != 'active') const PopupMenuItem(value: 'active', child: Text('Aktivieren')),
                                if (it.status != 'paused') const PopupMenuItem(value: 'paused', child: Text('Pausieren')),
                                if (it.status != 'ended') const PopupMenuItem(value: 'ended', child: Text('Beenden')),
                              ];
                            },
                            child: const Icon(Icons.more_horiz, color: Colors.white70),
                          )
                        ])
                      ]),
                    )
                  ]),
                ),
              );
            },
          );
  }
}
