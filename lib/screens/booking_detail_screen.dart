import 'package:flutter/material.dart';
import 'package:lendify/screens/message_thread_screen.dart';
import 'package:lendify/screens/bookings_screen.dart';
import 'package:lendify/screens/public_profile_screen.dart';
import 'package:lendify/widgets/return_reminder_picker_sheet.dart';
import 'package:lendify/services/data_service.dart';
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
import 'package:lendify/widgets/review_prompt_sheet.dart';
import 'package:lendify/services/address_privacy.dart';
import 'package:lendify/widgets/approx_location_map.dart';
import 'package:lendify/screens/report_issue_screen.dart';
import 'package:lendify/widgets/sit_overflow_menu.dart';
import 'package:lendify/services/handover_code.dart';

class BookingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  final bool viewerIsOwner; // when true, show owner-facing details (e.g., payout, counterparty role = "Mieter")
  const BookingDetailScreen({super.key, required this.booking, this.viewerIsOwner = false});

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

  List<String> get _photos {
    final b = widget.booking;
    final list = (b['images'] as List?)?.cast<String>();
    if (list != null && list.isNotEmpty) return list;
    final single = (b['image'] as String?) ?? '';
    return single.isNotEmpty ? [single] : <String>[];
  }

  bool get _canCancel => widget.booking['category'] == 'upcoming' || widget.booking['category'] == 'pending';
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
  bool get _canMessage => (widget.booking['status'] == 'Akzeptiert') || (widget.booking['status'] == 'Laufend');

  String get _listerName => (widget.booking['listerName'] as String?) ?? 'Vermieter';
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
    String key = monStr.substring(0, 1).toUpperCase() + monStr.substring(1, math.min(monStr.length, 3)).toLowerCase();
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
      if (mounted) setState(() { _ownerPickupFailCount = fails; _manualPickupAllowed = fails >= 3; });
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
          if (mounted) setState(() { _itemLat = item?.lat; _itemLng = item?.lng; });
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

  Future<void> _viewListing() async {
    final ctx = context;
    final title = (widget.booking['title'] as String?)?.toLowerCase() ?? '';
    final tokens = title.split(RegExp(r'[^a-z0-9äöüß]+')).where((w) => w.length >= 3).toSet();
    final items = await DataService.getPublicItems();
    int bestScore = 0; var bestItem = null;
    for (final it in items) {
      final t = it.title.toLowerCase();
      int s = 0; for (final tok in tokens) { if (t.contains(tok)) s++; }
      if (s > bestScore) { bestScore = s; bestItem = it; }
    }
    if (!mounted) return;
    if (bestItem == null || bestScore == 0) {
      await showDialog<void>(context: ctx, builder: (dCtx) => AlertDialog(title: const Text('Hinweis'), content: const Text('Anzeige wurde gelöscht'), actions: [TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('OK'))]));
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
        return 'Abgeschlossene Buchung';
      default:
        return 'Buchung';
    }
  }

  // Derive an effective category for detail view using dates and status,
  // mirroring the logic on the list screen so both stay consistent.
  String _effectiveCategory({DateTime? start, DateTime? end}) {
    String rawCat = (widget.booking['category'] as String?)?.toLowerCase() ?? '';
    String rawStatus = ((widget.booking['status'] as String?) ?? '').toLowerCase();

    // Pending-like
    if (rawCat == 'pending' ||
        rawStatus.contains('ausstehend') ||
        rawStatus.contains('angefragt') ||
        rawStatus.contains('bezahlt')) {
      return 'pending';
    }

    // Completed-like (cancelled/declined resolved into completed bucket)
    if (rawCat == 'completed' ||
        rawStatus.contains('storniert') ||
        rawStatus.contains('abgelehnt') ||
        rawStatus.contains('abgeschlossen')) {
      return 'completed';
    }

    DateTime? s = start;
    DateTime? e = end;
    if (s == null || e == null) {
      final (ss, ee) = _parseDateRange();
      s ??= ss;
      e ??= ee;
    }
    if (s != null && e != null) {
      final now = DateTime.now();
      if (now.isBefore(s)) return 'upcoming';
      if (now.isBefore(e)) return 'ongoing';
      return 'completed';
    }

    // Fallback to raw category or status keywords
    if (rawCat == 'upcoming') return 'upcoming';
    if (rawCat == 'ongoing') return 'ongoing';
    if (rawStatus.contains('akzeptiert')) return 'upcoming';
    if (rawStatus.contains('laufend')) return 'ongoing';
    return 'pending';
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
                const SitMenuOption(icon: Icons.visibility_rounded, label: 'Anzeige ansehen', value: 'view'),
                if (effective == 'upcoming') const SitMenuOption(icon: Icons.cancel_outlined, label: 'Stornieren', value: 'cancel'),
                if (effective == 'pending') const SitMenuOption(icon: Icons.undo, label: 'Anfrage zurückziehen', value: 'withdraw'),
                const SitMenuOption(icon: Icons.error_outline, label: 'Problem melden', value: 'issue'),
              ];
              final picked = await showSITOverflowMenu<String>(context, options: opts);
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
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ReportIssueScreen(requestId: requestId, itemTitle: title),
                      ));
                    }
                  }
                  break;
                default:
              }
            },
          ),
        ],
      ),
      // Bottom messaging bar removed per request
      bottomNavigationBar: null,
      body: SafeArea(
        child: _isOngoing ? _buildOngoingBody(theme) : _buildDefaultBody(theme, pickupText, returnText),
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

    final days = (start != null && end != null) ? end.difference(start).inDays.clamp(1, 365) : 1;
    final totalPaid = _parseEuro(pricePaidStr);
    final discounts = _discountsFromBooking();
    final fee = _serviceFee(totalPaid);
    final rentalSubtotal = (totalPaid - fee + discounts).clamp(0.0, totalPaid);
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
              child: Stack(children: [
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _photos.length,
                  itemBuilder: (_, i) => SizedBox(width: double.infinity, height: 220, child: AppImage(url: _photos[i], fit: BoxFit.cover)),
                ),
                if (_photos.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (int i = 0; i < _photos.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 12 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _page ? theme.colorScheme.primary : Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )
                    ]),
                  ),
                // Status chip bottom-left overlay (all states)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Builder(builder: (context) {
                    final (start, end) = _parseDateRange();
                    final effective = _effectiveCategory(start: start, end: end);
                    final status = (widget.booking['status'] as String?) ?? '';
                    String label; Color color;
                    if (effective == 'completed') {
                      final cancelled = status == 'Storniert' || status == 'Abgelehnt';
                      label = cancelled ? 'Storniert' : 'Abgeschlossen';
                      color = cancelled ? const Color(0xFFF43F5E) : Colors.blueGrey;
                    } else if (effective == 'pending') {
                      label = 'Anfrage'; color = Colors.grey;
                    } else if (effective == 'upcoming') {
                      label = 'Kommend'; color = _statusColor('Akzeptiert');
                    } else {
                      label = 'Laufend'; color = _statusColor('Laufend');
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                    );
                  }),
                ),
                // Countdown pill inside the image (bottom-right) for laufend
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      boxShadow: [
                        BoxShadow(
                          color: (isOverdue ? const Color(0xFFF43F5E) : theme.colorScheme.primary).withValues(alpha: 0.30),
                          blurRadius: 10,
                          spreadRadius: 0.2,
                        ),
                      ],
                    ),
                    child: Row(children: [
                      Icon(isOverdue ? Icons.report_outlined : Icons.timer_outlined, size: 16, color: isOverdue ? const Color(0xFFF43F5E) : Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        _formatDurationCompact(diff),
                        style: TextStyle(color: isOverdue ? const Color(0xFFF43F5E) : Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                ),
                // end stack children
              ]),
            ),
          ),

        // Removed the row with status + actions – chip is back in the image

        const SizedBox(height: 12),

        // Centered title above the info card
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
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
          durationText: (start != null && end != null) ? _formatDaysHours(end.difference(start)) : null,
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
          onMessage: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MessageThreadScreen(participantName: _listerName, avatarUrl: _listerAvatar),
            ));
          },
          // Locations moved out of the info card in all sections
          showLocations: false,
          transportInfo: () {
            // For laufend we show return side, for others pickup side
            final renterPicksUpSelf = (widget.booking['ownerDeliversAtDropoffChosen'] == true) ? false : true;
            final renterReturnsSelf = (widget.booking['ownerPicksUpAtReturnChosen'] == true) ? false : true;
            if (_isOngoing) {
              return renterReturnsSelf ? 'Du bringst den Artikel selbst zurück.' : 'Der Vermieter holt den Artikel wieder ab.';
            } else {
              final (s, e) = _parseDateRange();
              final eff = _effectiveCategory(start: s, end: e);
              if (renterPicksUpSelf) {
                return eff == 'pending'
                    ? 'Du holst den Artikel selbst ab, wenn deine Anfrage akzeptiert wird.'
                    : 'Du holst den Artikel selbst ab.';
              } else {
                return 'Der Vermieter bringt dir den Artikel.';
              }
            }
          }(),
        ),

        // Ongoing (Laufend): Karte für Rückgabe, falls der Mieter selbst zurückbringt –
        // identisches Verhalten wie die Abhol‑Karte in „Kommende Buchung"
        Builder(builder: (context) {
          final renterReturnsSelf = (widget.booking['ownerPicksUpAtReturnChosen'] == true) ? false : true;
          if (!renterReturnsSelf) return const SizedBox.shrink();
          final label = AddressPrivacy.nearbyShort(kindLabel: 'Rückgabe');
          final fullAddress = (widget.booking['location'] as String?) ?? '';
          // For ongoing bookings, always show the exact address
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: ApproxLocationMap(lat: _itemLat, lng: _itemLng, label: label),
              ),
              const SizedBox(height: 8),
              _AddressInfoCard(
                icon: Icons.place_outlined,
                text: 'Rückgabeort: $fullAddress',
              ),
            ],
          );
        }),

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
          child: Builder(builder: (context) {
            final pricePaidStr = (widget.booking['pricePaid'] as String?) ?? '';
            final totalPaid = _parseEuro(pricePaidStr);
            final daysLocal = (start != null && end != null) ? end.difference(start).inDays.clamp(1, 365) : 1;
            final providedBasePerDay = (widget.booking['basePerDay'] as num?)?.toDouble();
            final discountPercentProvided = (widget.booking['discountPercentApplied'] as num?)?.toDouble() ?? 0.0;
            final discountAmountProvided = _discountsFromBooking();
            double baseTotal;
            double discountAmount;
            if (providedBasePerDay != null) {
              baseTotal = (providedBasePerDay * daysLocal);
              discountAmount = discountAmountProvided;
            } else {
              final feeTmp = _serviceFee(totalPaid);
              final rentalSubtotalTmp = (totalPaid - feeTmp + discountAmountProvided).clamp(0.0, totalPaid);
              baseTotal = rentalSubtotalTmp;
              discountAmount = discountAmountProvided;
            }
            final feeLocal = _serviceFee(totalPaid);
            final rentalSubtotalLocal = (baseTotal - discountAmount).clamp(0.0, totalPaid);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Zahlungsübersicht', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (discountAmount > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.percent_outlined, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Langzeitmiet‑Rabatt aktiv: Du sparst ${discountPercentProvided > 0 ? discountPercentProvided.toStringAsFixed(0) + '%' : ''} bei dieser Buchung.', style: const TextStyle(color: Colors.white))),
                  ]),
                ),
              if (providedBasePerDay != null)
                _AmountRow(label: 'Grundpreis: ${_formatEuro(providedBasePerDay)} × $daysLocal', value: _formatEuro(baseTotal)),
              if (discountAmount > 0)
                _AmountRow(label: 'Rabatt${discountPercentProvided > 0 ? ' (${discountPercentProvided.toStringAsFixed(0)}%)' : ''}', value: '-${_formatEuro(discountAmount)}'),
              _AmountRow(label: 'Zwischensumme (Mietpreis)', value: _formatEuro(rentalSubtotalLocal)),
              _AmountRow(label: 'Servicegebühr', value: _formatEuro(feeLocal)),
              const Divider(height: 16, color: Colors.white24),
              _AmountRow(label: 'Gesamt bezahlt (Mieter)', value: _formatEuro(totalPaid), strong: true),
              if (_isViewerOwnerSync()) ...[
                const SizedBox(height: 8),
                _AmountRow(label: 'Vorauss. Auszahlung', value: _formatEuro(totalPaid - feeLocal), strong: true),
                if (end != null)
                  Text('Auszahlung am ${_formatPayoutDate(end)}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
              ]
            ]);
          }),
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Übergabe', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.vpn_key, color: Colors.white70),
                const SizedBox(width: 8),
                Text('Übergabe-Code', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(_handoverCode(), style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.w800, color: Colors.white)),
                )
              ]),
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: () => _showQrOverlay(context, 'shareittoo:handover:${_handoverCode()}:$bookingId'),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35), blurRadius: 14, spreadRadius: 0.5),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        child: QrImageView(
                          data: 'shareittoo:handover:${_handoverCode()}:$bookingId',
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
            ]),
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
                Text('Artikelrückgabe bestätigen', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _startScanRenterQrForReturn,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('QR‑Code vom Mieter scannen'),
                    ),
                  ),
                ]),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _showManualReturnEntry = !_showManualReturnEntry),
                    child: Text(_showManualReturnEntry ? 'Eingabe ausblenden' : 'QR‑Scan nicht möglich?'),
                  ),
                ),
                if (_showManualReturnEntry) ...[
                  const SizedBox(height: 4),
                  Text('🔒 Code manuell eingeben (6‑stellig)', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
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
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _confirmManualReturnByCode,
                        icon: const Icon(Icons.key),
                        label: const Text('Code bestätigen'),
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 0),
                // Aufklappbarer Hinweis (kleiner Titel, randloser Text)
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    collapsedIconColor: Colors.white70,
                    iconColor: Colors.white70,
                    leading: const Icon(Icons.info_outline, color: Colors.white70),
                    title: Text(
                      'Hinweis',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    childrenPadding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 0, right: 0, bottom: 6),
                        child: Text(
                          'Bitte den Mieter, in seinem Bereich „Laufende Buchungen“, eure Buchung zu wählen und dort die Rückgabe zu starten. Erst dann sind der QR‑Code und der 6‑stellige Code für dich sichtbar.',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.45),
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
              border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.24)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFF43F5E)),
              const SizedBox(width: 8),
              const Expanded(child: Text('Überfällig – bitte Rückgabe jetzt starten', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              TextButton(
                onPressed: _startOwnerReturnFlow,
                child: const Text('Jetzt starten'),
              )
            ]),
          )
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
                title: Text('Was passiert als Nächstes?', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                childrenPadding: const EdgeInsets.only(left: 0, right: 0, bottom: 12),
                children: const [
                  _Bullet(text: 'Triff dich mit dem Vermieter zum vereinbarten Rückgabezeitpunkt.'),
                  _Bullet(text: 'Klicke auf „Rückgabe starten“, wenn ihr euch trefft.'),
                  _Bullet(text: 'Beide müssen mindestens 4 Rückgabe‑Fotos vom Artikel machen.'),
                  _Bullet(text: 'Rückgabe bestätigen durch QR‑Code‑Scan oder Eingabe des 6‑stelligen Rückgabecodes.'),
                  _Bullet(text: 'Tippe auf „Abschließen“, um die Rückgabe abzuschließen.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!widget.viewerIsOwner)
          FilledButton.icon(
            onPressed: _startOwnerReturnFlow,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(isOverdue ? 'Rückgabe jetzt starten' : 'Rückgabe starten'),
          ),
        // Hinweis: "Problem melden" nur in abgeschlossenen Buchungen anzeigen (siehe weiter unten in isCompleted‑Block)
      ],
    );
  }

  Widget _buildDefaultBody(ThemeData theme, String pickupText, String returnText) {
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
    final days = (start != null && end != null) ? end.difference(start).inDays.clamp(1, 365) : 1;
    final providedBasePerDay = (widget.booking['basePerDay'] as num?)?.toDouble();
    final discountPercentProvided = (widget.booking['discountPercentApplied'] as num?)?.toDouble() ?? 0.0;
    final discountAmountProvided = _discountsFromBooking();
    double baseTotal;
    double discountAmount;
    if (providedBasePerDay != null) {
      baseTotal = (providedBasePerDay * days);
      discountAmount = discountAmountProvided;
    } else {
      // Fallback: infer from totals
      final feeTmp = _serviceFee(totalPaid);
      final rentalSubtotalTmp = (totalPaid - feeTmp + discountAmountProvided).clamp(0.0, totalPaid);
      baseTotal = rentalSubtotalTmp;
      discountAmount = discountAmountProvided;
    }
    final fee = _serviceFee(totalPaid);
    final rentalSubtotal = (baseTotal - discountAmount).clamp(0.0, totalPaid);
    final daily = days > 0 ? (rentalSubtotal / days) : rentalSubtotal;

    // Cancellation deadline based on selected policy
    final policy = (widget.booking['policy'] as String?) ?? 'flexible';
    final createdAt = DateTime.tryParse((widget.booking['requestCreatedAtIso'] as String?) ?? '');
    final cancellationDeadline = (start != null && createdAt != null)
        ? DataService.freeCancellationUntil(policy: policy, start: start, createdAt: createdAt)
        : (start != null ? DataService.freeCancellationUntil(policy: policy, start: start, createdAt: DateTime.now()) : null);
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
              child: Stack(children: [
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _photos.length,
                  itemBuilder: (_, i) => SizedBox(width: double.infinity, height: 220, child: AppImage(url: _photos[i], fit: BoxFit.cover)),
                ),
                if (_photos.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (int i = 0; i < _photos.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 12 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _page ? theme.colorScheme.primary : Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )
                    ]),
                  ),
                // Status chip bottom-left overlay (all states)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Builder(builder: (context) {
                    final effectiveLocal = effective;
                    final status = (widget.booking['status'] as String?) ?? '';
                    String label; Color color;
                    if (effectiveLocal == 'completed') {
                      final cancelled = status == 'Storniert' || status == 'Abgelehnt';
                      label = cancelled ? 'Storniert' : 'Abgeschlossen';
                      color = cancelled ? const Color(0xFFF43F5E) : Colors.blueGrey;
                    } else if (effectiveLocal == 'pending') {
                      label = 'Anfrage'; color = Colors.grey;
                    } else if (effectiveLocal == 'upcoming') {
                      label = 'Kommend'; color = _statusColor('Akzeptiert');
                    } else {
                      label = 'Laufend'; color = _statusColor('Laufend');
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                    );
                  }),
                ),
                // Pickup countdown pill overlay for upcoming bookings (bottom-right on image)
                if (isUpcoming && start != null)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Builder(builder: (context) {
                      final now = DateTime.now();
                      final diff = start.difference(now);
                      String text;
                      if (diff.isNegative || diff.inDays == 0) {
                        text = 'Abholung Heute';
                      } else if (diff.inDays == 1) {
                        text = 'Abholung in 1 Tag';
                      } else {
                        text = 'Abholung in ${diff.inDays} Tagen';
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.30),
                              blurRadius: 10,
                              spreadRadius: 0.2,
                            ),
                          ],
                        ),
                        child: Row(children: [
                          const Icon(Icons.timer_outlined, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ]),
                      );
                    }),
                  ),
                // end stack children
              ]),
            ),
          ),

        // Removed row with status + actions – chip moved into the image; actions moved to overlays/menu

        // Reduce the gap after the top status row for declined as well
        SizedBox(height: (isCancelled || isDeclined || isPending || isUpcoming) ? 6 : 12),
        // Header chip row removed (status chip now overlays the image)
        if (false) const SizedBox.shrink(),

        SizedBox(height: isCancelled ? 8 : 12),
        Text(
          (widget.booking['title'] as String?) ?? '-',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
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
          durationText: (start != null && end != null) ? _formatDaysHours(end.difference(start)) : null,
          onAddPickupToCalendar: null, // Calendar links removed per request
          onAddReturnToCalendar: null,
          location: (widget.booking['location'] as String?) ?? '-',
          onMap: () => _openMaps((widget.booking['location'] as String?) ?? '-'),
          onNav: () => _openDirections((widget.booking['location'] as String?) ?? '-'),
          bookingId: isPending ? '' : _computeBookingId(),
          counterpartyName: _listerName,
          counterpartyAvatar: _listerAvatar,
          counterpartyRole: 'Vermieter',
          onCounterpartyProfile: () {
            final listerId = widget.booking['listerId'] as String?;
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: listerId)));
          },
          counterpartyRating: null,
          counterpartyReviews: null,
          onMessage: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MessageThreadScreen(participantName: _listerName, avatarUrl: _listerAvatar),
            ));
          },
            // Locations moved out of the info card for all sections
            showLocations: false,
            transportInfo: () {
              final renterPicksUpSelf = (widget.booking['ownerDeliversAtDropoffChosen'] == true) ? false : true;
              final renterReturnsSelf = (widget.booking['ownerPicksUpAtReturnChosen'] == true) ? false : true;
              if (_isOngoing) {
                return renterReturnsSelf ? 'Du bringst den Artikel selbst zurück.' : 'Der Vermieter holt den Artikel wieder ab.';
              } else if (isPending || isUpcoming) {
                if (renterPicksUpSelf) {
                  return isPending
                      ? 'Du holst den Artikel selbst ab, wenn deine Anfrage akzeptiert wird.'
                      : 'Du holst den Artikel selbst ab.';
                }
                return 'Der Vermieter bringt dir den Artikel.';
              }
              return null;
            }(),
        ),

        // Approximate pickup map directly under the info card (only for the traveler)
        if (isUpcoming)
          Builder(builder: (context) {
            final renterPicksUpSelf = (widget.booking['ownerDeliversAtDropoffChosen'] == true) ? false : true;
            if (!renterPicksUpSelf) return const SizedBox.shrink();
            final label = AddressPrivacy.nearbyShort(kindLabel: 'Abholung');
            final fullAddress = (widget.booking['location'] as String?) ?? '';
            // For confirmed bookings (upcoming), always show the exact address
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: ApproxLocationMap(lat: _itemLat, lng: _itemLng, label: label),
                ),
                const SizedBox(height: 8),
                _AddressInfoCard(
                  icon: Icons.place_outlined,
                  text: 'Abholort: $fullAddress',
                ),
              ],
            );
          }),

        // Pending (Ausstehend): gleiche Kartenlogik wie Kommend, falls der Mieter selbst abholt
        if (isPending)
          Builder(builder: (context) {
            final renterPicksUpSelf = (widget.booking['ownerDeliversAtDropoffChosen'] == true) ? false : true;
            if (!renterPicksUpSelf) return const SizedBox.shrink();
            final label = AddressPrivacy.nearbyShort(kindLabel: 'Abholung');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: ApproxLocationMap(lat: _itemLat, lng: _itemLng, label: label),
                ),
                const SizedBox(height: 8),
                _AddressInfoCard(
                  icon: Icons.lock_outline,
                  text: AddressPrivacy.privacyNoticePickup(),
                ),
              ],
            );
          }),

        // Ongoing (Laufend): Karte für Rückgabe, falls der Mieter selbst zurückbringt
        if (_isOngoing)
          Builder(builder: (context) {
            final renterReturnsSelf = (widget.booking['ownerPicksUpAtReturnChosen'] == true) ? false : true;
            if (!renterReturnsSelf) return const SizedBox.shrink();
            final label = AddressPrivacy.nearbyShort(kindLabel: 'Rückgabe');
            final fullAddress = (widget.booking['location'] as String?) ?? '';
            // For ongoing bookings, always show the exact address
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: ApproxLocationMap(lat: _itemLat, lng: _itemLng, label: label),
                ),
                const SizedBox(height: 8),
                _AddressInfoCard(
                  icon: Icons.place_outlined,
                  text: 'Rückgabeort: $fullAddress',
                ),
              ],
            );
          }),

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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Zahlungsübersicht', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _AmountRow(label: 'Mietpreis (Tagespreis × Tage)', value: _formatEuro(rentalSubtotal)),
            _AmountRow(label: 'Servicegebühr', value: _formatEuro(fee)),
            if (!isPending) ...[
              const Divider(height: 16, color: Colors.white24),
              _AmountRow(label: 'Gesamt bezahlt (Mieter)', value: _formatEuro(totalPaid), strong: true),
            ],
            if (isPending) ...[
              const SizedBox(height: 8),
              Text(
                'Es erfolgt noch keine Abbuchung. Der Betrag wird erst bei Bestätigung fällig.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
            if (_isViewerOwnerSync()) ...[
              const SizedBox(height: 8),
              if (isCompleted) ...[
                _AmountRow(label: 'Ausgezahlt (an Vermieter)', value: _formatEuro(totalPaid - fee), strong: true),
                if (end != null)
                  Text('Ausgezahlt am ${_formatPayoutDate(end)}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
              ] else ...[
                if (!isPending)
                  _AmountRow(label: 'Vorauss. Auszahlung', value: _formatEuro(totalPaid - fee), strong: true),
                if (end != null)
                  Text('Auszahlung am ${_formatPayoutDate(end)}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
              ],
            ],
            // Refund info (only relevant for Storniert)
            if (isCancelled) ...[
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final policy = (widget.booking['policy'] as String?) ?? 'flexible';
                final createdAt = DateTime.tryParse((widget.booking['requestCreatedAtIso'] as String?) ?? '');
                final now = DateTime.now();
                double ratio = 0.0;
                if (start != null) {
                  ratio = DataService.refundRatio(policy: policy, start: start, cancelAt: now, createdAt: createdAt);
                }
                final rentalRefund = (rentalSubtotal * ratio).clamp(0.0, rentalSubtotal);
                final totalRefund = rentalRefund.clamp(0.0, totalPaid);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _AmountRow(label: 'Rückerstattung (gesamt)', value: _formatEuro(totalRefund), strong: true),
                  Text('Erstattung gem. Stornobedingungen. Servicegebühr nicht erstattbar.', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                ]);
              }),
            ],
            if (!isPending) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: OutlinedButton.icon(
                  onPressed: _downloadReceiptPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Beleg herunterladen (PDF)'),
                ),
              ),
            ],
          ]),
        ),

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
                title: Text('Was passiert als Nächstes?', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                childrenPadding: const EdgeInsets.only(left: 0, right: 0, bottom: 12),
                children: const [
                  _Bullet(text: 'Warte, bis der Vermieter die Anfrage annimmt.'),
                  _Bullet(text: 'Sobald deine Anfrage akzeptiert wird, erscheint sie unter Kommende Buchungen.'),
                  _Bullet(text: 'Vereinbare mit dem Vermieter einen konkreten Zeitpunkt für Übergabe und Rückgabe.'),
                ],
              ),
            ),
          ),
          // Removed duplicate bottom 'Anfrage zurückziehen' button – now placed next to status chip
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Übergabe', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              // Kurzer Hinweis: QR & Code werden innerhalb des Flows angezeigt
              Row(children: [
                const Icon(Icons.info_outline, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'QR‑Code und 6‑stelliger Übergabe‑Code erscheinen in Schritt 2 nach dem Start.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              // Button moved to the page bottom per request
            ]) ,
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
                title: Text('Was passiert als Nächstes?', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                childrenPadding: const EdgeInsets.only(left: 0, right: 0, bottom: 12),
                children: const [
                  _Bullet(text: 'Triff dich mit dem Vermieter zum vereinbarten Übergabezeitpunkt.'),
                  _Bullet(text: 'Tippe auf „Übergabe starten“, wenn ihr euch trefft.'),
                  _Bullet(text: 'Beide müssen mindestens 4 Übergabe‑Fotos vom Artikel machen.'),
                  _Bullet(text: 'Übergabe bestätigen durch QR‑Code‑Scan oder Eingabe des 6‑stelligen Übergabecodes.'),
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
                title: Text('Was passiert als Nächstes?', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                childrenPadding: const EdgeInsets.only(left: 0, right: 0, bottom: 12),
                children: const [
                  _Bullet(text: 'Triff dich mit dem Vermieter zum vereinbarten Übergabezeitpunkt.'),
                  _Bullet(text: 'Tippe auf „Übergabe starten“, wenn ihr euch trefft.'),
                  _Bullet(text: 'Beide müssen mindestens 4 Übergabe‑Fotos vom Artikel machen.'),
                  _Bullet(text: 'Übergabe bestätigen durch QR‑Code‑Scan oder Eingabe des 6‑stelligen Übergabecodes.'),
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
            payoutFormatter: _formatPayoutDate,
            euroFormatter: _formatEuro,
            serviceFee: _serviceFee,
          ),
          const SizedBox(height: 12),
          // Prominent on-page review button when completed (renter view)
          if (!_isViewerOwnerSync())
            SizedBox(
              height: 40,
              child: FilledButton.icon(
                onPressed: () async {
                  final current = await DataService.getCurrentUser();
                  final requestId = widget.booking['requestId'] as String?;
                  final itemId = widget.booking['itemId'] as String?;
                  final listerId = widget.booking['listerId'] as String?;
                  if (current == null || requestId == null || itemId == null || listerId == null) return;
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
                  }
                },
                icon: const Icon(Icons.star_rate_outlined),
                label: const Text('Bewerten'),
              ),
            ),
          if (!_isViewerOwnerSync()) const SizedBox(height: 12),
        ] else ...[
          // No additional Stornierungsbedingungen here; shown above Zahlungsübersicht already
          const SizedBox.shrink(),
        ],

        const SizedBox(height: 16),
        // Bottom primary action for upcoming bookings: move here per request
        if (isUpcoming)
          FilledButton.icon(
            onPressed: _startPickupFlow,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Übergabe starten'),
          ),
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
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        _toast('Karte konnte nicht geöffnet werden');
      }
    } catch (_) {
      _toast('Karte konnte nicht geöffnet werden');
    }
  }

  Future<void> _openDirections(String destination) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}');
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
    final uid = '${_computeBookingId()}-${isPickup ? 'pickup' : 'return'}@shareittoo';

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

    final dataUri = Uri.dataFromString(ics, mimeType: 'text/calendar', encoding: utf8);
    try {
      await launchUrl(dataUri, mode: LaunchMode.platformDefault);
    } catch (_) {
      _toast('Kalendereintrag konnte nicht erstellt werden');
    }
  }

  String _computeBookingId() {
    final seed = ((widget.booking['title']?.hashCode ?? 0) ^ (widget.booking['dates']?.hashCode ?? 0) ^ (widget.booking['location']?.hashCode ?? 0)).abs();
    final s = seed.toString().padLeft(8, '0');
    return 'BKG-${s.substring(0, 4)}-${s.substring(4, 8)}';
    }

  String _handoverCode() {
    // Unified generation: based on title + start datetime
    final title = (widget.booking['title'] as String?) ?? '';
    // Try ISO first, then fall back to parsing the human string
    DateTime? start = DateTime.tryParse((widget.booking['startIso'] as String?) ?? '');
    if (start == null) {
      final (s, _) = _CompletionSummaryCard._parseStaticDateRange(widget.booking);
      start = s;
    }
    // If still null, use now to avoid crashes (code will then match both sides for this view)
    start ??= DateTime.now();
    return HandoverCodeService.codeFromTitleAndStart(title: title, start: start);
  }

  double _parseEuro(String s) {
    if (s.isEmpty) return 0.0;
    final cleaned = s.replaceAll('€', '').replaceAll('EUR', '').replaceAll('.', '').replaceAll(',', '.').trim();
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
    final months = ['Jan','Feb','Mär','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'];
    final m = months[(payout.month - 1).clamp(0, 11)];
    final dd = payout.day.toString().padLeft(2, '0');
    return '$dd. $m';
  }

  String _formatPickupCountdown(Duration d) {
    if (d.isNegative || d.inDays == 0) {
      return 'Abholung Heute';
    }
    if (d.inDays == 1) return 'Abholung in 1 Tag';
    return 'Abholung in ${d.inDays} Tagen';
  }

  String _formatDeadline(DateTime dt) {
    final months = ['Jan','Feb','Mär','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'];
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
          child: Stack(children: [
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
                        color: theme.colorScheme.primary.withValues(alpha: 0.45),
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
          ]),
        );
      },
      transitionBuilder: (context, anim, anim2, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
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
    final days = (start != null && end != null) ? math.max(1, end.difference(start).inDays) : 1;
    final totalPaid = _parseEuro((widget.booking['pricePaid'] as String?) ?? '0');
    final pricePerDay = days > 0 ? (totalPaid / days) : totalPaid;

    final itemIdSeed = ((widget.booking['title']?.hashCode ?? 0) ^ (widget.booking['location']?.hashCode ?? 0)).abs().toString();
    final reqIdSeed = ((widget.booking['dates']?.hashCode ?? 0) ^ (widget.booking['title']?.hashCode ?? 0)).abs().toString();

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
      deposit: totalPaid > 100 ? math.min(200.0, totalPaid * 0.25) : (totalPaid > 0 ? 50.0 : 0.0),
    );

    final req = RentalRequest(
      id: 'req_$reqIdSeed',
      itemId: item.id,
      ownerId: item.ownerId,
      renterId: (widget.booking['listerId'] as String?) ?? 'renter_local',
      start: start ?? DateTime.now().subtract(const Duration(days: 1)),
      end: end ?? DateTime.now().add(const Duration(days: 1)),
      status: 'running',
      message: null,
    );

    final renterName = widget.viewerIsOwner ? _listerName : 'Mieter';
    final ownerName = widget.viewerIsOwner ? 'Vermieter' : _listerName;

    final ok = await ReturnHandoverStepperSheet.push(
      context,
      item: item,
      request: req,
      renterName: renterName,
      ownerName: ownerName,
      handoverCode: _handoverCode(),
      viewerIsOwner: widget.viewerIsOwner,
      mode: ReturnFlowMode.returnFlow,
    );

    if (ok == true && mounted) {
      setState(() {
        widget.booking['status'] = 'Abgeschlossen';
      });
      final titleTxt = (widget.booking['title'] as String?) ?? '';
      final listerId = widget.booking['listerId'] as String?;
      final itemId = widget.booking['itemId'] as String?;
      final requestId = widget.booking['requestId'] as String?;
      final viewerIsOwner = widget.viewerIsOwner;
      final whoToRateName = viewerIsOwner ? (widget.booking['renterName'] as String? ?? 'Mieter') : _listerName;

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
            onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
            child: const Text('OK'),
          ),
        ],
      );
      // Schedule a 10-minute review reminder for the current viewer (renter in this page)
      try {
        final current = await DataService.getCurrentUser();
        if (current != null && requestId != null && itemId != null && listerId != null && !viewerIsOwner) {
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
    final days = (start != null && end != null) ? math.max(1, end.difference(start).inDays) : 1;
    final totalPaid = _parseEuro((widget.booking['pricePaid'] as String?) ?? '0');
    final pricePerDay = days > 0 ? (totalPaid / days) : totalPaid;

    final itemIdSeed = ((widget.booking['title']?.hashCode ?? 0) ^ (widget.booking['location']?.hashCode ?? 0)).abs().toString();
    final reqIdSeed = ((widget.booking['dates']?.hashCode ?? 0) ^ (widget.booking['title']?.hashCode ?? 0)).abs().toString();

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

    final req = RentalRequest(
      id: 'req_$reqIdSeed',
      itemId: item.id,
      ownerId: item.ownerId,
      renterId: (widget.booking['listerId'] as String?) ?? 'renter_local',
      start: start ?? DateTime.now().add(const Duration(hours: 1)),
      end: end ?? DateTime.now().add(const Duration(days: 1)),
      status: 'accepted',
      message: null,
    );

    final renterName = widget.viewerIsOwner ? _listerName : 'Mieter';
    final ownerName = widget.viewerIsOwner ? 'Vermieter' : _listerName;

    await ReturnHandoverStepperSheet.push(
      context,
      item: item,
      request: req,
      renterName: renterName,
      ownerName: ownerName,
      handoverCode: _handoverCode(),
      viewerIsOwner: widget.viewerIsOwner,
      mode: ReturnFlowMode.pickupFlow,
    );
  }

  Future<void> _downloadReceiptPdf() async {
    // Lightweight HTML receipt (user can print/save as PDF in browser)
    final title = (widget.booking['title'] as String?) ?? '-';
    final bookingId = _computeBookingId();
    final (start, end) = _parseDateRange();
    final pricePaidStr = (widget.booking['pricePaid'] as String?) ?? '';
    final totalPaid = _parseEuro(pricePaidStr);
    final fee = _serviceFee(totalPaid);
    final rentalSubtotal = (totalPaid - fee + _discountsFromBooking()).clamp(0.0, totalPaid);
    // Refund computation (demo logic based on policy and assumed cancel time = now)
    final policy = (widget.booking['policy'] as String?) ?? 'flexible';
    final createdAt = DateTime.tryParse((widget.booking['requestCreatedAtIso'] as String?) ?? '');
    final status = (widget.booking['status'] as String?) ?? '';
    final now = DateTime.now();
    double refundRatio = 0.0;
    if (status == 'Storniert' && start != null) {
      refundRatio = DataService.refundRatio(policy: policy, start: start, cancelAt: now, createdAt: createdAt);
    }
    final rentalRefund = (rentalSubtotal * refundRatio).clamp(0.0, rentalSubtotal);
    final totalRefund = rentalRefund.clamp(0.0, totalPaid);
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
<div style="margin:8px 0 16px 0">$title</div>
<div class="muted">Zeitraum: ${(widget.booking['dates'] as String?) ?? '-'}</div>
<hr>
<table>
   <tr><td>Mietpreis (Tagespreis × Tage)</td><td class="right">${_formatEuro(rentalSubtotal)}</td></tr>
  <tr><td>Servicegebühr</td><td class="right">${_formatEuro(fee)}</td></tr>
  <tr><td colspan="2"><hr></td></tr>
  <tr><td class="total">Gesamt bezahlt (Mieter)</td><td class="right total">${_formatEuro(totalPaid)}</td></tr>
  ${totalRefund > 0 ? '<tr><td class="total">Rückerstattung gesamt</td><td class="right total">${_formatEuro(totalRefund)}</td></tr>' : '<tr><td>Rückerstattung</td><td class="right">0,00 €</td></tr>'}
</table>
<p class="muted">${status == 'Storniert' ? 'Erstattung gem. Stornobedingungen (Servicegebühr ausgenommen).' : 'Keine Erstattung angewendet.'}</p>
<p class="muted">ShareItToo – Quittung ohne Gewähr.</p>
</html>
''';
    final dataUri = Uri.dataFromString(html, mimeType: 'text/html', encoding: utf8);
    try {
      await launchUrl(dataUri, mode: LaunchMode.platformDefault);
    } catch (_) {
      _toast('Beleg konnte nicht geöffnet werden');
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
          child: Stack(children: [
            MobileScanner(
              controller: MobileScannerController(detectionSpeed: DetectionSpeed.normal, facing: CameraFacing.back, torchEnabled: false),
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
              child: IconButton(onPressed: () => Navigator.of(ctx).maybePop(), icon: const Icon(Icons.close, color: Colors.white)),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: const Text('Scanne den QR‑Code des Vermieters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            )
          ]),
        );
      },
    );

    if (!mounted) return;
    if (scanned == null || scanned!.isEmpty) {
      AppPopup.toast(context, icon: Icons.qr_code_2, title: 'Kein Code erkannt');
      return;
    }

    try {
      final raw = scanned!.trim();
      final okPrefix = raw.startsWith('shareittoo:handover:');
      final parts = raw.split(':');
      final bkg = parts.length >= 4 ? parts[3] : '';
      final matches = okPrefix && bkg == _computeBookingId();
      if (!matches) {
        AppPopup.toast(context, icon: Icons.error_outline, title: 'Ungültiger QR‑Code');
        return;
      }

      final requestId = widget.booking['requestId'] as String?;
      if (requestId != null && requestId.isNotEmpty) {
        await DataService.updateRentalRequestStatus(requestId: requestId, status: 'running');
      }
      if (!mounted) return;
      setState(() { widget.booking['status'] = 'Laufend'; widget.booking['category'] = 'ongoing'; });
      final title = (widget.booking['title'] as String?) ?? '';
      await DataService.addNotification(title: 'Übergabe bestätigt', body: 'Übergabe des Listings "$title" bestätigt.');
      AppPopup.toast(context, icon: Icons.check_circle_outline, title: 'Übergabe per QR bestätigt');
    } catch (e) {
      if (!mounted) return;
      AppPopup.toast(context, icon: Icons.error_outline, title: 'Bestätigung fehlgeschlagen');
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
          child: Stack(children: [
            MobileScanner(
              controller: MobileScannerController(detectionSpeed: DetectionSpeed.normal, facing: CameraFacing.back, torchEnabled: false),
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
              child: IconButton(onPressed: () => Navigator.of(ctx).maybePop(), icon: const Icon(Icons.close, color: Colors.white)),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: const Text('Scanne den QR‑Code des Mieters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            )
          ]),
        );
      },
    );

    if (!mounted) return;
    if (scanned == null || scanned!.isEmpty) {
      AppPopup.toast(context, icon: Icons.qr_code_2, title: 'Kein Code erkannt');
      return;
    }

    try {
      final raw = scanned!.trim();
      final parts = raw.split(':');
      final okPrefix = raw.startsWith('shareittoo:handover:');
      final code = parts.length >= 3 ? parts[2] : '';
      final bkg = parts.length >= 4 ? parts[3] : '';
      final matches = okPrefix && code == _handoverCode() && bkg == _computeBookingId();
      if (!matches) {
        AppPopup.toast(context, icon: Icons.error_outline, title: 'Ungültiger QR‑Code');
        return;
      }

      final requestId = widget.booking['requestId'] as String?;
      if (requestId != null && requestId.isNotEmpty) {
        await DataService.updateRentalRequestStatus(requestId: requestId, status: 'completed');
        await DataService.addTimelineEvent(requestId: requestId, type: 'completed', note: 'Rückgabe abgeschlossen');
      }
      if (!mounted) return;
      setState(() { widget.booking['status'] = 'Abgeschlossen'; widget.booking['category'] = 'completed'; });
      final title = (widget.booking['title'] as String?) ?? '';
      await DataService.addNotification(title: 'Buchung abgeschlossen', body: 'Die Rückgabe für "$title" wurde abgeschlossen. Beleg gesendet.');
      AppPopup.toast(context, icon: Icons.check_circle_outline, title: 'Rückgabe per QR bestätigt');
      // Schedule a review reminder for the current user (viewer on this page rates the counterparty)
      try {
        final current = await DataService.getCurrentUser();
        final requestId = widget.booking['requestId'] as String?;
        final itemId = widget.booking['itemId'] as String?;
        final listerId = widget.booking['listerId'] as String?;
        if (current != null && requestId != null && itemId != null && listerId != null) {
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
      AppPopup.toast(context, icon: Icons.error_outline, title: 'Bestätigung fehlgeschlagen');
    }
  }

  Future<void> _confirmManualReturnByCode() async {
    final entered = _manualReturnCodeCtrl.text.trim();
    if (entered.isEmpty) {
      AppPopup.toast(context, icon: Icons.error_outline, title: 'Bitte Code eingeben');
      return;
    }
    if (entered != _handoverCode()) {
      AppPopup.toast(context, icon: Icons.error_outline, title: 'Falscher Code');
      return;
    }
    try {
      final requestId = widget.booking['requestId'] as String?;
      if (requestId != null && requestId.isNotEmpty) {
        await DataService.updateRentalRequestStatus(requestId: requestId, status: 'completed');
        await DataService.addTimelineEvent(requestId: requestId, type: 'completed', note: 'Rückgabe manuell bestätigt');
      }
      if (!mounted) return;
      setState(() { widget.booking['status'] = 'Abgeschlossen'; widget.booking['category'] = 'completed'; });
      final title = (widget.booking['title'] as String?) ?? '';
      await DataService.addNotification(title: 'Buchung abgeschlossen', body: 'Die Rückgabe für "$title" wurde abgeschlossen. Beleg gesendet.');
      AppPopup.toast(context, icon: Icons.check_circle_outline, title: 'Rückgabe per Code bestätigt');
      setState(() { _showManualReturnEntry = false; _manualReturnCodeCtrl.clear(); });
      // Schedule a review reminder for the current user
      try {
        final current = await DataService.getCurrentUser();
        final requestId = widget.booking['requestId'] as String?;
        final itemId = widget.booking['itemId'] as String?;
        final listerId = widget.booking['listerId'] as String?;
        if (current != null && requestId != null && itemId != null && listerId != null) {
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
      AppPopup.toast(context, icon: Icons.error_outline, title: 'Bestätigung fehlgeschlagen');
    }
  }

  Future<void> _confirmManualPickupAsRenter() async {
    await AppPopup.show(
      context,
      icon: Icons.help_outline,
      title: 'Manuell bestätigen?',
      message: 'Bestätigst du, dass du den Gegenstand abgeholt hast?',
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).maybePop();
            try {
              final id = widget.booking['requestId'] as String?;
              if (id != null && id.isNotEmpty) {
                await DataService.updateRentalRequestStatus(requestId: id, status: 'running');
              }
              if (!mounted) return;
              setState(() { widget.booking['status'] = 'Laufend'; widget.booking['category'] = 'ongoing'; });
              // Prepare cross-party banner + notification
              final bookingId = _computeBookingId();
              final title = (widget.booking['title'] as String?) ?? '';
              final message = 'Übergabe des Listings "${title}" wurde vom Mieter bestätigt.';
              await DataService.addNotification(title: 'Übergabe bestätigt', body: message);
              await DataService.setHandoverBanner(bookingId: bookingId, message: message);
              AppPopup.toast(context, icon: Icons.check_circle_outline, title: 'Abholung bestätigt');
            } catch (e) {
              if (!mounted) return;
              AppPopup.toast(context, icon: Icons.error_outline, title: 'Konnte nicht bestätigen');
            }
          },
          child: const Text('Ja, bestätigt'),
        ),
      ],
    );
  }

  Future<void> _confirmManualPickupByCode() async {
    final entered = _manualPickupCodeCtrl.text.trim();
    if (entered.isEmpty) {
      AppPopup.toast(context, icon: Icons.error_outline, title: 'Bitte Code eingeben');
      return;
    }
    if (entered != _handoverCode()) {
      AppPopup.toast(context, icon: Icons.error_outline, title: 'Falscher Code');
      return;
    }
    try {
      final requestId = widget.booking['requestId'] as String?;
      if (requestId != null && requestId.isNotEmpty) {
        await DataService.updateRentalRequestStatus(requestId: requestId, status: 'running');
      }
      if (!mounted) return;
      setState(() {
        widget.booking['status'] = 'Laufend';
        widget.booking['category'] = 'ongoing';
      });
      final bookingId = _computeBookingId();
      final title = (widget.booking['title'] as String?) ?? '';
      final message = 'Übergabe des Listings "$title" wurde vom Mieter bestätigt.';
      await DataService.addNotification(title: 'Übergabe bestätigt', body: message);
      await DataService.setHandoverBanner(bookingId: bookingId, message: message);
      AppPopup.toast(context, icon: Icons.check_circle_outline, title: 'Übergabe per Code bestätigt');
      setState(() { _showManualPickupEntry = false; _manualPickupCodeCtrl.clear(); });
    } catch (e) {
      if (!mounted) return;
      AppPopup.toast(context, icon: Icons.error_outline, title: 'Bestätigung fehlgeschlagen');
    }
  }

  Future<void> _confirmCancelUpcoming() async {
    // Show minimal confirmation text per request (no refund breakdown)
    final policy = (widget.booking['policy'] as String?) ?? 'flexible';
    final policyName = DataService.policyName(policy);

    await AppPopup.show(
      context,
      icon: Icons.close,
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
        OutlinedButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).maybePop();
            final id = widget.booking['requestId'] as String?;
            if (id != null && id.isNotEmpty) {
              await DataService.updateRentalRequestStatus(requestId: id, status: 'cancelled');
            }
            if (!mounted) return;
            // Navigate to Bookings -> Abgeschlossen with highlight on the cancelled card
            AppPopup.toast(context, icon: Icons.cancel_outlined, title: 'Buchung storniert');
            // Replace the detail page with the bookings screen focused on "Abgeschlossen"
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => BookingsScreen(initialTabIndex: 3, highlightRequestId: id ?? ''),
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
          onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).maybePop();
            final id = widget.booking['requestId'] as String?;
            if (id != null) {
              await DataService.updateRentalRequestStatus(requestId: id, status: 'cancelled');
            }
            if (!mounted) return;
            setState(() => widget.booking['status'] = 'Zurückgezogen');
            await AppPopup.toast(context, icon: Icons.undo, title: 'Anfrage wurde zurückgezogen');
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
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String label; final String value; final Widget? trailing;
  const _InfoRow({required this.icon, required this.label, required this.value, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Colors.white, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ])),
      if (trailing != null) ...[
        const SizedBox(width: 8),
        trailing!,
      ]
    ]);
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (transportInfo != null && transportInfo!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Center(
              child: Text(
                transportInfo!,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
              style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 6),
        _InfoRowModern(icon: Icons.schedule, label: 'Zeitraum', value: datesText),
        if (durationText != null) ...[
          const SizedBox(height: 3),
          _InfoRowModern(icon: Icons.timelapse, label: 'Dauer', value: durationText!),
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
              trailing: enablePickupMapActions ? _MapActions(onMap: onMap, onNav: onNav) : null,
            ),
            const SizedBox(height: 3),
          ],
          if (returnVisible != false) ...[
            _InfoRowModern(
              icon: Icons.place,
              label: 'Rückgabeort',
              value: (returnAddress ?? location),
              trailing: enableReturnMapActions ? _MapActions(onMap: onMap, onNav: onNav) : null,
            ),
            const SizedBox(height: 4),
          ],
        ],

        if (bookingId.trim().isNotEmpty)
          _InfoRowModern(icon: Icons.tag, label: 'Buchungs-ID', value: bookingId),

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
      ]),
    );
  }
}

class _InfoRowModern extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  const _InfoRowModern({required this.icon, required this.label, required this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
      if (trailing != null) ...[
        const SizedBox(width: 8),
        trailing!,
      ],
    ]);
  }
}

class _MapLink extends StatelessWidget {
  final VoidCallback onTap;
  const _MapLink({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, child: Text('Karte', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)));
  }
}

class _MapActions extends StatelessWidget {
  final VoidCallback onMap; final VoidCallback onNav;
  const _MapActions({required this.onMap, required this.onNav});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      InkWell(onTap: onMap, child: Text('Karte', style: TextStyle(color: color, fontWeight: FontWeight.w700))),
      const SizedBox(width: 8),
      InkWell(onTap: onNav, child: Text('Navigation starten', style: TextStyle(color: color, fontWeight: FontWeight.w700))),
    ]);
  }
}

class _CounterpartyInlineRow extends StatelessWidget {
  final String name; final String? avatarUrl; final String role; final VoidCallback? onMessage;
  const _CounterpartyInlineRow({required this.name, this.avatarUrl, required this.role, this.onMessage});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      CircleAvatar(radius: 18, backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null, child: avatarUrl == null ? const Icon(Icons.person) : null),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(role, style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      if (onMessage != null)
        IconButton(
          tooltip: 'Nachricht schreiben',
          onPressed: onMessage,
          icon: const Icon(Icons.chat_bubble_outline, color: Colors.white70),
        ),
    ]);
  }
}

class _CounterpartyRow extends StatelessWidget {
  final String name; final String? avatarUrl; final String role; final VoidCallback? onProfile;
  final double? rating; final int? reviewsCount; final int? trustPercent;
  const _CounterpartyRow({required this.name, this.avatarUrl, required this.role, this.onProfile, this.rating, this.reviewsCount, this.trustPercent});
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
    return Row(children: [
      CircleAvatar(radius: 18, backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null, child: avatarUrl == null ? const Icon(Icons.person) : null),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        Row(children: [
          Text(role, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
          if (ratingText != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.star_rate_rounded, color: Colors.amber, size: 16),
            const SizedBox(width: 2),
            Text(ratingText, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
          ],
        ]),
      ])),
      TextButton(onPressed: onProfile, child: const Text('Zum Profil')),
    ]);
  }
}

class _AmountRow extends StatelessWidget {
  final String label; final String value; final bool strong;
  const _AmountRow({required this.label, required this.value, this.strong = false});
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: strong ? FontWeight.w800 : FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600))),
        Text(value, style: style),
      ]),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});
  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.3);
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
  final IconData icon; final String label; final VoidCallback onPressed;
  const _PrimaryCTA({required this.icon, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _SecondaryCTA extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _SecondaryCTA({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: Colors.white70),
        label: Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ListerCard extends StatelessWidget {
  final String name; final String? avatarUrl; final VoidCallback? onMessage;
  const _ListerCard({required this.name, this.avatarUrl, this.onMessage});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 22, backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null, child: avatarUrl == null ? const Icon(Icons.person) : null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('Antwortet in der Regel schnell', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
          ])),
        ]),
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
        ]
      ]),
    );
  }
}

class _CancellationPolicyCard extends StatefulWidget {
  final Map<String, dynamic> booking;
  final bool initiallyOpen;
  const _CancellationPolicyCard({required this.booking, this.initiallyOpen = false});
  @override
  State<_CancellationPolicyCard> createState() => _CancellationPolicyCardState();
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
    final months = ['Jan','Feb','Mär','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'];
    final m = months[(dt.month - 1).clamp(0, 11)];
    final dd = dt.day.toString().padLeft(2, '0');
    return '$dd. $m';
  }
  @override
  Widget build(BuildContext context) {
    final policy = (widget.booking['policy'] as String?) ?? 'flexible';
    final policyName = DataService.policyName(policy);
    // Resolve start from ISO or fallback to parsed range from dates text
    DateTime? start = DateTime.tryParse((widget.booking['startIso'] as String?) ?? '');
    if (start == null) {
      final (s, _) = _CompletionSummaryCard._parseStaticDateRange(widget.booking);
      start = s;
    }
    final createdAt = DateTime.tryParse((widget.booking['requestCreatedAtIso'] as String?) ?? '');
    final freeUntil = (start != null)
        ? DataService.freeCancellationUntil(policy: policy, start: start, createdAt: createdAt ?? DateTime.now())
        : null;
    String header = 'Stornierungsbedingungen';
    String bodyText;
    switch (policy) {
      case 'strict':
        // Remove emoji icons from the header per design update
        header = 'Stornierungsbedingungen – Streng';
        bodyText = 'Solange deine Anfrage noch aussteht, kannst du sie jederzeit über das Drei-Punkte-Menü oben rechts zurückziehen.\n\n'
            'Nach Bestätigung gelten:\n'
            '• Kostenlos nur innerhalb von 1 Stunde nach Annahme (wenn mehr als 48 Std. bis Mietbeginn).\n'
            '• Danach: keine Rückerstattung.\n'
            '• Nicht-Erscheinen: keine Rückerstattung.\n\n'
            '📌 Hinweis:\n'
            '– Servicegebühr und Expresszuschlag bekommst du nur zurück, wenn deine Anfrage noch nicht akzeptiert wurde.\n'
            '– Wenn der Vermieter nach Annahme deiner Anfrage storniert, bekommst du den vollen Betrag inkl. Servicegebühr automatisch zurückerstattet.';
        break;
      case 'moderate':
        header = 'Stornierungsbedingungen – Standard';
        bodyText = 'Solange deine Anfrage noch aussteht, kannst du sie jederzeit über das Drei-Punkte-Menü oben rechts zurückziehen.\n\n'
            'Nach Bestätigung gelten:\n'
            '• Kostenlos bis 48 Std. vor Mietbeginn.\n'
            '• Zwischen 12–48 Std. vorher: 50% Rückerstattung.\n'
            '• Weniger als 12 Std. vorher oder nach Mietbeginn: keine Rückerstattung.\n\n'
            '📌 Hinweis:\n'
            '– Servicegebühr und Expresszuschlag bekommst du nur zurück, wenn deine Anfrage noch nicht akzeptiert wurde.\n'
            '– Wenn der Vermieter nach Annahme deiner Anfrage storniert, bekommst du den vollen Betrag inkl. Servicegebühr automatisch zurückerstattet.';
        break;
      default:
        header = 'Stornierungsbedingungen – Flexibel';
        bodyText = 'Solange deine Anfrage noch aussteht, kannst du sie jederzeit über das Drei-Punkte-Menü oben rechts zurückziehen.\n\n'
            'Nach Bestätigung gelten:\n'
            '• Kostenlos bis 24 Std. vor Mietbeginn.\n'
            '• Weniger als 24 Std. vorher: 50% Rückerstattung.\n'
            '• Nicht-Erscheinen: keine Rückerstattung.\n\n'
            '📌 Hinweis:\n'
            '– Servicegebühr und Expresszuschlag bekommst du nur zurück, wenn deine Anfrage noch nicht akzeptiert wurde.\n'
            '– Wenn der Vermieter nach Annahme deiner Anfrage storniert, bekommst du den vollen Betrag inkl. Servicegebühr automatisch zurückerstattet.';
    }
    final status = (widget.booking['status'] as String?)?.toLowerCase() ?? '';
    final category = (widget.booking['category'] as String?)?.toLowerCase() ?? '';
    final isPending = category == 'pending' || status.contains('ausstehend') || status.contains('angefragt');
    // Deadline line intentionally removed per new copy – keep messaging focused
    const String deadlineLine = '';
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              const Icon(Icons.policy_outlined, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(child: Text(header, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white))),
              Icon(_open ? Icons.expand_less : Icons.expand_more, color: Colors.white70),
            ]),
          ),
        ),
        AnimatedCrossFade(
          crossFadeState: _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Builder(builder: (context) {
              return Text(bodyText + deadlineLine,
                  style: const TextStyle(color: Colors.white70, height: 1.3));
            }),
          ),
          secondChild: const SizedBox(height: 0),
        ),
      ]),
    );
  }
}

// Summary card for completed/cancelled bookings with key facts
class _CompletionSummaryCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isOwnerView;
  final String Function(DateTime) payoutFormatter;
  final String Function(double) euroFormatter;
  final double Function(double) serviceFee;

  const _CompletionSummaryCard({
    required this.booking,
    required this.isOwnerView,
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
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );

    List<Widget> rows = [];
    if (status == 'Storniert') {
      rows.addAll([
        _FactRow(icon: Icons.cancel_outlined, label: 'Status', value: 'Storniert', color: const Color(0xFFF43F5E)),
        if (returnedAt != null)
          _FactRow(icon: Icons.event_busy, label: 'Storniert am', value: _fmtDate(returnedAt)),
        _FactRow(
          icon: Icons.receipt_long_outlined,
          label: 'Beleg',
          value: 'Erstattung gem. Richtlinien',
        ),
      ]);
    } else {
      // Abgeschlossen
      rows.addAll([
        _FactRow(icon: Icons.verified_outlined, label: 'Status', value: 'Abgeschlossen', color: Colors.blueGrey),
        if (returnedAt != null)
          _FactRow(icon: Icons.assignment_turned_in_outlined, label: 'Rückgabe bestätigt', value: _fmtDate(returnedAt)),
        if (isOwnerView)
          _FactRow(icon: Icons.payments_outlined, label: 'Auszahlung', value: euroFormatter((totalPaid - fee).clamp(0.0, totalPaid))),
        if (isOwnerView && payoutAt != null)
          _FactRow(icon: Icons.event_available_outlined, label: 'Ausgezahlt am', value: payoutFormatter(payoutAt)),
      ]);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Abschluss-Zusammenfassung', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ..._withDividers(rows),
      ]),
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

  static (DateTime?, DateTime?) _parseStaticDateRange(Map<String, dynamic> booking) {
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
      key = key.substring(0, 1).toUpperCase() + key.substring(1, math.min(key.length, 3)).toLowerCase();
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
    final months = ['Jan','Feb','Mär','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'];
    final m = months[(dt.month - 1).clamp(0, 11)];
    final dd = dt.day.toString().padLeft(2, '0');
    return '$dd. $m';
  }

  static double _parseStaticEuro(String s) {
    if (s.isEmpty) return 0.0;
    final cleaned = s.replaceAll('€', '').replaceAll('EUR', '').replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }
}

class _FactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _FactRow({required this.icon, required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ])),
    ]);
  }
}

class _ReturnReminderCard extends StatelessWidget {
  final int? valueMinutes; final ValueChanged<int?> onChanged;
  const _ReturnReminderCard({required this.valueMinutes, required this.onChanged});
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.alarm, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Erinnerung zur Rückgabe', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(_humanize(valueMinutes), style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
          ])),
          const Icon(Icons.chevron_right, color: Colors.white38),
        ]),
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
  final String current; // one of Requested, Accepted, Paid, Picked up, Laufend, Due, Completed, Überfällig
  const _Timeline({required this.current});

  @override
  Widget build(BuildContext context) {
    final steps = ['Requested','Accepted','Paid','Picked up','Laufend','Due','Completed'];
    final isOverdue = current == 'Überfällig';
    final currentIndex = isOverdue ? 5 : steps.indexOf(current);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < steps.length; i++)
          _StepChip(
            label: steps[i],
            state: i < currentIndex ? _StepState.done : (i == currentIndex ? (isOverdue ? _StepState.overdue : _StepState.current) : _StepState.todo),
          ),
        if (isOverdue) _StepChip(label: 'Überfällig', state: _StepState.overdue),
      ],
    );
  }
}

enum _StepState { done, current, todo, overdue }

class _StepChip extends StatelessWidget {
  final String label; final _StepState state;
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
