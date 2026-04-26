import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lendify/screens/booking_detail_screen.dart';
import 'package:lendify/screens/notification_settings_screen.dart';
import 'package:lendify/screens/message_thread_screen.dart';
import 'package:lendify/screens/payment_methods_screen.dart';
import 'package:lendify/screens/verification_intro_screen.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/services/notification_preferences_service.dart';
import 'package:lendify/theme.dart';
import 'package:provider/provider.dart';

class NotificationsScreen extends StatefulWidget {
  /// Optional: open the notifications screen already filtered to one category.
  ///
  /// When [initialCategory] is provided and [lockToInitialCategory] is true, the
  /// screen behaves like a "category details" page (no filter chips, no
  /// grouping headers – just the list for that category).
  const NotificationsScreen({super.key, this.initialCategory, this.lockToInitialCategory = false, this.titleOverride});

  /// Category key, e.g. 'important', 'bookings', 'messages', 'reviews',
  /// 'payments', 'security', 'platform'.
  final String? initialCategory;

  /// If true, user cannot change the category filter on this screen.
  ///
  /// Note: This is intentionally nullable to stay resilient against stale
  /// hot-reload states on Flutter Web where an older widget shape might still
  /// exist briefly. `null` is treated as `false`.
  final bool? lockToInitialCategory;

  /// Optional app bar title.
  final String? titleOverride;

  bool get isCategoryLocked => lockToInitialCategory == true;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

enum _NotifFilter { all, important, bookings, messages, payments, reviews, system }

enum _DateBucket { today, yesterday, week, older }

class _NotificationsScreenState extends State<NotificationsScreen> {
  _NotifFilter _filter = _NotifFilter.all;
  bool _loading = true;
  String? _currentUserId;
  List<Map<String, dynamic>> _feed = [];
  NotificationPreferences _prefs = NotificationPreferences.defaults();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCategory;
    if (initial != null && initial.isNotEmpty) {
      _filter = _filterForCategory(initial);
    }
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prefs = await NotificationPreferencesService.get();
      final user = await DataService.getCurrentUser();
      final userId = user?.id;
      if (userId == null || userId.isEmpty) {
        setState(() {
          _currentUserId = null;
          _feed = [];
          _prefs = prefs;
        });
        return;
      }
      final feed = await DataService.getNotificationFeedForUser(userId);
      if (!mounted) return;
      setState(() {
        _currentUserId = userId;
        _feed = feed;
        _prefs = prefs;
      });
    } catch (e) {
      debugPrint('[NotificationsScreen] load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    final uid = _currentUserId;
    if (uid == null) return;
    await DataService.markAllNotificationsRead(uid);
    await _load();
  }

  List<Map<String, dynamic>> get _filtered {
    Set<String>? cats;
    switch (_filter) {
      case _NotifFilter.all:
        cats = null;
        break;
      case _NotifFilter.important:
        cats = {'important', 'security'};
        break;
      case _NotifFilter.bookings:
        cats = {'bookings'};
        break;
      case _NotifFilter.messages:
        cats = {'messages'};
        break;
      case _NotifFilter.payments:
        cats = {'payments'};
        break;
      case _NotifFilter.reviews:
        cats = {'reviews'};
        break;
      case _NotifFilter.system:
        cats = {'platform'};
        break;
    }

    bool enabled(String category) {
      switch (category) {
        case 'important':
          return _prefs.showImportant;
        case 'bookings':
          return _prefs.showBookings;
        case 'messages':
          return _prefs.showMessages;
        case 'reviews':
          return _prefs.showReviews;
        // 'platform' is used for system messages in the current structured model.
        case 'platform':
          return _prefs.showSystem;
        // Future expansion (payments/security) – keep these keys supported so we can
        // add structured notifications without breaking settings.
        case 'payments':
          return _prefs.showPayments;
        case 'security':
          return _prefs.showSecurity;
        case 'system':
          return _prefs.showSystem;
        default:
          return true;
      }
    }

    final base = _feed.where((e) => enabled((e['category'] ?? '').toString())).toList();
    if (cats == null) return base;
    return base.where((e) => cats!.contains((e['category'] ?? '').toString())).toList();
  }

  String _categoryKeyForFilter(_NotifFilter f) {
    switch (f) {
      case _NotifFilter.important:
        return 'important';
      case _NotifFilter.bookings:
        return 'bookings';
      case _NotifFilter.messages:
        return 'messages';
      case _NotifFilter.payments:
        return 'payments';
      case _NotifFilter.reviews:
        return 'reviews';
      case _NotifFilter.system:
        return 'platform';
      case _NotifFilter.all:
        return 'all';
    }
  }

  Future<void> _openNotification(Map<String, dynamic> n) async {
    final uid = _currentUserId;
    if (uid == null) return;

    final id = (n['id'] ?? '').toString();
    if (id.isNotEmpty) {
      // Mark read immediately to make the UI feel responsive.
      await DataService.markNotificationRead(userId: uid, notificationId: id);
      if (mounted) {
        setState(() {
          _feed = [
            for (final e in _feed)
              if ((e['id'] ?? '').toString() == id) {...e, 'read': true} else e,
          ];
        });
      }
    }

    final category = (n['category'] ?? '').toString();
    final entityType = (n['entityType'] ?? '').toString();
    final entityId = (n['entityId'] ?? '').toString();

    // If the notification has no deep-link target, show a detail popup.
    if (entityType.isEmpty || entityId.isEmpty) {
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _NotificationDetailsSheet(notification: n),
      );
      return;
    }

    try {
      if (entityType == 'booking') {
        final req = await DataService.getRentalRequestById(entityId);
        if (req == null) return;
        final item = await DataService.getItemById(req.itemId);
        if (item == null) return;
        final owner = await DataService.getUserById(req.ownerId);
        final deliverySel = await DataService.getSavedDeliverySelection(req.itemId);
        final booking = _toBookingMap(req, item, owner, deliverySel);
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: booking, viewerIsOwner: uid == req.ownerId)));
        if (mounted) await _load();
        return;
      }

      if (entityType == 'thread') {
        final thread = await DataService.getMessageThreadById(entityId);
        if (thread == null) return;
        final otherId = (thread.user1Id == uid) ? thread.user2Id : thread.user1Id;
        final other = await DataService.getUserById(otherId);
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MessageThreadScreen(
              threadId: thread.id,
              participantName: other?.displayName ?? 'Chat',
              avatarUrl: other?.photoURL,
              itemTitle: thread.itemTitle,
            ),
          ),
        );
        if (mounted) await _load();
        return;
      }

      if (entityType == 'payment') {
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentMethodsScreen()));
        return;
      }

      // Security/verification: open the verification flow.
      if (entityType == 'verification' || category == 'security') {
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VerificationIntroScreen()));
        return;
      }

      // Fallback: show details for any unhandled entityType (e.g. 'system').
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _NotificationDetailsSheet(notification: n),
      );
    } catch (e) {
      debugPrint('[NotificationsScreen] openNotification failed: $e');
    }
  }

  Future<void> _archive(Map<String, dynamic> n) async {
    final uid = _currentUserId;
    if (uid == null) return;
    final id = (n['id'] ?? '').toString();
    if (id.isEmpty) return;
    await DataService.archiveNotification(userId: uid, notificationId: id);
    await _load();
  }

  void _setFilter(_NotifFilter f) {
    if (widget.isCategoryLocked) return;
    if (_filter == f) return;
    setState(() => _filter = f);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
  }

  _NotifFilter _filterForCategory(String category) {
    switch (category) {
      case 'important':
      case 'security':
        return _NotifFilter.important;
      case 'bookings':
        return _NotifFilter.bookings;
      case 'messages':
        return _NotifFilter.messages;
      case 'payments':
        return _NotifFilter.payments;
      case 'reviews':
        return _NotifFilter.reviews;
      case 'platform':
      default:
        return _NotifFilter.system;
    }
  }

  String _labelForCategory(String category) {
    switch (category) {
      case 'important':
        return 'Wichtig';
      case 'bookings':
        return 'Buchungen';
      case 'messages':
        return 'Nachrichten';
      case 'payments':
        return 'Zahlungen';
      case 'security':
        return 'Wichtig';
      case 'reviews':
        return 'Bewertungen';
      case 'platform':
      default:
        return 'System';
    }
  }

  Map<_DateBucket, List<Map<String, dynamic>>> _groupByDate(List<Map<String, dynamic>> list) {
    final out = <_DateBucket, List<Map<String, dynamic>>>{
      _DateBucket.today: [],
      _DateBucket.yesterday: [],
      _DateBucket.week: [],
      _DateBucket.older: [],
    };
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final n in list) {
      final ts = DateTime.tryParse((n['ts'] ?? '').toString());
      if (ts == null) {
        out[_DateBucket.older]!.add(n);
        continue;
      }
      final d = DateTime(ts.year, ts.month, ts.day);
      if (d == today) {
        out[_DateBucket.today]!.add(n);
      } else if (d == yesterday) {
        out[_DateBucket.yesterday]!.add(n);
      } else if (ts.isAfter(today.subtract(const Duration(days: 7)))) {
        out[_DateBucket.week]!.add(n);
      } else {
        out[_DateBucket.older]!.add(n);
      }
    }

    for (final e in out.entries) {
      e.value.sort(_compareNotifications);
    }
    return out;
  }

  int _compareNotifications(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (_prefs.unreadFirst) {
      final ar = a['read'] == true;
      final br = b['read'] == true;
      if (ar != br) return ar ? 1 : -1;
    }

    final at = DateTime.tryParse((a['ts'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = DateTime.tryParse((b['ts'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bt.compareTo(at);
  }

  Map<String, List<Map<String, dynamic>>> _groupByCategory(List<Map<String, dynamic>> list) {
    final out = <String, List<Map<String, dynamic>>>{
      'important': [],
      'bookings': [],
      'messages': [],
      'payments': [],
      'reviews': [],
      'platform': [],
    };

    for (final n in list) {
      final raw = (n['category'] ?? '').toString();
      final key = switch (raw) {
        'security' => 'important',
        'system' => 'platform',
        _ => raw,
      };
      if (!out.containsKey(key)) continue;
      out[key]!.add(n);
    }

    for (final e in out.entries) {
      e.value.sort(_compareNotifications);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final theme = Theme.of(context);

    final visible = _filtered;
    final unreadCount = visible.where((e) => e['read'] != true).length;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_currentUserId == null) {
      body = _EmptyState(
        icon: Icons.notifications_off,
        title: 'Nicht verfügbar',
        subtitle: 'Bitte erst ein Profil erstellen, um deinen persönlichen Benachrichtigungs‑Feed zu sehen. Einstellungen kannst du aber schon festlegen.',
      );
    } else if (visible.isEmpty) {
      final bool categoryMode = widget.isCategoryLocked && widget.initialCategory != null && widget.initialCategory!.isNotEmpty;
      final bool isFiltered = _filter != _NotifFilter.all;
      if (categoryMode || isFiltered) {
        final String catKey = categoryMode ? widget.initialCategory! : _categoryKeyForFilter(_filter);
        final String label = _labelForCategory(catKey);
        body = _EmptyState(
          icon: Icons.notifications_none,
          title: 'Keine Benachrichtigungen in „$label“',
          subtitle: 'Sobald es neue Updates in dieser Kategorie gibt, erscheinen sie hier.',
        );
      } else {
        body = _EmptyState(
          icon: Icons.notifications_none,
          title: 'Hier siehst du künftig deine Benachrichtigungen.',
          subtitle: 'Sobald es Neuigkeiten zu deinen Buchungen oder Nachrichten gibt, erscheinen sie hier.',
        );
      }
    } else {
      final bool categoryMode = widget.isCategoryLocked && widget.initialCategory != null && widget.initialCategory!.isNotEmpty;

      body = CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          if (!categoryMode)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 12, 16, 10),
                child: _FilterBar(filter: _filter, onChanged: _setFilter),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: kToolbarHeight + 12)),
          if (categoryMode)
            SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), sliver: _notifSliverList(theme, ([...visible]..sort(_compareNotifications))))
          else if (_prefs.groupByCategory)
            ..._buildCategoryGroupedSlivers(theme, visible)
          else
            ..._buildDateGroupedSlivers(theme, visible),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
        ),
        Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            title: SizedBox(
              width: double.infinity,
              child: Text(widget.titleOverride ?? l10n.t('account.item.notifications'), textAlign: TextAlign.center),
            ),
            centerTitle: true,
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
            actions: [
              IconButton(
                tooltip: 'Einstellungen',
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()));
                  if (mounted) await _load();
                },
              ),
              IconButton(
                tooltip: 'Alle als gelesen markieren',
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.done_all, color: Colors.white),
                    if (unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
                onPressed: unreadCount == 0 ? null : _markAllRead,
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: RefreshIndicator(
            color: theme.colorScheme.primary,
            onRefresh: _load,
            child: body,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDateGroupedSlivers(ThemeData theme, List<Map<String, dynamic>> visible) {
    final grouped = _groupByDate(visible);
    const order = [_DateBucket.today, _DateBucket.yesterday, _DateBucket.week, _DateBucket.older];
    return [
      for (final b in order)
        if (grouped[b] != null && grouped[b]!.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: _DateHeader(bucket: b),
            ),
          ),
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), sliver: _notifSliverList(theme, grouped[b]!)),
        ],
    ];
  }

  List<Widget> _buildCategoryGroupedSlivers(ThemeData theme, List<Map<String, dynamic>> visible) {
    final grouped = _groupByCategory(visible);
    const order = ['important', 'bookings', 'messages', 'payments', 'reviews', 'platform'];
    return [
      for (final key in order)
        if (grouped[key] != null && grouped[key]!.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: _CategoryHeader(label: _labelForCategory(key), icon: _iconForCategory(key)),
            ),
          ),
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), sliver: _notifSliverList(theme, grouped[key]!)),
        ],
    ];
  }

  SliverList _notifSliverList(ThemeData theme, List<Map<String, dynamic>> list) {
    return SliverList.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final n = list[index];
        final critical = n['critical'] == true;
        final archivable = !critical && (n['category']?.toString() == 'platform');
        final card = _NotificationCard(
          notification: n,
          onTap: () => _openNotification(n),
          onAction: (actionId) => _handleQuickAction(notification: n, actionId: actionId),
        );
        if (!archivable) return card;
        return Dismissible(
          key: ValueKey('notif_${n['id']}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.archive_outlined, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            await _archive(n);
            return true;
          },
          child: card,
        );
      },
    );
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'important':
        return Icons.error_outline;
      case 'bookings':
        return Icons.calendar_month_outlined;
      case 'messages':
        return Icons.chat_bubble_outline;
      case 'payments':
        return Icons.payments_outlined;
      case 'reviews':
        return Icons.star_outline;
      case 'platform':
      default:
        return Icons.info_outline;
    }
  }

  Future<void> _handleQuickAction({required Map<String, dynamic> notification, required String actionId}) async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      if (actionId == 'reply') {
        await _openNotification(notification);
        return;
      }

      final entityType = (notification['entityType'] ?? '').toString();
      final entityId = (notification['entityId'] ?? '').toString();
      if (entityType == 'booking' && entityId.isNotEmpty) {
        if (actionId == 'accept') {
          await DataService.updateRentalRequestStatus(requestId: entityId, status: 'accepted');
          await _load();
          return;
        }
        if (actionId == 'decline') {
          await DataService.updateRentalRequestStatus(requestId: entityId, status: 'declined');
          await _load();
          return;
        }
      }

      await _openNotification(notification);
    } catch (e) {
      debugPrint('[NotificationsScreen] quickAction failed: $e');
    }
  }

  Map<String, dynamic> _toBookingMap(RentalRequest req, Item it, User? owner, Map<String, dynamic>? deliverySel) {
    // We intentionally keep this minimal-but-compatible with BookingDetailScreen.
    // (BookingDetailScreen reads keys defensively; missing optional fields are okay.)
    String fmt(DateTime d) {
      const months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
      final mm = months[d.month - 1];
      final dd = d.day.toString().padLeft(2, '0');
      return '$dd. $mm';
    }

    final breakdown = DataService.priceBreakdownForRequest(item: it, req: req, deliverySel: deliverySel);
    final total = (req.quotedTotalRenter ?? breakdown.totalRenter);
    return {
      'requestId': req.id,
      'itemId': it.id,
      'rawStatus': req.status,
      'cancelledBy': req.cancelledBy,
      'needsReview': req.needsReview,
      'title': it.title,
      'dates': '${fmt(req.start)} – ${fmt(req.end)}',
      'location': it.locationText,
      'status': req.status,
      'image': (it.photos.isNotEmpty ? it.photos.first : null),
      'images': it.photos,
      'listerId': it.ownerId,
      'listerName': owner?.displayName ?? 'Vermieter',
      'listerAvatar': owner?.photoURL,
      'pricePaid': '${total.round()} €',
      'quotedTotalRenter': total,
      'days': breakdown.days,
      'basePerDay': it.pricePerDay,
      'expressRequested': req.expressRequested,
      'expressStatus': req.expressStatus,
      'expressRequestedAt': req.expressRequestedAt?.toIso8601String(),
      'startIso': req.start.toIso8601String(),
      'endIso': req.end.toIso8601String(),
      'policy': it.cancellationPolicy,
      'requestCreatedAtIso': req.createdAt.toIso8601String(),
      'offersDeliveryAtDropoff': it.offersDeliveryAtDropoff,
      'offersPickupAtReturn': it.offersPickupAtReturn,
      'ownerDeliversAtDropoffChosen': req.ownerDeliversAtDropoffChosen,
      'ownerPicksUpAtReturnChosen': req.ownerPicksUpAtReturnChosen,
      'deliveryAddressLine': req.deliveryAddressLine ?? (deliverySel?['addressLine'] as String?) ?? '',
      'deliveryCity': req.deliveryCity ?? (deliverySel?['city'] as String?) ?? '',
      'deliveryLat': req.deliveryLat ?? (deliverySel?['lat'] as num?)?.toDouble(),
      'deliveryLng': req.deliveryLng ?? (deliverySel?['lng'] as num?)?.toDouble(),
    };
  }
}

class _FilterBar extends StatelessWidget {
  final _NotifFilter filter;
  final ValueChanged<_NotifFilter> onChanged;
  const _FilterBar({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _FilterPill(label: 'Alle', selected: filter == _NotifFilter.all, onTap: () => onChanged(_NotifFilter.all)),
          const SizedBox(width: 8),
          _FilterPill(label: 'Wichtig', selected: filter == _NotifFilter.important, onTap: () => onChanged(_NotifFilter.important)),
          const SizedBox(width: 8),
          _FilterPill(label: 'Buchungen', selected: filter == _NotifFilter.bookings, onTap: () => onChanged(_NotifFilter.bookings)),
          const SizedBox(width: 8),
          _FilterPill(label: 'Nachrichten', selected: filter == _NotifFilter.messages, onTap: () => onChanged(_NotifFilter.messages)),
          const SizedBox(width: 8),
          _FilterPill(label: 'Zahlungen', selected: filter == _NotifFilter.payments, onTap: () => onChanged(_NotifFilter.payments)),
          const SizedBox(width: 8),
          _FilterPill(label: 'Bewertungen', selected: filter == _NotifFilter.reviews, onTap: () => onChanged(_NotifFilter.reviews)),
          const SizedBox(width: 8),
          _FilterPill(label: 'System', selected: filter == _NotifFilter.system, onTap: () => onChanged(_NotifFilter.system)),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: selected ? 0.18 : 0.10)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: selected ? 1.0 : 0.85), fontWeight: selected ? FontWeight.w800 : FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accent.withValues(alpha: 0.42), accent.withValues(alpha: 0.14)]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.10))),
      ],
    );
  }
}

class _DateHeader extends StatelessWidget {
  final _DateBucket bucket;
  const _DateHeader({required this.bucket});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (bucket) {
      _DateBucket.today => 'Heute',
      _DateBucket.yesterday => 'Gestern',
      _DateBucket.week => 'Diese Woche',
      _DateBucket.older => 'Älter',
    };

    return Row(
      children: [
        Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.10))),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;
  const _NotificationCard({required this.notification, required this.onTap, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final cat = (notification['category'] ?? 'platform').toString();
    final title = (notification['title'] ?? '').toString();
    final body = (notification['body'] ?? '').toString();
    final tsStr = (notification['ts'] ?? '').toString();
    final ts = DateTime.tryParse(tsStr);
    final timeLabel = ts == null ? '' : _relativeTime(ts);
    final read = notification['read'] == true;
    final actions = (notification['actions'] is List) ? List<Map<String, dynamic>>.from(notification['actions'] as List) : <Map<String, dynamic>>[];

    final (icon, tint) = _meta(cat, accent);
    final hasDeepLink = (notification['entityType']?.toString().isNotEmpty ?? false) && (notification['entityId']?.toString().isNotEmpty ?? false);
    final bool showChevron = hasDeepLink || body.trim().isNotEmpty;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: read ? 0.78 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: read ? 0.055 : 0.075),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: read ? Colors.white.withValues(alpha: 0.10) : accent.withValues(alpha: 0.22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [tint.withValues(alpha: 0.60), tint.withValues(alpha: 0.18)]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: read ? FontWeight.w700 : FontWeight.w900),
                                ),
                              ),
                              if (!read) ...[
                                const SizedBox(width: 8),
                                Container(width: 9, height: 9, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                              ],
                              if (showChevron) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.7)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.86))),
                          if (timeLabel.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(timeLabel, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.70))),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _QuickActionsRow(actions: actions, onAction: onAction),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static (IconData, Color) _meta(String category, Color accent) {
    switch (category) {
      case 'important':
      case 'security':
        return (Icons.error_outline, BrandColors.danger);
      case 'bookings':
        return (Icons.calendar_month_outlined, accent);
      case 'messages':
        return (Icons.chat_bubble_outline, const Color(0xFF22C55E));
      case 'payments':
        return (Icons.payments_outlined, const Color(0xFF8B5CF6));
      case 'reviews':
        return (Icons.star_outline, const Color(0xFF3B82F6));
      case 'platform':
      default:
        return (Icons.info_outline, const Color(0xFF64748B));
    }
  }

  static String _relativeTime(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    if (diff.inDays < 7) return 'vor ${diff.inDays} Tg.';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return 'vor ${weeks} W.';
    final months = (diff.inDays / 30).floor();
    return 'vor ${months} Mon.';
  }
}

class _QuickActionsRow extends StatelessWidget {
  final List<Map<String, dynamic>> actions;
  final ValueChanged<String> onAction;
  const _QuickActionsRow({required this.actions, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final visible = actions
        .where((e) => (e['id'] ?? '').toString().isNotEmpty && (e['label'] ?? '').toString().isNotEmpty)
        .take(2)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    Widget button({required String label, required String id, required bool primary}) {
      final bg = primary ? accent.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.08);
      final border = primary ? accent.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.12);
      return Expanded(
        child: SizedBox(
          height: 40,
          child: OutlinedButton(
            onPressed: () => onAction(id),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: bg,
              side: BorderSide(color: border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
      );
    }

    if (visible.length == 1) {
      final a = visible.first;
      return Row(children: [button(label: (a['label'] ?? '').toString(), id: (a['id'] ?? '').toString(), primary: true)]);
    }

    final a = visible[0];
    final b = visible[1];
    return Row(
      children: [
        button(label: (a['label'] ?? '').toString(), id: (a['id'] ?? '').toString(), primary: true),
        const SizedBox(width: 10),
        button(label: (b['label'] ?? '').toString(), id: (b['id'] ?? '').toString(), primary: false),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [BrandColors.logoGradientStart, BrandColors.logoGradientEnd]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.82))),
          ],
        ),
      ),
    );
  }
}

class _NotificationDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> notification;
  const _NotificationDetailsSheet({required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = (notification['title'] ?? '').toString();
    final body = (notification['body'] ?? '').toString();
    final tsStr = (notification['ts'] ?? '').toString();
    final ts = DateTime.tryParse(tsStr);
    final timeLabel = ts == null ? '' : _NotificationCard._relativeTime(ts);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            color: Colors.black.withValues(alpha: 0.55),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Schließen',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    if (timeLabel.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(timeLabel, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.72))),
                    ],
                    const SizedBox(height: 12),
                    Text(body, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.88), height: 1.45)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.16))),
                            child: const Text('OK'),
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
  }
}
