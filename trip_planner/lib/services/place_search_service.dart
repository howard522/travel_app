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
    print(res.body);
    if (res.statusCode != 200) throw res.body;
    final json = jsonDecode(res.body) as Map;
    if (json['status'] != 'OK') throw json['status'];
    return (json['results'] as List).map((e) {
      final loc = e['geometry']['location'];
      return PlaceSuggestion(
        name: e['name'],
        lat: (loc['lat'] as num).toDouble(),
        lng: (loc['lng'] as num).toDouble(),
      );
    }).toList();
  }
}

class PlaceSuggestion {
  final String name;
  final double lat, lng;
  PlaceSuggestion({required this.name, required this.lat, required this.lng});
}
