import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_utils.dart';
import '../../services/upload_service.dart';
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
                    final isMe = message.sender == 'me';
                    final bubbleColor = isMe
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300;
                    final textColor = isMe ? Colors.white : Colors.grey.shade800;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (message.hasImage) ...<Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  message.imageUrl!,
                                  width: 160,
                                  height: 160,
                                  fit: BoxFit.cover,
                                  errorBuilder: (
                                    BuildContext context,
                                    Object error,
                                    StackTrace? stackTrace,
                                  ) {
                                    return Container(
                                      width: 160,
                                      height: 160,
                                      color: Colors.black12,
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Gagal memuat gambar',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (message.text != null)
                              Text(
                                message.text!,
                                style: TextStyle(color: textColor),
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
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }
                  _showSnackBar(friendlyErrorMessage(error));
                });
                return const Center(
                  child: Text('Chat akan datang (Coming Soon). Sila cuba lagi nanti.'),
                );
              },
            ),
          ),
          _MessageComposer(
            controller: _controller,
            onSendText: _handleSendText,
            onSendImage: _handleSendImage,
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
            chatId: widget.chatId,
            text: trimmed,
          );
      _controller.clear();
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Ralat menghantar mesej.');
    }
  }

  Future<void> _handleSendImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }
    try {
      final imageUrl = await uploadService.uploadFile(path);
      await ref.read(chatRepositoryProvider).sendImage(
            chatId: widget.chatId,
            imageUrl: imageUrl,
          );
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(mapDioError(error).message);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is StateError ? error.message : error.toString();
      _showSnackBar(message);
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
    required this.onSendImage,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSendText;
  final VoidCallback onSendImage;
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
            IconButton(
              icon: const Icon(Icons.photo),
              onPressed: enabled ? onSendImage : null,
            ),
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
