import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:provider/provider.dart';
import 'package:lendify/widgets/app_image.dart';
import 'package:lendify/widgets/app_popup.dart';

class RequestDetailScreen extends StatefulWidget {
  final String requestId;
  final String? titleOverride;
  const RequestDetailScreen({super.key, required this.requestId, this.titleOverride});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  RentalRequest? _req; Item? _item; User? _renter; User? _owner;
  Timer? _ticker;
  Duration _remainingConfirm = const Duration(minutes: 30);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final req = await DataService.getRentalRequestById(widget.requestId);
    if (req == null) return;
    final item = await DataService.getItemById(req.itemId);
    final renter = await DataService.getUserById(req.renterId);
    final owner = await DataService.getUserById(req.ownerId);
    setState(() { _req = req; _item = item; _renter = renter; _owner = owner; });
    _startOrStopTicker();
  }

  void _startOrStopTicker() {
    _ticker?.cancel();
    final req = _req;
    if (req != null && req.expressRequested && (req.expressStatus == null || req.expressStatus == 'pending')) {
      _computeRemaining();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        _computeRemaining();
      });
    }
  }

  void _computeRemaining() {
    final req = _req; if (req == null) return;
    final started = req.expressRequestedAt ?? req.createdAt;
    final deadline = started.add(const Duration(minutes: 30));
    final left = deadline.difference(DateTime.now());
    setState(() { _remainingConfirm = left.isNegative ? Duration.zero : left; });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final req = _req; final item = _item; final renter = _renter;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titleOverride ?? l10n.t('Anfrage'))),
      body: (req == null || item == null || renter == null)
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (req.expressRequested && (req.expressStatus == null || req.expressStatus == 'pending'))
                _ExpressOwnerBanner(
                  remaining: _remainingConfirm,
                  onAccept: () async {
                    await DataService.updateRentalRequestExpress(requestId: req.id, accept: true);
                    if (!mounted) return; await _load();
                  },
                  onDecline: () async {
                    await DataService.updateRentalRequestExpress(requestId: req.id, accept: false);
                    if (!mounted) return; await _load();
                  },
                )
              else if (req.expressRequested && req.expressStatus == 'accepted')
                _ExpressAcceptedInfo(confirmedAt: req.expressConfirmedAt),
              _ItemSummaryCard(
                item: item,
                request: req,
                onAccept: () async {
                  await DataService.updateRentalRequestStatus(requestId: req.id, status: 'accepted');
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
                        onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
                        child: const Text('Abbrechen'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          Navigator.of(context, rootNavigator: true).maybePop();
                          await DataService.updateRentalRequestStatus(requestId: req.id, status: 'declined');
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
              _PriceCard(item: item, request: req),
              const SizedBox(height: 20),
            ]),
    );
  }
}

class _ItemSummaryCard extends StatelessWidget {
  final Item item; final RentalRequest request;
  final VoidCallback? onAccept; final VoidCallback? onDecline;
  const _ItemSummaryCard({required this.item, required this.request, this.onAccept, this.onDecline});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Image banner
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: AppImage(url: item.photos.isNotEmpty ? item.photos.first : '', fit: BoxFit.cover),
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
              label: const Text('Akzeptieren', style: TextStyle(color: Colors.green)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.green),
                foregroundColor: Colors.green,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        // Title under the buttons
        Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('${request.start.day.toString().padLeft(2, '0')}.${request.start.month.toString().padLeft(2, '0')}.${request.start.year} – ${request.end.day.toString().padLeft(2, '0')}.${request.end.month.toString().padLeft(2, '0')}.${request.end.year}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
      ]),
    );
  }
}

class _RenterCard extends StatelessWidget {
  final User user; const _RenterCard({required this.user});
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      child: ListTile(
        leading: CircleAvatar(backgroundImage: NetworkImage(user.photoURL ?? 'https://images.unsplash.com/photo-1502685104226-ee32379fefbe?w=150&h=150&fit=crop&crop=face')),
        title: Text(user.displayName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
        subtitle: Text('${user.city ?? ''}${(user.city?.isNotEmpty ?? false) && (user.country?.isNotEmpty ?? false) ? ', ' : ''}${user.country ?? ''}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
        trailing: TextButton(onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PublicProfileQuickView(user: user, title: 'Profil des Mieters')));
        }, child: Text(l10n.t('Zum Profil'))),
      ),
    );
  }
}

class _DatesCard extends StatelessWidget {
  final RentalRequest request; const _DatesCard({required this.request});
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.t('Zeitraum'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
        const SizedBox(height: 6),
        Text('${request.start.day.toString().padLeft(2, '0')}.${request.start.month.toString().padLeft(2, '0')}.${request.start.year} – ${request.end.day.toString().padLeft(2, '0')}.${request.end.month.toString().padLeft(2, '0')}.${request.end.year}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
      ]),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final Item item; final RentalRequest request; const _PriceCard({required this.item, required this.request});
  int _daysCeil(DateTime a, DateTime b) => ((b.difference(a).inHours) / 24).ceil().clamp(1, 3650);
  @override
  Widget build(BuildContext context) {
    final days = _daysCeil(request.start, request.end);
    final total = DataService.computeTotalWithDiscounts(item: item, days: days).$1;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      child: Row(children: [
        const Icon(Icons.payments_outlined, color: Colors.white70),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Preis (vom Mieter zu zahlen)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          Text('${total.toStringAsFixed(0)} €', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        ]))
      ]),
    );
  }
}

class _ExpressOwnerBanner extends StatelessWidget {
  final Duration remaining;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _ExpressOwnerBanner({required this.remaining, required this.onAccept, required this.onDecline});
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
          Text('Prioritätslieferung angefragt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Text(
          canAccept ? 'Du hast noch ${_fmt(left)} Minuten zur Bestätigung.' : 'Die 30 Minuten sind abgelaufen. Priorität gilt als nicht bestätigt.',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: FilledButton(onPressed: canAccept ? onAccept : null, child: const Text('Priorität bestätigen (+5,00 €)'))),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton(onPressed: onDecline, child: const Text('Priorität ablehnen'))),
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
    const months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
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
          Text('Priorität bestätigt (+5,00 €)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Text('Lieferung bis: ${_formatGermanDateTime(deliveryBy)}  •  Noch $countdown', style: const TextStyle(color: Colors.white70)),
      ]),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message; const _MessageCard({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
    );
  }
}

class _PublicProfileQuickView extends StatelessWidget {
  final User user; final String title;
  const _PublicProfileQuickView({required this.user, required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          CircleAvatar(radius: 36, backgroundImage: NetworkImage(user.photoURL ?? 'https://images.unsplash.com/photo-1502685104226-ee32379fefbe?w=150&h=150&fit=crop&crop=face')),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.displayName, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
            const SizedBox(height: 4),
            Text('${user.city ?? ''}${(user.city?.isNotEmpty ?? false) && (user.country?.isNotEmpty ?? false) ? ', ' : ''}${user.country ?? ''}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70))
          ]))
        ]),
      ]),
    );
  }
}
