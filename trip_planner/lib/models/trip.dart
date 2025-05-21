/// Trip — 一次旅程的主檔
import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String title;
  final String owner; // uid
  final List<String> members; // uid list
  final DateTime startDate;
  final DateTime endDate;

  Trip({
    required this.id,
    required this.title,
    required this.owner,
    required this.members,
    required this.startDate,
    required this.endDate,
  });

  factory Trip.fromJson(Map<String, dynamic> json, String id) => Trip(
        id: id,
        title: json['title'] as String,
        owner: json['owner'] as String,
        members: List<String>.from(json['members'] ?? const []),
        startDate: (json['startDate'] as Timestamp).toDate(),
        endDate: (json['endDate'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'owner': owner,
        'members': members,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'createdAt': FieldValue.serverTimestamp(),
      };
}
