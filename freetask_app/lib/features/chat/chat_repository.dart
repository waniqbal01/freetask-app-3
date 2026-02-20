import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/utils/api_error_handler.dart';
import '../../core/router.dart';
import '../../core/storage/storage.dart';
import '../../core/utils/query_utils.dart';
import '../../services/http_client.dart';
import '../auth/auth_repository.dart';
import 'chat_models.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

import '../../core/websocket/socket_service.dart';

final chatRepositoryProvider = Provider.autoDispose<ChatRepository>((Ref ref) {
  final repository = ChatRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final chatThreadsProvider =
    StreamProvider.autoDispose<List<ChatThread>>((Ref ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.threadsStream;
});

final chatThreadsProviderWithQuery = StreamProvider.autoDispose
    .family<List<ChatThread>, ({String? limit, String? offset})>(
        (Ref ref, query) {
  final repository = ref.watch(chatRepositoryProvider);
  // If requesting the main list (first page), return the live stream
  if (query.offset == null || query.offset == '0' || query.offset == '') {
    // Ensure initial fetch is triggered if stream is empty/stale?
    // The repository constructor doesn't auto-fetch.
    // But StreamProvider will listen to current value.
    // We should trigger a fetch if needed.
    // Pattern: return stream, but side-effect fetch?
    // Or repository.threadsStream should start with a fetch?
    // Let's rely on repository.fetchThreads() to be called or the stream to emit.
    // Better: return Valid stream that starts with a fetch.
    return repository.threadsStream;
  }
  // For other pages, just fetch once as a stream (no live updates to page 2 for now to avoid complexity)
  return Stream.fromFuture(
      repository.fetchThreads(limit: query.limit, offset: query.offset));
});

final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((Ref ref, String conversationId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.streamMessages(conversationId);
});

class ChatRepository {
  ChatRepository({AppStorage? storage, Dio? dio})
      : _storage = storage ?? appStorage,
        _dio = dio ?? HttpClient().dio {
    _logoutSubscription = authRepository.onLogout.listen((_) => dispose());
    _socketSubscription =
        SocketService.instance.newMessageStream.listen(_onNewMessage);
    // Initial fetch of threads on startup? Or lazy?
    // Let's lazy fetch when threadsStream is listened to?
    // StreamController.broadcast onListen can trigger fetch.
  }

  final AppStorage _storage;
  final Dio _dio;
  StreamSubscription? _logoutSubscription;
  StreamSubscription? _socketSubscription;

  /// Tracks which conversation is currently open on screen.
  /// Used to suppress unread badge increment and in-app notifications
  /// when user is actively viewing that chat.
  String? _activeConversationId;

  List<ChatThread> _threads = <ChatThread>[];
  final Map<String, List<ChatMessage>> _messages =
      <String, List<ChatMessage>>{};
  final Map<String, StreamController<List<ChatMessage>>> _controllers =
      <String, StreamController<List<ChatMessage>>>{};
  final _threadsController = StreamController<List<ChatThread>>.broadcast();

  Stream<List<ChatThread>> get threadsStream {
    if (_threads.isEmpty) {
      fetchThreads(); // Trigger initial fetch
    }
    return _threadsController.stream;
  }

  static const int _pageSize = 50;
  final Map<String, bool> _hasMore = <String, bool>{};
  final Map<String, bool> _isLoadingMore = <String, bool>{};
  final Map<String, bool> _isInitialLoading = <String, bool>{};

  bool hasMore(String conversationId) => _hasMore[conversationId] ?? false;
  bool isLoadingMore(String conversationId) =>
      _isLoadingMore[conversationId] ?? false;
  bool isInitialLoading(String conversationId) =>
      _isInitialLoading[conversationId] ?? false;

  Future<List<ChatThread>> fetchThreads({String? limit, String? offset}) async {
    final paginationQuery = _buildPagination(limit: limit, offset: offset);
    try {
      final response = await _dio.get<List<dynamic>>(
        '/chats',
        queryParameters: paginationQuery.isEmpty ? null : paginationQuery,
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <dynamic>[];
      final threads = data
          .whereType<Map<String, dynamic>>()
          .map(ChatThread.fromJson)
          .toList(growable: true);
      threads.sort(
        (ChatThread a, ChatThread b) =>
            (b.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          a.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );

      // If fetching first page, update cache
      if (offset == null || offset == '0' || offset == '') {
        _threads =
            threads; // Should be unmodifiable? We modify it in _onNewMessage
        // So keep it modifiable
        _threadsController.add(List<ChatThread>.unmodifiable(_threads));
      }

      return threads;
    } on DioException catch (error) {
      await _handleError(error);
      rethrow;
    }
  }

  Future<ChatThread> createConversation({required String otherUserId}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/chats/conversation',
        data: {'otherUserId': otherUserId},
        options: await _authorizedOptions(),
      );

      final data = response.data;
      if (data == null) {
        throw Exception('Gagal memulakan perbualan.');
      }
      final thread = ChatThread.fromJson(data);
      // Optimistically add to top of threads
      _updateThread(thread);
      return thread;
    } on DioException catch (error) {
      await _handleError(error);
      rethrow;
    }
  }

  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    final controller = _controllers.putIfAbsent(
      conversationId,
      () => StreamController<List<ChatMessage>>.broadcast(
        onListen: () => _onListenToConversation(conversationId),
        onCancel: () => _onCancelConversation(conversationId),
      ),
    );
    // Return existing data immediately if available
    if (_messages.containsKey(conversationId)) {
      controller
          .add(List<ChatMessage>.unmodifiable(_messages[conversationId]!));
    }
    return controller.stream;
  }

  Future<void> _onListenToConversation(String conversationId) async {
    _isInitialLoading[conversationId] = true;

    // Connect to specific room
    // Ensure socket is connected
    final baseUrl = await HttpClient().currentBaseUrl();
    await SocketService.instance.connect(baseUrl);
    SocketService.instance.joinRoom(conversationId);

    // Initial load via HTTP
    await _loadMessages(conversationId)
        .catchError((Object error, StackTrace stackTrace) {
      _notifyStreamError(error);
      // Don't close controller on error, just notify. User can retry.
    });
  }

  /// Call when user navigates INTO a chat room.
  /// Marks the conversation as read immediately.
  void enterChat(String conversationId) {
    _activeConversationId = conversationId;
    // Mark all messages as read after first frame is rendered
    markChatAsRead(conversationId);
  }

  /// Call when user navigates OUT of a chat room.
  void leaveChat(String conversationId) {
    if (_activeConversationId == conversationId) {
      _activeConversationId = null;
    }
  }

  /// Emit socket event to mark all messages in a conversation as read.
  /// Also resets the local unread count so the badge disappears.
  void markChatAsRead(String conversationId) {
    final conversationIntId = int.tryParse(conversationId);
    if (conversationIntId != null) {
      SocketService.instance.emit('mark_chat_read', {
        'conversationId': conversationIntId,
      });
    }
    // Reset unread count locally so badge clears immediately
    final index = _threads.indexWhere((t) => t.id == conversationId);
    if (index != -1) {
      final updated = _threads[index].copyWith(unreadCount: 0);
      _threads[index] = updated;
      _threadsController.add(List<ChatThread>.unmodifiable(_threads));
    }
  }

  void _onCancelConversation(String conversationId) {
    SocketService.instance.leaveRoom(conversationId);
    // We don't remove the controller immediately as it might be re-listened to
    // or we might want to keep cache. But to correspond with polling logic removal:
    // We can keep it or dispose it. The provider is autoDispose? No.
    // So let's leave it.
  }

  void _onNewMessage(ChatMessage message) {
    // Update messages for conversation if active
    final conversationId = message.jobId;
    if (conversationId.isNotEmpty) {
      final currentMessages = _messages[conversationId] ?? <ChatMessage>[];

      // Check if message already exists (dedup)
      if (!currentMessages.any((m) => m.id == message.id)) {
        final updatedMessages = <ChatMessage>[message, ...currentMessages];
        updatedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _messages[conversationId] = updatedMessages;
        _emit(conversationId);
      }

      // Update threads list (shows red badge in chat list)
      _updateThreadForMessage(message);
    }
  }

  void _updateThreadForMessage(ChatMessage message) {
    final conversationId = message.jobId;
    final index = _threads.indexWhere((t) => t.id == conversationId);

    ChatThread? thread;
    if (index != -1) {
      thread = _threads[index];

      final myId = authRepository.currentUser?.id;
      final isMe = myId != null && myId.toString() == message.senderId;

      // Increment unread count only if:
      // 1. Message is from other person (not me)
      // 2. User is NOT currently viewing this specific chat
      int newUnread = thread.unreadCount;
      final isViewingThisChat = _activeConversationId == conversationId;
      if (!isMe && !isViewingThisChat) {
        newUnread += 1;
        // Auto-mark as read if user is in the chat
      } else if (!isMe && isViewingThisChat) {
        // User is viewing: mark as read immediately
        markChatAsRead(conversationId);
      }

      thread = thread.copyWith(
        lastMessage:
            message.type == 'text' ? message.text : '[${message.type}]',
        lastAt: message.timestamp,
        unreadCount: newUnread,
      );

      _threads.removeAt(index);
    } else {
      // Thread not in list, skip silently
      return;
    }

    _threads.insert(0, thread);
    _threadsController.add(List<ChatThread>.unmodifiable(_threads));
  }

  void _updateThread(ChatThread thread) {
    final index = _threads.indexWhere((t) => t.id == thread.id);
    if (index != -1) {
      _threads.removeAt(index);
    }
    _threads.insert(0, thread);
    _threadsController.add(List<ChatThread>.unmodifiable(_threads));
  }

  Future<void> sendMessage({
    required String conversationId,
    required String text,
    String? attachmentUrl,
    String type = 'text',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && attachmentUrl == null) {
      _notifyStreamError('Mesej kosong tidak dihantar.');
      return;
    }
    try {
      // Optimistic update could be added here, but for now we rely on socket event
      // coming back from server after creation.
      await _dio.post<void>(
        '/chats/$conversationId/messages',
        data: <String, dynamic>{
          'content': trimmed,
          'type': type, // 'text', 'image', 'file'
          'attachmentUrl': attachmentUrl,
        },
        options: await _authorizedOptions(),
      );

      // No need to _loadMessages manually if socket works.
      // But purely for safety/redundancy or if socket is slow/disconnected:
      // We can fetch. But socket should handle it.
      // Let's rely on socket to avoid duplicates or race conditions if possible.
      // However, if socket is disconnected, we won't get the update.
      // So checking socket status might be good.
      if (!SocketService.instance.isConnected) {
        await _loadMessages(conversationId, mergeExisting: true);
      }
    } on DioException catch (error) {
      await _handleError(error);
      rethrow;
    }
  }

  Future<String> uploadChatImage(PlatformFile file) async {
    try {
      MultipartFile multipartFile;
      final mimeType = lookupMimeType(file.name);
      final contentType = mimeType != null ? MediaType.parse(mimeType) : null;

      if (kIsWeb) {
        if (file.bytes == null) {
          throw StateError('File bytes are missing for Web upload');
        }
        multipartFile = MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
          contentType: contentType,
        );
      } else {
        if (file.path == null) {
          throw StateError('File path is missing for Native upload');
        }
        multipartFile = await MultipartFile.fromFile(
          file.path!,
          filename: file.name,
          contentType: contentType,
        );
      }

      final formData = FormData.fromMap({
        'file': multipartFile,
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/uploads',
        data: formData,
        options: await _authorizedOptions(),
      );

      final data = response.data;
      if (data != null && data['url'] != null) {
        return data['url'] as String;
      }
      throw StateError('Upload failed: No URL returned');
    } on DioException catch (error) {
      await _handleError(error);
      rethrow;
    }
  }

  void dispose() {
    _logoutSubscription?.cancel();
    _socketSubscription?.cancel();

    for (final controller in _controllers.values) {
      controller.close();
    }
    SocketService.instance.disconnect();

    _controllers.clear();
    _threadsController.close();
  }

  Future<void> reloadMessages(String conversationId) {
    return _loadMessages(conversationId);
  }

  Future<void> loadMoreMessages(String conversationId) {
    return _loadMessages(conversationId, append: true, mergeExisting: true);
  }

  Future<void> _loadMessages(String conversationId,
      {bool append = false, bool mergeExisting = true}) async {
    final current = _messages[conversationId] ?? <ChatMessage>[];
    if (append && (_isLoadingMore[conversationId] ?? false)) {
      return;
    }

    if (!append && current.isEmpty) {
      _isInitialLoading[conversationId] = true;
    }
    if (append) {
      _isLoadingMore[conversationId] = true;
    }
    _emit(conversationId);

    try {
      final response = await _dio.get<List<dynamic>>(
        '/chats/$conversationId/messages',
        queryParameters: _buildPagination(
          limit: _pageSize.toString(),
          offset: append ? current.length.toString() : '0',
        ),
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <dynamic>[];
      final messages = data
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(growable: false)
        ..sort((ChatMessage a, ChatMessage b) =>
            a.timestamp.compareTo(b.timestamp));

      List<ChatMessage> merged;
      if (append) {
        // Appending means fetching OLDER messages since we are scrolling up in a reverse list?
        // Wait. UI: ListView with reverse: false?
        // In ChatRoomScreen: ListView.builder (default reverse: false).
        // And it renders top-down.
        // ScrollToBottomFAB implies bottom is newest.
        // So fetching MORE usually implies fetching older messages to prepend?
        // Let's check logic:
        // offset 0 is newest/latest page?
        // Backend `listMessages` in `ChatsService.ts`:
        // orderBy: { createdAt: 'desc' }, take, skip... returned reversed.
        // So offset 0 returns {latest 50 messages, ordered oldest to newest}.
        // Offset 50 returns {next 50 older messages, ordered oldest to newest}.
        // So 'append' = true means we fetched OLDER messages.
        // They should be PREPENDED to the current list of newer messages?
        // If current list is [Oldest -> Newest].
        // And we fetch OlderChunk [Oldest -> Older].
        // Result should be [OlderChunk, Current].

        // original logic:
        /*
        if (append) {
           merged = _dedupeMessages(<ChatMessage>[...messages, ...current]);
        }
        */
        // If messages is OlderChunk and current is NewerChunk.
        // [...messages, ...current] results in [Older, Newer]. Correct.
        merged = _dedupeMessages(<ChatMessage>[...messages, ...current]);
      } else if (mergeExisting && current.isNotEmpty) {
        // Reloading/Fetching latest.
        // fetched messages are latest.
        // current might have some old ones.
        // If we allow holes, it's complex.
        // But usually we just replace or merge if we are sure we are fetching from 0.
        // original logic:
        /*
         } else if (mergeExisting && current.isNotEmpty) {
            merged = _dedupeMessages(<ChatMessage>[...current, ...messages]);
         }
         */
        // If messages = Newest 50.
        // Current = [Oldest ... Newest].
        // [...current, ...messages] puts fetched messages AT END.
        // If they overlap, dedupe handles it.
        // This seems correct for adding new messages or refreshing latest key.
        merged = _dedupeMessages(<ChatMessage>[...current, ...messages]);
      } else {
        merged = messages;
      }

      _messages[conversationId] = merged;
      _hasMore[conversationId] = messages.length >= _pageSize;
      _emit(conversationId);
    } on DioException catch (error) {
      await _handleError(error);
      _notifyStreamError('Rangkaian terputus. Tap untuk cuba lagi.');
      rethrow;
    } finally {
      _isLoadingMore[conversationId] = false;
      _isInitialLoading[conversationId] = false;
    }
  }

  Map<String, dynamic> _buildPagination({String? limit, String? offset}) {
    final parsedLimit = parsePositiveInt(limit);
    final parsedOffset = parsePositiveInt(offset);
    final query = <String, dynamic>{};
    query['limit'] = min(parsedLimit ?? _pageSize, _pageSize);
    if (parsedOffset != null) {
      query['offset'] = parsedOffset;
    }
    return query;
  }

  void _emit(String conversationId) {
    if (!_controllers.containsKey(conversationId)) return;

    final controller = _controllers[conversationId]!;
    if (controller.isClosed) return;

    controller.add(List<ChatMessage>.unmodifiable(
        _messages[conversationId] ?? <ChatMessage>[]));
  }

  List<ChatMessage> _dedupeMessages(List<ChatMessage> messages) {
    final seen = <String>{};
    messages.sort(
        (ChatMessage a, ChatMessage b) => a.timestamp.compareTo(b.timestamp));
    return messages
        .where((ChatMessage message) => seen.add(message.id))
        .toList(growable: false);
  }

  Future<Options> _authorizedOptions() async {
    final token = await _storage.read(AuthRepository.tokenStorageKey);
    if (token == null || token.isEmpty) {
      await _handleMissingToken();
      return Options();
    }
    return Options(headers: <String, String>{'Authorization': 'Bearer $token'});
  }

  Future<void> _handleError(DioException error) async {
    await handleApiError(error);
  }

  Future<void> _handleMissingToken() async {
    notificationService.messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Sesi tamat. Sila log masuk semula.')),
    );
    await authRepository.logout();
    authRefreshNotifier.value = DateTime.now();
    appRouter.go('/login');
  }

  void _notifyStreamError(Object error) {
    final message = error is DioException
        ? resolveErrorMessage(error)
        : error.toString().isEmpty
            ? 'Ralat chat tidak diketahui.'
            : error.toString();
    notificationService.messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String resolveErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) {
        return msg;
      }
    }
    return error.message ?? 'Ralat chat.';
  }
}
