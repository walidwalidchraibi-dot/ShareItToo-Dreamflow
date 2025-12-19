import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/screens/message_thread_screen.dart';
import 'package:lendify/screens/public_profile_screen.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/widgets/item_details_overlay.dart';
import 'package:lendify/widgets/return_handover_stepper_sheet.dart';
import 'package:lendify/widgets/review_prompt_sheet.dart';
import 'package:lendify/screens/owner_requests_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/screens/report_issue_screen.dart';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:lendify/services/address_privacy.dart';
import 'package:lendify/widgets/approx_location_map.dart';
import 'package:lendify/widgets/sit_overflow_menu.dart';
import 'package:lendify/services/handover_code.dart';

class OngoingOwnerDetailScreen extends StatefulWidget {
  final String requestId;
  final String? titleOverride; // Allows caller to reflect the source tab name
  const OngoingOwnerDetailScreen({super.key, required this.requestId, this.titleOverride});

  @override
  State<OngoingOwnerDetailScreen> createState() => _OngoingOwnerDetailScreenState();
}

class _OngoingOwnerDetailScreenState extends State<OngoingOwnerDetailScreen> {
  RentalRequest? _req; Item? _item; User? _renter; User? _owner;
  bool _showManualHandover = false;
  final TextEditingController _manualCodeCtrl = TextEditingController();
  Map<String, dynamic>? _deliverySel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final req = await DataService.getRentalRequestById(widget.requestId);
    if (req == null) return;
    final item = await DataService.getItemById(req.itemId);
    final renter = await DataService.getUserById(req.renterId);
    final owner = await DataService.getUserById(req.ownerId);
    final sel = item != null ? await DataService.getSavedDeliverySelection(item.id) : null;
    setState(() { _req = req; _item = item; _renter = renter; _owner = owner; _deliverySel = sel; });
    // Show one-time handover banner if present (e.g., renter confirmed)
    if (mounted && item != null) {
      final bookingId = _computeBookingId(item, req);
      final msg = await DataService.takeHandoverBanner(bookingId);
      if (msg != null && msg.isNotEmpty && mounted) {
        AppPopup.toast(context, icon: Icons.check_circle_outline, title: msg);
      }
    }
  }

  List<String> get _photos => (_item?.photos ?? const <String>[]);

  @override
  Widget build(BuildContext context) {
    final req = _req; final item = _item; final renter = _renter;
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
                final picked = await showSITOverflowMenu<String>(context, options: [
                  const SitMenuOption(icon: Icons.visibility_rounded, label: 'Anzeige ansehen', value: 'view'),
                  if (cat == 'upcoming') const SitMenuOption(icon: Icons.cancel_outlined, label: 'Stornieren', value: 'cancel'),
                  const SitMenuOption(icon: Icons.error_outline, label: 'Problem melden', value: 'issue'),
                ]);
                switch (picked) {
                  case 'view':
                    ItemDetailsOverlay.showFullPage(context, item: item);
                    break;
                  case 'cancel':
                    await AppPopup.show(
                      context,
                      icon: Icons.close,
                      title: 'Buchung stornieren?',
                      message: 'Bist du sicher? Diese Buchung wird storniert und der Mieter wird informiert.',
                      barrierDismissible: true,
                      plainCloseIcon: true,
                      actions: [
                        OutlinedButton(onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(), child: const Text('Abbrechen')),
                        FilledButton(
                          onPressed: () async {
                            Navigator.of(context, rootNavigator: true).maybePop();
                            await DataService.updateRentalRequestStatus(requestId: req.id, status: 'cancelled');
                            await DataService.addTimelineEvent(requestId: req.id, type: 'cancelled', note: 'Von Vermieter storniert');
                            if (!mounted) return;
                            AppPopup.toast(context, icon: Icons.cancel_outlined, title: 'Buchung storniert');
                            await _load();
                          },
                          child: const Text('Stornieren'),
                        ),
                      ],
                    );
                    break;
                  case 'issue':
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ReportIssueScreen(requestId: req.id, itemTitle: item.title),
                    ));
                    break;
                  default:
                }
              },
            ),
        ],
      ),
      body: (req == null || item == null || renter == null)
          ? const Center(child: CircularProgressIndicator())
          : _buildOngoingBody(context, req, item, renter),
    );
  }

  String _titleFromReq() {
    final r = _req;
    if (r == null) return 'Laufende Anmietung';
    switch (_categoryFor(r)) {
      case 'requests':
        return 'Mietanfrage';
      case 'upcoming':
        return 'Kommende Anmietung';
      case 'completed':
        return 'Abgeschlossene Anmietung';
      case 'ongoing':
      default:
        return 'Laufende Anmietung';
    }
  }

  String _categoryFor(RentalRequest r) {
    if (r.status == 'pending') return 'requests';
    if (r.status == 'completed' || r.status == 'cancelled' || r.status == 'declined') return 'completed';
    final now = DateTime.now();
    if (now.isBefore(r.start)) return 'upcoming';
    if (now.isBefore(r.end)) return 'ongoing';
    return 'completed';
  }

  Widget _buildOngoingBody(BuildContext context, RentalRequest req, Item item, User renter) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final due = req.end;
    final diff = due.difference(now);
    final isOverdue = now.isAfter(due) && req.status != 'completed';
    final category = _categoryFor(req);

    final isCompleted = req.status == 'completed';
    final title = item.title;
    final location = item.locationText ?? (item.city ?? '');
    final bool ownerDelivers = (_deliverySel?['hinweg'] == true);
    final bool ownerPicksUp = (_deliverySel?['rueckweg'] == true);
    final String targetAddr = _composeTargetAddress(_deliverySel, fallback: location);

    final days = (req.end.difference(req.start).inHours / 24).ceil().clamp(1, 365);
    double totalPaid = DataService.computeTotalWithDiscounts(item: item, days: days).$1;
    // Add express fee if accepted
    final bool expressOn = req.expressRequested && (req.expressStatus == 'accepted');
    if (expressOn) totalPaid += (req.expressFee);
    final daily = days > 0 ? (totalPaid / days) : totalPaid;
    final fee = (totalPaid * 0.10);
    final subtotal = (totalPaid - fee).clamp(0.0, totalPaid);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Express confirmation card (only when request pending confirmation and express was requested)
        if (req.status == 'pending' && req.expressRequested && (req.expressStatus == null || req.expressStatus == 'pending')) ...[
          Container(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: const [
                Icon(Icons.flash_on_outlined, color: Colors.white70),
                SizedBox(width: 8),
                Text('Expresslieferung angefragt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 8),
              const Text('Expresslieferung in den nächsten 2 Stunden möglich?', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 4),
              const Text('(5,00 € Zusatzvergütung – wird automatisch gutgeschrieben)', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: ElevatedButton.icon(onPressed: () async {
                  await DataService.updateRentalRequestExpress(requestId: req.id, accept: true);
                  await DataService.addTimelineEvent(requestId: req.id, type: 'express_accepted', note: 'Expresslieferung bestätigt');
                  await DataService.addNotification(title: 'Express bestätigt', body: 'Die Expresslieferung wurde bestätigt (+5,00 €).');
                  await _load();
                }, icon: const Icon(Icons.check_circle_outline), label: const Text('Ja, bestätigen'))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(onPressed: () async {
                  await DataService.updateRentalRequestExpress(requestId: req.id, accept: false);
                  await DataService.addTimelineEvent(requestId: req.id, type: 'express_declined', note: 'Expresslieferung abgelehnt');
                  await DataService.addNotification(title: 'Express abgelehnt', body: 'Die 5,00 € Express-Zahlung wird dem Mieter automatisch erstattet.');
                  await _load();
                }, icon: const Icon(Icons.cancel_outlined), label: const Text('Ablehnen'))),
              ])
            ]),
          ),
          const SizedBox(height: 12),
        ] else if (req.expressRequested && req.expressStatus == 'accepted') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.24))),
            child: Row(children: const [
              Icon(Icons.check_circle_outline, color: Color(0xFF22C55E)),
              SizedBox(width: 8),
              Expanded(child: Text('Expresslieferung bestätigt (+5,00 €)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: 12),
        ] else if (req.expressRequested && req.expressStatus == 'declined') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF43F5E).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.24))),
            child: Row(children: const [
              Icon(Icons.info_outline, color: Color(0xFFF43F5E)),
              SizedBox(width: 8),
              Expanded(child: Text('Expresslieferung abgelehnt – 5,00 € werden erstattet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            ]),
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
              child: Stack(children: [
                // Ensure the image fills and is centered (avoid half-shifted appearance)
                Positioned.fill(child: AppImage(url: _photos.first, fit: BoxFit.cover)),
                // Status chip overlay (bottom-left) across all categories
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: () {
                        if (category == 'completed') {
                          // Completed bucket may be cancelled or finished
                          final cancelled = req.status == 'cancelled' || req.status == 'declined';
                          return (cancelled ? const Color(0xFFF43F5E) : const Color(0xFF22C55E)).withValues(alpha: 0.12);
                        }
                        if (isCompleted) return const Color(0xFF22C55E).withValues(alpha: 0.12);
                        switch (category) {
                          case 'requests':
                            return Colors.grey.withValues(alpha: 0.12);
                          case 'upcoming':
                            return const Color(0xFF0EA5E9).withValues(alpha: 0.12);
                          case 'ongoing':
                          default:
                            return const Color(0xFF0EA5E9).withValues(alpha: 0.12);
                        }
                      }(),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    ),
                    child: Text(
                      () {
                        if (category == 'completed') {
                          final cancelled = req.status == 'cancelled' || req.status == 'declined';
                          return cancelled ? 'Storniert' : 'Abgeschlossen';
                        }
                        if (isCompleted) return 'Abgeschlossen';
                        if (category == 'requests') return 'Anfrage';
                        if (category == 'upcoming') return 'Kommend';
                        return 'Laufend';
                      }(),
                      style: TextStyle(
                        color: () {
                          if (category == 'completed') {
                            final cancelled = req.status == 'cancelled' || req.status == 'declined';
                            return cancelled ? const Color(0xFFF43F5E) : const Color(0xFF22C55E);
                          }
                          if (isCompleted) return const Color(0xFF22C55E);
                          return category == 'requests' ? Colors.grey : const Color(0xFF0EA5E9);
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                        boxShadow: [
                          BoxShadow(
                            color: (isOverdue ? const Color(0xFFF43F5E) : Theme.of(context).colorScheme.primary).withValues(alpha: 0.30),
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
                if (category == 'upcoming')
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Builder(builder: (context) {
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
              ]),
            ),
          ),

        const SizedBox(height: 12),

        // Centered title above the info card
        const SizedBox(height: 10),
        Text(
          item.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),

        // (verlegt) "Was passiert als Nächstes?" wird unten auf der Seite angezeigt

        if (category == 'requests') ...[
          const SizedBox(height: 10),
          // Actions directly under the image per request
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
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
                          await DataService.updateRentalRequestStatus(requestId: req.id, status: 'declined');
                          await DataService.addTimelineEvent(requestId: req.id, type: 'declined', note: 'Anfrage abgelehnt');
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
                            message: 'Du findest sie jetzt unter Abgeschlossene Anmietungen.',
                            barrierDismissible: true,
                            showCloseIcon: false,
                            plainCloseIcon: true,
                            autoCloseAfter: const Duration(seconds: 20),
                            actions: [
                              FilledButton(
                                onPressed: () {
                                  Navigator.of(context, rootNavigator: true).maybePop();
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (_) => OwnerRequestsScreen(initialTabIndex: 3)),
                                  );
                                },
                                child: const Text('Zu Abgeschlossene Anmietungen'),
                              ),
                            ],
                          );
                        },
                        child: const Text('Ablehnen'),
                      ),
                    ],
                  );
                },
                icon: const Icon(Icons.cancel_outlined, color: Color(0xFFF43F5E)),
                label: const Text('Ablehnen'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF43F5E)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await DataService.updateRentalRequestStatus(requestId: req.id, status: 'accepted');
                  await DataService.addTimelineEvent(requestId: req.id, type: 'accepted', note: 'Anfrage akzeptiert');
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
                    icon: Icons.check_circle_outline,
                    title: 'Du hast die Anfrage akzeptiert.',
                    message: 'Du findest diese Anmietung jetzt unter Kommende Anmietungen.',
                    barrierDismissible: true,
                    showCloseIcon: false,
                    plainCloseIcon: true,
                    autoCloseAfter: const Duration(seconds: 20),
                    actions: [
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).maybePop();
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => OwnerRequestsScreen(initialTabIndex: 1)),
                          );
                        },
                        child: const Text('Zu Kommende Anmietungen'),
                      ),
                    ],
                  );
                },
                icon: const Icon(Icons.check_circle_outline, color: Color(0xFF22C55E)),
                label: const Text('Akzeptieren', style: TextStyle(color: Color(0xFF22C55E))),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              ),
            ),
          ]),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Transport info sentence inline (no extra card)
            Builder(builder: (context) {
              String? t;
              if (category == 'upcoming' || category == 'requests') {
                t = ownerDelivers ? 'Du lieferst den Artikel zum Mieter.' : 'Der Mieter holt den Artikel selbst ab.';
              } else if (category == 'ongoing') {
                t = ownerPicksUp ? 'Du holst den Artikel wieder ab.' : 'Der Mieter bringt den Artikel selbst zurück.';
              }
              if (t == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: Text(
                    t,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }),
            _InfoRow(icon: Icons.schedule, label: 'Zeitraum', value: _formatRange(req.start, req.end)),
            const SizedBox(height: 4),
            _InfoRow(icon: Icons.timelapse, label: 'Dauer', value: _formatDaysHours(req.end.difference(req.start))),
            const SizedBox(height: 4),
            if (category != 'requests')
              _InfoRow(icon: Icons.tag, label: 'Buchungs-ID', value: _computeBookingId(item, req)),
            if (category != 'requests') ...[
              const SizedBox(height: 6),
              Divider(height: 12, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 2),
            ],
            const SizedBox(height: 6),
            _CounterpartyRow(
              name: renter.displayName,
              avatarUrl: renter.photoURL,
              role: 'Mieter',
              onProfile: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: renter.id)));
              },
              onMessage: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MessageThreadScreen(participantName: renter.displayName, avatarUrl: renter.photoURL),
                ));
              },
            ),
          ]),
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
          Builder(builder: (context) {
            // For confirmed bookings (upcoming), always show the exact address
            return _AddressInfoCardInline(icon: Icons.place_outlined, text: 'Abholort: $targetAddr');
          }),
        ],
        if (category == 'requests' && ownerDelivers) ...[
          const SizedBox(height: 8),
          ApproxLocationMap(
            lat: item.lat,
            lng: item.lng,
            label: AddressPrivacy.nearbyShort(kindLabel: 'Abholung'),
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final now = DateTime.now();
            // For pending/requests, also respect the 6h before start if available.
            final reveal = now.isAfter(req.start.subtract(const Duration(hours: 6)));
            final text = reveal
                ? 'Abholort: $targetAddr'
                : AddressPrivacy.privacyNoticePickup();
            final icon = reveal ? Icons.place_outlined : Icons.lock_outline;
            return _AddressInfoCardInline(icon: icon, text: text);
          }),
        ],
        if (category == 'ongoing' && ownerPicksUp) ...[
          const SizedBox(height: 8),
          ApproxLocationMap(
            lat: item.lat,
            lng: item.lng,
            label: AddressPrivacy.nearbyShort(kindLabel: 'Rückgabe'),
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            // For ongoing bookings, always show the exact address
            return _AddressInfoCardInline(icon: Icons.place_outlined, text: 'Rückgabeort: $targetAddr');
          }),
        ],

        const SizedBox(height: 16),
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
            _AmountRow(label: 'Tagespreis × Tage', value: '${_formatEuro(daily)} × $days'),
            _AmountRow(label: 'Zwischensumme', value: _formatEuro(subtotal)),
            _AmountRow(label: 'Gebühren', value: _formatEuro(fee)),
            if (expressOn) _AmountRow(label: 'Expresslieferung', value: _formatEuro(req.expressFee)),
            const Divider(height: 16, color: Colors.white24),
            _AmountRow(label: 'Gesamt bezahlt (Mieter)', value: _formatEuro(totalPaid), strong: true),
            const SizedBox(height: 8),
            if (req.expressRequested && req.expressStatus == 'declined') ...[
              _AmountRow(label: 'Rückerstattung (Express)', value: _formatEuro(req.expressFee)),
              const SizedBox(height: 4),
              Text('Expresszuschlag wird vollständig erstattet.', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
              const SizedBox(height: 8),
            ],
            if (isCompleted) ...[
              _AmountRow(label: 'Ausgezahlt (an Vermieter)', value: _formatEuro(totalPaid - fee), strong: true),
              Text('Ausgezahlt am ${_formatPayoutDate(req.end)}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
            ] else ...[
              _AmountRow(label: 'Vorauss. Auszahlung', value: _formatEuro(totalPaid - fee), strong: true),
              Text('Auszahlung am ${_formatPayoutDate(req.end)}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: OutlinedButton.icon(
                onPressed: () => _downloadReceiptPdf(item, req, totalPaid, fee, subtotal),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Beleg herunterladen (PDF)'),
              ),
            ),
          ]),
        ),

        // Removed owner status card per request

        // Bottom timeline removed in favor of compact status card

        const SizedBox(height: 12),
        if (category == 'requests' || category == 'upcoming' || category == 'ongoing')
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
                children: [
                  if (category == 'requests') ...const [
                    _Bullet(text: 'Prüfe die Details und entscheide, ob du die Anfrage annimmst oder ablehnst.'),
                    _Bullet(text: 'Wenn du die Anfrage annimmst, erscheint sie unter Kommende Buchungen.'),
                    _Bullet(text: 'Vereinbare mit dem Mieter einen konkreten Zeitpunkt für Übergabe und Rückgabe.'),
                  ] else if (category == 'upcoming') ...const [
                    _Bullet(text: 'Triff dich mit dem Mieter zum vereinbarten Übergabezeitpunkt.'),
                    _Bullet(text: 'Tippe auf „Übergabe starten“, wenn ihr euch trefft.'),
                    _Bullet(text: 'Beide müssen mindestens 4 Übergabe‑Fotos vom Artikel machen.'),
                    _Bullet(text: 'Übergabe bestätigen durch QR‑Code‑Scan oder Eingabe des 6‑stelligen Übergabecodes.'),
                  ] else ...const [
                    _Bullet(text: 'Triff dich mit dem Mieter zum vereinbarten Rückgabezeitpunkt.'),
                    _Bullet(text: 'Tippe auf „Rückgabe starten“, wenn ihr euch trefft.'),
                    _Bullet(text: 'Beide müssen mindestens 4 Rückgabe‑Fotos vom Artikel machen.'),
                    _Bullet(text: 'Rückgabe bestätigen durch QR‑Code‑Scan oder Eingabe des 6‑stelligen Rückgabecodes.'),
                    _Bullet(text: 'Tippe auf „Abschließen“, um die Übergabe abzuschließen.'),
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(category == 'upcoming' ? 'Übergabe' : 'Rückgabe',
                  style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),

              if (category == 'upcoming') ...[
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _startPickupFlowOwner(context, req, item, renter),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Übergabe starten'),
                    ),
                  ),
                ]),
              ] else if (category == 'ongoing') ...[
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _startReturnFlow(context, req, item, renter),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Rückgabe starten'),
                    ),
                  ),
                ]),
              ],
            ]),
          ),

        if (category == 'completed' && req.status == 'completed') ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: FilledButton.icon(
              onPressed: () => _showReviewSheet(context, renter),
              icon: const Icon(Icons.star_rate_outlined),
              label: const Text('Bewerten'),
            ),
          ),
        ],

        // Problem melden should be at the bottom for completed
        // Removed duplicate Problem melden CTA – moved to overflow menu
      ],
    );
  }

  Future<void> _downloadReceiptPdf(Item item, RentalRequest req, double totalPaid, double fee, double subtotal) async {
    final bookingId = _computeBookingId(item, req);
    final bool expressRefund = req.expressRequested && req.expressStatus == 'declined' && req.expressFee > 0;
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
   <tr><td>Mietpreis (Tagespreis × Tage)</td><td class="right">${_formatEuro(subtotal)}</td></tr>
   <tr><td>Servicegebühr</td><td class="right">${_formatEuro(fee)}</td></tr>
   <tr><td colspan="2"><hr></td></tr>
   <tr><td class="total">Gesamt bezahlt (Mieter)</td><td class="right total">${_formatEuro(totalPaid)}</td></tr>
  ${expressRefund ? '<tr><td>Rückerstattung (Express)</td><td class="right">${_formatEuro(req.expressFee)}</td></tr>' : ''}
 </table>
 <p class="muted">${expressRefund ? 'Expresszuschlag wird vollständig erstattet.' : ''}</p>
 <p class="muted">ShareItToo – Quittung ohne Gewähr.</p>
 </html>
''';
    final dataUri = Uri.dataFromString(html, mimeType: 'text/html', encoding: const Utf8Codec());
    try { await launchUrl(dataUri, mode: LaunchMode.platformDefault); } catch (_) {}
  }

  String _formatRange(DateTime a, DateTime b) {
    String dd(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    String tt(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${dd(a)} um ${tt(a)} – ${dd(b)} um ${tt(b)}';
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
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        _toast(context, 'Karte konnte nicht geöffnet werden');
      }
    } catch (_) {
      _toast(context, 'Karte konnte nicht geöffnet werden');
    }
  }

  String _computeBookingId(Item item, RentalRequest req) {
    final seed = ((item.id.hashCode) ^ (req.id.hashCode) ^ (item.title.hashCode)).abs();
    final s = seed.toString().padLeft(8, '0');
    return 'BKG-${s.substring(0, 4)}-${s.substring(4, 8)}';
  }

  String _handoverCode(Item item, RentalRequest req) {
    return HandoverCodeService.codeFromTitleAndStart(title: item.title, start: req.start);
  }

  String _formatEuro(double v) {
    String two = v.toStringAsFixed(2);
    two = two.replaceAll('.', ',');
    return '$two €';
  }

  String _formatPayoutDate(DateTime end) {
    final payout = end.add(const Duration(days: 1));
    const months = ['Jan','Feb','Mär','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'];
    final m = months[(payout.month - 1).clamp(0, 11)];
    final dd = payout.day.toString().padLeft(2, '0');
    return '$dd. $m';
  }

  String _composeTargetAddress(Map<String, dynamic>? sel, {required String fallback}) {
    final line = (sel?['addressLine'] as String?)?.trim() ?? '';
    final city = (sel?['city'] as String?)?.trim() ?? '';
    if (line.isEmpty && city.isEmpty) return fallback;
    if (line.isNotEmpty && city.isNotEmpty) return '$line, $city';
    return line.isNotEmpty ? line : city;
  }

  void _toast(BuildContext context, String msg) {
    AppPopup.toast(context, icon: Icons.info_outline, title: msg);
  }

  Future<void> _confirmManualHandover(BuildContext context, RentalRequest req, Item item) async {
    await AppPopup.show(
      context,
      icon: Icons.help_outline,
      title: 'Übergabe manuell bestätigen?',
      message: 'Haben Sie Ihr Gegenstand ordnungsgemäß übergeben?',
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
          child: const Text('Nein'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).maybePop();
              try {
              await DataService.updateRentalRequestStatus(requestId: req.id, status: 'running');
              await DataService.addTimelineEvent(requestId: req.id, type: 'handover_manual_confirmed', note: 'Übergabe manuell bestätigt');
                final bookingId = _computeBookingId(item, req);
                final message = 'Übergabe des Listings "${item.title}" wurde vom Vermieter bestätigt.';
                await DataService.addNotification(title: 'Übergabe bestätigt', body: message);
                await DataService.setHandoverBanner(bookingId: bookingId, message: message);
              if (!mounted) return;
              AppPopup.toast(context, icon: Icons.check_circle_outline, title: 'Als übergeben markiert');
              await _load();
            } catch (e) {
              debugPrint('[handover] manual confirm failed: $e');
              if (!mounted) return;
              AppPopup.toast(context, icon: Icons.error_outline, title: 'Konnte nicht bestätigen');
            }
          },
          child: const Text('Ja'),
        ),
      ],
    );
  }

  Future<void> _startQrScan(BuildContext context, {required String expectedCode, required String bookingId, required String requestId}) async {
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
                child: Text('Scanne den QR-Code des Mieters', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
      // Expected payload format: shareittoo:handover:<code>:<bookingId>
      final raw = scanned!.trim();
      final okPrefix = raw.startsWith('shareittoo:handover:');
      final parts = raw.split(':');
      final code = parts.length >= 3 ? parts[2] : '';
      final bkg = parts.length >= 4 ? parts[3] : '';
      final matches = okPrefix && code == expectedCode && bkg == bookingId;
      if (!matches) {
        AppPopup.toast(context, icon: Icons.error_outline, title: 'Ungültiger QR-Code');
        return;
      }

      await DataService.updateRentalRequestStatus(requestId: requestId, status: 'running');
      await DataService.addTimelineEvent(requestId: requestId, type: 'handover_qr_confirmed', note: 'Übergabe per QR bestätigt');
      final message = 'Übergabe des Listings "${_item?.title ?? ''}" wurde vom Vermieter bestätigt.';
      await DataService.addNotification(title: 'Übergabe bestätigt', body: message);
      await DataService.setHandoverBanner(bookingId: bookingId, message: message);
      if (!mounted) return;
      AppPopup.toast(context, icon: Icons.check_circle_outline, title: 'Übergabe per QR bestätigt');
      await _load();
    } catch (e) {
      debugPrint('[handover] qr scan verification failed: $e');
      if (!mounted) return;
      AppPopup.toast(context, icon: Icons.error_outline, title: 'Bestätigung fehlgeschlagen');
    }
  }

  Future<void> _startReturnFlow(BuildContext context, RentalRequest req, Item item, User renter) async {
    final code = _handoverCode(item, req);
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
    if (ok == true) {
      // Set completed, add timeline + notification, send receipt
      await DataService.updateRentalRequestStatus(requestId: req.id, status: 'completed');
      await DataService.addTimelineEvent(requestId: req.id, type: 'completed', note: 'Rückgabe abgeschlossen');
      await DataService.addNotification(title: 'Buchung abgeschlossen', body: 'Die Rückgabe für "${item.title}" wurde abgeschlossen. Beleg gesendet.');
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
  }

  Future<void> _startPickupFlowOwner(BuildContext context, RentalRequest req, Item item, User renter) async {
    final code = _handoverCode(item, req);
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
          child: Stack(children: [
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
                      BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.45), blurRadius: 28, spreadRadius: 1),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: QrImageView(data: data, version: QrVersions.auto, size: 300, backgroundColor: Colors.white),
                ),
              ),
            ),
          ]),
        );
      },
      transitionBuilder: (context, anim, anim2, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(opacity: curved, child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved), child: child));
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
      await AppPopup.toast(context, icon: Icons.star_rate_outlined, title: 'Danke für deine Bewertung!');
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
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerStatusCard extends StatelessWidget {
  final String status; final DateTime end; final bool isOverdue; final double totalPaid; final double fee; final bool expressAccepted;
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
    const months = ['Jan','Feb','Mär','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'];
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            status == 'cancelled' ? Icons.cancel_outlined : Icons.verified_outlined,
            color: status == 'cancelled' ? colorWarn : colorOk,
          ),
          const SizedBox(width: 8),
          Text(
            status == 'cancelled' ? 'Storniert' : 'Bezahlt',
            style: TextStyle(color: status == 'cancelled' ? colorWarn : colorOk, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          if (status != 'cancelled')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: colorInfo.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: colorInfo.withValues(alpha: 0.24))),
              child: Row(children: [
                Icon(isOverdue ? Icons.report_outlined : Icons.timer_outlined, size: 16, color: isOverdue ? colorWarn : Colors.white70),
                const SizedBox(width: 6),
                Text(_countdownText(end), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ]),
            ),
        ]),

        if (status != 'cancelled') ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.payments_outlined, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Vorauss. Auszahlung: ${_formatEuro(payout)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            Text(_formatPayoutDate(end), style: const TextStyle(color: Colors.white70)),
          ]),
          if (expressAccepted) ...[
            const SizedBox(height: 8),
            const Text('Abholung vereinbart (Express)', style: TextStyle(color: Colors.white)),
          ],
        ],
      ]),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.3);
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

class _MapLink extends StatelessWidget {
  final VoidCallback onTap; const _MapLink({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, child: Text('Karte', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)));
  }
}

class _CounterpartyRow extends StatelessWidget {
  final String name; final String? avatarUrl; final String role; final VoidCallback? onProfile; final VoidCallback? onMessage;
  const _CounterpartyRow({required this.name, this.avatarUrl, required this.role, this.onProfile, this.onMessage});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onProfile,
        child: CircleAvatar(
          radius: 18,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null ? const Icon(Icons.person) : null,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(role, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
      ])),
      IconButton(
        tooltip: 'Nachricht',
        onPressed: onMessage,
        icon: const Icon(Icons.forum_outlined, color: Colors.white70),
      ),
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

class _Timeline extends StatelessWidget {
  final String current; // Laufend | Überfällig
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
        if (isOverdue) const _StepChip(label: 'Überfällig', state: _StepState.overdue),
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
    Color border; Color fg; Color bg; IconData? icon;
    switch (state) {
      case _StepState.done:
        border = Colors.white24; fg = Colors.white; bg = Colors.white.withValues(alpha: 0.08); icon = Icons.check_circle_outline; break;
      case _StepState.current:
        border = Theme.of(context).colorScheme.primary.withValues(alpha: 0.40); fg = Theme.of(context).colorScheme.primary; bg = Theme.of(context).colorScheme.primary.withValues(alpha: 0.12); icon = Icons.radio_button_checked; break;
      case _StepState.overdue:
        border = const Color(0xFFF43F5E).withValues(alpha: 0.40); fg = const Color(0xFFF43F5E); bg = const Color(0xFFF43F5E).withValues(alpha: 0.12); icon = Icons.error_outline; break;
      case _StepState.todo:
      default:
        border = Colors.white12; fg = Colors.white70; bg = Colors.white.withValues(alpha: 0.05); icon = Icons.radio_button_unchecked;
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
