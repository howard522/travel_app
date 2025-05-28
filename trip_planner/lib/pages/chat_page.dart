// lib/pages/chat_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/profile_providers.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    await ref.read(sendMessageProvider)(widget.tripId, text);
    _ctrl.clear();
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final msgsAsync = ref.watch(messagesProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('行程聊天室')),
      body: Column(
        children: [
          Expanded(
            child: msgsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('載入失敗：$e')),
              data: (list) {
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(8),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final m = list[i];
                    final isMe = m.senderId ==
                        ref.read(authStateProvider).value?.uid;

                    // 監聽此 senderId 的 Profile
                    final profileAsync =
                        ref.watch(userProfileProviderFamily(m.senderId));

                    return profileAsync.when(
                      loading: () => _buildMessageBubble(
                        senderName: m.senderId,
                        text: m.text,
                        isMe: isMe,
                      ),
                      error: (_, __) => _buildMessageBubble(
                        senderName: m.senderId,
                        text: m.text,
                        isMe: isMe,
                      ),
                      data: (profile) {
                        final name = profile?.displayName.isNotEmpty == true
                            ? profile!.displayName
                            : m.senderId;
                        return _buildMessageBubble(
                          senderName: name,
                          text: m.text,
                          isMe: isMe,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          KeyboardVisibilityBuilder(
            builder: (_, __) {
              return SafeArea(
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        decoration:
                            const InputDecoration(hintText: '輸入訊息…'),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _send,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String senderName,
    required String text,
    required bool isMe,
  }) {
    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          child: Text(
            senderName,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            decoration: BoxDecoration(
              color: isMe
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(text),
          ),
        ),
      ],
    );
  }
}
