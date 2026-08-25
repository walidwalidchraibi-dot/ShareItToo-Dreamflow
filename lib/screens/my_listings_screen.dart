import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/services/shared_persistence_sync.dart';
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
  bool _loading = true;
  bool _actionBusy = false;
  String? _loadError;
  String? _currentUserId;
  StreamSubscription<String>? _persistenceSubscription;
  final SharedPersistenceRefreshCoordinator _refreshCoordinator = SharedPersistenceRefreshCoordinator();

  @override
  void initState() {
    super.initState();
    final init = widget.initialTabIndex.clamp(0, 1);
    _tabController = TabController(length: 2, vsync: this, initialIndex: init);
    _persistenceSubscription = SharedPersistenceSync.changes.listen((key) {
      if (key != SharedPersistenceSync.listingCatalogKey) return;
      _refreshCoordinator.schedule(() async {
        await SharedPersistenceSync.reloadPreferences();
        await _load();
      });
    });
    _load();
  }

  @override
  void dispose() {
    _persistenceSubscription?.cancel();
    _refreshCoordinator.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
        _currentUserId = null;
        _canCreateListings = false;
        _items = const <Item>[];
      });
    }
    try {
      final user = await DataService.getCurrentUser();
      final expectedUserId = user?.id.trim() ?? '';
      if (expectedUserId.isEmpty) {
        throw StateError('Für deine Anzeigen ist eine Anmeldung erforderlich.');
      }
      final all = await DataService.getItems();
      final rechecked = await DataService.getCurrentUser();
      if (rechecked?.id.trim() != expectedUserId) {
        throw StateError('Das angemeldete Konto hat sich geändert.');
      }
      if (!mounted) return;
      setState(() {
        _currentUserId = expectedUserId;
        _canCreateListings = !user!.isBanned;
        _items = all.where((item) => item.ownerId == expectedUserId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserId = null;
        _canCreateListings = false;
        _items = const <Item>[];
        _loading = false;
        _loadError = 'Deine Anzeigen konnten nicht sicher geladen werden.';
      });
    }
  }

  Future<void> _startCreateListing() async {
    if (!_canCreateListings) return;
    final created = await Navigator.of(context).push<Item?>(
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
    if (!mounted) return;
    if (created != null) {
      await _load();
      if (!mounted || _loadError != null) return;
      AppPopup.toast(context, icon: Icons.check_circle_outline, title: 'Anzeige erstellt', message: created.title);
    }
  }

  // All listed items except drafts
  List<Item> _listedItems(List<Item> src) => src.where((e) => e.status != 'draft').toList();
  List<Item> _draftItems(List<Item> src) => src.where((e) => e.status == 'draft').toList();

  Future<bool> _runOwnerMutation(Future<void> Function() mutation) async {
    if (_actionBusy || _currentUserId == null) return false;
    final expectedUserId = _currentUserId!;
    setState(() => _actionBusy = true);
    try {
      await mutation();
      final rechecked = await DataService.getCurrentUser();
      if (rechecked?.id != expectedUserId) {
        throw StateError('Das angemeldete Konto hat sich geändert.');
      }
      await _load();
      if (_loadError != null) {
        throw StateError('Die Anzeige konnte nicht sicher neu geladen werden.');
      }
      return true;
    } catch (_) {
      await _load();
      if (mounted) {
        AppPopup.error(
          context,
          title: 'Änderung nicht gespeichert',
          message: 'Die Anzeige blieb unverändert. Prüfe deine Anmeldung und versuche es erneut.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<bool> _changeStatus(Item it, String status) => _runOwnerMutation(
        () => DataService.updateItemStatus(itemId: it.id, status: status),
      );

  Future<bool> _deleteListing(Item item) => _runOwnerMutation(
        () => DataService.deleteItemById(item.id),
      );

  Widget _buildBody(LocalizationController l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _MyListingsLoadFailure(
        message: _loadError!,
        onRetry: _load,
      );
    }
    return TabBarView(
      controller: _tabController,
      children: [
        _buildItemsGrid(_listedItems(_items), l10n, emptyKind: _EmptyKind.listed),
        _buildItemsGrid(_draftItems(_items), l10n, emptyKind: _EmptyKind.savedForLater),
      ],
    );
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
        leading: IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
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
          unselectedLabelColor: AppTheme.textSecondary(context),
          labelStyle: tabsStyle,
          unselectedLabelStyle: tabsStyle,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: [
            Tab(text: l10n.t('Meine Anzeigen')),
            Tab(text: l10n.t('für später gespeichert')),
          ],
        ),
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildItemsGrid(List<Item> visible, LocalizationController l10n, {required _EmptyKind emptyKind}) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    return visible.isEmpty
        ? _MyListingsEmptyState(kind: emptyKind, onTapCreate: _startCreateListing, canCreate: _canCreateListings)
        : GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: compact ? 0.78 : 1.02),
            itemCount: visible.length,
            itemBuilder: (_, i) {
              final it = visible[i];
              String statusLabel = switch (it.status) { 'active' => 'Aktiv', 'paused' => 'Pausiert', 'ended' => 'Beendet', 'draft' => 'Entwurf', _ => 'Aktiv' };
              Color chipColor = switch (it.status) { 'active' => const Color(0x3322C55E), 'paused' => const Color(0x33F59E0B), 'ended' => const Color(0x33F43F5E), 'draft' => AppTheme.textSecondary(context), _ => AppTheme.textSecondary(context) };
              return InkWell(
                onTap: () => ItemDetailsOverlay.showFullPage(
                  context,
                  item: it,
                  isOwnerPreview: true,
                  overrideAppBarTitle: it.status == 'draft' ? 'Für Später gespeichert' : 'Meine Anzeigen (Vorschau)',
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.30) : AppTheme.surfacePrimary(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.glassStroke(context)), boxShadow: AppTheme.cardShadow(context)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: AspectRatio(aspectRatio: 16 / 9, child: AppImage(url: it.photos.isNotEmpty ? it.photos.first : '', fit: BoxFit.cover))),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary(context), fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Text('${it.pricePerDay.toStringAsFixed(0)} €', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textPrimary(context))),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.t('pro Tag'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary(context)),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(8)), child: Text(statusLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textPrimary(context)))),
                          const Spacer(),
                          PopupMenuButton<String>(
                            tooltip: 'Status ändern',
                            enabled: !_actionBusy,
                            onSelected: (v) async {
                              if (it.status == 'draft') {
                                switch (v) {
                                  case 'publish':
                                    final changed = await _changeStatus(it, 'active');
                                    if (mounted && changed) {
                                      AppPopup.toast(context, icon: Icons.check_circle, title: 'Anzeige veröffentlicht');
                                    }
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
                                      _tabController.animateTo(1);
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
                                    final deleted = await _deleteListing(it);
                                    if (mounted && deleted) {
                                      AppPopup.toast(context, icon: Icons.delete_outline, title: 'Entwurf gelöscht');
                                    }
                                    break;
                                }
                              } else {
                                await _changeStatus(it, v);
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
                            child: Icon(Icons.more_horiz, color: AppTheme.textSecondary(context)),
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

class _MyListingsLoadFailure extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _MyListingsLoadFailure({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          label: '$message Lokale Daten bleiben unverändert. Erneut laden.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Lokale Daten bleiben unverändert.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Erneut laden'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _EmptyKind { listed, savedForLater }

class _MyListingsEmptyState extends StatelessWidget {
  final _EmptyKind kind;
  final VoidCallback onTapCreate;
  final bool canCreate;
  const _MyListingsEmptyState({required this.kind, required this.onTapCreate, required this.canCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final cs = Theme.of(context).colorScheme;

    // Use the same "Neue Anzeige" icon for both empty states, and make it tappable
    // to jump directly into the create-listing flow.
    final (String title, String hint) = switch (kind) {
      _EmptyKind.listed => (l10n.t('Du hast noch keine Anzeige.'), l10n.t('Tippe auf das Icon, um eine neue Anzeige zu erstellen.')),
      _EmptyKind.savedForLater => (l10n.t('Du hast noch keine Anzeige für später gespeichert.'), l10n.t('Tippe auf das Icon, um eine neue Anzeige zu erstellen.')),
    };

    final iconWidget = InkWell(
      onTap: canCreate ? onTapCreate : null,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.add_business, size: 64, color: cs.primary.withValues(alpha: 0.85)),
      ),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary(context), height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary(context), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
