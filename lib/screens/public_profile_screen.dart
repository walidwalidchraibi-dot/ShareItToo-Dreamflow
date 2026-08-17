import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/models/review.dart';
import 'package:lendify/models/multi_criteria_review.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/app_link_service.dart';
import 'package:lendify/services/review_metrics_service.dart';
import 'package:lendify/services/blocked_users_service.dart';
import 'package:lendify/services/profile_ecosystem_service.dart';
import 'package:lendify/screens/message_thread_screen.dart';
import 'package:lendify/screens/support_flow_screen.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/widgets/item_card.dart';
import 'package:lendify/widgets/profile_header_card.dart';
import 'package:lendify/widgets/user_avatar.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/widgets/rating_badge.dart';
import 'package:provider/provider.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/navigation/main_nav_controller.dart';
import 'package:lendify/navigation/main_navigation.dart';

List<String> buildPublicProfileMenuActions({
  required bool isOwnProfile,
  required bool isOwnPreview,
}) {
  if (isOwnProfile || isOwnPreview) {
    return const ['share_profile'];
  }
  return const ['report_problem', 'share_profile', 'block_user'];
}

const String publicProfileBioSectionLabel = 'Über mich';
const IconData publicProfileBioSectionIcon = Icons.person_outline;
const int publicProfileReviewPreviewMaxLines = 3;
const String publicProfileReviewAuthorPrefix = 'Bewertung von';
const String publicProfileReviewItemPrefix = 'zu';

String buildPublicProfileReviewAuthorLine(String reviewerName) =>
    '$publicProfileReviewAuthorPrefix $reviewerName';

String buildPublicProfileReviewItemLine(String itemTitle) =>
    '$publicProfileReviewItemPrefix $itemTitle';

String publicProfileReviewCriterionLabel(String key) {
  switch (key) {
    case 'communication':
      return 'Kommunikation';
    case 'reliability':
      return 'Zuverlässigkeit';
    case 'article_as_described':
    case 'description_accuracy':
      return 'Artikel wie beschrieben';
    case 'handover_return':
    case 'condition_dropoff':
    case 'condition_return':
    case 'process':
      return 'Übergabe & Rückgabe';
    default:
      return key;
  }
}

class PublicProfileCriterionAggregate {
  final String key;
  final double average;
  final int count;

  const PublicProfileCriterionAggregate({
    required this.key,
    required this.average,
    required this.count,
  });
}

String formatPublicProfileRatingValue(double value) =>
    ReviewMetricsService.formatRatingValue(value);

List<ReviewWithUser> buildAllPublicProfileReviews(
        List<ReviewWithUser> reviews) =>
    ReviewMetricsService.calculateUserSummary(reviews).reviews;

List<PublicProfileCriterionAggregate> buildPublicProfileCriterionAggregates(
  List<ReviewWithUser> reviews,
) {
  final summary = ReviewMetricsService.calculateUserSummary(reviews);
  return [
    for (final aggregate in summary.criterionAverages)
      PublicProfileCriterionAggregate(
        key: aggregate.key,
        average: aggregate.average,
        count: aggregate.count,
      ),
  ];
}

enum PublicProfileBlockFlowOutcome {
  cancelled,
  blocked,
  persistFailed,
}

Future<T?> showCenteredPublicProfileBlockDialog<T>(
  BuildContext context, {
  required IconData icon,
  required String title,
  required Widget body,
  bool barrierDismissible = false,
  bool showCloseIcon = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: title,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim, secondaryAnim) {
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Material(
                    color: Colors.transparent,
                    child: _PublicProfileBlockDialogCard(
                      icon: icon,
                      title: title,
                      body: body,
                      showCloseIcon: showCloseIcon,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

class _PublicProfileBlockDialogCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget body;
  final bool showCloseIcon;

  const _PublicProfileBlockDialogCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.showCloseIcon,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    final background = Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.60)
        : AppTheme.surfacePrimary(context);
    final titleColor = AppTheme.textPrimary(context);
    final secondaryColor = AppTheme.textSecondary(context);
    final borderClr = Theme.of(context).colorScheme.onSurface.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.10);
    final danger = Theme.of(context).colorScheme.error;

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: Border.all(color: borderClr),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.16),
                  ),
                  child: Icon(icon,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (showCloseIcon)
                  InkResponse(
                    onTap: () =>
                        Navigator.of(context, rootNavigator: true).maybePop(),
                    radius: 18,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: danger,
                        boxShadow: [
                          BoxShadow(
                            color: danger.withValues(alpha: 0.35),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 30),
              ],
            ),
            const SizedBox(height: 12),
            DefaultTextStyle(
              style: TextStyle(color: secondaryColor),
              child: body,
            ),
          ],
        ),
      ),
    );
  }

}

Future<bool?> showPublicProfileBlockConfirmationDialog(
  BuildContext context, {
  required String displayName,
}) {
  return showCenteredPublicProfileBlockDialog<bool>(
    context,
    icon: Icons.block_outlined,
    title: '$displayName blockieren?',
    barrierDismissible: false,
    showCloseIcon: true,
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Solange du $displayName blockiert hast, werden dir keine öffentlichen Anzeigen oder Profile dieses Nutzers angezeigt.',
          style:
              TextStyle(color: AppTheme.textSecondary(context), height: 1.45),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(false),
                child: const Text('Abbrechen'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(true),
                child: const Text('Blockieren'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> showPublicProfileBlockSuccessDialog(
  BuildContext context, {
  required String displayName,
}) {
  return showCenteredPublicProfileBlockDialog<void>(
    context,
    icon: Icons.block,
    title: 'Du hast $displayName blockiert.',
    barrierDismissible: false,
    showCloseIcon: true,
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Solange du $displayName blockiert hast, werden dir keine öffentlichen Anzeigen oder Profile dieses Nutzers angezeigt.',
          style:
              TextStyle(color: AppTheme.textSecondary(context), height: 1.45),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).maybePop(),
            child: const Text('Zu Erkunden'),
          ),
        ),
      ],
    ),
  );
}

Future<void> navigateToExploreAfterBlocking(BuildContext context) async {
  context.read<MainNavController>().setIndex(0);
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const MainNavigation(initialIndex: 0)),
    (route) => false,
  );
}

Future<PublicProfileBlockFlowOutcome> runPublicProfileBlockFlow(
  BuildContext context, {
  required String displayName,
  required String targetUserId,
  Future<ActionGuardResult> Function(String otherUserId)? canBlockUser,
  Future<void> Function(String userId)? blockUser,
  Future<bool> Function(String userId)? isBlocked,
  Future<void> Function(BuildContext context)? navigateToExplore,
}) async {
  final guardCheck = canBlockUser ??
      (otherUserId) =>
          ProfileEcosystemService.canBlockUser(otherUserId: otherUserId);
  final persistBlock = blockUser ?? BlockedUsersService.blockUser;
  final blockedCheck = isBlocked ?? BlockedUsersService.isBlocked;
  final navigate = navigateToExplore ?? navigateToExploreAfterBlocking;

  final guard = await guardCheck(targetUserId);
  if (!context.mounted) return PublicProfileBlockFlowOutcome.cancelled;
  if (!guard.allowed) {
    await AppPopup.show(
      context,
      icon: Icons.block_outlined,
      backgroundColor:
          AppTheme.isDark(context) ? null : AppTheme.surfacePrimary(context),
      borderColor:
          AppTheme.isDark(context) ? null : AppTheme.glassStroke(context),
      title: 'Du kannst $displayName im Moment nicht blockieren.',
      message: '${guard.reason}\n\nNächster Schritt: ${guard.actionLabel}',
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Schließen'),
        ),
      ],
    );
    return PublicProfileBlockFlowOutcome.cancelled;
  }

  final confirmed = await showPublicProfileBlockConfirmationDialog(
    context,
    displayName: displayName,
  );
  if (!context.mounted || confirmed != true) {
    return PublicProfileBlockFlowOutcome.cancelled;
  }

  await persistBlock(targetUserId);
  final persisted = await blockedCheck(targetUserId);
  if (!context.mounted || !persisted) {
    return PublicProfileBlockFlowOutcome.persistFailed;
  }

  await showPublicProfileBlockSuccessDialog(
    context,
    displayName: displayName,
  );
  if (!context.mounted) return PublicProfileBlockFlowOutcome.blocked;
  await navigate(context);
  return PublicProfileBlockFlowOutcome.blocked;
}

class PublicProfileScreen extends StatefulWidget {
  final String? userId;
  final User? previewUser;
  final bool isOwnPreview;
  final String appBarTitle;
  const PublicProfileScreen({
    super.key,
    this.userId,
    this.previewUser,
    this.isOwnPreview = false,
    this.appBarTitle = 'Öffentliches Profil',
  });
  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  User? _user;
  List<Item> _items = [];
  bool _redirectingBlockedProfile = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _profileUserId =>
      _user?.id ?? widget.previewUser?.id ?? widget.userId;

  bool get _isOwnProfile =>
      _viewerId != null &&
      _profileUserId != null &&
      _viewerId == _profileUserId;

  String? _viewerId;

  Future<void> _load() async {
    final u = widget.previewUser ??
        (widget.userId != null
            ? await DataService.getUserById(widget.userId!)
            : await DataService.getCurrentUser());
    final items = await DataService.getItems();
    final viewer = await DataService.getCurrentUser();
    final profileGuard = await ProfileEcosystemService.canViewPublicProfile(
      profileUserId: u?.id,
      currentUserId: viewer?.id,
    );
    if (!mounted) return;
    if (!widget.isOwnPreview && !profileGuard.allowed) {
      if (!_redirectingBlockedProfile) {
        _redirectingBlockedProfile = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await AppPopup.toast(
            context,
            icon: Icons.block,
            title: 'Profil blockiert',
            message: profileGuard.reason,
          );
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true)
              .popUntil((route) => route.isFirst);
        });
      }
      setState(() {
        _user = u;
        _viewerId = viewer?.id;
        _items = const [];
      });
      return;
    }
    final ownerItems = items.where((e) => e.ownerId == u?.id).toList();
    final visibleItems = widget.isOwnPreview
        ? ownerItems
            .where(ProfileEcosystemService.isPubliclyVisibleItem)
            .toList()
        : await ProfileEcosystemService.filterVisiblePublicItems(ownerItems);
    if (!mounted) return;
    setState(() {
      _user = u;
      _viewerId = viewer?.id;
      _items = visibleItems;
    });
  }

  Future<void> _openProfileSupportFlow(String issueType) async {
    final u = _user;
    final current = await DataService.getCurrentUser();
    if (u == null || current == null || !mounted) return;
    final flowContext = SupportFlowContext(
      itemTitle: u.displayName,
      itemId: 'profile:${u.id}',
      requestId: 'profile:${u.id}',
      bookingStatus: 'profile',
      source: SupportFlowSource.bookingDetail,
      role: current.id == u.id ? SupportFlowRole.owner : SupportFlowRole.renter,
      otherUserName: u.displayName,
      otherUserImageUrl: u.photoURL,
    );
    final result = await Navigator.of(context).push<SupportFlowResult?>(
      MaterialPageRoute(
          builder: (_) => SupportFlowScreen(context: flowContext)),
    );
    if (result == null || !mounted) return;
    final supportThread =
        await DataService.createSupportThread(userId: current.id);
    if (supportThread == null) return;
    final descText = result.userDescription.isNotEmpty
        ? '\n\nBeschreibung:\n${result.userDescription}'
        : '';
    await DataService.addSystemMessageToThread(
      threadId: supportThread.id,
      text:
          'Support-Fall eröffnet: ${result.mainCategoryLabel} · Profil ${u.displayName}\n📋 Support-Anfrage zu Profil: ${u.displayName}\nReferenz: profile:${u.id}\nTyp: $issueType\nKategorie: ${result.mainCategoryLabel}\nUnterkategorie: ${result.subCategory}$descText',
    );
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MessageThreadScreen(
            threadId: supportThread.id,
            participantName: 'SIT Support',
            itemTitle: 'Support')));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final u = _user;
    final displayName = u?.displayName ?? 'Nutzer';
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Zurück',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
            widget.appBarTitle == 'Öffentliches Profil'
                ? l10n.t('Öffentliches Profil')
                : widget.appBarTitle,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.textPrimary(context))),
        actions: [
          if (u != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              color: AppTheme.surfacePrimary(context),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppTheme.glassStroke(context)),
              ),
              onSelected: (value) async {
                if (value == 'report_problem') {
                  await _openProfileSupportFlow('Profil melden');
                }
                if (value == 'share_profile') {
                  final link = AppLinkBuilder.profile(u.id).toString();
                  await Clipboard.setData(ClipboardData(text: link));
                  if (!mounted) return;
                  AppPopup.toast(context,
                      icon: Icons.link, title: l10n.t('Profil-Link kopiert'));
                }
                if (value == 'block_user') {
                  final targetUserId = u.id;
                  if (targetUserId.isEmpty) return;
                  await runPublicProfileBlockFlow(
                    context,
                    displayName: displayName,
                    targetUserId: targetUserId,
                  );
                }
              },
              itemBuilder: (context) {
                final actions = buildPublicProfileMenuActions(
                  isOwnProfile: _isOwnProfile,
                  isOwnPreview: widget.isOwnPreview,
                );
                return [
                  if (actions.contains('report_problem'))
                    PopupMenuItem(
                      value: 'report_problem',
                      child: Text('Profil melden',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  if (actions.contains('share_profile'))
                    PopupMenuItem(
                      value: 'share_profile',
                      child: Text('Profil teilen',
                          style:
                              TextStyle(color: AppTheme.textPrimary(context))),
                    ),
                  if (actions.contains('block_user'))
                    PopupMenuItem(
                      value: 'block_user',
                      child: Text('$displayName blockieren',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                ];
              },
            ),
        ],
      ),
      body: SafeArea(
        child: u == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ProfileHeaderCard(user: u, listingsCount: _items.length),
                  const SizedBox(height: 12),
                  _TrustAndSafetySection(user: u),
                  const SizedBox(height: 16),
                  if (u.showWork && (u.workTitle?.isNotEmpty ?? false))
                    _InfoTile(
                        icon: Icons.work_outline,
                        label: l10n.t('Beruf'),
                        value: u.workTitle!),
                  if (u.showHobbies && (u.hobbies?.isNotEmpty ?? false))
                    _InfoTile(
                        icon: Icons.interests,
                        label: l10n.t('Hobbys'),
                        value: u.hobbies!),
                  if (u.showFavoriteSong &&
                      (u.favoriteSong?.isNotEmpty ?? false))
                    _InfoTile(
                        icon: Icons.music_note_outlined,
                        label: l10n.t('Lieblingssong'),
                        value: u.favoriteSong!),
                  if (u.showBioPublic && (u.bio?.isNotEmpty ?? false))
                    _InfoTile(
                        icon: Icons.info_outline,
                        label: l10n.t('Über'),
                        value: u.bio!),
                  if (u.showLanguagesPublic && u.languages.isNotEmpty)
                    _TagInfoTile(
                      icon: Icons.translate,
                      label: l10n.t('Sprachen'),
                      values: u.languages,
                    ),
                  if (u.showInterestsPublic && u.interests.isNotEmpty)
                    _TagInfoTile(
                      icon: Icons.interests_outlined,
                      label: l10n.t('Interessen'),
                      values: u.interests,
                    ),
                  const SizedBox(height: 16),
                  _ReviewsSection(user: u),
                  const SizedBox(height: 16),
                  if (_items.isNotEmpty) ...[
                    Text('Anzeigen von ${u.displayName}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppTheme.textPrimary(context))),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio:
                            ItemCard.recommendedGridChildAspectRatio(context,
                                    compact: true) +
                                0.08,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) => widget.isOwnPreview
                          ? IgnorePointer(
                              child: ItemCard(item: _items[i], compact: true),
                            )
                          : ItemCard(item: _items[i], compact: true),
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
      decoration: BoxDecoration(color: AppTheme.isDark(context) ? Colors.black.withValues(alpha: 0.20) : AppTheme.surfacePrimary(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.glassStroke(context)), boxShadow: AppTheme.cardShadow(context)),
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
                  SitUserAvatar(
                    url: user.photoURL ?? 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
                    radius: 36,
                    borderColor: AppTheme.glassStroke(context),
                  ),
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
                Text(user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary(context))),
                const SizedBox(height: 4),
                Text(user.isVerified ? l10n.t('Verifiziert') : l10n.t('Nicht verifiziert'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary(context))),
              ],
            ),
          ),
          // Vertical divider centered and spanning intrinsic height
          const SizedBox(width: 12),
          VerticalDivider(width: 1, thickness: 1, color: AppTheme.glassStroke(context)),
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

class PublicProfileReviewDetailsInline extends StatelessWidget {
  final List<ReviewCriterion> criteria;

  const PublicProfileReviewDetailsInline({
    super.key,
    required this.criteria,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bewertungsdetails',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary(context),
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        if (criteria.isEmpty)
          Text(
            'Für diese Bewertung wurden keine einzelnen Kriterien gespeichert.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary(context),
                  height: 1.45,
                ),
          )
        else
          Column(
            children: criteria.map<Widget>((criterion) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSecondary(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.glassStroke(context)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            publicProfileReviewCriterionLabel(criterion.key),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.textPrimary(context),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if ((criterion.note?.trim().isNotEmpty ?? false)) ...[
                            const SizedBox(height: 4),
                            Text(
                              criterion.note!.trim(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.textSecondary(context),
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${criterion.stars.toStringAsFixed(1).replaceAll('.0', ',0')} / 5',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textPrimary(context),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (index) {
                            return Icon(
                              index < criterion.stars
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 14,
                              color: const Color(0xFFFB923C),
                            );
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class PublicProfileCompactReviewCard extends StatelessWidget {
  final String reviewerName;
  final String? avatarUrl;
  final String? itemImageUrl;
  final String itemTitle;
  final String reviewComment;
  final double rating;
  final VoidCallback onTap;

  const PublicProfileCompactReviewCard({
    super.key,
    required this.reviewerName,
    required this.avatarUrl,
    required this.itemImageUrl,
    required this.itemTitle,
    required this.reviewComment,
    required this.rating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.isDark(context)
                ? Colors.black.withValues(alpha: 0.20)
                : AppTheme.surfacePrimary(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.glassStroke(context)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PublicProfileReviewArtwork(
                itemImageUrl: itemImageUrl,
                avatarUrl: avatarUrl,
                rating: rating,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buildPublicProfileReviewAuthorLine(reviewerName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimary(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      buildPublicProfileReviewItemLine(itemTitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (reviewComment.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        reviewComment,
                        maxLines: publicProfileReviewPreviewMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary(context),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicProfileReviewArtwork extends StatelessWidget {
  final String? itemImageUrl;
  final String? avatarUrl;
  final double rating;

  const _PublicProfileReviewArtwork({
    required this.itemImageUrl,
    required this.avatarUrl,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.surfaceSecondary(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.glassStroke(context)),
            ),
            clipBehavior: Clip.antiAlias,
            child: itemImageUrl != null
                ? AppImage(
                    url: itemImageUrl!,
                    fit: BoxFit.cover,
                    fallback: Icon(
                      Icons.inventory_2_outlined,
                      color: AppTheme.textSecondary(context),
                      size: 22,
                    ),
                  )
                : Icon(
                    Icons.inventory_2_outlined,
                    color: AppTheme.textSecondary(context),
                    size: 22,
                  ),
          ),
          Positioned(
            top: -4,
            left: -4,
            child: SitUserAvatar(
              url: avatarUrl,
              radius: 16,
              borderColor: AppTheme.surfacePrimary(context),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: RatingBadge(
              rating: rating,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustAndSafetySection extends StatelessWidget {
  final User user;
  const _TrustAndSafetySection({required this.user});

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? Colors.black.withValues(alpha: 0.20)
            : AppTheme.surfacePrimary(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassStroke(context)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('Vertrauen & Sicherheit'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: AppTheme.textPrimary(context))),
          const SizedBox(height: 10),
          _TrustRow(
            icon: Icons.verified_user,
            label: l10n.t('Identität'),
            value: user.isVerified
                ? l10n.t('Verifiziert')
                : l10n.t('Nicht verifiziert'),
            isPositive: user.isVerified,
          ),
          const SizedBox(height: 10),
          _TrustRow(
            icon: Icons.phone_outlined,
            label: l10n.t('Telefon'),
            value: user.phoneVerified
                ? l10n.t('Verifiziert')
                : l10n.t('Nicht verifiziert'),
            isPositive: user.phoneVerified,
          ),
          const SizedBox(height: 10),
          _TrustRow(
            icon: Icons.alternate_email,
            label: l10n.t('E-Mail'),
            value: user.emailVerified
                ? l10n.t('Verifiziert')
                : l10n.t('Nicht verifiziert'),
            isPositive: user.emailVerified,
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isPositive;

  const _TrustRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary(context), size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.textPrimary(context)))),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSecondary(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.glassStroke(context)),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isPositive
                  ? const Color(0xFF22C55E)
                  : AppTheme.textSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: AppTheme.surfaceSecondary(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.glassStroke(context))),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textPrimary(context))));
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: AppTheme.isDark(context)
              ? Colors.black.withValues(alpha: 0.20)
              : AppTheme.surfacePrimary(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.glassStroke(context))),
      child: ListTile(
          leading: Icon(icon),
          title: Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondary(context))),
          subtitle: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
    );
  }
}

class _TagInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> values;

  const _TagInfoTile({
    required this.icon,
    required this.label,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    final chips = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? Colors.black.withValues(alpha: 0.20)
            : AppTheme.surfacePrimary(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassStroke(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.textSecondary(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.textSecondary(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((value) => _Pill(text: value)).toList(),
          ),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatefulWidget {
  final User user;
  const _ReviewsSection({required this.user});
  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  List<ReviewWithUser> _reviews = const [];
  bool _loading = true;

  String _reviewItemTitle(ReviewWithUser entry) {
    final itemTitle = entry.item?.title.trim() ?? '';
    return itemTitle.isNotEmpty ? itemTitle : 'Anzeige';
  }

  String? _reviewItemImageUrl(ReviewWithUser entry) {
    final item = entry.item;
    if (item == null || item.photos.isEmpty) return null;
    final imageUrl = item.photos.first.trim();
    return imageUrl.isNotEmpty ? imageUrl : null;
  }

  Future<void> _openReviewPreviewDetails(ReviewWithUser entry) async {
    final reviewer = entry.reviewer;
    final name = reviewer?.displayName ?? '—';
    final avatarUrl = reviewer?.photoURL;
    final itemTitle = _reviewItemTitle(entry);
    final itemImageUrl = _reviewItemImageUrl(entry);

    await AppPopup.showCustom<void>(
      context,
      icon: Icons.rate_review_outlined,
      title: 'Bewertung von $name',
      barrierDismissible: true,
      showCloseIcon: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PublicProfileReviewArtwork(
                itemImageUrl: itemImageUrl,
                avatarUrl: avatarUrl,
                rating: entry.review.rating,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buildPublicProfileReviewItemLine(itemTitle),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textPrimary(context),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateDe(entry.review.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary(context),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            entry.review.comment,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary(context),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          PublicProfileReviewDetailsInline(
            criteria: entry.multiReview?.criteria ?? const [],
          ),
        ],
      ),
    );
  }

  static String _formatDateDe(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez'
    ];
    final d = dt.day.toString().padLeft(2, '0');
    final m = months[(dt.month - 1).clamp(0, 11)];
    return '$d. $m ${dt.year}';
  }

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
          Text(l10n.t('Bewertungen'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: AppTheme.textPrimary(context))),
          const SizedBox(height: 12),
          Center(
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.primary))),
        ],
      );
    }

    if (_reviews.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('Bewertungen'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: AppTheme.textPrimary(context))),
          const SizedBox(height: 8),
          Text(l10n.t('Dieser Nutzer hat noch keine Bewertungen erhalten.'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.textSecondary(context))),
        ],
      );
    }

    final preview = _reviews.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.t('Bewertungen'),
            style: theme.textTheme.titleMedium
                ?.copyWith(color: AppTheme.textPrimary(context))),
        const SizedBox(height: 8),
        ...preview.map((entry) {
          final reviewer = entry.reviewer;
          final name = reviewer?.displayName ?? '—';
          final avatarUrl = reviewer?.photoURL;
          final itemImageUrl = _reviewItemImageUrl(entry);
          return PublicProfileCompactReviewCard(
            reviewerName: name,
            avatarUrl: avatarUrl,
            itemImageUrl: itemImageUrl,
            itemTitle: _reviewItemTitle(entry),
            reviewComment: entry.review.comment,
            rating: entry.review.rating,
            onTap: () => _openReviewPreviewDetails(entry),
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
      barrierColor: AppTheme.isDark(context)
          ? Colors.black.withValues(alpha: 0.90)
          : Colors.black.withValues(alpha: 0.16),
      builder: (_) {
        return SafeArea(
          top: false,
          child: SizedBox.expand(
            child: Stack(
              children: [
                BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: AppTheme.isDark(context)
                        ? const Color(0xFF0B111C).withValues(alpha: 0.96)
                        : const Color(0xFFF8FAFC).withValues(alpha: 0.96),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Builder(
                    builder: (context) {
                      final summary =
                          ReviewMetricsService.calculateUserSummary(_reviews);
                      final list = summary.reviews;
                      final criteria =
                          buildPublicProfileCriterionAggregates(list);
                      final double avg = summary.averageRating;
                      final int count = summary.reviewCount;
                      return Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                            decoration: BoxDecoration(
                              gradient: AppTheme.isDark(context)
                                  ? LinearGradient(
                                      colors: [
                                        const Color(0xFF141B27),
                                        const Color(0xFF0F1723),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : const LinearGradient(
                                      colors: [
                                        Color(0xFFFFFFFF),
                                        Color(0xFFF8FAFC),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                  color: AppTheme.glassStroke(context)),
                              boxShadow: AppTheme.isDark(context)
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.06),
                                        blurRadius: 22,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Bewertungen',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  color: AppTheme.textPrimary(
                                                      context),
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$count Bewertungen aus abgeschlossenen Buchungen',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: AppTheme.textSecondary(
                                                      context),
                                                  height: 1.3,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      onPressed: () =>
                                          Navigator.of(context).maybePop(),
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            AppTheme.isDark(context)
                                                ? Colors.white
                                                    .withValues(alpha: 0.06)
                                                : const Color(0xFFF3F6FA),
                                        foregroundColor:
                                            AppTheme.textPrimary(context),
                                      ),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.isDark(context)
                                            ? Colors.white
                                                .withValues(alpha: 0.06)
                                            : const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: AppTheme.isDark(context)
                                              ? Colors.white
                                                  .withValues(alpha: 0.08)
                                              : const Color(0xFFFED7AA),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star_rounded,
                                              color: Color(0xFFFB923C),
                                              size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${formatPublicProfileRatingValue(avg)} / 5',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: AppTheme.textPrimary(
                                                      context),
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (criteria.isNotEmpty) ...[
                                  const SizedBox(height: 22),
                                  Text(
                                    'Bewertung nach Kriterien',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: AppTheme.textPrimary(context),
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...criteria.map((criterion) {
                                    return Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.isDark(context)
                                            ? Colors.white
                                                .withValues(alpha: 0.04)
                                            : const Color(0xFFFCFDFF),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color:
                                                AppTheme.glassStroke(context)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  publicProfileReviewCriterionLabel(
                                                      criterion.key),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: AppTheme
                                                            .textPrimary(
                                                                context),
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  '${criterion.count} Bewertung${criterion.count == 1 ? '' : 'en'}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: AppTheme
                                                            .textSecondary(
                                                                context),
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: List.generate(5, (index) {
                                              final filled = index <
                                                  criterion.average.round();
                                              return Padding(
                                                padding: EdgeInsets.only(
                                                    right: index == 4 ? 0 : 2),
                                                child: Icon(
                                                  filled
                                                      ? Icons.star_rounded
                                                      : Icons
                                                          .star_border_rounded,
                                                  size: 16,
                                                  color:
                                                      const Color(0xFFFB923C),
                                                ),
                                              );
                                            }),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            width: 64,
                                            child: Text(
                                              '${formatPublicProfileRatingValue(criterion.average)} / 5',
                                              textAlign: TextAlign.right,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: AppTheme.textPrimary(
                                                        context),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.only(top: 2, bottom: 4),
                              itemCount: list.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final entry = list[i];
                                final reviewer = entry.reviewer;
                                final name = reviewer?.displayName ?? '—';
                                final avatarUrl = reviewer?.photoURL;
                                final itemImageUrl = _reviewItemImageUrl(entry);
                                return PublicProfileCompactReviewCard(
                                  reviewerName: name,
                                  avatarUrl: avatarUrl,
                                  itemImageUrl: itemImageUrl,
                                  itemTitle: _reviewItemTitle(entry),
                                  reviewComment: entry.review.comment,
                                  rating: entry.review.rating,
                                  onTap: () => _openReviewPreviewDetails(entry),
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
