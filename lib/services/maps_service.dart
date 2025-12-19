import 'dart:convert';
import 'package:http/http.dart' as http;

class MapsService {
  // Provide an API key via --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY when running the app.
  static const String _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static bool get isConfigured => _apiKey.isNotEmpty;

  static Future<List<_AddrOption>> autocomplete(String input, {String language = 'de', String country = 'de'}) async {
    if (!isConfigured) {
      // Fallback demo suggestions
      final demo = <String>[
        'Musterstraße 1, 10115 Berlin',
        'Hauptstraße 12, 80331 München',
        'Bahnhofstraße 3, 50667 Köln',
        'Gartenweg 7, 70173 Stuttgart',
        'Ringstraße 22, 28195 Bremen',
      ];
      final q = input.toLowerCase().trim();
      return demo.where((e) => e.toLowerCase().contains(q)).map((e) => _AddrOption(description: e, placeId: null)).toList();
    }
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': input,
      'types': 'address',
      'language': language,
      'components': 'country:$country',
      'key': _apiKey,
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final preds = (data['predictions'] as List?) ?? const [];
    return preds.map((p) {
      final m = p as Map<String, dynamic>;
      return _AddrOption(description: m['description'] ?? '', placeId: m['place_id']);
    }).toList();
  }

  static Future<PlaceDetails?> placeDetails(String placeId, {String language = 'de'}) async {
    if (!isConfigured) return null;
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'fields': 'formatted_address,geometry',
      'language': language,
      'key': _apiKey,
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final result = data['result'] as Map<String, dynamic>?;
    if (result == null) return null;
    final formatted = result['formatted_address'] as String?;
    final loc = (result['geometry'] as Map?)?['location'] as Map?;
    final lat = (loc?['lat'] as num?)?.toDouble();
    final lng = (loc?['lng'] as num?)?.toDouble();
    if (formatted == null || lat == null || lng == null) return null;
    return PlaceDetails(formattedAddress: formatted, lat: lat, lng: lng);
  }
}

class _AddrOption {
  final String description;
  final String? placeId;
  const _AddrOption({required this.description, required this.placeId});
}

class PlaceDetails {
  final String formattedAddress;
  final double lat;
  final double lng;
  const PlaceDetails({required this.formattedAddress, required this.lat, required this.lng});
}
