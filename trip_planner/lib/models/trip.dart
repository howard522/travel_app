import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String title;
  final List<String> members;
  final List<String> invites;    // ← 新增
  final DateTime startDate;
  final DateTime endDate;

  Trip({
    required this.id,
    required this.title,
    required this.members,
    required this.invites,
    required this.startDate,
    required this.endDate,
  });

  factory Trip.fromJson(Map<String, dynamic> json, String id) {
    return Trip(
      id: id,
      title: json['title'] as String,
      members: List<String>.from(json['members'] ?? []),
      invites: List<String>.from(json['invites'] ?? []), // ← 讀 invites
      startDate: (json['startDate'] as Timestamp).toDate(),
      endDate: (json['endDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'members': members,
      'invites': invites, // ← 寫回 invites
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
    };
  }
}
