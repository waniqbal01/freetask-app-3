import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/error_utils.dart';
import '../../core/utils/url_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../widgets/chat_widgets.dart';

import '../auth/auth_providers.dart';
import '../../core/websocket/socket_service.dart';
import '../../models/chat_enums.dart';
import 'chat_models.dart';
import 'chat_repository.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.chatId,
    this.initialThread,
  });

  final String chatId;
  final ChatThread? initialThread;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  PlatformFile? _selectedFile;
  FileType? _selectedFileType;
  bool _isUploading = false;

  // Real-time state
  bool _isOtherTyping = false;
  bool _isOtherOnline = false;
  DateTime? _otherLastSeen;
  ConnectionStatus _connectionStatus = SocketService.instance.currentStatus;

  // Replied message state
  ChatMessage? _replyingTo;

  // Typing detection
  bool _isTyping = false;
  Timer? _typingTimer;

  // Subscriptions
  StreamSubscription? _typingSub;
  StreamSubscription? _presenceSub;
  StreamSubscription? _connSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatRepositoryProvider).enterChat(widget.chatId);
    });

    _controller.addListener(_onTextChanged);

    final otherId = widget.initialThread?.participantId;

    _connSub = SocketService.instance.connectionStream.listen((status) {
      if (mounted) setState(() => _connectionStatus = status);
    });

    _typingSub = SocketService.instance.typingStream.listen((event) {
      if (event['data'] != null &&
          event['data']['conversationId'] == widget.chatId) {
        // Technically we should check if the user who typed is the other user,
        // but since this is a 1-on-1 chat room, we can infer it.
        final type = event['event'];
        if (mounted) {
          setState(() {
            _isOtherTyping = type == 'start';
          });
        }
      }
    });

    _presenceSub = SocketService.instance.presenceStream.listen((presence) {
      // If we don't know otherId, we can't reliably update presence.
      // But assuming presence is for the other user.
      if (otherId != null && presence.userId == otherId) {
        if (mounted) {
          setState(() {
            _isOtherOnline = presence.isOnline;
            _otherLastSeen = presence.lastSeen;
          });
        }
      }
    });
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      SocketService.instance.sendTyping(widget.chatId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        SocketService.instance.sendTyping(widget.chatId, false);
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _typingTimer?.cancel();
    _typingSub?.cancel();
    _presenceSub?.cancel();
    _connSub?.cancel();

    // Stop typing if leaving
    if (_isTyping) {
      SocketService.instance.sendTyping(widget.chatId, false);
    }

    ref.read(chatRepositoryProvider).leaveChat(widget.chatId);
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
            orElse: () =>
                widget.initialThread ??
                const ChatThread(
                  id: 'unknown',
                  title: 'Chat',
                  participantName: 'Pengguna',
                ),
          ),
          orElse: () =>
              widget.initialThread ??
              const ChatThread(
                id: 'unknown',
                title: 'Chat',
                participantName: 'Pengguna',
              ),
        );

    final currentUserAsync = ref.watch(currentUserProvider);
    final currentUserId = currentUserAsync.value?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB), // Light blue-grey background
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: InkWell(
          onTap: () {
            if (thread.participantId != null &&
                thread.participantId!.isNotEmpty) {
              context.push('/users/${thread.participantId}');
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 18,
                child: Text(
                    thread.participantName.isNotEmpty
                        ? thread.participantName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Color(0xFF2196F3), fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(thread.participantName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _getStatusColor(thread.status),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            thread.status.replaceAll('_', ' ').toLowerCase(),
                            style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3),
                          ),
                        ),
                        // Online status placeholder (will update via WebSocket)
                        const SizedBox(width: 8),
                        if (_isOtherOnline)
                          Text(
                            'online',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w400,
                            ),
                          )
                        else if (_otherLastSeen != null)
                          Text(
                            TimeUtils.formatLastSeen(_otherLastSeen!),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          ConnectionStatusBanner(status: _connectionStatus),
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
                return NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo.metrics.pixels >=
                            scrollInfo.metrics.maxScrollExtent - 200 &&
                        hasMore &&
                        !isLoadingMore) {
                      _handleLoadMore();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: () => ref
                        .read(chatRepositoryProvider)
                        .reloadMessages(widget.chatId),
                    child: ListView.builder(
                      reverse: true,
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: messages.length + (hasMore ? 1 : 0),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == messages.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final message = messages[index];
                        final bool isFirstMessageOfDay =
                            _isFirstMessageOfDay(messages, index);

                        ChatMessage? repliedMessage;
                        if (message.replyToId != null) {
                          try {
                            repliedMessage = messages
                                .firstWhere((m) => m.id == message.replyToId);
                          } catch (_) {}
                        }

                        return Column(
                          children: [
                            if (isFirstMessageOfDay)
                              _DateHeader(timestamp: message.timestamp),
                            Dismissible(
                              key: ValueKey(message.id),
                              direction: DismissDirection.startToEnd,
                              onDismissed: (_) {
                                // Since we don't actually want to dismiss it from the list
                                // we shouldn't use Dismissible this way directly for list modification,
                                // but we can use confirmDismiss to intercept the swipe and return false.
                              },
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  setState(() {
                                    _replyingTo = message;
                                  });
                                }
                                return false; // Never actually dismiss the item
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20.0),
                                color: Colors.transparent,
                                child: const CircleAvatar(
                                  backgroundColor: Colors.black12,
                                  radius: 18,
                                  child: Icon(Icons.reply,
                                      color: Colors.black54, size: 20),
                                ),
                              ),
                              child: _MessageBubble(
                                message: message,
                                repliedMessage: repliedMessage,
                                isMe: currentUserId != null &&
                                    message.senderId == currentUserId,
                                onReply: () {
                                  setState(() {
                                    _replyingTo = message;
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
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
          if (_isOtherTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      radius: 12,
                      child: Text(
                        thread.participantName.isNotEmpty
                            ? thread.participantName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const TypingAnimation(size: 6),
                    ),
                  ],
                ),
              ),
            ),
          if (_replyingTo != null)
            _ReplyPreview(
              message: _replyingTo!,
              onCancel: () {
                setState(() {
                  _replyingTo = null;
                });
              },
            ),
          _MessageComposer(
            controller: _controller,
            onSend: _handleSendMessage,
            onFileSelected: _handleFileSelection,
            selectedFile: _selectedFile,
            selectedFileType: _selectedFileType,
            onClearFile: _clearSelectedFile,
            isUploading: _isUploading,
            enabled: !hasMessageError && !_isUploading,
          ),
        ],
      ),
    );
  }

  Future<void> _handleSendMessage() async {
    if (_isUploading) return;

    final text = _controller.text.trim();
    if (text.isEmpty && _selectedFile == null) {
      return;
    }

    final replyToId = _replyingTo?.id;

    setState(() {
      _isUploading = true;
      _replyingTo = null;
    });

    try {
      String? attachmentUrl;
      String type = 'text';

      if (_selectedFile != null) {
        attachmentUrl = await ref
            .read(chatRepositoryProvider)
            .uploadChatImage(_selectedFile!);

        if (_selectedFileType == FileType.image) {
          type = 'image';
          // For images, we can send text as caption in the same message
          await ref.read(chatRepositoryProvider).sendMessage(
                conversationId: widget.chatId,
                text: text,
                type: type,
                attachmentUrl: attachmentUrl,
                replyToId: replyToId,
              );
        } else {
          type = 'file';
          // For files, use valid filename as text
          await ref.read(chatRepositoryProvider).sendMessage(
                conversationId: widget.chatId,
                text: _selectedFile!.name,
                type: type,
                attachmentUrl: attachmentUrl,
                replyToId: replyToId,
              );

          // If there's a caption for the file, send it as a separate message
          if (text.isNotEmpty) {
            await ref.read(chatRepositoryProvider).sendMessage(
                  conversationId: widget.chatId,
                  text: text,
                  type: 'text',
                );
          }
        }
      } else {
        // Text only message
        await ref.read(chatRepositoryProvider).sendMessage(
              conversationId: widget.chatId,
              text: text,
              type: 'text',
              replyToId: replyToId,
            );
      }

      _controller.clear();
      setState(() {
        _selectedFile = null;
        _selectedFileType = null;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      _showSnackBar(resolveDioErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Ralat menghantar mesej.');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _handleFileSelection(PlatformFile file, FileType type) {
    setState(() {
      _selectedFile = file;
      _selectedFileType = type;
    });
  }

  void _clearSelectedFile() {
    setState(() {
      _selectedFile = null;
      _selectedFileType = null;
    });
  }

  // ... (keep _isFirstMessageOfDay and other helpers)

  // ... inside build method, replace _MessageComposer instantiation
  // This needs to be done carefully as it's inside the build method.
  // I will use a separate replace call for the build method or include it here if the range allows.
  // The range 335-364 covers _handleSendImage and _handleSendFile.
  // I will just update these two methods first.

  bool _isFirstMessageOfDay(List<ChatMessage> messages, int index) {
    if (index == messages.length - 1) return true;
    final current = messages[index];
    final older = messages[index + 1];
    return TimeUtils.isDifferentDay(older.timestamp, current.timestamp);
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
    final label = TimeUtils.formatDateHeader(timestamp);

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
  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.onReply,
    this.repliedMessage,
  });

  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onReply;
  final ChatMessage? repliedMessage;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onDoubleTap: onReply,
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.reply, color: Colors.blue),
                    title: const Text('Balas (Reply)'),
                    onTap: () {
                      Navigator.pop(context);
                      if (onReply != null) onReply!();
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe
                ? const Color(0xFFDCF8C6) // WhatsApp-style light green for sent
                : Colors.white, // White for received
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (repliedMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color:
                        isMe ? const Color(0xFFC8E6C9) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: isMe
                            ? Colors.green.shade800
                            : Colors.indigo.shade400,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        repliedMessage!.senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isMe
                              ? Colors.green.shade800
                              : Colors.indigo.shade400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        repliedMessage!.type == 'image'
                            ? '📷 Gambar'
                            : (repliedMessage!.type == 'file'
                                ? '📄 Dokumen'
                                : repliedMessage!.text),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
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
                      child: GestureDetector(
                        onTap: () {
                          // Full-screen image viewer
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                backgroundColor: Colors.black,
                                appBar: AppBar(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                ),
                                body: Center(
                                  child: InteractiveViewer(
                                    clipBehavior: Clip.none,
                                    minScale: 1.0,
                                    maxScale: 4.0,
                                    child: Image.network(
                                      UrlUtils.resolveImageUrl(
                                          message.attachmentUrl),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
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
                ),
              if (message.type == 'file' && message.attachmentUrl != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color:
                        isMe ? const Color(0xFFC8E6C9) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insert_drive_file,
                          color: Colors.blueGrey),
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
                  padding: const EdgeInsets.only(bottom: 4),
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
                    TimeUtils.formatTime(message.timestamp),
                    style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.blue.shade800 : Colors.black54),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    MessageStatusIcon(status: message.status),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatefulWidget {
  const _MessageComposer({
    required this.controller,
    required this.onSend,
    required this.onFileSelected,
    this.selectedFile,
    this.selectedFileType,
    required this.onClearFile,
    this.isUploading = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final Function(PlatformFile, FileType) onFileSelected;
  final PlatformFile? selectedFile;
  final FileType? selectedFileType;
  final VoidCallback onClearFile;
  final bool isUploading;
  final bool enabled;

  @override
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _sendAndDismiss() {
    _focusNode.unfocus();
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: Colors.white,
        child: Column(
          children: [
            if (widget.selectedFile != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    if (widget.selectedFileType == FileType.image)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? Image.memory(
                                widget.selectedFile!.bytes!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(widget.selectedFile!.path!),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                      )
                    else
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.insert_drive_file,
                            color: Colors.indigo),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.selectedFile!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: widget.onClearFile,
                    ),
                  ],
                ),
              ),
            Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.add_circle,
                      color: Color(0xFF2196F3)), // FreeTask blue
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
                      focusNode: _focusNode,
                      readOnly: !widget.enabled,
                      maxLines: null, // Allow multiline
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Mesej',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted:
                          widget.enabled ? (_) => _sendAndDismiss() : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF2196F3), // FreeTask blue
                  radius: 22,
                  child: IconButton(
                    icon: widget.isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: widget.enabled ? _sendAndDismiss : null,
                  ),
                ),
              ],
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
      widget.onFileSelected(file, type);
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

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.message,
    required this.onCancel,
  });

  final ChatMessage message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          left: BorderSide(color: Theme.of(context).primaryColor, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.type == 'image'
                      ? '📷 Gambar'
                      : (message.type == 'file' ? '📄 Dokumen' : message.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.grey),
            onPressed: onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
