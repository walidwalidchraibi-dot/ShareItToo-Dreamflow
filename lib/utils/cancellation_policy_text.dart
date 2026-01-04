import 'package:flutter/foundation.dart';

/// Centralized strings for the unified cancellation policy used across the app.
/// Keep this as the single source of truth so all info cards stay consistent.
class CancellationPolicyText {
  static const String header = 'Stornierungsbedingungen';

  static const String _intro =
      'Solange deine Anfrage noch nicht akzeptiert ist, kannst du sie kostenlos jederzeit zurückziehen.';

  static const String _rules =
      'Nach Bestätigung gelten:\n\n'
      '• Kostenlos bis 1 Kalendertag vor Mietbeginn.\n'
      '• Am Kalendertag vor Mietbeginn: 50 % Rückerstattung.\n'
      '• Ab Mietbeginn oder bei Nicht‑Erscheinen: keine Rückerstattung.';

  static const String _note =
      '📌 Hinweis:\n\n'
      'Erfolgt eine Rückerstattung, werden alle gezahlten Beträge entsprechend mit zurückerstattet,\n'
      'einschließlich Plattformbeitrag, Priorität, sowie ggf. Liefer- und Abholgebühren.\n\n'
      'Wenn der Vermieter nach Annahme deiner Anfrage storniert, erhältst du den vollen Betrag automatisch zurück, '
      'inklusive aller gezahlten Gebühren.';

  /// Full body used in info cards.
  static String body() => '$_intro\n\n$_rules\n\n$_note';

  /// Owner-facing variant for the create-listing info card.
  /// This phrasing addresses the landlord directly and clarifies effects on reliability.
  static String get bodyForOwnerListingCard =>
      'Solange du eine Anfrage noch nicht akzeptiert hast, kann der Mieter sie jederzeit kostenlos zurückziehen.\n\n'
      'Nach deiner Bestätigung gelten für den Mieter folgende Stornierungsbedingungen:\n\n'
      '• Kostenlos bis 1 Kalendertag vor Mietbeginn\n'
      '• Am Kalendertag vor Mietbeginn: 50 % Rückerstattung\n'
      '• Ab Mietbeginn oder bei Nicht‑Erscheinen: keine Rückerstattung\n\n'
      '📌 Hinweis:\n\n'
      'Erfolgt eine Rückerstattung, werden alle gezahlten Beträge entsprechend mit zurückerstattet,\n'
      'einschließlich Plattformbeitrag, Priorität sowie ggf. Liefer- und Abholgebühren.\n\n'
      'Wenn du nach Annahme einer Anfrage stornierst, erhält der Mieter automatisch den vollen Betrag zurück,\n'
      'inklusive aller gezahlten Gebühren.\n\n'
      '⚠️ Wichtiger Hinweis für Vermieter:\n\n'
      'Eine Stornierung nach Annahme wirkt sich negativ auf deine Zuverlässigkeit und Sichtbarkeit in der App aus.\n'
      'Nimm Anfragen daher nur an, wenn die Vermietung sicher stattfinden kann.';

  /// Short, compact summary for confirmation popups.
  static String compactSummary() =>
      'Bitte beachte die Stornierungsbedingungen.\n\n'
      'Kostenlos bis 1 Kalendertag vor Mietbeginn.\n'
      'Am Kalendertag vor Mietbeginn: 50 %.\n'
      'Ab Mietbeginn oder bei Nicht‑Erscheinen: 0 %.';
}
