// lib/pages/chat_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

import '../models/chat_message.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/profile_providers.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({Key? key, required this.tripId}) : super(key: key);
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
                    final profileAsync =
                        ref.watch(userProfileProviderFamily(m.senderId));

                    return profileAsync.when(
                      loading: () => _buildMessageBubble(
                        senderName: m.senderId,
                        text: m.text,
                        isMe: isMe,
                        avatarUrl: null,
                      ),
                      error: (_, __) => _buildMessageBubble(
                        senderName: m.senderId,
                        text: m.text,
                        isMe: isMe,
                        avatarUrl: null,
                      ),
                      data: (profile) {
                        final name = (profile?.displayName.isNotEmpty == true)
                            ? profile!.displayName
                            : m.senderId;
                        final avatarUrl =
                            profile?.photoURL.isNotEmpty == true
                                ? profile!.photoURL
                                : null;
                        return _buildMessageBubble(
                          senderName: name,
                          text: m.text,
                          isMe: isMe,
                          avatarUrl: avatarUrl,
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
    String? avatarUrl,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) _buildAvatar(avatarUrl),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(text),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe) _buildAvatar(avatarUrl),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? url) {
    return CircleAvatar(
      radius: 16,
      backgroundImage: (url != null) ? NetworkImage(url) : null,
      child: (url == null) ? const Icon(Icons.person, size: 16) : null,
    );
  }
}
