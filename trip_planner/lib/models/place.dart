// lib/models/place.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Place 類別：新增了 `date` 欄位，用來標記此景點屬於哪一天
class Place {
  final String id;
  final String name;
  final double lat, lng;
  final int order;
  final int stayHours;
  final String note;
  final DateTime date; // 新增：該景點所屬的日期（不包含時間）

  Place({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.order,
    required this.stayHours,
    required this.note,
    required this.date,
  });

  /// 將各欄位序列化成 Firestore 可以接受的 Map
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'order': order,
        'stayHours': stayHours,
        'note': note,
        // 將 DateTime 轉成 Timestamp
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      };

  /// 從 Firestore 回傳的 JSON Map 建構 Place 物件
  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String,
        name: json['name'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        order: json['order'] as int,
        stayHours: json['stayHours'] as int,
        note: json['note'] as String,
        // 從 Timestamp 取出純日期（若 Firestore 裡面存的是 Timestamp）
        date: (json['date'] as Timestamp).toDate(),
      );
}
