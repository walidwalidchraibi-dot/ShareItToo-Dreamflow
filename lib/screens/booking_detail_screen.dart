import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lendify/screens/message_thread_screen.dart';
import 'package:lendify/screens/bookings_screen.dart';
import 'package:lendify/screens/public_profile_screen.dart';
import 'package:lendify/widgets/return_reminder_picker_sheet.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/models/invoice.dart';
import 'package:lendify/services/invoice_pdf_service.dart';
import 'package:lendify/services/local_artifact_storage_service.dart';
import 'package:printing/printing.dart';
import 'package:lendify/services/file_download_stub.dart'
    if (dart.library.html) 'package:lendify/services/file_download_web.dart';
import 'package:lendify/widgets/item_details_overlay.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:convert';
import 'package:lendify/widgets/return_handover_stepper_sheet.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/user_avatar.dart';
import 'package:lendify/widgets/review_prompt_sheet.dart';
import 'package:lendify/services/address_privacy.dart';
import 'package:lendify/widgets/approx_location_map.dart';
import 'package:lendify/screens/support_flow_screen.dart';
import 'package:lendify/widgets/sit_glass_time_picker.dart';
import 'package:lendify/widgets/sit_overflow_menu.dart';
import 'package:lendify/services/handover_code.dart';
import 'package:lendify/utils/total_subtitle.dart';
import 'package:lendify/utils/cancellation_policy_text.dart';

class BookingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  final bool
      viewerIsOwner; // when true, show owner-facing details (e.g., payout, counterparty role = "Mieter")
  const BookingDetailScreen({
    super.key,
    required this.booking,
    this.viewerIsOwner = false,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late final PageController _pageController;
  int _page = 0;
  int? _returnReminderMinutes; // e.g., 2880, 1440, 720, 360, 120
  int _ownerPickupFailCount = 0;
  bool _manualPickupAllowed = false;
  bool _pickupHintOpen = false; // collapsible hint under Abholung
  bool _upcomingPrivacyOpen = false; // collapsible privacy hint for upcoming
  // Renter upcoming: manual code entry toggle + controller
  bool _showManualPickupEntry = false;
  final TextEditingController _manualPickupCodeCtrl = TextEditingController();
  // Owner laufend (Rückgabe bestätigen): manueller Code-Eingabe-Toggle + Controller
  bool _showManualReturnEntry = false;
  final TextEditingController _manualReturnCodeCtrl = TextEditingController();
  // Approximate map center for the listing (if available)
  double? _itemLat;
  double? _itemLng;
  Map<String, dynamic> _flowState = const {};
  bool _reviewAlreadySubmitted = false;

  List<String> get _photos {
    final b = widget.booking;
    final list = (b['images'] as List?)?.cast<String>();
    if (list != null && list.isNotEmpty) return list;
    final single = (b['image'] as String?) ?? '';
    return single.isNotEmpty ? [single] : <String>[];
  }

  bool get _canCancel =>
      widget.booking['category'] == 'upcoming' ||
      widget.booking['category'] == 'pending';
  bool get _isCompletedState {
    final cat = (widget.booking['category'] as String?) ?? '';
    final status = (widget.booking['status'] as String?) ?? '';
    if (cat == 'completed') return true;
    if (status == 'Abgeschlossen' || status == 'Storniert') return true;
    return false;
  }

  bool get _isOngoing {
    // Treat as ongoing using effective category derived from dates + status
    if (_isCompletedState) return false;
    return _effectiveCategory() == 'ongoing';
  }

  bool get _canMessage =>
      (widget.booking['status'] == 'Akzeptiert') ||
      (widget.booking['status'] == 'Laufend');

  bool get _canStartBookingHandover {
    final status = ((widget.booking['status'] as String?) ?? '').trim();
    return status == 'Akzeptiert' && !_isCompletedState && !_isOngoing;
  }

  bool get _canCompleteBookingReturn {
    final status = ((widget.booking['status'] as String?) ?? '').trim();
    return status == 'Laufend' && _isOngoing;
  }

  String get _listerName =>
      (widget.booking['listerName'] as String?) ?? 'Vermieter';
  String? get _listerAvatar => widget.booking['listerAvatar'] as String?;

  (String, String) _splitDatesText() {
    final raw = (widget.booking['dates'] as String?) ?? '';
    if (raw.contains('–')) {
      final parts = raw.split('–');
      final start = parts.first.trim();
      final end = parts.length > 1 ? parts[1].trim() : '';
      return (start, end);
    }
    if (raw.contains('-')) {
      final parts = raw.split('-');
      final start = parts.first.trim();
      final end = parts.length > 1 ? parts[1].trim() : '';
      return (start, end);
    }
    return (raw, '');
  }

  DateTime? _parseGermanDateTime(String s) {
    // Formats like: 10. Jan (without time)
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
    // Normalize month token (e.g., Mär -> Mär)
    String key = monStr.substring(0, 1).toUpperCase() +
        monStr.substring(1, math.min(monStr.length, 3)).toLowerCase();
    if (key == 'Mä' || key == 'Mär') key = 'Mär';
    final month = months[key];
    if (month == null) return null;
    final now = DateTime.now();
    // Assume current year, time defaults to 00:00
    return DateTime(now.year, month, d);
  }

  (DateTime?, DateTime?) _parseDateRange() {
    final (startText, endText) = _splitDatesText();
    final start = _parseGermanDateTime(startText);
    final end = _parseGermanDateTime(endText);
    if (start == null || end == null) return (start, end);
    if (end.isBefore(start)) {
      // If end fell earlier within the same year, assume it crosses into next year
      return (start, DateTime(start.year + 1, end.month, end.day));
    }
    return (start, end);
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Load owner-side failed confirmations to decide when to show manual pickup confirmation for renter
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = _computeBookingId();
      final fails = await DataService.getPickupFailCountForBooking(id);
      if (mounted) {
        setState(() {
          _ownerPickupFailCount = fails;
          _manualPickupAllowed = fails >= 3;
        });
      }
      // Show one-time banner if a handover confirmation happened on the other side
      final msg = await DataService.takeHandoverBanner(id);
      if (msg != null && msg.isNotEmpty && mounted) {
        AppPopup.toast(context, icon: Icons.check_circle_outline, title: msg);
      }
      // Removed: immediate auto-prompt to review after completion. We now schedule a reminder.

      // Load item coordinates for map preview
      try {
        final itemId = widget.booking['itemId'] as String?;
        if (itemId != null && itemId.isNotEmpty) {
          final item = await DataService.getItemById(itemId);
          if (mounted) {
            setState(() {
              _itemLat = item?.lat;
              _itemLng = item?.lng;
            });
          }
        }
        final requestId =
            (widget.booking['requestId'] as String?)?.trim() ?? '';
        if (requestId.isNotEmpty) {
          final state = await DataService.getHandoverReturnState(requestId);
          final current = await DataService.getCurrentUser();
          final alreadyReviewed = current != null
              ? await DataService.hasSubmittedReview(
                  requestId: requestId,
                  reviewerId: current.id,
                )
              : false;
          if (mounted) {
            setState(() {
              _flowState = state;
              _reviewAlreadySubmitted = alreadyReviewed;
            });
          }
        }
      } catch (e) {
        debugPrint('[booking_detail] load item coords failed: ' + e.toString());
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _manualPickupCodeCtrl.dispose();
    _manualReturnCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _openSupportFlow({
    required String requestId,
    required String itemTitle,
  }) async {
    final current = await DataService.getCurrentUser();
    if (!mounted || current == null) return;
    final flowContext = SupportFlowContext.fromBookingDetail(
      itemTitle: itemTitle,
      itemId: (widget.booking['itemId'] as String?) ?? '',
      requestId: requestId,
      bookingStatus: (widget.booking['status'] as String?) ?? '',
      viewerIsOwner: widget.viewerIsOwner,
      otherUserName: widget.viewerIsOwner
          ? ((widget.booking['renterName'] as String?) ?? 'Mieter')
          : _listerName,
      itemImageUrl: _photos.isNotEmpty ? _photos.first : null,
      otherUserImageUrl: widget.viewerIsOwner
          ? (widget.booking['renterAvatar'] as String?)
          : _listerAvatar,
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
          "Support-Fall eröffnet: ${result.mainCategoryLabel} · ${itemTitle.isNotEmpty ? itemTitle : 'Buchung'}\n📋 Support-Anfrage zu: ${itemTitle.isNotEmpty ? itemTitle : 'Buchung'}\nBuchung: $requestId\nKategorie: ${result.mainCategoryLabel}\nUnterkategorie: ${result.subCategory}$descText",
    );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageThreadScreen(
          threadId: supportThread!.id,
          participantName: 'SIT Support',
          itemTitle: 'Support',
        ),
      ),
    );
  }

  Future<void> _manageBookingTime({required bool isReturn}) async {
    final requestId = (widget.booking['requestId'] as String?)?.trim() ?? '';
    if (requestId.isEmpty || !mounted) return;
    final current = await DataService.getCurrentUser();
    if (current == null) return;
    final thread = await DataService.createOrGetThreadForRequest(requestId);
    if (thread == null) {
      AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Zeitabstimmung gerade nicht verfügbar',
      );
      return;
    }
    final state = await DataService.getHandoverReturnState(requestId);
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
          requestId: requestId,
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
        return;
      }
    }
    final (start, end) = _parseDateRange();
    final initial = isReturn
        ? (end ?? DateTime.now().add(const Duration(days: 1)))
        : (start ?? DateTime.now().add(const Duration(hours: 2)));
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
      requestId: requestId,
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
    if (!mounted) return;
    AppPopup.toast(
      context,
      icon: Icons.schedule,
      title: '$flowLabel gesendet',
      message:
          'Die ${isReturn ? 'Rückgabezeit' : 'Übergabezeit'} wurde geändert. Warte auf die Annahme von ${widget.viewerIsOwner ? ((widget.booking['renterName'] as String?) ?? 'der Gegenpartei') : _listerName}, bevor du die ${isReturn ? 'Rückgabe' : 'Übergabe'} starten kannst.',
    );
  }

  Future<bool> _timeConfirmedForStart({required bool isReturn}) async {
    final requestId = (widget.booking['requestId'] as String?)?.trim() ?? '';
    if (requestId.isEmpty) return true;
    final state = await DataService.getHandoverReturnState(requestId);
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

  Future<void> _viewListing() async {
    final ctx = context;
    final title = (widget.booking['title'] as String?)?.toLowerCase() ?? '';
    final tokens = title
        .split(RegExp(r'[^a-z0-9äöüß]+'))
        .where((w) => w.length >= 3)
        .toSet();
    final items = await DataService.getPublicItems();
    int bestScore = 0;
    var bestItem = null;
    for (final it in items) {
      final t = it.title.toLowerCase();
      int s = 0;
      for (final tok in tokens) {
        if (t.contains(tok)) s++;
      }
      if (s > bestScore) {
        bestScore = s;
        bestItem = it;
      }
    }
    if (!mounted) return;
    if (bestItem == null || bestScore == 0) {
      await showDialog<void>(
        context: ctx,
        builder: (dCtx) => AlertDialog(
          title: const Text('Hinweis'),
          content: const Text('Anzeige wurde gelöscht'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    await ItemDetailsOverlay.showFullPage(ctx, item: bestItem);
  }

  String _pageTitle() {
    switch (_effectiveCategory()) {
      case 'upcoming':
        return 'Kommende Buchung';
      case 'ongoing':
        return 'Laufende Buchung';
      case 'pending':
        return 'Ausstehende Buchung';
      case 'completed':
        return widget.booking['needsReview'] == true
            ? 'Buchung in Prüfung'
            : 'Abgeschlossene Buchung';
      default:
        return 'Buchung';
    }
  }

  // Derive an effective category strictly from status.
  // Aligns with list categorization: never auto-advance by time.
  String _effectiveCategory({DateTime? start, DateTime? end}) {
    final rawCat = (widget.booking['category'] as String?)?.toLowerCase() ?? '';
    final rawStatus =
        ((widget.booking['status'] as String?) ?? '').toLowerCase();
    if (widget.booking['needsReview'] == true) {
      return 'completed';
    }
    if (rawCat == 'pending' ||
        rawStatus == 'pending' ||
        rawStatus.contains('ausstehend') ||
        rawStatus.contains('angefragt')) {
      return 'pending';
    }
    if (rawStatus == 'accepted' || rawStatus.contains('akzeptiert')) {
      return 'upcoming';
    }
    if (rawStatus == 'running' || rawStatus.contains('laufend')) {
      return 'ongoing';
    }
    if (rawStatus == 'completed' ||
        rawStatus == 'cancelled' ||
        rawStatus == 'declined' ||
        rawStatus.contains('abgeschlossen') ||
        rawStatus.contains('storniert') ||
        rawStatus.contains('abgelehnt')) {
      return 'completed';
    }
    // Fallback
    return 'upcoming';
  }

  Widget _viewListingOverlay() => Positioned(
        top: 8,
        right: 8,
        child: Material(
          color: Colors.black.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _viewListing,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.visibility_outlined,
                  size: 18, color: Colors.white),
            ),
          ),
        ),
      );

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
                        filter: ui.ImageFilter.blur(sigmaX: 25.2, sigmaY: 25.2),
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
    final theme = Theme.of(context);
    final (pickupText, returnText) = _splitDatesText();

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle()),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () async {
              final (start, end) = _parseDateRange();
              final effective = _effectiveCategory(start: start, end: end);
              final opts = <SitMenuOption<String>>[
                const SitMenuOption(
                  icon: Icons.visibility_rounded,
                  label: 'Anzeige ansehen',
                  value: 'view',
                ),
                if (effective == 'upcoming')
                  const SitMenuOption(
                    icon: Icons.cancel_outlined,
                    label: 'Stornieren',
                    value: 'cancel',
                  ),
                if (effective == 'pending')
                  const SitMenuOption(
                    icon: Icons.undo,
                    label: 'Anfrage zurückziehen',
                    value: 'withdraw',
                  ),
                const SitMenuOption(
                  icon: Icons.error_outline,
                  label: 'Problem melden',
                  value: 'issue',
                ),
              ];
              final picked = await showSITOverflowMenu<String>(
                context,
                options: opts,
              );
              switch (picked) {
                case 'view':
                  await _viewListing();
                  break;
                case 'cancel':
                  await _confirmCancelUpcoming();
                  break;
                case 'withdraw':
                  await _confirmWithdrawPending();
                  break;
                case 'issue':
                  final requestId = widget.booking['requestId'] as String?;
                  final title = (widget.booking['title'] as String?) ?? '-';
                  if (requestId == null || requestId.isEmpty) {
                    _toast('Keine Buchungs-ID');
                  } else {
                    if (mounted) {
                      await _openSupportFlow(
                        requestId: requestId,
                        itemTitle: title,
                      );
                    }
                  }
                  break;
                default:
              }
            },
          ),
        ],
      ),
      // Bottom actions
      bottomNavigationBar: Builder(
        builder: (context) {
          // Show bottom-anchored actions depending on effective booking state
          final statusLc =
              ((widget.booking['status'] as String?) ?? '').toLowerCase();
          final (s, e) = _parseDateRange();
          final effective = _effectiveCategory(start: s, end: e);
          final isTrulyCompleted = effective == 'completed' &&
              !statusLc.contains('storniert') &&
              !statusLc.contains('abgelehnt');
          final isRenterView = !_isViewerOwnerSync();
          final isHeldForReview = widget.booking['needsReview'] == true;

          Widget? child;
          if (isTrulyCompleted && isRenterView && !isHeldForReview) {
            child = SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: _reviewAlreadySubmitted
                    ? null
                    : () async {
                        final current = await DataService.getCurrentUser();
                        final requestId =
                            widget.booking['requestId'] as String?;
                        final itemId = widget.booking['itemId'] as String?;
                        final listerId = widget.booking['listerId'] as String?;
                        if (current == null ||
                            requestId == null ||
                            itemId == null ||
                            listerId == null) {
                          return;
                        }
                        final ok = await ReviewPromptSheet.show(
                          context,
                          requestId: requestId,
                          itemId: itemId,
                          reviewerId: current.id,
                          reviewedUserId: listerId,
                          direction: 'renter_to_owner',
                        );
                        if (ok == true && mounted) {
                          setState(() => _reviewAlreadySubmitted = true);
                          await AppPopup.toast(
                            context,
                            icon: Icons.star_rate_outlined,
                            title: 'Danke für deine Bewertung!',
                          );
                          await _viewListing();
                        } else if (ok == false && mounted) {
                          setState(() => _reviewAlreadySubmitted = true);
                          await AppPopup.toast(
                            context,
                            icon: Icons.check_circle_outline,
                            title: 'Bewertung abgegeben',
                          );
                        }
                      },
                icon: Icon(
                  _reviewAlreadySubmitted
                      ? Icons.check_circle_outline
                      : Icons.star_rate_outlined,
                ),
                label: Text(
                  _reviewAlreadySubmitted ? 'Bewertung abgegeben' : 'Bewerten',
                ),
              ),
            );
          } else if (effective == 'pending' && isRenterView) {
            // Anchor the withdraw button at the very bottom for pending renter view
            child = SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _confirmWithdrawPending,
                icon: const Icon(Icons.undo),
                label: const Text('Anfrage zurückziehen'),
              ),
            );
          }

          if (child == null) return const SizedBox.shrink();
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: child,
            ),
          );
        },
      ),
      body: SafeArea(
        child: _isOngoing
            ? _buildOngoingBody(theme)
            : _buildDefaultBody(theme, pickupText, returnText),
      ),
    );
  }

  Widget _buildOngoingBody(ThemeData theme) {
    final (start, end) = _parseDateRange();
    final now = DateTime.now();
    final due = end;
    final diff = (due != null) ? due.difference(now) : const Duration(hours: 0);
    final isOverdue = due != null && now.isAfter(due);

    final title = (widget.booking['title'] as String?) ?? '-';
    final location = (widget.booking['location'] as String?) ?? '';
    final pricePaidStr = (widget.booking['pricePaid'] as String?) ?? '';
    final bookingId = _computeBookingId();

    final days = (start != null && end != null)
        ? end.difference(start).inDays.clamp(1, 365)
        : 1;
    final totalPaid = _parseEuro(pricePaidStr);
    final discounts = _discountsFromBooking();
    final providedBasePerDay =
        (widget.booking['basePerDay'] as num?)?.toDouble();
    final baseTotal =
        providedBasePerDay != null ? (providedBasePerDay * days) : totalPaid;
    final rentalSubtotal = (baseTotal - discounts).clamp(0.0, baseTotal);
    final fee = DataService.platformContributionForRental(rentalSubtotal);
    final daily = days > 0 ? (rentalSubtotal / days) : rentalSubtotal;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Image carousel
        if (_photos.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              height: 220,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _photos.length,
                    itemBuilder: (_, i) => SizedBox(
                      width: double.infinity,
                      height: 220,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            _showImagePreview(_photos, initialIndex: i),
                        child: AppImage(url: _photos[i], fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  _viewListingOverlay(),
                  if (_photos.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < _photos.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _page ? 12 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == _page
                                    ? theme.colorScheme.primary
                                    : Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                  // Status chip bottom-left overlay (all states)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Builder(
                      builder: (context) {
                        final (start, end) = _parseDateRange();
                        final effective = _effectiveCategory(
                          start: start,
                          end: end,
                        );
                        final status =
                            (widget.booking['status'] as String?) ?? '';
                        String label;
                        Color color;
                        if (effective == 'completed') {
                          final cancelled =
                              status == 'Storniert' || status == 'Abgelehnt';
                          final heldForReview =
                              widget.booking['needsReview'] == true;
                          label = cancelled
                              ? 'Storniert'
                              : (heldForReview
                                  ? 'In Prüfung'
                                  : 'Abgeschlossen');
                          color = cancelled
                              ? const Color(0xFFF43F5E)
                              : (heldForReview
                                  ? const Color(0xFFF59E0B)
                                  : Colors.blueGrey);
                        } else if (effective == 'pending') {
                          label = 'Anfrage';
                          color = Colors.grey;
                        } else if (effective == 'upcoming') {
                          label = 'Kommend';
                          color = _statusColor('Akzeptiert');
                        } else {
                          label = 'Laufend';
                          color = _statusColor('Laufend');
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Countdown pill inside the image (bottom-right) for laufend
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
                                    : theme.colorScheme.primary)
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
                  // end stack children
                ],
              ),
            ),
          ),

        // Removed the row with status + actions – chip is back in the image
        const SizedBox(height: 12),

        // Centered title above the info card
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 16),
        // Details card (modernized)
        _ModernDetailsCard(
          title: null, // show big centered title above the card
          photoUrl: null, // Thumbnail removed per request
          onViewListing: _viewListing,
          datesText: (widget.booking['dates'] as String?) ?? '-',
          durationText: (start != null && end != null)
              ? _formatDaysHours(end.difference(start))
              : null,
          onAddPickupToCalendar: null, // Calendar links removed per request
          onAddReturnToCalendar: null,
          location: location,
          onMap: () => _openMaps(location),
          onNav: () => _openDirections(location),
          bookingId: bookingId,
          counterpartyName: _listerName,
          counterpartyAvatar: _listerAvatar,
          counterpartyRole: widget.viewerIsOwner ? 'Mieter' : 'Vermieter',
          onCounterpartyProfile: null, // Counterparty row removed inside card
          // Hide message button for pending (Ausstehende Buchung)
          onMessage: (() {
            final (s, e) = _parseDateRange();
            final eff = _effectiveCategory(start: s, end: e);
            if (eff == 'pending' ||
                widget.booking['needsReview'] == true ||
                eff == 'completed') {
              return null;
            }
            return () {
              final reqId = (widget.booking['requestId'] ?? '').toString();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MessageThreadScreen(
                    requestId: reqId.isNotEmpty ? reqId : null,
                    participantName: _listerName,
                    avatarUrl: _listerAvatar,
                    itemTitle: (widget.booking['title'] as String?),
                  ),
                ),
              );
            };
          }()),
          // Locations moved out of the info card in all sections
          showLocations: false,
          transportInfo: () {
            // For laufend we show return side, for others pickup side
            final renterPicksUpSelf =
                (widget.booking['ownerDeliversAtDropoffChosen'] == true)
                    ? false
                    : true;
            final renterReturnsSelf =
                (widget.booking['ownerPicksUpAtReturnChosen'] == true)
                    ? false
                    : true;
            try {
              final (s, e) = _parseDateRange();
              final eff = _effectiveCategory(start: s, end: e);
              debugPrint(
                '[BookingDetail] transportInfo A: requestId=' +
                    ((widget.booking['requestId'] ?? '')).toString() +
                    ' ownerDeliversAtDropoffChosen=' +
                    ((widget.booking['ownerDeliversAtDropoffChosen'] == true)
                        .toString()) +
                    ' ownerPicksUpAtReturnChosen=' +
                    ((widget.booking['ownerPicksUpAtReturnChosen'] == true)
                        .toString()) +
                    ' effective=' +
                    eff,
              );
            } catch (_) {}
            if (_isOngoing) {
              return renterReturnsSelf
                  ? 'Du bringst den Artikel selbst zurück.'
                  : 'Der Vermieter holt den Artikel wieder ab.';
            } else {
              final (s, e) = _parseDateRange();
              final eff = _effectiveCategory(start: s, end: e);
              if (renterPicksUpSelf) {
                return eff == 'pending'
                    ? 'Du holst den Artikel selbst ab, wenn deine Anfrage akzeptiert wird.'
                    : 'Du holst den Artikel selbst ab.';
              } else {
                return eff == 'pending'
                    ? 'Wenn ${_listerName} deine Anfrage annimmt, bringt er dir den Artikel vorbei.'
                    : 'Der Vermieter bringt dir den Artikel.';
              }
            }
          }(),
        ),

        if (_confirmedLocationText(false) != null) ...[
          const SizedBox(height: 12),
          _AddressInfoCard(
            icon: Icons.place_outlined,
            text: _confirmedLocationText(false)!,
          ),
        ],
        if (_confirmedLocationMapsUrl(false).isNotEmpty) ...[
          const SizedBox(height: 6),
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
          _AddressInfoCard(
            icon: Icons.place,
            text: _confirmedLocationText(true)!,
          ),
        ],
        if (_confirmedLocationMapsUrl(true).isNotEmpty) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openConfirmedLocationUrl(true),
              child: const Text('In Google Maps öffnen'),
            ),
          ),
        ],

        // Ongoing (Laufend): Karte für Rückgabe, falls der Mieter selbst zurückbringt –
        // identisches Verhalten wie die Abhol‑Karte in „Kommende Buchung"
        Builder(
          builder: (context) {
            final renterReturnsSelf =
                (widget.booking['ownerPicksUpAtReturnChosen'] == true)
                    ? false
                    : true;
            if (!renterReturnsSelf) return const SizedBox.shrink();
            final label = AddressPrivacy.nearbyShort(kindLabel: 'Rückgabe');
            final fullAddress = (widget.booking['location'] as String?) ?? '';
            // For ongoing bookings, always show the exact address
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: ApproxLocationMap(
                    lat: _itemLat,
                    lng: _itemLng,
                    label: label,
                  ),
                ),
                const SizedBox(height: 8),
                _AddressInfoCard(
                  icon: Icons.place_outlined,
                  text: 'Rückgabeort: $fullAddress',
                ),
              ],
            );
          },
        ),

        // Non-collapsible privacy/address info is shown above – remove old expandable tile

        // (moved later) Next steps for laufend
        const SizedBox(height: 16),
        // Cancellation policy must appear directly above the payment summary
        _CancellationPolicyCard(booking: widget.booking),
        const SizedBox(height: 12),
        // Payment summary
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          padding: const EdgeInsets.all(12),
          child: Builder(
            builder: (context) {
              final pricePaidStr =
                  (widget.booking['pricePaid'] as String?) ?? '';
              final totalPaidLegacy = _parseEuro(pricePaidStr);
              final daysLocal = (start != null && end != null)
                  ? end.difference(start).inDays.clamp(1, 365)
                  : 1;
              final providedBasePerDay =
                  (widget.booking['basePerDay'] as num?)?.toDouble();
              final discountAmountProvided = _discountsFromBooking();
              final baseTotal = (providedBasePerDay ?? 0.0) * daysLocal;
              final rentalSubtotalLocal =
                  (baseTotal - discountAmountProvided).clamp(0.0, baseTotal);
              final feeLocal = DataService.platformContributionForRental(
                rentalSubtotalLocal,
              );
              // Delivery/return/express fees derived from stored selection + item coords
              final bool ownerDelivers =
                  (widget.booking['ownerDeliversAtDropoffChosen'] == true) ||
                      (widget.booking['expressRequested'] == true) ||
                      (widget.booking['expressStatus'] != null) ||
                      ((widget.booking['deliveryAddressLine'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ||
                      ((widget.booking['deliveryCity'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty);
              final bool ownerPicks =
                  (widget.booking['ownerPicksUpAtReturnChosen'] == true);
              double km = 0.0;
              final double? dLat =
                  (widget.booking['deliveryLat'] as num?)?.toDouble();
              final double? dLng =
                  (widget.booking['deliveryLng'] as num?)?.toDouble();
              if (_itemLat != null &&
                  _itemLng != null &&
                  dLat != null &&
                  dLng != null) {
                km = DataService.estimateDistanceKm(
                  _itemLat!,
                  _itemLng!,
                  dLat,
                  dLng,
                );
              } else if (_itemLat != null &&
                  _itemLng != null &&
                  ((widget.booking['deliveryAddressLine'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty)) {
                km = DataService.estimateDistanceKmFromAddressLine(
                  _itemLat!,
                  _itemLng!,
                  (widget.booking['deliveryAddressLine'] as String).trim(),
                );
              } else if (_itemLat != null &&
                  _itemLng != null &&
                  ((widget.booking['deliveryCity'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty)) {
                km = DataService.estimateDistanceKmToCity(
                  _itemLat!,
                  _itemLng!,
                  (widget.booking['deliveryCity'] as String).trim(),
                );
              }
              final double dropFee = ownerDelivers
                  ? double.parse((km * 0.30).toStringAsFixed(2))
                  : 0.0;
              final double retFee = ownerPicks
                  ? double.parse((km * 0.30).toStringAsFixed(2))
                  : 0.0;
              final bool expressSelected =
                  (widget.booking['expressRequested'] == true) ||
                      (widget.booking['expressStatus'] == 'accepted');
              final bool expressAccepted =
                  (widget.booking['expressStatus'] == 'accepted');
              final double expressFee = expressSelected ? 5.0 : 0.0;
              final double expressFeePlatform = expressFee > 0
                  ? double.parse((expressFee * 0.10).toStringAsFixed(2))
                  : 0.0;
              final double totalPaid = double.parse(
                (rentalSubtotalLocal +
                        feeLocal +
                        dropFee +
                        retFee +
                        expressFee +
                        expressFeePlatform)
                    .toStringAsFixed(2),
              );
              final payoutEst = double.parse(
                (rentalSubtotalLocal +
                        dropFee +
                        retFee +
                        (expressAccepted ? 5.0 : 0.0))
                    .toStringAsFixed(2),
              );
              if (_isViewerOwnerSync()) {
                final isHeldForReview = widget.booking['needsReview'] == true;
                // Owner view: show only payout, no details
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            isHeldForReview
                                ? 'Wird geprüft'
                                : 'Vorauss. Auszahlung',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isHeldForReview
                                  ? 'Wird geprüft'
                                  : _formatEuro(payoutEst),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (!isHeldForReview)
                      Text(
                        end != null
                            ? 'Auszahlung am ${_formatPayoutDate(end)}'
                            : 'Auszahlung nach Rückgabe',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                  ],
                );
              }
              // Renter view: detailed breakdown for laufend
              return Column(
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
                  if (discountAmountProvided > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.percent_outlined,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Langzeitmiet‑Rabatt aktiv.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (providedBasePerDay != null)
                    _AmountRow(
                      label:
                          'Grundpreis: ${_formatEuro(providedBasePerDay)} × $daysLocal',
                      value: _formatEuro(baseTotal),
                    ),
                  if (discountAmountProvided > 0)
                    _AmountRow(
                      label: 'Rabatt',
                      value: '-${_formatEuro(discountAmountProvided)}',
                    ),
                  _AmountRow(
                    label: 'Zwischensumme (Mietpreis)',
                    value: _formatEuro(rentalSubtotalLocal),
                  ),
                  if (dropFee > 0)
                    _AmountRow(
                      label: 'Lieferung (Abgabe)',
                      value: _formatEuro(dropFee),
                    ),
                  if (retFee > 0)
                    _AmountRow(
                      label: 'Abholung (Rückgabe)',
                      value: _formatEuro(retFee),
                    ),
                  if (expressFee > 0)
                    _AmountRow(
                      label: 'Prioritätszuschlag',
                      value: _formatEuro(expressFee),
                    ),
                  if (expressFeePlatform > 0)
                    _AmountRow(
                      label: 'Plattformbeitrag auf Priorität (10%)',
                      value: _formatEuro(expressFeePlatform),
                    ),
                  _AmountRow(
                    label: 'Plattformbeitrag',
                    value: _formatEuro(feeLocal),
                  ),
                  const Divider(height: 16, color: Colors.white24),
                  _AmountRow(
                    label: 'Gesamt bezahlt (Mieter)',
                    value: _formatEuro(totalPaid),
                    strong: true,
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 16),
        // Übergabe-Karte (mit Code + QR) nur zeigen, wenn der Viewer Vermieter ist.
        // Dieser Block befindet sich im laufenden View.
        if (_isViewerOwnerSync())
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
                  'Übergabe',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.vpn_key, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      'Übergabe-Code',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _pickupOwnerCode(),
                        style: const TextStyle(
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    onTap: () => _showQrOverlay(
                      context,
                      HandoverCodeService.qrPayload(
                        segment: HandoverCodeService.segmentPickup,
                        presenterRole: HandoverCodeService.presenterOwner,
                        code: _pickupOwnerCode(),
                        bookingId: bookingId,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.35),
                            blurRadius: 14,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(8),
                          child: QrImageView(
                            data: HandoverCodeService.qrPayload(
                              segment: HandoverCodeService.segmentPickup,
                              presenterRole: HandoverCodeService.presenterOwner,
                              code: _pickupOwnerCode(),
                              bookingId: bookingId,
                            ),
                            version: QrVersions.auto,
                            size: 140,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Per request: remove Check-in/Check-out photo buttons in ongoing view
              ],
            ),
          ),

        // Owner – Laufende Anmietung: Rückgabe bestätigen (QR scannen oder Code eingeben)
        // Nur in "Laufend" sichtbar, nicht in "Kommend" oder anderen Zuständen.
        if (_isViewerOwnerSync() && _isOngoing) ...[
          const SizedBox(height: 12),
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
                  'Artikelrückgabe bestätigen',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _startScanRenterQrForReturn,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('QR‑Code vom Mieter scannen'),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(
                      () => _showManualReturnEntry = !_showManualReturnEntry,
                    ),
                    child: Text(
                      _showManualReturnEntry
                          ? 'Eingabe ausblenden'
                          : 'QR‑Scan nicht möglich?',
                    ),
                  ),
                ),
                if (_showManualReturnEntry) ...[
                  const SizedBox(height: 4),
                  Text(
                    '🔒 Code manuell eingeben (6‑stellig)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _manualReturnCodeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '6‑stelliger Rückgabecode',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _confirmManualReturnByCode,
                          icon: const Icon(Icons.key),
                          label: const Text('Code bestätigen'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 0),
                // Aufklappbarer Hinweis (kleiner Titel, randloser Text)
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    collapsedIconColor: Colors.white70,
                    iconColor: Colors.white70,
                    leading: const Icon(
                      Icons.info_outline,
                      color: Colors.white70,
                    ),
                    title: Text(
                      'Hinweis',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    childrenPadding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 0,
                          right: 0,
                          bottom: 6,
                        ),
                        child: Text(
                          'Bitte den Mieter, in seinem Bereich „Laufende Buchungen“, eure Buchung zu wählen und dort die Rückgabe zu starten. Erst dann sind der QR‑Code und der 6‑stellige Code für dich sichtbar.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Removed: messaging tile and status timeline per request
        const SizedBox(height: 12),

        if (isOverdue && widget.viewerIsOwner) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF43F5E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.24),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF43F5E),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Überfällig – bitte Rückgabe jetzt starten',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _startOwnerReturnFlow,
                  child: const Text('Jetzt starten'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Bottom actions (moved here per request)
        if (!widget.viewerIsOwner) ...[
          // Place "Was passiert als Nächstes?" directly above the button
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
                children: const [
                  _Bullet(
                    text:
                        'Triff dich mit dem Vermieter zum vereinbarten Rückgabezeitpunkt.',
                  ),
                  _Bullet(
                    text:
                        'Klicke auf „Rückgabe starten“, wenn ihr euch trefft.',
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
                        'Tippe auf „Abschließen“, um die Rückgabe abzuschließen.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!widget.viewerIsOwner && widget.booking['needsReview'] != true) ...[
          _InlineTimeActionButton(
            icon: Icons.undo_rounded,
            label: 'Rückgabezeit',
            onTap: () => _manageBookingTime(isReturn: true),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () async {
              if (!await _timeConfirmedForStart(isReturn: true)) return;
              await _startOwnerReturnFlow();
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(
              isOverdue ? 'Rückgabe jetzt starten' : 'Rückgabe starten',
            ),
          ),
        ],
        // Hinweis: "Problem melden" nur in abgeschlossenen Buchungen anzeigen (siehe weiter unten in isCompleted‑Block)
      ],
    );
  }

  Widget _buildDefaultBody(
    ThemeData theme,
    String pickupText,
    String returnText,
  ) {
    final (start, end) = _parseDateRange();
    final now = DateTime.now();
    final effective = _effectiveCategory(start: start, end: end);
    final isUpcoming = effective == 'upcoming';
    final isPending = effective == 'pending';
    final isCompleted = effective == 'completed';
    final status = (widget.booking['status'] as String?) ?? '';
    final isCancelled = status == 'Storniert';
    final isDeclined = status == 'Abgelehnt';

    // Derive pricing breakdown
    final pricePaidStr = (widget.booking['pricePaid'] as String?) ?? '';
    final totalPaid = _parseEuro(pricePaidStr);
    final days = (start != null && end != null)
        ? end.difference(start).inDays.clamp(1, 365)
        : 1;
    final providedBasePerDay =
        (widget.booking['basePerDay'] as num?)?.toDouble();
    final discountPercentProvided =
        (widget.booking['discountPercentApplied'] as num?)?.toDouble() ?? 0.0;
    final discountAmountProvided = _discountsFromBooking();
    double baseTotal;
    double discountAmount;
    if (providedBasePerDay != null) {
      baseTotal = (providedBasePerDay * days);
      discountAmount = discountAmountProvided;
    } else {
      // Fallback: infer from totals
      final feeTmp = _serviceFee(totalPaid);
      final rentalSubtotalTmp =
          (totalPaid - feeTmp + discountAmountProvided).clamp(0.0, totalPaid);
      baseTotal = rentalSubtotalTmp;
      discountAmount = discountAmountProvided;
    }
    final fee = _serviceFee(totalPaid);
    final rentalSubtotal = (baseTotal - discountAmount).clamp(0.0, totalPaid);
    final daily = days > 0 ? (rentalSubtotal / days) : rentalSubtotal;

    // Unified policy uses calendar days only; no specific deadline label shown here
    final DateTime? cancellationDeadline = null;
    final canStillCancel = _canCancel && (start == null || now.isBefore(start));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_photos.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              height: 220,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _photos.length,
                    itemBuilder: (_, i) => SizedBox(
                      width: double.infinity,
                      height: 220,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            _showImagePreview(_photos, initialIndex: i),
                        child: AppImage(url: _photos[i], fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  _viewListingOverlay(),
                  if (_photos.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < _photos.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _page ? 12 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == _page
                                    ? theme.colorScheme.primary
                                    : Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                  // Status chip bottom-left overlay (all states)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Builder(
                      builder: (context) {
                        final effectiveLocal = effective;
                        final status =
                            (widget.booking['status'] as String?) ?? '';
                        String label;
                        Color color;
                        if (effectiveLocal == 'completed') {
                          final cancelled =
                              status == 'Storniert' || status == 'Abgelehnt';
                          final heldForReview =
                              widget.booking['needsReview'] == true;
                          label = cancelled
                              ? 'Storniert'
                              : (heldForReview
                                  ? 'In Prüfung'
                                  : 'Abgeschlossen');
                          color = cancelled
                              ? const Color(0xFFF43F5E)
                              : (heldForReview
                                  ? const Color(0xFFF59E0B)
                                  : Colors.blueGrey);
                        } else if (effectiveLocal == 'pending') {
                          label = 'Anfrage';
                          color = Colors.grey;
                        } else if (effectiveLocal == 'upcoming') {
                          label = 'Kommend';
                          color = _statusColor('Akzeptiert');
                        } else {
                          label = 'Laufend';
                          color = _statusColor('Laufend');
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Pickup countdown pill overlay for upcoming bookings (bottom-right on image)
                  if (isUpcoming && start != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Builder(
                        builder: (context) {
                          final now = DateTime.now();
                          final diff = start.difference(now);
                          final ownerDeliversAtDropoff = (widget.booking[
                                      'ownerDeliversAtDropoffChosen'] ==
                                  true) ||
                              (widget.booking['expressRequested'] == true) ||
                              (widget.booking['expressStatus'] == 'accepted');
                          final modeLabel =
                              ownerDeliversAtDropoff ? 'Lieferung' : 'Abholung';
                          final text = _formatPickupCountdown(
                            diff,
                            modeLabel: modeLabel,
                          );
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
                  // end stack children
                ],
              ),
            ),
          ),

        // Removed row with status + actions – chip moved into the image; actions moved to overlays/menu

        // Reduce the gap after the top status row for declined as well
        SizedBox(
          height:
              (isCancelled || isDeclined || isPending || isUpcoming) ? 6 : 12,
        ),
        // Header chip row removed (status chip now overlays the image)
        if (false) const SizedBox.shrink(),

        SizedBox(height: isCancelled ? 8 : 12),
        Text(
          (widget.booking['title'] as String?) ?? '-',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 16),
        // Details card (modernized)
        _ModernDetailsCard(
          title: null, // Titel steht bereits oben groß
          photoUrl: null, // Thumbnail removed per request
          onViewListing: _viewListing,
          datesText: (widget.booking['dates'] as String?) ?? '-',
          durationText: (start != null && end != null)
              ? _formatDaysHours(end.difference(start))
              : null,
          onAddPickupToCalendar: null, // Calendar links removed per request
          onAddReturnToCalendar: null,
          location: (widget.booking['location'] as String?) ?? '-',
          onMap: () =>
              _openMaps((widget.booking['location'] as String?) ?? '-'),
          onNav: () =>
              _openDirections((widget.booking['location'] as String?) ?? '-'),
          bookingId: isPending ? '' : _computeBookingId(),
          counterpartyName: _listerName,
          counterpartyAvatar: _listerAvatar,
          counterpartyRole: 'Vermieter',
          onCounterpartyProfile: () {
            final listerId = widget.booking['listerId'] as String?;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PublicProfileScreen(userId: listerId),
              ),
            );
          },
          counterpartyRating: null,
          counterpartyReviews: null,
          // Remove message button in pending
          onMessage: (isPending ||
                  widget.booking['needsReview'] == true ||
                  _isCompletedState)
              ? null
              : () {
                  final reqId = (widget.booking['requestId'] ?? '').toString();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MessageThreadScreen(
                        requestId: reqId.isNotEmpty ? reqId : null,
                        participantName: _listerName,
                        avatarUrl: _listerAvatar,
                        itemTitle: (widget.booking['title'] as String?),
                      ),
                    ),
                  );
                },
          // Locations moved out of the info card for all sections
          showLocations: false,
          transportInfo: () {
            final renterPicksUpSelf =
                (widget.booking['ownerDeliversAtDropoffChosen'] == true)
                    ? false
                    : true;
            final renterReturnsSelf =
                (widget.booking['ownerPicksUpAtReturnChosen'] == true)
                    ? false
                    : true;
            if (_isOngoing) {
              // Laufend: Rückgabe-Info abhängig von der gewählten Rückgabeart
              return renterReturnsSelf
                  ? 'Du bringst den Artikel selbst zurück.'
                  : 'Der Vermieter holt den Artikel wieder ab.';
            } else if (isPending || isUpcoming) {
              if (renterPicksUpSelf) {
                return isPending
                    ? 'Du holst den Artikel selbst ab, wenn deine Anfrage akzeptiert wird.'
                    : 'Du holst den Artikel selbst ab.';
              }
              // Lieferung gewählt: In Ausstehend klarstellen, dass erst nach Annahme geliefert wird
              return isPending
                  ? 'Wenn ${_listerName} deine Anfrage annimmt, bringt er dir den Artikel vorbei.'
                  : 'Der Vermieter bringt dir den Artikel.';
            }
            return null;
          }(),
        ),

        // Approximate pickup map directly under the info card (only for the traveler)
        if (isUpcoming)
          Builder(
            builder: (context) {
              final renterPicksUpSelf =
                  (widget.booking['ownerDeliversAtDropoffChosen'] == true)
                      ? false
                      : true;
              if (!renterPicksUpSelf) return const SizedBox.shrink();
              final label = AddressPrivacy.nearbyShort(kindLabel: 'Abholung');
              final fullAddress = (widget.booking['location'] as String?) ?? '';
              final requestStatus = ((widget.booking['statusRaw'] as String?) ??
                      (widget.booking['status'] as String?) ??
                      '')
                  .trim()
                  .toLowerCase();
              final isAccepted = requestStatus == 'accepted' ||
                  requestStatus.contains('akzeptiert');
              final revealExactAddress =
                  AddressPrivacy.shouldRevealExactAddress(
                handoverAt: start,
                isAccepted: isAccepted,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: ApproxLocationMap(
                      lat: _itemLat,
                      lng: _itemLng,
                      label: label,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _AddressInfoCard(
                    icon: revealExactAddress
                        ? Icons.place_outlined
                        : Icons.lock_outline,
                    text: revealExactAddress && fullAddress.isNotEmpty
                        ? 'Abholort: $fullAddress'
                        : 'Die genaue Adresse wird rechtzeitig vor der Übergabe angezeigt.',
                  ),
                ],
              );
            },
          ),

        // Pending (Ausstehend): gleiche Kartenlogik wie Kommend, falls der Mieter selbst abholt
        if (isPending)
          Builder(
            builder: (context) {
              final renterPicksUpSelf =
                  (widget.booking['ownerDeliversAtDropoffChosen'] == true)
                      ? false
                      : true;
              try {
                debugPrint(
                  '[BookingDetail] pending map visibility: requestId=' +
                      ((widget.booking['requestId'] ?? '')).toString() +
                      ' ownerDeliversAtDropoffChosen=' +
                      ((widget.booking['ownerDeliversAtDropoffChosen'] == true)
                          .toString()) +
                      ' showMap=' +
                      (renterPicksUpSelf).toString(),
                );
              } catch (_) {}
              if (!renterPicksUpSelf) return const SizedBox.shrink();
              final label = AddressPrivacy.nearbyShort(kindLabel: 'Abholung');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: ApproxLocationMap(
                      lat: _itemLat,
                      lng: _itemLng,
                      label: label,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _AddressInfoCard(
                    icon: Icons.lock_outline,
                    text: AddressPrivacy.privacyNoticePickup(),
                  ),
                ],
              );
            },
          ),

        // Ongoing (Laufend): Karte für Rückgabe, falls der Mieter selbst zurückbringt
        if (_isOngoing && widget.booking['needsReview'] != true)
          Builder(
            builder: (context) {
              final renterReturnsSelf =
                  (widget.booking['ownerPicksUpAtReturnChosen'] == true)
                      ? false
                      : true;
              if (!renterReturnsSelf) return const SizedBox.shrink();
              final label = AddressPrivacy.nearbyShort(kindLabel: 'Rückgabe');
              final fullAddress = (widget.booking['location'] as String?) ?? '';
              // For ongoing bookings, always show the exact address
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: ApproxLocationMap(
                      lat: _itemLat,
                      lng: _itemLng,
                      label: label,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _AddressInfoCard(
                    icon: Icons.place_outlined,
                    text: 'Rückgabeort: $fullAddress',
                  ),
                ],
              );
            },
          ),

        // Old collapsible privacy card removed – now shown as a fixed card directly under maps

        // Removed per request: no Stornierungsbedingungen directly under Adressanzeige & Datenschutz
        // (We will show it once near the bottom and control its order there.)

        // Vermieter-Zeile befindet sich jetzt innerhalb der Info-Card (unter Buchungs-ID)
        // Note: Stornierungsbedingungen are shown once directly above the Zahlungsübersicht below

        // Removed separate top-level Übergabe-Button to avoid duplication.
        const SizedBox(height: 16),
        // Show cancellation policy above the payment summary, except for truly completed (Abgeschlossen)
        if (status != 'Abgeschlossen') ...[
          _CancellationPolicyCard(booking: widget.booking),
          const SizedBox(height: 12),
        ],
        // Payment summary
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          padding: const EdgeInsets.all(12),
          child: Builder(
            builder: (context) {
              // Delivery/return/express fees for total computation (align with ongoing logic)
              final bool ownerDelivers =
                  (widget.booking['ownerDeliversAtDropoffChosen'] == true) ||
                      (widget.booking['expressRequested'] == true) ||
                      (widget.booking['expressStatus'] != null) ||
                      ((widget.booking['deliveryAddressLine'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ||
                      ((widget.booking['deliveryCity'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty);
              final bool ownerPicks =
                  (widget.booking['ownerPicksUpAtReturnChosen'] == true);
              double km = 0.0;
              final double? dLat =
                  (widget.booking['deliveryLat'] as num?)?.toDouble();
              final double? dLng =
                  (widget.booking['deliveryLng'] as num?)?.toDouble();
              if (_itemLat != null &&
                  _itemLng != null &&
                  dLat != null &&
                  dLng != null) {
                km = DataService.estimateDistanceKm(
                  _itemLat!,
                  _itemLng!,
                  dLat,
                  dLng,
                );
              } else if (_itemLat != null &&
                  _itemLng != null &&
                  ((widget.booking['deliveryAddressLine'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty)) {
                km = DataService.estimateDistanceKmFromAddressLine(
                  _itemLat!,
                  _itemLng!,
                  (widget.booking['deliveryAddressLine'] as String).trim(),
                );
              } else if (_itemLat != null &&
                  _itemLng != null &&
                  ((widget.booking['deliveryCity'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty)) {
                km = DataService.estimateDistanceKmToCity(
                  _itemLat!,
                  _itemLng!,
                  (widget.booking['deliveryCity'] as String).trim(),
                );
              }
              final double dropFee = ownerDelivers
                  ? double.parse((km * 0.30).toStringAsFixed(2))
                  : 0.0;
              final double retFee = ownerPicks
                  ? double.parse((km * 0.30).toStringAsFixed(2))
                  : 0.0;
              final bool expressSelected =
                  (widget.booking['expressRequested'] == true) ||
                      (widget.booking['expressStatus'] == 'accepted');
              final bool expressAccepted =
                  (widget.booking['expressStatus'] == 'accepted');
              final double expressFee = expressSelected ? 5.0 : 0.0;
              final double expressFeePlatform = expressFee > 0
                  ? double.parse((expressFee * 0.10).toStringAsFixed(2))
                  : 0.0;
              final totalRenter = (rentalSubtotal +
                      fee +
                      dropFee +
                      retFee +
                      expressFee +
                      expressFeePlatform)
                  .clamp(0.0, double.infinity);
              if (_isViewerOwnerSync()) {
                final isHeldForReview = widget.booking['needsReview'] == true;
                // Owner view: payout berücksichtigt Lieferung/Abholung/Priorität (keine Plattformgebühr)
                final payoutOwner = double.parse(
                  (rentalSubtotal +
                          dropFee +
                          retFee +
                          (expressAccepted ? 5.0 : 0.0))
                      .toStringAsFixed(2),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            isHeldForReview
                                ? 'Wird geprüft'
                                : 'Vorauss. Auszahlung',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isHeldForReview
                                  ? 'Wird geprüft'
                                  : _formatEuro(payoutOwner),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (!isHeldForReview)
                      Text(
                        end != null
                            ? 'Auszahlung am ${_formatPayoutDate(end)}'
                            : 'Auszahlung nach Rückgabe',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                  ],
                );
              }
              if (isPending || isUpcoming) {
                // Renter view – show the exact quoted total & subtitle captured at booking time
                final double shownTotal =
                    (widget.booking['quotedTotalRenter'] as num?)?.toDouble() ??
                        totalRenter;
                final String subtitle =
                    (widget.booking['quotedSubtitle'] as String?) ??
                        TotalSubtitleHelper.build(
                          delivery: ownerDelivers,
                          pickup: ownerPicks,
                          priority: expressSelected,
                        );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          'Gesamtbetrag',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _formatEuro(shownTotal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              }
              // Other renter states keep detailed breakdown
              return Column(
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
                  _AmountRow(
                    label: 'Mietpreis (Tagespreis × Tage)',
                    value: _formatEuro(rentalSubtotal),
                  ),
                  if (dropFee > 0)
                    _AmountRow(
                      label: 'Lieferung (Abgabe)',
                      value: _formatEuro(dropFee),
                    ),
                  if (retFee > 0)
                    _AmountRow(
                      label: 'Abholung (Rückgabe)',
                      value: _formatEuro(retFee),
                    ),
                  if (expressFee > 0)
                    _AmountRow(
                      label: 'Prioritätszuschlag',
                      value: _formatEuro(expressFee),
                    ),
                  if (expressFeePlatform > 0)
                    _AmountRow(
                      label: 'Plattformbeitrag auf Priorität (10%)',
                      value: _formatEuro(expressFeePlatform),
                    ),
                  _AmountRow(
                    label: 'Plattformbeitrag',
                    value: _formatEuro(fee),
                  ),
                  if (!isPending) ...[
                    const Divider(height: 16, color: Colors.white24),
                    _AmountRow(
                      label: 'Gesamt bezahlt (Mieter)',
                      value: _formatEuro(
                        (rentalSubtotal +
                            fee +
                            dropFee +
                            retFee +
                            expressFee +
                            expressFeePlatform),
                      ),
                      strong: true,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        // Refund info (only relevant for Storniert)
        if (isCancelled) ...[
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              // Unified refund logic with Master‑Regel
              final now = DateTime.now();
              double ratio = 0.0;
              if (start != null) {
                ratio = DataService.refundRatio(
                  policy: 'unified',
                  start: start,
                  cancelAt: now,
                );
              }
              final cancelledBy =
                  (widget.booking['cancelledBy'] as String?) ?? '';
              double totalRefund;
              String note;
              if (cancelledBy == 'owner') {
                totalRefund = totalPaid; // 100% aller gezahlten Beträge
                note =
                    'Erstattung 100% aller gezahlten Beträge (Stornierung durch Vermieter).';
              } else {
                // Recompute fee and extras for proportional refund
                final fee = DataService.platformContributionForRental(
                  rentalSubtotal,
                );
                final bool ownerDelivers =
                    (widget.booking['ownerDeliversAtDropoffChosen'] == true) ||
                        (widget.booking['expressRequested'] == true) ||
                        (widget.booking['expressStatus'] != null) ||
                        ((widget.booking['deliveryAddressLine'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty) ||
                        ((widget.booking['deliveryCity'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty);
                final bool ownerPicks =
                    (widget.booking['ownerPicksUpAtReturnChosen'] == true);
                double km = 0.0;
                final double? dLat =
                    (widget.booking['deliveryLat'] as num?)?.toDouble();
                final double? dLng =
                    (widget.booking['deliveryLng'] as num?)?.toDouble();
                if (_itemLat != null &&
                    _itemLng != null &&
                    dLat != null &&
                    dLng != null) {
                  km = DataService.estimateDistanceKm(
                    _itemLat!,
                    _itemLng!,
                    dLat,
                    dLng,
                  );
                } else if (_itemLat != null &&
                    _itemLng != null &&
                    ((widget.booking['deliveryAddressLine'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty)) {
                  km = DataService.estimateDistanceKmFromAddressLine(
                    _itemLat!,
                    _itemLng!,
                    (widget.booking['deliveryAddressLine'] as String).trim(),
                  );
                } else if (_itemLat != null &&
                    _itemLng != null &&
                    ((widget.booking['deliveryCity'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty)) {
                  km = DataService.estimateDistanceKmToCity(
                    _itemLat!,
                    _itemLng!,
                    (widget.booking['deliveryCity'] as String).trim(),
                  );
                }
                final double dropFee = ownerDelivers
                    ? double.parse((km * 0.30).toStringAsFixed(2))
                    : 0.0;
                final double retFee = ownerPicks
                    ? double.parse((km * 0.30).toStringAsFixed(2))
                    : 0.0;
                final bool expressSelected =
                    (widget.booking['expressRequested'] == true) ||
                        (widget.booking['expressStatus'] == 'accepted');
                final double expressFee = expressSelected ? 5.0 : 0.0;
                final double expressFeePlatform = expressFee > 0
                    ? double.parse((expressFee * 0.10).toStringAsFixed(2))
                    : 0.0;
                final feesTotal =
                    fee + dropFee + retFee + expressFee + expressFeePlatform;
                final refundableTotal = (rentalSubtotal + feesTotal).clamp(
                  0.0,
                  totalPaid,
                );
                totalRefund = double.parse(
                  (refundableTotal * ratio).toStringAsFixed(2),
                );
                note = ratio >= 1.0
                    ? 'Kostenlose Stornierung – 100% Erstattung aller Beträge.'
                    : (ratio > 0.0
                        ? '50% Rückerstattung von Mietpreis und allen Gebühren.'
                        : 'Keine Rückerstattung (Mietbeginn erreicht oder Nicht‑Erscheinen).');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AmountRow(
                    label: 'Rückerstattung (gesamt)',
                    value: _formatEuro(totalRefund),
                    strong: true,
                  ),
                  Text(
                    note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        // Show receipt download only for explicit status "Abgeschlossen"
        if (status == 'Abgeschlossen') ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton.icon(
              onPressed: _downloadReceiptPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Beleg herunterladen'),
            ),
          ),
        ],

        if (isPending) ...[
          const SizedBox(height: 16),
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
                children: const [
                  _Bullet(
                    text: 'Warte, bis der Vermieter die Anfrage annimmt.',
                  ),
                  _Bullet(
                    text:
                        'Sobald deine Anfrage akzeptiert wird, erscheint sie unter Kommende Buchungen.',
                  ),
                  _Bullet(
                    text:
                        'Vereinbare mit dem Vermieter einen konkreten Zeitpunkt für Übergabe und Rückgabe.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Button wurde an die feste Fußleiste (bottomNavigationBar) verschoben
        ],

        if (isUpcoming && _isViewerOwnerSync()) ...[
          const SizedBox(height: 16),
          // Pickup code & QR
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
                  'Übergabe',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                // Kurzer Hinweis: QR & Code werden innerhalb des Flows angezeigt
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'QR‑Code und 6‑stelliger Übergabe‑Code erscheinen in Schritt 2 nach dem Start.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Button moved to the page bottom per request
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Next steps (collapsible) for upcoming
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
                children: const [
                  _Bullet(
                    text:
                        'Triff dich mit dem Vermieter zum vereinbarten Übergabezeitpunkt.',
                  ),
                  _Bullet(
                    text: 'Tippe auf „Übergabe starten“, wenn ihr euch trefft.',
                  ),
                  _Bullet(
                    text:
                        'Beide müssen mindestens 4 Übergabe‑Fotos vom Artikel machen.',
                  ),
                  _Bullet(
                    text:
                        'Übergabe bestätigen durch QR‑Code‑Scan oder Eingabe des 6‑stelligen Übergabecodes.',
                  ),
                ],
              ),
            ),
          ),
        ],

        if (isUpcoming && !_isViewerOwnerSync()) ...[
          const SizedBox(height: 16),
          // Button moved to the page bottom per request
          // Next steps (collapsible) for upcoming (renter)
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
                children: const [
                  _Bullet(
                    text:
                        'Triff dich mit dem Vermieter zum vereinbarten Übergabezeitpunkt.',
                  ),
                  _Bullet(
                    text: 'Tippe auf „Übergabe starten“, wenn ihr euch trefft.',
                  ),
                  _Bullet(
                    text:
                        'Beide müssen mindestens 4 Übergabe‑Fotos vom Artikel machen.',
                  ),
                  _Bullet(
                    text:
                        'Übergabe bestätigen durch QR‑Code‑Scan oder Eingabe des 6‑stelligen Übergabecodes.',
                  ),
                ],
              ),
            ),
          ),
        ],

        // Entfernt: separate ListerCard für Pending, da Vermieter bereits in Info-Card enthalten ist

        // Entfernt: Der Zurückziehen-Button wandert an das Seitenende (nur für Ausstehende Buchung)
        const SizedBox(height: 12),
        if (isCompleted) ...[
          _CompletionSummaryCard(
            booking: widget.booking,
            isOwnerView: _isViewerOwnerSync(),
            needsReview: widget.booking['needsReview'] == true,
            payoutFormatter: _formatPayoutDate,
            euroFormatter: _formatEuro,
            serviceFee: _serviceFee,
          ),
          const SizedBox(height: 12),
          // Review button moved to bottomNavigationBar for completed renter view
        ] else ...[
          // No additional Stornierungsbedingungen here; shown above Zahlungsübersicht already
          const SizedBox.shrink(),
        ],

        const SizedBox(height: 16),
        // Bottom primary action for upcoming bookings: move here per request
        if (isUpcoming && widget.booking['needsReview'] != true) ...[
          _InlineTimeActionButton(
            icon: Icons.inventory_2_rounded,
            label: 'Übergabezeit',
            onTap: () => _manageBookingTime(isReturn: false),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () async {
              if (!await _timeConfirmedForStart(isReturn: false)) return;
              await _startPickupFlow();
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Übergabe starten'),
          ),
        ],
        // Removed bottom "Anzeige ansehen" per request
      ],
    );
  }

  String _humanizeReminder(int? minutes) {
    if (minutes == null || minutes <= 0) return '—';
    final d = minutes ~/ (60 * 24);
    final h = (minutes % (60 * 24)) ~/ 60;
    final m = minutes % 60;
    final parts = <String>[];
    if (d > 0) parts.add(d == 1 ? '1 Tag' : '$d Tage');
    if (h > 0) parts.add(h == 1 ? '1 Stunde' : '$h Stunden');
    if (m > 0) parts.add('$m Min');
    return parts.isEmpty ? '—' : parts.join(' ');
  }

  Color _statusColor(String? status) {
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
      case 'Abgelehnt':
        return Colors.grey;
      case 'Storniert':
        return const Color(0xFFF43F5E);
      default:
        return Colors.grey;
    }
  }

  void _toast(String msg) {
    AppPopup.toast(context, icon: Icons.info_outline, title: msg);
  }

  Future<void> _openMaps(String query) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    try {
      if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        _toast('Karte konnte nicht geöffnet werden');
      }
    } catch (_) {
      _toast('Karte konnte nicht geöffnet werden');
    }
  }

  Future<void> _openDirections(String destination) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}',
    );
    try {
      if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        _toast('Navigation konnte nicht gestartet werden');
      }
    } catch (_) {
      _toast('Navigation konnte nicht gestartet werden');
    }
  }

  void _call(String phone) async {
    final tel = Uri.parse('tel:$phone');
    try {
      await launchUrl(tel, mode: LaunchMode.platformDefault);
    } catch (_) {
      _toast('Anruf nicht möglich');
    }
  }

  Future<void> _addToCalendar({required bool isPickup}) async {
    final (start, end) = _parseDateRange();
    final when = isPickup ? start : end;
    if (when == null) {
      _toast('Termin fehlt');
      return;
    }
    final title = (widget.booking['title'] as String?) ?? 'ShareItToo Buchung';
    final location = (widget.booking['location'] as String?) ?? '';
    final summary = isPickup ? 'Abholung: $title' : 'Rückgabe: $title';
    final uid =
        '${_computeBookingId()}-${isPickup ? 'pickup' : 'return'}@shareittoo';

    String fmt(DateTime dt) {
      final z = dt.toUtc();
      String two(int x) => x.toString().padLeft(2, '0');
      return '${z.year}${two(z.month)}${two(z.day)}T${two(z.hour)}${two(z.minute)}${two(z.second)}Z';
    }

    final ics = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//ShareItToo//Booking//DE',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:$uid',
      'DTSTAMP:${fmt(DateTime.now())}',
      'SUMMARY:$summary',
      if (location.isNotEmpty) 'LOCATION:$location',
      'DTSTART:${fmt(when)}',
      // Use 1-hour default duration
      'DTEND:${fmt(when.add(const Duration(hours: 1)))}',
      'DESCRIPTION:Buchungs-ID ${_computeBookingId()}',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\n');

    final dataUri = Uri.dataFromString(
      ics,
      mimeType: 'text/calendar',
      encoding: utf8,
    );
    try {
      await launchUrl(dataUri, mode: LaunchMode.platformDefault);
    } catch (_) {
      _toast('Kalendereintrag konnte nicht erstellt werden');
    }
  }

  String _computeBookingId() {
    final itemId = (widget.booking['itemId'] as String?) ?? '';
    final requestId = (widget.booking['requestId'] as String?) ?? '';
    final title = (widget.booking['title'] as String?) ?? '';
    if (itemId.isNotEmpty && requestId.isNotEmpty && title.isNotEmpty) {
      final seed =
          ((itemId.hashCode) ^ (requestId.hashCode) ^ (title.hashCode)).abs();
      final s = seed.toString().padLeft(8, '0');
      return 'BKG-${s.substring(0, 4)}-${s.substring(4, 8)}';
    }
    final fallbackSeed = ((widget.booking['title']?.hashCode ?? 0) ^
            (widget.booking['dates']?.hashCode ?? 0) ^
            (widget.booking['location']?.hashCode ?? 0))
        .abs();
    final s = fallbackSeed.toString().padLeft(8, '0');
    return 'BKG-${s.substring(0, 4)}-${s.substring(4, 8)}';
  }

  DateTime _handoverCodeStart() {
    DateTime? start = DateTime.tryParse(
      (widget.booking['startIso'] as String?) ?? '',
    );
    if (start == null) {
      final (s, _) = _CompletionSummaryCard._parseStaticDateRange(
        widget.booking,
      );
      start = s;
    }
    return start ?? DateTime.now();
  }

  String _confirmationCode({
    required String segment,
    required String presenterRole,
  }) {
    final title = (widget.booking['title'] as String?) ?? '';
    return HandoverCodeService.codeForTitleAndStart(
      title: title,
      start: _handoverCodeStart(),
      bookingId: _computeBookingId(),
      segment: segment,
      presenterRole: presenterRole,
    );
  }

  String _pickupOwnerCode() => _confirmationCode(
        segment: HandoverCodeService.segmentPickup,
        presenterRole: HandoverCodeService.presenterOwner,
      );

  String _returnRenterCode() => _confirmationCode(
        segment: HandoverCodeService.segmentReturn,
        presenterRole: HandoverCodeService.presenterRenter,
      );

  String _handoverCode() {
    final title = (widget.booking['title'] as String?) ?? '';
    return HandoverCodeService.codeFromTitleAndStart(
      title: title,
      start: _handoverCodeStart(),
    );
  }

  double _parseEuro(String s) {
    if (s.isEmpty) return 0.0;
    final cleaned = s
        .replaceAll('€', '')
        .replaceAll('EUR', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  double _serviceFee(double total) => (total * 0.10);
  double _discountsFromBooking() {
    final s = (widget.booking['discounts'] as String?) ?? '';
    if (s.isEmpty) return 0.0;
    // discounts may be like "-5 €" or "5 €"
    final v = _parseEuro(s);
    return v > 0 ? v : v.abs();
  }

  String _formatEuro(double v) {
    String two = v.toStringAsFixed(2);
    // European format
    two = two.replaceAll('.', ',');
    return '$two €';
  }

  bool _isViewerOwnerSync() {
    // Owner-view is explicitly passed by the caller (e.g., Meine Anzeigen > Laufend)
    return widget.viewerIsOwner;
  }

  String _formatPayoutDate(DateTime end) {
    final payout = end.add(const Duration(days: 1));
    final months = [
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

  String _formatPickupCountdown(Duration d, {String modeLabel = 'Abholung'}) {
    if (d.isNegative || d.inDays == 0) {
      return '$modeLabel Heute';
    }
    if (d.inDays == 1) return '$modeLabel in 1 Tag';
    return '$modeLabel in ${d.inDays} Tagen';
  }

  String _formatDeadline(DateTime dt) {
    final months = [
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
    final m = months[(dt.month - 1).clamp(0, 11)];
    final dd = dt.day.toString().padLeft(2, '0');
    return '$dd. $m';
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
              // Blurred background of the same page
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.black.withValues(alpha: 0.25)),
                ),
              ),
              // Centered enlarged QR
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

  Future<void> _startOwnerReturnFlow() async {
    // Build lightweight Item and RentalRequest to drive the stepper
    final (start, end) = _parseDateRange();
    final days = (start != null && end != null)
        ? math.max(1, end.difference(start).inDays)
        : 1;
    final totalPaid = _parseEuro(
      (widget.booking['pricePaid'] as String?) ?? '0',
    );
    final pricePerDay = days > 0 ? (totalPaid / days) : totalPaid;

    final itemIdSeed = ((widget.booking['title']?.hashCode ?? 0) ^
            (widget.booking['location']?.hashCode ?? 0))
        .abs()
        .toString();
    final reqIdSeed = ((widget.booking['dates']?.hashCode ?? 0) ^
            (widget.booking['title']?.hashCode ?? 0))
        .abs()
        .toString();

    final item = Item(
      id: 'itm_$itemIdSeed',
      ownerId: (widget.booking['ownerId'] as String?) ?? 'owner_local',
      title: (widget.booking['title'] as String?) ?? '-',
      description: '-',
      categoryId: 'cat0',
      subcategory: '-',
      tags: const [],
      pricePerDay: pricePerDay,
      currency: 'EUR',
      photos: _photos,
      locationText: (widget.booking['location'] as String?) ?? '-',
      lat: 0,
      lng: 0,
      geohash: '',
      condition: 'good',
      createdAt: DateTime.now(),
      isActive: true,
      verificationStatus: 'verified',
      city: '',
      country: '',
      status: 'active',
      endedAt: null,
      timesLent: 0,
      deposit: totalPaid > 100
          ? math.min(200.0, totalPaid * 0.25)
          : (totalPaid > 0 ? 50.0 : 0.0),
    );

    // Carry through transport selections so the stepper can show the
    // "Fahrtvergütung bestätigen" step when zutreffend (Abholung bei Rückgabe).
    final bool ownerPicksUpChosen =
        (widget.booking['ownerPicksUpAtReturnChosen'] == true);
    final bool ownerDeliversChosen =
        (widget.booking['ownerDeliversAtDropoffChosen'] == true);
    final String? delLine = widget.booking['deliveryAddressLine'] as String?;
    final String? delCity = widget.booking['deliveryCity'] as String?;
    final double? delLat = (widget.booking['deliveryLat'] as num?)?.toDouble();
    final double? delLng = (widget.booking['deliveryLng'] as num?)?.toDouble();
    final bool expressRequested = (widget.booking['expressRequested'] == true);
    final String? expressStatus = widget.booking['expressStatus'] as String?;

    final req = RentalRequest(
      id: 'req_$reqIdSeed',
      itemId: item.id,
      ownerId: item.ownerId,
      renterId: (widget.booking['listerId'] as String?) ?? 'renter_local',
      start: start ?? DateTime.now().subtract(const Duration(days: 1)),
      end: end ?? DateTime.now().add(const Duration(days: 1)),
      status: 'running',
      message: null,
      ownerPicksUpAtReturnChosen: ownerPicksUpChosen,
      ownerDeliversAtDropoffChosen: ownerDeliversChosen,
      deliveryAddressLine: delLine,
      deliveryCity: delCity,
      deliveryLat: delLat,
      deliveryLng: delLng,
      expressRequested: expressRequested,
      expressStatus: expressStatus,
    );

    final renterName = widget.viewerIsOwner ? _listerName : 'Mieter';
    final ownerName = widget.viewerIsOwner ? 'Vermieter' : _listerName;

    final ok = await ReturnHandoverStepperSheet.push(
      context,
      item: item,
      request: req,
      renterName: renterName,
      ownerName: ownerName,
      handoverCode: _returnRenterCode(),
      viewerIsOwner: widget.viewerIsOwner,
      mode: ReturnFlowMode.returnFlow,
    );

    final counterpartyConfirmed = ok?.confirmed == true;
    if (counterpartyConfirmed && mounted) {
      final ownerUserId = await DataService.getCurrentUser();
      final expectedOwnerId = (widget.booking['ownerId'] as String?)?.trim();
      if (ownerUserId == null ||
          expectedOwnerId == null ||
          ownerUserId.id != expectedOwnerId) {
        AppPopup.toast(
          context,
          icon: Icons.lock_outline,
          title: 'Diese Bestätigung ist nur für den Vermieter möglich.',
        );
        return;
      }
      final requestId = widget.booking['requestId'] as String?;
      if (requestId != null && requestId.isNotEmpty) {
        final galleryAcknowledged = await _acknowledgeGalleryEvidenceIfNeeded(
          requestId,
          isReturn: true,
        );
        if (!galleryAcknowledged) return;
        final transitioned = await _finalizeReturnTransition(
          requestId: requestId,
          confirmedByUserId: ownerUserId.id,
          method: 'stepper',
          confirmationContextVerified: counterpartyConfirmed,
          galleryAcknowledged: galleryAcknowledged,
          reviewPauseSource: 'booking_detail_screen_stepper',
        );
        if (!transitioned) return;
      }
      // Release/cancel ride compensation automatically if a decision was made for return segment
      try {
        if (requestId != null && requestId.isNotEmpty) {
          final grant = await DataService.getRideCompensationDecision(
            requestId: requestId,
            segment: 'return',
            consume: true,
          );
          if (grant != null) {
            await DataService.addTimelineEvent(
              requestId: requestId,
              type: grant
                  ? 'ride_comp_release_return'
                  : 'ride_comp_cancel_return',
              note: grant
                  ? 'Fahrtvergütung freigegeben (Rückgabe)'
                  : 'Fahrtvergütung nicht ausgezahlt (Rückgabe)',
            );
          }
        }
      } catch (_) {}
      if (requestId != null && requestId.isNotEmpty) {
        await _syncBookingLifecycleFromRequest(requestId!);
      }
      final titleTxt = (widget.booking['title'] as String?) ?? '';
      final listerId = widget.booking['listerId'] as String?;
      final itemId = widget.booking['itemId'] as String?;
      final viewerIsOwner = widget.viewerIsOwner;
      final whoToRateName = viewerIsOwner
          ? (widget.booking['renterName'] as String? ?? 'Mieter')
          : _listerName;

      await AppPopup.show(
        context,
        icon: Icons.check_circle_outline,
        title: 'Rückgabe von "$titleTxt" erfolgreich durchgeführt',
        message: 'Danke! Eine Erinnerung zum Bewerten erscheint in 10 Minuten.',
        barrierDismissible: true,
        showCloseIcon: false,
        plainCloseIcon: true,
        useExploreBackground: true,
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).maybePop(),
            child: const Text('OK'),
          ),
        ],
      );
      // Schedule a 10-minute review reminder for the current viewer (renter in this page)
      try {
        final current = await DataService.getCurrentUser();
        if (current != null &&
            requestId != null &&
            itemId != null &&
            listerId != null &&
            !viewerIsOwner) {
          await DataService.scheduleReviewReminder(
            requestId: requestId,
            itemId: itemId,
            reviewerId: current.id,
            reviewedUserId: listerId,
            direction: 'renter_to_owner',
            dueAt: DateTime.now().add(const Duration(minutes: 10)),
          );
        }
      } catch (_) {}
    }
  }

  Future<void> _startPickupFlow() async {
    final (start, end) = _parseDateRange();
    final days = (start != null && end != null)
        ? math.max(1, end.difference(start).inDays)
        : 1;
    final totalPaid = _parseEuro(
      (widget.booking['pricePaid'] as String?) ?? '0',
    );
    final pricePerDay = days > 0 ? (totalPaid / days) : totalPaid;

    final itemIdSeed = ((widget.booking['title']?.hashCode ?? 0) ^
            (widget.booking['location']?.hashCode ?? 0))
        .abs()
        .toString();
    final reqIdSeed = ((widget.booking['dates']?.hashCode ?? 0) ^
            (widget.booking['title']?.hashCode ?? 0))
        .abs()
        .toString();

    final item = Item(
      id: 'itm_$itemIdSeed',
      ownerId: (widget.booking['ownerId'] as String?) ?? 'owner_local',
      title: (widget.booking['title'] as String?) ?? '-',
      description: '-',
      categoryId: 'cat0',
      subcategory: '-',
      tags: const [],
      pricePerDay: pricePerDay,
      currency: 'EUR',
      photos: _photos,
      locationText: (widget.booking['location'] as String?) ?? '-',
      lat: 0,
      lng: 0,
      geohash: '',
      condition: 'good',
      createdAt: DateTime.now(),
      isActive: true,
      verificationStatus: 'verified',
      city: '',
      country: '',
      status: 'active',
      endedAt: null,
      timesLent: 0,
      deposit: null,
    );

    // Carry through transport selections so the stepper can show the
    // "Fahrtvergütung bestätigen" step when Lieferung bei Abgabe gewählt wurde.
    final bool ownerDeliversChosenPickup =
        (widget.booking['ownerDeliversAtDropoffChosen'] == true) ||
            (widget.booking['expressRequested'] == true) ||
            (widget.booking['expressStatus'] != null) ||
            ((widget.booking['deliveryAddressLine'] ?? '')
                .toString()
                .trim()
                .isNotEmpty) ||
            ((widget.booking['deliveryCity'] ?? '')
                .toString()
                .trim()
                .isNotEmpty);
    final bool ownerPicksChosenPickup =
        (widget.booking['ownerPicksUpAtReturnChosen'] == true);
    final String? pDelLine = widget.booking['deliveryAddressLine'] as String?;
    final String? pDelCity = widget.booking['deliveryCity'] as String?;
    final double? pDelLat = (widget.booking['deliveryLat'] as num?)?.toDouble();
    final double? pDelLng = (widget.booking['deliveryLng'] as num?)?.toDouble();
    final bool pExpressRequested = (widget.booking['expressRequested'] == true);
    final String? pExpressStatus = widget.booking['expressStatus'] as String?;

    final req = RentalRequest(
      id: 'req_$reqIdSeed',
      itemId: item.id,
      ownerId: item.ownerId,
      renterId: (widget.booking['listerId'] as String?) ?? 'renter_local',
      start: start ?? DateTime.now().add(const Duration(hours: 1)),
      end: end ?? DateTime.now().add(const Duration(days: 1)),
      status: 'accepted',
      message: null,
      ownerDeliversAtDropoffChosen: ownerDeliversChosenPickup,
      ownerPicksUpAtReturnChosen: ownerPicksChosenPickup,
      deliveryAddressLine: pDelLine,
      deliveryCity: pDelCity,
      deliveryLat: pDelLat,
      deliveryLng: pDelLng,
      expressRequested: pExpressRequested,
      expressStatus: pExpressStatus,
    );

    final renterName = widget.viewerIsOwner ? _listerName : 'Mieter';
    final ownerName = widget.viewerIsOwner ? 'Vermieter' : _listerName;

    final ok = await ReturnHandoverStepperSheet.push(
      context,
      item: item,
      request: req,
      renterName: renterName,
      ownerName: ownerName,
      handoverCode: _pickupOwnerCode(),
      viewerIsOwner: widget.viewerIsOwner,
      mode: ReturnFlowMode.pickupFlow,
    );
    // If the renter successfully confirmed via QR or manual code in the stepper,
    // mark the booking as running immediately.
    final counterpartyConfirmed = ok?.confirmed == true;
    if (counterpartyConfirmed) {
      try {
        final renterUserId = await _guardAuthenticatedRenter();
        if (renterUserId == null) return;
        final requestId = widget.booking['requestId'] as String?;
        if (requestId != null && requestId.isNotEmpty) {
          final galleryAcknowledged = await _acknowledgeGalleryEvidenceIfNeeded(
            requestId,
            isReturn: false,
          );
          if (!galleryAcknowledged) return;
          final transitioned = await _finalizePickupTransition(
            requestId: requestId,
            confirmedByUserId: renterUserId,
            method: 'stepper',
            confirmationContextVerified: counterpartyConfirmed,
            galleryAcknowledged: galleryAcknowledged,
          );
          if (!transitioned) return;
          // Release/cancel ride compensation for dropoff if decision exists
          try {
            final grant = await DataService.getRideCompensationDecision(
              requestId: requestId,
              segment: 'dropoff',
              consume: true,
            );
            if (grant != null) {
              await DataService.addTimelineEvent(
                requestId: requestId,
                type: grant
                    ? 'ride_comp_release_dropoff'
                    : 'ride_comp_cancel_dropoff',
                note: grant
                    ? 'Fahrtvergütung freigegeben (Übergabe)'
                    : 'Fahrtvergütung nicht ausgezahlt (Übergabe)',
              );
            }
          } catch (_) {}
        }
        if (!mounted) return;
        await _syncBookingLifecycleFromRequest(requestId!);
        final bookingId = _computeBookingId();
        final title = (widget.booking['title'] as String?) ?? '';
        final message = 'Übergabe des Listings "$title" wurde bestätigt.';
        await DataService.addNotification(
          title: 'Übergabe bestätigt',
          body: message,
        );
        await DataService.setHandoverBanner(
          bookingId: bookingId,
          message: message,
        );
        AppPopup.toast(
          context,
          icon: Icons.check_circle_outline,
          title: 'Übergabe bestätigt',
        );
      } catch (e) {
        if (!mounted) return;
        AppPopup.toast(
          context,
          icon: Icons.error_outline,
          title: 'Konnte Status nicht aktualisieren',
        );
      }
    }
  }

  Future<void> _downloadReceiptPdf() async {
    if (widget.booking['needsReview'] == true) {
      if (mounted) {
        AppPopup.toast(
          context,
          icon: Icons.hourglass_top_outlined,
          title: 'Beleg gesperrt, solange dieser Fall geprüft wird.',
        );
      }
      return;
    }
    final title = (widget.booking['title'] as String?) ?? '-';
    final bookingId = _computeBookingId();
    final requestId = (widget.booking['requestId'] ?? '').toString();
    final (start, end) = _parseDateRange();
    final pricePaidStr = (widget.booking['pricePaid'] as String?) ?? '';
    final totalPaidLegacy = _parseEuro(pricePaidStr);
    final daysVal = (widget.booking['days'] as num?)?.toInt() ??
        ((start != null && end != null)
            ? end.difference(start).inDays.clamp(1, 365)
            : 1);
    final basePerDayProvided =
        (widget.booking['basePerDay'] as num?)?.toDouble();
    final double baseTotal = basePerDayProvided != null
        ? (basePerDayProvided * daysVal)
        : totalPaidLegacy;
    final double discountAmount = _discountsFromBooking();
    final rentalSubtotal = (baseTotal - discountAmount).clamp(0.0, baseTotal);
    final fee = DataService.platformContributionForRental(rentalSubtotal);
    final netAmount = (rentalSubtotal / 1.19);
    final taxAmount = (rentalSubtotal - netAmount);

    final bool ownerDelivers =
        (widget.booking['ownerDeliversAtDropoffChosen'] == true) ||
            (widget.booking['expressRequested'] == true) ||
            (widget.booking['expressStatus'] != null) ||
            ((widget.booking['deliveryAddressLine'] ?? '')
                .toString()
                .trim()
                .isNotEmpty) ||
            ((widget.booking['deliveryCity'] ?? '')
                .toString()
                .trim()
                .isNotEmpty);
    final bool ownerPicks =
        (widget.booking['ownerPicksUpAtReturnChosen'] == true);
    double km = 0.0;
    final double? dLat = (widget.booking['deliveryLat'] as num?)?.toDouble();
    final double? dLng = (widget.booking['deliveryLng'] as num?)?.toDouble();
    if (_itemLat != null && _itemLng != null && dLat != null && dLng != null) {
      km = DataService.estimateDistanceKm(_itemLat!, _itemLng!, dLat, dLng);
    } else if (_itemLat != null &&
        _itemLng != null &&
        ((widget.booking['deliveryAddressLine'] ?? '')
            .toString()
            .trim()
            .isNotEmpty)) {
      km = DataService.estimateDistanceKmFromAddressLine(
        _itemLat!,
        _itemLng!,
        (widget.booking['deliveryAddressLine'] as String).trim(),
      );
    } else if (_itemLat != null &&
        _itemLng != null &&
        ((widget.booking['deliveryCity'] ?? '').toString().trim().isNotEmpty)) {
      km = DataService.estimateDistanceKmToCity(
        _itemLat!,
        _itemLng!,
        (widget.booking['deliveryCity'] as String).trim(),
      );
    }
    final double dropFee =
        ownerDelivers ? double.parse((km * 0.30).toStringAsFixed(2)) : 0.0;
    final double retFee =
        ownerPicks ? double.parse((km * 0.30).toStringAsFixed(2)) : 0.0;
    final bool expressSelected = (widget.booking['expressRequested'] == true) ||
        (widget.booking['expressStatus'] == 'accepted');
    final double expressFee = expressSelected ? 5.0 : 0.0;
    final double expressFeePlatform = expressFee > 0
        ? double.parse((expressFee * 0.10).toStringAsFixed(2))
        : 0.0;
    final double totalPaid = double.parse(
      (rentalSubtotal +
              fee +
              dropFee +
              retFee +
              expressFee +
              expressFeePlatform)
          .toStringAsFixed(2),
    );

    final renterName = (widget.booking['renterName'] as String?)?.trim();
    final ownerName = (widget.booking['listerName'] as String?)?.trim();
    final invoice = Invoice(
      id: 'receipt_${requestId.isNotEmpty ? requestId : bookingId}',
      invoiceNumber:
          'SIT-${bookingId.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '')}',
      bookingId: bookingId,
      requestId: requestId.isNotEmpty ? requestId : bookingId,
      type: InvoiceType.invoice,
      date: DateTime.now(),
      title: title,
      amount: totalPaid,
      booking: InvoiceBookingDetails(
        itemTitle: title,
        renterName: (renterName?.isNotEmpty == true ? renterName! : 'Mieter'),
        ownerName: (ownerName?.isNotEmpty == true ? ownerName! : 'Vermieter'),
        rentalDays: daysVal,
      ),
      pricing: InvoicePriceBreakdown(
        vatRate: 0.19,
        netAmount: double.parse(netAmount.toStringAsFixed(2)),
        taxAmount: double.parse(taxAmount.toStringAsFixed(2)),
        totalAfterTax: double.parse(rentalSubtotal.toStringAsFixed(2)),
        platformFee: double.parse(fee.toStringAsFixed(2)),
        payoutToOwner: double.parse(
          (totalPaid - fee).clamp(0.0, totalPaid).toStringAsFixed(2),
        ),
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final bytes = await InvoicePdfService.buildPdf(invoice);
      final fileName =
          'SIT_Buchungsbeleg_${bookingId}_${DateTime.now().toIso8601String().split('T').first}.pdf';
      final saveResult = await LocalArtifactStorageService.maybeSaveReceiptPdf(
        bytes: bytes,
        artifactKey:
            'booking-receipt:${invoice.id}:${invoice.updatedAt.toIso8601String()}',
        filename: fileName,
      );
      if (!saveResult.handledPrimaryAction) {
        await triggerFileDownload(bytes, fileName, mimeType: 'application/pdf');
      }
      if (!kIsWeb) {
        await Printing.layoutPdf(name: fileName, onLayout: (_) async => bytes);
      }
    } catch (e) {
      debugPrint('[BookingDetailScreen] receipt download failed: $e');
      _toast('Beleg konnte nicht erstellt werden');
    }
  }

  Future<void> _startScanOwnerQr() async {
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
                  child: const Text(
                    'Scanne den QR‑Code des Vermieters',
                    style: TextStyle(
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
        presenterRole: HandoverCodeService.presenterOwner,
        code: _pickupOwnerCode(),
        bookingId: _computeBookingId(),
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

      if (!_canStartBookingHandover) {
        AppPopup.toast(
          context,
          icon: Icons.info_outline,
          title: 'Übergabe ist gerade nicht verfügbar',
        );
        return;
      }

      final renterUserId = await _guardAuthenticatedRenter();
      if (renterUserId == null) return;
      final requestId = widget.booking['requestId'] as String?;
      if (requestId != null && requestId.isNotEmpty) {
        final galleryAcknowledged = await _acknowledgeGalleryEvidenceIfNeeded(
          requestId,
          isReturn: false,
        );
        if (!galleryAcknowledged) return;
        final transitioned = await _finalizePickupTransition(
          requestId: requestId,
          confirmedByUserId: renterUserId,
          method: 'qr',
          confirmationContextVerified: true,
          galleryAcknowledged: galleryAcknowledged,
        );
        if (!transitioned) return;
      }
      if (!mounted) return;
      if (requestId != null && requestId.isNotEmpty) {
        await _syncBookingLifecycleFromRequest(requestId!);
      }
      final title = (widget.booking['title'] as String?) ?? '';
      await DataService.addNotification(
        title: 'Übergabe bestätigt',
        body: 'Übergabe des Listings "$title" bestätigt.',
      );
      AppPopup.toast(
        context,
        icon: Icons.check_circle_outline,
        title: 'Übergabe per QR bestätigt',
      );
    } catch (e) {
      if (!mounted) return;
      AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Bestätigung fehlgeschlagen',
      );
    }
  }

  Future<void> _startScanRenterQrForReturn() async {
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
                  child: const Text(
                    'Scanne den QR‑Code des Mieters',
                    style: TextStyle(
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
        segment: HandoverCodeService.segmentReturn,
        presenterRole: HandoverCodeService.presenterRenter,
        code: _returnRenterCode(),
        bookingId: _computeBookingId(),
      );
      if (!matches) {
        AppPopup.toast(
          context,
          icon: Icons.error_outline,
          title:
              'Dieser Code gehört nicht zu dieser Rückgabe. Bitte den aktuellen Rückgabe-Code verwenden.',
        );
        return;
      }

      if (!_canCompleteBookingReturn) {
        AppPopup.toast(
          context,
          icon: Icons.info_outline,
          title: 'Rückgabe ist gerade nicht verfügbar',
        );
        return;
      }

      final ownerUserId = await DataService.getCurrentUser();
      final expectedOwnerId = (widget.booking['ownerId'] as String?)?.trim();
      if (ownerUserId == null ||
          expectedOwnerId == null ||
          ownerUserId.id != expectedOwnerId) {
        AppPopup.toast(
          context,
          icon: Icons.lock_outline,
          title: 'Diese Bestätigung ist nur für den Vermieter möglich.',
        );
        return;
      }
      final requestId = widget.booking['requestId'] as String?;
      if (requestId != null && requestId.isNotEmpty) {
        final galleryAcknowledged = await _acknowledgeGalleryEvidenceIfNeeded(
          requestId,
          isReturn: true,
        );
        if (!galleryAcknowledged) return;
        final transitioned = await _finalizeReturnTransition(
          requestId: requestId,
          confirmedByUserId: ownerUserId.id,
          method: 'qr',
          confirmationContextVerified: true,
          galleryAcknowledged: galleryAcknowledged,
          reviewPauseSource: 'booking_detail_screen_qr_return',
        );
        if (!transitioned) return;
      }
      if (!mounted) return;
      if (requestId != null && requestId.isNotEmpty) {
        await _syncBookingLifecycleFromRequest(requestId!);
      }
      final title = (widget.booking['title'] as String?) ?? '';
      await DataService.addNotification(
        title: 'Buchung abgeschlossen',
        body: 'Die Rückgabe für "$title" wurde abgeschlossen. Beleg gesendet.',
      );
      AppPopup.toast(
        context,
        icon: Icons.check_circle_outline,
        title: 'Rückgabe per QR bestätigt',
      );
      // Schedule a review reminder for the current user (viewer on this page rates the counterparty)
      try {
        final current = await DataService.getCurrentUser();
        final requestId = widget.booking['requestId'] as String?;
        final itemId = widget.booking['itemId'] as String?;
        final listerId = widget.booking['listerId'] as String?;
        if (current != null &&
            requestId != null &&
            itemId != null &&
            listerId != null) {
          await DataService.scheduleReviewReminder(
            requestId: requestId,
            itemId: itemId,
            reviewerId: current.id,
            reviewedUserId: listerId,
            direction: 'renter_to_owner',
            dueAt: DateTime.now().add(const Duration(minutes: 10)),
          );
        }
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Bestätigung fehlgeschlagen',
      );
    }
  }

  Future<void> _confirmManualReturnByCode() async {
    final entered = _manualReturnCodeCtrl.text.trim();
    if (entered.isEmpty) {
      AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Bitte Code eingeben',
      );
      return;
    }
    if (entered != _returnRenterCode()) {
      AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title:
            'Dieser Code gehört nicht zu dieser Rückgabe. Bitte den aktuellen Rückgabe-Code verwenden.',
      );
      return;
    }
    try {
      if (!_canCompleteBookingReturn) {
        AppPopup.toast(
          context,
          icon: Icons.info_outline,
          title: 'Rückgabe ist gerade nicht verfügbar',
        );
        return;
      }

      final ownerUserId = await DataService.getCurrentUser();
      final expectedOwnerId = (widget.booking['ownerId'] as String?)?.trim();
      if (ownerUserId == null ||
          expectedOwnerId == null ||
          ownerUserId.id != expectedOwnerId) {
        AppPopup.toast(
          context,
          icon: Icons.lock_outline,
          title: 'Diese Bestätigung ist nur für den Vermieter möglich.',
        );
        return;
      }

      final requestId = widget.booking['requestId'] as String?;
      if (requestId != null && requestId.isNotEmpty) {
        final galleryAcknowledged = await _acknowledgeGalleryEvidenceIfNeeded(
          requestId,
          isReturn: true,
        );
        if (!galleryAcknowledged) return;
        final transitioned = await _finalizeReturnTransition(
          requestId: requestId,
          confirmedByUserId: ownerUserId.id,
          method: 'manual',
          confirmationContextVerified: true,
          galleryAcknowledged: galleryAcknowledged,
          reviewPauseSource: 'booking_detail_screen_manual_return',
        );
        if (!transitioned) return;
      }
      if (!mounted) return;
      await _syncBookingLifecycleFromRequest(requestId!);
      final title = (widget.booking['title'] as String?) ?? '';
      await DataService.addNotification(
        title: 'Buchung abgeschlossen',
        body: 'Die Rückgabe für "$title" wurde abgeschlossen. Beleg gesendet.',
      );
      AppPopup.toast(
        context,
        icon: Icons.check_circle_outline,
        title: 'Rückgabe per Code bestätigt',
      );
      setState(() {
        _showManualReturnEntry = false;
        _manualReturnCodeCtrl.clear();
      });
      // Schedule a review reminder for the current user
      try {
        final current = await DataService.getCurrentUser();
        final requestId = widget.booking['requestId'] as String?;
        final itemId = widget.booking['itemId'] as String?;
        final listerId = widget.booking['listerId'] as String?;
        if (current != null &&
            requestId != null &&
            itemId != null &&
            listerId != null) {
          await DataService.scheduleReviewReminder(
            requestId: requestId,
            itemId: itemId,
            reviewerId: current.id,
            reviewedUserId: listerId,
            direction: 'renter_to_owner',
            dueAt: DateTime.now().add(const Duration(minutes: 10)),
          );
        }
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Bestätigung fehlgeschlagen',
      );
    }
  }

  Future<bool> _hasRequiredHandoverPhotos(String requestId) async {
    final handoverPhotos = await DataService.getHandoverPhotoCount(requestId);
    return handoverPhotos >= DataService.minimumRequiredPhotos;
  }

  Future<bool> _hasRequiredReturnPhotos(String requestId) async {
    final returnPhotos = await DataService.getReturnPhotoCount(requestId);
    return returnPhotos >= DataService.minimumRequiredPhotos;
  }

  Future<bool> _guardRequiredHandoverPhotos(String requestId) async {
    final ok = await _hasRequiredHandoverPhotos(requestId);
    if (!ok && mounted) {
      AppPopup.toast(
        context,
        icon: Icons.photo_camera_back_outlined,
        title: 'Bitte dokumentiere die Übergabe zuerst mit mindestens 4 Fotos.',
      );
    }
    return ok;
  }

  Future<bool> _guardRequiredReturnPhotos(String requestId) async {
    final ok = await _hasRequiredReturnPhotos(requestId);
    if (!ok && mounted) {
      AppPopup.toast(
        context,
        icon: Icons.photo_camera_back_outlined,
        title: 'Bitte dokumentiere die Rückgabe zuerst mit mindestens 4 Fotos.',
      );
    }
    return ok;
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

  Future<void> _syncBookingLifecycleFromRequest(String requestId) async {
    final request = await DataService.getRentalRequestById(requestId);
    if (!mounted || request == null) return;
    final mapped = switch (request.status) {
      'running' => ('Laufend', 'ongoing'),
      'completed' => ('Abgeschlossen', 'completed'),
      'accepted' => ('Akzeptiert', 'upcoming'),
      _ => (
          ((widget.booking['status'] as String?) ?? ''),
          ((widget.booking['category'] as String?) ?? ''),
        ),
    };
    setState(() {
      widget.booking['rawStatus'] = request.status;
      if (mapped.$1.isNotEmpty) widget.booking['status'] = mapped.$1;
      if (mapped.$2.isNotEmpty) widget.booking['category'] = mapped.$2;
      widget.booking['needsReview'] = request.needsReview;
    });
  }

  Future<bool> _finalizePickupTransition({
    required String requestId,
    required String confirmedByUserId,
    required String method,
    required bool confirmationContextVerified,
    required bool galleryAcknowledged,
  }) async {
    final result = await DataService.confirmPickupTransition(
      requestId: requestId,
      confirmedByUserId: confirmedByUserId,
      method: method,
      confirmationContextVerified: confirmationContextVerified,
      galleryAcknowledged: galleryAcknowledged,
    );
    if (!result.success) {
      if (mounted && result.errorMessage != null) {
        AppPopup.toast(
          context,
          icon: Icons.info_outline,
          title: result.errorMessage!,
        );
      }
      return false;
    }
    await _syncBookingLifecycleFromRequest(requestId!);
    return true;
  }

  Future<bool> _finalizeReturnTransition({
    required String requestId,
    required String confirmedByUserId,
    required String method,
    required bool confirmationContextVerified,
    required bool galleryAcknowledged,
    required String reviewPauseSource,
  }) async {
    final result = await DataService.confirmReturnTransition(
      requestId: requestId,
      confirmedByUserId: confirmedByUserId,
      method: method,
      confirmationContextVerified: confirmationContextVerified,
      galleryAcknowledged: galleryAcknowledged,
      reviewPauseSource: reviewPauseSource,
    );
    if (!result.success) {
      if (mounted && result.errorMessage != null) {
        AppPopup.toast(
          context,
          icon:
              result.pausedForReview ? Icons.info_outline : Icons.error_outline,
          title: result.errorMessage!,
        );
      }
      return false;
    }
    await _syncBookingLifecycleFromRequest(requestId!);
    return true;
  }

  String? _bookingRenterId() {
    final renterId = (widget.booking['renterId'] as String?)?.trim();
    if (renterId != null && renterId.isNotEmpty) return renterId;
    final listerId = (widget.booking['listerId'] as String?)?.trim();
    if (listerId != null && listerId.isNotEmpty) return listerId;
    return null;
  }

  Future<String?> _guardAuthenticatedRenter() async {
    final current = await DataService.getCurrentUser();
    final expectedRenterId = _bookingRenterId();
    if (current == null ||
        expectedRenterId == null ||
        current.id != expectedRenterId) {
      if (mounted) {
        AppPopup.toast(
          context,
          icon: Icons.lock_outline,
          title: 'Diese Bestätigung ist nur für den Mieter möglich.',
        );
      }
      return null;
    }
    return current.id;
  }

  Future<void> _confirmManualPickupAsRenter() async {
    await AppPopup.toast(
      context,
      icon: Icons.info_outline,
      title:
          'Eine Übergabe kann nur durch QR-Code oder den 6-stelligen Code der Gegenpartei bestätigt werden.',
    );
  }

  Future<void> _confirmManualPickupByCode() async {
    final entered = _manualPickupCodeCtrl.text.trim();
    if (entered.isEmpty) {
      AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Bitte Code eingeben',
      );
      return;
    }
    if (entered != _pickupOwnerCode()) {
      AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title:
            'Dieser Code passt nicht zu diesem Übergabeschritt. Bitte den aktuellen Code erneut anzeigen oder scannen.',
      );
      return;
    }
    try {
      final renterUserId = await _guardAuthenticatedRenter();
      if (renterUserId == null) return;
      final requestId = widget.booking['requestId'] as String?;
      if (requestId != null && requestId.isNotEmpty) {
        if (!_canStartBookingHandover) {
          AppPopup.toast(
            context,
            icon: Icons.info_outline,
            title: 'Übergabe ist gerade nicht verfügbar',
          );
          return;
        }
        final galleryAcknowledged = await _acknowledgeGalleryEvidenceIfNeeded(
          requestId,
          isReturn: false,
        );
        if (!galleryAcknowledged) return;
        final transitioned = await _finalizePickupTransition(
          requestId: requestId,
          confirmedByUserId: renterUserId,
          method: 'manual',
          confirmationContextVerified: true,
          galleryAcknowledged: galleryAcknowledged,
        );
        if (!transitioned) return;
      }
      if (!mounted) return;
      if (requestId != null && requestId.isNotEmpty) {
        await _syncBookingLifecycleFromRequest(requestId!);
      }
      final bookingId = _computeBookingId();
      final title = (widget.booking['title'] as String?) ?? '';
      final message =
          'Übergabe des Listings "$title" wurde vom Mieter bestätigt.';
      await DataService.addNotification(
        title: 'Übergabe bestätigt',
        body: message,
      );
      await DataService.setHandoverBanner(
        bookingId: bookingId,
        message: message,
      );
      AppPopup.toast(
        context,
        icon: Icons.check_circle_outline,
        title: 'Übergabe per Code bestätigt',
      );
      setState(() {
        _showManualPickupEntry = false;
        _manualPickupCodeCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Bestätigung fehlgeschlagen',
      );
    }
  }

  Future<void> _confirmCancelUpcoming() async {
    await AppPopup.show(
      context,
      icon: Icons.close,
      title: 'Buchung stornieren?',
      message: CancellationPolicyText.compactSummary(),
      barrierDismissible: true,
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
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).maybePop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).maybePop();
            final id = widget.booking['requestId'] as String?;
            if (id != null && id.isNotEmpty) {
              await DataService.updateRentalRequestStatusWithActor(
                requestId: id,
                status: 'cancelled',
                cancelledBy: 'renter',
              );
            }
            if (!mounted) return;
            // Navigate to Bookings -> Abgeschlossen with highlight on the cancelled card
            AppPopup.toast(
              context,
              icon: Icons.cancel_outlined,
              title: 'Buchung storniert',
            );
            // Replace the detail page with the bookings screen focused on "Abgeschlossen"
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => BookingsScreen(
                  initialTabIndex: 3,
                  highlightRequestId: id ?? '',
                ),
              ),
            );
          },
          child: const Text('Stornieren'),
        ),
      ],
    );
  }

  Future<void> _confirmWithdrawPending() async {
    await AppPopup.show(
      context,
      icon: Icons.help_outline,
      title: 'Zurückziehen bestätigen',
      message: 'Möchtest du die Anfrage wirklich zurückziehen?',
      barrierDismissible: true,
      actions: [
        OutlinedButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).maybePop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).maybePop();
            final id = widget.booking['requestId'] as String?;
            if (id != null) {
              await DataService.updateRentalRequestStatusWithActor(
                requestId: id,
                status: 'cancelled',
                cancelledBy: 'renter',
              );
            }
            if (!mounted) return;
            setState(() => widget.booking['status'] = 'Zurückgezogen');
            await AppPopup.toast(
              context,
              icon: Icons.undo,
              title: 'Anfrage wurde zurückgezogen',
            );
          },
          child: const Text('Zurückziehen'),
        ),
      ],
    );
  }
}

/// Small non-collapsible card used under the map to show either
/// the privacy notice (with a lock) or the exact address (with a pin).
class _AddressInfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _AddressInfoCard({required this.icon, required this.text});

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
        // Center the icon vertically with the single-line text so the
        // lock appears perfectly centered relative to the hint copy.
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

// A more modern, cleaner details card used on the booking page
class _ModernDetailsCard extends StatelessWidget {
  final String? title;
  final String? photoUrl;
  final VoidCallback onViewListing;
  final String datesText;
  final String? durationText;
  final VoidCallback? onAddPickupToCalendar;
  final VoidCallback? onAddReturnToCalendar;
  final String location;
  final VoidCallback onMap;
  final VoidCallback onNav;
  final String bookingId;
  final String counterpartyName;
  final String? counterpartyAvatar;
  final String counterpartyRole;
  final VoidCallback? onCounterpartyProfile;
  final double? counterpartyRating;
  final int? counterpartyReviews;
  final VoidCallback? onMessage;
  final bool showLocations;
  final bool? pickupVisible;
  final bool? returnVisible;
  final String? pickupAddress;
  final String? returnAddress;
  final bool enablePickupMapActions;
  final bool enableReturnMapActions;
  final bool showPickupRow;
  final String? transportInfo;

  const _ModernDetailsCard({
    required this.title,
    required this.photoUrl,
    required this.onViewListing,
    required this.datesText,
    required this.durationText,
    required this.onAddPickupToCalendar,
    required this.onAddReturnToCalendar,
    required this.location,
    required this.onMap,
    required this.onNav,
    required this.bookingId,
    required this.counterpartyName,
    required this.counterpartyAvatar,
    required this.counterpartyRole,
    required this.onCounterpartyProfile,
    this.counterpartyRating,
    this.counterpartyReviews,
    this.onMessage,
    this.showLocations = true,
    this.pickupVisible,
    this.returnVisible,
    this.pickupAddress,
    this.returnAddress,
    this.enablePickupMapActions = true,
    this.enableReturnMapActions = true,
    this.showPickupRow = true,
    this.transportInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool showLocationSection = showLocations;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (transportInfo != null && transportInfo!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(
                child: Text(
                  transportInfo!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                title!,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          const SizedBox(height: 6),
          _InfoRowModern(
            icon: Icons.schedule,
            label: 'Zeitraum',
            value: datesText,
          ),
          if (durationText != null) ...[
            const SizedBox(height: 3),
            _InfoRowModern(
              icon: Icons.timelapse,
              label: 'Dauer',
              value: durationText!,
            ),
          ],

          if (showLocationSection) ...[
            const SizedBox(height: 4),
            Divider(height: 12, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 2),
            if (pickupVisible != false && showPickupRow) ...[
              _InfoRowModern(
                icon: Icons.place_outlined,
                label: 'Abholort',
                value: (pickupAddress ?? location),
                trailing: enablePickupMapActions
                    ? _MapActions(onMap: onMap, onNav: onNav)
                    : null,
              ),
              const SizedBox(height: 3),
            ],
            if (returnVisible != false) ...[
              _InfoRowModern(
                icon: Icons.place,
                label: 'Rückgabeort',
                value: (returnAddress ?? location),
                trailing: enableReturnMapActions
                    ? _MapActions(onMap: onMap, onNav: onNav)
                    : null,
              ),
              const SizedBox(height: 4),
            ],
          ],

          if (bookingId.trim().isNotEmpty)
            _InfoRowModern(
              icon: Icons.tag,
              label: 'Buchungs-ID',
              value: bookingId,
            ),

          // Divider vor dem Vermieter-Block: immer eine feine Linie darstellen.
          if (showLocationSection || bookingId.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Divider(height: 12, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 2),
          ] else ...[
            const SizedBox(height: 8),
            Divider(height: 12, color: Colors.white24),
            const SizedBox(height: 4),
          ],

          // Counterparty (e.g., Vermieter) inside the same card, under Buchungs-ID
          if (counterpartyName.isNotEmpty)
            (onCounterpartyProfile != null
                ? InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onCounterpartyProfile,
                    child: _CounterpartyInlineRow(
                      name: counterpartyName,
                      avatarUrl: counterpartyAvatar,
                      role: counterpartyRole,
                      onMessage: onMessage,
                    ),
                  )
                : _CounterpartyInlineRow(
                    name: counterpartyName,
                    avatarUrl: counterpartyAvatar,
                    role: counterpartyRole,
                    onMessage: onMessage,
                  )),
        ],
      ),
    );
  }
}

class _InfoRowModern extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  const _InfoRowModern({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
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
          child: Icon(icon, size: 18, color: Colors.white),
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

class _MapActions extends StatelessWidget {
  final VoidCallback onMap;
  final VoidCallback onNav;
  const _MapActions({required this.onMap, required this.onNav});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onMap,
          child: Text(
            'Karte',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onNav,
          child: Text(
            'Navigation starten',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _CounterpartyInlineRow extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String role;
  final VoidCallback? onMessage;
  const _CounterpartyInlineRow({
    required this.name,
    this.avatarUrl,
    required this.role,
    this.onMessage,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SitUserAvatar(
          url: avatarUrl,
          radius: 18,
          borderColor: Colors.white.withValues(alpha: 0.12),
          placeholderIcon: Icons.person_outline,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (onMessage != null)
          IconButton(
            tooltip: 'Nachricht schreiben',
            onPressed: onMessage,
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white70),
          ),
      ],
    );
  }
}

class _CounterpartyRow extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String role;
  final VoidCallback? onProfile;
  final double? rating;
  final int? reviewsCount;
  final int? trustPercent;
  const _CounterpartyRow({
    required this.name,
    this.avatarUrl,
    required this.role,
    this.onProfile,
    this.rating,
    this.reviewsCount,
    this.trustPercent,
  });
  @override
  Widget build(BuildContext context) {
    String? ratingText;
    if (rating != null) {
      final val = rating!.toStringAsFixed(1).replaceAll('.', ',');
      final rc = reviewsCount ?? 0;
      ratingText = '$val · ${rc > 0 ? '$rc Bewertungen' : 'Bewertung'}';
    } else if (trustPercent != null) {
      ratingText = '${trustPercent!.clamp(0, 100)}% Vertrauen';
    }
    return Row(
      children: [
        SitUserAvatar(
          url: avatarUrl,
          radius: 18,
          borderColor: Colors.white.withValues(alpha: 0.12),
          placeholderIcon: Icons.person_outline,
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
              Row(
                children: [
                  Text(
                    role,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                  if (ratingText != null) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.star_rate_rounded,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      ratingText,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        TextButton(onPressed: onProfile, child: const Text('Zum Profil')),
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

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});
  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.3);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('•', style: bodyStyle),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: bodyStyle)),
        ],
      ),
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

class _ListerCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final VoidCallback? onMessage;
  const _ListerCard({required this.name, this.avatarUrl, this.onMessage});
  @override
  Widget build(BuildContext context) {
    return Container(
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
            children: [
              SitUserAvatar(
                url: avatarUrl,
                radius: 22,
                borderColor: Colors.white.withValues(alpha: 0.12),
                placeholderIcon: Icons.person_outline,
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 2),
                    Text(
                      'Antwortet in der Regel schnell',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onMessage != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.center,
              child: OutlinedButton.icon(
                onPressed: onMessage,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Nachricht schreiben'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CancellationPolicyCard extends StatefulWidget {
  final Map<String, dynamic> booking;
  final bool initiallyOpen;
  const _CancellationPolicyCard({
    required this.booking,
    this.initiallyOpen = false,
  });
  @override
  State<_CancellationPolicyCard> createState() =>
      _CancellationPolicyCardState();
}

class _CancellationPolicyCardState extends State<_CancellationPolicyCard> {
  bool _open = false;
  @override
  void initState() {
    super.initState();
    // Default collapsed everywhere; only open when explicitly requested
    _open = widget.initiallyOpen;
  }

  String _formatDeadline(DateTime dt) {
    final months = [
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
    final m = months[(dt.month - 1).clamp(0, 11)];
    final dd = dt.day.toString().padLeft(2, '0');
    return '$dd. $m';
  }

  @override
  Widget build(BuildContext context) {
    // Unified policy text from central helper
    final String header = CancellationPolicyText.header;
    final String bodyText = CancellationPolicyText.body();
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
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
                    const Icon(Icons.policy_outlined, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      header,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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
              child: Builder(
                builder: (context) {
                  return Text(
                    bodyText,
                    style: const TextStyle(color: Colors.white70, height: 1.3),
                  );
                },
              ),
            ),
            secondChild: const SizedBox(height: 0),
          ),
        ],
      ),
    );
  }
}

// Summary card for completed/cancelled bookings with key facts
class _CompletionSummaryCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isOwnerView;
  final bool needsReview;
  final String Function(DateTime) payoutFormatter;
  final String Function(double) euroFormatter;
  final double Function(double) serviceFee;

  const _CompletionSummaryCard({
    required this.booking,
    required this.isOwnerView,
    required this.needsReview,
    required this.payoutFormatter,
    required this.euroFormatter,
    required this.serviceFee,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = (booking['status'] as String?) ?? 'Abgeschlossen';
    final (start, end) = _parseStaticDateRange(booking);
    final totalPaid = _parseStaticEuro((booking['pricePaid'] as String?) ?? '');
    final fee = serviceFee(totalPaid);

    // Dates: use end as return date fallback
    final returnedAt = end;
    final payoutAt = end != null ? end.add(const Duration(days: 1)) : null;

    Text _line(String label, String value, {IconData? icon}) => Text(
          value.isEmpty ? '' : value,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );

    List<Widget> rows = [];
    if (status == 'Storniert') {
      rows.addAll([
        _FactRow(
          icon: Icons.cancel_outlined,
          label: 'Status',
          value: 'Storniert',
          color: const Color(0xFFF43F5E),
        ),
        if (returnedAt != null)
          _FactRow(
            icon: Icons.event_busy,
            label: 'Storniert am',
            value: _fmtDate(returnedAt),
          ),
        _FactRow(
          icon: Icons.receipt_long_outlined,
          label: 'Beleg',
          value: 'Erstattung gem. Richtlinien',
        ),
      ]);
    } else {
      // Abgeschlossen
      rows.addAll([
        _FactRow(
          icon: needsReview
              ? Icons.hourglass_top_outlined
              : Icons.verified_outlined,
          label: 'Status',
          value: needsReview ? 'Wird geprüft' : 'Abgeschlossen',
          color: needsReview ? const Color(0xFFF59E0B) : Colors.blueGrey,
        ),
        if (returnedAt != null)
          _FactRow(
            icon: Icons.assignment_turned_in_outlined,
            label: 'Rückgabe bestätigt',
            value: _fmtDate(returnedAt),
          ),
        if (isOwnerView && needsReview)
          _FactRow(
            icon: Icons.payments_outlined,
            label: 'Auszahlung',
            value: 'Wird geprüft',
          ),
        if (isOwnerView && !needsReview)
          _FactRow(
            icon: Icons.payments_outlined,
            label: 'Auszahlung',
            value: euroFormatter((totalPaid - fee).clamp(0.0, totalPaid)),
          ),
        if (isOwnerView && !needsReview && payoutAt != null)
          _FactRow(
            icon: Icons.event_available_outlined,
            label: 'Ausgezahlt am',
            value: payoutFormatter(payoutAt),
          ),
        if (needsReview)
          _FactRow(
            icon: Icons.info_outline,
            label: 'Hinweis',
            value:
                'Zu dieser Buchung liegt eine Rückmeldung vor. Wir prüfen den Vorgang sorgfältig und schließen die Buchung danach vollständig ab. Danke für dein Verständnis.',
          ),
      ]);
    }

    return Container(
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
            needsReview ? 'Prüfstatus' : 'Abschluss-Zusammenfassung',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ..._withDividers(rows),
        ],
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> children) {
    if (children.isEmpty) return const [];
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) {
        out.add(const SizedBox(height: 8));
        out.add(const Divider(height: 16, color: Colors.white24));
        out.add(const SizedBox(height: 2));
      }
    }
    return out;
  }

  static (DateTime?, DateTime?) _parseStaticDateRange(
    Map<String, dynamic> booking,
  ) {
    String raw = (booking['dates'] as String?) ?? '';
    DateTime? parse(String s) {
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
      final m = reg.firstMatch(s.trim());
      if (m == null) return null;
      final d = int.tryParse(m.group(1)!);
      String key = m.group(2)!;
      if (d == null) return null;
      key = key.substring(0, 1).toUpperCase() +
          key.substring(1, math.min(key.length, 3)).toLowerCase();
      if (key == 'Mä' || key == 'Mär') key = 'Mär';
      final month = months[key];
      if (month == null) return null;
      final now = DateTime.now();
      return DateTime(now.year, month, d);
    }

    DateTime? s;
    DateTime? e;
    if (raw.contains('–')) {
      final parts = raw.split('–');
      s = parse(parts.first);
      e = parse(parts.length > 1 ? parts[1] : '');
    } else if (raw.contains('-')) {
      final parts = raw.split('-');
      s = parse(parts.first);
      e = parse(parts.length > 1 ? parts[1] : '');
    } else {
      s = parse(raw);
    }
    if (s != null && e != null && e.isBefore(s)) {
      e = DateTime(s.year + 1, e.month, e.day);
    }
    return (s, e);
  }

  static String _fmtDate(DateTime dt) {
    final months = [
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
    final m = months[(dt.month - 1).clamp(0, 11)];
    final dd = dt.day.toString().padLeft(2, '0');
    return '$dd. $m';
  }

  static double _parseStaticEuro(String s) {
    if (s.isEmpty) return 0.0;
    final cleaned = s
        .replaceAll('€', '')
        .replaceAll('EUR', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(cleaned) ?? 0.0;
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

class _ReturnReminderCard extends StatelessWidget {
  final int? valueMinutes;
  final ValueChanged<int?> onChanged;
  const _ReturnReminderCard({
    required this.valueMinutes,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final selected = await ReturnReminderPickerSheet.show(
          context,
          initialMinutes: valueMinutes ?? 120,
          maxDays: 30,
          minuteStep: 5,
        );
        if (selected != null) {
          onChanged(selected == 0 ? null : selected);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.alarm, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Erinnerung zur Rückgabe',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _humanize(valueMinutes),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  String _humanize(int? minutes) {
    if (minutes == null || minutes <= 0) {
      return 'Tippen, um eine Erinnerung vor dem Rückgabetermin zu setzen.';
    }
    final d = minutes ~/ (60 * 24);
    final h = (minutes % (60 * 24)) ~/ 60;
    final m = minutes % 60;
    final parts = <String>[];
    if (d > 0) parts.add(d == 1 ? '1 Tag' : '$d Tage');
    if (h > 0) parts.add(h == 1 ? '1 Std' : '$h Std');
    if (m > 0) parts.add('$m Min');
    return parts.isEmpty ? '—' : parts.join(' ');
  }
}

class _Timeline extends StatelessWidget {
  final String
      current; // one of Requested, Accepted, Paid, Picked up, Laufend, Due, Completed, Überfällig
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
          _StepChip(label: 'Überfällig', state: _StepState.overdue),
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
