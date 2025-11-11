import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_models.dart';

final chatRepositoryProvider = Provider<ChatRepository>((Ref ref) {
  final repository = ChatRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final chatThreadsProvider = Provider<List<ChatThread>>((Ref ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.chatThreads;
});

final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>(
    (Ref ref, String chatId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.streamMessages(chatId);
});

class ChatRepository {
  ChatRepository();

  final List<ChatThread> _threads = <ChatThread>[
    const ChatThread(
      id: 'chat-1',
      jobTitle: 'Pembersihan Rumah',
      participantName: 'Ali',
    ),
    const ChatThread(
      id: 'chat-2',
      jobTitle: 'Servis Aircond',
      participantName: 'Siti',
    ),
  ];

  final Map<String, List<ChatMessage>> _messages = <String, List<ChatMessage>>{};
  final Map<String, StreamController<List<ChatMessage>>> _controllers =
      <String, StreamController<List<ChatMessage>>>{};

  List<ChatThread> get chatThreads => List<ChatThread>.unmodifiable(_threads);

  Stream<List<ChatMessage>> streamMessages(String chatId) {
    final controller = _controllers.putIfAbsent(
      chatId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    controller.add(List<ChatMessage>.unmodifiable(_messages[chatId] ?? <ChatMessage>[]));
    return controller.stream;
  }

  Future<void> sendText({
    required String chatId,
    required String sender,
    required String text,
  }) async {
    final message = ChatMessage(
      id: _generateMessageId(),
      sender: sender,
      text: text,
      timestamp: DateTime.now(),
    );
    _addMessage(chatId, message);
  }

  Future<void> sendImage({
    required String chatId,
    required String sender,
    required String imagePath,
  }) async {
    final message = ChatMessage(
      id: _generateMessageId(),
      sender: sender,
      imagePath: imagePath,
      timestamp: DateTime.now(),
    );
    _addMessage(chatId, message);
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
  }

  void _addMessage(String chatId, ChatMessage message) {
    final messages = _messages.putIfAbsent(chatId, () => <ChatMessage>[]);
    messages.add(message);
    final controller = _controllers.putIfAbsent(
      chatId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    controller.add(List<ChatMessage>.unmodifiable(messages));
  }

  String _generateMessageId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
