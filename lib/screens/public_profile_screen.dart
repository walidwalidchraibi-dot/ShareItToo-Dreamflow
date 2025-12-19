import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/models/review.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/widgets/item_card.dart';
import 'package:lendify/widgets/profile_header_card.dart';
import 'package:provider/provider.dart';

class PublicProfileScreen extends StatefulWidget {
  final String? userId;
  const PublicProfileScreen({super.key, this.userId});
  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  User? _user;
  List<Item> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = widget.userId != null ? await DataService.getUserById(widget.userId!) : await DataService.getCurrentUser();
    final items = await DataService.getItems();
    setState(() {
      _user = u;
      _items = items.where((e) => e.ownerId == u?.id).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final u = _user;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('Öffentliches Profil'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white))),
      body: SafeArea(
        child: u == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ProfileHeaderCard(user: u, listingsCount: _items.length),
                  const SizedBox(height: 12),
                  _ProfileQuickInfoLines(user: u, listingsCount: _items.length),
                  const SizedBox(height: 16),
                  if (u.showWork && (u.workTitle?.isNotEmpty ?? false)) _InfoTile(icon: Icons.work_outline, label: l10n.t('Beruf'), value: u.workTitle!),
                  if (u.showHobbies && (u.hobbies?.isNotEmpty ?? false)) _InfoTile(icon: Icons.interests, label: l10n.t('Hobbys'), value: u.hobbies!),
                  if (u.showHomeLocation && ((u.homeLocation?.isNotEmpty ?? false) || (u.city != null))) _InfoTile(icon: Icons.home_outlined, label: l10n.t('Wohnort'), value: u.homeLocation ?? '${u.city}${u.country != null ? ', ${u.country}' : ''}'),
                  if (u.showFavoriteSong && (u.favoriteSong?.isNotEmpty ?? false)) _InfoTile(icon: Icons.music_note_outlined, label: l10n.t('Lieblingssong'), value: u.favoriteSong!),
                  if (u.showBioPublic && (u.bio?.isNotEmpty ?? false)) _InfoTile(icon: Icons.info_outline, label: l10n.t('Über'), value: u.bio!),
                  const SizedBox(height: 16),
                  _ReviewsSection(user: u),
                  const SizedBox(height: 16),
                  if (_items.isNotEmpty) ...[
                    Text('Andere Anzeigen von ${u.displayName}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.90,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) => ItemCard(item: _items[i], compact: true),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/* class _HeaderCard extends StatelessWidget { // replaced by ProfileHeaderCard
  final User user; final int listingsCount;
  const _HeaderCard({required this.user, required this.listingsCount});
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      padding: const EdgeInsets.all(16),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Left: avatar, badge, name
          SizedBox(
            width: 140,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(children: [
                  CircleAvatar(radius: 36, backgroundImage: NetworkImage(user.photoURL ?? 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face')),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(4),
                      child: Icon(user.isVerified ? Icons.verified : Icons.verified_outlined, size: 16, color: user.isVerified ? const Color(0xFF22C55E) : Colors.black45),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(user.isVerified ? l10n.t('Verifiziert') : l10n.t('Nicht verifiziert'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          // Vertical divider centered and spanning intrinsic height
          const SizedBox(width: 12),
          VerticalDivider(width: 1, thickness: 1, color: Colors.white54.withValues(alpha: 0.15)),
          const SizedBox(width: 12),
          // Right: metrics (center vertically)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetricLine(label: l10n.t('Bewertung'), value: '${user.avgRating.toStringAsFixed(1)} ★'),
                  const SizedBox(height: 8),
                  _MetricLine(label: l10n.t('Buchungen'), value: _estimatedBookings(user).toString()),
                  const SizedBox(height: 8),
                  _MetricLine(label: l10n.t('Dabei seit'), value: _joinedMonthYear(user.createdAt)),
                  const SizedBox(height: 8),
                  _MetricLine(label: l10n.t('Anzeigen'), value: listingsCount.toString()),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  static String _joinedMonthYear(DateTime createdAt) {
    const monthsDe = ['Januar','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember'];
    final m = monthsDe[createdAt.month - 1];
    return '$m ${createdAt.year}';
  }

  static int _estimatedBookings(User u) {
    final est = (u.reviewCount * 1.3).clamp(0, 9999).toInt();
    return est;
  }
}

*/
 
class _MetricLine extends StatelessWidget {
  final String label; final String value;
  const _MetricLine({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70))),
      const SizedBox(width: 8),
      Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _ProfileQuickInfoLines extends StatelessWidget {
  final User user; final int listingsCount;
  const _ProfileQuickInfoLines({required this.user, required this.listingsCount});
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final responseTimeMin = 42; // mock
    final city = user.city ?? '-';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.schedule, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('${l10n.t('Durchschnittliche Reaktionszeit')}: ${responseTimeMin} Min', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)))
      ]),
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.home_outlined, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('${l10n.t('Wohnt in')}: $city', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)))
      ]),
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.apps_outage_rounded, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('${l10n.t('Gesamt Anzeigen bis jetzt')}: $listingsCount', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)))
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Icon(user.isVerified ? Icons.verified_user : Icons.gpp_maybe, color: user.isVerified ? const Color(0xFF22C55E) : Colors.white70, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(user.isVerified ? l10n.t('Identität verifiziert') : l10n.t('Identität nicht verifiziert'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)))
      ]),
    ]);
  }
}

class _Pill extends StatelessWidget {
  final String text; const _Pill({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.12))), child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)));
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      child: ListTile(leading: Icon(icon), title: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)), subtitle: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
    );
  }
}

class _ReviewsSection extends StatefulWidget {
  final User user; const _ReviewsSection({required this.user});
  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  List<ReviewWithUser> _reviews = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DataService.getReviewSummariesForUser(widget.user.id);
    if (!mounted) return;
    setState(() {
      _reviews = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final theme = Theme.of(context);

    if (_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('Bewertungen'), style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
          const SizedBox(height: 12),
          Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: theme.colorScheme.primary))),
        ],
      );
    }

    if (_reviews.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('Bewertungen'), style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          Text('Noch keine Bewertungen', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
        ],
      );
    }

    final preview = _reviews.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.t('Bewertungen'), style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
        const SizedBox(height: 8),
        ...preview.map((entry) {
          final reviewer = entry.reviewer;
          final name = reviewer?.displayName ?? '—';
          final avatarUrl = reviewer?.photoURL;
          final city = reviewer?.city;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?', style: const TextStyle(color: Colors.white))
                    : null,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFFB923C), size: 16),
                          const SizedBox(width: 4),
                          Text(entry.review.rating.toStringAsFixed(1), style: theme.textTheme.bodySmall?.copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (city != null && city.isNotEmpty)
                    Text('$city, Deutschland', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(entry.review.comment, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white)),
                ],
              ),
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _openAllReviews,
            child: Text(l10n.t('Alle Bewertungen ansehen')),
          ),
        ),
      ],
    );
  }

  Future<void> _openAllReviews() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.90),
      builder: (_) {
        return SafeArea(
          top: false,
          child: SizedBox.expand(
            child: Stack(
              children: [
                // Full-screen frosted dark background
                BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.black.withValues(alpha: 0.92)),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: StatefulBuilder(
                    builder: (context, setSheetState) {
                      // Always sort by rating (desc)
                      final list = List<ReviewWithUser>.from(_reviews)
                        ..sort((a, b) => b.review.rating.compareTo(a.review.rating));
                      final double avg = list.isEmpty
                          ? 0
                          : list.map((e) => e.review.rating).reduce((a, b) => a + b) / list.length;
                      final int count = list.length;
                      return Column(
                        children: [
                          // Close button
                          SizedBox(
                            height: 44,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                onPressed: () => Navigator.of(context).maybePop(),
                                icon: const Icon(Icons.close, color: Colors.white),
                              ),
                            ),
                          ),
                          // Summary header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.star, color: Color(0xFFFB923C)),
                                  const SizedBox(width: 8),
                                  Text(avg.toStringAsFixed(1), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 8),
                                  Text('· $count Bewertungen', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                                ]),
                              ),
                              const Spacer(),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final entry = list[i];
                                final reviewer = entry.reviewer;
                                final name = reviewer?.displayName ?? '—';
                                final avatarUrl = reviewer?.photoURL;
                                final city = reviewer?.city;
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                                        child: (avatarUrl == null || avatarUrl.isEmpty)
                                            ? Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?', style: const TextStyle(color: Colors.white))
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                              const Icon(Icons.star, color: Color(0xFFFB923C), size: 16),
                                              const SizedBox(width: 4),
                                              Text(entry.review.rating.toStringAsFixed(1), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
                                            ]),
                                            const SizedBox(height: 2),
                                            if (city != null && city.isNotEmpty)
                                              Text('$city, Deutschland', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                                            const SizedBox(height: 8),
                                            Text(entry.review.comment, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}