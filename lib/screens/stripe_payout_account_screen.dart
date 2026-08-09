import 'package:flutter/material.dart';
import 'package:lendify/services/backend_http.dart';
import 'package:lendify/services/backend_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class StripePayoutAccountScreen extends StatefulWidget {
  const StripePayoutAccountScreen({super.key});

  @override
  State<StripePayoutAccountScreen> createState() =>
      _StripePayoutAccountScreenState();
}

class _StripePayoutAccountScreenState extends State<StripePayoutAccountScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _account;
  bool _loading = true;
  bool _working = false;
  String? _error;
  late final String _onboardingKey =
      'connect_onboarding_${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final account = await BackendRepository.getConnectStatus();
      if (!mounted) return;
      setState(() {
        _account = account;
        _loading = false;
        _error = null;
      });
    } on BackendException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.code == 'payments_disabled'
            ? 'Auszahlungen sind für dieses Konto noch nicht freigeschaltet.'
            : 'Der Stripe-Kontostatus konnte gerade nicht geladen werden.';
      });
    }
  }

  Future<void> _startOnboarding() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final response = await BackendRepository.startConnectOnboarding(
        idempotencyKey: _onboardingKey,
      );
      final uri = Uri.tryParse(response['onboardingUrl']?.toString() ?? '');
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const BackendException(503, 'connect_open_failed');
      }
    } on BackendException {
      if (mounted) {
        setState(() => _error =
            'Das sichere Stripe-Onboarding konnte nicht geöffnet werden.');
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _account?['ready'] == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auszahlungskonto'),
        actions: [
          IconButton(
              onPressed: _working ? null : _load,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            ready
                                ? Icons.verified_rounded
                                : Icons.account_balance_outlined,
                            size: 40,
                            color: ready
                                ? Colors.green
                                : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            ready
                                ? 'Stripe-Konto bereit'
                                : 'Stripe-Auszahlungskonto einrichten',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            ready
                                ? 'Identität und Auszahlungsmöglichkeit wurden bestätigt. Erlöse werden erst nach abgeschlossener Rückgabe und der festgelegten Sicherheitsfrist freigegeben.'
                                : 'Stripe erfasst Identität, Steuer- und Bankdaten in einem sicheren, aktuellen Onboarding. ShareItToo speichert keine IBAN auf diesem Gerät.',
                          ),
                          if (_account?['disabledReason'] != null) ...[
                            const SizedBox(height: 12),
                            Text('Hinweis: ${_account!['disabledReason']}'),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _working ? null : _startOnboarding,
                              icon: const Icon(Icons.open_in_new),
                              label: Text(
                                _working
                                    ? 'Bitte warten …'
                                    : (ready
                                        ? 'Stripe-Konto verwalten'
                                        : 'Sicher bei Stripe fortfahren'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('So fließt das Geld',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 17)),
                          SizedBox(height: 10),
                          Text('1. Der Mieter bezahlt sicher über Stripe.'),
                          Text(
                              '2. ShareItToo bestätigt die Zahlung ausschließlich per Stripe-Ereignis.'),
                          Text(
                              '3. Der Vermietererlös bleibt bis zum Buchungsabschluss gesperrt.'),
                          Text(
                              '4. Streitfälle oder Erstattungen stoppen die Auszahlung automatisch.'),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_error!)),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
