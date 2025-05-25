import 'dart:convert';
import 'package:http/http.dart' as http;

class ScheduleService {
  ScheduleService(this.apiKey);
  final String apiKey;

  /// 取得最優化後的 waypoint 順序
  /// waypoints：不含起點終點的中繼站字串列表，格式 ["lat,lng", …]
  Future<List<int>> optimize(List<String> waypoints) async {
    if (waypoints.length < 2) return List.generate(waypoints.length, (i) => i);
    // 假定第一／最後站不變，用所有站當中繼排
    final wp = waypoints.join('|');
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      {
        'origin': waypoints.first,
        'destination': waypoints.last,
        'waypoints': 'optimize:true|$wp',
        'key': apiKey,
      },
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Directions API error: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if ((json['status'] as String) != 'OK') {
      throw Exception('Directions API status: ${json['status']}');
    }
    // 回傳 routes[0].waypoint_order，裡面是中繼站最佳化後的原始索引
    return List<int>.from(json['routes'][0]['waypoint_order'] as List);
  }
}
