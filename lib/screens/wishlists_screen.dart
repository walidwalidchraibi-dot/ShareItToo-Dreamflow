import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:lendify/models/item.dart';
import 'package:lendify/models/rental_cart.dart';
import 'package:lendify/screens/login_screen.dart';
import 'package:lendify/screens/private_pilot_checkout_screen.dart';
import 'package:lendify/services/auth_service.dart';
import 'package:lendify/services/data_service.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/widgets/item_card.dart';
import 'package:lendify/widgets/listing_options_dialog.dart';
import 'package:lendify/widgets/wishlist_mosaic_card.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/navigation/main_nav_controller.dart';
import 'package:lendify/theme.dart';

class RentalCartScreen extends StatefulWidget {
  const RentalCartScreen({super.key});

  @override
  State<RentalCartScreen> createState() => _RentalCartScreenState();
}

/// Compatibility type for callers that still use the pre-G2A screen name.
/// Persisted wishlist values remain on the original keys for safe rollback.
@Deprecated('Use RentalCartScreen; saved wishlist data remains compatible.')
class WishlistsScreen extends RentalCartScreen {
  const WishlistsScreen({super.key});
}

class _RentalCartScreenState extends State<RentalCartScreen> {
  bool _loading = true;
  RentalCart _rentalCart = const RentalCart(localDeviceOnly: true);
  String? _busyCartItemId;
  List<Map<String, dynamic>> _lists = [];
  Map<String, List<Item>> _itemsByList = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        DataService.getWishlists(),
        DataService.getItemsByWishlist(),
        DataService.getRentalCart(),
      ]);
      if (!mounted) return;
      setState(() {
        _lists = results[0] as List<Map<String, dynamic>>;
        _itemsByList = results[1] as Map<String, List<Item>>;
        _rentalCart = results[2] as RentalCart;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      await AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Mietkorb konnte nicht geladen werden',
        message: 'Bitte versuche es erneut.',
      );
    }
  }

  Future<void> _addProject() async {
    final controller = TextEditingController();
    final title = await AppPopup.showCustom<String>(
      context,
      icon: Icons.create_new_folder_outlined,
      title: 'Neues Projekt',
      showCloseIcon: false,
      showLeading: false,
      showAccentLine: false,
      body: _CreateWishlistPopupBody(controller: controller),
    );
    controller.dispose();
    if (title == null || title.trim().isEmpty) return;
    try {
      await DataService.addRentalCartProject(title: title);
      await _reload();
    } catch (error) {
      if (!mounted) return;
      await AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Projekt konnte nicht gespeichert werden',
      );
    }
  }

  Future<void> _recheckCart() async {
    try {
      final cart = await DataService.recheckRentalCart();
      if (mounted) setState(() => _rentalCart = cart);
    } catch (error) {
      if (!mounted) return;
      await AppPopup.toast(
        context,
        icon: Icons.cloud_off_outlined,
        title: 'Prüfung gerade nicht möglich',
        message: 'Dein Mietkorb bleibt gespeichert.',
      );
    }
  }

  Future<void> _removeCartItem(String id) async {
    try {
      final cart = await DataService.removeRentalCartItem(id);
      if (mounted) setState(() => _rentalCart = cart);
    } catch (error) {
      if (!mounted) return;
      await AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Artikel konnte nicht entfernt werden',
      );
    }
  }

  Future<void> _removeProject(String id) async {
    try {
      final cart = await DataService.removeRentalCartProject(id);
      if (mounted) setState(() => _rentalCart = cart);
    } catch (error) {
      if (!mounted) return;
      await AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Projekt konnte nicht entfernt werden',
      );
    }
  }

  Future<void> _assignCartItem(RentalCartItem item) async {
    const unassigned = '__unassigned__';
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Projekt zuordnen'),
              subtitle: Text('Die Zuordnung ändert keine Reservierung.'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Ohne Projekt'),
              trailing: item.projectId == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(unassigned),
            ),
            for (final project in _rentalCart.projects)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(project.title),
                trailing: item.projectId == project.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(project.id),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    try {
      final cart = await DataService.assignRentalCartItemToProject(
        itemId: item.id,
        projectId: selected == unassigned ? null : selected,
      );
      if (mounted) setState(() => _rentalCart = cart);
    } catch (error) {
      if (!mounted) return;
      await AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Projektzuordnung konnte nicht gespeichert werden',
      );
    }
  }

  Future<void> _openCartItem(RentalCartItem cartItem) async {
    if (_busyCartItemId != null) return;
    final session = await AuthService.readSession();
    if (!mounted) return;
    if (session == null) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(returnTabIndex: 1),
      ));
      return;
    }
    setState(() => _busyCartItemId = cartItem.id);
    try {
      final checked = await DataService.recheckRentalCart();
      final current = checked.items.firstWhere(
        (item) => item.id == cartItem.id,
        orElse: () => cartItem,
      );
      if (current.quoteStatus == 'unavailable') {
        if (!mounted) return;
        setState(() => _rentalCart = checked);
        await AppPopup.toast(
          context,
          icon: Icons.event_busy_outlined,
          title: 'Zeitraum derzeit nicht verfügbar',
          message: 'Der Artikel bleibt in deinem Mietkorb.',
        );
        return;
      }
      final item = await DataService.getItemById(current.listingId);
      if (!mounted) return;
      if (item == null) {
        await AppPopup.toast(
          context,
          icon: Icons.inventory_2_outlined,
          title: 'Artikel derzeit nicht verfügbar',
        );
        return;
      }
      setState(() => _rentalCart = checked);
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PrivatePilotCheckoutScreen(
          item: item,
          range: DateTimeRange(
            start: current.startDate,
            end: current.endDate,
          ),
        ),
      ));
      if (mounted) await _reload();
    } catch (error) {
      if (!mounted) return;
      await AppPopup.toast(
        context,
        icon: Icons.cloud_off_outlined,
        title: 'Serverprüfung fehlgeschlagen',
        message: 'Es wurde keine Reservierung erstellt.',
      );
    } finally {
      if (mounted) setState(() => _busyCartItemId = null);
    }
  }

  Future<void> _addCustomList() async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = await AppPopup.showCustom<String>(
      context,
      icon: Icons.bookmark_add_outlined,
      title: 'Neue Merkliste',
      showCloseIcon: false,
      showLeading: false,
      showAccentLine: false,
      cardBackgroundColor: isDark ? null : AppTheme.surfacePrimary(context),
      body: _CreateWishlistPopupBody(controller: controller),
    );
    if (name != null && name.isNotEmpty) {
      await DataService.addCustomWishlist(name);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back)),
        title: Text(l10n.t('Mietkorb')),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Neue Merkliste',
            onPressed: _addCustomList,
            icon: const Icon(Icons.add),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRentalCartSection(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Semantics(
                        container: true,
                        label: l10n.t('saved.nonBindingSemantics'),
                        child: ExcludeSemantics(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bookmark_border,
                                      size: 20, color: cs.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.t('Gemerkt'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.t('saved.nonBindingNotice'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color:
                                          cs.onSurface.withValues(alpha: 0.55),
                                      height: 1.5,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildFolderGrid(context)),
              ],
            ),
    );
  }
}

extension on _RentalCartScreenState {
  Widget _buildRentalCartSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cart = _rentalCart;
    final itemHeight =
        cart.items.isEmpty ? 72.0 : math.min(300.0, 96.0 * cart.items.length);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Im Mietkorb – noch nicht reserviert',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Verfügbarkeit und Preis werden vor jeder Anfrage neu geprüft.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.62),
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Verfügbarkeit und Preis neu prüfen',
                  onPressed: cart.items.isEmpty ? null : _recheckCart,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (cart.syncPending)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Kontosynchronisierung ausstehend – die lokale Kopie bleibt erhalten.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            if (cart.projects.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final project in cart.projects)
                    Chip(
                      avatar: const Icon(Icons.folder_outlined, size: 16),
                      label: Text(project.title),
                      onDeleted: () => _removeProject(project.id),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: itemHeight,
              child: cart.items.isEmpty
                  ? Center(
                      child: Text(
                        'Noch keine Mietzeiträume vorbereitet.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.58),
                            ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        final title =
                            (item.listing['title'] ?? 'Mietartikel').toString();
                        RentalCartProject? project;
                        for (final entry in cart.projects) {
                          if (entry.id == item.projectId) {
                            project = entry;
                            break;
                          }
                        }
                        final status = switch (item.quoteStatus) {
                          'current' => 'Aktuell geprüft',
                          'changed' => 'Preis oder Verfügbarkeit geändert',
                          'unavailable' => 'Derzeit nicht verfügbar',
                          _ => cart.localDeviceOnly
                              ? 'Lokal vorbereitet – Serverprüfung nach Anmeldung'
                              : 'Serverprüfung erforderlich',
                        };
                        final quoteLabel = _informativeQuoteLabel(item);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            item.quoteStatus == 'unavailable'
                                ? Icons.event_busy_outlined
                                : Icons.event_available_outlined,
                            color: item.quoteStatus == 'unavailable'
                                ? cs.error
                                : cs.primary,
                          ),
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_cartDate(item.startDate)} – ${_cartDate(item.endDate)}'
                            '${project == null ? '' : ' · ${project.title}'}'
                            '${quoteLabel == null ? '' : '\n$quoteLabel'}\n$status',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Projekt zuordnen',
                                onPressed: () => _assignCartItem(item),
                                icon: const Icon(Icons.drive_file_move_outline),
                              ),
                              IconButton(
                                tooltip: 'Einzelmiete prüfen',
                                onPressed: _busyCartItemId == null
                                    ? () => _openCartItem(item)
                                    : null,
                                icon: _busyCartItemId == item.id
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.arrow_forward),
                              ),
                              IconButton(
                                tooltip: 'Aus Mietkorb entfernen',
                                onPressed: () => _removeCartItem(item.id),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _addProject,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('Projekt anlegen'),
                ),
                const Spacer(),
                if (cart.localDeviceOnly && cart.items.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginScreen(returnTabIndex: 1),
                      ),
                    ),
                    child: const Text('Anmelden & synchronisieren'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _cartDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  String? _informativeQuoteLabel(RentalCartItem item) {
    if (item.quoteStatus == 'unavailable') return null;
    final quoteEnvelope = item.quote;
    final quote = quoteEnvelope?['quote'];
    if (quote is! Map) return null;
    final totalMinor = (quote['totalMinor'] as num?)?.toInt();
    if (totalMinor == null || totalMinor < 0) return null;
    final currency = (quote['currency'] ?? 'EUR').toString();
    final amount = (totalMinor / 100).toStringAsFixed(2).replaceAll('.', ',');
    return 'Informative Preisangabe: $amount $currency';
  }

  Widget _buildFolderGrid(BuildContext context) {
    if (_lists.isEmpty) {
      return Center(
          child: Text(
              context
                  .watch<LocalizationController>()
                  .t('Noch keine Merklisten'),
              style: Theme.of(context).textTheme.titleMedium));
    }

    // Build data for mosaic cards
    final cards = _lists.map((wl) {
      final id = (wl['id'] ?? '').toString();
      // Make a mutable copy first, then sort. Sorting an unmodifiable/const list throws "Unsupported operation: sort".
      final items = List<Item>.from(_itemsByList[id] ?? const <Item>[])
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final photos = <String>[
        for (int i = 0; i < (items.length < 4 ? items.length : 4); i++)
          ((items[i].photos.isNotEmpty) ? items[i].photos.first : '')
      ];
      return (
        id: id,
        title: (wl['name'] ?? '').toString(),
        subtitle: wl['system'] == true ? _systemSubtitle(id) : 'Eigene Liste',
        count: items.length,
        photos: photos,
        system: wl['system'] == true,
      );
    }).toList();

    final columnCount = _wishlistGridColumnCount(context);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        // Dynamically size height so the 1:1 image mosaic + text fits without overflow
        childAspectRatio:
            _mosaicChildAspectRatio(context, columnCount: columnCount),
      ),
      itemBuilder: (_, i) {
        final c = cards[i];
        return WishlistMosaicCard(
          id: c.id,
          title: c.title,
          subtitle: c.subtitle,
          count: c.count,
          photoUrls: c.photos,
          onTap: () async {
            await Navigator.of(context).push(_mosaicRoute(_WishlistFolderDetail(
              listId: c.id,
              title: c.title,
              system: c.system,
            )));
            if (mounted) _reload();
          },
        );
      },
    );
  }

  String _systemSubtitle(String id) {
    if (id == DataService.wlSoonId) {
      return 'Ich plane, diesen Artikel bald zu mieten';
    }
    if (id == DataService.wlLaterId) return 'Interessant, aber nicht jetzt';
    if (id == DataService.wlAgainId) return 'Diesen Artikel hatte ich schon';
    return '';
  }
}

Route _mosaicRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 210),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: page,
      ),
    ),
  );
}

class _WishlistFolderDetail extends StatefulWidget {
  final String listId;
  final String title;
  final bool system;
  const _WishlistFolderDetail(
      {required this.listId, required this.title, required this.system});

  @override
  State<_WishlistFolderDetail> createState() => _WishlistFolderDetailState();
}

class _WishlistFolderDetailState extends State<_WishlistFolderDetail> {
  bool _loading = true;
  List<Item> _items = const [];
  bool _editMode = false;
  String? _title; // Null-safe to survive hot reload without initState re-run

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final by = await DataService.getItemsByWishlist();
      if (!mounted) return;
      _items = by[widget.listId] ?? const <Item>[];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _headerSubline() {
    if (widget.listId == DataService.wlSoonId) {
      return 'Plane, was du bald mieten möchtest.';
    }
    if (widget.listId == DataService.wlLaterId) {
      return 'Sammle Ideen für spätere Mieten.';
    }
    if (widget.listId == DataService.wlAgainId) {
      return 'Artikel, die du erneut mieten möchtest.';
    }
    return 'Eigene Sammlung';
  }

  String _systemDetailSubline(String id) {
    if (id == DataService.wlSoonId) {
      return 'Speichere passende Artikel aus Entdecken,\num deine nächste Miete zu planen.';
    }
    if (id == DataService.wlLaterId) {
      return 'Sammle Ideen für spätere Mieten\nund finde sie hier wieder.';
    }
    if (id == DataService.wlAgainId) {
      return 'Merke dir Artikel, die du bereits\ngemietet hast und erneut mieten möchtest.';
    }
    return 'Speichere passende Artikel aus Entdecken.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back)),
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_title ?? widget.title),
          Text(
            _headerSubline(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w400,
                ),
          ),
        ]),
        centerTitle: true,
        toolbarHeight: 64,
        actions: [
          if (!widget.system || _items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () async {
                final items = <({
                  String value,
                  IconData icon,
                  String label,
                  Color color
                })>[];
                if (_items.isNotEmpty) {
                  items.add((
                    value: 'edit',
                    icon: _editMode
                        ? Icons.check_circle_outline
                        : Icons.edit_outlined,
                    label: _editMode ? 'Fertig' : 'Merkliste bearbeiten',
                    color:
                        isDark ? Colors.white : AppTheme.textSecondary(context)
                  ));
                }
                if (!widget.system) {
                  items.addAll([
                    (
                      value: 'rename',
                      icon: Icons.drive_file_rename_outline,
                      label: 'Name ändern',
                      color: isDark
                          ? Colors.white
                          : AppTheme.textSecondary(context)
                    ),
                    (
                      value: 'delete',
                      icon: Icons.delete_outline,
                      label: 'Merkliste löschen',
                      color: cs.error
                    ),
                  ]);
                }
                final choice =
                    await AppPopup.showMenuActions(context, items: items);
                switch (choice) {
                  case 'rename':
                    await _renameWishlist();
                    break;
                  case 'edit':
                    setState(() => _editMode = !_editMode);
                    break;
                  case 'delete':
                    await _deleteWishlist();
                    break;
                }
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.favorite_border_rounded,
                                      size: 48,
                                      color: isDark
                                          ? cs.onSurface.withValues(alpha: 0.18)
                                          : cs.onSurface
                                              .withValues(alpha: 0.26)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Noch keine Artikel gespeichert',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            color: cs.onSurface
                                                .withValues(alpha: 0.75),
                                            fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.system
                                        ? _systemDetailSubline(widget.listId)
                                        : 'Speichere passende Artikel aus Entdecken.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: cs.onSurface.withValues(
                                                alpha: isDark ? 0.5 : 0.58),
                                            height: 1.4),
                                  ),
                                  const SizedBox(height: 24),
                                  TextButton.icon(
                                    onPressed: () {
                                      if (mounted) {
                                        context
                                            .read<MainNavController>()
                                            .setIndex(0);
                                      }
                                      Navigator.of(context)
                                          .popUntil((r) => r.isFirst);
                                    },
                                    icon: const Icon(Icons.explore_outlined,
                                        size: 18),
                                    label: const Text('Artikel entdecken'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: cs.primary,
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ]),
                          ),
                        ),
                      ],
                    )
                  : Column(children: [
                      if (_editMode)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? cs.surface.withValues(alpha: 0.08)
                                : cs.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: cs.primary.withValues(alpha: 0.18)),
                          ),
                          child: Row(children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: isDark ? Colors.white70 : cs.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bearbeitungsmodus: Tippe auf das X, um Artikel zu entfernen.',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color:
                                          isDark ? Colors.white : cs.onSurface,
                                    ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _editMode = false),
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    isDark ? Colors.white : cs.primary,
                              ),
                              child: const Text('Fertig'),
                            ),
                          ]),
                        ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio:
                                _wishlistDetailChildAspectRatio(context),
                          ),
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final item = _items[i];
                            return Stack(children: [
                              Positioned.fill(
                                  child: ItemCard(
                                      item: item,
                                      longPressContext:
                                          ListingOptionsContext.wishlist,
                                      onContextActionCompleted: _load)),
                              if (_editMode)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: InkWell(
                                    onTap: () async {
                                      try {
                                        await DataService
                                            .removeItemFromWishlist(item.id);
                                        if (mounted) {
                                          setState(() {
                                            _items = List<Item>.from(_items)
                                              ..removeAt(i);
                                          });
                                        }
                                      } catch (_) {}
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: cs.error.withValues(alpha: 0.90),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                            ]);
                          },
                        ),
                      ),
                    ]),
            ),
    );
  }

  Future<void> _renameWishlist() async {
    final controller = TextEditingController(text: _title ?? widget.title);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newName = await AppPopup.showCustom<String>(
      context,
      icon: Icons.drive_file_rename_outline,
      title: 'Merkliste umbenennen',
      showCloseIcon: false,
      showLeading: false,
      showAccentLine: false,
      cardBackgroundColor: isDark ? null : AppTheme.surfacePrimary(context),
      body: _RenameWishlistPopupBody(controller: controller),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      await DataService.renameCustomWishlist(
          id: widget.listId, newName: newName.trim());
      if (mounted) setState(() => _title = newName.trim());
    }
  }

  Future<void> _deleteWishlist() async {
    // Simple confirm using AppPopup
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool? confirmed = await AppPopup.showCustom<bool>(
      context,
      icon: Icons.delete_outline,
      title: 'Merkliste löschen',
      showCloseIcon: false,
      showLeading: false,
      showAccentLine: false,
      cardBackgroundColor: isDark ? null : AppTheme.surfacePrimary(context),
      body: _ConfirmDeleteWishlistBody(name: _title ?? widget.title),
    );
    if (confirmed == true) {
      await DataService.deleteCustomWishlist(widget.listId);
      if (mounted) Navigator.of(context).maybePop();
    }
  }
}

// Compute a childAspectRatio that gives enough vertical room for
// 1:1 mosaic image + text block without causing pixel overflow,
// while staying visually balanced on various widths and text scales.
int _wishlistGridColumnCount(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final textScale = MediaQuery.textScalerOf(context).scale(1);
  return size.width < 360 || textScale >= 1.6 ? 1 : 2;
}

double _mosaicChildAspectRatio(
  BuildContext context, {
  required int columnCount,
}) {
  final size = MediaQuery.sizeOf(context);
  final textScaler = MediaQuery.textScalerOf(context);

  // Grid paddings and spacing must match GridView.builder settings above
  const horizontalPadding = 32.0; // 16 + 16
  const crossSpacing = 12.0;

  // Column width per card
  final totalSpacing = crossSpacing * (columnCount - 1);
  final colWidth =
      (size.width - horizontalPadding - totalSpacing) / columnCount;

  // Estimate height from actual card layout: mosaic (fixed aspect) + padded text block.
  // This keeps the card frame ending right below the count text without dead space.
  final theme = Theme.of(context).textTheme;
  final titleFs = textScaler.scale(theme.titleSmall?.fontSize ?? 16);
  final labelFs = textScaler.scale(theme.labelSmall?.fontSize ?? 12);
  final titleLines = textScaler.scale(1) >= 1.6 ? 2 : 1;
  final titleHeight = titleFs * (theme.titleSmall?.height ?? 1.2) * titleLines;
  final labelHeight = labelFs * (theme.labelSmall?.height ?? 1.2);

  const mosaicAspect = 1.18; // width / height used in card
  final mosaicHeight = colWidth / mosaicAspect;
  final textBlockHeight =
      6 + titleHeight + 2 + labelHeight + 18; // padding, gaps and font metrics

  final totalHeight = mosaicHeight + textBlockHeight;
  final ratio = colWidth / totalHeight;
  // Keep within a safe band to avoid overflow on small screens or large text scales
  final maxRatio = columnCount == 1 ? 0.96 : 0.9;
  return math.min(maxRatio, math.max(0.62, ratio));
}

// Keep wishlist detail item cards a bit tighter than the generic grid,
// while still leaving enough room for two title lines on smaller phones.
double _wishlistDetailChildAspectRatio(BuildContext context) {
  final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
  final base = ItemCard.recommendedGridChildAspectRatio(context);
  final extra = textScale > 1.1 ? 0.06 : 0.10;
  return (base + extra).clamp(0.82, 1.0);
}

class _CreateWishlistPopupBody extends StatelessWidget {
  final TextEditingController controller;
  const _CreateWishlistPopupBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final inputBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : AppTheme.surfaceSecondary(context);
    final inputBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : cs.onSurface.withValues(alpha: 0.10)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Ordne Artikel nach Anlass, Projekt oder Zeitraum.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppTheme.textSecondary(context)),
                textAlign: TextAlign.center,
              ),
            ),
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) =>
                  Navigator.of(context).maybePop(controller.text.trim()),
              style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textPrimary(context),
                  fontSize: 15),
              cursorColor: cs.primary,
              decoration: InputDecoration(
                hintText: 'z. B. Umzug, Werkzeug, Gartenparty',
                hintStyle: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : AppTheme.textDisabled(context),
                    fontSize: 14),
                filled: true,
                fillColor: inputBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: inputBorder,
                enabledBorder: inputBorder,
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: cs.primary.withValues(alpha: 0.35), width: 1)),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppTheme.textPrimary(context),
                      side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : cs.onSurface.withValues(alpha: 0.12)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Abbrechen'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).maybePop(controller.text.trim()),
                  style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Erstellen'),
                ),
              ),
            ]),
          ]),
    );
  }
}

class _RenameWishlistPopupBody extends StatelessWidget {
  final TextEditingController controller;
  const _RenameWishlistPopupBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final inputBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppTheme.surfaceSecondary(context);
    final inputBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : cs.onSurface.withValues(alpha: 0.10)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textPrimary(context)),
              cursorColor: cs.primary,
              decoration: InputDecoration(
                hintText: 'Neuer Name',
                hintStyle: TextStyle(
                    color: isDark
                        ? Colors.white70
                        : AppTheme.textDisabled(context)),
                filled: true,
                fillColor: inputBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: inputBorder,
                enabledBorder: inputBorder,
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary, width: 1.2)),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? Colors.white70
                          : AppTheme.textPrimary(context),
                      side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.20)
                              : cs.onSurface.withValues(alpha: 0.12)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Abbrechen'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context)
                      .maybePop<String>(controller.text.trim()),
                  style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Umbenennen'),
                ),
              ),
            ]),
          ]),
    );
  }
}

class _ConfirmDeleteWishlistBody extends StatelessWidget {
  final String name;
  const _ConfirmDeleteWishlistBody({required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                'Möchtest du "$name" wirklich löschen?\nAlle Artikel-Zuordnungen werden entfernt.',
                style: TextStyle(
                    color: isDark
                        ? Colors.white70
                        : AppTheme.textSecondary(context))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(false),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? Colors.white70
                          : AppTheme.textPrimary(context),
                      side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.20)
                              : cs.onSurface.withValues(alpha: 0.12)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Abbrechen'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(true),
                  style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Löschen'),
                ),
              ),
            ]),
          ]),
    );
  }
}
