// lib/models/segment_info.dart

/// 單一路段資訊：時間與 polyline
class SegmentInfo {
  /// 該路段的行駛時間（秒）
  final int duration;
  /// 該路段的 polyline 編碼字串
  final String polyline;

  SegmentInfo({
    required this.duration,
    required this.polyline,
  });
}