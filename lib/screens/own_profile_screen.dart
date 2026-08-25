import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/models/review.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/review_metrics_service.dart';
import 'package:lendify/services/shared_persistence_sync.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/widgets/item_details_overlay.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/widgets/user_avatar.dart';
import 'package:lendify/widgets/app_popup.dart';

class OwnProfileScreen extends StatefulWidget {
  final int initialTabIndex;
  const OwnProfileScreen({super.key, this.initialTabIndex = 0});
  @override
  State<OwnProfileScreen> createState() => _OwnProfileScreenState();
}

class _OwnProfileScreenState extends State<OwnProfileScreen> with SingleTickerProviderStateMixin {
  User? _user;
  List<Item> _myItems = [];
  bool _loading = true;
  String? _loadError;
  late TabController _tabController;
  final TextEditingController _bioCtrl = TextEditingController();
  StreamSubscription<String>? _persistenceSubscription;
  final SharedPersistenceRefreshCoordinator _refreshCoordinator = SharedPersistenceRefreshCoordinator();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: widget.initialTabIndex.clamp(0, 4));
    _persistenceSubscription = SharedPersistenceSync.changes.listen((key) {
      if (key != SharedPersistenceSync.listingCatalogKey &&
          key != SharedPersistenceSync.reviewReputationKey) {
        return;
      }
      _refreshCoordinator.schedule(() async {
        await SharedPersistenceSync.reloadPreferences();
        await _load();
      });
    });
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
        _user = null;
        _myItems = const <Item>[];
        _bioCtrl.clear();
      });
    }
    try {
      final user = await DataService.getCurrentUser();
      final expectedUserId = user?.id.trim() ?? '';
      if (expectedUserId.isEmpty) {
        throw StateError('Für dein Profil ist eine Anmeldung erforderlich.');
      }
      final items = await DataService.getItems();
      final rechecked = await DataService.getCurrentUser();
      if (rechecked?.id.trim() != expectedUserId) {
        throw StateError('Das angemeldete Konto hat sich geändert.');
      }
      if (!mounted) return;
      setState(() {
        _user = user;
        _myItems = items.where((item) => item.ownerId == expectedUserId).toList();
        _bioCtrl.text = user!.bio ?? '';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _user = null;
        _myItems = const <Item>[];
        _bioCtrl.clear();
        _loading = false;
        _loadError = 'Dein Profil konnte nicht sicher geladen werden.';
      });
    }
  }

  @override
  void dispose() {
    _persistenceSubscription?.cancel();
    _refreshCoordinator.dispose();
    _tabController.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final verified = _user?.isVerified ?? false;
    final avg = _user?.avgRating ?? 0;
    final count = _user?.reviewCount ?? 0;
    final metrics = _computeMetrics(avgRating: avg, reviewCount: count, isVerified: verified);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.t('Mein Profil')),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.white70,
          labelStyle: Theme.of(context).textTheme.bodySmall,
          unselectedLabelStyle: Theme.of(context).textTheme.bodySmall,
          tabs: [
            Tab(text: l10n.t('Anzeigen')),
            Tab(text: l10n.t('Interessen')),
            Tab(text: l10n.t('Buchungen')),
            Tab(text: l10n.t('Bewertungen')),
            Tab(text: l10n.t('Über mich')),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _OwnProfileLoadFailure(message: _loadError!, onRetry: _load)
              : TabBarView(controller: _tabController, children: [
                  _ListingsTab(items: _myItems),
                  _InterestsTab(user: _user, onChanged: _updateUserInterests),
                  const _BookingsHistoryTab(),
                  _ReviewsTab(
                    key: ValueKey('own-reviews-${_user!.id}'),
                    userId: _user!.id,
                    avgRating: avg,
                    reviewCount: count,
                  ),
                  _AboutMeTab(user: _user, metrics: metrics, bioCtrl: _bioCtrl, onBioSaved: _saveBio),
                ]),
    );
  }

  void _updateUserInterests(List<String> interests) async {
    if (_user == null) return;
    final updated = User(
      id: _user!.id,
      displayName: _user!.displayName,
      email: _user!.email,
      phone: _user!.phone,
      photoURL: _user!.photoURL,
      bio: _user!.bio,
      city: _user!.city,
      country: _user!.country,
      preferredLanguage: _user!.preferredLanguage,
      isVerified: _user!.isVerified,
      isBanned: _user!.isBanned,
      role: _user!.role,
      payoutAccountId: _user!.payoutAccountId,
      avgRating: _user!.avgRating,
      reviewCount: _user!.reviewCount,
      createdAt: _user!.createdAt,
      languages: _user!.languages,
      interests: interests,
    );
    await DataService.setCurrentUser(updated);
    setState(() => _user = updated);
  }

  void _saveBio(String bio) async {
    if (_user == null) return;
    final updated = User(
      id: _user!.id,
      displayName: _user!.displayName,
      email: _user!.email,
      phone: _user!.phone,
      photoURL: _user!.photoURL,
      bio: bio,
      city: _user!.city,
      country: _user!.country,
      preferredLanguage: _user!.preferredLanguage,
      isVerified: _user!.isVerified,
      isBanned: _user!.isBanned,
      role: _user!.role,
      payoutAccountId: _user!.payoutAccountId,
      avgRating: _user!.avgRating,
      reviewCount: _user!.reviewCount,
      createdAt: _user!.createdAt,
      languages: _user!.languages,
      interests: _user!.interests,
    );
    await DataService.setCurrentUser(updated);
    setState(() => _user = updated);
  }

  _UserMetrics _computeMetrics({required double avgRating, required int reviewCount, required bool isVerified}) {
    final trust = (isVerified ? 20 : 0) + (avgRating * 12).clamp(0, 60) + (reviewCount.clamp(0, 50) * 0.4).clamp(0, 20);
    return _UserMetrics(trustScore: trust.clamp(0, 100).toDouble(), responseTimeMinutes: null, cancellationRate: null);
  }
}

class _OwnProfileLoadFailure extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _OwnProfileLoadFailure({
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

class _ListingsTab extends StatefulWidget {
  final List<Item> items;
  const _ListingsTab({required this.items});
  @override
  State<_ListingsTab> createState() => _ListingsTabState();
}

class _ListingsTabState extends State<_ListingsTab> {
  late List<Item> _items;
  String _bucket = 'active'; // active | requests | paused | draft
  bool _actionBusy = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
  }

  @override
  void didUpdateWidget(covariant _ListingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _items = List<Item>.of(widget.items);
      _loadError = null;
    }
  }

  List<Item> _applyBucket(List<Item> src) {
    switch (_bucket) {
      case 'requests':
        return src.where((e) => (e.verificationStatus == 'pending') && (e.status != 'draft')).toList();
      case 'paused':
        return src.where((e) => e.status == 'paused').toList();
      case 'draft':
        return src.where((e) => e.status == 'draft').toList();
      case 'active':
      default:
        return src.where((e) => e.status == 'active').toList();
    }
  }

  Future<void> _reload() async {
    try {
      final current = await DataService.getCurrentUser();
      final expectedUserId = current?.id.trim() ?? '';
      if (expectedUserId.isEmpty) {
        throw StateError('Für deine Anzeigen ist eine Anmeldung erforderlich.');
      }
      final items = await DataService.getItems();
      final rechecked = await DataService.getCurrentUser();
      if (rechecked?.id.trim() != expectedUserId) {
        throw StateError('Das angemeldete Konto hat sich geändert.');
      }
      if (!mounted) return;
      setState(() {
        _items = items.where((item) => item.ownerId == expectedUserId).toList();
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = const <Item>[];
        _loadError = 'Deine Anzeigen konnten nicht sicher geladen werden.';
      });
    }
  }

  Future<void> _changeStatus(Item item, String status) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final current = await DataService.getCurrentUser();
      if (current?.id != item.ownerId) {
        throw StateError('Die Anzeige gehört zu einem anderen Konto.');
      }
      await DataService.updateItemStatus(itemId: item.id, status: status);
      await _reload();
      if (_loadError != null) {
        throw StateError('Die Anzeige konnte nicht sicher neu geladen werden.');
      }
    } catch (_) {
      await _reload();
      if (mounted) {
        AppPopup.error(
          context,
          title: 'Änderung nicht gespeichert',
          message: 'Die Anzeige blieb unverändert. Prüfe deine Anmeldung und versuche es erneut.',
        );
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final visible = _applyBucket(_items);

    Widget chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BucketChip(label: l10n.t('Meine Anzeigen'), selected: _bucket == 'active', onTap: () => setState(() => _bucket = 'active')),
          const SizedBox(width: 8),
          _BucketChip(label: l10n.t('Anfragen'), selected: _bucket == 'requests', onTap: () => setState(() => _bucket = 'requests')),
          const SizedBox(width: 8),
          _BucketChip(label: l10n.t('in Vermietung'), selected: _bucket == 'paused', onTap: () => setState(() => _bucket = 'paused')),
          const SizedBox(width: 8),
          _BucketChip(label: l10n.t('für später gespeichert'), selected: _bucket == 'draft', onTap: () => setState(() => _bucket = 'draft')),
        ],
      ),
    );

    Widget content;
    if (_loadError != null) {
      content = _OwnProfileLoadFailure(
        message: _loadError!,
        onRetry: _reload,
      );
    } else if (visible.isEmpty) {
      content = Center(child: Text(l10n.t('Keine Anzeigen'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)));
    } else {
      content = GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 3 / 4),
        itemCount: visible.length,
        itemBuilder: (_, i) {
          final it = visible[i];
          String statusLabel = switch (it.status) { 'active' => 'Aktiv', 'paused' => 'Pausiert', 'ended' => 'Beendet', 'draft' => 'Entwurf', _ => 'Aktiv' };
          Color chipColor = switch (it.status) { 'active' => const Color(0x3322C55E), 'paused' => const Color(0x33F59E0B), 'ended' => const Color(0x33F43F5E), 'draft' => Colors.white.withValues(alpha: 0.10), _ => Colors.white.withValues(alpha: 0.10) };
          return InkWell(
            onTap: () => ItemDetailsOverlay.showFullPage(context, item: it, isOwnerPreview: true),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: AspectRatio(aspectRatio: 16 / 9, child: AppImage(url: it.photos.isNotEmpty ? it.photos.first : '', fit: BoxFit.cover))),
                Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text('${it.pricePerDay.toStringAsFixed(0)} €', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
                        const SizedBox(width: 4),
                        Text(context.watch<LocalizationController>().t('pro Tag'), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(8)), child: Text(statusLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white))),
                        const Spacer(),
                        PopupMenuButton<String>(
                          tooltip: 'Status ändern',
                          enabled: !_actionBusy,
                          onSelected: (v) => _changeStatus(it, v),
                          itemBuilder: (context) => [
                            if (it.status != 'active') const PopupMenuItem(value: 'active', child: Text('Aktivieren')),
                            if (it.status != 'paused') const PopupMenuItem(value: 'paused', child: Text('Pausieren')),
                            if (it.status != 'ended') const PopupMenuItem(value: 'ended', child: Text('Beenden')),
                            if (it.status == 'draft') const PopupMenuItem(value: 'active', child: Text('Veröffentlichen')),
                          ],
                          child: const Icon(Icons.more_vert, color: Colors.white70),
                        )
                      ])
                    ]))
              ]),
            ),
          );
        },
      );
    }

    return Column(children: [
      chips,
      Expanded(child: content),
    ]);
  }
}

class _BucketChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _BucketChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.w700)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      side: BorderSide(color: selected ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _InterestsTab extends StatefulWidget {
  final User? user;
  final ValueChanged<List<String>> onChanged;
  const _InterestsTab({required this.user, required this.onChanged});
  @override
  State<_InterestsTab> createState() => _InterestsTabState();
}

class _InterestsTabState extends State<_InterestsTab> {
  late List<String> _interests;
  final List<String> _allTags = const ['Fotografie', 'Camping', 'Werkzeuge', 'Elektronik', 'Fitness', 'Garten', 'Events', 'Gaming'];

  @override
  void initState() {
    super.initState();
    _interests = List.of(widget.user?.interests ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allTags.map((t) {
            final selected = _interests.contains(t);
            return FilterChip(
              label: Text(t, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
              selected: selected,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _interests.add(t);
                  } else {
                    _interests.remove(t);
                  }
                });
                widget.onChanged(_interests);
              },
            );
          }).toList()),
    );
  }
}

class _BookingsHistoryTab extends StatelessWidget {
  const _BookingsHistoryTab();
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final bookings = <Map<String, String>>[];
    if (bookings.isEmpty) {
      return Center(child: Text(l10n.t('Keine Historie'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final b = bookings[i];
        return Container(
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              AppImage(url: b['image']!, width: 72, height: 72, fit: BoxFit.cover, borderRadius: BorderRadius.circular(10)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b['title']!, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(b['dates']!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                Text(b['location']!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
              ]))
            ]),
          ),
        );
      },
    );
  }
}

class _ReviewsTab extends StatefulWidget {
  final String userId;
  final double avgRating;
  final int reviewCount;
  const _ReviewsTab({
    super.key,
    required this.userId,
    required this.avgRating,
    required this.reviewCount,
  });
  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab> {
  List<ReviewWithUser> _reviews = const [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _reviews = const [];
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final current = await DataService.getCurrentUser();
      if (current?.id != widget.userId) {
        throw StateError('Das angemeldete Konto hat sich geändert.');
      }
      final data = await DataService.getReviewSummariesForUser(widget.userId);
      final rechecked = await DataService.getCurrentUser();
      if (rechecked?.id != widget.userId) {
        throw StateError('Das angemeldete Konto hat sich geändert.');
      }
      if (!mounted) return;
      setState(() {
        _reviews = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reviews = const [];
        _loading = false;
        _loadError = 'Bewertungen konnten nicht sicher geladen werden.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            'Lokale Daten bleiben unverändert.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('own_review_retry'),
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Erneut laden'),
          ),
        ],
      );
    }

    final summary = ReviewMetricsService.calculateUserSummary(_reviews);
    final count = summary.reviewCount > 0 ? summary.reviewCount : widget.reviewCount;
    final double avg = summary.reviewCount > 0 ? summary.averageRating : widget.avgRating;

    if (_reviews.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Icon(Icons.star, color: Color(0xFFFB923C)),
            const SizedBox(width: 6),
            Text('${ReviewMetricsService.formatRatingValue(avg)} ($count)', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
          ]),
          const SizedBox(height: 12),
          Text('Keine Bewertung vorhanden.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const Icon(Icons.star, color: Color(0xFFFB923C)),
          const SizedBox(width: 6),
          Text('${ReviewMetricsService.formatRatingValue(avg)} ($count)', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
        ]),
        const SizedBox(height: 12),
        ..._reviews.map((entry) {
          final reviewer = entry.reviewer;
          final name = reviewer?.displayName ?? '—';
          final avatarUrl = reviewer?.photoURL;
          final city = reviewer?.city;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ListTile(
              leading: SitUserAvatar(url: avatarUrl, radius: 20),
              title: Text(name, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (city != null && city.isNotEmpty) Text('$city, Deutschland', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(entry.review.comment, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 16, color: Color(0xFFFB923C)),
                  const SizedBox(width: 4),
                  Text(ReviewMetricsService.formatRatingValue(entry.review.rating), style: theme.textTheme.bodySmall?.copyWith(color: Colors.white)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _AboutMeTab extends StatelessWidget {
  final User? user;
  final _UserMetrics metrics;
  final TextEditingController bioCtrl;
  final ValueChanged<String> onBioSaved;
  const _AboutMeTab({required this.user, required this.metrics, required this.bioCtrl, required this.onBioSaved});
  @override
  Widget build(BuildContext context) {
    final u = user;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SitUserAvatar(
            url: u?.photoURL,
            radius: 34,
            borderColor: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(u?.displayName ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
              const SizedBox(width: 6),
              Icon(
                (u?.isVerified ?? false) ? Icons.verified : Icons.verified_outlined,
                color: (u?.isVerified ?? false) ? const Color(0xFF22C55E) : Colors.white38,
                size: 18,
              ),
            ]),
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: (u?.languages ?? ['Deutsch']).map((l) => Chip(label: Text(l), labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white), backgroundColor: Colors.white.withValues(alpha: 0.10))).toList()),
          ])),
        ]),
        const SizedBox(height: 16),
        Text(context.watch<LocalizationController>().t('Kurzbeschreibung'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
          child: TextField(controller: bioCtrl, maxLines: 4, style: const TextStyle(color: Colors.white), decoration: InputDecoration(contentPadding: const EdgeInsets.all(12), hintText: context.watch<LocalizationController>().t('Erzähle etwas über dich…'), hintStyle: const TextStyle(color: Colors.white70), border: InputBorder.none)),
        ),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => onBioSaved(bioCtrl.text), child: Text(context.watch<LocalizationController>().t('Speichern')))),
        const SizedBox(height: 12),
        Text(context.watch<LocalizationController>().t('Leistung'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _MetricTile(title: context.watch<LocalizationController>().t('Ø Reaktionszeit'), value: metrics.responseTimeMinutes == null ? context.watch<LocalizationController>().t('Noch keine Daten') : '${metrics.responseTimeMinutes!.toStringAsFixed(0)} Min')),
          const SizedBox(width: 8),
          Expanded(child: _MetricTile(title: context.watch<LocalizationController>().t('Ø Storno-Rate'), value: metrics.cancellationRate == null ? context.watch<LocalizationController>().t('Noch keine Daten') : '${metrics.cancellationRate!.toStringAsFixed(1)}%')),
        ]),
      ]),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  const _MetricTile({required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
      ]),
    );
  }
}

class _UserMetrics {
  final double trustScore;
  final double? responseTimeMinutes;
  final double? cancellationRate;
  const _UserMetrics({required this.trustScore, required this.responseTimeMinutes, required this.cancellationRate});
}
