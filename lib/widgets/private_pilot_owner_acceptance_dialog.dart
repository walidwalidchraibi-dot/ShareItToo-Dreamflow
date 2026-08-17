import 'package:flutter/material.dart';
import 'package:lendify/config/private_pilot_config.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/services/backend_config.dart';
import 'package:lendify/services/private_pilot_pricing.dart';
import 'package:lendify/services/qa_runtime_service.dart';
import 'package:lendify/widgets/private_pilot_risk_notice.dart';

Future<List<Map<String, dynamic>>?> showPrivatePilotOwnerAcceptanceDialog(
  BuildContext context, {
  required RentalRequest request,
  PrivatePilotQuote? quote,
  bool? isBindingServerQuote,
}) async {
  PrivatePilotQuote? requestSnapshot;
  try {
    requestSnapshot = PrivatePilotQuote.fromRentalRequestSnapshot(request);
  } on FormatException {
    requestSnapshot = null;
  }
  final displayedQuote = quote ?? requestSnapshot;
  final bindingServerQuote = isBindingServerQuote ??
      (BackendConfig.enabled &&
          !QaRuntimeService.isEnabled &&
          requestSnapshot != null);
  var confirmed = false;
  return showDialog<List<Map<String, dynamic>>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Buchungsanfrage annehmen'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zeitraum: ${_date(request.start)} bis ${_date(request.end)}',
                ),
                const SizedBox(height: 8),
                Text(
                  displayedQuote == null
                      ? 'Preisprüfung fehlgeschlagen'
                      : bindingServerQuote
                          ? 'Verbindlicher Serverpreis'
                          : 'Lokaler Testpreis · kein Echtgeld',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (displayedQuote == null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Der verbindliche Preis fehlt oder ist widersprüchlich. Die Annahme bleibt gesperrt; bitte lade die Anfrage neu.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'Privater Mietpreis / deine vorgesehene Auszahlung: ${_money(displayedQuote.rentalSubtotalMinor)}',
                  ),
                  Text(
                    'SIT-Plattformbeitrag des Mieters: ${_money(displayedQuote.platformFeeMinor)}',
                  ),
                  Text(
                    'Gesamtpreis des Mieters: ${_money(displayedQuote.totalMinor)}',
                  ),
                ],
                const SizedBox(height: 12),
                const PrivatePilotRiskNotice(
                  title: 'Privatvermietung ohne SIT-Schadenschutz',
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: confirmed,
                  onChanged: displayedQuote == null
                      ? null
                      : (value) => setState(() => confirmed = value == true),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    PrivatePilotConfig.ownerAcceptanceDeclaration,
                  ),
                  subtitle: const Text(
                    '${PrivatePilotConfig.documentName} · ${PrivatePilotConfig.documentVersion}',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: confirmed && displayedQuote != null
                ? () {
                    final acceptedAt = DateTime.now();
                    Navigator.of(dialogContext).pop([
                      {
                        'type': 'owner_booking_acceptance',
                        'exactWording':
                            PrivatePilotConfig.ownerAcceptanceDeclaration,
                        'documentName': PrivatePilotConfig.documentName,
                        'documentVersion': PrivatePilotConfig.documentVersion,
                        'language': PrivatePilotConfig.language,
                        'accepted': true,
                        'acceptedAt': acceptedAt.toIso8601String(),
                      },
                    ]);
                  }
                : null,
            child: const Text('Verbindlich annehmen'),
          ),
        ],
      ),
    ),
  );
}

String _date(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year}';
}

String _money(int minor) => '${(minor / 100).toStringAsFixed(2)} €';
