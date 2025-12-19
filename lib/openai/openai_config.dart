import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// OpenAI Configuration and API wrapper
class OpenAIConfig {
  static const _apiKey = String.fromEnvironment('OPENAI_PROXY_API_KEY');
  static const _endpoint = String.fromEnvironment('OPENAI_PROXY_ENDPOINT');

  /// Parse natural language search query into structured fields
  /// Returns {what: String?, where: String?, whenStart: String?, whenEnd: String?, priceMin: double?, priceMax: double?, category: String?}
  static Future<Map<String, dynamic>> parseSearchQuery(String userInput) async {
    if (userInput.trim().isEmpty) {
      return {'what': null, 'where': null, 'whenStart': null, 'whenEnd': null, 'priceMin': null, 'priceMax': null, 'category': null};
    }

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': '''Du bist ein intelligenter Parser für eine Miet-App. Extrahiere aus der natürlichen Sprache des Nutzers die folgenden Felder:

REGELN:
1. "was" = der gesuchte Gegenstand (z.B. "Auto", "Bohrmaschine", "Fahrrad")
   - Ignoriere Tippfehler und unsinnige Eingaben (z.B. "cih" → null)
   - Ignoriere Artikel, Pronomen und Verben (ich, suche, brauche, möchte, etc.)
   - Nur sinnvolle Gegenstände extrahieren
   - Mindestens 3 Buchstaben

2. "wo" = Ort oder Stadt (z.B. "München", "Berlin", "Hamburg")
   - Nur echte Ortsnamen, keine Gegenstände
   - Wenn der Nutzer "Auto in München" sagt: was="Auto", wo="München"
   - Wenn kein Ort erkennbar ist → null

3. "whenStart" = Startdatum (Format: YYYY-MM-DD)
   - "heute" = heutiges Datum
   - "morgen" = morgiges Datum
   - "übermorgen" = in 2 Tagen
   - "nächste Woche" = Montag nächster Woche
   - "nächsten Freitag" = nächster Freitag
   - "ab 15.12." = 2025-12-15
   - Wenn kein Datum erkennbar → null

4. "whenEnd" = Enddatum (Format: YYYY-MM-DD)
   - Nur setzen wenn explizite Dauer genannt wird: "für 2 Wochen", "für 3 Tage"
   - Wenn nur ein Tag genannt wird (morgen, heute), dann whenEnd = whenStart
   - Wenn keine Dauer genannt wird → null

5. "priceMin" = Mindestpreis in Euro (nur Zahl)
   - "max 50€" → priceMax=50, priceMin=null
   - "zwischen 20 und 50€" → priceMin=20, priceMax=50
   - "bis 100€" → priceMax=100, priceMin=null
   - "ab 30€" → priceMin=30, priceMax=null
   - Wenn kein Preis genannt → null

6. "priceMax" = Maximalpreis in Euro (nur Zahl)
   - Siehe Beispiele bei priceMin
   - Wenn kein Preis genannt → null

7. "category" = Kategorie (z.B. "Auto", "Werkzeuge", "Elektronik")
   - Aus dem Kontext ableiten (z.B. "Bohrmaschine" → "Werkzeuge")
   - Wenn nicht eindeutig → null

HEUTIGES DATUM: ${DateTime.now().toString().split(' ')[0]}

WICHTIG: Antworte NUR mit einem JSON-Objekt im Format:
{"what": "...", "where": "...", "whenStart": "YYYY-MM-DD", "whenEnd": "YYYY-MM-DD", "priceMin": 20, "priceMax": 50, "category": "..."}
Felder die nicht erkannt werden können → null'''
            },
            {
              'role': 'user',
              'content': userInput,
            }
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices']?[0]?['message']?['content'];
        if (content == null) {
          debugPrint('OpenAI: No content in response');
          return {'what': null, 'where': null, 'whenStart': null, 'whenEnd': null, 'priceMin': null, 'priceMax': null, 'category': null};
        }

        try {
          final parsed = jsonDecode(content) as Map<String, dynamic>;
          debugPrint('OpenAI parsed: $parsed');
          return {
            'what': parsed['what'],
            'where': parsed['where'],
            'whenStart': parsed['whenStart'],
            'whenEnd': parsed['whenEnd'],
            'priceMin': parsed['priceMin'] is num ? (parsed['priceMin'] as num).toDouble() : null,
            'priceMax': parsed['priceMax'] is num ? (parsed['priceMax'] as num).toDouble() : null,
            'category': parsed['category'],
          };
        } catch (e) {
          debugPrint('OpenAI: Failed to parse JSON: $e');
          return {'what': null, 'where': null, 'whenStart': null, 'whenEnd': null, 'priceMin': null, 'priceMax': null, 'category': null};
        }
      } else {
        debugPrint('OpenAI API error: ${response.statusCode} ${response.body}');
        return {'what': null, 'where': null, 'whenStart': null, 'whenEnd': null, 'priceMin': null, 'priceMax': null, 'category': null};
      }
    } catch (e) {
      debugPrint('OpenAI: Exception during API call: $e');
      return {'what': null, 'where': null, 'whenStart': null, 'whenEnd': null, 'priceMin': null, 'priceMax': null, 'category': null};
    }
  }

  /// Generate price suggestion for a new listing based on title and description
  /// Returns {dailyPrice: double, weeklyPrice: double, reasoning: String}
  static Future<Map<String, dynamic>> suggestPrice({
    required String title,
    required String description,
    required String category,
    required String condition,
    required String location,
  }) async {
    if (title.trim().isEmpty) {
      return {'dailyPrice': 10.0, 'weeklyPrice': 50.0, 'reasoning': 'Bitte Titel eingeben für Preisvorschlag'};
    }

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': '''Du bist ein intelligenter Mietpreis-Algorithmus für die ShareItToo Mietplattform.
Deine Aufgabe ist es, realistische Mietpreise für beliebige Gegenstände zu berechnen – sowohl Tagespreise als auch Wochenpreise – basierend auf realen Marktbedingungen in Deutschland.

EINGABEPARAMETER:
- Artikel: $title
- Beschreibung: $description
- Kategorie: $category
- Zustand: $condition
- Standort: $location

BERÜCKSICHTIGE BEI DER BERECHNUNG:

1. MARKTPREISE FÜR VERGLEICHBARE MIETANGEBOTE:
   - Recherchiere typische Mietpreise für diese Artikelkategorie in Deutschland
   - Orientiere dich am Neupreis des Produkts
   - Faustregel: Tagespreis = 1-5% des Neupreises
   - Wochenpreis = Tagespreis × 5-6 (Rabatt für längere Miete)

2. REGIONALE UNTERSCHIEDE:
   - Urban vs. ländlich: Großstädte wie München, Hamburg, Berlin → höhere Preise (+20%)
   - Mittlere Städte wie Heilbronn, Leipzig → normale Preise (Referenz)
   - Ländliche Gebiete → niedrigere Preise (-20%)
   - Nachfrage & Kaufkraft der Region beachten

3. ZUSTAND DES ARTIKELS:
   - Neu / unbenutzt: 100% des berechneten Preises
   - Sehr gut / wie neu: 80% Preisnachlass
   - Gut: 60% Preisnachlass
   - Gebraucht / akzeptabel: 40% Preisnachlass

4. NACHFRAGE IN DER KATEGORIE:
   - Fahrzeuge: sehr hohe Nachfrage → Premium-Preise
   - Technik/Elektronik: hohe Nachfrage → höhere Preise
   - Werkzeuge: mittlere Nachfrage → moderate Preise
   - Möbel/Haushalt: niedrige Nachfrage → niedrigere Preise

ANTWORTFORMAT (NUR JSON):
{"dailyPrice": 25, "weeklyPrice": 130, "reasoning": "Kurze Begründung (max. 100 Zeichen)"}'''
            },
            {
              'role': 'user',
              'content': 'Titel: $title\nBeschreibung: $description\nKategorie: $category\nZustand: $condition\nOrt: $location',
            }
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.4,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices']?[0]?['message']?['content'];
        if (content == null) {
          debugPrint('OpenAI: No content in price response');
          return {'dailyPrice': 10.0, 'weeklyPrice': 50.0, 'reasoning': 'Fehler bei Preisberechnung'};
        }

        try {
          final parsed = jsonDecode(content) as Map<String, dynamic>;
          debugPrint('OpenAI price suggestion: $parsed');
          return {
            'dailyPrice': (parsed['dailyPrice'] is num) ? (parsed['dailyPrice'] as num).toDouble() : 10.0,
            'weeklyPrice': (parsed['weeklyPrice'] is num) ? (parsed['weeklyPrice'] as num).toDouble() : 50.0,
            'reasoning': parsed['reasoning']?.toString() ?? 'KI-basierte Preisempfehlung',
          };
        } catch (e) {
          debugPrint('OpenAI: Failed to parse price JSON: $e');
          return {'dailyPrice': 10.0, 'weeklyPrice': 50.0, 'reasoning': 'Fehler bei Parsing'};
        }
      } else {
        debugPrint('OpenAI price API error: ${response.statusCode}');
        return {'dailyPrice': 10.0, 'weeklyPrice': 50.0, 'reasoning': 'API-Fehler'};
      }
    } catch (e) {
      debugPrint('OpenAI price: Exception: $e');
      return {'dailyPrice': 10.0, 'weeklyPrice': 50.0, 'reasoning': 'Netzwerkfehler'};
    }
  }

  /// Suggest long-term discount tiers based on item context and strategy
  /// Returns {tiers: [{days:int, discount:double}, {..}, {..}]}
  static Future<Map<String, dynamic>> suggestDiscountTiers({
    required String title,
    required String description,
    required String category,
    required String condition,
    required String location,
    required String strategy, // 'quick' | 'premium'
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': '''Du bist ein Mietpreis-Algorithmus für ShareItToo. Erstelle eine Rabattstaffel für längere Mietdauern.

EINGABE:
- Artikel: $title
- Beschreibung: $description
- Kategorie: $category
- Zustand: $condition
- Standort: $location
- Strategie: ${strategy == 'quick' ? 'Schnell vermieten' : 'Maximaler Gewinn'}

REGELN:
1) Liefere GENAU drei Stufen mit Mindesttagen (integer) und Rabatt in Prozent (0-95).
2) Ausgangswerte als Basis: Tage = [3, 5, 8], Rabatt = [10, 20, 30].
3) Passe die Rabatte je nach Kategorie, Standort (urban/landlich) und Zustand leicht an (±0-5 Prozentpunkte).
4) Strategieanpassung:
   - Schnell vermieten: erhöhe Rabatte leicht (bis +5 Punkte insgesamt), behalte Tage [3,5,8].
   - Maximaler Gewinn: verringere Rabatte leicht (bis -5 Punkte insgesamt), behalte Tage [3,5,8].
5) Gib NUR JSON zurück im Format:
{"tiers":[{"days":3,"discount":10},{"days":5,"discount":20},{"days":8,"discount":30}]}
'''
            },
            {
              'role': 'user',
              'content': 'Artikel: $title\nBeschreibung: $description\nKategorie: $category\nZustand: $condition\nOrt: $location\nStrategie: ${strategy == 'quick' ? 'Schnell vermieten' : 'Maximaler Gewinn'}',
            }
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices']?[0]?['message']?['content'];
        if (content == null) {
          debugPrint('OpenAI: No content in discount response');
          return {
            'tiers': [
              {'days': 3, 'discount': 10},
              {'days': 5, 'discount': 20},
              {'days': 8, 'discount': 30},
            ]
          };
        }
        try {
          final parsed = jsonDecode(content) as Map<String, dynamic>;
          final tiers = (parsed['tiers'] as List?) ?? [];
          if (tiers.length == 3) return parsed;
          // Fallback to defaults when malformed
          return {
            'tiers': [
              {'days': 3, 'discount': 10},
              {'days': 5, 'discount': 20},
              {'days': 8, 'discount': 30},
            ]
          };
        } catch (e) {
          debugPrint('OpenAI: Failed to parse discount JSON: $e');
          return {
            'tiers': [
              {'days': 3, 'discount': 10},
              {'days': 5, 'discount': 20},
              {'days': 8, 'discount': 30},
            ]
          };
        }
      } else {
        debugPrint('OpenAI discount API error: ${response.statusCode}');
        return {
          'tiers': [
            {'days': 3, 'discount': 10},
            {'days': 5, 'discount': 20},
            {'days': 8, 'discount': 30},
          ]
        };
      }
    } catch (e) {
      debugPrint('OpenAI discount: Exception: $e');
      return {
        'tiers': [
          {'days': 3, 'discount': 10},
          {'days': 5, 'discount': 20},
          {'days': 8, 'discount': 30},
        ]
      };
    }
  }
}
