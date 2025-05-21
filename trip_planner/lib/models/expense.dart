/// Expense — 分帳花費
import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String description;
  final String payer; // uid
  final double total;
  final Map<String, double> participants; // { uid: share }
  final bool settled;

  Expense({
    required this.id,
    required this.description,
    required this.payer,
    required this.total,
    required this.participants,
    required this.settled,
  });

  factory Expense.fromJson(Map<String, dynamic> json, String id) => Expense(
        id: id,
        description: json['description'] as String,
        payer: json['payer'] as String,
        total: (json['total'] as num).toDouble(),
        participants: Map<String, double>.from(
          (json['participants'] as Map? ?? {}),
        ),
        settled: json['settled'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'description': description,
        'payer': payer,
        'total': total,
        'participants': participants,
        'settled': settled,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
