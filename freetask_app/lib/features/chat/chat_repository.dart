import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
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

final chatRepositoryProvider = Provider<ChatRepository>((Ref ref) {
  final repository = ChatRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final chatThreadsProvider = FutureProvider<List<ChatThread>>((Ref ref) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.fetchThreads();
});

final chatThreadsProviderWithQuery = FutureProvider.family<List<ChatThread>, ({String? limit, String? offset})>((Ref ref, query) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.fetchThreads(limit: query.limit, offset: query.offset);
});

final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>(
    (Ref ref, String jobId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.streamMessages(jobId);
});

class ChatRepository {
  ChatRepository({AppStorage? storage, Dio? dio})
      : _storage = storage ?? appStorage,
        _dio = dio ?? HttpClient().dio;

  final AppStorage _storage;
  final Dio _dio;
  List<ChatThread> _threads = <ChatThread>[];
  final Map<String, List<ChatMessage>> _messages = <String, List<ChatMessage>>{};
  final Map<String, StreamController<List<ChatMessage>>> _controllers =
      <String, StreamController<List<ChatMessage>>>{};

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

  Stream<List<ChatMessage>> streamMessages(String jobId) {
    final controller = _controllers.putIfAbsent(
      jobId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    unawaited(
      _loadMessages(jobId).catchError((Object error, StackTrace stackTrace) {
        _notifyStreamError(error);
        controller.addError(error, stackTrace);
      }),
    );
    controller
        .add(List<ChatMessage>.unmodifiable(_messages[jobId] ?? <ChatMessage>[]));
    return controller.stream;
  }

  Future<void> sendText({
    required String jobId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _notifyStreamError('Mesej kosong tidak dihantar.');
      return;
    }
    try {
      await _retryRequest(() async {
        await _dio.post<void>(
          '/chats/$jobId/messages',
          data: <String, dynamic>{
            'content': trimmed,
          },
          options: await _authorizedOptions(),
        );
      });
      await _loadMessages(jobId);
    } on DioException catch (error) {
      await _handleError(error);
      rethrow;
    }
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
  }

  Future<void> reloadMessages(String jobId) {
    return _loadMessages(jobId);
  }

  Future<void> _loadMessages(String jobId) async {
    try {
      final response = await _retryRequest(() async {
        return _dio.get<List<dynamic>>(
          '/chats/$jobId/messages',
          options: await _authorizedOptions(),
        );
      });
      final data = response.data ?? <dynamic>[];
      final messages = data
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(growable: false)
        ..sort((ChatMessage a, ChatMessage b) => a.timestamp.compareTo(b.timestamp));
      _messages[jobId] = messages;
      final controller = _controllers.putIfAbsent(
        jobId,
        () => StreamController<List<ChatMessage>>.broadcast(),
      );
      controller.add(List<ChatMessage>.unmodifiable(messages));
    } on DioException catch (error) {
      await _handleError(error);
      _notifyStreamError('Rangkaian terputus. Tap untuk cuba lagi.');
      rethrow;
    }
  }

  Map<String, dynamic> _buildPagination({String? limit, String? offset}) {
    final parsedLimit = parsePositiveInt(limit);
    final parsedOffset = parsePositiveInt(offset);
    final query = <String, dynamic>{};
    if (parsedLimit != null) {
      query['limit'] = min(parsedLimit, 50);
    }
    if (parsedOffset != null) {
      query['offset'] = parsedOffset;
    }
    return query;
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
        return true;
      }
      // Cooldown expired, reset
      _circuitBreakerCooldownUntil = null;
      _recentFailures.clear();
    }

    // If >10 failures in last 60s, activate cooldown
    if (_recentFailures.length >= 10) {
      _circuitBreakerCooldownUntil =
          DateTime.now().add(const Duration(minutes: 5));
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
        await Future<void>.delayed(Duration(milliseconds: 200 * (1 << attempt)));
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
