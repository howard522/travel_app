/// Place — 行程中的一個景點
import 'package:cloud_firestore/cloud_firestore.dart';

class Place {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final int order;       // 行程中的順序
  final double stayHours;
  final String note;

  Place({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.order,
    required this.stayHours,
    required this.note,
  });

  factory Place.fromJson(Map<String, dynamic> json, String id) => Place(
        id: id,
        name: json['name'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        order: json['order'] as int,
        stayHours: (json['stayHours'] as num).toDouble(),
        note: json['note'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        'order': order,
        'stayHours': stayHours,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
