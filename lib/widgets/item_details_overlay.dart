import 'dart:ui';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart' as f;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/models/user.dart' as model;
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/app_link_service.dart';
import 'package:lendify/models/category.dart';
import 'package:lendify/screens/public_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/screens/select_rental_duration_screen.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/widgets/user_avatar.dart';
import 'package:lendify/services/maps_service.dart';
import 'package:lendify/screens/bookings_screen.dart';
import 'package:lendify/screens/message_thread_screen.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/sit_overflow_menu.dart';
import 'package:lendify/screens/support_flow_screen.dart';
import 'package:lendify/utils/cancellation_policy_text.dart';
import 'package:lendify/utils/condition_labels.dart';
import 'package:lendify/widgets/wishlist_selection_sheet.dart';
import 'package:lendify/widgets/image_gallery_overlay.dart';
import 'package:lendify/widgets/login_nudge_sheet.dart';
import 'package:lendify/widgets/listing_display_truth.dart';
import 'package:lendify/widgets/rating_badge.dart';
import 'package:lendify/config/private_pilot_config.dart';
import 'package:lendify/services/private_pilot_pricing.dart';
import 'package:lendify/screens/private_pilot_checkout_screen.dart';
import 'package:lendify/widgets/private_pilot_risk_notice.dart';
import 'package:lendify/theme.dart';

class ItemDetailsOverlay {
  static Future<void> show(BuildContext context,
      {required Item item, model.User? owner}) async {
    final userFuture =
        owner != null ? Future.value(owner) : _loadOwner(item.ownerId);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (context) {
        return Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Stack(children: [
              Positioned.fill(
                  child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(color: Colors.transparent))),
              Align(
                alignment: Alignment.bottomCenter,
                child: _ItemDetailsSheet(item: item, ownerFuture: userFuture),
              ),
            ]),
          ),
        );
      },
    );
  }

  // New: direct navigation to the full listing page (bypasses overlay)
  static Future<void> showFullPage(
    BuildContext context, {
    required Item item,
    model.User? owner,
    String? editRequestId,
    bool fresh = false,
    bool isOwnerPreview = false,
    String? overrideAppBarTitle,
  }) async {
    final userFuture =
        owner != null ? Future.value(owner) : _loadOwner(item.ownerId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ItemDetailsPage(
          item: item,
          ownerFuture: userFuture,
          editRequestId: editRequestId,
          fresh: fresh,
          isOwnerPreview: isOwnerPreview,
          overrideAppBarTitle: overrideAppBarTitle,
        ),
      ),
    );
  }

  static Future<model.User?> _loadOwner(String id) async {
    final users = await DataService.getUsers();
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }
}

class LinkedListingDetailsScreen extends StatelessWidget {
  final Item item;

  const LinkedListingDetailsScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) => _ItemDetailsPage(
        item: item,
        ownerFuture: DataService.getUserById(item.ownerId),
      );
}

class _ItemDetailsSheet extends StatefulWidget {
  final Item item;
  final Future<model.User?> ownerFuture;
  const _ItemDetailsSheet({required this.item, required this.ownerFuture});
  @override
  State<_ItemDetailsSheet> createState() => _ItemDetailsSheetState();
}

class _ItemDetailsSheetState extends State<_ItemDetailsSheet> {
  int _page = 0;
  final PageController _pc = PageController();
  DateTimeRange? _selectedRange;
  bool _canReserve = false;
  String? _wishlistId;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _share() async {
    try {
      f.debugPrint('[share] listing ${widget.item.id}');
      await AppPopup.toast(context,
          icon: Icons.check_circle_outline, title: 'Link kopiert');
    } catch (e) {
      f.debugPrint('[share] failed: $e');
      await AppPopup.toast(context,
          icon: Icons.error_outline, title: 'Teilen fehlgeschlagen');
    }
  }

  Future<void> _loadWishlist() async {
    try {
      final id = await DataService.getWishlistForItem(widget.item.id);
      if (mounted) setState(() => _wishlistId = id);
    } catch (e) {
      f.debugPrint('[ItemDetailsSheet] load wishlist failed: $e');
    }
  }

  @override
  void dispose() {
    // Always clear any cached selection when leaving the listing overlay
    // so that the next time a user opens any listing it starts fresh.
    DataService.clearSavedDateRange(widget.item.id);
    DataService.clearSavedDeliverySelection(widget.item.id);
    _pc.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    // Kein Datum vorgewählt, es sei denn der Nutzer hat in dieser Sitzung
    // bereits explizit etwas gewählt.
    final DateTimeRange? initial = _selectedRange;
    // Load booked ranges to mark them in calendar
    await DataService.getUnavailableRangesForItem(widget.item.id);
    // Switch to the new full screen availability UX
    final picked = await Navigator.of(context).push<DateTimeRange>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.25),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Material(
            type: MaterialType.transparency,
            child: Stack(children: [
              Positioned.fill(
                  child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(color: Colors.transparent))),
              SelectRentalDurationScreen(
                  item: widget.item, initialRange: initial),
            ]),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved =
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                  position:
                      Tween(begin: const Offset(0, 0.02), end: Offset.zero)
                          .animate(curved),
                  child: child));
        },
      ),
    );
    if (picked != null) {
      DateTimeRange rangeWithTime = picked;
      // Enforce full-week selection for week-based listings (exactly 7 days)
      if (widget.item.priceUnit == 'week') {
        final start =
            DateTime(picked.start.year, picked.start.month, picked.start.day);
        final end = start.add(const Duration(days: 6));
        rangeWithTime = DateTimeRange(start: start, end: end);
      }
      setState(() => _selectedRange = rangeWithTime);
      await DataService.setSavedDateRange(widget.item.id,
          start: rangeWithTime.start, end: rangeWithTime.end);
    }
  }

  Future<void> _sendRequest() async {
    final range = _selectedRange;
    if (range == null) return;

    final ok = await DataService.checkAvailability(
        itemId: widget.item.id, start: range.start, end: range.end);
    if (!ok) {
      if (!mounted) return;
      await _showUnavailablePopup(context);
      return;
    }
    final current = await DataService.getCurrentUser();
    if (!mounted) return;
    if (current == null) {
      await showGuestRestrictionSheet(context,
          gateContext: GuestGateContext.rentalRequest);
      return;
    }

    if (PrivatePilotConfig.enabled) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PrivatePilotCheckoutScreen(
            item: widget.item,
            range: range,
          ),
        ),
      );
      return;
    }

    final req = RentalRequest(
      id: 'local',
      itemId: widget.item.id,
      ownerId: widget.item.ownerId,
      renterId: current.id,
      start: range.start,
      end: range.end,
      status: 'pending',
      message: null,
      expressRequested: false,
      expressStatus: null,
      expressFee: 5.0,
    );

    RentalRequest stored;
    try {
      stored = await DataService.addRentalRequest(req);
    } catch (e) {
      f.debugPrint('[ItemDetailsOverlay] addRentalRequest failed: $e');
      if (!mounted) return;
      await AppPopup.toast(context,
          icon: Icons.error_outline,
          title: 'Anfrage konnte nicht gesendet werden');
      return;
    }

    // UI flow errors should not be shown as “send failed” if the request was stored.
    try {
      if (!mounted) return;
      final rootNav = Navigator.of(context, rootNavigator: true);
      rootNav.popUntil((route) => route.isFirst);
      if (!rootNav.mounted) return;
      await _showReservationSentPopup(rootNav.context,
          requestId: stored.id, item: widget.item);
    } catch (e) {
      f.debugPrint(
          '[ItemDetailsOverlay] post-send UI flow failed (request stored): $e');
    }
  }

  String _priceWithUnit(Item i) {
    final unit = i.priceUnit;
    final raw = i.priceRaw;
    return '${listingCustomerPriceText(raw, currency: i.currency)} ${unit == 'week' ? '/ Woche' : '/ Tag'}';
  }

  String _formatRangeForButton(Item i, DateTimeRange r) {
    String two(int v) => v.toString().padLeft(2, '0');
    final von = '${two(r.start.day)}.${two(r.start.month)}.${r.start.year}';
    final bis = '${two(r.end.day)}.${two(r.end.month)}.${r.end.year}';
    return 'Von: $von    Bis: $bis';
  }

  String _buildPriceSummary(Item i, DateTimeRange r) {
    final diff = r.end.difference(r.start);
    int days = diff.inDays;
    if (days <= 0) days = 1;
    final quote = PrivatePilotPricing.quoteForItem(item: i, days: days);
    final span = days == 1 ? '1 Tag' : '$days Tage';
    return '${PrivatePilotPricing.formatMinor(quote.totalMinor, currency: quote.currency)} für $span';
  }

  Future<void> _addToWishlist() async {
    if (_wishlistId == null) {
      final sel = await WishlistSelectionSheet.showAdd(context);
      if (sel != null && sel.isNotEmpty) {
        await DataService.setItemWishlist(widget.item.id, sel);
        if (!mounted) return;
        setState(() => _wishlistId = sel);
        await AppPopup.toast(context,
            icon: Icons.favorite, title: 'Unter Gemerkt gespeichert');
      }
      return;
    }
    final choice = await WishlistSelectionSheet.showManageOptions(context);
    if (choice == 'move') {
      final sel = await WishlistSelectionSheet.showMove(context,
          currentListId: _wishlistId!);
      if (sel != null && sel.isNotEmpty) {
        await DataService.setItemWishlist(widget.item.id, sel);
        if (mounted) setState(() => _wishlistId = sel);
      }
    } else if (choice == 'remove') {
      await DataService.removeItemFromWishlist(widget.item.id);
      if (mounted) setState(() => _wishlistId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final l10n = context.watch<LocalizationController>();
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        constraints: BoxConstraints(maxWidth: 720, maxHeight: h * 0.88),
        decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              height: 44,
              child: Stack(children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2)))),
                Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close, color: Colors.white))),
              ])),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(children: [
                          PageView.builder(
                            controller: _pc,
                            onPageChanged: (i) => setState(() => _page = i),
                            itemCount:
                                item.photos.isNotEmpty ? item.photos.length : 1,
                            itemBuilder: (context, index) {
                              final url = item.photos.isNotEmpty
                                  ? item.photos[index]
                                  : '';
                              return AppImage(url: url, fit: BoxFit.cover);
                            },
                          ),
                          // Tap to open immersive gallery overlay
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () async {
                                await ImageGalleryOverlay.show(
                                  context,
                                  images: item.photos,
                                  initialIndex: _page,
                                  isWishlisted: () => _wishlistId != null,
                                  onWishlistPressed: _addToWishlist,
                                  onShare: _share,
                                );
                              },
                            ),
                          ),
                          // Top-right: wishlist heart (nudged ~1.5mm to the right edge)
                          Positioned(
                            top: 10,
                            right: 7,
                            child: InkWell(
                              onTap: _addToWishlist,
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    shape: BoxShape.circle),
                                child: Icon(
                                    _wishlistId == null
                                        ? Icons.favorite_border
                                        : Icons.favorite,
                                    size: 18,
                                    color: _wishlistId == null
                                        ? Colors.black54
                                        : Colors.pinkAccent),
                              ),
                            ),
                          ),
                          // Show a rating only when the owner has real reviews.
                          Positioned(
                            left: 13,
                            bottom: 10,
                            child: _ListingImageRatingBadge(
                              ownerFuture: widget.ownerFuture,
                              item: item,
                            ),
                          ),
                          // Bottom-right: price (nudged ~1.5mm to the right edge)
                          Positioned(
                            right: 7,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(_priceWithUnit(item),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                          if (item.photos.length > 1)
                            Positioned(
                                bottom: 8,
                                left: 0,
                                right: 0,
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (int i = 0;
                                          i < item.photos.length;
                                          i++)
                                        Container(
                                            width: 6,
                                            height: 6,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 3),
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: i == _page
                                                    ? Colors.white
                                                    : Colors.white.withValues(
                                                        alpha: 0.4)))
                                    ])),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Title centered under the image
                    Center(
                        child: Text(item.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : AppTheme.textPrimary(context),
                                fontWeight: FontWeight.w800,
                                fontSize: 18))),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.place,
                            size: 14,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : AppTheme.textSecondary(context)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${item.city}, ${item.country}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white70
                                    : AppTheme.textSecondary(context)),
                          ),
                        )
                      ],
                    ),
                    // Add ~2mm extra spacing before description
                    const SizedBox(height: 18),
                    // Artikelbeschreibung: ohne Card, komplett sichtbar
                    Text('Artikelbeschreibung',
                        style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : AppTheme.textPrimary(context),
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(item.description,
                        style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : AppTheme.textBody(context))),
                    const SizedBox(height: 12),
                    // Show combined info table directly under description; includes owner at bottom
                    _ItemMetaSection(
                        item: item, ownerFuture: widget.ownerFuture),
                    if (_canReserve) ...[
                      const SizedBox(height: 8),
                      // Use the same expandable card design as in Ausstehende Buchung – full width
                      _CancellationPolicyBookingCard(
                          policy: item.cancellationPolicy),
                    ],
                    const SizedBox(height: 8),
                    FutureBuilder<model.User?>(
                      future: widget.ownerFuture,
                      builder: (context, snap) {
                        final owner = snap.data;
                        if (owner == null) return const SizedBox.shrink();
                        return _ListingReviewsPreview(
                            ownerId: owner.id, itemId: widget.item.id);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: _ActionCard(
                              title: l10n.t('Anzeige ansehen'),
                              icon: Icons.visibility_rounded,
                              onTap: () async {
                                Navigator.of(context).maybePop();
                                await Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => _ItemDetailsPage(
                                            item: item,
                                            ownerFuture: widget.ownerFuture)));
                              })),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _ActionCard(
                              title: l10n.t('Unter Gemerkt speichern'),
                              icon: Icons.favorite_border,
                              onTap: _addToWishlist)),
                    ]),
                    const SizedBox(height: 16),
                    _BottomActionBar(
                      item: item,
                      range: _selectedRange,
                      onPickRange: _pickRange,
                      // Remove price composition header as requested
                      priceSummary: null,
                      rangeLabel: _selectedRange == null
                          ? null
                          : _formatRangeForButton(item, _selectedRange!),
                      onReserve: _selectedRange == null
                          ? null
                          : () {
                              final msg = _selectedRange == null
                                  ? ''
                                  : _formatRangeForButton(
                                      item, _selectedRange!);
                              AppPopup.toast(context,
                                  icon: Icons.info_outline,
                                  title: l10n.t('Anfrage senden'),
                                  message: msg);
                            },
                      collapsibleDelivery: false,
                      showDeliverySection: false,
                      onCanReserveChange: (v) {
                        if (_canReserve != v) setState(() => _canReserve = v);
                      },
                    ),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.title, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06)
                : AppTheme.surfacePrimary(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppTheme.glassStroke(context))),
        child: Row(children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppTheme.textPrimary(context),
                      fontWeight: FontWeight.w700)))
        ]),
      ),
    );
  }
}

class _ItemDetailsPage extends StatefulWidget {
  final Item item;
  final Future<model.User?> ownerFuture;
  final String? editRequestId;
  final bool fresh;
  final bool isOwnerPreview;
  final String? overrideAppBarTitle;
  const _ItemDetailsPage({
    required this.item,
    required this.ownerFuture,
    this.editRequestId,
    this.fresh = false,
    this.isOwnerPreview = false,
    this.overrideAppBarTitle,
  });
  @override
  State<_ItemDetailsPage> createState() => _ItemDetailsPageState();
}

class _ItemDetailsPageState extends State<_ItemDetailsPage> {
  int _page = 0;
  final PageController _pc = PageController();
  final ScrollController _sc = ScrollController();
  DateTimeRange? _selectedRange;
  bool _canReserve = false;
  String? _wishlistId;

  Future<void> _toggleWishlistFromMenu() async {
    if (_wishlistId == null) {
      final sel = await WishlistSelectionSheet.showAdd(context);
      if (sel != null && sel.isNotEmpty) {
        await DataService.setItemWishlist(widget.item.id, sel);
        if (!mounted) return;
        setState(() => _wishlistId = sel);
        await AppPopup.toast(context,
            icon: Icons.favorite, title: 'Unter Gemerkt gespeichert');
      }
      return;
    }
    final sel = await WishlistSelectionSheet.showMove(context,
        currentListId: _wishlistId!);
    if (sel != null && sel.isNotEmpty) {
      await DataService.setItemWishlist(widget.item.id, sel);
      if (mounted) setState(() => _wishlistId = sel);
    }
  }

  Future<void> _share() async {
    try {
      f.debugPrint('[share] listing ${widget.item.id}');
      await AppPopup.toast(context,
          icon: Icons.check_circle_outline, title: 'Link kopiert');
    } catch (e) {
      f.debugPrint('[share] failed: $e');
      await AppPopup.toast(context,
          icon: Icons.error_outline, title: 'Teilen fehlgeschlagen');
    }
  }

  Widget _availabilityLabel() {
    final r = _selectedRange;
    String two(int v) => v.toString().padLeft(2, '0');
    if (r == null) return const Text('Verfügbarkeit prüfen');
    final startStr =
        '${two(r.start.day)}.${two(r.start.month)}.${r.start.year}';
    final endStr = '${two(r.end.day)}.${two(r.end.month)}.${r.end.year}';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(startStr),
      const SizedBox(width: 8),
      const Text('–'),
      const SizedBox(width: 8),
      Text(endStr),
    ]);
  }

  @override
  void initState() {
    super.initState();
    // Ensure the page always starts scrolled to the very top on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _sc.jumpTo(0);
      } catch (_) {
        // The scroll controller may not have clients during the first frame.
      }
    });
    () async {
      try {
        final id = await DataService.getWishlistForItem(widget.item.id);
        if (mounted) setState(() => _wishlistId = id);
      } catch (_) {
        debugPrint(
            '[ItemDetails] Wishlist-Zuordnung konnte nicht geladen werden.');
      }
    }();
    if (widget.fresh == true) {
      // Clear any previously saved selection so page opens as if brand new
      // Do not await; fire-and-forget to avoid delaying initial build
      DataService.clearSavedDateRange(widget.item.id);
      DataService.clearSavedDeliverySelection(widget.item.id);
      // Keep _selectedRange as null to show pristine state
    } else {
      _loadSavedRange();
    }
  }

  Future<void> _loadSavedRange() async {
    final saved = await DataService.getSavedDateRange(widget.item.id);
    if (!mounted) return;
    if (saved.$1 != null && saved.$2 != null) {
      setState(() =>
          _selectedRange = DateTimeRange(start: saved.$1!, end: saved.$2!));
    }
  }

  @override
  void dispose() {
    // Clear any saved state so the next open is pristine wherever it comes from
    DataService.clearSavedDateRange(widget.item.id);
    DataService.clearSavedDeliverySelection(widget.item.id);
    _pc.dispose();
    _sc.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    // Do not pre-select a default range. The sheet must open without a
    // selection unless the user already picked something in this session.
    final DateTimeRange? initial = _selectedRange;
    final picked = await Navigator.of(context).push<DateTimeRange>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SelectRentalDurationScreen(
            item: widget.item, initialRange: initial),
      ),
    );
    if (picked != null) {
      DateTimeRange rangeWithTime = picked;
      // Enforce full-week selection for week-based listings
      if (widget.item.priceUnit == 'week') {
        final start =
            DateTime(picked.start.year, picked.start.month, picked.start.day);
        final end = start.add(const Duration(days: 6));
        rangeWithTime = DateTimeRange(start: start, end: end);
      }
      setState(() => _selectedRange = rangeWithTime);
      await DataService.setSavedDateRange(widget.item.id,
          start: rangeWithTime.start, end: rangeWithTime.end);
    }
  }

  Future<void> _sendRequest() async {
    final range = _selectedRange;
    if (range == null) return;

    final ok = await DataService.checkAvailability(
        itemId: widget.item.id, start: range.start, end: range.end);
    if (!ok) {
      if (!mounted) return;
      await _showUnavailablePopup(context);
      return;
    }
    final current = await DataService.getCurrentUser();
    if (!mounted) return;
    if (current == null) {
      await showGuestRestrictionSheet(context,
          gateContext: GuestGateContext.rentalRequest);
      return;
    }

    if (PrivatePilotConfig.enabled) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PrivatePilotCheckoutScreen(
            item: widget.item,
            range: range,
          ),
        ),
      );
      return;
    }

    final req = RentalRequest(
      id: 'local',
      itemId: widget.item.id,
      ownerId: widget.item.ownerId,
      renterId: current.id,
      start: range.start,
      end: range.end,
      status: 'pending',
      message: null,
      expressRequested: false,
      expressStatus: null,
      expressFee: 5.0,
    );

    RentalRequest stored;
    try {
      stored = await DataService.addRentalRequest(req);
    } catch (e) {
      f.debugPrint('[ItemDetailsOverlay] addRentalRequest failed: $e');
      if (!mounted) return;
      await AppPopup.toast(context,
          icon: Icons.error_outline, title: 'Fehler beim Senden');
      return;
    }

    try {
      if (!mounted) return;
      await DataService.clearSavedDateRange(widget.item.id);
      await DataService.clearSavedDeliverySelection(widget.item.id);
      if (!mounted) return;
      final rootNav = Navigator.of(context, rootNavigator: true);
      rootNav.popUntil((route) => route.isFirst);
      if (!rootNav.mounted) return;
      await _showReservationSentPopup(rootNav.context,
          requestId: stored.id, item: widget.item);
    } catch (e) {
      f.debugPrint(
          '[ItemDetailsOverlay] post-send UI flow failed (request stored): $e');
    }
  }

  String _priceWithUnit(Item i) {
    final unit = i.priceUnit;
    final raw = i.priceRaw;
    return '${listingCustomerPriceText(raw, currency: i.currency)} ${unit == 'week' ? '/ Woche' : '/ Tag'}';
  }

  String _formatRangeForButton(Item i, DateTimeRange r) {
    String two(int v) => v.toString().padLeft(2, '0');
    final von = '${two(r.start.day)}.${two(r.start.month)}.${r.start.year}';
    final bis = '${two(r.end.day)}.${two(r.end.month)}.${r.end.year}';
    return 'Von: $von    Bis: $bis';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final l10n = context.watch<LocalizationController>();
    final isEditing =
        (widget.editRequestId != null && widget.editRequestId!.isNotEmpty);
    final isPreview = widget.isOwnerPreview == true;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop()),
        title: Text(
          // Listing pages: leave the title empty unless a special override is provided
          widget.overrideAppBarTitle ??
              (isPreview ? 'Meine Anzeigen (Vorschau)' : ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Center the special page titles (preview and overridden titles like
        // "Für Später gespeichert"). Other titles keep platform defaults.
        centerTitle: widget.overrideAppBarTitle != null || isPreview,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () async {
              final choice =
                  await showSITOverflowMenu<String>(context, options: const [
                SitMenuOption(
                    icon: Icons.ios_share,
                    label: 'Anzeige teilen',
                    value: 'share'),
                SitMenuOption(
                    icon: Icons.favorite_border,
                    label: 'Unter Gemerkt speichern',
                    value: 'wishlist'),
                SitMenuOption(
                    icon: Icons.flag_outlined,
                    label: 'Anzeige melden',
                    value: 'report'),
              ]);
              if (!mounted || choice == null) return;
              switch (choice) {
                case 'share':
                  try {
                    final url = AppLinkBuilder.listing(item.id).toString();
                    await Clipboard.setData(ClipboardData(text: url));
                    await AppPopup.toast(context,
                        icon: Icons.ios_share, title: 'Link kopiert');
                  } catch (e) {
                    f.debugPrint('[share] failed: $e');
                    await AppPopup.toast(context,
                        icon: Icons.error_outline,
                        title: 'Teilen fehlgeschlagen');
                  }
                  break;
                case 'wishlist':
                  await _toggleWishlistFromMenu();
                  break;
                case 'report':
                  final current = await DataService.getCurrentUser();
                  if (current == null || !mounted) break;
                  final flowContext = SupportFlowContext.fromBookingDetail(
                    itemTitle: item.title,
                    itemId: item.id,
                    requestId: 'listing:${item.id}',
                    bookingStatus: 'listing',
                    viewerIsOwner: item.ownerId == current.id,
                    otherUserName: null,
                    itemImageUrl:
                        item.photos.isNotEmpty ? item.photos.first : null,
                  );
                  final result = await Navigator.of(context)
                      .push<SupportFlowResult?>(MaterialPageRoute(
                          builder: (_) =>
                              SupportFlowScreen(context: flowContext)));
                  if (result == null || !mounted) break;
                  final supportThread = await DataService.createSupportThread(
                    userId: current.id,
                    canonicalCaseNumber: result.canonicalCaseNumber,
                  );
                  if (!context.mounted) break;
                  if (supportThread == null) {
                    AppPopup.toast(context,
                        icon: Icons.check_circle_outline,
                        title:
                            'Fall ${result.canonicalCaseNumber} ist eingegangen');
                    break;
                  }
                  final descText = result.userDescription.isNotEmpty
                      ? '\n\nBeschreibung:\n${result.userDescription}'
                      : '';
                  await DataService.addSystemMessageToThread(
                      threadId: supportThread.id,
                      text:
                          "${result.canonicalReceiptMessage}\n\n📋 Support-Anfrage zu Anzeige: ${item.title}\nReferenz: listing:${item.id}\nKategorie: ${result.mainCategoryLabel}\nUnterkategorie: ${result.subCategory}$descText");
                  if (!mounted) break;
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MessageThreadScreen(
                          threadId: supportThread.id,
                          participantName: 'SIT Support',
                          itemTitle: 'Support')));
                  break;
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _sc,
          // Only scrolls when content exceeds viewport; no bounce when not needed
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Photos carousel (square)
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(children: [
                  PageView.builder(
                    controller: _pc,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: item.photos.isNotEmpty ? item.photos.length : 1,
                    itemBuilder: (context, index) {
                      final url =
                          item.photos.isNotEmpty ? item.photos[index] : '';
                      return AppImage(url: url, fit: BoxFit.cover);
                    },
                  ),
                  // Tap to open immersive gallery overlay
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () async {
                        await ImageGalleryOverlay.show(
                          context,
                          images: item.photos,
                          initialIndex: _page,
                          isWishlisted: () => _wishlistId != null,
                          onWishlistPressed: _toggleWishlistFromMenu,
                          onShare: _share,
                        );
                      },
                    ),
                  ),
                  // Top-right: wishlist heart (nudged ~1.5mm to the right edge)
                  Positioned(
                    top: 10,
                    right: 7,
                    child: InkWell(
                      onTap: _toggleWishlistFromMenu,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle),
                        child: Icon(
                            _wishlistId == null
                                ? Icons.favorite_border
                                : Icons.favorite,
                            size: 18,
                            color: _wishlistId == null
                                ? Colors.black54
                                : Colors.pinkAccent),
                      ),
                    ),
                  ),
                  // Show a rating only when the owner has real reviews.
                  Positioned(
                    left: 13,
                    bottom: 10,
                    child: _ListingImageRatingBadge(
                      ownerFuture: widget.ownerFuture,
                      item: item,
                    ),
                  ),
                  // Bottom-right: price (nudged ~1.5mm to the right edge)
                  Positioned(
                    right: 7,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(_priceWithUnit(item),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                  if (item.photos.length > 1)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (int i = 0; i < item.photos.length; i++)
                              Container(
                                  width: 6,
                                  height: 6,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i == _page
                                          ? Colors.white
                                          : Colors.white
                                              .withValues(alpha: 0.4))),
                          ]),
                    ),
                ]),
              ),
            ),

            const SizedBox(height: 12),

            // Title centered under the image
            Center(
                child: Text(item.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : AppTheme.textPrimary(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 18))),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.place,
                    size: 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : AppTheme.textSecondary(context)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${item.city}, ${item.country}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : AppTheme.textSecondary(context)),
                  ),
                ),
              ],
            ),

            // Add ~2mm extra spacing before description
            const SizedBox(height: 18),
            Text('Artikelbeschreibung',
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : AppTheme.textPrimary(context),
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(item.description,
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : AppTheme.textBody(context))),

            const SizedBox(height: 12),
            // Infos zum Listing als Kompakttabelle direkt unter der Beschreibung
            _ItemMetaSection(item: item, ownerFuture: widget.ownerFuture),

            if (_canReserve) ...[
              const SizedBox(height: 8),
              // Full-width variant
              _CancellationPolicyBookingCard(policy: item.cancellationPolicy),
            ],

            // Push the divider (top border of the options block) ~3mm lower
            const SizedBox(height: 12),

            // Booking/action section: show also in owner preview, but intercept reservation
            _BottomActionBar(
              item: item,
              range: _selectedRange,
              onPickRange: _pickRange,
              // Remove price composition header as requested
              priceSummary: null,
              rangeLabel: _selectedRange == null
                  ? null
                  : _formatRangeForButton(item, _selectedRange!),
              onReserve: _selectedRange == null
                  ? null
                  : () {
                      final msg = _selectedRange == null
                          ? ''
                          : _formatRangeForButton(item, _selectedRange!);
                      AppPopup.toast(context,
                          icon: Icons.info_outline,
                          title: l10n.t('Anfrage senden'),
                          message: msg);
                    },
              isEditing: isEditing,
              editRequestId: widget.editRequestId,
              fresh: widget.fresh,
              ownerPreview: isPreview,
              collapsibleDelivery: true,
              showDeliverySection: false,
              showReserveButton: false,
              showDatePickerInline: false,
              onCanReserveChange: (v) {
                if (_canReserve != v) setState(() => _canReserve = v);
              },
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
      // Bottom-anchored availability button only (no reserve button on listing page)
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.calendar_month),
                label: _availabilityLabel(),
              ),
              if (_selectedRange != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: isPreview
                      ? () => _showOwnerPreviewBlockPopup(context)
                      : () => _storeRentalCartIntent(
                            context,
                            item: item,
                            range: _selectedRange!,
                          ),
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: const Text('In den Mietkorb'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _sendRequest,
                  icon: const Icon(Icons.event_available),
                  label: const Text('Anfrage senden'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemMetaSection extends StatelessWidget {
  final Item item;
  final Future<model.User?>? ownerFuture;
  const _ItemMetaSection({required this.item, this.ownerFuture});
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    // Compact table-style list without a separate title. Owner info is appended at the bottom.
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : AppTheme.surfacePrimary(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.12)
                : AppTheme.glassStroke(context)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Preis basierend auf der vom Anbieter gewählten Einheit
        Builder(builder: (context) {
          final unit = item.priceUnit;
          final raw = item.priceRaw;
          return _TableLine(
              label: l10n.t('Preis'),
              value:
                  '${listingCustomerPriceText(raw, currency: item.currency)} ${unit == 'week' ? '/ Woche' : '/ Tag'}');
        }),
        _TableLine(
            label: l10n.t('Kategorie'),
            valueWidget:
                _CategoryNameById(id: item.categoryId, sub: item.subcategory)),
        _TableLine(
            label: l10n.t('Zustand'),
            value: ConditionLabels.label(item.condition)),
        if (item.minDays != null || item.maxDays != null)
          _TableLine(label: l10n.t('Mietdauer'), value: _duration(item)),
        const _TableLine(
          label: 'Buchungsablauf',
          value: 'Geführte Übergabe und Rückgabe',
        ),
        _TableLine(label: l10n.t('Verliehen'), value: '${item.timesLent}×'),
        _TableLine(
            label: l10n.t('Eingestellt am'), value: _date(item.createdAt)),
        _TableLine(
          label: l10n.t('Ort'),
          value: item.approximateLocation
              ? '${item.city}, ${item.country} · ungefähr'
              : '${item.city}, ${item.country}',
        ),
        // Owner profile inline at the bottom (no separate card). If no future was
        // passed in, resolve it here by loading the owner from item.ownerId.
        const SizedBox(height: 6),
        Divider(
            height: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white24
                : const Color(0xFFE2E8F0)),
        const SizedBox(height: 8),
        FutureBuilder<model.User?>(
          future: ownerFuture ?? ItemDetailsOverlay._loadOwner(item.ownerId),
          builder: (context, snap) {
            final u = snap.data;
            return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SitUserAvatar(
                    url: (u?.photoURL != null && (u!.photoURL!.isNotEmpty))
                        ? u.photoURL
                        : null,
                    radius: 18,
                    borderColor: Colors.white.withValues(alpha: 0.12),
                    placeholderIcon: Icons.person_outline,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Expanded(
                              child: Text(u?.displayName ?? l10n.t('Anbieter'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : AppTheme.textPrimary(context),
                                      fontWeight: FontWeight.w700))),
                          Icon(Icons.verified,
                              size: 16,
                              color: (u?.isVerified == true)
                                  ? const Color(0xFF22C55E)
                                  : Colors.grey),
                        ]),
                        const SizedBox(height: 2),
                        _OwnerReviewSummary(user: u),
                        if (u?.city != null) ...[
                          const SizedBox(height: 2),
                          Text(
                              '${u!.city}${u.country != null ? ', ${u.country}' : ''}',
                              style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white70
                                      : AppTheme.textSecondary(context),
                                  fontSize: 12)),
                        ],
                      ])),
                  const SizedBox(width: 12),
                  // thin vertical divider between profile infos and "Zum Profil"
                  Container(
                      height: 44,
                      width: 1,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFFE2E8F0)),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      shape: const StadiumBorder(),
                      side: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.20)
                              : AppTheme.glassStroke(context)),
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : AppTheme.textPrimary(context),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () {
                      final userId = u?.id;
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PublicProfileScreen(userId: userId)));
                    },
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: Text(l10n.t('Zum Profil')),
                  ),
                ]);
          },
        ),
      ]),
    );
  }

  static String _duration(Item i) {
    final min = i.minDays;
    final max = i.maxDays;
    if (min != null && max != null) {
      return '$min–$max ${max == 1 ? 'Tag' : 'Tage'}';
    }
    if (min != null) return 'min. $min ${min == 1 ? 'Tag' : 'Tage'}';
    if (max != null) return 'max. $max ${max == 1 ? 'Tag' : 'Tage'}';
    return '-';
  }

  static String _date(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }
}

class _MetaLine extends StatelessWidget {
  final String label;
  final Widget value;
  const _MetaLine({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Make the title bigger than the info as requested
      Text(label,
          style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : AppTheme.textPrimary(context),
              fontSize: 14)),
      const SizedBox(height: 2),
      value,
    ]);
  }
}

class _TableLine extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  const _TableLine({required this.label, this.value, this.valueWidget})
      : assert(value != null || valueWidget != null);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : AppTheme.textSecondary(context),
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: valueWidget ??
                Text(value!,
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : AppTheme.textBody(context)))),
      ]),
    );
  }
}

// Compact two-line paragraph with a single "no entry" (block) symbol to indicate no delivery.
class _NoDeliveryParagraph extends StatelessWidget {
  const _NoDeliveryParagraph();
  @override
  Widget build(BuildContext context) {
    final Color fg = Colors.white;
    final Color sub = Colors.white70;
    Widget blockOnly(double size) => Icon(
          Icons.block,
          size: size,
          color: Theme.of(context).colorScheme.error,
        );
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            baseline: TextBaseline.alphabetic,
            child: blockOnly(16),
          ),
          const TextSpan(text: ' '),
          TextSpan(
              text: 'Lieferung wird vom Anbieter nicht angeboten.',
              style: TextStyle(color: fg, fontSize: 13)),
          const TextSpan(text: '\n'),
          TextSpan(
              text: 'Bitte organisiere die Abholung und Rückgabe selbst.',
              style: TextStyle(color: sub, fontSize: 12)),
        ],
      ),
    );
  }
}

class _DeliveryMetaChips extends StatelessWidget {
  final Item item;
  const _DeliveryMetaChips({required this.item});
  @override
  Widget build(BuildContext context) {
    final bool d = item.offersDeliveryAtDropoff;
    final bool p = item.offersPickupAtReturn;
    if (!d && !p) {
      return const _NoDeliveryParagraph();
    }
    Widget chip(String text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
      );
    }

    final List<Widget> chips = [];
    if (d) {
      final label = item.maxDeliveryKmAtDropoff != null
          ? 'Lieferung bei Abgabe · bis ${item.maxDeliveryKmAtDropoff!.toStringAsFixed(0)} km'
          : 'Lieferung bei Abgabe';
      chips.add(chip(label));
    }
    if (p) {
      final label = item.maxPickupKmAtReturn != null
          ? 'Abholung bei Rückgabe · bis ${item.maxPickupKmAtReturn!.toStringAsFixed(0)} km'
          : 'Abholung bei Rückgabe';
      chips.add(chip(label));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _CategoryNameById extends StatelessWidget {
  final String id;
  final String sub;
  const _CategoryNameById({required this.id, required this.sub});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      // resolve category name lazily
      future: DataService.getCategories(),
      builder: (context, snap) {
        String name = '—';
        if (snap.hasData) {
          final cat = snap.data!.firstWhere((c) => c.id == id,
              orElse: () => Category(
                  id: id,
                  name: id,
                  slug: id,
                  iconName: 'category',
                  subcategories: const [],
                  createdAt: DateTime.now()));
          // Map to simplified, coarse category for clean display without separators
          name = DataService.coarseCategoryFor(cat.name);
        }
        // Plain text only – no dots, dashes, or extra symbols
        return Text(name,
            style: const TextStyle(color: Colors.white, fontSize: 12));
      },
    );
  }
}

class _CollapsingDescriptionSlot extends StatefulWidget {
  final String text;
  final GlobalKey ownerBoxKey;
  const _CollapsingDescriptionSlot(
      {required this.text, required this.ownerBoxKey});
  @override
  State<_CollapsingDescriptionSlot> createState() =>
      _CollapsingDescriptionSlotState();
}

class _CollapsingDescriptionSlotState
    extends State<_CollapsingDescriptionSlot> {
  double? _threshold;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Initial measurement after first frame
    SchedulerBinding.instance.addPostFrameCallback((_) => _measureOwner());
  }

  @override
  void didUpdateWidget(covariant _CollapsingDescriptionSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerBoxKey != widget.ownerBoxKey) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _measureOwner());
    } else {
      // Re-measure in case owner content changed after async load
      SchedulerBinding.instance.addPostFrameCallback((_) => _measureOwner());
    }
  }

  void _measureOwner() {
    final ctx = widget.ownerBoxKey.currentContext;
    if (ctx == null) return;
    final sz = ctx.size;
    if (sz == null) return;
    final h = sz.height;
    if (_threshold == null || (h - _threshold!).abs() > 0.5) {
      setState(() => _threshold = h);
    }
  }

  @override
  Widget build(BuildContext context) {
    const EdgeInsets inner = EdgeInsets.all(12);
    final Color boxBg = Colors.white.withValues(alpha: 0.06);
    final Color boxBorder = Colors.white.withValues(alpha: 0.12);
    const TextStyle textStyle = TextStyle(color: Colors.white);
    const TextStyle titleStyle =
        TextStyle(color: Colors.white, fontWeight: FontWeight.w700);

    return LayoutBuilder(builder: (context, constraints) {
      final double maxW = (constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width) -
          inner.horizontal;
      // Measure full height of the text
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: maxW);
      final double fullTextHeight = tp.size.height;
      // Measure title height + spacing to keep collapse math consistent
      final titlePainter = TextPainter(
          text: const TextSpan(text: 'Artikelbeschreibung', style: titleStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1)
        ..layout(maxWidth: maxW);
      const double titleSpacing = 6;
      final double headerExtra = titlePainter.size.height + titleSpacing;
      final double fullBoxHeight =
          fullTextHeight + inner.vertical + headerExtra;
      final double? threshold = _threshold; // landlord card height
      final bool shouldCollapse =
          threshold != null && fullBoxHeight > threshold + 0.5;

      final double collapsedTextMaxH = (threshold != null)
          ? (threshold - inner.vertical - headerExtra).clamp(0, threshold)
          : 0;
      final Widget content = Container(
        width: double.infinity,
        decoration: BoxDecoration(
            color: boxBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: boxBorder)),
        padding: inner,
        child: Stack(
          children: [
            // Content column with title and body
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Artikelbeschreibung', style: titleStyle),
                const SizedBox(height: titleSpacing),
                if (shouldCollapse && !_expanded)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: collapsedTextMaxH),
                      child: Text(widget.text, style: textStyle),
                    ),
                  )
                else
                  Text(widget.text, style: textStyle),
              ],
            ),

            if (shouldCollapse && !_expanded)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          boxBg.withValues(alpha: 0.0),
                          boxBg,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

      if (!shouldCollapse) return content;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          content,
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white70),
              label: Text(_expanded ? 'Weniger anzeigen' : 'Mehr anzeigen',
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      );
    });
  }
}

class _OwnerRow extends StatelessWidget {
  final model.User? owner;
  const _OwnerRow({required this.owner});
  @override
  Widget build(BuildContext context) {
    final verified = owner?.isVerified == true;
    return Container(
      decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.06)
              : AppTheme.surfacePrimary(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.12)
                  : AppTheme.glassStroke(context))),
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        SitUserAvatar(
          url: owner?.photoURL,
          radius: 18,
          borderColor: Colors.white.withValues(alpha: 0.12),
          placeholderIcon: Icons.person_outline,
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Builder(builder: (context) {
                final l10n = context.watch<LocalizationController>();
                return Text(owner?.displayName ?? l10n.t('Anbieter'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : AppTheme.textPrimary(context),
                        fontWeight: FontWeight.w700));
              })),
              Icon(Icons.verified,
                  size: 16,
                  color: verified ? const Color(0xFF22C55E) : Colors.grey),
            ]),
            const SizedBox(height: 2),
            _OwnerReviewSummary(user: owner),
          ]),
        ),
      ]),
    );
  }
}

class _ListerDetailsCard extends StatelessWidget {
  final model.User? user;
  final Key? boxKey;
  const _ListerDetailsCard({required this.user, this.boxKey});
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final u = user;
    return Container(
      key: boxKey,
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SitUserAvatar(
            url: u?.photoURL,
            radius: 22,
            borderColor: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(u?.displayName ?? l10n.t('Anbieter'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : AppTheme.textPrimary(context),
                              fontWeight: FontWeight.w700))),
                  Icon(Icons.verified,
                      size: 18,
                      color: (u?.isVerified == true)
                          ? const Color(0xFF22C55E)
                          : Colors.grey)
                ]),
                const SizedBox(height: 2),
                _OwnerReviewSummary(user: u, iconSize: 16),
                if (u?.city != null) ...[
                  const SizedBox(height: 2),
                  Text('${u!.city}${u.country != null ? ', ${u.country}' : ''}',
                      style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : AppTheme.textSecondary(context),
                          fontSize: 12)),
                ],
                if (u != null) ...[
                  const SizedBox(height: 2),
                  Text(
                      '${l10n.t('Dabei seit')}: ${_joinedMonthYear(u.createdAt)}',
                      style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : AppTheme.textSecondary(context),
                          fontSize: 12)),
                ],
              ])),

          // Vertical divider
          Container(
              height: 44,
              width: 1,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFE2E8F0)),
          const SizedBox(width: 12),

          // Small profile button aligned to the right
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: const StadiumBorder(),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 13),
            ),
            onPressed: () {
              final userId = u?.id;
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PublicProfileScreen(userId: userId)));
            },
            icon: const Icon(Icons.person_outline, size: 18),
            label: Text(l10n.t('Zum Profil')),
          ),
        ]),
        if ((u?.bio?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 10),
          Text(u!.bio!, style: const TextStyle(color: Colors.white)),
        ],
      ]),
    );
  }

  static String _joinedMonthYear(DateTime createdAt) {
    const monthsDe = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember'
    ];
    final m = monthsDe[createdAt.month - 1];
    return '$m ${createdAt.year}';
  }
}

class _ListingImageRatingBadge extends StatelessWidget {
  final Future<model.User?> ownerFuture;
  final Item item;

  const _ListingImageRatingBadge({
    required this.ownerFuture,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<model.User?>(
      future: ownerFuture,
      builder: (context, snapshot) {
        final owner = snapshot.data;
        final rating = ownerRatingForDisplay(
          averageRating: owner?.avgRating,
          reviewCount: owner?.reviewCount,
        );
        if (owner == null || rating == null) {
          return const SizedBox.shrink();
        }
        return GestureDetector(
          onTap: () => _showReviews(context, owner),
          child: RatingBadge(
            rating: rating,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        );
      },
    );
  }

  Future<void> _showReviews(BuildContext context, model.User owner) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(children: [
                Icon(Icons.rate_review_outlined, color: Colors.white70),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bewertungen',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              _ListingReviewsPreview(ownerId: owner.id, itemId: item.id),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerReviewSummary extends StatelessWidget {
  final model.User? user;
  final double iconSize;

  const _OwnerReviewSummary({required this.user, this.iconSize = 14});

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final color = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : AppTheme.textSecondary(context);
    final style = TextStyle(color: color, fontSize: 12);
    final u = user;
    if (u == null) return Text(l10n.t('Laden …'), style: style);

    final rating = ownerRatingForDisplay(
      averageRating: u.avgRating,
      reviewCount: u.reviewCount,
    );
    if (rating == null) {
      return Text(l10n.t('Noch keine Bewertungen'), style: style);
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('${u.reviewCount} ${l10n.t('Bewertungen')}', style: style),
      const SizedBox(width: 8),
      Icon(Icons.star, size: iconSize, color: const Color(0xFFFB923C)),
      const SizedBox(width: 4),
      Text(rating.toStringAsFixed(1), style: style),
    ]);
  }
}

class _ListingReviewsPreview extends StatefulWidget {
  final String ownerId;
  final String itemId;
  const _ListingReviewsPreview({required this.ownerId, required this.itemId});
  @override
  State<_ListingReviewsPreview> createState() => _ListingReviewsPreviewState();
}

class _ListingReviewsPreviewState extends State<_ListingReviewsPreview> {
  List<Map<String, dynamic>> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final multi = await DataService.getMultiReviewsForUserByItem(
        widget.ownerId, widget.itemId);
    if (!mounted) return;
    setState(() {
      _entries = [
        for (final r in multi)
          {
            'avg': r.average,
            'createdAt': r.createdAt,
            'text': r.criteria
                .where((c) => (c.note?.trim().isNotEmpty ?? false))
                .map((c) => c.note!.trim())
                .join(' · '),
          }
      ];
      _entries.sort((a, b) =>
          (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_entries.isEmpty) return const SizedBox.shrink();
    final preview = _entries.take(2).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 4),
      const Text('Bewertungen zu dieser Anzeige',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      for (final e in preview)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
          child: Row(children: [
            const Icon(Icons.star, color: Color(0xFFFB923C), size: 16),
            const SizedBox(width: 6),
            Text(((e['avg'] as double?) ?? 0).toStringAsFixed(1),
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : AppTheme.textPrimary(context),
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    (e['text'] as String?)?.trim().isEmpty == true
                        ? '—'
                        : (e['text'] as String),
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : AppTheme.textSecondary(context)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis)),
          ]),
        ),
    ]);
  }
}

class _ShimmerFill extends StatefulWidget {
  const _ShimmerFill();
  @override
  State<_ShimmerFill> createState() => _ShimmerFillState();
}

class _ShimmerFillState extends State<_ShimmerFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
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
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _c.value, -1),
              end: Alignment(0 + 2 * _c.value, 1),
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.18),
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

class _BottomActionBar extends StatefulWidget {
  final Item item;
  final DateTimeRange? range;
  final VoidCallback onPickRange;
  final String? priceSummary;
  final String? rangeLabel;
  final VoidCallback? onReserve;
  final bool isEditing;
  final String? editRequestId;
  final bool fresh;
  final bool ownerPreview;
  // Controls whether delivery/pickup options are shown as an ExpansionTile
  // (collapsible). We will enable this only on the full page view after dates
  // have been chosen. Overlay remains non-collapsible.
  final bool collapsibleDelivery;
  // New: allow completely hiding delivery/abhol section on the final page
  // before reserving, per latest spec.
  final bool showDeliverySection;
  final ValueChanged<bool>? onCanReserveChange;
  // New flags to control inline components visibility
  final bool showReserveButton;
  final bool showDatePickerInline;
  const _BottomActionBar(
      {required this.item,
      required this.range,
      required this.onPickRange,
      required this.priceSummary,
      required this.rangeLabel,
      required this.onReserve,
      this.isEditing = false,
      this.editRequestId,
      this.fresh = false,
      this.ownerPreview = false,
      this.collapsibleDelivery = false,
      this.showDeliverySection = false,
      this.onCanReserveChange,
      this.showReserveButton = true,
      this.showDatePickerInline = true});

  @override
  State<_BottomActionBar> createState() => _BottomActionBarState();
}

enum _DropoffOption { self, landlord }

enum _ReturnOption { self, landlord }

class _BottomActionBarState extends State<_BottomActionBar> {
  // Booking choices (radio-style)

  _DropoffOption _dropoff = _DropoffOption.self; // Abgabe
  _ReturnOption _returning = _ReturnOption.self; // Rückgabe
  String? _addressCity; // legacy support only; not shown in UI anymore
  String _addressLine = '';
  double? _addressLat;
  double? _addressLng;
  bool _wantExpress =
      false; // renter choice for priority (express) delivery option (2h)
  bool? _isAvailable; // null = unknown, true/false = checked
  bool? _lastNotifiedCanReserve;

  @override
  void initState() {
    super.initState();
    _refreshAvailability();
    // A stale pre-pilot transport choice must not affect this booking surface.
    DataService.clearSavedDeliverySelection(widget.item.id);
  }

  @override
  void didUpdateWidget(covariant _BottomActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range?.start != widget.range?.start ||
        oldWidget.range?.end != widget.range?.end ||
        oldWidget.item.id != widget.item.id) {
      _refreshAvailability();
      if (oldWidget.item.id != widget.item.id) {
        DataService.clearSavedDeliverySelection(widget.item.id);
      }
    }
  }

  Future<void> _refreshAvailability() async {
    final r = widget.range;
    if (r == null) {
      if (_isAvailable != null) setState(() => _isAvailable = null);
      return;
    }
    final ok = await DataService.checkAvailability(
        itemId: widget.item.id, start: r.start, end: r.end);
    if (mounted) setState(() => _isAvailable = ok);
  }

  void _persistDeliverySelection() {
    // Persist selection
    DataService.setSavedDeliverySelection(
      widget.item.id,
      hinweg: _dropoff == _DropoffOption.landlord,
      rueckweg: _returning == _ReturnOption.landlord,
      addressCity: _addressCity,
      addressLine: _addressLine,
      express: _wantExpress,
      lat: _addressLat,
      lng: _addressLng,
    );
  }

  double _baseRentalTotal() {
    final range = widget.range;
    if (range == null) return 0.0;
    final perDay = widget.item.pricePerDay;
    int days = range.end.difference(range.start).inDays;
    if (days <= 0) days = 1;
    return days * perDay;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final range = widget.range;
    final canOfferHinweg =
        PrivatePilotConfig.deliveryEnabled && item.offersDeliveryAtDropoff;
    final canOfferRueckweg =
        PrivatePilotConfig.deliveryEnabled && item.offersPickupAtReturn;
    // Rental part with discounts applied (owner-configured thresholds)
    double rentalSubtotal = 0.0;
    if (range != null) {
      int days = range.end.difference(range.start).inDays;
      if (days <= 0) days = 1;
      final tuple =
          DataService.computeTotalWithDiscounts(item: item, days: days);
      rentalSubtotal = tuple.$1; // final after discount
    }
    // Private pilot: local fallback pricing contains rent and platform
    // contribution only. The binding checkout quote remains server-owned.
    final platformFee = range != null
        ? DataService.platformContributionForRental(rentalSubtotal)
        : 0.0;
    final total = range != null
        ? double.parse((rentalSubtotal + platformFee).toStringAsFixed(2))
        : 0.0;

    // compute canReserve to inform parent (for showing cancellation section)
    final canReserveForNotify = range != null && (_isAvailable != false);
    if (widget.onCanReserveChange != null &&
        _lastNotifiedCanReserve != canReserveForNotify) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _lastNotifiedCanReserve = canReserveForNotify;
        widget.onCanReserveChange?.call(canReserveForNotify);
      });
    }

    return Container(
      decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
      // Remove horizontal padding to align the chevron with "Infos zum Listing"
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
      child: SafeArea(
        top: false,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Collapsible variant only on full page and only after dates are selected
                // Hidden entirely when showDeliverySection == false (per latest spec)
                if (range != null &&
                    widget.collapsibleDelivery &&
                    widget.showDeliverySection) ...[
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      listTileTheme: const ListTileThemeData(
                          dense: true,
                          minVerticalPadding: 0,
                          visualDensity: VisualDensity(vertical: -3)),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                      collapsedIconColor: Colors.white70,
                      iconColor: Colors.white70,
                      initiallyExpanded: false,
                      leading: const SizedBox(width: 40),
                      title: const Center(
                          child: Text('Liefer- und Abholoptionen',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15))),
                      children: [
                        // Plain text layout (no card)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 8),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Abgabe (Artikel zu dir):',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                RadioListTile<_DropoffOption>(
                                  value: _DropoffOption.self,
                                  groupValue: _dropoff,
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _dropoff = v;
                                      });
                                      _persistDeliverySelection();
                                    }
                                  },
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: const Text('Selbst abholen',
                                      style: TextStyle(color: Colors.white)),
                                ),
                                if (canOfferHinweg)
                                  RadioListTile<_DropoffOption>(
                                    value: _DropoffOption.landlord,
                                    groupValue: _dropoff,
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          _dropoff = v;
                                        });
                                        _persistDeliverySelection();
                                      }
                                    },
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: const Text(
                                        'Vom Vermieter liefern lassen',
                                        style: TextStyle(color: Colors.white)),
                                  )
                                else
                                  RadioListTile<_DropoffOption>(
                                    value: _DropoffOption.landlord,
                                    groupValue: _dropoff,
                                    onChanged: null,
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: const Text(
                                        'Lieferung durch Vermieter nicht verfügbar',
                                        style:
                                            TextStyle(color: Colors.white54)),
                                    secondary: const Icon(Icons.lock_outline,
                                        color: Colors.white38),
                                  ),
                                if (canOfferHinweg &&
                                    _dropoff == _DropoffOption.landlord &&
                                    widget.item.maxDeliveryKmAtDropoff != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 16.0, bottom: 6),
                                    child: Text(
                                        'Lieferung bis ${widget.item.maxDeliveryKmAtDropoff!.toStringAsFixed(0)} km verfügbar.',
                                        style: TextStyle(
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white70
                                                    : AppTheme.textSecondary(
                                                        context),
                                            fontSize: 12)),
                                  ),
                                const SizedBox(height: 4),
                                const Text('Rückgabe (Artikel zurückgeben):',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                RadioListTile<_ReturnOption>(
                                  value: _ReturnOption.self,
                                  groupValue: _returning,
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _returning = v;
                                      });
                                      _persistDeliverySelection();
                                    }
                                  },
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: const Text('Selbst zurückbringen',
                                      style: TextStyle(color: Colors.white)),
                                ),
                                if (canOfferRueckweg)
                                  RadioListTile<_ReturnOption>(
                                    value: _ReturnOption.landlord,
                                    groupValue: _returning,
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          _returning = v;
                                        });
                                        _persistDeliverySelection();
                                      }
                                    },
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: const Text(
                                        'Vom Vermieter abholen lassen',
                                        style: TextStyle(color: Colors.white)),
                                  )
                                else
                                  RadioListTile<_ReturnOption>(
                                    value: _ReturnOption.landlord,
                                    groupValue: _returning,
                                    onChanged: null,
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: const Text(
                                        'Abholung durch Vermieter nicht verfügbar',
                                        style:
                                            TextStyle(color: Colors.white54)),
                                    secondary: const Icon(Icons.lock_outline,
                                        color: Colors.white38),
                                  ),
                                if (canOfferRueckweg &&
                                    _returning == _ReturnOption.landlord &&
                                    widget.item.maxPickupKmAtReturn != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 16.0, bottom: 6),
                                    child: Text(
                                        'Abholung bis ${widget.item.maxPickupKmAtReturn!.toStringAsFixed(0)} km verfügbar.',
                                        style: TextStyle(
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white70
                                                    : AppTheme.textSecondary(
                                                        context),
                                            fontSize: 12)),
                                  ),
                                const SizedBox(height: 4),
                                if (!canOfferHinweg && !canOfferRueckweg)
                                  const Text(
                                      'Dieser Vermieter bietet für diese Anzeige keine Lieferung oder Abholung an.',
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 12))
                                else if (!widget.item.offersExpressAtDropoff)
                                  const Text(
                                      'Prioritätslieferung ist für dieses Angebot nicht verfügbar.',
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 12)),
                                if ((_dropoff == _DropoffOption.landlord) ||
                                    (_returning == _ReturnOption.landlord)) ...[
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 18, color: Colors.white70),
                                    const SizedBox(width: 6),
                                    const Text('Lieferadresse',
                                        style:
                                            TextStyle(color: Colors.white70)),
                                  ]),
                                  const SizedBox(height: 6),
                                  _AddressAutocomplete(
                                    initialText: _addressLine,
                                    onChanged: (text) {
                                      setState(() {
                                        _addressLine = text;
                                        _addressLat = null;
                                        _addressLng = null;
                                      });
                                      _persistDeliverySelection();
                                    },
                                    onSelected: (full, lat, lng) {
                                      setState(() {
                                        _addressLine = full;
                                        _addressLat = lat;
                                        _addressLng = lng;
                                      });
                                      _persistDeliverySelection();
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Builder(builder: (context) {
                                    double? km;
                                    if (_addressLat != null &&
                                        _addressLng != null) {
                                      km = DataService.estimateDistanceKm(
                                          widget.item.lat,
                                          widget.item.lng,
                                          _addressLat!,
                                          _addressLng!);
                                    } else if (_addressLine.trim().isNotEmpty) {
                                      km = DataService
                                          .estimateDistanceKmFromAddressLine(
                                              widget.item.lat,
                                              widget.item.lng,
                                              _addressLine);
                                    }
                                    if (km == null) {
                                      return const SizedBox.shrink();
                                    }
                                    if (_dropoff == _DropoffOption.landlord &&
                                        widget.item.maxDeliveryKmAtDropoff !=
                                            null &&
                                        km >
                                            widget
                                                .item.maxDeliveryKmAtDropoff!) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                            'Die gewünschte Lieferadresse liegt außerhalb des vom Vermieter angebotenen Lieferbereichs (max. ${widget.item.maxDeliveryKmAtDropoff!.toStringAsFixed(0)} km).',
                                            style: const TextStyle(
                                                color: Color(0xFFF43F5E))),
                                      );
                                    }
                                    if (_returning == _ReturnOption.landlord &&
                                        widget.item.maxPickupKmAtReturn !=
                                            null &&
                                        km > widget.item.maxPickupKmAtReturn!) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                            'Die gewünschte Lieferadresse liegt außerhalb des vom Vermieter angebotenen Abholbereichs (max. ${widget.item.maxPickupKmAtReturn!.toStringAsFixed(0)} km).',
                                            style: const TextStyle(
                                                color: Color(0xFFF43F5E))),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  }),
                                  const SizedBox(height: 4),
                                  Text(
                                      'Kilometerpreis: 0,30 Euro pro km (Hin- + Rückweg)',
                                      style: TextStyle(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white70
                                              : AppTheme.textSecondary(context),
                                          fontSize: 12)),
                                  if (canOfferHinweg &&
                                      widget.item.offersExpressAtDropoff &&
                                      _dropoff == _DropoffOption.landlord) ...[
                                    const SizedBox(height: 10),
                                    CheckboxListTile(
                                      value: _wantExpress,
                                      onChanged: (v) {
                                        setState(() {
                                          _wantExpress = v ?? false;
                                        });
                                        _persistDeliverySelection();
                                      },
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                          'Prioritätslieferung (innerhalb von 2,5 Stunden) gegen 5,00 € Aufpreis',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13)),
                                      subtitle: const Text(
                                          'Die 5,00 € werden nur berechnet, wenn die Anfrage in 30 Minuten bestätigt wird und innerhalb von 2,5 Stunden geliefert wird.',
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11)),
                                    ),
                                  ],
                                  if (_wantExpress) const SizedBox(height: 4),
                                  if (_wantExpress)
                                    Text(
                                        'Priorität (Option): 5,00 € – wird bei Bestätigung automatisch hinzugefügt',
                                        style: TextStyle(
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white70
                                                    : AppTheme.textSecondary(
                                                        context),
                                            fontSize: 12)),
                                ] else ...[
                                  const SizedBox(height: 6),
                                ],
                              ]),
                        ),
                      ],
                    ),
                  ),
                ],
                // Liefer-/Abholoptionen – Standard (nicht aufklappbar)
                // Hidden entirely when showDeliverySection == false
                if (widget.showDeliverySection &&
                    (range == null || !widget.collapsibleDelivery))
                  const Center(
                      child: Text('Liefer- und Abholoptionen',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15))),
                if (widget.showDeliverySection &&
                    (range == null || !widget.collapsibleDelivery))
                  const SizedBox(height: 8),
                if (widget.showDeliverySection && range == null) ...[
                  Builder(builder: (context) {
                    if (!item.offersDeliveryAtDropoff &&
                        !item.offersPickupAtReturn) {
                      return const _NoDeliveryParagraph();
                    }
                    return const Center(
                      child: Text(
                        'Im nächsten Schritt kannst du die Lieferung/Abholung wählen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }),
                ] else if (widget.showDeliverySection &&
                    !widget.collapsibleDelivery) ...[
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Abgabe (Artikel zu dir):',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                        RadioListTile<_DropoffOption>(
                          value: _DropoffOption.self,
                          groupValue: _dropoff,
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _dropoff = v;
                              });
                              _persistDeliverySelection();
                            }
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Selbst abholen',
                              style: TextStyle(color: Colors.white)),
                        ),
                        if (canOfferHinweg)
                          RadioListTile<_DropoffOption>(
                            value: _DropoffOption.landlord,
                            groupValue: _dropoff,
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _dropoff = v;
                                });
                                _persistDeliverySelection();
                              }
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Vom Vermieter liefern lassen',
                                style: TextStyle(color: Colors.white)),
                          )
                        else
                          RadioListTile<_DropoffOption>(
                            value: _DropoffOption.landlord,
                            groupValue: _dropoff,
                            onChanged: null,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text(
                                'Lieferung durch Vermieter nicht verfügbar',
                                style: TextStyle(color: Colors.white54)),
                            secondary: const Icon(Icons.lock_outline,
                                color: Colors.white38),
                          ),
                        if (canOfferHinweg &&
                            _dropoff == _DropoffOption.landlord &&
                            widget.item.maxDeliveryKmAtDropoff != null)
                          Padding(
                            padding:
                                const EdgeInsets.only(left: 16.0, bottom: 6),
                            child: Text(
                                'Lieferung bis ${widget.item.maxDeliveryKmAtDropoff!.toStringAsFixed(0)} km verfügbar.',
                                style: TextStyle(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white70
                                        : AppTheme.textSecondary(context),
                                    fontSize: 12)),
                          ),
                        const SizedBox(height: 4),
                        const Text('Rückgabe (Artikel zurückgeben):',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                        RadioListTile<_ReturnOption>(
                          value: _ReturnOption.self,
                          groupValue: _returning,
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _returning = v;
                              });
                              _persistDeliverySelection();
                            }
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Selbst zurückbringen',
                              style: TextStyle(color: Colors.white)),
                        ),
                        if (canOfferRueckweg)
                          RadioListTile<_ReturnOption>(
                            value: _ReturnOption.landlord,
                            groupValue: _returning,
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _returning = v;
                                });
                                _persistDeliverySelection();
                              }
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Vom Vermieter abholen lassen',
                                style: TextStyle(color: Colors.white)),
                          )
                        else
                          RadioListTile<_ReturnOption>(
                            value: _ReturnOption.landlord,
                            groupValue: _returning,
                            onChanged: null,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text(
                                'Abholung durch Vermieter nicht verfügbar',
                                style: TextStyle(color: Colors.white54)),
                            secondary: const Icon(Icons.lock_outline,
                                color: Colors.white38),
                          ),
                        if (canOfferRueckweg &&
                            _returning == _ReturnOption.landlord &&
                            widget.item.maxPickupKmAtReturn != null)
                          Padding(
                            padding:
                                const EdgeInsets.only(left: 16.0, bottom: 6),
                            child: Text(
                                'Abholung bis ${widget.item.maxPickupKmAtReturn!.toStringAsFixed(0)} km verfügbar.',
                                style: TextStyle(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white70
                                        : AppTheme.textSecondary(context),
                                    fontSize: 12)),
                          ),
                        const SizedBox(height: 4),
                        if (!canOfferHinweg && !canOfferRueckweg)
                          const Text(
                              'Dieser Vermieter bietet für diese Anzeige keine Lieferung oder Abholung an.',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12))
                        else if (!widget.item.offersExpressAtDropoff)
                          const Text(
                              'Prioritätslieferung ist für dieses Angebot nicht verfügbar.',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        if ((_dropoff == _DropoffOption.landlord) ||
                            (_returning == _ReturnOption.landlord)) ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            const Icon(Icons.location_on_outlined,
                                size: 18, color: Colors.white70),
                            const SizedBox(width: 6),
                            const Text('Lieferadresse',
                                style: TextStyle(color: Colors.white70)),
                          ]),
                          const SizedBox(height: 6),
                          _AddressAutocomplete(
                            initialText: _addressLine,
                            onChanged: (text) {
                              setState(() {
                                _addressLine = text;
                                _addressLat = null;
                                _addressLng = null;
                              });
                              _persistDeliverySelection();
                            },
                            onSelected: (full, lat, lng) {
                              setState(() {
                                _addressLine = full;
                                _addressLat = lat;
                                _addressLng = lng;
                              });
                              _persistDeliverySelection();
                            },
                          ),
                          const SizedBox(height: 8),
                          Builder(builder: (context) {
                            double? km;
                            if (_addressLat != null && _addressLng != null) {
                              km = DataService.estimateDistanceKm(
                                  widget.item.lat,
                                  widget.item.lng,
                                  _addressLat!,
                                  _addressLng!);
                            } else if (_addressLine.trim().isNotEmpty) {
                              km =
                                  DataService.estimateDistanceKmFromAddressLine(
                                      widget.item.lat,
                                      widget.item.lng,
                                      _addressLine);
                            }
                            if (km == null) return const SizedBox.shrink();
                            if (_dropoff == _DropoffOption.landlord &&
                                widget.item.maxDeliveryKmAtDropoff != null &&
                                km > widget.item.maxDeliveryKmAtDropoff!) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                    'Die gewünschte Lieferadresse liegt außerhalb des vom Vermieter angebotenen Lieferbereichs (max. ${widget.item.maxDeliveryKmAtDropoff!.toStringAsFixed(0)} km).',
                                    style: const TextStyle(
                                        color: Color(0xFFF43F5E))),
                              );
                            }
                            if (_returning == _ReturnOption.landlord &&
                                widget.item.maxPickupKmAtReturn != null &&
                                km > widget.item.maxPickupKmAtReturn!) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                    'Die gewünschte Lieferadresse liegt außerhalb des vom Vermieter angebotenen Abholbereichs (max. ${widget.item.maxPickupKmAtReturn!.toStringAsFixed(0)} km).',
                                    style: const TextStyle(
                                        color: Color(0xFFF43F5E))),
                              );
                            }
                            return const SizedBox.shrink();
                          }),
                          const SizedBox(height: 4),
                          Text(
                              'Kilometerpreis: 0,30 Euro pro km (Hin- + Rückweg)',
                              style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white70
                                      : AppTheme.textSecondary(context),
                                  fontSize: 12)),
                          if (canOfferHinweg &&
                              widget.item.offersExpressAtDropoff &&
                              _dropoff == _DropoffOption.landlord) ...[
                            const SizedBox(height: 10),
                            // Keine weitere Auf-/Zuklapp-UI – einfache Checkbox als Option
                            CheckboxListTile(
                              value: _wantExpress,
                              onChanged: (v) {
                                setState(() {
                                  _wantExpress = v ?? false;
                                });
                                _persistDeliverySelection();
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                  'Prioritätslieferung (innerhalb von 2,5 Stunden) gegen 5,00 € Aufpreis',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              subtitle: const Text(
                                  'Die 5,00 € werden nur berechnet, wenn die Anfrage in 30 Minuten bestätigt wird und innerhalb von 2,5 Stunden geliefert wird.',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11)),
                            ),
                          ],
                          if (_wantExpress) const SizedBox(height: 4),
                          if (_wantExpress)
                            const Text(
                                'Priorität (Option): 5,00 € – wird bei Bestätigung automatisch hinzugefügt',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                        ] else ...[
                          const SizedBox(height: 6),
                        ],
                      ]),
                ],

                const SizedBox(height: 12),

                if (range != null && PrivatePilotConfig.enabled) ...[
                  const PrivatePilotRiskNotice(),
                  const SizedBox(height: 12),
                ],

                if (range != null) ...[
                  Text(
                    'Zusammenfassung',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppTheme.textPrimary(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Preistitel über dem Datums-Button, wie im Screenshot
                if (widget.priceSummary != null) ...[
                  Text(widget.priceSummary!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                  const SizedBox(height: 10),
                ],

                // Hinweis: Date picker button moved below the price box (directly above Reservieren)

                // Preisübersicht nach den Optionen und Datumsauswahl
                if (range != null) ...[
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.06)
                            : AppTheme.surfacePrimary(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : AppTheme.glassStroke(context))),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Checkout: nur EIN Preis (inkl. Plattformbeitrag)
                          Builder(builder: (context) {
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text('Gesamtbetrag',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors.white
                                                  : AppTheme.textPrimary(
                                                      context),
                                              fontWeight: FontWeight.w700)),
                                      Text('${total.toStringAsFixed(2)} €',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors.white
                                                  : AppTheme.textPrimary(
                                                      context),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Inkl. Plattformgebühr',
                                      style: TextStyle(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white70
                                              : AppTheme.textSecondary(context),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('Inkl. Plattformbeitrag.',
                                      style: TextStyle(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white70
                                              : AppTheme.textSecondary(context),
                                          fontSize: 11)),
                                ]);
                          }),
                          if (_isAvailable == false) ...[
                            const SizedBox(height: 10),
                            Row(children: const [
                              Icon(Icons.block, color: Color(0xFFF43F5E)),
                              SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      'In diesem Zeitraum bereits gebucht',
                                      style: TextStyle(
                                          color: Color(0xFFF43F5E),
                                          fontWeight: FontWeight.w700))),
                            ])
                          ],
                        ]),
                  ),
                  const SizedBox(height: 10),
                ],

                // Date picker button placed directly above Reservieren button (optional)
                if (widget.showDatePickerInline) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: widget.onPickRange,
                    icon: const Icon(Icons.calendar_month),
                    label: _buildAvailabilityLabel(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Stornierungsbedingungen-Info wurde in "Infos zum Listing" verschoben.
                const SizedBox.shrink(),

                // Reservieren button with disabled state + tap guard popup for address (optional)
                if (widget.showReserveButton) ...[
                  if (range != null && !widget.isEditing) ...[
                    OutlinedButton.icon(
                      onPressed: _isAvailable == false
                          ? null
                          : () => _storeRentalCartIntent(
                                context,
                                item: widget.item,
                                range: range,
                                ownerPreview: widget.ownerPreview,
                              ),
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: const Text('In den Mietkorb'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Builder(builder: (context) {
                    context.watch<LocalizationController>();
                    final canReserve = range != null && (_isAvailable != false);
                    final buttonStyle = FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ).copyWith(
                      backgroundColor:
                          WidgetStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(WidgetState.disabled)) {
                          return Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.12)
                              : AppTheme.surfaceSecondary(context);
                        }
                        return Theme.of(context).colorScheme.primary;
                      }),
                      foregroundColor:
                          const WidgetStatePropertyAll<Color>(Colors.white),
                    );
                    final btn = FilledButton.icon(
                      style: buttonStyle,
                      onPressed: canReserve
                          ? () {
                              if (widget.ownerPreview) {
                                _showOwnerPreviewBlockPopup(context);
                                return;
                              }
                              _handleReserve(context);
                            }
                          : null,
                      icon: const Icon(Icons.event_available),
                      label: Text(widget.isEditing
                          ? 'Reservierung aktualisieren'
                          : 'Reservieren'),
                    );
                    return btn;
                  }),
                  if (range != null) ...[
                    const SizedBox(height: 6),
                    Text(
                        '„Reservieren“ oeffnet zuerst die vollstaendige Preis- und Risikouebersicht. Es wird noch keine Anfrage gesendet.',
                        style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white54
                                    : AppTheme.textSecondary(context),
                            fontSize: 11)),
                  ],
                ],
              ]),
            ]),
      ),
    );
  }

  bool _isValidAddressLine(String text) {
    final trimmed = text.trim();
    // Basic: require a space and at least one digit
    return trimmed.contains(' ') &&
        RegExp(r"\d").hasMatch(trimmed) &&
        trimmed.length >= 5;
  }

  Future<void> _handleReserve(BuildContext context) async {
    if (widget.ownerPreview) {
      await _showOwnerPreviewBlockPopup(context);
      return;
    }

    final current = await DataService.getCurrentUser();
    if (!mounted || !context.mounted) return;
    if (current == null) {
      await showGuestRestrictionSheet(context,
          gateContext: GuestGateContext.rentalRequest);
      return;
    }
    if (widget.range == null) {
      widget.onReserve?.call();
      return;
    }

    // Final availability guard
    final availableNow = await DataService.checkAvailability(
        itemId: widget.item.id,
        start: widget.range!.start,
        end: widget.range!.end);
    if (!mounted || !context.mounted) return;
    if (!availableNow) {
      await _showUnavailablePopup(context);
      return;
    }

    if (widget.isEditing && (widget.editRequestId != null)) {
      // Update existing request instead of creating a new one
      await DataService.updateRentalRequestTimes(
        requestId: widget.editRequestId!,
        start: widget.range!.start,
        end: widget.range!.end,
        expressRequested: false,
      );
      if (!mounted || !context.mounted) return;
      await AppPopup.toast(context,
          icon: Icons.check_circle_outline,
          title: 'Reservierung aktualisiert.');
      if (!context.mounted) return;
      Navigator.of(context).maybePop();
      return;
    }

    if (PrivatePilotConfig.enabled) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PrivatePilotCheckoutScreen(
            item: widget.item,
            range: widget.range!,
          ),
        ),
      );
      return;
    }

    final req = RentalRequest(
      id: 'local',
      itemId: widget.item.id,
      ownerId: widget.item.ownerId,
      renterId: current.id,
      start: widget.range!.start,
      end: widget.range!.end,
      status: 'pending',
      message: null,
      expressRequested: false,
      expressStatus: null,
      expressFee: 0.0,
    );
    final stored = await DataService.addRentalRequest(req);

    if (!mounted || !context.mounted) return;
    // Navigate back to Explore: pop to root, then show confirmation on top
    final rootNav = Navigator.of(context, rootNavigator: true);
    rootNav.popUntil((route) => route.isFirst);
    if (!rootNav.mounted) return;
    await _showReservationSentPopup(rootNav.context,
        requestId: stored.id, item: widget.item);
  }
}

Future<void> _storeRentalCartIntent(
  BuildContext context, {
  required Item item,
  required DateTimeRange range,
  bool ownerPreview = false,
}) async {
  if (ownerPreview) {
    await _showOwnerPreviewBlockPopup(context);
    return;
  }
  try {
    final cart = await DataService.addRentalCartItem(item: item, range: range);
    if (!context.mounted) return;
    final saved = cart.items.isNotEmpty;
    await AppPopup.toast(
      context,
      icon: saved ? Icons.shopping_bag_outlined : Icons.error_outline,
      title: saved
          ? 'Im Mietkorb – noch nicht reserviert'
          : 'Mietkorb konnte nicht aktualisiert werden',
      message: saved
          ? 'Preis und Verfügbarkeit werden vor der Anfrage erneut geprüft.'
          : null,
    );
  } catch (error) {
    if (!context.mounted) return;
    await AppPopup.toast(
      context,
      icon: Icons.error_outline,
      title: 'Mietkorb konnte nicht aktualisiert werden',
      message: 'Es wurde keine Reservierung erstellt.',
    );
  }
}

Future<void> _showUnavailablePopup(BuildContext context) async {
  await AppPopup.show(
    context,
    icon: Icons.block,
    title: 'Nicht verfügbar',
    message:
        'Dieses Listing ist im gewählten Zeitraum bereits gebucht. Bitte wähle einen anderen Zeitraum.',
    actions: [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).maybePop(),
          child: const Text('OK'),
        ),
      ),
    ],
  );
}

Future<void> _showReservationSentPopup(BuildContext context,
    {required String requestId, required Item item}) async {
  final owner = await ItemDetailsOverlay._loadOwner(item.ownerId);
  final range = await DataService.getRentalRequestById(requestId);
  if (!context.mounted) return;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  String formatDate(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year}';
  }

  final rangeText = range == null
      ? null
      : '${formatDate(range.start)} – ${formatDate(range.end)}';
  final unit = item.priceUnit;
  final raw = item.priceRaw;
  final customerPriceText =
      '${listingCustomerPriceText(raw, currency: item.currency)} ${unit == 'week' ? '/ Woche' : '/ Tag'}';

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Anfrage geschickt',
    barrierColor: isDark
        ? Colors.black.withValues(alpha: 0.80)
        : Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim, secondaryAnim) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0B111C).withValues(alpha: 0.96)
                        : AppTheme.surfacePrimary(context),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFFD9E2EC)),
                    boxShadow: [
                      BoxShadow(
                          color: isDark
                              ? const Color(0x55000000)
                              : const Color(0x140F172A),
                          blurRadius: 24,
                          offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : BrandColors.primary.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : BrandColors.primary
                                          .withValues(alpha: 0.14)),
                            ),
                            child: Icon(Icons.mark_email_read_outlined,
                                color: isDark
                                    ? Colors.white
                                    : BrandColors.primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Anfrage geschickt',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textPrimary(context),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).maybePop(),
                            icon: Icon(Icons.close,
                                color: isDark
                                    ? Colors.white70
                                    : AppTheme.textSecondary(context)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        owner == null
                            ? 'Warte auf die Antwort des Vermieters.'
                            : 'Warte auf die Antwort von ${owner.displayName}.',
                        style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : AppTheme.textSecondary(context),
                            fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppTheme.surfaceSecondary(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: AppImage(
                                  url: item.photos.isNotEmpty
                                      ? item.photos.first
                                      : '',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : AppTheme.textPrimary(context),
                                        fontWeight: FontWeight.w700),
                                  ),
                                  if (rangeText != null) ...[
                                    const SizedBox(height: 4),
                                    Text(rangeText,
                                        style: TextStyle(
                                            color: isDark
                                                ? Colors.white70
                                                : AppTheme.textSecondary(
                                                    context),
                                            fontSize: 12)),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    customerPriceText,
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : AppTheme.textPrimary(context),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.16)
                                        : const Color(0xFFD1D9E6)),
                                foregroundColor: isDark
                                    ? Colors.white
                                    : AppTheme.textPrimary(context),
                                backgroundColor: isDark
                                    ? Colors.transparent
                                    : AppTheme.surfacePrimary(context),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                              onPressed: () => Navigator.of(ctx).maybePop(),
                              child: const Text('Weiter stöbern'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                              onPressed: () async {
                                final nav =
                                    Navigator.of(ctx, rootNavigator: true);
                                nav.pop();
                                if (!nav.mounted) return;
                                await nav.push(
                                  MaterialPageRoute(
                                      builder: (_) => BookingsScreen(
                                          initialTabIndex: 2,
                                          highlightRequestId: requestId)),
                                );
                              },
                              icon: const Icon(Icons.receipt_long),
                              label: const Text(
                                'Anfrage ansehen',
                                softWrap: false,
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, secondary, child) {
      final t = Curves.easeOutCubic.transform(anim.value);
      return Opacity(
        opacity: anim.value,
        child: Transform.scale(
          scale: 0.96 + (0.04 * t),
          child: child,
        ),
      );
    },
  );
}

Future<void> _showAddressGuardPopup(BuildContext context, bool empty) async {
  await AppPopup.show(
    context,
    icon: Icons.error_outline,
    title: 'Adresse benötigt',
    message: empty
        ? 'Bitte Adresse angeben.'
        : 'Bitte eine gültige Adresse auswählen oder korrigieren (Google Maps Vorschlag wählen).',
    actions: [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).maybePop(),
          child: const Text('OK'),
        ),
      ),
    ],
  );
}

Future<void> _showOwnerPreviewBlockPopup(BuildContext context) async {
  await AppPopup.show(
    context,
    icon: Icons.info_outline,
    title: 'Vorschau',
    message:
        'Sie können ihre eigener Anzeige nicht reservieren, dies dient nur zum Vorschau',
    actions: [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).maybePop(),
          child: const Text('OK'),
        ),
      ),
    ],
  );
}

class _LineRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _LineRow({required this.label, required this.value, this.bold = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Colors.white70,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
        Text(value,
            style: TextStyle(
                color: Colors.white,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      ]),
    );
  }
}

class _CancellationPolicySection extends StatelessWidget {
  final String policy; // 'flexible' | 'moderate' | 'strict'
  const _CancellationPolicySection({required this.policy});
  String _header() => CancellationPolicyText.header;

  String _body() => CancellationPolicyText.body();
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 0),
        collapsedIconColor: Colors.white70,
        iconColor: Colors.white70,
        initiallyExpanded: false,
        title: Text(_header(),
            style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppTheme.textPrimary(context),
                fontWeight: FontWeight.w700)),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(_body(), style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

// Match the expandable card design used in booking_detail_screen.dart (_CancellationPolicyCard)
class _CancellationPolicyBookingCard extends StatefulWidget {
  final String
      policy; // kept for compatibility, no longer used (unified policy)
  const _CancellationPolicyBookingCard({required this.policy});
  @override
  State<_CancellationPolicyBookingCard> createState() =>
      _CancellationPolicyBookingCardState();
}

class _CancellationPolicyBookingCardState
    extends State<_CancellationPolicyBookingCard> {
  bool _open = false;

  String _header() => CancellationPolicyText.header;

  String _body() => CancellationPolicyText.body();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Full-width within page padding
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.20)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.policy_outlined,
                        color: isDark
                            ? Colors.white70
                            : AppTheme.textSecondary(context)),
                    const SizedBox(width: 8),
                    Text(
                      _header(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : AppTheme.textPrimary(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            crossFadeState:
                _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(_body(),
                  style: TextStyle(
                      color: isDark
                          ? Colors.white70
                          : AppTheme.textSecondary(context),
                      height: 1.3)),
            ),
            secondChild: const SizedBox(height: 0),
          ),
        ],
      ),
    );
  }
}

class _CitySelector extends StatefulWidget {
  final String? initialCity;
  final ValueChanged<String> onChanged;
  const _CitySelector({required this.initialCity, required this.onChanged});
  @override
  State<_CitySelector> createState() => _CitySelectorState();
}

class _AddressAutocomplete extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onChanged;
  final void Function(String full, double? lat, double? lng)? onSelected;
  const _AddressAutocomplete(
      {required this.initialText, required this.onChanged, this.onSelected});
  @override
  State<_AddressAutocomplete> createState() => _AddressAutocompleteState();
}

class _AddressAutocompleteState extends State<_AddressAutocomplete> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initialText);
  late final FocusNode _focus = FocusNode();
  List<_AddrView> _options = const [];
  DateTime _lastReqAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _c.removeListener(_onTextChanged);
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() async {
    widget.onChanged(_c.text);
    final now = DateTime.now();
    if (now.difference(_lastReqAt).inMilliseconds < 250) return; // debounce
    _lastReqAt = now;
    final q = _c.text.trim();
    if (q.isEmpty) {
      if (_options.isNotEmpty) setState(() => _options = const []);
      return;
    }
    List<MapsAddressSuggestion> sugg;
    try {
      sugg = await MapsService.autocomplete(q);
    } catch (_) {
      sugg = const [];
    }
    if (!mounted) return;
    setState(() => _options = [
          for (final s in sugg)
            _AddrView(label: s.description, placeId: s.placeId)
        ]);
  }

  Future<void> _handleSelect(_AddrView v) async {
    String full = v.label;
    double? lat;
    double? lng;
    if (v.placeId != null) {
      final det = await MapsService.placeDetails(v.placeId!);
      if (det != null) {
        full = det.formattedAddress;
        lat = det.lat;
        lng = det.lng;
      }
    }
    if (!mounted) return;
    setState(() {
      _c.text = full;
      _options = const [];
    });
    _focus.unfocus();
    widget.onChanged(full);
    widget.onSelected?.call(full, lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _c,
          focusNode: _focus,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Straße, Hausnummer, PLZ, Ort',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: border,
            focusedBorder: border.copyWith(
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.30))),
          ),
        ),
        if (_options.isNotEmpty)
          Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: const Color(0xFF0B1220),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side:
                      BorderSide(color: Colors.white.withValues(alpha: 0.12))),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 720, maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemBuilder: (c, i) {
                    final opt = _options[i];
                    return ListTile(
                      dense: true,
                      title: Text(opt.label,
                          style: const TextStyle(color: Colors.white)),
                      onTap: () => _handleSelect(opt),
                    );
                  },
                  separatorBuilder: (_, __) => Divider(
                      height: 1, color: Colors.white.withValues(alpha: 0.06)),
                  itemCount: _options.length,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddrView {
  final String label;
  final String? placeId;
  const _AddrView({required this.label, this.placeId});
}

class _CitySelectorState extends State<_CitySelector> {
  late String _city = widget.initialCity ?? DataService.getCities().keys.first;
  @override
  Widget build(BuildContext context) {
    final cities = DataService.getCities().keys.toList();
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButton<String>(
        value: cities.contains(_city)
            ? _city
            : (cities.isNotEmpty ? cities.first : null),
        onChanged: (v) {
          if (v != null) {
            setState(() {
              _city = v;
            });
            widget.onChanged(v);
          }
        },
        dropdownColor: const Color(0xFF0B1220),
        icon: const Icon(Icons.expand_more, color: Colors.white70),
        underline: const SizedBox.shrink(),
        style: const TextStyle(color: Colors.white),
        items: [
          for (final c in cities)
            DropdownMenuItem(
                value: c,
                child: Text(c, style: const TextStyle(color: Colors.white)))
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const _GlassButton(
      {required this.label, required this.icon, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16))),
          child: TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white),
            label: Text(label, style: const TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              foregroundColor: Colors.white,
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpressCountdownSheet extends StatefulWidget {
  final String requestId;
  const _ExpressCountdownSheet({required this.requestId});
  @override
  State<_ExpressCountdownSheet> createState() => _ExpressCountdownSheetState();
}

class _ExpressCountdownSheetState extends State<_ExpressCountdownSheet> {
  late Duration _remaining = const Duration(minutes: 30);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) async {
    final total = const Duration(minutes: 30);
    final left = total - elapsed;
    if (!mounted) return;
    setState(() => _remaining = left.isNegative ? Duration.zero : left);
    // Poll status every ~2s
    if (elapsed.inMilliseconds % 2000 < 16) {
      final r = await DataService.getRentalRequestById(widget.requestId);
      if (!mounted) return;
      if (r?.expressStatus == 'accepted') {
        if (!mounted) return;
        await AppPopup.toast(context,
            icon: Icons.flash_on_outlined,
            title: 'Prioritätslieferung bestätigt (+5,00 €).');
        Navigator.of(context).maybePop();
      } else if (r?.expressStatus == 'declined') {
        _showFallbackChoice();
      }
    }
    if (_remaining == Duration.zero) {
      _showFallbackChoice();
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s Min';
  }

  Future<void> _showFallbackChoice() async {
    if (!mounted) return;
    _ticker.stop();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.60),
      builder: (_) => const _ExpressFallbackSheet(),
    );
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Colors.black.withValues(alpha: 0.34);
    final border = Colors.white.withValues(alpha: 0.10);
    return SafeArea(
      top: false,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: border)),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: const [
                  Icon(Icons.flash_on_outlined, color: Colors.white70),
                  SizedBox(width: 8),
                  Text('Warte auf Prioritätsbestätigung …',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800))
                ]),
                const SizedBox(height: 4),
                Text(_fmt(_remaining),
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                const Text(
                    'Prioritätslieferung innerhalb von 2,5 Stunden – Zuschlag 5,00 €, nur bei Bestätigung.',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.info_outline,
                      color: Colors.white54, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(
                          'Alle Preisangaben gelten nur für diese Anzeige und basieren auf den Bedingungen des Anbieters.',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11))),
                ])
              ]),
        ),
      ),
    );
  }
}

class _ExpressFallbackSheet extends StatefulWidget {
  const _ExpressFallbackSheet();
  @override
  State<_ExpressFallbackSheet> createState() => _ExpressFallbackSheetState();
}

class _ExpressFallbackSheetState extends State<_ExpressFallbackSheet> {
  bool _rebook = true; // or cancel
  _DropoffOption _drop = _DropoffOption.self;
  _ReturnOption _ret = _ReturnOption.self;

  @override
  Widget build(BuildContext context) {
    final bg = Colors.black.withValues(alpha: 0.34);
    final border = Colors.white.withValues(alpha: 0.10);
    return SafeArea(
      top: false,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: border)),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prioritätslieferung konnte nicht bestätigt werden.',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                    'Du kannst deine Anfrage jetzt anpassen oder stornieren:',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                RadioListTile<bool>(
                  value: true,
                  groupValue: _rebook,
                  onChanged: (v) {
                    setState(() => _rebook = v ?? true);
                  },
                  title: const Text('Buchung neu anfragen mit:',
                      style: TextStyle(color: Colors.white)),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_rebook) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 16.0, bottom: 4),
                    child: Text('Abgabe:',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(children: [
                      RadioListTile<_DropoffOption>(
                          value: _DropoffOption.self,
                          groupValue: _drop,
                          onChanged: (v) =>
                              setState(() => _drop = v ?? _DropoffOption.self),
                          title: const Text('Selbst abholen',
                              style: TextStyle(color: Colors.white)),
                          contentPadding: EdgeInsets.zero,
                          dense: true),
                      RadioListTile<_DropoffOption>(
                          value: _DropoffOption.landlord,
                          groupValue: _drop,
                          onChanged: (v) =>
                              setState(() => _drop = v ?? _DropoffOption.self),
                          title: const Text('Vom Vermieter liefern lassen',
                              style: TextStyle(color: Colors.white)),
                          contentPadding: EdgeInsets.zero,
                          dense: true),
                    ]),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 16.0, top: 6, bottom: 4),
                    child: Text('Rückgabe:',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(children: [
                      RadioListTile<_ReturnOption>(
                          value: _ReturnOption.self,
                          groupValue: _ret,
                          onChanged: (v) =>
                              setState(() => _ret = v ?? _ReturnOption.self),
                          title: const Text('Selbst zurückbringen',
                              style: TextStyle(color: Colors.white)),
                          contentPadding: EdgeInsets.zero,
                          dense: true),
                      RadioListTile<_ReturnOption>(
                          value: _ReturnOption.landlord,
                          groupValue: _ret,
                          onChanged: (v) =>
                              setState(() => _ret = v ?? _ReturnOption.self),
                          title: const Text('Vom Vermieter abholen lassen',
                              style: TextStyle(color: Colors.white)),
                          contentPadding: EdgeInsets.zero,
                          dense: true),
                    ]),
                  ),
                ],
                RadioListTile<bool>(
                  value: false,
                  groupValue: _rebook,
                  onChanged: (v) {
                    setState(() => _rebook = v ?? false);
                  },
                  title: const Text('Anfrage stornieren',
                      style: TextStyle(color: Colors.white)),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Abbrechen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        if (_rebook) {
                          // Persist new local preference without express
                          // Note: In this demo we do not update the existing request payload beyond express flags
                          await AppPopup.toast(context,
                              icon: Icons.edit_outlined,
                              title: 'Anfrage aktualisiert (ohne Priorität).');
                        } else {
                          // Mark as declined locally (demo)
                          // We don't have the request id here; renter can manage from requests list in a full app
                          await AppPopup.toast(context,
                              icon: Icons.cancel_outlined,
                              title: 'Anfrage storniert.');
                        }
                        if (mounted) Navigator.of(context).maybePop();
                      },
                      child: const Text('Bestätigen'),
                    ),
                  ),
                ])
              ]),
        ),
      ),
    );
  }
}

extension on _BottomActionBarState {
  Widget _buildAvailabilityLabel() {
    final r = widget.range;
    String two(int v) => v.toString().padLeft(2, '0');
    if (r == null) return const Text('Verfügbarkeit prüfen');
    final startStr =
        '${two(r.start.day)}.${two(r.start.month)}.${r.start.year}';
    final endStr = '${two(r.end.day)}.${two(r.end.month)}.${r.end.year}';
    // Build date row with fixed spacing (~2mm ≈ 8px) around dash
    Widget baseRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(startStr),
        const SizedBox(width: 8),
        const Text('–'),
        const SizedBox(width: 8),
        Text(endStr),
      ],
    );
    return baseRow;
  }
}

class _TwoLineCenteredButtonContent extends StatelessWidget {
  final IconData leadingIcon;
  final String top;
  final String bottom;
  final bool filled;
  const _TwoLineCenteredButtonContent({
    required this.leadingIcon,
    required this.top,
    required this.bottom,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor =
        filled ? Colors.white : Theme.of(context).colorScheme.primary;
    final Color iconColor =
        filled ? Colors.white : Theme.of(context).colorScheme.primary;
    // Subtle badge background: faint white on filled, faint primary on outlined
    final Color badgeBg = filled
        ? Colors.white.withValues(alpha: 0.18)
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
    return Stack(
      alignment: Alignment.center,
      children: [
        // Centered two-line label built as two Text widgets to avoid mid-word wrap
        // on the first line ("Reservierung"). The first line scales down slightly
        // instead of breaking, so the second line stays visible.
        Padding(
          // a bit tighter than before to give the first line more room
          padding: const EdgeInsets.symmetric(horizontal: 22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Prevent intraword wrapping of the first line by scaling down if needed
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  top,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 1.5),
              Text(
                bottom,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        // Leading icon inside a circular badge at the far left that does not affect text centering
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            // keep the badge ~1mm from the rounded border of the button
            // 1mm ≈ 6 logical px (approx across densities)
            padding: const EdgeInsets.only(left: 6.0),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: badgeBg,
                shape: BoxShape.circle,
              ),
              child: Icon(leadingIcon, color: iconColor, size: 16.5),
            ),
          ),
        ),
      ],
    );
  }
}
