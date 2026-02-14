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

final chatRepositoryProvider = Provider<ChatRepository>((Ref ref) {
  final repository = ChatRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final chatThreadsProvider = FutureProvider<List<ChatThread>>((Ref ref) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.fetchThreads();
});

final chatThreadsProviderWithQuery =
    FutureProvider.family<List<ChatThread>, ({String? limit, String? offset})>(
        (Ref ref, query) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.fetchThreads(limit: query.limit, offset: query.offset);
});

final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>(
    (Ref ref, String conversationId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.streamMessages(conversationId);
});

class ChatRepository {
  ChatRepository({AppStorage? storage, Dio? dio})
      : _storage = storage ?? appStorage,
        _dio = dio ?? HttpClient().dio {
    _logoutSubscription = authRepository.onLogout.listen((_) => dispose());
  }

  final AppStorage _storage;
  final Dio _dio;
  StreamSubscription? _logoutSubscription;
  List<ChatThread> _threads = <ChatThread>[];
  final Map<String, List<ChatMessage>> _messages =
      <String, List<ChatMessage>>{};
  final Map<String, StreamController<List<ChatMessage>>> _controllers =
      <String, StreamController<List<ChatMessage>>>{};
  final Map<String, Timer> _pollingTimers = <String, Timer>{};
  static const int _pageSize = 50;
  final Map<String, bool> _hasMore = <String, bool>{};
  final Map<String, bool> _isLoadingMore = <String, bool>{};
  final Map<String, bool> _isInitialLoading = <String, bool>{};

  // Circuit breaker stream
  final _circuitOpenController = StreamController<bool>.broadcast();
  Stream<bool> get circuitOpenStream => _circuitOpenController.stream;

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
      _threads = List<ChatThread>.unmodifiable(threads);
      return _threads;
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
      return ChatThread.fromJson(data);
    } on DioException catch (error) {
      await _handleError(error);
      rethrow;
    }
  }

  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    final controller = _controllers.putIfAbsent(
      conversationId,
      () => StreamController<List<ChatMessage>>.broadcast(
        onListen: () => _startPolling(conversationId),
        onCancel: () => _stopPolling(conversationId),
      ),
    );
    _isInitialLoading[conversationId] = true;
    unawaited(
      _loadMessages(conversationId)
          .catchError((Object error, StackTrace stackTrace) {
        _notifyStreamError(error);
        controller.addError(error, stackTrace);
      }),
    );
    _emit(conversationId);
    return controller.stream;
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
      await _retryRequest(() async {
        await _dio.post<void>(
          '/chats/$conversationId/messages',
          data: <String, dynamic>{
            'content': trimmed,
            'type': type,
            'attachmentUrl': attachmentUrl,
          },
          options: await _authorizedOptions(),
        );
      });
      await _loadMessages(conversationId, mergeExisting: true);
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
    for (final controller in _controllers.values) {
      controller.close();
    }
    for (final timer in _pollingTimers.values) {
      timer.cancel();
    }
    _pollingTimers.clear();
    _circuitOpenController.close();
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
      final response = await _retryRequest(() async {
        return _dio.get<List<dynamic>>(
          '/chats/$conversationId/messages',
          queryParameters: _buildPagination(
            limit: _pageSize.toString(),
            offset: append ? current.length.toString() : '0',
          ),
          options: await _authorizedOptions(),
        );
      });
      final data = response.data ?? <dynamic>[];
      final messages = data
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(growable: false)
        ..sort((ChatMessage a, ChatMessage b) =>
            a.timestamp.compareTo(b.timestamp));
      List<ChatMessage> merged;
      if (append) {
        merged = _dedupeMessages(<ChatMessage>[...messages, ...current]);
      } else if (mergeExisting && current.isNotEmpty) {
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
    final controller = _controllers.putIfAbsent(
      conversationId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
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

  // Circuit breaker state
  final List<DateTime> _recentFailures = <DateTime>[];
  DateTime? _circuitBreakerCooldownUntil;

  bool _isCircuitBreakerOpen() {
    // Remove old failures (older than 60s)
    final cutoff = DateTime.now().subtract(const Duration(seconds: 60));
    _recentFailures.removeWhere((timestamp) => timestamp.isBefore(cutoff));

    // Check if in cooldown
    if (_circuitBreakerCooldownUntil != null) {
      if (DateTime.now().isBefore(_circuitBreakerCooldownUntil!)) {
        _circuitOpenController.add(true);
        return true;
      }
      // Cooldown expired, reset
      _circuitBreakerCooldownUntil = null;
      _recentFailures.clear();
      _circuitOpenController.add(false);
    }

    // If >10 failures in last 60s, activate cooldown
    if (_recentFailures.length >= 10) {
      _circuitBreakerCooldownUntil =
          DateTime.now().add(const Duration(minutes: 5));
      _circuitOpenController.add(true);
      notificationService.messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Service unavailable. Too many failures. Please try again in 5 minutes.',
          ),
          duration: Duration(seconds: 10),
        ),
      );
      return true;
    }

    _circuitOpenController.add(false);
    return false;
  }

  void _recordFailure() {
    _recentFailures.add(DateTime.now());
  }

  Future<T> _retryRequest<T>(Future<T> Function() action) async {
    // Check circuit breaker first
    if (_isCircuitBreakerOpen()) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        message: 'Circuit breaker open: service unavailable',
      );
    }

    DioException? lastError;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await action();
        // Success - clear recent failures on success
        if (_recentFailures.isNotEmpty) {
          _recentFailures.clear();
        }
        return result;
      } on DioException catch (error) {
        lastError = error;
        _recordFailure();
        if (attempt == 2) {
          rethrow;
        }
        await Future<void>.delayed(
            Duration(milliseconds: 200 * (1 << attempt)));
      }
    }
    throw lastError ?? Exception('Permintaan gagal selepas percubaan semula.');
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

  void _startPolling(String conversationId) {
    if (_pollingTimers.containsKey(conversationId)) return;

    // Initial load
    _loadMessages(conversationId);

    // Poll every 3 seconds
    _pollingTimers[conversationId] =
        Timer.periodic(const Duration(seconds: 3), (_) {
      _loadMessages(conversationId);
    });
  }

  void _stopPolling(String conversationId) {
    _pollingTimers[conversationId]?.cancel();
    _pollingTimers.remove(conversationId);
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
