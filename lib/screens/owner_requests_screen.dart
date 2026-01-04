import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/models/user.dart' as model;
import 'package:lendify/services/data_service.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/screens/ongoing_owner_detail_screen.dart';
import 'package:lendify/widgets/review_prompt_sheet.dart';
import 'package:lendify/widgets/item_details_overlay.dart';

/// Owner-side requests hub: Tabs for Laufend, Kommend, Anfragen, Abgeschlossen
class OwnerRequestsScreen extends StatefulWidget {
  final int? initialTabIndex; // 0: Laufend, 1: Kommend, 2: Anfragen, 3: Abgeschlossen
  const OwnerRequestsScreen({super.key, this.initialTabIndex});

  @override
  State<OwnerRequestsScreen> createState() => _OwnerRequestsScreenState();
}

class _OwnerRequestsScreenState extends State<OwnerRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _ownerId;
  List<_OwnerEntry> _entries = const [];
  Timer? _ticker;
  final Map<String, Map<String, dynamic>?> _deliveryByItemId = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: (widget.initialTabIndex ?? 2).clamp(0, 3));
    _tabController.addListener(() {
      if (_tabController.index == 2 && _ownerId != null) {
        DataService.markOwnerRequestsSeen(_ownerId!);
      }
      if (mounted) setState(() {}); // refresh app bar title on tab change
    });
    _load();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!mounted) return;
      await _maybeShowReviewReminder();
      setState(() {});
    });
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
    final owner = await DataService.getCurrentUser();
    if (owner == null) return;
    final reminder = await DataService.takeDueReviewReminder(reviewerId: owner.id);
    if (!mounted || reminder == null) return;
    _showingReminder = true;
    try {
      final String requestId = (reminder['requestId'] ?? '').toString();
      final String itemId = (reminder['itemId'] ?? '').toString();
      final String reviewedUserId = (reminder['reviewedUserId'] ?? '').toString();
      final String direction = (reminder['direction'] ?? 'owner_to_renter').toString();
      await AppPopup.show(
        context,
        icon: Icons.star_rate_outlined,
        title: 'Zeit für eine Bewertung',
        message: 'Magst du die Anmietung bewerten?',
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
                reviewerId: owner.id,
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
    final owner = await DataService.getCurrentUser();
    if (owner == null) return;
    _ownerId = owner.id;
    final requests = await DataService.getRentalRequestsForOwner(owner.id);
    final items = await DataService.getItems();
    final users = await DataService.getUsers();
    final byItem = {for (final it in items) it.id: it};
    final byUser = {for (final u in users) u.id: u};
    // Load delivery selection per item (demo persistence)
    for (final it in items) {
      _deliveryByItemId[it.id] = await DataService.getSavedDeliverySelection(it.id);
    }
    final list = <_OwnerEntry>[];
    for (final r in requests) {
      final it = byItem[r.itemId];
      final renter = byUser[r.renterId];
      if (it == null || renter == null) continue;
      list.add(_OwnerEntry(r: r, item: it, renter: renter));
    }
    setState(() => _entries = list);
    if (_tabController.index == 2 && _ownerId != null) {
      await DataService.markOwnerRequestsSeen(_ownerId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabsStyle = Theme.of(context).textTheme.bodySmall;
    String title;
    switch (_tabController.index) {
      case 0:
        title = 'Laufende Anmietungen';
        break;
      case 1:
        title = 'Kommende Anmietungen';
        break;
      case 2:
        title = 'Mietanfragen';
        break;
      case 3:
      default:
        title = 'Abgeschlossene Anmietungen';
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
        title: Text(title),
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
          tabs: const [
            Tab(text: 'Laufend'),
            Tab(text: 'Kommend'),
            Tab(text: 'Mietanfragen'),
            Tab(text: 'Abgeschlossen'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList('ongoing'),
          _buildList('upcoming'),
          _buildList('requests'),
          _buildList('completed'),
        ],
      ),
    );
  }

  Widget _buildList(String target) {
    final maps = _entries.where((e) => _effectiveCategory(e) == target).toList();
    if (maps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Keine Einträge', style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    final bool _isRequestsTab = target == 'requests';
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: maps.length,
      itemBuilder: (context, index) {
        final e = maps[index];
        final booking = _toCardMap(e);
        final (start, end) = (_parseDateTime(e.r.start), _parseDateTime(e.r.end));
        final effective = _effectiveCategory(e);
        final titleForCategory = _titleForCategory(effective);
        final chip = _buildStatusChipForCard(effective, start, end, e);
        final inlineAction = _isRequestsTab ? null : _buildInlineAction(effective, e);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OngoingOwnerDetailScreen(requestId: e.r.id, titleOverride: titleForCategory)));
              if (!mounted) return;
              await _load();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(width: 80, height: 80, child: _ThumbnailWithSkeleton(url: booking['image'] as String?)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 78,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(booking['title'] ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white, height: 1.1)),
                                    const SizedBox(height: 1),
                                    Text(booking['dates'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.1)),
                                    const SizedBox(height: 1),
                                    Text(booking['renter'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.1)),
                                    const SizedBox(height: 2),
                                    if (effective == 'requests' || effective == 'upcoming' || effective == 'ongoing')
                                      _privacyHintForOwner(e.item.id),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!_isRequestsTab)
                                Text(booking['total'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16), textAlign: TextAlign.right),
                            ],
                          ),
                           Row(children: [
                            chip,
                            if (inlineAction != null) ...[
                              const SizedBox(width: 4),
                              // Prevent right overflow on small widths: horizontally scrollable action row
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Align(alignment: Alignment.centerLeft, child: inlineAction),
                                ),
                              ),
                            ],
                          ])
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Map<String, String> _toCardMap(_OwnerEntry e) {
    String fmt(DateTime d) {
      const months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
      final mm = months[d.month - 1];
      final dd = d.day.toString().padLeft(2, '0');
      return '$dd. $mm';
    }
    final r = e.r; final it = e.item; final renter = e.renter;
    final breakdown = DataService.priceBreakdownForRequest(item: it, req: r);
    final payout = breakdown.payoutOwner.clamp(0.0, double.infinity);
    return {
      'title': it.title,
      'dates': '${fmt(r.start)} – ${fmt(r.end)}',
      'image': it.photos.isNotEmpty ? it.photos.first : '',
      // Show only the payout value for owner lists
      'total': '${payout.round()} €',
      'renter': renter.displayName,
    };
  }

  // Strict status-driven categorization (no auto-advance by time)
  // Business rules (mirror renter view and detail page):
  // - pending   → requests (Mietanfragen)
  // - accepted  → upcoming (Kommend)
  // - running   → ongoing (Laufend; only after bestätigte Übergabe)
  // - completed/cancelled/declined → completed (Abgeschlossen)
  String _effectiveCategory(_OwnerEntry e) {
    final s = (e.r.status).toLowerCase();
    if (s == 'pending') return 'requests';
    if (s == 'accepted') return 'upcoming';
    if (s == 'running') return 'ongoing';
    if (s == 'completed' || s == 'cancelled' || s == 'declined') return 'completed';
    // Fallback to upcoming to avoid misrouting unknown states
    return 'upcoming';
  }

  String _titleForCategory(String category) {
    switch (category) {
      case 'upcoming':
        return 'Kommende Anmietung';
      case 'requests':
        return 'Mietanfrage';
      case 'completed':
        return 'Abgeschlossene Anmietung';
      case 'ongoing':
      default:
        return 'Laufende Anmietung';
    }
  }

  // Tiny privacy hint: only when the owner is the traveling party (delivers or picks up)
  Widget _privacyHintForOwner(String itemId) {
    final sel = _deliveryByItemId[itemId];
    final bool ownerDelivers = (sel?['hinweg'] == true);
    final bool ownerPicksUp = (sel?['rueckweg'] == true);
    final bool ownerTravels = ownerDelivers || ownerPicksUp;
    if (!ownerTravels) return const SizedBox.shrink();
    return Row(children: const [
      Icon(Icons.privacy_tip_outlined, size: 14, color: Colors.white70),
      SizedBox(width: 4),
      Expanded(child: Text('Adresse geschützt • Karte + Abhol-/Rückgabeort nur für dich sichtbar', style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.05), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _buildStatusChipForCard(String category, DateTime start, DateTime end, _OwnerEntry e) {
    String label; Color color;
    switch (category) {
      case 'upcoming':
        final diff = start.difference(DateTime.now());
        // Do not show a return countdown for upcoming; keep a neutral label
        label = 'Kommend';
        color = const Color(0xFF0EA5E9);
        break;
      case 'ongoing':
        label = 'Laufend bis ${_formatGermanDateTime(end)}';
        color = const Color(0xFFFB923C);
        break;
      case 'requests':
        // Owner shouldn't see a passive "waiting" state. Indicate action required.
        label = 'Anfrage';
        color = Colors.grey;
        break;
      case 'completed':
        final s = e.r.status;
        final cancelled = s == 'cancelled' || s == 'declined';
        // Special copy: if renter withdrew (cancelledBy == 'renter'), show "Zurückgezogen"
        if (s == 'cancelled' && (e.r.cancelledBy == 'renter')) {
          label = 'Zurückgezogen';
          color = const Color(0xFFF43F5E);
        } else {
          label = cancelled ? 'Storniert' : 'Abgeschlossen';
          color = cancelled ? const Color(0xFFF43F5E) : const Color(0xFF22C55E);
        }
        break;
      default:
        label = '—';
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, height: 1.05), maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget? _buildInlineAction(String category, _OwnerEntry e) {
    switch (category) {
      case 'requests':
        return Row(mainAxisSize: MainAxisSize.min, children: [
          // Swap order: Akzeptieren first. Same design as Ablehnen, only text in green.
            _TinyTextButton(
              icon: Icons.check_circle_outline,
              label: 'Akzeptieren',
              color: const Color(0xFF22C55E),
              onPressed: () async {
                await DataService.updateRentalRequestStatus(requestId: e.r.id, status: 'accepted');
                if (!mounted) return;
                await _load();
                // Success popup (keeps overlay on top for 10 seconds, does not auto-navigate underlying page)
                // ignore: unawaited_futures
                AppPopup.show(
                  context,
                  icon: Icons.check_circle_outline,
                  title: 'Du hast die Anfrage akzeptiert.',
                  message: 'Du findest diese Anmietung jetzt unter „Kommende Anmietungen“.',
                  barrierDismissible: false,
                  showCloseIcon: false,
                  plainCloseIcon: true,
                  autoCloseAfter: const Duration(seconds: 10),
                  actions: [
                    FilledButton(
                      onPressed: () {
                        // Close the popup then open the specific upcoming rental detail
                        Navigator.of(context, rootNavigator: true).maybePop();
                        Future.delayed(const Duration(milliseconds: 120), () async {
                          if (!mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OngoingOwnerDetailScreen(
                                requestId: e.r.id,
                                titleOverride: 'Kommende Anmietung',
                              ),
                            ),
                          );
                          if (!mounted) return;
                          await _load();
                        });
                      },
                      child: const Text('Zur kommenden Anmietung'),
                    ),
                  ],
                );
              },
            ),
          const SizedBox(width: 6),
          _TinyTextButton(
            icon: Icons.cancel_outlined,
            label: 'Ablehnen',
            color: Theme.of(context).colorScheme.error,
            onPressed: () async {
              // Confirmation popup with app design before declining
              await AppPopup.show(
                context,
                icon: Icons.block,
                title: 'Anfrage ablehnen?',
                message: 'Bist du sicher? Der Mieter wird informiert.',
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
                  OutlinedButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
                    child: const Text('Abbrechen'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      Navigator.of(context, rootNavigator: true).maybePop();
                      await DataService.updateRentalRequestStatus(requestId: e.r.id, status: 'declined');
                      if (!mounted) return;
                      await _load();
                      // Auto-close after 3 seconds
                      Future.delayed(const Duration(seconds: 3), () {
                        if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
                      });
                      // Result popup
                      // ignore: unawaited_futures
                      AppPopup.show(
                        context,
                        icon: Icons.cancel_outlined,
                        title: 'Du hast die Anfrage abgelehnt.',
                        message: 'Du findest sie jetzt unter „Abgeschlossene Anmietungen“.',
                        barrierDismissible: true,
                        showCloseIcon: false,
                        plainCloseIcon: true,
                        autoCloseAfter: const Duration(seconds: 15),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
                            child: const Text('OK'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(context, rootNavigator: true).maybePop();
                              _tabController.animateTo(3);
                            },
                            child: const Text('Zu „Abgeschlossene Anmietungen“'),
                          ),
                        ],
                      );
                    },
                    child: const Text('Ablehnen'),
                  ),
                ],
              );
            },
          ),
        ]);
      case 'completed':
        // Show a small inline "Bewerten" action for completed rentals (not for cancelled/declined)
        if (e.r.status == 'completed') {
          return _TinyTextButton(
            icon: Icons.star_rate_outlined,
            label: 'Bewerten',
            onPressed: () async {
              final owner = await DataService.getCurrentUser();
              if (owner == null) return;
              final ok = await ReviewPromptSheet.show(
                context,
                requestId: e.r.id,
                itemId: e.item.id,
                reviewerId: owner.id,
                reviewedUserId: e.renter.id,
                direction: 'owner_to_renter',
              );
              if (ok == true && mounted) {
                await AppPopup.toast(context, icon: Icons.star_rate_outlined, title: 'Danke für deine Bewertung!');
                if (mounted) {
                  await ItemDetailsOverlay.showFullPage(context, item: e.item);
                }
              }
            },
          );
        }
        return null;
      default:
        return null;
    }
  }

  String _formatTwoUnits(Duration d) {
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

  DateTime _parseDateTime(DateTime d) => d; // stored as real DateTime already
}

class _OwnerEntry {
  final RentalRequest r; final Item item; final model.User renter;
  const _OwnerEntry({required this.r, required this.item, required this.renter});
}

class _TinyTextButton extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onPressed; final Color? color; final Color? iconColor;
  const _TinyTextButton({required this.icon, required this.label, required this.onPressed, this.color, this.iconColor});
  @override
  Widget build(BuildContext context) {
    final fg = color ?? Theme.of(context).colorScheme.primary;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 24),
        visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: iconColor ?? fg),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: fg)),
      ]),
    );
  }
}

class _ThumbnailWithSkeleton extends StatefulWidget {
  final String? url; const _ThumbnailWithSkeleton({required this.url});
  @override
  State<_ThumbnailWithSkeleton> createState() => _ThumbnailWithSkeletonState();
}

class _ThumbnailWithSkeletonState extends State<_ThumbnailWithSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller; bool _done = false;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    if (url == null || url.isEmpty) return _skeleton();
    return Image.network(url, fit: BoxFit.cover, loadingBuilder: (c, child, progress) {
      if (progress == null) { _done = true; return child; }
      return _skeleton();
    }, errorBuilder: (_, __, ___) => _skeleton());
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
