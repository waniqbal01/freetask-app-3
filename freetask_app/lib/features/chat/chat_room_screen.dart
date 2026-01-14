import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_utils.dart';
import '../../core/utils/url_utils.dart';
import '../auth/auth_providers.dart';
import 'chat_models.dart';
import 'chat_repository.dart';
import 'package:intl/intl.dart';

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
      backgroundColor: const Color(0xFFF5F7FB), // Light Blue-Grey background
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2), // Primary Blue
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              child: Text(
                  thread.participantName.isNotEmpty
                      ? thread.participantName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.black)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(thread.participantName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(thread.jobStatus),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      thread.jobStatus.replaceAll('_', ' '),
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      // Reverse index for checking next/prev message because ListView is usually safe,
                      // but here we render top-down.
                      // To check date change:
                      final bool isFirstMessageOfDay = _isFirstMessageOfDay(
                          messages, hasMore ? index - 1 : index);

                      return Column(
                        children: [
                          if (isFirstMessageOfDay)
                            _DateHeader(timestamp: message.timestamp),
                          _MessageBubble(
                            message: message,
                            isMe: message.senderId ==
                                ref.read(currentUserProvider).value?.id,
                          ),
                        ],
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
            onSendFile: _handleSendFile,
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

  Future<void> _handleSendImage(PlatformFile file) async {
    try {
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

  Future<void> _handleSendFile(PlatformFile file) async {
    try {
      final url = await ref.read(chatRepositoryProvider).uploadChatImage(file);
      final extension = file.extension?.toLowerCase() ?? '';
      final type = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)
          ? 'image'
          : 'file';

      await ref.read(chatRepositoryProvider).sendMessage(
            jobId: widget.chatId,
            text: file.name, // Filename as text for file type
            type: type,
            attachmentUrl: url,
          );
    } on DioException catch (error) {
      if (!mounted) return;
      _showSnackBar(resolveDioErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Gagal menghantar fail.');
    }
  }

  bool _isFirstMessageOfDay(List<ChatMessage> messages, int index) {
    if (index == 0) return true;
    final current = messages[index];
    final previous =
        messages[index - 1]; // Previous in list is chronologically older? Wait.
    // List is likely sorted Chronologically if index 0 is oldest?
    // Repo sorts: a.timestamp.compareTo(b.timestamp).
    // So 0 is Oldest.
    // Check Date of current vs message BEFORE it (index - 1).

    final prevDate = DateTime(previous.timestamp.year, previous.timestamp.month,
        previous.timestamp.day);
    final currDate = DateTime(
        current.timestamp.year, current.timestamp.month, current.timestamp.day);
    return prevDate != currDate;
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

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orangeAccent;
      case 'IN_PROGRESS':
        return Colors.lightBlueAccent;
      case 'COMPLETED':
        return Colors.lightGreenAccent.shade400;
      case 'CANCELLED':
      case 'REJECTED':
      case 'DISPUTED':
        return Colors.redAccent;
      default:
        return Colors.white24;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.timestamp});
  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);

    String label;
    if (date == today) {
      label = 'Hari Ini';
    } else if (date == today.subtract(const Duration(days: 1))) {
      label = 'Semalam';
    } else {
      label = DateFormat('dd/MM/yyyy').format(timestamp);
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFD1E4E8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});
  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFFE3F2FD) // Light Blue for me
              : Colors.white, // White for others
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Image message
            if (message.type == 'image' && message.attachmentUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 250,
                      maxHeight: 250,
                    ),
                    child: Image.network(
                      UrlUtils.resolveImageUrl(message.attachmentUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 150,
                          width: 200,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ),
              ),
            if (message.type == 'file' && message.attachmentUrl != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insert_drive_file, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(message.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black87))),
                  ],
                ),
              ),
            if (message.type == 'text' ||
                (message.text.isNotEmpty && message.type != 'file'))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.text,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  textAlign: TextAlign.left,
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('hh:mm a').format(message.timestamp),
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all,
                      size: 16, color: Colors.blue), // Blue ticks
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageComposer extends StatefulWidget {
  const _MessageComposer({
    required this.controller,
    required this.onSendText,
    required this.onSendImage,
    required this.onSendFile,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSendText;
  final ValueChanged<PlatformFile> onSendImage;
  final ValueChanged<PlatformFile> onSendFile;
  final bool enabled;

  @override
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  // ... (keep build method)
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: Colors.white,
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.add_circle,
                  color: Color(0xFF1976D2)), // Primary Blue
              onPressed: widget.enabled ? _showAttachmentMenu : null,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: widget.controller,
                  readOnly: !widget.enabled,
                  maxLines: null, // Allow multiline
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: 'Mesej',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: widget.enabled ? widget.onSendText : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF1976D2),
              radius: 22,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: widget.enabled
                    ? () => widget.onSendText(widget.controller.text)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 150,
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _AttachmentOption(
              icon: Icons.image,
              color: Colors.purple,
              label: 'Galeri',
              onTap: () {
                Navigator.pop(context);
                _pickFile(FileType.image);
              },
            ),
            _AttachmentOption(
              icon: Icons.camera_alt,
              color: Colors.pink,
              label: 'Kamera',
              onTap: () {
                Navigator.pop(context);
                _pickFile(FileType.image);
              },
            ),
            _AttachmentOption(
              icon: Icons.insert_drive_file,
              color: Colors.indigo,
              label: 'Dokumen',
              onTap: () {
                Navigator.pop(context);
                _pickFile(FileType.any);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile(FileType type) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowMultiple: false,
      withData: kIsWeb,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      if (type == FileType.image) {
        widget.onSendImage(file);
      } else {
        widget.onSendFile(file);
      }
    }
  }
}

class _AttachmentOption extends StatelessWidget {
  const _AttachmentOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
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
