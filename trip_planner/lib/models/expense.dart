/// Expense model
import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  Expense({
    required this.id,
    required this.title,
    required this.cents,       // 以「整數分」記金額
    required this.payerId,
    required this.sharedBy,    // 參與者 uid
    required this.createdAt,
    this.settled = false,      // 👈 新增，預設 false
  });

  final String id;
  final String title;
  final int    cents;
  final String payerId;
  final List<String> sharedBy;
  final DateTime createdAt;
  final bool settled;

  /* ---------------- serialization ---------------- */

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id        : json['id']       as String,
        title     : json['title']    as String,
        cents     : json['cents']    as int,
        payerId   : json['payerId']  as String,
        sharedBy  : List<String>.from(json['sharedBy'] as List),
        createdAt : (json['createdAt'] as Timestamp).toDate(),
        settled   : (json['settled'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => {
        'id'       : id,
        'title'    : title,
        'cents'    : cents,
        'payerId'  : payerId,
        'sharedBy' : sharedBy,
        'createdAt': createdAt,
        'settled'  : settled,
      };

  Expense copyWith({bool? settled}) =>
      Expense(
        id        : id,
        title     : title,
        cents     : cents,
        payerId   : payerId,
        sharedBy  : sharedBy,
        createdAt : createdAt,
        settled   : settled ?? this.settled,
      );
}
