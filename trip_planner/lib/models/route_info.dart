// lib/models/route_info.dart

class RouteInfo {
  /// 經 Google Directions API optimize 計算後的中繼站索引（不含起點終點）
  final List<int> waypointOrder;
  /// 每段路程的持續時間（秒）
  final List<int> durations;
  /// 全程路線的 polyline 編碼字串
  final String overviewPolyline;

  RouteInfo({
    required this.waypointOrder,
    required this.durations,
    required this.overviewPolyline,
  });
}