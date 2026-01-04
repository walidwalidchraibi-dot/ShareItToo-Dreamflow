import 'package:flutter/material.dart';

/// Helper to build the small subtitle shown under the Gesamtbetrag.
/// Decides wording based on delivery (Lieferung), pickup (Abholung), and
/// priority (Priorität) selections.
class TotalSubtitleHelper {
  /// Returns the localized German sentence with proper punctuation.
  ///
  /// Rules (updated):
  /// - Priorität wird IMMER erwähnt, wenn aktiv – auch ohne Lieferung.
  /// Beispiele:
  /// 1) L=false · A=false · Prio=false → "Inkl. Plattformbeitrag."
  /// 2) L=false · A=false · Prio=true  → "Inkl. Plattformbeitrag und priorisierter Anfrage."
  /// 3) L=true  · A=false · Prio=false → "Inkl. Plattformbeitrag und Lieferung."
  /// 4) L=true  · A=false · Prio=true  → "Inkl. Plattformbeitrag, Lieferung und priorisierter Anfrage."
  /// 5) L=false · A=true  · Prio=false → "Inkl. Plattformbeitrag und Abholung."
  /// 6) L=false · A=true  · Prio=true  → "Inkl. Plattformbeitrag, Abholung und priorisierter Anfrage."
  /// 7) L=true  · A=true  · Prio=false → "Inkl. Plattformbeitrag und Lieferung & Abholung."
  /// 8) L=true  · A=true  · Prio=true  → "Inkl. Plattformbeitrag, Lieferung & Abholung sowie priorisierter Anfrage."
  static String build({required bool delivery, required bool pickup, required bool priority}) {
    try {
      if (!delivery && !pickup && !priority) return 'Inkl. Plattformbeitrag.';
      if (!delivery && !pickup && priority) return 'Inkl. Plattformbeitrag und priorisierter Anfrage.';
      if (delivery && !pickup && !priority) return 'Inkl. Plattformbeitrag und Lieferung.';
      if (delivery && !pickup && priority) return 'Inkl. Plattformbeitrag, Lieferung und priorisierter Anfrage.';
      if (!delivery && pickup && !priority) return 'Inkl. Plattformbeitrag und Abholung.';
      if (!delivery && pickup && priority) return 'Inkl. Plattformbeitrag, Abholung und priorisierter Anfrage.';
      if (delivery && pickup && !priority) return 'Inkl. Plattformbeitrag und Lieferung & Abholung.';
      if (delivery && pickup && priority) return 'Inkl. Plattformbeitrag, Lieferung & Abholung sowie priorisierter Anfrage.';
      return 'Inkl. Plattformbeitrag.';
    } catch (e) {
      debugPrint('TotalSubtitleHelper.build error: $e');
      return 'Inkl. Plattformbeitrag.';
    }
  }
}
