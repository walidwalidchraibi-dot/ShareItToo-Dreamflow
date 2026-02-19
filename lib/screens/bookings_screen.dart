import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lendify/screens/booking_detail_screen.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/user.dart' as model;
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/review_prompt_sheet.dart';
import 'package:lendify/widgets/item_details_overlay.dart';

class BookingsScreen extends StatefulWidget {
  final int? initialTabIndex; // Neue Reihenfolge: 0: Laufend, 1: Kommend, 2: Ausstehend, 3: Abgeschlossen
  // When provided, the card with this requestId will pulse briefly to
  // indicate it was just created.
  final String? highlightRequestId;
  const BookingsScreen({super.key, this.initialTabIndex, this.highlightRequestId});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allBookings = const [];
  Timer? _ticker;
  // Used to disable highlight after navigation/first render
  String? _highlightRequestId;
  String? _currentUserId;
  // Track unread counts per category
  final Map<String, int> _unreadCounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex ?? 0);
    _highlightRequestId = widget.highlightRequestId;
    _load();
    // Periodically refresh to update countdowns and move cards between tabs
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!mounted) return;
      await _maybeShowReviewReminder();
      setState(() {});
    });
    // Also check once shortly after open
    Future.delayed(const Duration(seconds: 2), () => _maybeShowReviewReminder());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  bool _showingReminder = false;
  Future<void> _maybeShowReviewReminder() async {
    if (_showingReminder) return;
    final current = await DataService.getCurrentUser();
    if (current == null) return;
    final reminder = await DataService.takeDueReviewReminder(reviewerId: current.id);
    if (!mounted || reminder == null) return;
    _showingReminder = true;
    try {
      final String requestId = (reminder['requestId'] ?? '').toString();
      final String itemId = (reminder['itemId'] ?? '').toString();
      final String reviewedUserId = (reminder['reviewedUserId'] ?? '').toString();
      final String direction = (reminder['direction'] ?? 'renter_to_owner').toString();
      await AppPopup.show(
        context,
        icon: Icons.star_rate_outlined,
        title: 'Zeit für eine Bewertung',
        message: 'Magst du deine letzte Buchung bewerten?',
        barrierDismissible: true,
        plainCloseIcon: true,
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context, rootNavigator: true).maybePop();
              await DataService.postponeReviewReminder(reminder: reminder, by: const Duration(minutes: 10));
              _showingReminder = false;
            },
            child: const Text('Später erinnern'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context, rootNavigator: true).maybePop();
              final ok = await ReviewPromptSheet.show(
                context,
                requestId: requestId,
                itemId: itemId,
                reviewerId: current.id,
                reviewedUserId: reviewedUserId,
                direction: direction,
              );
              if (ok == true && mounted) {
                await AppPopup.toast(context, icon: Icons.star_rate_outlined, title: 'Danke für deine Bewertung!');
                final item = await DataService.getItemById(itemId);
                if (item != null && mounted) {
                  await ItemDetailsOverlay.showFullPage(context, item: item);
                }
              }
              _showingReminder = false;
            },
            child: const Text('Jetzt bewerten'),
          ),
        ],
      );
    } catch (_) {
      _showingReminder = false;
    }
  }

  Future<void> _load() async {
    final user = await DataService.getCurrentUser();
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _allBookings = const [];
        _currentUserId = null;
      });
      return;
    }
    _currentUserId = user.id;
    final requests = await DataService.getRentalRequestsForRenter(user.id);
    // Load items and listers referenced by requests
    final Map<String, Item?> itemById = {};
    final Map<String, model.User?> userById = {};
    final Map<String, Map<String, dynamic>?> deliveryByItemId = {};
    for (final r in requests) {
      itemById[r.itemId] = itemById[r.itemId] ?? await DataService.getItemById(r.itemId);
    }
    for (final it in itemById.values) {
      if (it != null) {
        userById[it.ownerId] = userById[it.ownerId] ?? await DataService.getUserById(it.ownerId);
        deliveryByItemId[it.id] = await DataService.getSavedDeliverySelection(it.id);
      }
    }
    List<Map<String, dynamic>> maps = [];
    for (final r in requests) {
      final it = itemById[r.itemId];
      if (it == null) continue; // skip dangling
      final owner = userById[it.ownerId];
      maps.add(_toBookingMap(r, it, owner, deliveryByItemId[it.id]));
    }
    
    // Calculate unread counts for each category
    final categorized = {
      'ongoing': <RentalRequest>[],
      'upcoming': <RentalRequest>[],
      'pending': <RentalRequest>[],
      'completed': <RentalRequest>[],
    };
    for (final r in requests) {
      final it = itemById[r.itemId];
      if (it == null) continue;
      final bookingMap = _toBookingMap(r, it, userById[it.ownerId], deliveryByItemId[it.id]);
      final (start, end) = _parseDateRange(bookingMap['dates'] ?? '');
      final cat = _effectiveCategoryFor(bookingMap, start, end);
      categorized[cat]?.add(r);
    }
    
    for (final cat in categorized.keys) {
      final unreadCount = await DataService.getUnreadCountForCategory(
        userId: user.id,
        category: cat,
        requests: categorized[cat]!,
      );
      _unreadCounts[cat] = unreadCount;
    }
    
    if (!mounted) return;
    setState(() => _allBookings = maps);
  }

  Map<String, dynamic> _toBookingMap(RentalRequest r, Item it, model.User? owner, Map<String, dynamic>? deliverySel) {
    String fmt(DateTime d) {
      const months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
      final mm = months[d.month - 1];
      final dd = d.day.toString().padLeft(2, '0');
      return '$dd. $mm';
    }
    // Unified breakdown including delivery/pickup/express
    final breakdown = DataService.priceBreakdownForRequest(item: it, req: r, deliverySel: deliverySel);
    final priced = (breakdown.rentalSubtotal, breakdown.baseTotal, 0.0, breakdown.discountAmount);
    final int days = breakdown.days;
    final double total = (r.quotedTotalRenter ?? breakdown.totalRenter);
    // Address privacy: hide exact house number until 6h before pickup
    final now = DateTime.now();
    final hideHouseNumber = now.isBefore(r.start.subtract(const Duration(hours: 6)));
    final displayLocation = hideHouseNumber ? _approximateAddress(it.locationText, seed: r.id) : it.locationText;

    // Delivery selection flags (persisted on request; fall back to transient selection if missing)
    // Be robust: if legacy requests are missing the snapshot flags, infer from
    // - transient selection
    // - express (only available when delivery at dropoff is chosen)
    // - presence of a delivery address snapshot
    final bool inferredOwnerDeliversByTransient = (deliverySel?['hinweg'] == true);
    final bool inferredOwnerDeliversByExpress = r.expressRequested || (r.expressStatus != null);
    final bool inferredOwnerDeliversByAddress = ((r.deliveryAddressLine ?? '').toString().trim().isNotEmpty) || ((r.deliveryCity ?? '').toString().trim().isNotEmpty);
    final bool ownerDeliversAtDropoff = r.ownerDeliversAtDropoffChosen || inferredOwnerDeliversByTransient || inferredOwnerDeliversByExpress || inferredOwnerDeliversByAddress;

    final bool inferredOwnerPicksUpByTransient = (deliverySel?['rueckweg'] == true);
    final bool ownerPicksUpAtReturn = r.ownerPicksUpAtReturnChosen || inferredOwnerPicksUpByTransient;

    return {
      'requestId': r.id,
      'itemId': it.id,
      'rawStatus': r.status,
      'cancelledBy': r.cancelledBy,
      'title': it.title,
      'dates': '${fmt(r.start)} – ${fmt(r.end)}',
      'location': displayLocation,
      'status': _statusLabel(r),
      'image': (it.photos.isNotEmpty ? it.photos.first : null),
      'images': it.photos,
      'listerId': it.ownerId,
      'listerName': owner?.displayName ?? 'Vermieter',
      'listerAvatar': owner?.photoURL,
      'category': r.status == 'pending' ? 'pending' : null, // let UI compute otherwise
      'pricePaid': '${total.round()} €',
      // Persisted renter-facing constants for stable display across all states
      if (r.quotedTotalRenter != null) 'quotedTotalRenter': r.quotedTotalRenter,
      if (r.quotedSubtitle != null) 'quotedSubtitle': r.quotedSubtitle,
      if (breakdown.discountAmount > 0) 'discounts': '-${breakdown.discountAmount.toStringAsFixed(0)} €',
      // add context so detail view can show breakdown precisely
      'days': days,
      'basePerDay': it.pricePerDay,
      // keep percent only when available from item discount tiers; use computeTotalWithDiscounts again
      if (DataService.computeTotalWithDiscounts(item: it, days: days).$3 > 0)
        'discountPercentApplied': DataService.computeTotalWithDiscounts(item: it, days: days).$3,
      // express fields for countdown in UI
      'expressRequested': r.expressRequested,
      'expressStatus': r.expressStatus,
      'expressRequestedAt': r.expressRequestedAt?.toIso8601String(),
      'startIso': r.start.toIso8601String(),
      'endIso': r.end.toIso8601String(),
      'policy': it.cancellationPolicy,
      'requestCreatedAtIso': r.createdAt.toIso8601String(),
      // Email copy (for potential backend integration)
      'mailSummary': 'Anzahl Tage: $days\nUrsprünglicher Preis: ${priced.$2.round()} €\nRabatt: ${priced.$3.toStringAsFixed(0)}% (−${priced.$4.toStringAsFixed(0)} €)\nEndpreis: ${total.round()} €',
      // delivery/pickup capabilities for privacy hints
      'offersDeliveryAtDropoff': it.offersDeliveryAtDropoff,
      'offersPickupAtReturn': it.offersPickupAtReturn,
      // chosen responsibilities (persisted per item for demo)
      'ownerDeliversAtDropoffChosen': ownerDeliversAtDropoff,
      'ownerPicksUpAtReturnChosen': ownerPicksUpAtReturn,
      'deliveryAddressLine': r.deliveryAddressLine ?? (deliverySel?['addressLine'] as String?) ?? '',
      'deliveryCity': r.deliveryCity ?? (deliverySel?['city'] as String?) ?? '',
      'deliveryLat': r.deliveryLat ?? (deliverySel?['lat'] as num?)?.toDouble(),
      'deliveryLng': r.deliveryLng ?? (deliverySel?['lng'] as num?)?.toDouble(),
    };
  }

  // Builds a fake house number range like "Musterstraße 30–45" when a number exists; otherwise returns original.
  String _approximateAddress(String raw, {required String seed}) {
    final reg = RegExp(r"^(.*?)(\s+)(\d{1,4})([\s,].*|)");
    final m = reg.firstMatch(raw.trim());
    if (m == null) return raw; // no obvious house number
    final street = m.group(1)!.trim();
    final numStr = m.group(3)!;
    final rest = (m.group(4) ?? '').trim();
    final base = int.tryParse(numStr) ?? 0;
    // Deterministic pseudo-random +/- offset up to 15 based on seed
    int hash = 0;
    for (int i = 0; i < seed.length; i++) { hash = 0x1fffffff & (hash + seed.codeUnitAt(i)); }
    final off = (hash % 31) - 15; // -15..15
    final low = (base + (off < 0 ? off : 0)).clamp(1, 9999);
    final high = (base + (off > 0 ? off : 0)).clamp(1, 9999);
    final range = low <= high ? '$low–$high' : '$high–$low';
    return [street, range, rest].where((s) => s.isNotEmpty).join(' ');
  }

  String _statusLabel(RentalRequest r) {
    switch (r.status) {
      case 'accepted':
        return 'Akzeptiert';
      case 'running':
        return 'Laufend';
      case 'completed':
        return 'Abgeschlossen';
      case 'declined':
        return 'Abgelehnt';
      case 'cancelled':
        return 'Storniert';
      default:
        return 'Angefragt';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabsStyle = Theme.of(context).textTheme.bodySmall;
    
    // Get unread counts for each tab
    final ongoingUnread = _unreadCounts['ongoing'] ?? 0;
    final upcomingUnread = _unreadCounts['upcoming'] ?? 0;
    final pendingUnread = _unreadCounts['pending'] ?? 0;
    final completedUnread = _unreadCounts['completed'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
          title: const Text('Buchungen'),
          centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabAlignment: TabAlignment.center,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.white70,
          labelStyle: tabsStyle,
          unselectedLabelStyle: tabsStyle,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: [
            _buildTabWithBadge('Laufend', ongoingUnread),
            _buildTabWithBadge('Kommend', upcomingUnread),
            _buildTabWithBadge('Ausstehend', pendingUnread),
            _buildTabWithBadge('Abgeschlossen', completedUnread),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList('ongoing'),
          _buildBookingsList('upcoming'),
          _buildBookingsList('pending'),
          _buildBookingsList('completed'),
        ],
      ),
    );
  }
  
  Widget _buildTabWithBadge(String text, int unreadCount) {
    if (unreadCount == 0) {
      return Tab(text: text);
    }
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFFFFB277),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildBookingsList(String status) {
    final bookings = _getBookingsForStatus(status);

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Keine Buchungen',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final (start, end) = _parseDateRange(booking['dates'] ?? '');
        final effectiveCategory = _effectiveCategoryFor(booking, start, end);
        final chip = _buildStatusChipForCard(effectiveCategory, start, end, booking);
        final raw = booking['rawStatus'] as String?;
        final String? targetId = _highlightRequestId?.isNotEmpty == true ? _highlightRequestId : widget.highlightRequestId;
        final bool highlight = (targetId != null && targetId.isNotEmpty &&
            booking['requestId'] == targetId && (status == 'completed' || status == 'pending') && (raw == 'cancelled' || status == 'pending'));

        final bool isPending = (effectiveCategory == 'pending');
        // Build an optional small inline action to sit next to the chip
        final Widget? inlineAction = _buildSmallInlineAction(effectiveCategory, booking, start, end);
        return _BlinkHighlight(
          enabled: highlight && (_highlightRequestId != null),
          onFinished: () {
            if (_highlightRequestId != null) {
              setState(() => _highlightRequestId = null);
            }
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                // Mark request as read when user taps on it
                if (_currentUserId != null) {
                  final requestId = booking['requestId'] as String?;
                  if (requestId != null) {
                    await DataService.markRequestAsRead(userId: _currentUserId!, requestId: requestId);
                  }
                }
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BookingDetailScreen(booking: booking),
                  ),
                );
                if (!mounted) return;
                await _load(); // refresh from storage in case of changes
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: _ThumbnailWithSkeleton(url: booking['image'] as String?),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right content column with fixed height to keep the whole card as high as the image
                    Expanded(
                      child: ConstrainedBox(
                        // Allow the content to grow if text/chip needs a bit more room,
                        // while keeping at least the thumbnail height for alignment.
                        constraints: const BoxConstraints(minHeight: 80),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        booking['title'] ?? '-',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: isPending ? 16 : 18,
                                          color: Colors.white,
                                          height: 1.1,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        booking['dates'] ?? '',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: isPending ? 12 : 13,
                                          height: 1.1,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        booking['location'] ?? '',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: isPending ? 12 : 13,
                                          height: 1.1,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  booking['pricePaid'] ?? '',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: isPending ? 15 : 16,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                            // Bottom row: status chip + optional tiny action; stays within the same 80px block
                            Row(
                              children: [
                                chip,
                                if (inlineAction != null) ...[
                                  const SizedBox(width: 8),
                                  Flexible(child: Align(alignment: Alignment.centerLeft, child: inlineAction)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Quick actions per state
  Widget _buildQuickActionsRow(Map<String, dynamic> booking) {
    final category = booking['category'] as String?;
    switch (category) {
      case 'pending':
        // Entfernt: "Anfrage zurückziehen" gehört jetzt in die Detailseite ganz unten (Ausstehende Buchung)
        return const SizedBox.shrink();
      case 'completed':
        return Wrap(spacing: 8, children: [
          TextButton.icon(
            onPressed: () async {
              final current = await DataService.getCurrentUser();
              if (current == null) return;
              final requestId = booking['requestId'] as String?;
              final itemId = booking['itemId'] as String?;
              final listerId = booking['listerId'] as String?;
              if (requestId == null || itemId == null || listerId == null) return;
              final ok = await ReviewPromptSheet.show(
                context,
                requestId: requestId,
                itemId: itemId,
                reviewerId: current.id,
                reviewedUserId: listerId,
                direction: 'renter_to_owner',
              );
              if (ok == true && context.mounted) {
                await AppPopup.toast(context, icon: Icons.star_rate_outlined, title: 'Danke für deine Bewertung!');
                final item = await DataService.getItemById(itemId);
                if (item != null && context.mounted) {
                  await ItemDetailsOverlay.showFullPage(context, item: item);
                }
              }
            },
            icon: const Icon(Icons.star_rate_outlined, color: Colors.white70, size: 18),
            label: const Text('Bewerten', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          ),
          TextButton.icon(
            onPressed: () => AppPopup.toast(context, icon: Icons.replay, title: 'Wieder mieten gestartet'),
            icon: const Icon(Icons.refresh_outlined, color: Colors.white70, size: 18),
            label: const Text('Wieder mieten', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          ),
        ]);
      default:
        // For upcoming confirmed bookings, add a "Stornieren" quick action
        final (start, end) = _parseDateRange(booking['dates'] ?? '');
        final effective = _effectiveCategoryFor(booking, start, end);
        final rawStatus = booking['rawStatus'] as String?;
        if (effective == 'upcoming' && rawStatus == 'accepted') {
          return Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                // Minimal confirmation text only
                final policy = (booking['policy'] as String?) ?? 'flexible';
                final policyName = DataService.policyName(policy);
                await AppPopup.show(
                  context,
                  icon: Icons.help_outline,
                  title: 'Buchung stornieren?',
                  message: 'Bitte beachte die Stornierungsbedingungen ($policyName).',
                  barrierDismissible: true,
                  plainCloseIcon: true,
                  leadingWidget: Builder(builder: (context) {
                    final danger = Theme.of(context).colorScheme.error;
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                        border: Border.all(color: danger, width: 2),
                      ),
                      child: Icon(Icons.close, color: danger),
                    );
                  }),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(), child: const Text('Abbrechen')),
                    FilledButton(
                      onPressed: () async {
                        Navigator.of(context, rootNavigator: true).maybePop();
                        final id = booking['requestId'] as String?;
                        if (id != null) {
                          await DataService.updateRentalRequestStatusWithActor(requestId: id, status: 'cancelled', cancelledBy: 'renter');
                          if (!mounted) return;
                          await _load();
                          await AppPopup.toast(context, icon: Icons.cancel_outlined, title: 'Buchung storniert');
                          // Switch to Abgeschlossen and highlight the just-cancelled booking
                          setState(() { _highlightRequestId = id; });
                          _tabController.index = 3;
                        }
                      },
                      child: const Text('Stornieren'),
                    ),
                  ],
                );
              },
              icon: const Icon(Icons.cancel_outlined, color: Colors.white70, size: 18),
              label: const Text('Stornieren', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            ),
          );
        }
        return const SizedBox.shrink();
    }
  }

  // Compute effective category for renter view strictly from status.
  // Business rules:
  // - pending → pending
  // - accepted → upcoming (never auto-advance by time)
  // - running → ongoing (only after confirmed Übergabe)
  // - completed/cancelled/declined → completed (never auto-complete by time)
  String _effectiveCategoryFor(Map<String, dynamic> booking, DateTime? start, DateTime? end) {
    final raw = (booking['category'] as String?)?.toLowerCase();
    final status = (booking['rawStatus'] as String?)?.toLowerCase();
    if (raw == 'pending' || status == 'pending') return 'pending';
    if (status == 'accepted') return 'upcoming';
    if (status == 'running') return 'ongoing';
    if (status == 'completed' || status == 'cancelled' || status == 'declined') return 'completed';
    // Fallback for unknown/missing status: treat as upcoming
    return 'upcoming';
  }

  // Status chip with countdown for list card (German, renter view)
  Widget _buildStatusChipForCard(String category, DateTime? start, DateTime? end, [Map<String, dynamic>? booking]) {
    final now = DateTime.now();
    final toPickup = start != null ? start.difference(now) : null;
    // final toReturn = end != null ? end.difference(now) : null; // not used for countdown per latest copy

    String label;
    Color color;

    switch (category) {
      case 'upcoming':
        final txt = toPickup == null
            ? null
            : _formatTwoUnitsCountdown(toPickup.isNegative ? Duration.zero : toPickup);
        label = txt == null ? 'Kommend' : 'Abholung in $txt';
        color = const Color(0xFF0EA5E9); // Blau
        break;
      case 'ongoing':
        // Show "Laufend bis {Datum Uhrzeit}" (no countdown)
        final endText = end != null ? _formatGermanDateTime(end) : '';
        label = endText.isEmpty ? 'Laufend' : 'Laufend bis $endText';
        color = const Color(0xFFFB923C); // Orange
        break;
      case 'pending':
        // If express requested and pending, show countdown
        Duration? remain;
        final expReq = booking?['expressRequested'] == true;
        final expStatus = booking?['expressStatus'] as String?;
        final expAtIso = booking?['expressRequestedAt'] as String?;
        if (expReq && (expStatus == null || expStatus == 'pending') && expAtIso != null && expAtIso.isNotEmpty) {
          final expAt = DateTime.tryParse(expAtIso);
          if (expAt != null) {
            final endAt = expAt.add(const Duration(minutes: 30));
            final left = endAt.difference(now);
            remain = left.isNegative ? Duration.zero : left;
          }
        }
        label = remain != null ? 'Priorität: ${_formatTwoUnitsCountdown(remain)}' : 'Wartet auf Bestätigung';
        color = Colors.grey; // Grau
        break;
      case 'completed':
        final rawStatus = booking?['rawStatus'] as String?;
        final wasCancelled = rawStatus == 'cancelled' || (booking?['status'] == 'Storniert');
        final wasDeclined = rawStatus == 'declined' || (booking?['status'] == 'Abgelehnt');
        if (wasCancelled) {
          label = 'Storniert';
          color = const Color(0xFFF43F5E);
        } else if (wasDeclined) {
          label = 'Abgelehnt';
          color = Colors.grey; // neutral grey for declined
        } else {
          label = 'Abgeschlossen';
          color = const Color(0xFF22C55E);
        }
        break;
      default:
        label = '—';
        color = Colors.grey;
    }

    return Container(
      // Trim vertical padding to keep the compact card within 80px height
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, height: 1.05),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Tiny privacy hint line for cards (upcoming, ongoing) – only for the party who travels
  Widget _privacyHintForCard(Map<String, dynamic> booking) {
    final bool ownerDelivers = booking['ownerDeliversAtDropoffChosen'] == true;
    final bool ownerPicksUp = booking['ownerPicksUpAtReturnChosen'] == true;
    final bool renterTravels = (!ownerDelivers) || (!ownerPicksUp);
    if (!renterTravels) return const SizedBox.shrink();
    final String text = 'Adresse geschützt • Karte + Abhol-/Rückgabeort nur für dich sichtbar';
    return Row(
      children: [
        Icon(Icons.privacy_tip_outlined, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.05),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Build a tiny inline action button to live next to the chip, keeping the card compact
  Widget? _buildSmallInlineAction(String effectiveCategory, Map<String, dynamic> booking, DateTime? start, DateTime? end) {
    final rawStatus = booking['rawStatus'] as String?;
    switch (effectiveCategory) {
      case 'pending':
        // Entfernt: kein Inline-Button mehr – nur noch in der Detailseite unten
        return null;
      case 'upcoming':
        // Kein "Stornieren"-Button mehr in der Kommend-Liste (nur in Detailseite)
        return null;
      case 'completed':
        // Show a tiny "Bewerten" button for completed bookings (not for declined/storniert)
        if (rawStatus == 'completed') {
          return _TinyTextButton(
            icon: Icons.star_rate_outlined,
            label: 'Bewerten',
            onPressed: () async {
              final current = await DataService.getCurrentUser();
              if (current == null) return;
              final requestId = booking['requestId'] as String?;
              final itemId = booking['itemId'] as String?;
              final listerId = booking['listerId'] as String?;
              if (requestId == null || itemId == null || listerId == null) return;
              final ok = await ReviewPromptSheet.show(
                context,
                requestId: requestId,
                itemId: itemId,
                reviewerId: current.id,
                reviewedUserId: listerId,
                direction: 'renter_to_owner',
              );
              if (ok == true && mounted) {
                await AppPopup.toast(context, icon: Icons.star_rate_outlined, title: 'Danke für deine Bewertung!');
                final item = await DataService.getItemById(itemId);
                if (item != null && mounted) {
                  await ItemDetailsOverlay.showFullPage(context, item: item);
                }
              }
            },
          );
        }
        return null;
      default:
        return null; // completed/ongoing have no inline action for now
    }
  }

  // Format durations in days only
  String _formatTwoUnitsCountdown(Duration d) {
    final days = d.inDays;
    if (days == 0) return '1 Tag';
    if (days == 1) return '1 Tag';
    return '$days Tage';
  }

  String _formatGermanDateTime(DateTime d) {
    const months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    final mm = months[d.month - 1];
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd. $mm';
  }

  (String, String) _splitDatesText(String raw) {
    if (raw.contains('–')) {
      final parts = raw.split('–');
      return (parts.first.trim(), parts[1].trim());
    }
    if (raw.contains('-')) {
      final parts = raw.split('-');
      return (parts.first.trim(), parts[1].trim());
    }
    return (raw, '');
  }

  DateTime? _parseGermanDateTime(String s) {
    final months = {
      'Jan': 1,
      'Feb': 2,
      'Mär': 3,
      'Mrz': 3,
      'Apr': 4,
      'Mai': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Okt': 10,
      'Nov': 11,
      'Dez': 12,
    };
    final reg = RegExp(r'^(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]{3})');
    final m = reg.firstMatch(s);
    if (m == null) return null;
    final d = int.tryParse(m.group(1)!);
    final monStr = m.group(2)!;
    if (d == null) return null;
    String key = monStr.substring(0, 1).toUpperCase() + monStr.substring(1, math.min(monStr.length, 3)).toLowerCase();
    if (key == 'Mä' || key == 'Mär') key = 'Mär';
    final month = months[key];
    if (month == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, month, d);
  }

  (DateTime?, DateTime?) _parseDateRange(String raw) {
    final (startText, endText) = _splitDatesText(raw);
    final start = _parseGermanDateTime(startText);
    final end = _parseGermanDateTime(endText);
    if (start == null || end == null) return (start, end);
    if (end.isBefore(start)) {
      return (start, DateTime(start.year + 1, end.month, end.day));
    }
    return (start, end);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Akzeptiert':
        return const Color(0xFF22C55E);
      case 'Angefragt':
        return const Color(0xFFFB923C);
      case 'Bezahlt':
        return const Color(0xFF3B82F6);
      case 'Laufend':
        return const Color(0xFF0EA5E9);
      case 'Abgeschlossen':
        return Colors.blueGrey; // different color for completed confirmation
      case 'Storniert':
        return const Color(0xFFF43F5E);
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _getBookingsForStatus(String status) {
    return _allBookings.where((b) {
      final (start, end) = _parseDateRange(b['dates'] ?? '');
      final effective = _effectiveCategoryFor(b, start, end);
      return effective == status;
    }).toList();
  }
}

// Hinweis: Der frühere Inline-Button _WithdrawInlineButton wurde entfernt.

class _TinyTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onPressed;
  const _TinyTextButton({required this.icon, required this.label, required this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Theme.of(context).colorScheme.primary;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: fg),
      label: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: fg)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 24),
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      ),
    );
  }
}

/// A subtle pulsing glow around a child for a short period.
class _BlinkHighlight extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final Duration totalDuration;
  final VoidCallback? onFinished;
  // Default: 5 full pulses (0->1->0) at 650ms each direction => 6.5s
  const _BlinkHighlight({
    required this.child,
    required this.enabled,
    this.totalDuration = const Duration(milliseconds: 6500),
    this.onFinished,
  });
  @override
  State<_BlinkHighlight> createState() => _BlinkHighlightState();
}

class _BlinkHighlightState extends State<_BlinkHighlight> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;
  Timer? _stopper;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _t = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    if (widget.enabled) {
      _c.repeat(reverse: true);
      _stopper = Timer(widget.totalDuration, () {
        if (!mounted) return;
        _c.stop();
        widget.onFinished?.call();
        setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(covariant _BlinkHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_c.isAnimating) {
      _c.repeat(reverse: true);
      _stopper?.cancel();
      _stopper = Timer(widget.totalDuration, () {
        if (!mounted) return;
        _c.stop();
        widget.onFinished?.call();
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _stopper?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bool active = widget.enabled && _c.isAnimating;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final double p = active ? _t.value : 0.0;
        // We only show subtle pulsing markers on the four corners of the card.
        final double dotSize = 8 + 6 * p; // controls blur footprint
        final Color glow = primary.withValues(alpha: 0.85 * p);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Card content
            child!,
            if (p > 0) ...[
              // Four corner blurs (no visible dots)
              Positioned(
                top: 6,
                left: 6,
                child: _CornerPulseDot(size: dotSize, color: glow),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: _CornerPulseDot(size: dotSize, color: glow),
              ),
              Positioned(
                bottom: 6,
                left: 6,
                child: _CornerPulseDot(size: dotSize, color: glow),
              ),
              Positioned(
                bottom: 6,
                right: 6,
                child: _CornerPulseDot(size: dotSize, color: glow),
              ),
            ],
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _CornerPulseDot extends StatelessWidget {
  final double size;
  final Color color;
  const _CornerPulseDot({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    // Only a soft blue blur in the corner; no visible dot center.
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // keep center fully transparent; render only shadow glow
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * 1.8,
              spreadRadius: 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailWithSkeleton extends StatefulWidget {
  final String? url;
  const _ThumbnailWithSkeleton({required this.url});

  @override
  State<_ThumbnailWithSkeleton> createState() => _ThumbnailWithSkeletonState();
}

class _ThumbnailWithSkeletonState extends State<_ThumbnailWithSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    if (url == null || url.isEmpty) {
      return _skeleton();
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (c, child, progress) {
        if (progress == null) {
          _loaded = true;
          return child;
        }
        return _skeleton();
      },
      errorBuilder: (_, __, ___) => _skeleton(),
    );
  }

  Widget _skeleton() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        final base = Colors.white.withValues(alpha: 0.06);
        final highlight = Colors.white.withValues(alpha: 0.16);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 2, -0.3),
              end: Alignment(1 + t * 2, 0.3),
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}
