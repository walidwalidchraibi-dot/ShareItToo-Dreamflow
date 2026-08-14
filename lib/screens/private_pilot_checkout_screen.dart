import 'package:flutter/material.dart';
import 'package:lendify/config/private_pilot_config.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/private_pilot_pricing.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/private_pilot_risk_notice.dart';

class PrivatePilotCheckoutScreen extends StatefulWidget {
  final Item item;
  final DateTimeRange range;

  const PrivatePilotCheckoutScreen({
    super.key,
    required this.item,
    required this.range,
  });

  @override
  State<PrivatePilotCheckoutScreen> createState() =>
      _PrivatePilotCheckoutScreenState();
}

class _PrivatePilotCheckoutScreenState
    extends State<PrivatePilotCheckoutScreen> {
  bool _privateStatusConfirmed = false;
  bool _bindingRequestConfirmed = false;
  bool _platformTermsConfirmed = false;
  bool _earlyPerformanceConfirmed = false;
  bool _withdrawalKnowledgeConfirmed = false;
  bool _submitting = false;

  int get _days => widget.range.end
      .difference(widget.range.start)
      .inDays
      .clamp(1, 365)
      .toInt();

  DateTime? get _shortNoticeGraceDeadline {
    final now = DateTime.now();
    final untilStart = widget.range.start.difference(now);
    if (untilStart >=
        const Duration(hours: PrivatePilotConfig.shortNoticeThresholdHours)) {
      return null;
    }
    final candidate = now.add(
      const Duration(minutes: PrivatePilotConfig.shortNoticeGraceMinutes),
    );
    return candidate.isBefore(widget.range.start)
        ? candidate
        : widget.range.start;
  }

  DateTime get _bindingDeadline {
    final candidate = DateTime.now().add(
      const Duration(hours: PrivatePilotConfig.bookingRequestBindingHours),
    );
    return candidate.isBefore(widget.range.start)
        ? candidate
        : widget.range.start;
  }

  List<Map<String, dynamic>> _legalDeclarations(DateTime acceptedAt) {
    Map<String, dynamic> declaration(String type, String exactWording) => {
          'type': type,
          'exactWording': exactWording,
          'documentName': PrivatePilotConfig.documentName,
          'documentVersion': PrivatePilotConfig.documentVersion,
          'language': PrivatePilotConfig.language,
          'accepted': true,
          'acceptedAt': acceptedAt.toIso8601String(),
        };
    return [
      declaration(
        'booking_private',
        PrivatePilotConfig.bookingPrivateDeclaration,
      ),
      declaration(
        'binding_booking_request',
        PrivatePilotConfig.bindingRequestDeclaration,
      ),
      declaration(
        'platform_terms',
        PrivatePilotConfig.platformTermsDeclaration,
      ),
      declaration(
        'early_performance',
        PrivatePilotConfig.earlyPerformanceDeclaration,
      ),
      declaration(
        'withdrawal_knowledge',
        PrivatePilotConfig.withdrawalKnowledgeDeclaration,
      ),
    ];
  }

  String _date(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year}';
  }

  String _dateTime(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${_date(value)}, ${two(value.hour)}:${two(value.minute)} Uhr';
  }

  bool get _allConfirmed =>
      _privateStatusConfirmed &&
      _bindingRequestConfirmed &&
      _platformTermsConfirmed &&
      _earlyPerformanceConfirmed &&
      _withdrawalKnowledgeConfirmed;

  Future<void> _submitRequest(PrivatePilotQuote quote) async {
    if (!_allConfirmed || _submitting) return;
    final current = await DataService.getCurrentUser();
    if (!mounted) return;
    if (current == null) {
      await AppPopup.error(
        context,
        title: 'Anmeldung erforderlich',
        message:
            'Bitte melde dich erneut an und öffne den Checkout danach noch einmal.',
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final declarationTime = DateTime.now();
      final request = RentalRequest(
        id: 'local',
        itemId: widget.item.id,
        ownerId: widget.item.ownerId,
        renterId: current.id,
        start: widget.range.start,
        end: widget.range.end,
        status: 'pending',
        expressRequested: false,
        quotedTotalRenter: PrivatePilotPricing.minorToEuros(quote.totalMinor),
        quotedSubtitle: 'inkl. ShareItToo-Plattformbeitrag 10 %',
        privateStatusConfirmed: true,
        quotedRentalSubtotalMinor: quote.rentalSubtotalMinor,
        quotedPlatformFeeMinor: quote.platformFeeMinor,
        quotedTotalMinor: quote.totalMinor,
        legalDeclarations: _legalDeclarations(declarationTime),
      );
      final stored = await DataService.addRentalRequest(request);
      if (!mounted) return;
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      rootNavigator.popUntil((route) => route.isFirst);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!rootNavigator.context.mounted) return;
      await AppPopup.success(
        rootNavigator.context,
        title: 'Buchungsanfrage gesendet',
        message:
            'Anfrage ${stored.id}: Der Vermieter kann sie jetzt prüfen. Es wurde noch kein echtes Zahlungsmittel belastet.',
      );
    } catch (error) {
      if (!mounted) return;
      await AppPopup.error(
        context,
        title: 'Buchungsanfrage nicht gesendet',
        message: 'Bitte prüfe deine Verbindung und versuche es erneut.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = PrivatePilotPricing.quoteForItem(
      item: widget.item,
      days: _days,
    );
    final graceDeadline = _shortNoticeGraceDeadline;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Buchungsübersicht')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.item.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_date(widget.range.start)} - ${_date(widget.range.end)} · ${quote.days} ${quote.days == 1 ? 'Tag' : 'Tage'}',
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _PriceRow(
                    label:
                        'Mietpreis - ${quote.days} ${quote.days == 1 ? 'Tag' : 'Tage'}',
                    value: PrivatePilotPricing.formatMinor(
                      quote.baseRentalMinor,
                      currency: quote.currency,
                    ),
                  ),
                  if (quote.discountMinor > 0)
                    _PriceRow(
                      label:
                          'Rabatt ${(quote.discountBasisPoints / 100).toStringAsFixed(0)} %',
                      value:
                          '-${PrivatePilotPricing.formatMinor(quote.discountMinor, currency: quote.currency)}',
                    ),
                  _PriceRow(
                    label: 'Mietpreis nach Rabatt',
                    value: PrivatePilotPricing.formatMinor(
                      quote.rentalSubtotalMinor,
                      currency: quote.currency,
                    ),
                  ),
                  _PriceRow(
                    label: 'ShareItToo-Plattformbeitrag 10 %',
                    value: PrivatePilotPricing.formatMinor(
                      quote.platformFeeMinor,
                      currency: quote.currency,
                    ),
                  ),
                  const Divider(height: 26),
                  _PriceRow(
                    label: 'Gesamtpreis',
                    value: PrivatePilotPricing.formatMinor(
                      quote.totalMinor,
                      currency: quote.currency,
                    ),
                    emphasized: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Storno und Karenz',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    graceDeadline == null
                        ? 'Mindestens 24 Stunden vor Mietbeginn ist die Stornierung nach dem aktuellen Pilot-Prüfmodell kostenlos.'
                        : 'Bei einer Bestätigung jetzt: kostenlose Stornierung bis ${_dateTime(graceDeadline)}. Die Sätze danach sind noch rechtlich zu prüfende Pilotparameter.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'An diese Anfrage bist du bis ${_dateTime(_bindingDeadline)} gebunden, höchstens bis Mietbeginn. Eine Eingangsbestätigung ist noch keine Annahme.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const PrivatePilotRiskNotice(title: 'Kein SIT-Schutzprodukt'),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _privateStatusConfirmed,
            onChanged: (value) =>
                setState(() => _privateStatusConfirmed = value == true),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(PrivatePilotConfig.bookingPrivateDeclaration),
            subtitle: Text(
              '${PrivatePilotConfig.documentName} · ${PrivatePilotConfig.documentVersion}',
            ),
          ),
          CheckboxListTile(
            value: _bindingRequestConfirmed,
            onChanged: (value) =>
                setState(() => _bindingRequestConfirmed = value == true),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              PrivatePilotConfig.bindingRequestDeclaration,
            ),
          ),
          CheckboxListTile(
            value: _platformTermsConfirmed,
            onChanged: (value) =>
                setState(() => _platformTermsConfirmed = value == true),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              PrivatePilotConfig.platformTermsDeclaration,
            ),
          ),
          CheckboxListTile(
            value: _earlyPerformanceConfirmed,
            onChanged: (value) =>
                setState(() => _earlyPerformanceConfirmed = value == true),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              PrivatePilotConfig.earlyPerformanceDeclaration,
            ),
          ),
          CheckboxListTile(
            value: _withdrawalKnowledgeConfirmed,
            onChanged: (value) => setState(
              () => _withdrawalKnowledgeConfirmed = value == true,
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              PrivatePilotConfig.withdrawalKnowledgeDeclaration,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: PrivatePilotConfig.bindingCheckoutEnabled &&
                    _allConfirmed &&
                    !_submitting
                ? () => _submitRequest(quote)
                : null,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(
              _submitting
                  ? 'Wird gesendet…'
                  : 'Zahlungspflichtige Buchungsanfrage senden',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Das bloße Öffnen dieser Übersicht sendet keine Anfrage. Erst die Schaltfläche oben sendet die Buchungsanfrage. Im aktuellen Testbetrieb wird kein echtes Zahlungsmittel autorisiert oder belastet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: emphasized ? FontWeight.w900 : FontWeight.w500,
                  fontSize: emphasized ? 17 : null,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              value,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
                fontSize: emphasized ? 19 : null,
              ),
            ),
          ],
        ),
      );
}
