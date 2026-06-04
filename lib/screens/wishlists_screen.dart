import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:lendify/models/item.dart';
import 'package:lendify/services/data_service.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/widgets/item_card.dart';
import 'package:lendify/widgets/wishlist_mosaic_card.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/navigation/main_nav_controller.dart';

class WishlistsScreen extends StatefulWidget {
  const WishlistsScreen({super.key});

  @override
  State<WishlistsScreen> createState() => _WishlistsScreenState();
}

class _WishlistsScreenState extends State<WishlistsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _lists = [];
  Map<String, List<Item>> _itemsByList = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final lists = await DataService.getWishlists();
    final by = await DataService.getItemsByWishlist();
    setState(() { _lists = lists; _itemsByList = by; _loading = false; });
  }

  Future<void> _addCustomList() async {
    final controller = TextEditingController();
    final name = await AppPopup.showCustom<String>(
      context,
      icon: Icons.bookmark_add_outlined,
      title: 'Neue Wunschliste',
      showCloseIcon: false,
      showLeading: false,
      showAccentLine: false,
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
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
        title: Text(l10n.t('Wunschlisten')),
        centerTitle: true,
        actions: [IconButton(onPressed: _addCustomList, icon: const Icon(Icons.add))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Text(
                        'Merke dir Artikel, die du bald brauchst oder später mieten möchtest.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.55),
                          height: 1.5,
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

extension on _WishlistsScreenState {
  Widget _buildFolderGrid(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_lists.isEmpty) {
      return Center(child: Text(context.watch<LocalizationController>().t('Noch keine Wunschlisten'), style: Theme.of(context).textTheme.titleMedium));
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

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        // Dynamically size height so the 1:1 image mosaic + text fits without overflow
        childAspectRatio: _mosaicChildAspectRatio(context),
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
    if (id == DataService.wlSoonId) return 'Ich plane, diesen Artikel bald zu mieten';
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
        scale: Tween<double>(begin: 0.98, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: page,
      ),
    ),
  );
}

class _WishlistFolderDetail extends StatefulWidget {
  final String listId;
  final String title;
  final bool system;
  const _WishlistFolderDetail({required this.listId, required this.title, required this.system});

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
      _items = by[widget.listId] ?? const <Item>[];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _headerSubline() {
    if (widget.listId == DataService.wlSoonId) return 'Plane, was du bald mieten möchtest.';
    if (widget.listId == DataService.wlLaterId) return 'Sammle Ideen für spätere Mieten.';
    if (widget.listId == DataService.wlAgainId) return 'Artikel, die du erneut mieten möchtest.';
    return 'Eigene Sammlung';
  }

  String _systemDetailSubline(String id) {
    if (id == DataService.wlSoonId) return 'Speichere passende Artikel aus Erkunden,\num deine nächste Miete zu planen.';
    if (id == DataService.wlLaterId) return 'Sammle Ideen für spätere Mieten\nund finde sie hier wieder.';
    if (id == DataService.wlAgainId) return 'Merke dir Artikel, die du bereits\ngemietet hast und erneut mieten möchtest.';
    return 'Speichere passende Artikel aus Erkunden.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
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
                final items = <({String value, IconData icon, String label, Color color})>[];
                items.add((value: 'edit', icon: _editMode ? Icons.check_circle_outline : Icons.edit_outlined, label: _editMode ? 'Fertig' : 'Wunschliste bearbeiten', color: Colors.white));
                if (!widget.system) {
                  items.addAll([
                    (value: 'rename', icon: Icons.drive_file_rename_outline, label: 'Name ändern', color: Colors.white),
                    (value: 'delete', icon: Icons.delete_outline, label: 'Wunschliste löschen', color: cs.error),
                  ]);
                }
                final choice = await AppPopup.showMenuActions(context, items: items);
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
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.favorite_border_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.18)),
                              const SizedBox(height: 16),
                              Text(
                                'Noch keine Artikel gespeichert',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.system ? _systemDetailSubline(widget.listId) : 'Speichere passende Artikel aus Erkunden.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.5), height: 1.4),
                              ),
                              const SizedBox(height: 24),
                              TextButton.icon(
                                onPressed: () {
                                  if (mounted) {
                                    context.read<MainNavController>().setIndex(0);
                                  }
                                  Navigator.of(context).popUntil((r) => r.isFirst);
                                },
                                icon: const Icon(Icons.explore_outlined, size: 18),
                                label: const Text('Artikel entdecken'),
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.primary,
                                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_outline, size: 18, color: Colors.white70),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bearbeitungsmodus: Tippe auf das X, um Artikel zu entfernen.',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _editMode = false),
                              style: TextButton.styleFrom(foregroundColor: Colors.white),
                              child: const Text('Fertig'),
                            ),
                          ]),
                        ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: _wishlistDetailChildAspectRatio(context),
                          ),
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final item = _items[i];
                            return Stack(children: [
                              Positioned.fill(child: ItemCard(item: item)),
                              if (_editMode)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: InkWell(
                                    onTap: () async {
                                      try {
                                        await DataService.removeItemFromWishlist(item.id);
                                        if (mounted) {
                                          setState(() { _items = List<Item>.from(_items)..removeAt(i); });
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
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
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
    final newName = await AppPopup.showCustom<String>(
      context,
      icon: Icons.drive_file_rename_outline,
      title: 'Wunschliste umbenennen',
      showCloseIcon: false,
      showLeading: false,
      showAccentLine: false,
      body: _RenameWishlistPopupBody(controller: controller),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      await DataService.renameCustomWishlist(id: widget.listId, newName: newName.trim());
      if (mounted) setState(() => _title = newName.trim());
    }
  }

  Future<void> _deleteWishlist() async {
    // Simple confirm using AppPopup
    bool? confirmed = await AppPopup.showCustom<bool>(
      context,
      icon: Icons.delete_outline,
      title: 'Wunschliste löschen',
      showCloseIcon: false,
      showLeading: false,
      showAccentLine: false,
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
double _mosaicChildAspectRatio(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final textScale = MediaQuery.textScaleFactorOf(context);

  // Grid paddings and spacing must match GridView.builder settings above
  const horizontalPadding = 32.0; // 16 + 16
  const crossSpacing = 12.0;

  // Column width per card
  final colWidth = (size.width - horizontalPadding - crossSpacing) / 2.0;

  // Estimate height from actual card layout: mosaic (fixed aspect) + padded text block.
  // This keeps the card frame ending right below the count text without dead space.
  final theme = Theme.of(context).textTheme;
  final titleFs = (theme.titleSmall?.fontSize ?? 16) * textScale;
  final labelFs = (theme.labelSmall?.fontSize ?? 12) * textScale;
  final titleHeight = titleFs * (theme.titleSmall?.height ?? 1.2);
  final labelHeight = labelFs * (theme.labelSmall?.height ?? 1.2);

  const mosaicAspect = 1.18; // width / height used in card
  final mosaicHeight = colWidth / mosaicAspect;
  final textBlockHeight = 6 + titleHeight + 2 + labelHeight + 2; // padding + gaps

  final totalHeight = mosaicHeight + textBlockHeight;
  final ratio = colWidth / totalHeight;
  // Keep within a safe band to avoid overflow on small screens or large text scales
  return math.min(0.9, math.max(0.7, ratio));
}

// Compute aspect ratio for wishlist detail item grid so the ItemCard has
// enough vertical room for 2 text lines + city + price without overflow on phones.
double _wishlistDetailChildAspectRatio(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final textScale = MediaQuery.textScaleFactorOf(context);

  const horizontalPadding = 32.0; // 16 + 16
  const crossSpacing = 12.0;
  final colWidth = (size.width - horizontalPadding - crossSpacing) / 2.0;

  final theme = Theme.of(context).textTheme;
  final titleFs = (theme.titleSmall?.fontSize ?? 14) * textScale;
  final titleHeight = titleFs * (theme.titleSmall?.height ?? 1.2) * 2; // 2 lines
  final cityFs = (theme.bodySmall?.fontSize ?? 12) * textScale;
  final cityHeight = cityFs * (theme.bodySmall?.height ?? 1.2);
  final priceFs = (theme.bodyMedium?.fontSize ?? 14) * textScale;
  final priceHeight = priceFs * (theme.bodyMedium?.height ?? 1.2);

  const verticalPadding = 24.0; // 12 top + 12 bottom inside ItemCard text area
  const gaps = 8.0; // 2 + 6 between text blocks
  final textBlockHeight = verticalPadding + gaps + titleHeight + cityHeight + priceHeight;

  // In ItemCard the info area is ~42% of the card height (58% image, 42% text)
  final ratioLimit = (colWidth * 0.42) / textBlockHeight;
  final safeRatio = (ratioLimit - 0.02).clamp(0.32, 0.88); // allow extra height on small phones
  return safeRatio.toDouble();
}

class _CreateWishlistPopupBody extends StatelessWidget {
  final TextEditingController controller;
  const _CreateWishlistPopupBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inputBg = Colors.white.withValues(alpha: 0.06);
    final inputBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Ordne Artikel nach Anlass, Projekt oder Zeitraum.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ),
        TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).maybePop(controller.text.trim()),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          cursorColor: cs.primary,
          decoration: InputDecoration(
            hintText: 'z. B. Umzug, Werkzeug, Gartenparty',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.35), width: 1)),
          ),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: 0.7), side: BorderSide(color: Colors.white.withValues(alpha: 0.15)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Abbrechen'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(context).maybePop(controller.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 14)),
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
    final cs = Theme.of(context).colorScheme;
    final inputBg = Colors.white.withValues(alpha: 0.08);
    final inputBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: cs.primary,
          decoration: InputDecoration(
            hintText: 'Neuer Name',
            hintStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 1.2)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: BorderSide(color: Colors.white.withValues(alpha: 0.20)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Abbrechen'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(context).maybePop<String>(controller.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Möchtest du "' + name + '" wirklich löschen?\nAlle Artikel-Zuordnungen werden entfernt.', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(false),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: BorderSide(color: Colors.white.withValues(alpha: 0.20)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Abbrechen'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(context).maybePop(true),
              style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Löschen'),
            ),
          ),
        ]),
      ]),
    );
  }
}
