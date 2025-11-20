import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/env.dart';
import '../../features/auth/auth_repository.dart';
import '../../features/chat/chat_models.dart';
import '../token_storage.dart';

class ChatSocketMessageEvent {
  ChatSocketMessageEvent({required this.jobId, required this.message});

  final String jobId;
  final ChatMessage message;
}

class JobSocketStatusEvent {
  const JobSocketStatusEvent({
    required this.jobId,
    required this.status,
    this.title,
    this.updatedAt,
    this.disputeReason,
  });

  final String jobId;
  final String status;
  final String? title;
  final DateTime? updatedAt;
  final String? disputeReason;
}

final chatSocketServiceProvider = Provider<ChatSocketService>((Ref ref) {
  final service = ChatSocketService();
  ref.onDispose(service.dispose);
  return service;
});

// Socket is best-effort only. HTTP remains the source of truth; UI must
// stay usable even if realtime connection fails.
class ChatSocketService {
  ChatSocketService({TokenStorage? tokenStorage, String? baseUrl})
      : _tokenStorage = tokenStorage ?? createTokenStorage(),
        _baseUrl = baseUrl ?? Env.apiBaseUrl;

  final TokenStorage _tokenStorage;
  final String _baseUrl;
  io.Socket? _socket;
  Completer<void>? _connectionCompleter;
  bool _isConnecting = false;

  final StreamController<ChatSocketMessageEvent> _messageController =
      StreamController<ChatSocketMessageEvent>.broadcast();
  final StreamController<JobSocketStatusEvent> _jobUpdateController =
      StreamController<JobSocketStatusEvent>.broadcast();
  final Set<String> _joinedJobs = <String>{};

  Stream<ChatSocketMessageEvent> get messages => _messageController.stream;
  Stream<JobSocketStatusEvent> get jobUpdates => _jobUpdateController.stream;

  Future<void> ensureConnected() async {
    if (_socket != null && (_socket!.connected || _isConnecting)) {
      return _connectionCompleter?.future ?? Future.value();
    }

    final token =
        await _tokenStorage.read(AuthRepository.tokenStorageKey) ?? '';
    if (token.isEmpty) {
      throw StateError('Token tidak ditemui. Sila log masuk semula.');
    }

    _isConnecting = true;
    _connectionCompleter = Completer<void>();
    final socket = io.io(
      _namespaceUrl,
      io.OptionBuilder()
          .setTransports(<String>['websocket'])
          .disableAutoConnect()
          .setQuery(<String, dynamic>{'token': token})
          .setExtraHeaders(<String, String>{'Authorization': 'Bearer $token'})
          .build(),
    );
    _socket = socket;
    _registerListeners(socket);
    socket.connect();

    socket.onConnect((_) {
      debugPrint('[Socket] Connected to realtime gateway');
      _connectionCompleter?.complete();
      _isConnecting = false;
      _rejoinRooms();
    });

    socket.onConnectError((dynamic error) {
      debugPrint('[Socket] Connection error: $error');
      if (!(_connectionCompleter?.isCompleted ?? true)) {
        _connectionCompleter?.completeError(error ?? 'Unable to connect');
      }
      _isConnecting = false;
    });

    socket.onError((dynamic error) {
      debugPrint('[Socket] Error: $error');
    });

    socket.onDisconnect((_) {
      debugPrint('[Socket] Disconnected from realtime gateway');
    });

    return _connectionCompleter!.future;
  }

  Future<void> joinJobRoom(String jobId) async {
    if (jobId.isEmpty) {
      return;
    }
    await ensureConnected();
    if (_joinedJobs.contains(jobId)) {
      return;
    }
    _socket?.emit('joinJobRoom', <String, dynamic>{
      'jobId': int.tryParse(jobId) ?? jobId,
    });
    _joinedJobs.add(jobId);
  }

  Future<void> sendMessage(String jobId, String content) async {
    if (content.trim().isEmpty) {
      return;
    }
    await ensureConnected();
    await joinJobRoom(jobId);
    final payload = <String, dynamic>{
      'jobId': int.tryParse(jobId) ?? jobId,
      'content': content,
    };
    final socket = _socket;
    if (socket == null || !socket.connected) {
      throw StateError('Socket belum sedia.');
    }
    socket.emit('sendMessage', payload);
  }

  void dispose() {
    final socket = _socket;
    _socket = null;
    socket?.disconnect();
    _messageController.close();
    _jobUpdateController.close();
  }

  void _registerListeners(io.Socket socket) {
    socket.on('messageReceived', (dynamic data) {
      final event = _parseMessageEvent(data);
      if (event != null) {
        _messageController.add(event);
      }
    });

    socket.on('jobStatusUpdated', (dynamic data) {
      final event = _parseJobStatus(data);
      if (event != null) {
        _jobUpdateController.add(event);
      }
    });
  }

  ChatSocketMessageEvent? _parseMessageEvent(dynamic data) {
    final map = _normalizeMap(data);
    if (map == null) {
      return null;
    }
    final jobId = map['jobId']?.toString();
    if (jobId == null) {
      return null;
    }
    final message = ChatMessage.fromJson(map);
    return ChatSocketMessageEvent(jobId: jobId, message: message);
  }

  JobSocketStatusEvent? _parseJobStatus(dynamic data) {
    final map = _normalizeMap(data);
    if (map == null) {
      return null;
    }
    final jobId = map['jobId']?.toString();
    if (jobId == null) {
      return null;
    }
    return JobSocketStatusEvent(
      jobId: jobId,
      status: map['status']?.toString() ?? 'PENDING',
      title: map['title']?.toString(),
      disputeReason: map['disputeReason']?.toString(),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic>? _normalizeMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }

  void _rejoinRooms() {
    for (final jobId in _joinedJobs) {
      _socket?.emit('joinJobRoom', <String, dynamic>{
        'jobId': int.tryParse(jobId) ?? jobId,
      });
    }
  }

  String get _namespaceUrl {
    final normalized =
        _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    return '$normalized/chats';
  }
}
