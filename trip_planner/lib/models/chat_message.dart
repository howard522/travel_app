// lib/models/chat_message.dart
import 'package:cloud_firestore/cloud_firestore.dart';  
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id:         json['id'] as String,
        senderId:   json['senderId'] as String,
        text:       json['text'] as String,
        createdAt:  (json['createdAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toJson() => {
        'id':        id,
        'senderId':  senderId,
        'text':      text,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
