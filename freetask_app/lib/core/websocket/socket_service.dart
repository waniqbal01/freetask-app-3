import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../storage/storage.dart';
import '../../models/chat_enums.dart';
import '../../features/auth/auth_repository.dart';
import '../../features/chat/chat_models.dart';

/// WebSocket service for real-time chat functionality
/// Handles connection, reconnection, and event broadcasting
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  final _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();
  final _newMessageController = StreamController<ChatMessage>.broadcast();
  final _messageStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController = StreamController<PresenceStatus>.broadcast();

  // Streams
  Stream<ConnectionStatus> get connectionStream =>
      _connectionStatusController.stream;
  Stream<ChatMessage> get newMessageStream => _newMessageController.stream;
  Stream<Map<String, dynamic>> get messageStatusStream =>
      _messageStatusController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<PresenceStatus> get presenceStream => _presenceController.stream;

  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  ConnectionStatus get currentStatus => _currentStatus;

  bool get isConnected => _socket?.connected ?? false;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;

  /// Connect to WebSocket server
  Future<void> connect(String baseUrl) async {
    if (_socket?.connected == true) {
      debugPrint('SocketService: Already connected');
      return;
    }

    _updateStatus(ConnectionStatus.connecting);

    try {
      // Get auth token
      final token = await appStorage.read(AuthRepository.tokenStorageKey);
      if (token == null || token.isEmpty) {
        debugPrint('SocketService: No auth token available');
        _updateStatus(ConnectionStatus.disconnected);
        return;
      }

      // Parse base URL (remove /api if exists)
      final socketUrl = baseUrl.replaceAll('/api', '');

      debugPrint('SocketService: Connecting to $socketUrl');

      _socket = io.io(
        socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(_maxReconnectAttempts)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .build(),
      );

      _setupEventListeners();
      _socket!.connect();
    } catch (e) {
      debugPrint('SocketService: Connection error: $e');
      _updateStatus(ConnectionStatus.disconnected);
      _scheduleReconnect();
    }
  }

  /// Setup all WebSocket event listeners
  void _setupEventListeners() {
    if (_socket == null) return;

    // Connection events
    _socket!.onConnect((_) {
      debugPrint('SocketService: Connected');
      _reconnectAttempts = 0;
      _updateStatus(ConnectionStatus.connected);
      _startHeartbeat();
    });

    _socket!.onDisconnect((_) {
      debugPrint('SocketService: Disconnected');
      _updateStatus(ConnectionStatus.disconnected);
      _scheduleReconnect();
    });

    _socket!.onConnectError((error) {
      debugPrint('SocketService: Connection error: $error');
      _updateStatus(ConnectionStatus.disconnected);
    });

    _socket!.onError((error) {
      debugPrint('SocketService: Error: $error');
    });

    _socket!.onReconnect((_) {
      debugPrint('SocketService: Reconnected');
      _reconnectAttempts = 0;
      _updateStatus(ConnectionStatus.connected);
    });

    // Note: onReconnecting not available in socket_io_client
    // Connection status managed via onConnect/onDisconnect

    _socket!.onReconnectFailed((_) {
      debugPrint('SocketService: Reconnection failed');
      _updateStatus(ConnectionStatus.disconnected);
    });

    // Chat events
    _socket!.on('new_message', (data) {
      debugPrint('SocketService: Received new_message: $data');
      try {
        final message = ChatMessage.fromJson(data as Map<String, dynamic>);
        _newMessageController.add(message);
      } catch (e) {
        debugPrint('SocketService: Error parsing new_message: $e');
      }
    });

    _socket!.on('message_delivered', (data) {
      debugPrint('SocketService: Message delivered: $data');
      _messageStatusController.add({
        'event': 'delivered',
        'data': data,
      });
    });

    _socket!.on('message_read', (data) {
      debugPrint('SocketService: Message read: $data');
      _messageStatusController.add({
        'event': 'read',
        'data': data,
      });
    });

    // Typing events
    _socket!.on('typing_start', (data) {
      debugPrint('SocketService: User typing: $data');
      _typingController.add({
        'event': 'start',
        'data': data,
      });
    });

    _socket!.on('typing_stop', (data) {
      debugPrint('SocketService: User stopped typing: $data');
      _typingController.add({
        'event': 'stop',
        'data': data,
      });
    });

    // Presence events
    _socket!.on('user_online', (data) {
      debugPrint('SocketService: User online: $data');
      try {
        final presence = PresenceStatus.fromJson(data as Map<String, dynamic>);
        _presenceController.add(presence);
      } catch (e) {
        debugPrint('SocketService: Error parsing user_online: $e');
      }
    });

    _socket!.on('user_offline', (data) {
      debugPrint('SocketService: User offline: $data');
      try {
        final presence = PresenceStatus.fromJson(data as Map<String, dynamic>);
        _presenceController.add(presence);
      } catch (e) {
        debugPrint('SocketService: Error parsing user_offline: $e');
      }
    });
  }

  /// Send heartbeat to keep connection alive
  Timer? _heartbeatTimer;
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_socket?.connected == true) {
        emit('heartbeat', {'timestamp': DateTime.now().toIso8601String()});
      }
    });
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('SocketService: Max reconnect attempts reached. Giving up.');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: 2 * _reconnectAttempts);

    debugPrint(
        'SocketService: Scheduling reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(delay, () {
      if (_socket?.connected != true) {
        debugPrint('SocketService: Attempting reconnect...');
        _socket?.connect();
      }
    });
  }

  /// Update connection status and notify listeners
  void _updateStatus(ConnectionStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _connectionStatusController.add(status);
    }
  }

  /// Emit an event to the server
  void emit(String event, dynamic data) {
    if (_socket?.connected != true) {
      debugPrint('SocketService: Cannot emit $event - not connected');
      return;
    }
    debugPrint('SocketService: Emitting $event: $data');
    _socket!.emit(event, data);
  }

  /// Listen to specific event
  void on(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  /// Remove event listener
  void off(String event) {
    _socket?.off(event);
  }

  /// Disconnect from WebSocket
  void disconnect() {
    debugPrint('SocketService: Disconnecting');
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _updateStatus(ConnectionStatus.disconnected);
  }

  /// Dispose all resources
  void dispose() {
    disconnect();
    _connectionStatusController.close();
    _newMessageController.close();
    _messageStatusController.close();
    _typingController.close();
    _presenceController.close();
  }

  // Convenience methods for chat operations

  /// Join a chat room
  void joinRoom(String conversationId) {
    emit('join_room', {'conversationId': conversationId});
  }

  /// Leave a chat room
  void leaveRoom(String conversationId) {
    emit('leave_room', {'conversationId': conversationId});
  }

  /// Send typing indicator
  void sendTyping(String conversationId, bool isTyping) {
    emit(isTyping ? 'typing_start' : 'typing_stop',
        {'conversationId': conversationId});
  }

  /// Mark message as delivered
  void markDelivered(String messageId, String conversationId) {
    emit('mark_delivered', {
      'messageId': messageId,
      'conversationId': conversationId,
    });
  }

  /// Mark message as read
  void markRead(String messageId, String conversationId) {
    emit('mark_read', {
      'messageId': messageId,
      'conversationId': conversationId,
    });
  }

  /// Mark entire chat as read
  void markChatRead(String conversationId) {
    emit('mark_chat_read', {'conversationId': conversationId});
  }
}
