import 'dart:convert';
import 'package:http/http.dart' as http;

/// 使用 Google Routes API — Waypoint Optimization
class ScheduleService {
  ScheduleService(this.apiKey);
  final String apiKey;

  /// waypoints = [ "24.142,120.682", "24.152,120.69" ... ]
  Future<List<String>> optimize(List<String> waypoints) async {
    if (waypoints.length <= 2) return waypoints;

    final url = Uri.https(
      'routes.googleapis.com',
      '/directions/v2:computeRoutes',
    );

    // API 文件詳見: https://developers.google.com/maps/documentation/routes
    final body = {
      "origin": {"location": {"latLng": toLatLng(waypoints.first)}},
      "destination": {"location": {"latLng": toLatLng(waypoints.last)}},
      "intermediates": waypoints
          .sublist(1, waypoints.length - 1)
          .map((w) => {"location": {"latLng": toLatLng(w)}})
          .toList(),
      "travelMode": "DRIVE",
      "optimizeWaypointOrder": true
    };

    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'routes.optimizedIntermediateWaypointIndex'
      },
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) throw res.body;
    final data = jsonDecode(res.body) as Map;
    final idx = (data['routes'][0]['optimizedIntermediateWaypointIndex'] as List)
        .cast<int>();

    // 返回「最佳順序」的 waypoint 清單
    final optimized = [
      waypoints.first,
      ...idx.map((i) => waypoints.sublist(1, waypoints.length - 1)[i]),
      waypoints.last
    ];
    return optimized;
  }

  Map<String, dynamic> toLatLng(String latLng) {
    final parts = latLng.split(',');
    return {"latitude": double.parse(parts[0]), "longitude": double.parse(parts[1])};
  }
}
