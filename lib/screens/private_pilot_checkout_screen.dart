import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lendify/config/private_pilot_config.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/screens/legal_screen.dart';
import 'package:lendify/services/backend_config.dart';
import 'package:lendify/services/backend_http.dart';
import 'package:lendify/services/backend_repository.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/private_pilot_pricing.dart';
import 'package:lendify/services/qa_runtime_service.dart';
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
  bool _privateAndTermsConfirmed = false;
  bool _earlyPerformanceAndWithdrawalConfirmed = false;
  bool _submitting = false;
  bool _loadingQuote = false;
  bool _paymentMethodAvailable = false;
  String? _quoteError;
  Map<String, dynamic>? _checkoutQuote;
  DateTime? _quoteExpiresAt;
  Timer? _quoteExpiryTimer;
  late PrivatePilotQuote _displayQuote;
  String _ownerName = 'der private Vermieter';

  bool get _usesRemoteBackend =>
      BackendConfig.enabled && !QaRuntimeService.isEnabled;

  @override
  void initState() {
    super.initState();
    _displayQuote = PrivatePilotPricing.quoteForItem(
      item: widget.item,
      days: _days,
    );
    _paymentMethodAvailable = !_usesRemoteBackend;
    unawaited(_loadOwnerName());
    if (_usesRemoteBackend) unawaited(_loadFreshQuote());
  }

  @override
  void dispose() {
    _quoteExpiryTimer?.cancel();
    super.dispose();
  }

  int get _days => widget.range.end
      .difference(widget.range.start)
      .inDays
      .clamp(1, 365)
      .toInt();

  String _dateKey(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<void> _loadOwnerName() async {
    final owner = await DataService.getUserById(widget.item.ownerId);
    if (!mounted || owner == null || owner.displayName.trim().isEmpty) return;
    setState(() => _ownerName = owner.displayName.trim());
  }

  Future<void> _loadFreshQuote() async {
    if (_loadingQuote) return;
    _quoteExpiryTimer?.cancel();
    setState(() {
      _loadingQuote = true;
      _quoteError = null;
      _checkoutQuote = null;
      _quoteExpiresAt = null;
      _paymentMethodAvailable = false;
    });
    try {
      final envelope = await BackendRepository.quoteBooking({
        'itemId': widget.item.id,
        'startDate': _dateKey(widget.range.start),
        'endDate': _dateKey(widget.range.end),
        'ownerDeliversAtDropoffChosen': false,
        'ownerPicksUpAtReturnChosen': false,
        'expressRequested': false,
      });
      final quoteJson = envelope['quote'];
      final expiresAt = DateTime.tryParse(
        envelope['expiresAt']?.toString() ?? '',
      )?.toLocal();
      if (quoteJson is! Map ||
          expiresAt == null ||
          !expiresAt.isAfter(DateTime.now())) {
        throw const FormatException('Der Serverpreis ist nicht mehr gültig.');
      }
      final parsedQuote = PrivatePilotQuote.fromServerJson(
        Map<String, dynamic>.from(quoteJson),
      );
      if (!mounted) return;
      setState(() {
        _checkoutQuote = Map<String, dynamic>.from(envelope);
        _displayQuote = parsedQuote;
        _quoteExpiresAt = expiresAt;
        _paymentMethodAvailable = envelope['paymentMethodAvailable'] == true;
      });
      _quoteExpiryTimer = Timer(
        expiresAt.difference(DateTime.now()),
        () {
          if (!mounted) return;
          setState(() {
            _checkoutQuote = null;
            _quoteExpiresAt = null;
            _quoteError = 'Der Preis ist abgelaufen. Bitte neu laden.';
          });
        },
      );
    } on BackendException catch (error) {
      if (!mounted) return;
      setState(() {
        _quoteError = _quoteLoadMessage(error.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quoteError =
            'Der verbindliche Serverpreis konnte nicht geladen werden.';
      });
    } finally {
      if (mounted) setState(() => _loadingQuote = false);
    }
  }

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
      const Duration(
        minutes: PrivatePilotConfig.bookingRequestBindingMinutes,
      ),
    );
    return candidate.isBefore(widget.range.start)
        ? candidate
        : widget.range.start;
  }

  List<Map<String, dynamic>> _legalDeclarations(DateTime acceptedAt) {
    Map<String, dynamic> declaration(String type, String exactWording) => {
          'type': type,
          'exactWording': exactWording,
          'documentName': PrivatePilotConfig.v51DocumentName,
          'documentVersion': PrivatePilotConfig.v51DocumentVersion,
          'language': PrivatePilotConfig.language,
          'accepted': true,
          'acceptedAt': acceptedAt.toIso8601String(),
        };
    return [
      declaration(
        'private_terms_and_platform_terms',
        PrivatePilotConfig.v51PrivateAndPlatformTermsDeclaration,
      ),
      declaration(
        'early_performance_and_withdrawal',
        PrivatePilotConfig.v51EarlyPerformanceAndWithdrawalDeclaration,
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

  String _discountLabel(PrivatePilotQuote quote) {
    final matching = widget.item.longRentalDiscounts
        .where((tier) =>
            tier.days <= quote.days &&
            (tier.discountPercent * 100).round() == quote.discountBasisPoints)
        .toList()
      ..sort((left, right) => right.days.compareTo(left.days));
    final threshold = matching.isEmpty ? quote.days : matching.first.days;
    final percent = (quote.discountBasisPoints / 100).toStringAsFixed(0);
    return 'Rabatt ab $threshold Tagen ($percent %)';
  }

  bool get _freshQuoteAvailable =>
      !_usesRemoteBackend ||
      (_checkoutQuote != null &&
          _quoteExpiresAt != null &&
          _quoteExpiresAt!.isAfter(DateTime.now()));

  bool get _allConfirmed =>
      _privateAndTermsConfirmed && _earlyPerformanceAndWithdrawalConfirmed;

  bool get _canSubmit =>
      PrivatePilotConfig.bindingCheckoutEnabled &&
      _allConfirmed &&
      _freshQuoteAvailable &&
      _paymentMethodAvailable &&
      !_submitting;

  Future<void> _submitRequest() async {
    if (!_canSubmit) return;
    final quote = _displayQuote;
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
        bindingExpiresAt: _bindingDeadline,
        quotedTotalRenter: PrivatePilotPricing.minorToEuros(quote.totalMinor),
        quotedSubtitle: 'inkl. ShareItToo-Plattformbeitrag 10 %',
        privateStatusConfirmed: true,
        quotedDays: quote.days,
        quotedPricePerDayMinor: quote.ownerPricePerDayMinor,
        quotedBaseRentalMinor: quote.baseRentalMinor,
        quotedDiscountPercent: quote.discountBasisPoints / 100,
        quotedDiscountMinor: quote.discountMinor,
        quotedRentalSubtotalMinor: quote.rentalSubtotalMinor,
        quotedPlatformFeeMinor: quote.platformFeeMinor,
        quotedTotalMinor: quote.totalMinor,
        quotedOwnerPayoutMinor: quote.rentalSubtotalMinor,
        quotedCurrency: quote.currency,
        legalDeclarations: _legalDeclarations(declarationTime),
      );
      final stored = await DataService.addRentalRequest(
        request,
        checkoutQuote: _checkoutQuote,
      );
      if (!mounted) return;
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      final rootContext = rootNavigator.context;
      rootNavigator.popUntil((route) => route.isFirst);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!rootContext.mounted) return;
      await AppPopup.success(
        rootContext,
        title: 'Buchungsanfrage gesendet',
        message:
            'Anfrage ${stored.id}: Der Vermieter kann sie jetzt prüfen. Es wurde noch kein echtes Zahlungsmittel belastet.',
      );
    } on BackendException catch (error) {
      if (!mounted) return;
      final failure = _submissionFailure(error.code);
      if (failure.refreshQuote) {
        _quoteExpiryTimer?.cancel();
        setState(() {
          _checkoutQuote = null;
          _quoteExpiresAt = null;
          _paymentMethodAvailable = false;
          _quoteError = failure.message;
        });
      }
      await AppPopup.error(
        context,
        title: failure.title,
        message: failure.message,
      );
      if (failure.refreshQuote && mounted) {
        await _loadFreshQuote();
      }
    } catch (_) {
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

  String _quoteLoadMessage(String code) => switch (code) {
        'listing_not_found' =>
          'Diese Anzeige ist nicht mehr verfügbar. Bitte gehe zurück und aktualisiere die Suche.',
        'cannot_rent_own_listing' =>
          'Du kannst deine eigene Anzeige nicht mieten.',
        'rental_duration_not_allowed' =>
          'Die gewählte Mietdauer ist für diese Anzeige nicht möglich.',
        'booking_notice_too_short' =>
          'Der Mietbeginn liegt zu nah. Bitte wähle einen späteren Zeitraum.',
        'listing_period_blocked' ||
        'booking_period_unavailable' ||
        'listing_day_unavailable' =>
          'Der gewählte Zeitraum ist nicht mehr verfügbar. Bitte wähle neue Daten.',
        'booking_blocked_by_user_block' ||
        'booking_blocked_by_moderation' =>
          'Diese Buchung ist derzeit nicht möglich.',
        'booking_pilot_not_enabled' =>
          'Buchungsanfragen sind vorübergehend nicht verfügbar.',
        _ => 'Der verbindliche Serverpreis konnte nicht geladen werden.',
      };

  ({String title, String message, bool refreshQuote}) _submissionFailure(
    String code,
  ) =>
      switch (code) {
        'fresh_booking_quote_required' ||
        'booking_quote_not_found' ||
        'booking_quote_expired' ||
        'booking_quote_changed' =>
          (
            title: 'Preis wird erneuert',
            message:
                'Der verbindliche Preis ist abgelaufen oder hat sich geändert. SIT lädt jetzt einen neuen Serverpreis; bitte prüfe und bestätige ihn erneut.',
            refreshQuote: true,
          ),
        'listing_period_blocked' ||
        'booking_period_unavailable' ||
        'listing_day_unavailable' =>
          (
            title: 'Zeitraum nicht mehr verfügbar',
            message:
                'Der gewählte Zeitraum wurde inzwischen belegt oder gesperrt. Bitte gehe zurück und wähle neue Daten.',
            refreshQuote: false,
          ),
        'duplicate_booking_request' => (
            title: 'Anfrage bereits vorhanden',
            message:
                'Für diese Anzeige und diesen Zeitraum besteht bereits eine Mietanfrage. Bitte prüfe deine Buchungen.',
            refreshQuote: false,
          ),
        'cannot_rent_own_listing' => (
            title: 'Eigene Anzeige',
            message: 'Du kannst deine eigene Anzeige nicht mieten.',
            refreshQuote: false,
          ),
        'booking_blocked_by_user_block' || 'booking_blocked_by_moderation' => (
            title: 'Buchung nicht möglich',
            message: 'Diese Buchung kann derzeit nicht abgeschlossen werden.',
            refreshQuote: false,
          ),
        'authentication_required' => (
            title: 'Anmeldung erforderlich',
            message:
                'Bitte melde dich erneut an und öffne den Checkout danach noch einmal.',
            refreshQuote: false,
          ),
        'booking_command_in_progress' => (
            title: 'Anfrage wird verarbeitet',
            message:
                'Die Buchungsanfrage wird bereits verarbeitet. Bitte warte kurz und prüfe anschließend deine Buchungen.',
            refreshQuote: false,
          ),
        'booking_pilot_not_enabled' => (
            title: 'Buchung vorübergehend nicht verfügbar',
            message:
                'Buchungsanfragen sind momentan nicht freigeschaltet. Es wurde nichts belastet.',
            refreshQuote: false,
          ),
        _ => (
            title: 'Buchungsanfrage nicht gesendet',
            message: 'Bitte prüfe deine Verbindung und versuche es erneut.',
            refreshQuote: false,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final quote = _displayQuote;
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
          if (_loadingQuote) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Verbindlicher Preis wird geladen…'),
            const SizedBox(height: 12),
          ],
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
                      label: _discountLabel(quote),
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
          if (_usesRemoteBackend) ...[
            const SizedBox(height: 8),
            if (_quoteExpiresAt != null)
              Text(
                'Dieser Serverpreis ist bis ${_dateTime(_quoteExpiresAt!)} gültig.',
                style: theme.textTheme.bodySmall,
              ),
            if (_quoteError != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_quoteError!),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _loadingQuote ? null : _loadFreshQuote,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Preis neu laden'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
                        ? 'Mindestens 24 Stunden vor Mietbeginn ist die Stornierung kostenlos. Unter 24 Stunden werden grundsätzlich 50 % des Mietpreises berücksichtigt.'
                        : 'Bei einer Bestätigung jetzt: kostenlose Stornierung bis ${_dateTime(graceDeadline)}. Danach gilt vor Mietbeginn grundsätzlich die 50-%-Regel.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ab Mietbeginn gilt keine starre Pauschale. Maßgeblich sind der gesetzliche Mietzahlungsanspruch sowie ersparte Aufwendungen und eine mögliche Ersatzvermietung.',
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Dieses Angebot stammt von $_ownerName, der nach eigener Erklärung privat und nicht als Unternehmer handelt. Die besonderen gesetzlichen Vorschriften für Verbraucherverträge mit Unternehmern gelten für diesen Mietvertrag nicht. $_ownerName bleibt für Übergabe, Zustand, Mängel und Rückzahlung des Mietpreises verantwortlich. SIT unterstützt technisch; eigene Ansprüche aus dem SIT-Plattformvertrag bleiben unberührt.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LegalScreen()),
                ),
                child: Text(
                  'SIT-Plattformbedingungen und Privat-Mietbedingungen · ${PrivatePilotConfig.v51DocumentVersion}',
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LegalScreen()),
                ),
                child: const Text(
                  'Wie SIT deine Daten verarbeitet: Datenschutzerklärung',
                ),
              ),
            ],
          ),
          CheckboxListTile(
            value: _privateAndTermsConfirmed,
            onChanged: (value) => setState(
              () => _privateAndTermsConfirmed = value == true,
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              PrivatePilotConfig.v51PrivateAndPlatformTermsDeclaration,
            ),
            subtitle: Text(
              '${PrivatePilotConfig.v51DocumentName} · ${PrivatePilotConfig.v51DocumentVersion}',
            ),
          ),
          CheckboxListTile(
            value: _earlyPerformanceAndWithdrawalConfirmed,
            onChanged: (value) => setState(
              () => _earlyPerformanceAndWithdrawalConfirmed = value == true,
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              PrivatePilotConfig.v51EarlyPerformanceAndWithdrawalDeclaration,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Du gibst jetzt eine verbindliche Buchungsanfrage ab. Du zahlst erst, wenn der Vermieter sie annimmt. Dann werden insgesamt ${PrivatePilotPricing.formatMinor(quote.totalMinor, currency: quote.currency)} fällig: ${PrivatePilotPricing.formatMinor(quote.rentalSubtotalMinor, currency: quote.currency)} Mietpreis und ${PrivatePilotPricing.formatMinor(quote.platformFeeMinor, currency: quote.currency)} SIT-Plattformgebühr. Lehnt der Vermieter ab oder nimmt er die Anfrage nicht bis ${_dateTime(_bindingDeadline)} an, musst du nichts zahlen.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!_paymentMethodAvailable) ...[
            const SizedBox(height: 8),
            Text(
              'Eine echte Zahlungsmethode ist für diesen Teststand noch nicht verfügbar. Deshalb bleibt der Abschluss gesperrt.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _canSubmit ? _submitRequest : null,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(
              _submitting ? 'Wird gesendet…' : 'Bestätigen und bezahlen',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Das bloße Öffnen dieser Übersicht sendet keine Anfrage. Erst die Schaltfläche oben löst den nächsten sicheren Vertragsschritt aus.',
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
