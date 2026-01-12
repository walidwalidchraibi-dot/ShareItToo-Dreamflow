import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/widgets/item_details_overlay.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/models/user.dart' as model;
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/wishlist_selection_sheet.dart';

class ItemCard extends StatelessWidget {
  final Item item;
  final bool compact;

  const ItemCard({super.key, required this.item, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => ItemDetailsOverlay.showFullPage(context, item: item),
      borderRadius: BorderRadius.circular(16),
      mouseCursor: SystemMouseCursors.basic,
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: LayoutBuilder(builder: (context, constraints) {
          final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 240.0;
          // Use deterministic heights to avoid 1px rounding overflows.
          final imageH = (h * 0.58).floorToDouble();
          final infoH = (h - imageH).clamp(0.0, h);
          final iconSize = (imageH * 0.10).clamp(16.0, 22.0);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: imageH,
              width: double.infinity,
              child: Stack(children: [
                Positioned.fill(
                  child: AppImage(
                    url: item.photos.isNotEmpty ? item.photos.first : 'https://picsum.photos/seed/item_card_fallback/800/800',
                    fit: BoxFit.cover,
                  ),
                ),
                // Verified badge on the LEFT
                FutureBuilder<model.User?>(
                  future: DataService.getUserById(item.ownerId),
                  builder: (context, snap) {
                    final verified = snap.data?.isVerified == true;
                    return Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.all(iconSize * 0.35),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          verified ? Icons.verified : Icons.verified_outlined,
                          size: iconSize,
                          color: verified ? const Color(0xFF22C55E) : Colors.black45,
                        ),
                      ),
                    );
                  },
                ),
                // Wishlist heart on the RIGHT (manual selection flow)
                Positioned(top: 8, right: 5, child: _WishlistHeartButton(itemId: item.id, size: iconSize)),
              ]),
            ),
            SizedBox(
              height: infoH,
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.all(compact ? 10 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72), fontSize: 12),
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    Row(
                      children: [
                        Builder(
                          builder: (context) {
                            final unit = item.priceUnit;
                            final raw = item.priceRaw;
                            final suffix = unit == 'week' ? '€/Woche' : '€/Tag';
                            return Text(
                              'Preis: ${raw.toStringAsFixed(0)} $suffix',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            );
                          },
                        ),
                        const Spacer(),
                        const Icon(Icons.star, size: 14, color: Color(0xFFFB923C)),
                        const SizedBox(width: 2),
                        Text(
                          '4.8',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}

class _WishlistHeartButton extends StatefulWidget {
  final String itemId;
  final double size;
  const _WishlistHeartButton({required this.itemId, required this.size});

  @override
  State<_WishlistHeartButton> createState() => _WishlistHeartButtonState();
}

class _WishlistHeartButtonState extends State<_WishlistHeartButton> {
  String? listId; // null means not in any list
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = await DataService.getWishlistForItem(widget.itemId);
      setState(() { listId = id; });
    } catch (e) {
      debugPrint('[ItemCard] load wishlist state failed: ' + e.toString());
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _onTap() async {
    if (_loading) return;
    if (listId == null) {
      // First time: ask which wishlist
      final sel = await WishlistSelectionSheet.showAdd(context);
      if (sel != null && sel.isNotEmpty) {
        await DataService.setItemWishlist(widget.itemId, sel);
        setState(() { listId = sel; });
        final l10n = context.read<LocalizationController>();
        AppPopup.toast(context, icon: Icons.favorite, title: l10n.t('Zur Wunschliste hinzugefügt'));
      }
      return;
    }
    // Already in a wishlist: show small menu
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: Icon(Icons.swap_horiz, color: cs.primary),
                title: const Text('In andere Wunschliste verschieben'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final sel = await WishlistSelectionSheet.showMove(context, currentListId: listId!);
                  if (sel != null && sel.isNotEmpty) {
                    await DataService.setItemWishlist(widget.itemId, sel);
                    if (mounted) setState(() { listId = sel; });
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: const Text('Aus Wunschliste entfernen'),
                onTap: () async {
                  await DataService.removeItemFromWishlist(widget.itemId);
                  if (mounted) setState(() { listId = null; });
                  if (context.mounted) Navigator.of(ctx).pop();
                },
              ),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white.withValues(alpha: 0.92);
    final cs = Theme.of(context).colorScheme;
    final icon = listId == null ? Icons.favorite_border : Icons.favorite;
    final color = listId == null ? Colors.black54 : Colors.pinkAccent;
    return GestureDetector(
      onTap: _onTap,
      child: Container(
        padding: EdgeInsets.all(widget.size * 0.30),
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: widget.size * 0.90, color: color),
      ),
    );
  }
}

