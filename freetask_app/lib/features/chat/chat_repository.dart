import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    (Ref ref, String chatId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.streamMessages(chatId);
});

class ChatRepository {
  ChatRepository({FlutterSecureStorage? secureStorage, Dio? dio})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _dio = dio ?? HttpClient().dio;

  final FlutterSecureStorage _secureStorage;
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

  Stream<List<ChatMessage>> streamMessages(String chatId) {
    final controller = _controllers.putIfAbsent(
      chatId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    unawaited(_loadMessages(chatId));
    controller.add(List<ChatMessage>.unmodifiable(_messages[chatId] ?? <ChatMessage>[]));
    return controller.stream;
  }

  Future<void> sendText({
    required String chatId,
    required String text,
  }) async {
    try {
      await _dio.post<void>(
        '/chats/$chatId/messages',
        data: <String, dynamic>{
          'content': text,
        },
        options: await _authorizedOptions(),
      );
      await _loadMessages(chatId);
    } on DioException catch (error) {
      await _handleError(error);
      rethrow;
    }
  }

  Future<void> sendImage({
    required String chatId,
    required String imageUrl,
  }) async {
    try {
      await _dio.post<void>(
        '/chats/$chatId/messages',
        data: <String, dynamic>{
          'content': imageUrl,
        },
        options: await _authorizedOptions(),
      );
      await _loadMessages(chatId);
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

  Future<void> _loadMessages(String chatId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/chats/$chatId/messages',
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <dynamic>[];
      final messages = data
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(growable: false)
        ..sort((ChatMessage a, ChatMessage b) => a.timestamp.compareTo(b.timestamp));
      _messages[chatId] = messages;
      final controller = _controllers.putIfAbsent(
        chatId,
        () => StreamController<List<ChatMessage>>.broadcast(),
      );
      controller.add(List<ChatMessage>.unmodifiable(messages));
    } on DioException catch (error) {
      await _handleError(error);
      rethrow;
    }
  }

  Future<Options> _authorizedOptions() async {
    final token = await _secureStorage.read(key: AuthRepository.tokenStorageKey);
    if (token == null || token.isEmpty) {
      throw StateError('Token tidak ditemui. Sila log masuk semula.');
    }
    return Options(headers: <String, String>{'Authorization': 'Bearer $token'});
  }

  Future<void> _handleError(DioException error) async {
    if (error.response?.statusCode == 401) {
      await authRepository.logout();
    }
  }
}
