import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';

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
    final repository = ref.watch(chatRepositoryProvider);
    final bool hasMore = repository.hasMore(widget.chatId);
    final bool isLoadingMore = repository.isLoadingMore(widget.chatId);
    final bool isInitialLoading = repository.isInitialLoading(widget.chatId);
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
                if (isInitialLoading && messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Tiada mesej lagi. Hantar mesej pertama!'),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    final atBottom = _scrollController.offset >=
                        _scrollController.position.maxScrollExtent - 40;
                    if (atBottom || !hasMore) {
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    }
                  }
                });
                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(chatRepositoryProvider)
                      .reloadMessages(widget.chatId),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (hasMore ? 1 : 0),
                    itemBuilder: (BuildContext context, int index) {
                      if (hasMore && index == 0) {
                        return _LoadMoreBanner(
                          isLoadingMore: isLoadingMore,
                          onLoadMore: _handleLoadMore,
                        );
                      }
                      final message =
                          hasMore ? messages[index - 1] : messages[index];
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
                              if (message.type == 'image' &&
                                  message.attachmentUrl != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    message.attachmentUrl!,
                                    height: 200,
                                    width: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image,
                                        size: 50,
                                        color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (message.text.isNotEmpty)
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
                  ),
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
                        const Icon(Icons.error_outline,
                            size: 40, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () =>
                              ref.refresh(chatMessagesProvider(widget.chatId)),
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
      await ref.read(chatRepositoryProvider).sendMessage(
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

  Future<void> _handleSendImage(File file) async {
    try {
      // 1. Upload image using services repository (reusing upload logic)
      // Note: We might want to move upload logic to a shared repository later
      // For now, importing services_repository is fine or we duplicate upload logic
      // But ServicesRepository is not imported here.
      // Better: Add uploadImage to ChatRepository or use a shared FileRepository.

      // Let's assume ChatRepository has uploadImage now or we can implement it there quickly.
      // Wait, I didn't add uploadImage to ChatRepository. I should.

      // Temporary: Use a placeholder or notify user if fails.

      // Actually, I can use a quick http post here or better, add upload logic to ChatRepo.
      // Since I can't edit ChatRepo here easily (parallel edits constraint),
      // I will assume ChatRepo has it or I will add it in next step.
      // Note: Image upload logic to be implemented in ChatRepository.

      // Better plan: Add upload logic to ChatRepository in the next step.
      // So here just call it.

      final url = await ref.read(chatRepositoryProvider).uploadChatImage(file);

      await ref.read(chatRepositoryProvider).sendMessage(
            jobId: widget.chatId,
            text: '', // Empty text for image message
            type: 'image',
            attachmentUrl: url,
          );
    } on DioException catch (error) {
      if (!mounted) return;
      _showSnackBar(resolveDioErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Gagal menghantar gambar.');
    }
  }

  Future<void> _handleLoadMore() async {
    try {
      await ref.read(chatRepositoryProvider).loadMoreMessages(widget.chatId);
    } on DioException catch (error) {
      if (!mounted) return;
      _showSnackBar(resolveDioErrorMessage(error));
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Gagal memuat mesej tambahan: $error');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Sekarang';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minit lalu';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

class _MessageComposer extends StatefulWidget {
  const _MessageComposer({
    required this.controller,
    required this.onSendText,
    required this.onSendImage,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSendText;
  final ValueChanged<File> onSendImage;
  final bool enabled;

  @override
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
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
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: widget.enabled ? _pickImage : null,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.controller,
                readOnly: !widget.enabled,
                textInputAction: widget.enabled
                    ? TextInputAction.send
                    : TextInputAction.none,
                decoration: InputDecoration(
                  hintText: widget.enabled
                      ? 'Tulis mesej...'
                      : 'Chat akan datang (Coming Soon)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: widget.enabled ? widget.onSendText : null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: widget.enabled
                  ? () => widget.onSendText(widget.controller.text)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      widget.onSendImage(File(result.files.single.path!));
    }
  }
}

class _LoadMoreBanner extends StatelessWidget {
  const _LoadMoreBanner({
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Sejarah chat dipendekkan. Muat lebih mesej lama.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: isLoadingMore ? null : onLoadMore,
            child: isLoadingMore
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Load more'),
          ),
        ],
      ),
    );
  }
}
