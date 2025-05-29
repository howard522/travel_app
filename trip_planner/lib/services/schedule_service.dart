import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/route_info.dart';
import '../models/segment_info.dart';

/// 用 Google Directions API 取得最佳路徑、中繼順序、行程時間與 polyline
class ScheduleService {
  ScheduleService(this.apiKey);
  final String apiKey;

  /// 只回傳 optimize 後的中繼索引
  Future<List<int>> optimize(List<String> waypoints) async {
    if (waypoints.length < 2) {
      return List.generate(waypoints.length, (i) => i);
    }
    final origin = waypoints.first;
    final destination = waypoints.last;
    final intermediate = waypoints.sublist(1, waypoints.length - 1).join('|');
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      {
        'origin': origin,
        'destination': destination,
        'waypoints': 'optimize:true|$intermediate',
        'key': apiKey,
        'language': 'zh-TW',
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
    return List<int>.from(
      json['routes'][0]['waypoint_order'] as List<dynamic>,
    );
  }

  /// 回傳完整路線資訊：中繼順序、每段秒數、全程 polyline
  Future<RouteInfo> getRouteInfo(List<String> waypoints) async {
    if (waypoints.length < 2) {
      return RouteInfo(
        waypointOrder: List.generate(waypoints.length, (i) => i),
        durations: [],
        overviewPolyline: '',
      );
    }
    final origin = waypoints.first;
    final destination = waypoints.last;
    final intermediate = waypoints.sublist(1, waypoints.length - 1).join('|');
    final params = {
      'origin': origin,
      'destination': destination,
      'key': apiKey,
      'language': 'zh-TW',
    };
    if (intermediate.isNotEmpty) {
      params['waypoints'] = 'optimize:true|$intermediate';
    }
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      params,
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Directions API error: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if ((json['status'] as String) != 'OK') {
      throw Exception('Directions API status: ${json['status']}');
    }
    final route = json['routes'][0] as Map<String, dynamic>;
    final polyline = route['overview_polyline']['points'] as String;
    final order = List<int>.from(route['waypoint_order'] as List<dynamic>);
    final legs = route['legs'] as List<dynamic>;
    final durations = legs.map((leg) => (leg['duration']['value'] as int)).toList();

    return RouteInfo(
      waypointOrder: order,
      durations: durations,
      overviewPolyline: polyline,
    );
    
  }

  Future<SegmentInfo> getSegmentInfo(
    String origin,
    String destination,
    String modeKey,
  ) async {
    final params = {
      'origin': origin,
      'destination': destination,
      'key': apiKey,
      'language': 'zh-TW',
    };
    if (modeKey == 'bus' || modeKey == 'subway') {
      params['mode'] = 'transit';
      params['transit_mode'] = modeKey;
    } else {
      params['mode'] = modeKey;
    }
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      params,
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Directions API error: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if ((json['status'] as String) != 'OK') {
      throw Exception('Directions API status: ${json['status']}');
    }
    final route = json['routes'][0] as Map<String, dynamic>;
    final leg = (route['legs'] as List<dynamic>)[0] as Map<String, dynamic>;
    final polyline = route['overview_polyline']['points'] as String;
    final duration = (leg['duration']['value'] as int);
    return SegmentInfo(duration: duration, polyline: polyline);
  }

}
