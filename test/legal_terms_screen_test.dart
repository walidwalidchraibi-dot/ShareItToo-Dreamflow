import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('agb quelle enthält neue bewertungs- und verifizierungslogik', () async {
    final file = File('lib/screens/legal_terms_screen.dart');
    final text = await file.readAsString();

    expect(text, contains('Bewertungen & Bewertungssystem'));
    expect(text,
        contains('über SIT dokumentierten und abgeschlossenen Vermietung'));
    expect(
        text,
        contains(
            'Kommunikation, Zuverlässigkeit, Artikel wie beschrieben sowie Übergabe und Rückgabe'));
    expect(text, contains('arithmetischen Mittelwert der vier Kriterien'));
    expect(
        text,
        contains(
            'Preis-Leistung ist kein Bestandteil der öffentlichen Bewertung'));
    expect(text,
        contains('doppelt erfasste Bewertungen dürfen berichtigt werden'));
  });
}
