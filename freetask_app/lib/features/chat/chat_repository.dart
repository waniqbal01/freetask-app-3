import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_utils.dart';
import '../../services/http_client.dart';
import '../../services/token_storage.dart';
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
  ChatRepository({TokenStorage? tokenStorage, Dio? dio})
      : _tokenStorage = tokenStorage ?? createTokenStorage(),
        _dio = dio ?? HttpClient(tokenStorage: tokenStorage).dio;

  final TokenStorage _tokenStorage;
  final Dio _dio;
  List<ChatThread> _threads = <ChatThread>[];
  final Map<String, List<ChatMessage>> _messages = <String, List<ChatMessage>>{};
  final Map<String, StreamController<List<ChatMessage>>> _controllers =
      <String, StreamController<List<ChatMessage>>>{};

  Future<List<ChatThread>> fetchThreads() async {
    return _guardRequest(() async {
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
    });
  }

  Stream<List<ChatMessage>> streamMessages(String chatId) {
    final controller = _controllers.putIfAbsent(
      chatId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    unawaited(
      _loadMessages(chatId).catchError(
        (Object error, StackTrace stackTrace) {
          controller.addError(error, stackTrace);
        },
      ),
    );
    controller.add(List<ChatMessage>.unmodifiable(_messages[chatId] ?? <ChatMessage>[]));
    return controller.stream;
  }

  Future<void> sendText({
    required String chatId,
    required String text,
  }) async {
    await _guardRequest(() async {
      await _dio.post<void>(
        '/chats/$chatId/messages',
        data: <String, dynamic>{
          'content': text,
        },
        options: await _authorizedOptions(),
      );
      await _loadMessages(chatId);
    });
  }

  Future<void> sendImage({
    required String chatId,
    required String imageUrl,
  }) async {
    await _guardRequest(() async {
      await _dio.post<void>(
        '/chats/$chatId/messages',
        data: <String, dynamic>{
          'content': imageUrl,
        },
        options: await _authorizedOptions(),
      );
      await _loadMessages(chatId);
    });
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
  }

  Future<void> _loadMessages(String chatId) async {
    await _guardRequest(() async {
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
    });
  }

  Future<Options> _authorizedOptions() async {
    final token = await _tokenStorage.read(AuthRepository.tokenStorageKey);
    if (token == null || token.isEmpty) {
      throw StateError('Token tidak ditemui. Sila log masuk semula.');
    }
    return Options(headers: <String, String>{'Authorization': 'Bearer $token'});
  }

  Future<T> _guardRequest<T>(Future<T> Function() runner) async {
    try {
      return await runner();
    } on DioException catch (error) {
      final mapped = mapDioError(error);
      if (mapped.isUnauthorized) {
        await authRepository.logout();
      }
      throw mapped;
    }
  }
}
