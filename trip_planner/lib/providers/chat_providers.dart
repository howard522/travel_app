// lib/providers/chat_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import 'trip_providers.dart';
import 'auth_providers.dart';

/// 監聽指定行程的聊天室訊息
final messagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, tripId) {
  return ref.watch(tripRepoProvider).watchMessages(tripId);
});

/// 傳送聊天訊息的動作 provider
final sendMessageProvider =
    Provider<Future<void> Function(String tripId, String text)>((ref) {
  final repo = ref.watch(tripRepoProvider);
  return (tripId, text) async {
    final user = ref.read(authStateProvider).value!;
    final now = DateTime.now();
    final msg = ChatMessage(
      id:        '_tmp',
      senderId:  user.uid,
      text:      text,
      createdAt: now,
    );
    await repo.sendMessage(tripId, msg);
  };
});
