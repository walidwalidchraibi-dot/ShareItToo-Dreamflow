import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/backend_config.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/services/private_pilot_pricing.dart';
import 'package:lendify/services/qa_runtime_service.dart';
import 'package:provider/provider.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/user_avatar.dart';
import 'package:lendify/widgets/private_pilot_owner_acceptance_dialog.dart';

class RequestDetailScreen extends StatefulWidget {
  final String requestId;
  final String? titleOverride;
  const RequestDetailScreen(
      {super.key, required this.requestId, this.titleOverride});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  RentalRequest? _req;
  Item? _item;
  User? _renter;
  Timer? _ticker;
  Duration _remainingConfirm = const Duration(minutes: 30);

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
    if (!mounted) return;
    setState(() {
      _req = req;
      _item = item;
      _renter = renter;
    });
    _startOrStopTicker();
  }

  void _startOrStopTicker() {
    _ticker?.cancel();
    final req = _req;
    if (req != null &&
        req.expressRequested &&
        (req.expressStatus == null || req.expressStatus == 'pending')) {
      _computeRemaining();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        _computeRemaining();
      });
    }
  }

  void _computeRemaining() {
    final req = _req;
    if (req == null) return;
    final started = req.expressRequestedAt ?? req.createdAt;
    final deadline = started.add(const Duration(minutes: 30));
    final left = deadline.difference(DateTime.now());
    setState(() {
      _remainingConfirm = left.isNegative ? Duration.zero : left;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final req = _req;
    final item = _item;
    final renter = _renter;
    final serverQuote = req == null ? null : _strictQuoteSnapshot(req);
    final usesRemoteBackend =
        BackendConfig.enabled && !QaRuntimeService.isEnabled;
    final bindingDeadline = req?.bindingExpiresAt;
    final deadlineValid = !usesRemoteBackend ||
        (bindingDeadline != null && bindingDeadline.isAfter(DateTime.now()));
    final displayedQuote = req == null || item == null
        ? null
        : serverQuote ??
            (usesRemoteBackend
                ? null
                : PrivatePilotPricing.quoteForItem(
                    item: item,
                    days: _rentalDays(req),
                  ));
    final acceptanceBlockedReason = usesRemoteBackend && serverQuote == null
        ? 'Der verbindliche Serverpreis fehlt oder ist widersprüchlich. Bitte lade die Anfrage neu; bis dahin ist die Annahme gesperrt.'
        : !deadlineValid
            ? 'Die 30-Minuten-Annahmefrist ist abgelaufen. Diese Anfrage kann nicht mehr angenommen werden.'
            : null;
    final acceptanceInfo = usesRemoteBackend && deadlineValid
        ? 'Annahme möglich bis ${_formatDeadline(bindingDeadline!)}.'
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titleOverride ?? l10n.t('Anfrage'))),
      body: (req == null || item == null || renter == null)
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (req.expressRequested &&
                  (req.expressStatus == null || req.expressStatus == 'pending'))
                _ExpressOwnerBanner(
                  remaining: _remainingConfirm,
                  onAccept: () async {
                    await DataService.updateRentalRequestExpress(
                        requestId: req.id, accept: true);
                    if (!mounted) return;
                    await _load();
                  },
                  onDecline: () async {
                    await DataService.updateRentalRequestExpress(
                        requestId: req.id, accept: false);
                    if (!mounted) return;
                    await _load();
                  },
                )
              else if (req.expressRequested && req.expressStatus == 'accepted')
                _ExpressAcceptedInfo(confirmedAt: req.expressConfirmedAt),
              _ItemSummaryCard(
                item: item,
                request: req,
                acceptanceBlockedReason: acceptanceBlockedReason,
                acceptanceInfo: acceptanceInfo,
                onAccept: displayedQuote == null || !deadlineValid
                    ? null
                    : () async {
                        final declarations =
                            await showPrivatePilotOwnerAcceptanceDialog(
                          context,
                          request: req,
                          quote: displayedQuote,
                          isBindingServerQuote: serverQuote != null,
                        );
                        if (declarations == null) return;
                        if (!context.mounted) return;
                        final accepted =
                            await commitPrivatePilotOwnerAcceptance(
                          context,
                          request: req,
                          legalDeclarations: declarations,
                        );
                        if (!accepted) return;
                        if (mounted) Navigator.of(context).pop(true);
                      },
                onDecline: () async {
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
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true)
                                .maybePop(),
                        child: const Text('Abbrechen'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          Navigator.of(context, rootNavigator: true).maybePop();
                          await DataService.updateRentalRequestStatus(
                              requestId: req.id, status: 'declined');
                          if (mounted) Navigator.of(context).pop(true);
                        },
                        child: Text(l10n.t('Ablehnen')),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _RenterCard(user: renter),
              const SizedBox(height: 12),
              _DatesCard(request: req),
              const SizedBox(height: 12),
              _PriceCard(
                quote: displayedQuote,
                isBindingServerQuote: serverQuote != null,
              ),
              const SizedBox(height: 20),
            ]),
    );
  }
}

class _ItemSummaryCard extends StatelessWidget {
  final Item item;
  final RentalRequest request;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final String? acceptanceBlockedReason;
  final String? acceptanceInfo;
  const _ItemSummaryCard(
      {required this.item,
      required this.request,
      this.onAccept,
      this.onDecline,
      this.acceptanceBlockedReason,
      this.acceptanceInfo});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Image banner
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: AppImage(
                url: item.photos.isNotEmpty ? item.photos.first : '',
                fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 10),
        // Buttons under image (icons with explicit colors matching their labels)
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onDecline,
              icon: Builder(builder: (context) {
                final danger = Theme.of(context).colorScheme.error;
                return Icon(Icons.close, color: danger);
              }),
              label: Builder(builder: (context) {
                final danger = Theme.of(context).colorScheme.error;
                return Text('Ablehnen', style: TextStyle(color: danger));
              }),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).colorScheme.error),
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onAccept,
              icon: const Icon(Icons.check_circle, color: Colors.green),
              label: const Text('Akzeptieren',
                  style: TextStyle(color: Colors.green)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.green),
                foregroundColor: Colors.green,
              ),
            ),
          ),
        ]),
        if (acceptanceBlockedReason != null) ...[
          const SizedBox(height: 8),
          Text(
            acceptanceBlockedReason!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ] else if (acceptanceInfo != null) ...[
          const SizedBox(height: 8),
          Text(
            acceptanceInfo!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 8),
        // Title under the buttons
        Text(item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
            '${request.start.day.toString().padLeft(2, '0')}.${request.start.month.toString().padLeft(2, '0')}.${request.start.year} – ${request.end.day.toString().padLeft(2, '0')}.${request.end.month.toString().padLeft(2, '0')}.${request.end.year}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70)),
      ]),
    );
  }
}

class _RenterCard extends StatelessWidget {
  final User user;
  const _RenterCard({required this.user});
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    return Container(
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      child: ListTile(
        leading: SitUserAvatar(
          url: user.photoURL,
          radius: 20,
          borderColor: Colors.white.withValues(alpha: 0.12),
        ),
        title: Text(user.displayName,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white)),
        subtitle: Text(
            '${user.city ?? ''}${(user.city?.isNotEmpty ?? false) && (user.country?.isNotEmpty ?? false) ? ', ' : ''}${user.country ?? ''}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70)),
        trailing: TextButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _PublicProfileQuickView(
                      user: user, title: 'Profil des Mieters')));
            },
            child: Text(l10n.t('Zum Profil'))),
      ),
    );
  }
}

class _DatesCard extends StatelessWidget {
  final RentalRequest request;
  const _DatesCard({required this.request});
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.t('Zeitraum'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70)),
        const SizedBox(height: 6),
        Text(
            '${request.start.day.toString().padLeft(2, '0')}.${request.start.month.toString().padLeft(2, '0')}.${request.start.year} – ${request.end.day.toString().padLeft(2, '0')}.${request.end.month.toString().padLeft(2, '0')}.${request.end.year}',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white)),
      ]),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final PrivatePilotQuote? quote;
  final bool isBindingServerQuote;
  const _PriceCard({
    required this.quote,
    required this.isBindingServerQuote,
  });

  @override
  Widget build(BuildContext context) {
    final price = quote;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      child: Row(children: [
        const Icon(Icons.payments_outlined, color: Colors.white70),
        const SizedBox(width: 8),
        Expanded(
          child: price == null
              ? Text(
                  'Kein verbindlicher Preis verfügbar. Die Annahme bleibt gesperrt.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBindingServerQuote
                          ? 'Verbindlicher Serverpreis'
                          : 'Lokaler Testpreis · kein Echtgeld',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    _OwnerPriceLine(
                      label: 'Privater Mietpreis',
                      value: PrivatePilotPricing.formatMinor(
                        price.rentalSubtotalMinor,
                        currency: price.currency,
                      ),
                    ),
                    _OwnerPriceLine(
                      label: 'SIT-Plattformbeitrag des Mieters',
                      value: PrivatePilotPricing.formatMinor(
                        price.platformFeeMinor,
                        currency: price.currency,
                      ),
                    ),
                    _OwnerPriceLine(
                      label: 'Gesamtpreis des Mieters',
                      value: PrivatePilotPricing.formatMinor(
                        price.totalMinor,
                        currency: price.currency,
                      ),
                      strong: true,
                    ),
                    _OwnerPriceLine(
                      label: 'Deine vorgesehene Auszahlung',
                      value: PrivatePilotPricing.formatMinor(
                        price.rentalSubtotalMinor,
                        currency: price.currency,
                      ),
                      strong: true,
                    ),
                  ],
                ),
        ),
      ]),
    );
  }
}

class _OwnerPriceLine extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _OwnerPriceLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? Colors.white : Colors.white70,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

PrivatePilotQuote? _strictQuoteSnapshot(RentalRequest request) {
  try {
    return PrivatePilotQuote.fromRentalRequestSnapshot(request);
  } on FormatException {
    return null;
  }
}

int _rentalDays(RentalRequest request) =>
    ((request.end.difference(request.start).inHours) / 24)
        .ceil()
        .clamp(1, 365)
        .toInt();

String _formatDeadline(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  final local = value.toLocal();
  return '${two(local.day)}.${two(local.month)}.${local.year}, '
      '${two(local.hour)}:${two(local.minute)} Uhr';
}

class _ExpressOwnerBanner extends StatelessWidget {
  final Duration remaining;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _ExpressOwnerBanner(
      {required this.remaining,
      required this.onAccept,
      required this.onDecline});
  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final left = remaining.isNegative ? Duration.zero : remaining;
    final canAccept = left > Duration.zero;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.flash_on_outlined, color: Colors.white70),
          SizedBox(width: 8),
          Text('Prioritätslieferung angefragt',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Text(
          canAccept
              ? 'Du hast noch ${_fmt(left)} Minuten zur Bestätigung.'
              : 'Die 30 Minuten sind abgelaufen. Priorität gilt als nicht bestätigt.',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: FilledButton(
                  onPressed: canAccept ? onAccept : null,
                  child: const Text('Priorität bestätigen (+5,00 €)'))),
          const SizedBox(width: 12),
          Expanded(
              child: OutlinedButton(
                  onPressed: onDecline,
                  child: const Text('Priorität ablehnen'))),
        ]),
        const SizedBox(height: 8),
        const Text(
          'Hinweis: Die 5,00 € werden nur berechnet, wenn du innerhalb von 30 Minuten bestätigst und innerhalb von 2,5 Stunden lieferst.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ]),
    );
  }
}

class _ExpressAcceptedInfo extends StatelessWidget {
  final DateTime? confirmedAt;
  const _ExpressAcceptedInfo({required this.confirmedAt});
  String _formatGermanDateTime(DateTime d) {
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
    final mm = months[d.month - 1];
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd. $mm';
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = confirmedAt ?? DateTime.now();
    final deliveryBy = confirmed.add(const Duration(hours: 2, minutes: 30));
    final left = deliveryBy.difference(DateTime.now());
    String countdown;
    if (left.isNegative) {
      countdown = 'Zeitfenster überschritten';
    } else if (left.inDays > 0) {
      countdown = left.inDays == 1 ? '1 Tag' : '${left.inDays} Tage';
    } else {
      countdown = 'Heute';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.check_circle_outline, color: Color(0xFF22C55E)),
          SizedBox(width: 8),
          Text('Priorität bestätigt (+5,00 €)',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Text(
            'Lieferung bis: ${_formatGermanDateTime(deliveryBy)}  •  Noch $countdown',
            style: const TextStyle(color: Colors.white70)),
      ]),
    );
  }
}

class _PublicProfileQuickView extends StatelessWidget {
  final User user;
  final String title;
  const _PublicProfileQuickView({required this.user, required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          SitUserAvatar(
            url: user.photoURL,
            radius: 36,
            borderColor: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(user.displayName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                    '${user.city ?? ''}${(user.city?.isNotEmpty ?? false) && (user.country?.isNotEmpty ?? false) ? ', ' : ''}${user.country ?? ''}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70))
              ]))
        ]),
      ]),
    );
  }
}
