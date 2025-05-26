// 在最上方加入 Firestore import
import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String title;
  final int cents;
  final String payerId;
  final List<String> sharedBy;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.title,
    required this.cents,
    required this.payerId,
    required this.sharedBy,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cents': cents,
        'payerId': payerId,
        'sharedBy': sharedBy,
        'createdAt': createdAt,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        title: j['title'] as String,
        cents: j['cents'] as int,
        payerId: j['payerId'] as String,
        sharedBy: List<String>.from(j['sharedBy'] as List),
        // 正確使用 Timestamp 轉 DateTime
        createdAt: (j['createdAt'] as Timestamp).toDate(),
      );
}
