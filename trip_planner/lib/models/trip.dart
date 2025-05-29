// lib/models/trip.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String title;
  final List<String> members;
  final List<String> invites;

  /// 行程啟程時間（含日期與時分）
  final DateTime startTime;
  /// 行程結束日期（不含時間）
  final DateTime endDate;

  Trip({
    required this.id,
    required this.title,
    required this.members,
    required this.invites,
    required this.startTime,
    required this.endDate,
  });

  factory Trip.fromJson(Map<String, dynamic> json, String id) {
    // 先嘗試讀 startTime，沒有再 fallback 到舊的 startDate
    final tsStart = json['startTime'] as Timestamp?;
    final tsDate  = json['startDate']  as Timestamp?;
    final start   = tsStart?.toDate() ?? tsDate?.toDate() ?? DateTime.now();

    return Trip(
      id        : id,
      title     : json['title']   as String,
      members   : List<String>.from(json['members'] ?? []),
      invites   : List<String>.from(json['invites'] ?? []),
      startTime : start,
      endDate   : (json['endDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title'    : title,
        'members'  : members,
        'invites'  : invites,
        'startTime': Timestamp.fromDate(startTime),
        'endDate'  : Timestamp.fromDate(endDate),
      };
}
