import 'package:flutter/material.dart';
import 'package:lendify/services/backend_http.dart';
import 'package:lendify/services/backend_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentCheckoutScreen extends StatefulWidget {
  final String bookingId;

  const PaymentCheckoutScreen({super.key, required this.bookingId});

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen>
    with WidgetsBindingObserver {
  late final String _checkoutKey =
      'checkout_${widget.bookingId}_${DateTime.now().microsecondsSinceEpoch}';
  late final String _depositKey =
      'deposit_${widget.bookingId}_${DateTime.now().microsecondsSinceEpoch}';
  Map<String, dynamic>? _state;
  bool _loading = true;
  bool _working = false;
  bool _depositConsent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final value = await BackendRepository.getBookingPayment(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _state = value;
        _loading = false;
        _error = null;
      });
    } on BackendException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Der Zahlungsstatus konnte gerade nicht geladen werden.';
      });
    }
  }

  Future<void> _openSecureCheckout() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final response = await BackendRepository.createBookingCheckout(
        bookingId: widget.bookingId,
        idempotencyKey: _checkoutKey,
      );
      final rawUrl = response['checkoutUrl']?.toString() ?? '';
      final uri = Uri.tryParse(rawUrl);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const BackendException(503, 'checkout_open_failed');
      }
    } on BackendException catch (error) {
      if (mounted) {
        setState(() => _error = _message(error.code));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Der sichere Stripe-Checkout konnte nicht geöffnet werden.');
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _openDepositSetup() async {
    if (!_depositConsent) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final response = await BackendRepository.createDepositSetup(
        bookingId: widget.bookingId,
        consentVersion:
            _state?['depositConsentVersion']?.toString() ?? 'deposit-v2026-08',
        idempotencyKey: _depositKey,
      );
      final rawUrl = response['checkoutUrl']?.toString() ?? '';
      final uri = Uri.tryParse(rawUrl);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const BackendException(503, 'checkout_open_failed');
      }
    } on BackendException catch (error) {
      if (mounted) {
        setState(() => _error = _message(error.code));
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Die Kautionsabsicherung konnte nicht geöffnet werden.');
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  String _message(String code) => switch (code) {
        'booking_not_ready_for_payment' =>
          'Die Buchung muss zuerst vom Vermieter angenommen werden.',
        'owner_payout_account_not_ready' =>
          'Der Vermieter muss sein Stripe-Auszahlungskonto zuerst vervollständigen.',
        'payments_disabled' =>
          'Zahlungen sind für dieses Konto noch nicht freigeschaltet.',
        'booking_already_paid' => 'Diese Buchung wurde bereits bezahlt.',
        'deposit_consent_version_outdated' =>
          'Die Kautionsbedingungen wurden aktualisiert. Bitte öffne diese Seite erneut.',
        _ => 'Die Zahlungsaktion konnte gerade nicht abgeschlossen werden.',
      };

  String _money(Object? minor, String currency) {
    final value = (minor as num?)?.toInt() ?? 0;
    return '${(value / 100).toStringAsFixed(2).replaceAll('.', ',')} $currency';
  }

  @override
  Widget build(BuildContext context) {
    final payment = _state?['payment'] as Map?;
    final quote = _state?['quote'] as Map?;
    final amounts = payment ?? quote;
    final deposit = _state?['deposit'] as Map?;
    final currency = amounts?['currency']?.toString() ?? 'EUR';
    final paymentStatus = payment?['status']?.toString();
    final captured = const {'captured', 'partially_refunded', 'refunded'}
        .contains(paymentStatus);
    final depositMinor =
        (amounts?['securityDepositMinor'] as num?)?.toInt() ?? 0;
    final depositActive = deposit?['status'] == 'active';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sichere Zahlung'),
        actions: [
          IconButton(
              onPressed: _working ? null : _refresh,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lock_outline, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            captured ? 'Zahlung bestätigt' : 'Buchung bezahlen',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            captured
                                ? 'Stripe hat die Zahlung bestätigt. Der Status stammt direkt vom Server.'
                                : 'Betrag und Gebühr werden vom ShareItToo-Server festgelegt. Deine Kartendaten werden ausschließlich bei Stripe eingegeben.',
                          ),
                          if (amounts != null) ...[
                            const SizedBox(height: 18),
                            _AmountRow(
                                label: 'Gesamtbetrag',
                                value:
                                    _money(amounts['amountMinor'], currency)),
                            _AmountRow(
                                label: 'Plattformgebühr',
                                value: _money(
                                    amounts['platformFeeMinor'], currency)),
                            _AmountRow(
                                label: 'Vermietererlös',
                                value: _money(
                                    amounts['ownerPayoutMinor'], currency)),
                          ],
                          if (!captured) ...[
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed:
                                    _working ? null : _openSecureCheckout,
                                icon: const Icon(Icons.open_in_new),
                                label: Text(_working
                                    ? 'Bitte warten …'
                                    : 'Sicher mit Stripe bezahlen'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (captured && depositMinor > 0) ...[
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kautionsabsicherung',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text(
                              depositActive
                                  ? 'Die Zahlungsmethode für eine mögliche Kaution ist sicher bei Stripe hinterlegt.'
                                  : 'Maximal ${_money(depositMinor, currency)} dürfen nur bei einem dokumentierten Schaden und nach dem ShareItToo-Klärungsprozess belastet werden.',
                            ),
                            if (!depositActive) ...[
                              const SizedBox(height: 12),
                              CheckboxListTile(
                                value: _depositConsent,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: const Text(
                                    'Ich stimme dieser begrenzten Kautionsabsicherung ausdrücklich zu.'),
                                onChanged: _working
                                    ? null
                                    : (value) => setState(
                                        () => _depositConsent = value == true),
                              ),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _working || !_depositConsent
                                      ? null
                                      : _openDepositSetup,
                                  icon:
                                      const Icon(Icons.verified_user_outlined),
                                  label:
                                      const Text('Kaution sicher hinterlegen'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;

  const _AmountRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
