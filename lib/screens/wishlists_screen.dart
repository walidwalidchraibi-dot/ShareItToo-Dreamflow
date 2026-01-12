import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/services/data_service.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/widgets/wishlist_folder.dart';
import 'package:lendify/widgets/item_card.dart';

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
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neue Wunschliste erstellen'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Name der Wunschliste')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Erstellen')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await DataService.addCustomWishlist(name);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
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
          : _buildFolderGrid(context),
    );
  }
}

extension on _WishlistsScreenState {
  Widget _buildFolderGrid(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_lists.isEmpty) {
      return Center(child: Text(context.watch<LocalizationController>().t('Noch keine Wunschlisten'), style: Theme.of(context).textTheme.titleMedium));
    }
    final options = <WishlistFolderOption>[
      for (final wl in _lists)
        WishlistFolderOption(
          id: (wl['id'] ?? '').toString(),
          title: (wl['name'] ?? '').toString(),
          subtitle: wl['system'] == true ? _systemSubtitle((wl['id'] ?? '').toString()) : 'Eigene Liste',
          count: (_itemsByList[(wl['id'] ?? '').toString()] ?? const <Item>[]).length,
          system: wl['system'] == true,
        ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WishlistFolderGrid(
          options: options,
          onSelected: (id) async {
            // Navigate to detail view; refresh on return to update counts
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _WishlistFolderDetail(
                listId: id,
                title: _lists.firstWhere((e) => (e['id'] ?? '').toString() == id)['name'].toString(),
                system: _lists.firstWhere((e) => (e['id'] ?? '').toString() == id)['system'] == true,
              ),
            ));
            if (mounted) _reload();
          },
          crossAxisCount: 2,
        ),
        const SizedBox(height: 8),
        Divider(height: 24, thickness: 0.6, color: cs.onSurface.withValues(alpha: 0.06)),
      ]),
    );
  }

  String _systemSubtitle(String id) {
    if (id == DataService.wlSoonId) return 'Ich plane, diesen Artikel bald zu mieten';
    if (id == DataService.wlLaterId) return 'Interessant, aber nicht jetzt';
    if (id == DataService.wlAgainId) return 'Diesen Artikel hatte ich schon';
    return '';
  }
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

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 40),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              widget.system ? _systemEmptyText(widget.listId) : 'Noch nichts gespeichert',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.72)),
                            ),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => ItemCard(item: _items[i]),
                    ),
            ),
    );
  }

  String _systemEmptyText(String id) {
    if (id == DataService.wlSoonId) return 'Plane deine nächsten Mieten bewusst.';
    if (id == DataService.wlLaterId) return 'Sammle interessante Artikel für später.';
    if (id == DataService.wlAgainId) return 'Markiere Favoriten, die du erneut mieten willst.';
    return '';
  }
}
