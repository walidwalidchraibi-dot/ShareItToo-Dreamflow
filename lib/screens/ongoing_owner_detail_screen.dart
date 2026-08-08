import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/user_avatar.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/screens/message_thread_screen.dart';
import 'package:lendify/screens/public_profile_screen.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/shared_persistence_sync.dart';
import 'package:lendify/widgets/item_details_overlay.dart';
import 'package:lendify/widgets/return_handover_stepper_sheet.dart';
import 'package:lendify/widgets/review_prompt_sheet.dart';
import 'package:lendify/screens/owner_requests_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/screens/support_flow_screen.dart';
import 'package:lendify/widgets/sit_glass_time_picker.dart';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:lendify/services/address_privacy.dart';
import 'package:lendify/widgets/approx_location_map.dart';
import 'package:lendify/widgets/sit_overflow_menu.dart';
import 'package:lendify/services/handover_code.dart';

class OngoingOwnerDetailScreen extends StatefulWidget {
  final String requestId;
  final String? titleOverride; // Allows caller to reflect the source tab name
  const OngoingOwnerDetailScreen({
    super.key,
    required this.requestId,
    this.titleOverride,
  });

  @override
  State<OngoingOwnerDetailScreen> createState() =>
      _OngoingOwnerDetailScreenState();
}

class _OngoingOwnerDetailScreenState extends State<OngoingOwnerDetailScreen> {
  RentalRequest? _req;
  Item? _item;
  User? _renter;
  User? _owner;
  bool _showManualHandover = false;
  final TextEditingController _manualCodeCtrl = TextEditingController();
  Map<String, dynamic>? _deliverySel;
  Map<String, dynamic> _flowState = const {};
  bool _reviewAlreadySubmitted = false;
  StreamSubscription<String>? _sharedPersistenceSub;
  final SharedPersistenceRefreshCoordinator _sharedPersistenceRefresh =
      SharedPersistenceRefreshCoordinator();

  @override
  void initState() {
    super.initState();
    _load();
    _sharedPersistenceSub = SharedPersistenceSync.changes.listen((key) {
      if (!mounted || !SharedPersistenceSync.affectsBookingSync(key)) return;
      unawaited(_sharedPersistenceRefresh.schedule(() async {
        await SharedPersistenceSync.reloadPreferences();
        if (mounted) await _load();
      }));
    });
  }

  Future<void> _load() async {
    final req = await DataService.getRentalRequestById(widget.requestId);
    if (req == null) return;
    final item = await DataService.getItemById(req.itemId);
    final renter = await DataService.getUserById(req.renterId);
    final owner = await DataService.getUserById(req.ownerId);
    final sel = item != null
        ? await DataService.getSavedDeliverySelection(item.id)
        : null;
    final flowState = await DataService.getHandoverReturnState(req.id);
    final alreadyReviewed = owner != null
        ? await DataService.hasSubmittedReview(
            requestId: req.id,
            reviewerId: owner.id,
          )
        : false;
    if (!mounted) return;
    setState(() {
      _req = req;
      _item = item;
      _renter = renter;
      _owner = owner;
      _deliverySel = sel;
      _flowState = flowState;
      _reviewAlreadySubmitted = alreadyReviewed;
    });
    // Show one-time handover banner if present (e.g., renter confirmed)
    if (mounted && item != null) {
      final bookingId = _computeBookingId(item, req);
      final msg = await DataService.takeHandoverBanner(bookingId);
      if (msg != null && msg.isNotEmpty && mounted) {
        AppPopup.toast(context, icon: Icons.check_circle_outline, title: msg);
      }
    }
  }

  @override
  void dispose() {
    _sharedPersistenceSub?.cancel();
    _sharedPersistenceRefresh.dispose();
    _manualCodeCtrl.dispose();
    super.dispose();
  }

  List<String> get _photos => (_item?.photos ?? const <String>[]);

  String? _confirmedLocationText(bool isReturn) {
    final prefix = isReturn ? 'return' : 'handover';
    final label =
        ((_flowState['${prefix}LocationLabel'] as String?) ?? '').trim();
    final name =
        ((_flowState['${prefix}LocationSharedByName'] as String?) ?? '').trim();
    if (label.isNotEmpty) {
      return '${isReturn ? 'Rückgabeort' : 'Übergabeort'}: $label';
    }
    if (name.isNotEmpty) {
      return '${isReturn ? 'Rückgabeort' : 'Übergabeort'}: Standort von $name';
    }
    return null;
  }

  String _confirmedLocationMapsUrl(bool isReturn) {
    final prefix = isReturn ? 'return' : 'handover';
    return ((_flowState['${prefix}LocationMapsUrl'] as String?) ?? '').trim();
  }

  Future<void> _openConfirmedLocationUrl(bool isReturn) async {
    final url = _confirmedLocationMapsUrl(isReturn);
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openSupportFlow({
    required RentalRequest req,
    required Item item,
  }) async {
    final current = await DataService.getCurrentUser();
    if (!mounted || current == null) return;
    final flowContext = SupportFlowContext.fromOwnerRequestDetail(
      itemTitle: item.title,
      itemId: item.id,
      requestId: req.id,
      bookingStatus: req.status,
      otherUserName: _renter?.displayName,
      itemImageUrl: _photos.isNotEmpty ? _photos.first : null,
      otherUserImageUrl: _renter?.photoURL,
    );
    final result = await Navigator.of(context).push<SupportFlowResult?>(
      MaterialPageRoute(
        builder: (_) => SupportFlowScreen(context: flowContext),
      ),
    );
    if (result == null || !mounted) return;
    final supportThread = await DataService.createSupportThread(
      userId: current.id,
    );
    if (supportThread == null) {
      AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Support nicht verfügbar',
      );
      return;
    }
    final descText = result.userDescription.isNotEmpty
        ? '\n\nBeschreibung:\n${result.userDescription}'
        : '';
    await DataService.addSystemMessageToThread(
      threadId: supportThread.id,
      text:
          "Support-Fall eröffnet: ${result.mainCategoryLabel} · ${item.title}\n📋 Support-Anfrage zu: ${item.title}\nBuchung: ${req.id}\nKategorie: ${result.mainCategoryLabel}\nUnterkategorie: ${result.subCategory}$descText",
    );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageThreadScreen(
          threadId: supportThread.id,
          participantName: 'SIT Support',
          itemTitle: 'Support',
        ),
      ),
    );
  }

  Future<void> _manageBookingTime({
    required RentalRequest req,
    required bool isReturn,
  }) async {
    final current = await DataService.getCurrentUser();
    if (current == null) return;
    final thread = await DataService.createOrGetThreadForRequest(req.id);
    if (thread == null || !mounted) return;
    final state = await DataService.getHandoverReturnState(req.id);
    final key = isReturn ? 'return' : 'handover';
    final requestedLabel =
        ((state['${key}TimeRequested'] as String?) ?? '').trim();
    final requestedBy =
        ((state['${key}TimeRequestedByUserId'] as String?) ?? '').trim();
    final confirmed = state['${key}TimeConfirmed'] == true;
    final flowLabel = isReturn ? 'Rückgabezeit' : 'Übergabezeit';
    if (requestedLabel.isNotEmpty && !confirmed) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('$flowLabel verwalten'),
          content: Text(
            requestedBy.isNotEmpty && requestedBy != current.id
                ? 'Möchtest du die $flowLabel annehmen oder ändern?'
                : 'Möchtest du die $flowLabel ändern oder neu anfragen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen'),
            ),
            if (requestedBy.isNotEmpty && requestedBy != current.id)
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop('accept'),
                child: const Text('Annehmen'),
              ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop('change'),
              child: Text(
                requestedBy.isNotEmpty && requestedBy != current.id
                    ? 'Ändern'
                    : 'Neu anfragen',
              ),
            ),
          ],
        ),
      );
      if (action == null || !mounted) return;
      if (action == 'accept') {
        await DataService.confirmFlowTime(
          requestId: req.id,
          isReturn: isReturn,
          confirmedByUserId: current.id,
        );
        await DataService.addSystemMessageToThread(
          threadId: thread.id,
          text:
              '${isReturn ? '🔄' : '📦'} $flowLabel bestätigt: $requestedLabel Uhr',
        );
        AppPopup.toast(
          context,
          icon: Icons.check_circle_outline,
          title: '$flowLabel bestätigt',
        );
        await _load();
        return;
      }
    }
    final initial = isReturn ? req.end : req.start;
    final picked = await SitGlassTimePicker.show(
      context,
      title: isReturn ? 'Rückgabezeit wählen' : 'Übergabezeit wählen',
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (picked == null || !mounted) return;
    final proposed = DateTime(
      initial.year,
      initial.month,
      initial.day,
      picked.hour,
      picked.minute,
    );
    const days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final label =
        '${days[(proposed.weekday - 1) % 7]}, ${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await DataService.requestFlowTime(
      requestId: req.id,
      isReturn: isReturn,
      label: label,
      time: proposed,
      requestedByUserId: current.id,
    );
    await DataService.addSystemMessageToThread(
      threadId: thread.id,
      text:
          '${isReturn ? '🔄' : '📦'} $flowLabel ${requestedLabel.isNotEmpty ? 'geändert' : 'angefragt'}: $label Uhr',
    );
    AppPopup.toast(context, icon: Icons.schedule, title: '$flowLabel gesendet');
    await _load();
  }

  Future<bool> _timeConfirmedForStart({
    required RentalRequest req,
    required bool isReturn,
  }) async {
    final state = await DataService.getHandoverReturnState(req.id);
    final confirmed =
        state[isReturn ? 'returnTimeConfirmed' : 'handoverTimeConfirmed'] ==
            true;
    final requested =
        ((state[isReturn ? 'returnTimeRequested' : 'handoverTimeRequested']
                    as String?) ??
                '')
            .trim();
    if (requested.isNotEmpty && !confirmed) {
      if (mounted) {
        AppPopup.toast(
          context,
          icon: Icons.schedule,
          title: isReturn
              ? 'Rückgabezeit noch nicht bestätigt'
              : 'Übergabezeit noch nicht bestätigt',
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _showImagePreview(
    List<String> urls, {
    int initialIndex = 0,
  }) async {
    if (urls.isEmpty) return;
    await showGeneralDialog(
      context: context,
      barrierLabel: 'image_preview',
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, anim, secAnim) {
        final images = urls.where((u) => u.isNotEmpty).toList();
        if (images.isEmpty) return const SizedBox.shrink();
        final startIndex = initialIndex.clamp(0, images.length - 1);
        final controller = PageController(initialPage: startIndex);
        var page = startIndex;
        final size = MediaQuery.of(ctx).size;

        Future<void> _shift(int delta) async {
          final target = (page + delta).clamp(0, images.length - 1);
          if (target != page) {
            page = target;
            await controller.animateToPage(
              target,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
            );
          }
        }

        return StatefulBuilder(
          builder: (context, setState) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(ctx).maybePop(),
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 25.2, sigmaY: 25.2),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: size.width * 0.85,
                          maxHeight: size.height * 0.75,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Listener(
                              onPointerSignal: (signal) {
                                if (signal is PointerScrollEvent) {
                                  if (signal.scrollDelta.dy > 0 ||
                                      signal.scrollDelta.dx > 0) {
                                    _shift(1);
                                  } else if (signal.scrollDelta.dy < 0 ||
                                      signal.scrollDelta.dx < 0) {
                                    _shift(-1);
                                  }
                                }
                              },
                              child: Stack(
                                children: [
                                  ScrollConfiguration(
                                    behavior: const ScrollBehavior().copyWith(
                                      scrollbars: false,
                                    ),
                                    child: PageView.builder(
                                      controller: controller,
                                      onPageChanged: (i) =>
                                          setState(() => page = i),
                                      itemCount: images.length,
                                      itemBuilder: (_, i) => DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                        child: Center(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: AppImage(
                                              url: images[i],
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (images.length > 1)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 12,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          for (int i = 0;
                                              i < images.length;
                                              i++)
                                            AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 160,
                                              ),
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 4,
                                              ),
                                              width: i == page ? 10 : 8,
                                              height: i == page ? 10 : 8,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: i == page ? 0.9 : 0.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
      transitionBuilder: (ctx, anim, secAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(opacity: curved, child: child);
      },
      transitionDuration: const Duration(milliseconds: 160),
    );
  }

  @override
  Widget build(BuildContext context) {
    final req = _req;
    final item = _item;
    final renter = _renter;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titleOverride ?? _titleFromReq()),
        centerTitle: true,
        actions: [
          if (req != null && item != null)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () async {
                final cat = _categoryFor(req);
                final picked = await showSITOverflowMenu<String>(
                  context,
                  options: [
                    const SitMenuOption(
                      icon: Icons.visibility_rounded,
                      label: 'Anzeige ansehen',
                      value: 'view',
                    ),
                    if (cat == 'upcoming')
                      const SitMenuOption(
                        icon: Icons.cancel_outlined,
                        label: 'Stornieren',
                        value: 'cancel',
                      ),
                    const SitMenuOption(
                      icon: Icons.error_outline,
                      label: 'Problem melden',
                      value: 'issue',
                    ),
                  ],
                );
                switch (picked) {
                  case 'view':
                    ItemDetailsOverlay.showFullPage(context, item: item);
                    break;
                  case 'cancel':
                    await AppPopup.show(
                      context,
                      icon: Icons.close,
                      title: 'Buchung stornieren?',
                      message:
                          'Bist du sicher? Diese Buchung wird storniert und der Mieter wird informiert.',
                      barrierDismissible: true,
                      plainCloseIcon: true,
                      actions: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(
                            context,
                            rootNavigator: true,
                          ).maybePop(),
                          child: const Text('Abbrechen'),
                        ),
                        FilledButton(
                          onPressed: () async {
                            Navigator.of(
                              context,
                              rootNavigator: true,
                            ).maybePop();
                            await DataService
                                .updateRentalRequestStatusWithActor(
                              requestId: req.id,
                              status: 'cancelled',
                              cancelledBy: 'owner',
                            );
                            await DataService.addTimelineEvent(
                              requestId: req.id,
                              type: 'cancelled',
                              note: 'Von Vermieter storniert',
                            );
                            if (!mounted) return;
                            AppPopup.toast(
                              context,
                              icon: Icons.cancel_outlined,
                              title: 'Buchung storniert',
                            );
                            await _load();
                          },
                          child: const Text('Stornieren'),
                        ),
                      ],
                    );
                    break;
                  case 'issue':
                    await _openSupportFlow(req: req, item: item);
                    break;
                  default:
                }
              },
            ),
        ],
      ),
      // Bottom-anchored review button for completed rentals (owner -> renter)
      bottomNavigationBar: Builder(
        builder: (context) {
          final r = _req;
          final it = _item;
          final rn = _renter;
          if (r == null || it == null || rn == null) {
            return const SizedBox.shrink();
          }
          final cat = _categoryFor(r);
          // Show for all "completed" bucket items that are not cancelled/declined
          final isTrulyCompleted = (cat == 'completed') &&
              r.status != 'cancelled' &&
              r.status != 'declined';
          if (!isTrulyCompleted || r.needsReview) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: () => _showReviewSheet(context, rn),
                  icon: const Icon(Icons.star_rate_outlined),
                  label: const Text('Bewerten'),
                ),
              ),
            ),
          );
        },
      ),
      body: (req == null || item == null || renter == null)
          ? const Center(child: CircularProgressIndicator())
          : _buildOngoingBody(context, req, item, renter),
    );
  }

  String _titleFromReq() {
    final r = _req;
    if (r == null) return 'Laufende Vermietung';
    switch (_categoryFor(r)) {
      case 'requests':
        return 'Mietanfrage';
      case 'upcoming':
        return 'Kommende Vermietung';
      case 'completed':
        return r.needsReview
            ? 'Vermietung in Prüfung'
            : 'Abgeschlossene Vermietung';
      case 'ongoing':
      default:
        return 'Laufende Vermietung';
    }
  }

  String _categoryFor(RentalRequest r) {
    // Owner view follows strict status-driven categories
    final s = r.status.toLowerCase();
    if (s == 'pending') return 'requests';
    if (s == 'accepted') return 'upcoming';
    if (s == 'running') return 'ongoing';
    if (s == 'completed' || s == 'cancelled' || s == 'declined') {
      return 'completed';
    }
    // Fallback
    return 'upcoming';
  }

  Widget _buildOngoingBody(
    BuildContext context,
    RentalRequest req,
    Item item,
    User renter,
  ) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final due = req.end;
    final diff = due.difference(now);
    final isOverdue = now.isAfter(due) && req.status != 'completed';
    final category = _categoryFor(req);

    final isCompleted = req.status == 'completed';
    final isHeldForReview = req.needsReview;
    final title = item.title;
    final location = item.locationText ?? (item.city ?? '');
    // Derive responsibilities robustly from persisted request snapshot; fall back to
    // transient selection and express/address hints for legacy data.
    final bool inferredOwnerDeliversByTransient =
        (_deliverySel?['hinweg'] == true);
    final bool inferredOwnerDeliversByExpress =
        req.expressRequested || (req.expressStatus != null);
    final bool inferredOwnerDeliversByAddress =
        ((req.deliveryAddressLine ?? '').toString().trim().isNotEmpty) ||
            ((req.deliveryCity ?? '').toString().trim().isNotEmpty);
    final bool ownerDelivers = req.ownerDeliversAtDropoffChosen ||
        inferredOwnerDeliversByTransient ||
        inferredOwnerDeliversByExpress ||
        inferredOwnerDeliversByAddress;

    final bool inferredOwnerPicksUpByTransient =
        (_deliverySel?['rueckweg'] == true);
    final bool ownerPicksUp =
        req.ownerPicksUpAtReturnChosen || inferredOwnerPicksUpByTransient;

    final String targetAddr = _composeTargetAddressFromReq(
      req,
      _deliverySel,
      fallback: location,
    );

    final breakdown = DataService.priceBreakdownForRequest(
      item: item,
      req: req,
      deliverySel: _deliverySel,
    );
    final days = breakdown.days;
    final rentalSubtotalOnly = breakdown.rentalSubtotal;
    final platformFee = breakdown.platformFee;
    double totalPaid = breakdown.totalRenter;
    final daily = days > 0 ? (rentalSubtotalOnly / days) : rentalSubtotalOnly;
    final fee = platformFee;
    final subtotal = rentalSubtotalOnly;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Priorität confirmation card (only when request pending confirmation and express was requested)
        if (req.status == 'pending' &&
            req.expressRequested &&
            (req.expressStatus == null || req.expressStatus == 'pending')) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.flash_on_outlined, color: Colors.white70),
                    SizedBox(width: 8),
                    Text(
                      'Prioritätslieferung angefragt',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Prioritätslieferung in den nächsten 2 Stunden möglich?',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  '(5,00 € Zusatzvergütung – wird automatisch gutgeschrieben)',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await DataService.updateRentalRequestExpress(
                            requestId: req.id,
                            accept: true,
                          );
                          await DataService.addTimelineEvent(
                            requestId: req.id,
                            type: 'express_accepted',
                            note: 'Prioritätslieferung bestätigt',
                          );
                          await DataService.addNotification(
                            title: 'Priorität bestätigt',
                            body:
                                'Die Prioritätslieferung wurde bestätigt (+5,00 €).',
                          );
                          await _load();
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Ja, bestätigen'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await DataService.updateRentalRequestExpress(
                            requestId: req.id,
                            accept: false,
                          );
                          await DataService.addTimelineEvent(
                            requestId: req.id,
                            type: 'express_declined',
                            note: 'Prioritätslieferung abgelehnt',
                          );
                          await DataService.addNotification(
                            title: 'Priorität abgelehnt',
                            body:
                                'Die 5,00 € Prioritäts-Zahlung wird dem Mieter automatisch erstattet.',
                          );
                          await _load();
                        },
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Ablehnen'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else if (req.expressRequested && req.expressStatus == 'accepted') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF22C55E).withValues(alpha: 0.24),
              ),
            ),
            child: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Color(0xFF22C55E)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prioritätslieferung bestätigt (+5,00 €)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else if (req.expressRequested && req.expressStatus == 'declined') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF43F5E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.24),
              ),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Color(0xFFF43F5E)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prioritätslieferung abgelehnt – 5,00 € werden erstattet',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Hero image with overlays: status chip (bottom-left), optional countdown (bottom-right),
        // and for upcoming a cancel button (top-right)
        if (_photos.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              height: 220,
              child: Stack(
                children: [
                  // Ensure the image fills and is centered (avoid half-shifted appearance)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showImagePreview(_photos, initialIndex: 0),
                      child: AppImage(url: _photos.first, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => ItemDetailsOverlay.showFullPage(
                          context,
                          item: item,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.visibility_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Status chip overlay (bottom-left) across all categories
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: () {
                          if (category == 'completed') {
                            // Completed bucket may be cancelled or finished
                            final cancelled = req.status == 'cancelled' ||
                                req.status == 'declined';
                            return (cancelled
                                    ? const Color(0xFFF43F5E)
                                    : const Color(0xFF22C55E))
                                .withValues(alpha: 0.12);
                          }
                          if (isCompleted) {
                            return const Color(
                              0xFF22C55E,
                            ).withValues(alpha: 0.12);
                          }
                          switch (category) {
                            case 'requests':
                              return Colors.grey.withValues(alpha: 0.12);
                            case 'upcoming':
                              return const Color(
                                0xFF0EA5E9,
                              ).withValues(alpha: 0.12);
                            case 'ongoing':
                            default:
                              return const Color(
                                0xFF0EA5E9,
                              ).withValues(alpha: 0.12);
                          }
                        }(),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Text(
                        () {
                          if (category == 'completed') {
                            final isCancelled = req.status == 'cancelled';
                            final isDeclined = req.status == 'declined';
                            if (isCancelled && (req.cancelledBy == 'renter')) {
                              return 'Zurückgezogen';
                            }
                            if (isCancelled || isDeclined) return 'Storniert';
                            return 'Abgeschlossen';
                          }
                          if (isCompleted) return 'Abgeschlossen';
                          if (category == 'requests') return 'Anfrage';
                          if (category == 'upcoming') return 'Kommend';
                          return 'Laufend';
                        }(),
                        style: TextStyle(
                          color: () {
                            if (category == 'completed') {
                              final cancelled = req.status == 'cancelled' ||
                                  req.status == 'declined';
                              return cancelled
                                  ? const Color(0xFFF43F5E)
                                  : const Color(0xFF22C55E);
                            }
                            if (isCompleted) return const Color(0xFF22C55E);
                            return category == 'requests'
                                ? Colors.grey
                                : const Color(0xFF0EA5E9);
                          }(),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Right countdown: Rückgabe in ... (laufend) or Übergabe in ... (kommend)
                  if (category == 'ongoing')
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isOverdue
                                      ? const Color(0xFFF43F5E)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.primary)
                                  .withValues(alpha: 0.30),
                              blurRadius: 10,
                              spreadRadius: 0.2,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isOverdue
                                  ? Icons.report_outlined
                                  : Icons.timer_outlined,
                              size: 16,
                              color: isOverdue
                                  ? const Color(0xFFF43F5E)
                                  : Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatDurationCompact(diff),
                              style: TextStyle(
                                color: isOverdue
                                    ? const Color(0xFFF43F5E)
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (category == 'upcoming')
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Builder(
                        builder: (context) {
                          final now = DateTime.now();
                          final d = req.start.difference(now);
                          String text;
                          if (d.isNegative || d.inDays == 0) {
                            text = 'Übergabe Heute';
                          } else if (d.inDays == 1) {
                            text = 'Übergabe in 1 Tag';
                          } else {
                            text = 'Übergabe in ${d.inDays} Tagen';
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.30),
                                  blurRadius: 10,
                                  spreadRadius: 0.2,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Centered title above the info card
        const SizedBox(height: 10),
        Text(
          item.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),

        // (verlegt) "Was passiert als Nächstes?" wird unten auf der Seite angezeigt
        if (category == 'requests') ...[
          const SizedBox(height: 10),
          // Actions directly under the image per request
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await AppPopup.show(
                      context,
                      icon: Icons.block,
                      title: 'Anfrage ablehnen?',
                      message: 'Bist du sicher? Der Mieter wird informiert.',
                      plainCloseIcon: true,
                      leadingWidget: Builder(
                        builder: (context) {
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
                        },
                      ),
                      actions: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(
                            context,
                            rootNavigator: true,
                          ).maybePop(),
                          child: const Text('Abbrechen'),
                        ),
                        FilledButton(
                          onPressed: () async {
                            Navigator.of(
                              context,
                              rootNavigator: true,
                            ).maybePop();
                            await DataService.updateRentalRequestStatus(
                              requestId: req.id,
                              status: 'declined',
                            );
                            await DataService.addTimelineEvent(
                              requestId: req.id,
                              type: 'declined',
                              note: 'Anfrage abgelehnt',
                            );
                            if (!mounted) return;
                            await _load();
                            // Auto-close after 3 seconds
                            Future.delayed(const Duration(seconds: 3), () {
                              if (mounted) {
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).maybePop();
                              }
                            });
                            // Result popup
                            // ignore: unawaited_futures
                            AppPopup.show(
                              context,
                              icon: Icons.cancel_outlined,
                              title: 'Du hast die Anfrage abgelehnt.',
                              message:
                                  'Du findest sie jetzt unter Abgeschlossene Vermietungen.',
                              barrierDismissible: true,
                              showCloseIcon: false,
                              plainCloseIcon: true,
                              autoCloseAfter: const Duration(seconds: 20),
                              actions: [
                                FilledButton(
                                  onPressed: () {
                                    Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).maybePop();
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => OwnerRequestsScreen(
                                          initialTabIndex: 3,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Zu Abgeschlossene Vermietungen',
                                  ),
                                ),
                              ],
                            );
                          },
                          child: const Text('Ablehnen'),
                        ),
                      ],
                    );
                  },
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Color(0xFFF43F5E),
                  ),
                  label: const Text('Ablehnen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF43F5E),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await DataService.updateRentalRequestStatus(
                      requestId: req.id,
                      status: 'accepted',
                    );
                    await DataService.addTimelineEvent(
                      requestId: req.id,
                      type: 'accepted',
                      note: 'Anfrage akzeptiert',
                    );
                    if (!mounted) return;
                    await _load();
                    // Auto-close after 3 seconds
                    Future.delayed(const Duration(seconds: 3), () {
                      if (mounted) {
                        Navigator.of(context, rootNavigator: true).maybePop();
                      }
                    });
                    // Result popup
                    // ignore: unawaited_futures
                    AppPopup.show(
                      context,
                      icon: Icons.check_circle_outline,
                      title: 'Du hast die Anfrage akzeptiert.',
                      message:
                          'Du findest diese Vermietung jetzt unter Kommende Vermietungen.',
                      barrierDismissible: true,
                      showCloseIcon: false,
                      plainCloseIcon: true,
                      autoCloseAfter: const Duration(seconds: 20),
                      actions: [
                        FilledButton(
                          onPressed: () {
                            Navigator.of(
                              context,
                              rootNavigator: true,
                            ).maybePop();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) =>
                                    OwnerRequestsScreen(initialTabIndex: 1),
                              ),
                            );
                          },
                          child: const Text('Zu Kommende Vermietungen'),
                        ),
                      ],
                    );
                  },
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF22C55E),
                  ),
                  label: const Text(
                    'Akzeptieren',
                    style: TextStyle(color: Color(0xFF22C55E)),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 12),

        // Removed separate inline "Problem melden"; now available from overflow menu
        const SizedBox(height: 16),
        // Details card (modernized, tighter spacing, transport sentence inline)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transport info sentence inline (no extra card)
              Builder(
                builder: (context) {
                  String? t;
                  if (category == 'upcoming' || category == 'requests') {
                    t = ownerDelivers
                        ? 'Du lieferst den Artikel zum Mieter.'
                        : 'Der Mieter holt den Artikel selbst ab.';
                  } else if (category == 'ongoing') {
                    t = ownerPicksUp
                        ? 'Du holst den Artikel wieder ab.'
                        : 'Der Mieter bringt den Artikel selbst zurück.';
                  }
                  if (t == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Center(
                      child: Text(
                        t,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
              _InfoRow(
                icon: Icons.schedule,
                label: 'Zeitraum',
                value: _formatRange(req.start, req.end),
              ),
              const SizedBox(height: 4),
              _InfoRow(
                icon: Icons.timelapse,
                label: 'Dauer',
                value: _formatDaysHours(req.end.difference(req.start)),
              ),
              const SizedBox(height: 4),
              if (category != 'requests')
                _InfoRow(
                  icon: Icons.tag,
                  label: 'Buchungs-ID',
                  value: _computeBookingId(item, req),
                ),
              if (category != 'requests') ...[
                const SizedBox(height: 6),
                Divider(
                  height: 12,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 2),
              ],
              const SizedBox(height: 6),
              _CounterpartyRow(
                name: renter.displayName,
                avatarUrl: renter.photoURL,
                role: 'Mieter',
                onProfile: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PublicProfileScreen(userId: renter.id),
                    ),
                  );
                },
                // Remove message button for requests (Ausstehende Anmietung)
                onMessage: (category == 'requests')
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MessageThreadScreen(
                              requestId: req.id,
                              participantName: renter.displayName,
                              avatarUrl: renter.photoURL,
                              itemTitle: item.title,
                            ),
                          ),
                        );
                      },
              ),
            ],
          ),
        ),

        // Approximate pickup/return map directly under the card (only when der Vermieter liefert/abholt)
        if (category == 'upcoming' && ownerDelivers) ...[
          const SizedBox(height: 8),
          ApproxLocationMap(
            lat: item.lat,
            lng: item.lng,
            label: AddressPrivacy.nearbyShort(kindLabel: 'Abholung'),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final reveal = AddressPrivacy.shouldRevealExactAddress(
                isAccepted: true,
                handoverAt: req.start,
              );
              final text = reveal
                  ? 'Abholort: $targetAddr'
                  : AddressPrivacy.privacyNoticePickup();
              final icon = reveal ? Icons.place_outlined : Icons.lock_outline;
              return _AddressInfoCardInline(icon: icon, text: text);
            },
          ),
        ],
        if (category == 'requests' && ownerDelivers) ...[
          const SizedBox(height: 8),
          ApproxLocationMap(
            lat: item.lat,
            lng: item.lng,
            label: AddressPrivacy.nearbyShort(kindLabel: 'Abholung'),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final reveal = AddressPrivacy.shouldRevealExactAddress(
                isAccepted: req.status.toLowerCase().trim() == 'accepted',
                handoverAt: req.start,
              );
              final text = reveal
                  ? 'Abholort: $targetAddr'
                  : AddressPrivacy.privacyNoticePickup();
              final icon = reveal ? Icons.place_outlined : Icons.lock_outline;
              return _AddressInfoCardInline(icon: icon, text: text);
            },
          ),
        ],
        if (category == 'ongoing' && ownerPicksUp) ...[
          const SizedBox(height: 8),
          ApproxLocationMap(
            lat: item.lat,
            lng: item.lng,
            label: AddressPrivacy.nearbyShort(kindLabel: 'Rückgabe'),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              // For ongoing bookings, always show the exact address
              return _AddressInfoCardInline(
                icon: Icons.place_outlined,
                text: 'Rückgabeort: $targetAddr',
              );
            },
          ),
        ],

        if (_confirmedLocationText(false) != null) ...[
          const SizedBox(height: 12),
          _AddressInfoCardInline(
            icon: Icons.place_outlined,
            text: _confirmedLocationText(false)!,
          ),
        ],
        if (_confirmedLocationMapsUrl(false).isNotEmpty) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openConfirmedLocationUrl(false),
              child: const Text('In Google Maps öffnen'),
            ),
          ),
        ],
        if (_confirmedLocationText(true) != null) ...[
          const SizedBox(height: 8),
          _AddressInfoCardInline(
            icon: Icons.place,
            text: _confirmedLocationText(true)!,
          ),
        ],
        if (_confirmedLocationMapsUrl(true).isNotEmpty) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openConfirmedLocationUrl(true),
              child: const Text('In Google Maps öffnen'),
            ),
          ),
        ],

        const SizedBox(height: 16),
        // Payment summary (owner view): only payout shown
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Zahlungsübersicht',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              // If this rental was cancelled by the owner, there is no payout
              if (req.status == 'cancelled' &&
                  (req.cancelledBy == 'owner')) ...[
                _AmountRow(label: 'Auszahlung', value: '0,00 €', strong: true),
                const SizedBox(height: 2),
                Text(
                  'Keine Auszahlung, da vom Vermieter storniert.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ] else if (isCompleted && isHeldForReview) ...[
                _AmountRow(
                  label: 'Wird geprüft',
                  value: 'Wird nach Prüfung abgeschlossen',
                  strong: true,
                ),
              ] else if (isCompleted) ...[
                _AmountRow(
                  label: 'Ausgezahlt (an Vermieter)',
                  value: _formatEuro(totalPaid - fee),
                  strong: true,
                ),
                Text(
                  'Ausgezahlt am ${_formatPayoutDate(req.end)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ] else ...[
                _AmountRow(
                  label: 'Vorauss. Auszahlung',
                  value: _formatEuro(breakdown.payoutOwner),
                  strong: true,
                ),
                Text(
                  'Auszahlung am ${_formatPayoutDate(req.end)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (!isHeldForReview &&
                  (category == 'ongoing' || category == 'completed') &&
                  !(req.status == 'cancelled' && (req.cancelledBy == 'owner')))
                Align(
                  alignment: Alignment.center,
                  child: OutlinedButton.icon(
                    onPressed: () => _downloadReceiptPdf(
                      item,
                      req,
                      totalPaid,
                      fee,
                      subtotal,
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Beleg herunterladen (PDF)'),
                  ),
                ),
            ],
          ),
        ),

        // Completion summary (like renter view) – show for completed bucket including cancelled
        const SizedBox(height: 12),
        if (category == 'completed')
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHeldForReview ? 'Prüfstatus' : 'Abschluss-Zusammenfassung',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _FactRow(
                  icon: req.status == 'cancelled'
                      ? Icons.cancel_outlined
                      : (isHeldForReview
                          ? Icons.hourglass_top_outlined
                          : Icons.verified_outlined),
                  label: 'Status',
                  value: () {
                    if (req.status == 'cancelled' &&
                        (req.cancelledBy == 'renter')) {
                      return 'Zurückgezogen';
                    }
                    if (req.status == 'cancelled') return 'Storniert';
                    if (isHeldForReview) return 'Wird geprüft';
                    return 'Abgeschlossen';
                  }(),
                  color: req.status == 'cancelled'
                      ? const Color(0xFFF43F5E)
                      : (isHeldForReview
                          ? const Color(0xFFF59E0B)
                          : Colors.blueGrey),
                ),
                const SizedBox(height: 8),
                _FactRow(
                  icon: Icons.event_busy,
                  label: req.status == 'cancelled'
                      ? 'Storniert am'
                      : 'Rückgabe bestätigt',
                  value: _formatRange(
                    req.start,
                    req.end,
                  ).split('–').last.trim(),
                ),
                const SizedBox(height: 8),
                _FactRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'Beleg',
                  value: isHeldForReview
                      ? 'Wird nach Prüfung bereitgestellt'
                      : 'Erstattung gem. Richtlinien',
                ),
                if (isHeldForReview) ...[
                  const SizedBox(height: 8),
                  _FactRow(
                    icon: Icons.info_outline,
                    label: 'Hinweis',
                    value:
                        'Zu dieser Buchung liegt eine Rückmeldung vor. Wir prüfen den Vorgang sorgfältig und schließen die Buchung danach vollständig ab. Danke für dein Verständnis.',
                  ),
                ],
              ],
            ),
          ),

        // Bottom timeline removed in favor of compact status card
        const SizedBox(height: 12),
        if (category == 'requests' ||
            category == 'upcoming' ||
            category == 'ongoing')
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                collapsedIconColor: Colors.white70,
                iconColor: Colors.white70,
                leading: const Icon(Icons.help_outline, color: Colors.white70),
                title: Text(
                  'Was passiert als Nächstes?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                childrenPadding: const EdgeInsets.only(
                  left: 0,
                  right: 0,
                  bottom: 12,
                ),
                children: [
                  if (category == 'requests') ...const [
                    _Bullet(
                      text:
                          'Prüfe die Details und entscheide, ob du die Anfrage annimmst oder ablehnst.',
                    ),
                    _Bullet(
                      text:
                          'Wenn du die Anfrage annimmst, erscheint sie unter Kommende Vermietungen.',
                    ),
                    _Bullet(
                      text:
                          'Vereinbare mit dem Mieter einen konkreten Zeitpunkt für Übergabe und Rückgabe.',
                    ),
                  ] else if (category == 'upcoming') ...const [
                    _Bullet(
                      text:
                          'Triff dich mit dem Mieter zum vereinbarten Übergabezeitpunkt.',
                    ),
                    _Bullet(
                      text:
                          'Tippe auf „Übergabe starten“, wenn ihr euch trefft.',
                    ),
                    _Bullet(
                      text:
                          'Beide müssen mindestens 4 Übergabe‑Fotos vom Artikel machen.',
                    ),
                    _Bullet(
                      text:
                          'Übergabe bestätigen durch QR‑Code‑Scan oder Eingabe des 6‑stelligen Übergabecodes.',
                    ),
                  ] else ...const [
                    _Bullet(
                      text:
                          'Triff dich mit dem Mieter zum vereinbarten Rückgabezeitpunkt.',
                    ),
                    _Bullet(
                      text:
                          'Tippe auf „Rückgabe starten“, wenn ihr euch trefft.',
                    ),
                    _Bullet(
                      text:
                          'Beide müssen mindestens 4 Rückgabe‑Fotos vom Artikel machen.',
                    ),
                    _Bullet(
                      text:
                          'Rückgabe bestätigen durch QR‑Code‑Scan oder Eingabe des 6‑stelligen Rückgabecodes.',
                    ),
                    _Bullet(
                      text:
                          'Tippe auf „Abschließen“, um die Übergabe abzuschließen.',
                    ),
                  ],
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),
        // Handover/Return block moved to the very bottom (above page padding)
        // Show only for upcoming or ongoing. Hide for completed (incl. cancelled/declined)
        // and for requests.
        if (category == 'upcoming' || category == 'ongoing')
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category == 'upcoming' ? 'Übergabe' : 'Rückgabe',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (category == 'upcoming') ...[
                  _InlineTimeActionButton(
                    icon: Icons.inventory_2_rounded,
                    label: 'Übergabezeit',
                    onTap: () => _manageBookingTime(req: req, isReturn: false),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            if (!await _timeConfirmedForStart(
                              req: req,
                              isReturn: false,
                            )) {
                              return;
                            }
                            await _startPickupFlowOwner(
                              context,
                              req,
                              item,
                              renter,
                            );
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Übergabe starten'),
                        ),
                      ),
                    ],
                  ),
                ] else if (category == 'ongoing' && !req.needsReview) ...[
                  _InlineTimeActionButton(
                    icon: Icons.undo_rounded,
                    label: 'Rückgabezeit',
                    onTap: () => _manageBookingTime(req: req, isReturn: true),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            if (!await _timeConfirmedForStart(
                              req: req,
                              isReturn: true,
                            )) {
                              return;
                            }
                            await _startReturnFlow(context, req, item, renter);
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Rückgabe starten'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

        // Review button moved to bottomNavigationBar for completed owner view

        // Problem melden should be at the bottom for completed
        // Removed duplicate Problem melden CTA – moved to overflow menu
      ],
    );
  }

  Future<void> _downloadReceiptPdf(
    Item item,
    RentalRequest req,
    double totalPaid,
    double fee,
    double subtotal,
  ) async {
    if (req.needsReview) {
      if (mounted) {
        AppPopup.toast(
          context,
          icon: Icons.hourglass_top_outlined,
          title: 'Beleg gesperrt, solange dieser Fall geprüft wird.',
        );
      }
      return;
    }
    final bookingId = _computeBookingId(item, req);
    final bool expressRefund = req.expressRequested &&
        req.expressStatus == 'declined' &&
        req.expressFee > 0;
    final breakdown = DataService.priceBreakdownForRequest(
      item: item,
      req: req,
      deliverySel: _deliverySel,
    );
    final html = '''
<!doctype html>
<html lang="de">
<meta charset="utf-8">
<title>Beleg $bookingId</title>
<style>
  body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;padding:24px;color:#0f172a}
  h1{font-size:18px;margin:0 0 12px}
  table{border-collapse:collapse;width:100%;max-width:560px}
  td{padding:6px 0}
  .right{text-align:right}
  .muted{color:#475569}
  .total{font-weight:800}
  hr{border:none;border-top:1px solid #e2e8f0;margin:12px 0}
 </style>
 <h1>Beleg</h1>
 <div class="muted">Buchungs-ID $bookingId</div>
 <div style="margin:8px 0 16px 0">${item.title}</div>
 <div class="muted">Zeitraum: ${_formatRange(req.start, req.end)}</div>
 <hr>
  <table>
   <tr><td>Mietpreis (Tagespreis × Tage)</td><td class="right">${_formatEuro(breakdown.rentalSubtotal)}</td></tr>
   ${breakdown.dropoffFee > 0 ? '<tr><td>Lieferung (Abgabe)</td><td class="right">${_formatEuro(breakdown.dropoffFee)}</td></tr>' : ''}
   ${breakdown.returnFee > 0 ? '<tr><td>Abholung (Rückgabe)</td><td class="right">${_formatEuro(breakdown.returnFee)}</td></tr>' : ''}
    ${breakdown.expressApplied > 0 ? '<tr><td>Prioritätszuschlag</td><td class="right">${_formatEuro(breakdown.expressApplied)}</td></tr>' : ''}
    ${breakdown.expressApplied > 0 ? '<tr><td>Plattformbeitrag auf Priorität (10%)</td><td class="right">${_formatEuro(double.parse((breakdown.expressApplied * 0.10).toStringAsFixed(2)))}</td></tr>' : ''}
   <tr><td>Plattformbeitrag</td><td class="right">${_formatEuro(breakdown.platformFee)}</td></tr>
   <tr><td colspan="2"><hr></td></tr>
   <tr><td class="total">Gesamt bezahlt (Mieter)</td><td class="right total">${_formatEuro(breakdown.totalRenter)}</td></tr>
  ${expressRefund ? '<tr><td>Rückerstattung (Priorität)</td><td class="right">${_formatEuro(req.expressFee)}</td></tr>' : ''}
 </table>
  <p class="muted">${expressRefund ? 'Prioritätszuschlag wird vollständig erstattet.' : ''}</p>
 <p class="muted">ShareItToo – Quittung ohne Gewähr.</p>
 </html>
''';
    final dataUri = Uri.dataFromString(
      html,
      mimeType: 'text/html',
      encoding: const Utf8Codec(),
    );
    try {
      await launchUrl(dataUri, mode: LaunchMode.platformDefault);
    } catch (_) {}
  }

  String _formatRange(DateTime a, DateTime b) {
    // Show dates only (no time-of-day) to match the SIT design app-wide
    const months = [
      'Jan',
      'Feb',
      'M\u00e4r',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ];
    String dd(int v) => v.toString().padLeft(2, '0');
    final sa = '${dd(a.day)}. ${months[(a.month - 1).clamp(0, 11)]}';
    final sb = '${dd(b.day)}. ${months[(b.month - 1).clamp(0, 11)]}';
    return '$sa – $sb';
  }

  String _formatDurationCompact(Duration d) {
    final days = d.inDays;
    if (d.isNegative) {
      final ad = d.abs();
      final aDays = ad.inDays;
      if (aDays == 0) return 'Überfällig seit Heute';
      if (aDays == 1) return 'Überfällig seit 1 Tag';
      return 'Überfällig seit $aDays Tagen';
    }
    if (days == 0) return 'Rückgabe Heute';
    if (days == 1) return 'Rückgabe in 1 Tag';
    return 'Rückgabe in $days Tagen';
  }

  String _formatDaysHours(Duration d) {
    final days = d.inDays;
    if (days == 0) return '1 Tag';
    if (days == 1) return '1 Tag';
    return '$days Tage';
  }

  Future<void> _openMaps(BuildContext context, String query) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    try {
      if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        _toast(context, 'Karte konnte nicht geöffnet werden');
      }
    } catch (_) {
      _toast(context, 'Karte konnte nicht geöffnet werden');
    }
  }

  String _computeBookingId(Item item, RentalRequest req) {
    final seed =
        ((item.id.hashCode) ^ (req.id.hashCode) ^ (item.title.hashCode)).abs();
    final s = seed.toString().padLeft(8, '0');
    return 'BKG-${s.substring(0, 4)}-${s.substring(4, 8)}';
  }

  String _confirmationCode(
    Item item,
    RentalRequest req, {
    required String segment,
    required String presenterRole,
  }) {
    return HandoverCodeService.codeForTitleAndStart(
      title: item.title,
      start: req.start,
      bookingId: _computeBookingId(item, req),
      segment: segment,
      presenterRole: presenterRole,
    );
  }

  String _handoverCode(Item item, RentalRequest req) {
    return HandoverCodeService.codeFromTitleAndStart(
      title: item.title,
      start: req.start,
    );
  }

  String _formatEuro(double v) {
    String two = v.toStringAsFixed(2);
    two = two.replaceAll('.', ',');
    return '$two €';
  }

  String _formatPayoutDate(DateTime end) {
    final payout = end.add(const Duration(days: 1));
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
      'Dez',
    ];
    final m = months[(payout.month - 1).clamp(0, 11)];
    final dd = payout.day.toString().padLeft(2, '0');
    return '$dd. $m';
  }

  String _composeTargetAddressFromReq(
    RentalRequest req,
    Map<String, dynamic>? sel, {
    required String fallback,
  }) {
    // Prefer persisted snapshot on the request; fall back to last-known transient selection.
    final String line =
        (req.deliveryAddressLine ?? (sel?['addressLine'] as String?) ?? '')
            .trim();
    final String city =
        (req.deliveryCity ?? (sel?['city'] as String?) ?? '').trim();
    if (line.isEmpty && city.isEmpty) return fallback;
    if (line.isNotEmpty && city.isNotEmpty) return '$line, $city';
    return line.isNotEmpty ? line : city;
  }

  void _toast(BuildContext context, String msg) {
    AppPopup.toast(context, icon: Icons.info_outline, title: msg);
  }

  bool _canStartOwnerHandover(RentalRequest req) {
    final status = req.status.toLowerCase().trim();
    return status == 'accepted';
  }

  bool _canCompleteOwnerReturn(RentalRequest req) {
    final status = req.status.toLowerCase().trim();
    return status == 'running';
  }

  Future<bool> _guardRequiredHandoverPhotos(String requestId) async {
    final handoverPhotos = await DataService.getHandoverPhotoCount(requestId);
    if (handoverPhotos >= DataService.minimumRequiredPhotos) return true;
    if (mounted) {
      AppPopup.toast(
        context,
        icon: Icons.photo_camera_back_outlined,
        title: 'Bitte dokumentiere die Übergabe zuerst mit mindestens 4 Fotos.',
      );
    }
    return false;
  }

  Future<bool> _guardRequiredReturnPhotos(String requestId) async {
    final returnPhotos = await DataService.getReturnPhotoCount(requestId);
    if (returnPhotos >= DataService.minimumRequiredPhotos) return true;
    if (mounted) {
      AppPopup.toast(
        context,
        icon: Icons.photo_camera_back_outlined,
        title: 'Bitte dokumentiere die Rückgabe zuerst mit mindestens 4 Fotos.',
      );
    }
    return false;
  }

  Future<bool> _acknowledgeGalleryEvidenceIfNeeded(
    String requestId, {
    required bool isReturn,
  }) async {
    final galleryUsed = isReturn
        ? await DataService.wasReturnGalleryUsed(requestId)
        : await DataService.wasHandoverGalleryUsed(requestId);
    if (!galleryUsed) return true;
    if (!mounted) return false;
    bool acknowledged = false;
    await AppPopup.show(
      context,
      icon: Icons.photo_library_outlined,
      title: 'Galerie-Fotos verwendet',
      message:
          'Hinweis: Mindestens ein Foto wurde aus der Galerie hinzugefügt. Bitte prüfe die Dokumentation bewusst, bevor du bestätigst.',
      actions: [
        OutlinedButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).maybePop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            acknowledged = true;
            Navigator.of(context, rootNavigator: true).maybePop();
          },
          child: const Text('Trotzdem bestätigen'),
        ),
      ],
    );
    return acknowledged;
  }

  Future<bool> _guardActiveFlow(
    String requestId, {
    required bool isReturn,
  }) async {
    final state = await DataService.getHandoverReturnState(requestId);
    final isActive = isReturn
        ? state['returnActive'] == true
        : state['handoverActive'] == true;
    if (isActive) return true;
    if (mounted) {
      AppPopup.toast(
        context,
        icon: Icons.info_outline,
        title: isReturn
            ? 'Bitte starte die Rückgabe zuerst im Chat.'
            : 'Bitte starte die Übergabe zuerst im Chat.',
      );
    }
    return false;
  }

  Future<String?> _guardAuthenticatedOwner(String ownerId) async {
    final current = await DataService.getCurrentUser();
    final expectedOwnerId = ownerId.trim();
    if (current == null ||
        expectedOwnerId.isEmpty ||
        current.id != expectedOwnerId) {
      if (mounted) {
        AppPopup.toast(
          context,
          icon: Icons.lock_outline,
          title: 'Diese Bestätigung ist nur für den Vermieter möglich.',
        );
      }
      return null;
    }
    return current.id;
  }

  Future<void> _confirmManualHandover(
    BuildContext context,
    RentalRequest req,
    Item item,
  ) async {
    await AppPopup.toast(
      context,
      icon: Icons.info_outline,
      title:
          'Eine Übergabe kann nur durch QR-Code oder den 6-stelligen Code der Gegenpartei bestätigt werden.',
    );
  }

  RentalRequest? _requestForId(String requestId) {
    final req = _req;
    if (req != null && req.id == requestId) return req;
    return null;
  }

  Future<void> _startQrScan(
    BuildContext context, {
    required String expectedCode,
    required String bookingId,
    required String requestId,
  }) async {
    String? scanned;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.86,
          child: Stack(
            children: [
              MobileScanner(
                controller: MobileScannerController(
                  detectionSpeed: DetectionSpeed.normal,
                  facing: CameraFacing.back,
                  torchEnabled: false,
                ),
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  if (barcodes.isEmpty) return;
                  final value = barcodes.first.rawValue ?? '';
                  if (value.isEmpty) return;
                  scanned = value;
                  Navigator.of(ctx).maybePop();
                },
              ),
              Positioned(
                left: 8,
                top: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(ctx).maybePop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Scanne den QR-Code des Mieters',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (scanned == null || scanned!.isEmpty) {
      AppPopup.toast(
        context,
        icon: Icons.qr_code_2,
        title: 'Kein Code erkannt',
      );
      return;
    }

    try {
      final raw = scanned!.trim();
      final matches = HandoverCodeService.isExpectedQrPayload(
        raw,
        segment: HandoverCodeService.segmentPickup,
        presenterRole: HandoverCodeService.presenterRenter,
        code: expectedCode,
        bookingId: bookingId,
      );
      if (!matches) {
        AppPopup.toast(
          context,
          icon: Icons.error_outline,
          title:
              'Dieser Code passt nicht zu diesem Übergabeschritt. Bitte den aktuellen Code erneut anzeigen oder scannen.',
        );
        return;
      }

      final request = _requestForId(requestId);
      if (request == null) {
        AppPopup.toast(
          context,
          icon: Icons.info_outline,
          title: 'Übergabe ist gerade nicht verfügbar',
        );
        return;
      }
      final ownerUserId = await _guardAuthenticatedOwner(request.ownerId);
      if (!context.mounted) return;
      if (ownerUserId == null) return;
      if (!_canStartOwnerHandover(request)) {
        AppPopup.toast(
          context,
          icon: Icons.info_outline,
          title: 'Übergabe ist gerade nicht verfügbar',
        );
        return;
      }
      final isActive = await _guardActiveFlow(requestId, isReturn: false);
      if (!isActive) return;
      final hasRequiredPhotos = await _guardRequiredHandoverPhotos(requestId);
      if (!hasRequiredPhotos) return;
      final galleryAcknowledged = await _acknowledgeGalleryEvidenceIfNeeded(
        requestId,
        isReturn: false,
      );
      if (!galleryAcknowledged) return;
      final result = await DataService.confirmPickupTransition(
        requestId: requestId,
        confirmedByUserId: ownerUserId,
        method: 'qr',
        confirmationContextVerified: true,
        galleryAcknowledged: galleryAcknowledged,
      );
      if (!context.mounted) return;
      if (!result.success) {
        AppPopup.toast(
          context,
          icon: Icons.lock_outline,
          title: result.errorMessage ?? 'Bestätigung fehlgeschlagen',
        );
        return;
      }
      AppPopup.toast(
        context,
        icon: Icons.check_circle_outline,
        title: 'Übergabe per QR bestätigt',
      );
      await _load();
    } catch (e) {
      debugPrint('[handover] qr scan verification failed: $e');
      if (!context.mounted) return;
      AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Bestätigung fehlgeschlagen',
      );
    }
  }

  Future<void> _startReturnFlow(
    BuildContext context,
    RentalRequest req,
    Item item,
    User renter,
  ) async {
    final code = _confirmationCode(
      item,
      req,
      segment: HandoverCodeService.segmentReturn,
      presenterRole: HandoverCodeService.presenterRenter,
    );
    final ok = await ReturnHandoverStepperSheet.push(
      context,
      item: item,
      request: req,
      renterName: renter.displayName,
      ownerName: _owner?.displayName ?? 'Vermieter',
      handoverCode: code,
      viewerIsOwner: true,
      mode: ReturnFlowMode.returnFlow,
    );
    final counterpartyConfirmed = ok?.confirmed == true;
    if (counterpartyConfirmed) {
      await _completeOwnerReturnWithSideEffects(
        req: req,
        item: item,
        renter: renter,
      );
    }
  }

  Future<void> _completeOwnerReturnWithSideEffects({
    required RentalRequest req,
    required Item item,
    required User renter,
  }) async {
    // Set completed, add timeline + notification, send receipt
    final ownerUserId = await _guardAuthenticatedOwner(req.ownerId);
    if (!context.mounted) return;
    if (ownerUserId == null) return;
    if (!_canCompleteOwnerReturn(req)) {
      AppPopup.toast(
        context,
        icon: Icons.info_outline,
        title: 'Rückgabe ist gerade nicht verfügbar',
      );
      return;
    }
    final isActive = await _guardActiveFlow(req.id, isReturn: true);
    if (!isActive) return;
    final hasRequiredPhotos = await _guardRequiredReturnPhotos(req.id);
    if (!hasRequiredPhotos) return;
    final pausedForReview =
        await DataService.pauseReturnCompletionIfNeedsReview(
      req.id,
      source: 'ongoing_owner_detail_screen',
    );
    final galleryAcknowledged = await _acknowledgeGalleryEvidenceIfNeeded(
      req.id,
      isReturn: true,
    );
    if (!galleryAcknowledged) return;
    if (pausedForReview) {
      if (!mounted) return;
      AppPopup.toast(
        context,
        icon: Icons.info_outline,
        title:
            'Diese Rückgabe ist zur Prüfung markiert. Der Abschluss wird pausiert, bis der Fall geprüft wurde.',
      );
      await _load();
      return;
    }
    await DataService.updateRentalRequestStatus(
      requestId: req.id,
      status: 'completed',
    );
    await DataService.recordRentalRequestConfirmation(
      requestId: req.id,
      isReturn: true,
      method: 'stepper',
      confirmedByRole: 'owner',
      confirmedByUserId: ownerUserId,
    );
    await DataService.clearReturnActive(req.id);
    await DataService.addTimelineEvent(
      requestId: req.id,
      type: 'completed',
      note: 'Rückgabe abgeschlossen',
    );
    // Release/cancel ride compensation if present (return segment)
    try {
      final grant = await DataService.getRideCompensationDecision(
        requestId: req.id,
        segment: 'return',
        consume: true,
      );
      if (grant != null) {
        await DataService.addTimelineEvent(
          requestId: req.id,
          type: grant ? 'ride_comp_release_return' : 'ride_comp_cancel_return',
          note: grant
              ? 'Fahrtvergütung freigegeben (Rückgabe)'
              : 'Fahrtvergütung nicht ausgezahlt (Rückgabe)',
        );
      }
    } catch (_) {}
    await DataService.addNotification(
      title: 'Buchung abgeschlossen',
      body:
          'Die Rückgabe für "${item.title}" wurde abgeschlossen. Beleg gesendet.',
    );
    if (!mounted) return;
    AppPopup.toast(context, icon: Icons.receipt_long, title: 'Beleg gesendet');
    await _load(); // refresh request
    if (!mounted) return;
    // Schedule a review reminder for the owner in 10 minutes instead of immediate prompt
    try {
      final owner = _owner;
      if (owner != null) {
        await DataService.scheduleReviewReminder(
          requestId: req.id,
          itemId: item.id,
          reviewerId: owner.id,
          reviewedUserId: renter.id,
          direction: 'owner_to_renter',
          dueAt: DateTime.now().add(const Duration(minutes: 10)),
        );
      }
    } catch (_) {}
  }

  Future<void> _startPickupFlowOwner(
    BuildContext context,
    RentalRequest req,
    Item item,
    User renter,
  ) async {
    final code = _confirmationCode(
      item,
      req,
      segment: HandoverCodeService.segmentPickup,
      presenterRole: HandoverCodeService.presenterOwner,
    );
    await ReturnHandoverStepperSheet.push(
      context,
      item: item,
      request: req,
      renterName: renter.displayName,
      ownerName: _owner?.displayName ?? 'Vermieter',
      handoverCode: code,
      viewerIsOwner: true,
      mode: ReturnFlowMode.pickupFlow,
    );
  }

  void _showQrOverlay(BuildContext context, String data) {
    showGeneralDialog(
      context: context,
      barrierLabel: 'QR',
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, anim, anim2) {
        final theme = Theme.of(context);
        return GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).maybePop(),
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.black.withValues(alpha: 0.25)),
                ),
              ),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.45,
                          ),
                          blurRadius: 28,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: data,
                      version: QrVersions.auto,
                      size: 300,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, anim, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showReviewSheet(BuildContext context, User renter) async {
    final request = _req;
    final item = _item;
    final owner = _owner;
    if (request == null || item == null || owner == null) return;
    final ok = await ReviewPromptSheet.show(
      context,
      requestId: request.id,
      itemId: item.id,
      reviewerId: owner.id,
      reviewedUserId: renter.id,
      direction: 'owner_to_renter',
    );
    if (ok == true && context.mounted) {
      setState(() => _reviewAlreadySubmitted = true);
      await AppPopup.toast(
        context,
        icon: Icons.star_rate_outlined,
        title: 'Danke für deine Bewertung!',
      );
    } else if (ok == false && context.mounted) {
      setState(() => _reviewAlreadySubmitted = true);
      await AppPopup.toast(
        context,
        icon: Icons.check_circle_outline,
        title: 'Bewertung abgegeben',
      );
    }
  }
}

/// Small non-collapsible card identical in look to the renter view
/// used under the map to show either the privacy notice (with a lock)
/// or the exact address (with a pin).
class _AddressInfoCardInline extends StatelessWidget {
  final IconData icon;
  final String text;
  const _AddressInfoCardInline({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerStatusCard extends StatelessWidget {
  final String status;
  final DateTime end;
  final bool isOverdue;
  final double totalPaid;
  final double fee;
  final bool expressAccepted;
  const _OwnerStatusCard({
    required this.status,
    required this.end,
    required this.isOverdue,
    required this.totalPaid,
    required this.fee,
    required this.expressAccepted,
  });

  String _formatEuro(double v) {
    String two = v.toStringAsFixed(2).replaceAll('.', ',');
    return '$two €';
  }

  String _formatPayoutDate(DateTime end) {
    final payout = end.add(const Duration(days: 1));
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
      'Dez',
    ];
    final m = months[(payout.month - 1).clamp(0, 11)];
    final dd = payout.day.toString().padLeft(2, '0');
    return '$dd. $m';
  }

  String _countdownText(DateTime to) {
    final now = DateTime.now();
    final d = to.difference(now);
    if (d.isNegative) {
      final ad = d.abs();
      final days = ad.inDays;
      if (days == 0) return 'Überfällig seit Heute';
      if (days == 1) return 'Überfällig seit 1 Tag';
      return 'Überfällig seit $days Tagen';
    }
    final days = d.inDays;
    if (days == 0) return 'Rückgabe Heute';
    if (days == 1) return 'Rückgabe in 1 Tag';
    return 'Rückgabe in $days Tagen';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payout = (totalPaid - fee).clamp(0.0, totalPaid);
    final colorOk = const Color(0xFF22C55E);
    final colorWarn = const Color(0xFFF43F5E);
    final colorInfo = const Color(0xFF0EA5E9);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == 'cancelled'
                    ? Icons.cancel_outlined
                    : Icons.verified_outlined,
                color: status == 'cancelled' ? colorWarn : colorOk,
              ),
              const SizedBox(width: 8),
              Text(
                status == 'cancelled' ? 'Storniert' : 'Bezahlt',
                style: TextStyle(
                  color: status == 'cancelled' ? colorWarn : colorOk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (status != 'cancelled')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorInfo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: colorInfo.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOverdue
                            ? Icons.report_outlined
                            : Icons.timer_outlined,
                        size: 16,
                        color: isOverdue ? colorWarn : Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _countdownText(end),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (status != 'cancelled') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vorauss. Auszahlung: ${_formatEuro(payout)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _formatPayoutDate(end),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            if (expressAccepted) ...[
              const SizedBox(height: 8),
              const Text(
                'Abholung vereinbart (Priorität)',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.3);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('•', style: style),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _MapLink extends StatelessWidget {
  final VoidCallback onTap;
  const _MapLink({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        'Karte',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CounterpartyRow extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String role;
  final VoidCallback? onProfile;
  final VoidCallback? onMessage;
  const _CounterpartyRow({
    required this.name,
    this.avatarUrl,
    required this.role,
    this.onProfile,
    this.onMessage,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onProfile,
          child: SitUserAvatar(
            url: avatarUrl,
            radius: 18,
            borderColor: Colors.white.withValues(alpha: 0.12),
            placeholderIcon: Icons.person_outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                role,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
        if (onMessage != null)
          IconButton(
            tooltip: 'Nachricht',
            onPressed: onMessage,
            icon: const Icon(Icons.forum_outlined, color: Colors.white70),
          ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _AmountRow({
    required this.label,
    required this.value,
    this.strong = false,
  });
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color ?? Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryCTA extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _PrimaryCTA({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _SecondaryCTA extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SecondaryCTA({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: Colors.white70),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final String current; // Laufend | Überfällig
  const _Timeline({required this.current});

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Requested',
      'Accepted',
      'Paid',
      'Picked up',
      'Laufend',
      'Due',
      'Completed',
    ];
    final isOverdue = current == 'Überfällig';
    final currentIndex = isOverdue ? 5 : steps.indexOf(current);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < steps.length; i++)
          _StepChip(
            label: steps[i],
            state: i < currentIndex
                ? _StepState.done
                : (i == currentIndex
                    ? (isOverdue ? _StepState.overdue : _StepState.current)
                    : _StepState.todo),
          ),
        if (isOverdue)
          const _StepChip(label: 'Überfällig', state: _StepState.overdue),
      ],
    );
  }
}

enum _StepState { done, current, todo, overdue }

class _StepChip extends StatelessWidget {
  final String label;
  final _StepState state;
  const _StepChip({required this.label, required this.state});
  @override
  Widget build(BuildContext context) {
    Color border;
    Color fg;
    Color bg;
    IconData? icon;
    switch (state) {
      case _StepState.done:
        border = Colors.white24;
        fg = Colors.white;
        bg = Colors.white.withValues(alpha: 0.08);
        icon = Icons.check_circle_outline;
        break;
      case _StepState.current:
        border = Theme.of(context).colorScheme.primary.withValues(alpha: 0.40);
        fg = Theme.of(context).colorScheme.primary;
        bg = Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
        icon = Icons.radio_button_checked;
        break;
      case _StepState.overdue:
        border = const Color(0xFFF43F5E).withValues(alpha: 0.40);
        fg = const Color(0xFFF43F5E);
        bg = const Color(0xFFF43F5E).withValues(alpha: 0.12);
        icon = Icons.error_outline;
        break;
      case _StepState.todo:
      default:
        border = Colors.white12;
        fg = Colors.white70;
        bg = Colors.white.withValues(alpha: 0.05);
        icon = Icons.radio_button_unchecked;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InlineTimeActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _InlineTimeActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: const Color(0xFFB8956C)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
