import 'package:flutter/material.dart';
import 'package:lendify/config/private_pilot_config.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/widgets/app_popup.dart';

class PlatformWithdrawalScreen extends StatefulWidget {
  const PlatformWithdrawalScreen({super.key});

  @override
  State<PlatformWithdrawalScreen> createState() =>
      _PlatformWithdrawalScreenState();
}

class _PlatformWithdrawalScreenState extends State<PlatformWithdrawalScreen> {
  bool _loading = true;
  bool _submitting = false;
  List<RentalRequest> _requests = const [];
  RentalRequest? _selected;
  bool _confirmStep = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final current = await DataService.getCurrentUser();
    final requests = current == null
        ? <RentalRequest>[]
        : await DataService.getRentalRequestsForRenter(current.id);
    if (!mounted) return;
    setState(() {
      _requests = requests
          .where(
              (request) => !{'declined', 'cancelled'}.contains(request.status))
          .toList(growable: false);
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final request = _selected;
    final current = await DataService.getCurrentUser();
    if (request == null || current == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await DataService.recordPlatformWithdrawal(
        requestId: request.id,
        userId: current.id,
      );
      if (!mounted) return;
      if (result == null) {
        await AppPopup.error(
          context,
          title: 'Widerruf nicht gesendet',
          message: 'Die Buchung konnte nicht eindeutig zugeordnet werden.',
        );
        return;
      }
      await AppPopup.success(
        context,
        title: 'Widerruf eingegangen',
        message:
            'Inhalt, Datum und Uhrzeit wurden gespeichert. Die Wirkung auf den privaten Mietvertrag wird nicht automatisch behauptet; der aktuelle Buchungsstatus wird separat geklärt.',
      );
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      await AppPopup.error(
        context,
        title: 'Widerruf nicht gesendet',
        message: 'Bitte prüfe deine Verbindung und versuche es erneut.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vertrag widerrufen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  _confirmStep ? 'Widerruf bestätigen' : 'Buchung auswählen',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Du widerrufst hier die kostenpflichtige Plattformleistung von ShareItToo. Der Widerruf kann sich auch auf die zugehörige Buchung auswirken. Nach der Bestätigung zeigen wir den aktuellen Buchungsstatus und die weitere Abwicklung neutral an.',
                ),
                const SizedBox(height: 18),
                if (!_confirmStep) ...[
                  if (_requests.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Keine zuordenbare Buchung gefunden.'),
                      ),
                    ),
                  RadioGroup<RentalRequest>(
                    groupValue: _selected,
                    onChanged: (value) => setState(() => _selected = value),
                    child: Column(
                      children: [
                        for (final request in _requests)
                          RadioListTile<RentalRequest>(
                            value: request,
                            title: Text('Buchung ${request.id}'),
                            subtitle: Text(
                              '${_date(request.start)} bis ${_date(request.end)} · Status ${request.status}',
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _selected == null
                        ? null
                        : () => setState(() => _confirmStep = true),
                    child: const Text('Weiter'),
                  ),
                ] else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Buchung ${_selected!.id}'),
                          const SizedBox(height: 8),
                          const Text(
                            PrivatePilotConfig.platformWithdrawalDeclaration,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '${PrivatePilotConfig.documentName} · ${PrivatePilotConfig.documentVersion}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _confirmStep = false),
                    child: const Text('Zurück'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(
                      _submitting ? 'Wird gesendet…' : 'Widerruf bestätigen',
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

String _date(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year}';
}
