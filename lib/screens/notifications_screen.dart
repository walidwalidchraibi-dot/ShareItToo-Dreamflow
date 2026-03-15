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

enum _NotifFilter { all, important, bookings, messages, reviews, payments, security, platform }

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
    String? cat;
    switch (_filter) {
      case _NotifFilter.all:
        cat = null;
        break;
      case _NotifFilter.important:
        cat = 'important';
        break;
      case _NotifFilter.bookings:
        cat = 'bookings';
        break;
      case _NotifFilter.messages:
        cat = 'messages';
        break;
      case _NotifFilter.reviews:
        cat = 'reviews';
        break;
      case _NotifFilter.payments:
        cat = 'payments';
        break;
      case _NotifFilter.security:
        cat = 'security';
        break;
      case _NotifFilter.platform:
        cat = 'platform';
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
    if (cat == null) return base;
    return base.where((e) => (e['category'] ?? '').toString() == cat).toList();
  }

  String _categoryKeyForFilter(_NotifFilter f) {
    switch (f) {
      case _NotifFilter.important:
        return 'important';
      case _NotifFilter.bookings:
        return 'bookings';
      case _NotifFilter.messages:
        return 'messages';
      case _NotifFilter.reviews:
        return 'reviews';
      case _NotifFilter.payments:
        return 'payments';
      case _NotifFilter.security:
        return 'security';
      case _NotifFilter.platform:
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
        return _NotifFilter.important;
      case 'bookings':
        return _NotifFilter.bookings;
      case 'messages':
        return _NotifFilter.messages;
      case 'reviews':
        return _NotifFilter.reviews;
      case 'payments':
        return _NotifFilter.payments;
      case 'security':
        return _NotifFilter.security;
      case 'platform':
      default:
        return _NotifFilter.platform;
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
      case 'reviews':
        return 'Bewertungen';
      case 'payments':
        return 'Zahlungen';
      case 'security':
        return 'Sicherheit';
      case 'platform':
      default:
        return 'Plattform';
    }
  }

  Future<void> _openCategory(String category) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          initialCategory: category,
          lockToInitialCategory: true,
          titleOverride: _labelForCategory(category),
        ),
      ),
    );
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

      if (!categoryMode && _prefs.groupByCategory) {
        final grouped = _groupByCategory(visible);
        body = CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 12, 16, 10),
                child: _FilterRow(
                  filter: _filter,
                  onChanged: _setFilter,
                  onOpenCategory: _openCategory,
                ),
              ),
            ),
            for (final section in _sectionOrder)
              if (grouped[section] != null && grouped[section]!.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: _SectionHeader(
                      category: section,
                      count: grouped[section]!.where((e) => e['read'] != true).length,
                      onTap: () => _openCategory(section),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverList.separated(
                    itemCount: grouped[section]!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final n = grouped[section]![index];
                      final critical = n['critical'] == true;
                      final archivable = !critical && (n['category']?.toString() == 'platform');
                      final card = _NotificationCard(
                        notification: n,
                        onTap: () => _openNotification(n),
                        onCta: (n['ctaLabel']?.toString().isNotEmpty ?? false) ? () => _openNotification(n) : null,
                      );
                      if (!archivable) return card;
                      return Dismissible(
                        key: ValueKey('notif_${n['id']}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(color: BrandColors.logoAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
                          child: const Icon(Icons.archive_outlined, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          await _archive(n);
                          return true;
                        },
                        child: card,
                      );
                    },
                  ),
                ),
              ],
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
          ],
        );
      } else {
        body = CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            if (!categoryMode)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 12, 16, 10),
                  child: _FilterRow(
                    filter: _filter,
                    onChanged: _setFilter,
                    onOpenCategory: _openCategory,
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: kToolbarHeight + 12)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final n = visible[index];
                  final critical = n['critical'] == true;
                  final archivable = !critical && (n['category']?.toString() == 'platform');
                  final card = _NotificationCard(
                    notification: n,
                    onTap: () => _openNotification(n),
                    onCta: (n['ctaLabel']?.toString().isNotEmpty ?? false) ? () => _openNotification(n) : null,
                  );
                  if (!archivable) return card;
                  return Dismissible(
                    key: ValueKey('notif_${n['id']}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(color: BrandColors.logoAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
                      child: const Icon(Icons.archive_outlined, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      await _archive(n);
                      return true;
                    },
                    child: card,
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
          ],
        );
      }
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
                          decoration: const BoxDecoration(color: BrandColors.logoAccent, shape: BoxShape.circle),
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

  static const List<String> _sectionOrder = ['important', 'bookings', 'messages', 'reviews', 'payments', 'security', 'platform'];

  Map<String, List<Map<String, dynamic>>> _groupByCategory(List<Map<String, dynamic>> list) {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final n in list) {
      final c = (n['category'] ?? 'platform').toString();
      out.putIfAbsent(c, () => []).add(n);
    }
    // Ensure newest first within each category.
    for (final e in out.entries) {
      e.value.sort((a, b) {
        final at = DateTime.tryParse((a['ts'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = DateTime.tryParse((b['ts'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    }
    return out;
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

class _FilterRow extends StatelessWidget {
  final _NotifFilter filter;
  final ValueChanged<_NotifFilter> onChanged;
  final ValueChanged<String>? onOpenCategory;
  const _FilterRow({required this.filter, required this.onChanged, this.onOpenCategory});

  static String _categoryKey(_NotifFilter f) {
    switch (f) {
      case _NotifFilter.important:
        return 'important';
      case _NotifFilter.bookings:
        return 'bookings';
      case _NotifFilter.messages:
        return 'messages';
      case _NotifFilter.reviews:
        return 'reviews';
      case _NotifFilter.payments:
        return 'payments';
      case _NotifFilter.security:
        return 'security';
      case _NotifFilter.platform:
        return 'platform';
      case _NotifFilter.all:
        return 'all';
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, _NotifFilter value) {
      final selected = filter == value;
      return ChoiceChip(
        label: Text(label, overflow: TextOverflow.ellipsis),
        selected: selected,
        showCheckmark: false,
        selectedColor: BrandColors.logoAccent.withValues(alpha: 0.25),
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        side: BorderSide(color: Colors.white.withValues(alpha: selected ? 0.22 : 0.10)),
        labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: selected ? Colors.white : Colors.white.withValues(alpha: 0.86)),
        onSelected: (_) {
          if (value == _NotifFilter.all) {
            onChanged(value);
            return;
          }
          final key = _categoryKey(value);
          if (onOpenCategory != null) {
            onOpenCategory!(key);
            return;
          }
          onChanged(value);
        },
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          chip('Alle', _NotifFilter.all),
          const SizedBox(width: 8),
          chip('Wichtig', _NotifFilter.important),
          const SizedBox(width: 8),
          chip('Buchungen', _NotifFilter.bookings),
          const SizedBox(width: 8),
          chip('Nachrichten', _NotifFilter.messages),
          const SizedBox(width: 8),
          chip('Bewertungen', _NotifFilter.reviews),
          const SizedBox(width: 8),
          chip('Zahlungen', _NotifFilter.payments),
          const SizedBox(width: 8),
          chip('Sicherheit', _NotifFilter.security),
          const SizedBox(width: 8),
          chip('Plattform', _NotifFilter.platform),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String category;
  final int count;
  final VoidCallback? onTap;
  const _SectionHeader({required this.category, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, label, tint) = _meta(category);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [tint.withValues(alpha: 0.55), tint.withValues(alpha: 0.20)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: BrandColors.logoAccent.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(999)),
                  child: Text('$count neu', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.70)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static (IconData, String, Color) _meta(String category) {
    switch (category) {
      case 'important':
        return (Icons.error_outline, 'Wichtig', BrandColors.danger);
      case 'bookings':
        return (Icons.calendar_month_outlined, 'Buchungen', BrandColors.primary);
      case 'messages':
        return (Icons.chat_bubble_outline, 'Nachrichten', const Color(0xFF22C55E));
      case 'reviews':
        return (Icons.star_outline, 'Bewertungen', const Color(0xFFFB923C));
      case 'payments':
        return (Icons.payments_outlined, 'Zahlungen', const Color(0xFF8B5CF6));
      case 'security':
        return (Icons.verified_user_outlined, 'Sicherheit', const Color(0xFF06B6D4));
      case 'platform':
      default:
        return (Icons.info_outline, 'Plattform', const Color(0xFF3B82F6));
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  final VoidCallback? onCta;
  const _NotificationCard({required this.notification, required this.onTap, this.onCta});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cat = (notification['category'] ?? 'platform').toString();
    // Category icon is shown in the section header (e.g. "Nachrichten", "Bewertungen").
    // Inside the card we keep a clean text-first layout.
    final title = (notification['title'] ?? '').toString();
    final body = (notification['body'] ?? '').toString();
    final tsStr = (notification['ts'] ?? '').toString();
    final ts = DateTime.tryParse(tsStr);
    final timeLabel = ts == null ? '' : _relativeTime(ts);
    final read = notification['read'] == true;
    final cta = (notification['ctaLabel'] ?? '').toString();

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
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: read ? 0.08 : 0.14)),
            ),
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
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: read ? FontWeight.w600 : FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (!read) Container(width: 10, height: 10, decoration: const BoxDecoration(color: BrandColors.logoAccent, shape: BoxShape.circle)),
                    if (showChevron) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.7)),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.86))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text(timeLabel, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.70)))),
                    if (cta.isNotEmpty)
                      TextButton(
                        onPressed: onCta,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          backgroundColor: BrandColors.logoAccent.withValues(alpha: 0.20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        child: Text(cta, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
