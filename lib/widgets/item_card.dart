import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/widgets/item_details_overlay.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/shared_persistence_sync.dart';
import 'package:lendify/models/user.dart' as model;
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/wishlist_selection_sheet.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/widgets/listing_display_truth.dart';
import 'package:lendify/widgets/rating_badge.dart';
import 'package:lendify/widgets/listing_options_dialog.dart';
import 'package:lendify/widgets/long_press_feedback_wrapper.dart';

class ItemCard extends StatelessWidget {
  final Item item;
  final bool compact;
  final ListingOptionsContext? longPressContext;
  final VoidCallback? onContextActionCompleted;

  const ItemCard(
      {super.key,
      required this.item,
      this.compact = false,
      this.longPressContext,
      this.onContextActionCompleted});

  static double recommendedGridChildAspectRatio(
    BuildContext context, {
    bool compact = false,
    int columns = 2,
    double horizontalPadding = 32,
    double crossSpacing = 12,
  }) {
    final size = MediaQuery.sizeOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final theme = Theme.of(context).textTheme;

    final colWidth =
        (size.width - horizontalPadding - (crossSpacing * (columns - 1))) /
            columns;
    final imageHeight =
        colWidth * 0.66; // slightly shorter visual block to avoid long cards

    final titleFs = textScaler.scale(theme.bodyMedium?.fontSize ?? 14);
    final titleHeight =
        titleFs * (((theme.bodyMedium?.height) ?? 1.2)) * (compact ? 1 : 2);
    final cityFs = textScaler.scale(theme.bodySmall?.fontSize ?? 12);
    final cityHeight = cityFs * (((theme.bodySmall?.height) ?? 1.2));
    final priceFs = textScaler.scale(theme.bodyMedium?.fontSize ?? 14);
    final priceHeight = priceFs * (((theme.bodyMedium?.height) ?? 1.2));

    final verticalPadding = compact ? 16.0 : 20.0;
    const gaps = 8.0; // compact spacing between visible content blocks
    final textHeight =
        verticalPadding + titleHeight + cityHeight + priceHeight + gaps;
    final cardHeight = imageHeight + textHeight;
    return (colWidth / cardHeight).clamp(0.72, 1.08);
  }

  @override
  Widget build(BuildContext context) {
    return LongPressFeedbackWrapper(
      child: InkWell(
        onTap: () => ItemDetailsOverlay.showFullPage(context, item: item),
        onLongPress: longPressContext == null
            ? null
            : () => showListingOptionsDialog(context,
                item: item,
                contextType: longPressContext!,
                onWishlistChanged: onContextActionCompleted),
        borderRadius: BorderRadius.circular(16),
        mouseCursor: SystemMouseCursors.basic,
        child: Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: LayoutBuilder(builder: (context, constraints) {
            final width =
                constraints.maxWidth.isFinite ? constraints.maxWidth : 180.0;
            final maxHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : (width * 1.24);
            final reservedTextHeight = compact ? 58.0 : 68.0;
            final preferredImageH = width * 0.72;
            final imageH = preferredImageH.clamp(0.0,
                (maxHeight - reservedTextHeight).clamp(84.0, preferredImageH));
            final iconSize = (imageH * 0.10).clamp(16.0, 22.0);
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: imageH,
                    width: double.infinity,
                    child: Stack(children: [
                      Positioned.fill(
                        child: AppImage(
                          url: item.photos.isNotEmpty ? item.photos.first : '',
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Verification and rating come only from the real owner.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: FutureBuilder<model.User?>(
                            future: DataService.getUserById(item.ownerId),
                            builder: (context, snap) {
                              final verified = snap.data?.isVerified == true;
                              final rating =
                                  listingRatingForDisplay(snap.data?.avgRating);
                              return Stack(children: [
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: EdgeInsets.all(iconSize * 0.35),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      verified
                                          ? Icons.verified
                                          : Icons.verified_outlined,
                                      size: iconSize,
                                      color: verified
                                          ? BrandColors.success
                                          : Colors.black45,
                                    ),
                                  ),
                                ),
                                if (rating != null)
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: RatingBadge(rating: rating),
                                  ),
                              ]);
                            },
                          ),
                        ),
                      ),
                      // Wishlist heart on the RIGHT (manual selection flow)
                      Positioned(
                          top: 8,
                          right: 5,
                          child: _WishlistHeartButton(
                              itemId: item.id, size: iconSize)),
                    ]),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(compact ? 9 : 10,
                          compact ? 8 : 9, compact ? 9 : 10, compact ? 6 : 7),
                      child: LayoutBuilder(
                        builder: (context, textConstraints) {
                          final body = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface),
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                item.city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.72),
                                    fontSize: 12),
                              ),
                              SizedBox(height: compact ? 2 : 3),
                              Builder(
                                builder: (context) {
                                  final unit = item.priceUnit;
                                  final raw = item.priceRaw;
                                  return Text(
                                    '${listingCustomerPriceText(raw, currency: item.currency)} ${unit == 'week' ? '/ Woche' : '/ Tag'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  );
                                },
                              ),
                            ],
                          );

                          return Align(
                            alignment: Alignment.topLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: textConstraints.maxWidth,
                                  maxWidth: textConstraints.maxWidth,
                                ),
                                child: body,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ]);
          }),
        ),
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
  bool _stateKnown = false;
  final SharedPersistenceRefreshCoordinator _refreshCoordinator =
      SharedPersistenceRefreshCoordinator();
  StreamSubscription<String>? _savedStateSubscription;

  @override
  void initState() {
    super.initState();
    _savedStateSubscription = SharedPersistenceSync.changes.listen((key) {
      if (key == SharedPersistenceSync.wishlistStateKey ||
          key == SharedPersistenceSync.savedItemsKey) {
        unawaited(_refreshCoordinator.schedule(_load));
      }
    });
    unawaited(_refreshCoordinator.schedule(_load));
  }

  @override
  void dispose() {
    _refreshCoordinator.dispose();
    _savedStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final id = await DataService.getWishlistForItem(widget.itemId);
      if (!mounted) return;
      setState(() {
        listId = id;
        _stateKnown = true;
      });
    } catch (e) {
      debugPrint(
        '[ItemCard] load wishlist state failed (${e.runtimeType})',
      );
      if (mounted) setState(() => _stateKnown = false);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _onTap() async {
    if (_loading) return;
    if (!_stateKnown) {
      await _refreshCoordinator.schedule(_load);
      return;
    }
    try {
      if (listId == null) {
        // First time: ask which wishlist
        final sel = await WishlistSelectionSheet.showAdd(context);
        if (!mounted) return;
        if (sel != null && sel.isNotEmpty) {
          await DataService.setItemWishlist(widget.itemId, sel);
          if (!mounted) return;
          setState(() {
            listId = sel;
          });
          final l10n = context.read<LocalizationController>();
          AppPopup.toast(context,
              icon: Icons.favorite, title: l10n.t('Unter Gemerkt gespeichert'));
        }
        return;
      }
      // Already in a wishlist: show centered popup with the same design as
      // the wishlist selection (blurred background, glass card)
      final choice = await WishlistSelectionSheet.showManageOptions(context);
      if (!mounted) return;
      if (choice == 'move') {
        final currentListId = listId;
        if (currentListId == null) return;
        final sel = await WishlistSelectionSheet.showMove(context,
            currentListId: currentListId);
        if (!mounted) return;
        if (sel != null && sel.isNotEmpty) {
          await DataService.setItemWishlist(widget.itemId, sel);
          if (!mounted) return;
          setState(() {
            listId = sel;
          });
        }
      } else if (choice == 'remove') {
        await DataService.removeItemFromWishlist(widget.itemId);
        if (!mounted) return;
        setState(() {
          listId = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _stateKnown = false);
      await AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Gemerkt konnte nicht aktualisiert werden',
        message: 'Es wurde nichts als gespeichert bestätigt.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white.withValues(alpha: 0.92);
    final unavailable = !_loading && !_stateKnown;
    final icon = unavailable
        ? Icons.sync_problem_outlined
        : (listId == null ? Icons.favorite_border : Icons.favorite);
    final color = unavailable
        ? Theme.of(context).colorScheme.error
        : (listId == null ? Colors.black54 : Colors.pinkAccent);
    final label = unavailable
        ? 'Gemerkt-Status nicht verfügbar. Erneut laden.'
        : (listId == null ? 'Unter Gemerkt speichern' : 'Gemerkt verwalten');
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: _onTap,
          child: Container(
            padding: EdgeInsets.all(widget.size * 0.30),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: _loading
                ? SizedBox.square(
                    dimension: widget.size * 0.72,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, size: widget.size * 0.90, color: color),
          ),
        ),
      ),
    );
  }
}
