import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_utils.dart';
import '../../services/http_client.dart';
import '../../services/socket/chat_socket_service.dart';
import '../../services/token_storage.dart';
import '../auth/auth_repository.dart';
import 'chat_models.dart';

final chatRepositoryProvider = Provider<ChatRepository>((Ref ref) {
  final socketService = ref.watch(chatSocketServiceProvider);
  final repository = ChatRepository(chatSocketService: socketService);
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
  ChatRepository({
    TokenStorage? tokenStorage,
    Dio? dio,
    ChatSocketService? chatSocketService,
  })  : _tokenStorage = tokenStorage ?? createTokenStorage(),
        _dio = dio ?? HttpClient(tokenStorage: tokenStorage).dio,
        _socketService = chatSocketService ?? ChatSocketService(),
        _ownsSocketService = chatSocketService == null {
    _subscribeToSocket();
  }

  final TokenStorage _tokenStorage;
  final Dio _dio;
  final ChatSocketService _socketService;
  final bool _ownsSocketService;
  List<ChatThread> _threads = <ChatThread>[];
  final Map<String, List<ChatMessage>> _messages = <String, List<ChatMessage>>{};
  final Map<String, StreamController<List<ChatMessage>>> _controllers =
      <String, StreamController<List<ChatMessage>>>{};
  StreamSubscription<ChatSocketMessageEvent>? _socketSubscription;

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

  Future<List<ChatMessage>> refreshMessages(String chatId) {
    return _loadMessages(chatId);
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
    unawaited(
      _socketService.ensureConnected().catchError((Object error) {
        debugPrint('Socket connect error: $error');
      }),
    );
    unawaited(
      _socketService.joinJobRoom(chatId).catchError((Object error) {
        debugPrint('Join room failed: $error');
      }),
    );
    controller.add(List<ChatMessage>.unmodifiable(_messages[chatId] ?? <ChatMessage>[]));
    return controller.stream;
  }

  Future<void> sendText({
    required String chatId,
    required String text,
  }) async {
    try {
      await _socketService.sendMessage(chatId, text);
    } catch (_) {
      await _sendMessageHttp(chatId, text);
    }
  }

  Future<void> sendImage({
    required String chatId,
    required String imageUrl,
  }) async {
    try {
      await _socketService.sendMessage(chatId, imageUrl);
    } catch (_) {
      await _sendMessageHttp(chatId, imageUrl);
    }
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _socketSubscription?.cancel();
    if (_ownsSocketService) {
      _socketService.dispose();
    }
  }

  Future<List<ChatMessage>> _loadMessages(String chatId) async {
    List<ChatMessage> messages = <ChatMessage>[];
    await _guardRequest(() async {
      final response = await _dio.get<List<dynamic>>(
        '/chats/$chatId/messages',
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <dynamic>[];
      messages = data
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
    unawaited(
      _socketService.joinJobRoom(chatId).catchError((Object error) {
        debugPrint('Join room failed: $error');
      }),
    );
    return List<ChatMessage>.unmodifiable(messages);
  }

  Future<void> _sendMessageHttp(String chatId, String content) async {
    await _guardRequest(() async {
      await _dio.post<void>(
        '/chats/$chatId/messages',
        data: <String, dynamic>{'content': content},
        options: await _authorizedOptions(),
      );
      await _loadMessages(chatId);
    });
  }

  void _subscribeToSocket() {
    _socketSubscription ??=
        _socketService.messages.listen(_handleIncomingMessage);
  }

  void _handleIncomingMessage(ChatSocketMessageEvent event) {
    final existing = List<ChatMessage>.from(
      _messages[event.jobId] ?? <ChatMessage>[],
    )
      ..add(event.message)
      ..sort(
        (ChatMessage a, ChatMessage b) =>
            a.timestamp.compareTo(b.timestamp),
      );
    _messages[event.jobId] = existing;
    final controller = _controllers[event.jobId];
    if (controller != null && !controller.isClosed) {
      controller.add(List<ChatMessage>.unmodifiable(existing));
    }
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
