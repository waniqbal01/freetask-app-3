import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/router.dart';
import '../../core/storage/storage.dart';
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

  Future<List<ChatThread>> fetchThreads() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/chats',
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <dynamic>[];
      _threads = data
          .whereType<Map<String, dynamic>>()
          .map(ChatThread.fromJson)
          .toList(growable: false);
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
      _loadMessages(jobId).catchError((Object error, StackTrace _) {
        _notifyStreamError(error);
        controller.add(List<ChatMessage>.unmodifiable(_messages[jobId] ?? <ChatMessage>[]));
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
      await _dio.post<void>(
        '/chats/$jobId/messages',
        data: <String, dynamic>{
          'content': trimmed,
        },
        options: await _authorizedOptions(),
      );
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

  Future<void> _loadMessages(String jobId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/chats/$jobId/messages',
        options: await _authorizedOptions(),
      );
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
      _notifyStreamError(resolveErrorMessage(error));
    }
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
    if (error.response?.statusCode == 401) {
      await authRepository.logout();
    }
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
