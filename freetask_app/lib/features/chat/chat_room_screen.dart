import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_utils.dart';
import 'chat_models.dart';
import 'chat_repository.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncMessages = ref.watch(chatMessagesProvider(widget.chatId));
    final bool hasMessageError = asyncMessages.hasError;
    final thread = ref.watch(chatThreadsProvider).maybeWhen(
          data: (List<ChatThread> threads) => threads.firstWhere(
            (ChatThread element) => element.id == widget.chatId,
            orElse: () => const ChatThread(
              id: 'unknown',
              jobTitle: 'Chat',
              participantName: 'Pengguna',
            ),
          ),
          orElse: () => const ChatThread(
            id: 'unknown',
            jobTitle: 'Chat',
            participantName: 'Pengguna',
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(thread.jobTitle),
            Text(
              'Bersama ${thread.participantName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: asyncMessages.when(
              data: (List<ChatMessage> messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Tiada data'),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (BuildContext context, int index) {
                    final message = messages[index];
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              message.text,
                              style: const TextStyle(color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${message.senderName} • ${_formatTimestamp(message.timestamp)}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) {
                final message = error is DioException
                    ? resolveDioErrorMessage(error)
                    : 'Ralat memuat mesej. Sila cuba lagi.';
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.refresh(chatMessagesProvider(widget.chatId)),
                          child: const Text('Cuba Lagi'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _MessageComposer(
            controller: _controller,
            onSendText: _handleSendText,
            enabled: !hasMessageError,
          ),
        ],
      ),
    );
  }

  Future<void> _handleSendText(String text) async {
    if (text.trim().isEmpty) {
      return;
    }
    final trimmed = text.trim();
    try {
      await ref.read(chatRepositoryProvider).sendText(
            jobId: widget.chatId,
            text: trimmed,
          );
      _controller.clear();
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(resolveDioErrorMessage(error));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Ralat menghantar mesej.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.onSendText,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSendText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                readOnly: !enabled,
                textInputAction: enabled ? TextInputAction.send : TextInputAction.none,
                decoration: InputDecoration(
                  hintText: enabled
                      ? 'Tulis mesej...'
                      : 'Chat akan datang (Coming Soon)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: enabled ? onSendText : null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: enabled ? () => onSendText(controller.text) : null,
            ),
          ],
        ),
      ),
    );
  }
}
