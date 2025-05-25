import 'dart:convert';
import 'package:http/http.dart' as http;

/// 用 Google Places **Text Search** 端點做關鍵字搜尋
class PlaceSearchService {
  PlaceSearchService(this.apiKey);
  final String apiKey;

  Future<List<PlaceSuggestion>> search(String query) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/textsearch/json',
      {'query': query, 'key': apiKey, 'language': 'zh-TW'},
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Network error: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final status = json['status'] as String? ?? 'UNKNOWN';

    if (status == 'OK') {
      return (json['results'] as List).map((e) {
        final loc = e['geometry']['location'];
        return PlaceSuggestion(
          name: e['name'] as String,
          lat: (loc['lat'] as num).toDouble(),
          lng: (loc['lng'] as num).toDouble(),
        );
      }).toList();
    } else if (status == 'ZERO_RESULTS') {
      // 找不到時回傳空清單，不丟例外
      return [];
    } else {
      throw Exception('Places API error: $status');
    }
  }
}

class PlaceSuggestion {
  final String name;
  final double lat, lng;
  PlaceSuggestion({required this.name, required this.lat, required this.lng});
}
