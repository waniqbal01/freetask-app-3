import '../../models/chat_enums.dart';

class ChatThread {
  const ChatThread({
    required this.id,
    required this.title,
    required this.participantName,
    this.participantId,
    this.participantAvatarUrl,
    this.lastMessage,
    this.lastAt,
    this.status = 'ACTIVE',
    this.unreadCount = 0,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id']?.toString() ?? '',
      title: json['jobTitle']?.toString() ??
          json['job_title']?.toString() ??
          'Conversation',
      participantName: json['participantName']?.toString() ??
          json['participant_name']?.toString() ??
          '',
      participantId: json['participantId']?.toString() ??
          json['participant_id']?.toString(),
      participantAvatarUrl: json['participantAvatarUrl']?.toString() ??
          json['participant_avatar_url']?.toString(),
      lastMessage:
          json['lastMessage']?.toString() ?? json['last_message']?.toString(),
      lastAt: DateTime.tryParse(
        json['lastAt']?.toString() ?? json['last_at']?.toString() ?? '',
      ),
      status: json['jobStatus']?.toString() ??
          json['job_status']?.toString() ??
          'ACTIVE',
      unreadCount: int.tryParse(
            json['unreadCount']?.toString() ??
                json['unread_count']?.toString() ??
                '0',
          ) ??
          0,
    );
  }

  final String id;
  final String title;
  final String participantName;
  final String? participantId;
  final String? participantAvatarUrl;
  final String? lastMessage;
  final DateTime? lastAt;
  final String status;
  final int unreadCount;

  ChatThread copyWith({
    String? id,
    String? title,
    String? participantName,
    String? participantId,
    String? participantAvatarUrl,
    String? lastMessage,
    DateTime? lastAt,
    String? status,
    int? unreadCount,
  }) {
    return ChatThread(
      id: id ?? this.id,
      title: title ?? this.title,
      participantName: participantName ?? this.participantName,
      participantId: participantId ?? this.participantId,
      participantAvatarUrl: participantAvatarUrl ?? this.participantAvatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastAt: lastAt ?? this.lastAt,
      status: status ?? this.status,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.jobId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.type = 'text',
    this.attachmentUrl,
    this.status = MessageStatus.sent,
    this.deliveredAt,
    this.readAt,
    this.replyToId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    String textContent =
        json['content']?.toString() ?? json['text']?.toString() ?? '';
    String? parsedReplyToId = json['replyToId']?.toString();

    // Fallback: extract replyToId from text if encoded by frontend backend-workaround
    if (textContent.startsWith('__REPLY:')) {
      final endIdx = textContent.indexOf('__\n');
      if (endIdx != -1) {
        parsedReplyToId = textContent.substring(8, endIdx);
        textContent = textContent.substring(endIdx + 3);
      }
    }

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      jobId: json['jobId']?.toString() ?? json['job_id']?.toString() ?? '',
      senderId:
          json['senderId']?.toString() ?? json['sender_id']?.toString() ?? '',
      senderName: json['senderName']?.toString() ??
          json['sender_name']?.toString() ??
          '',
      text: textContent,
      timestamp: DateTime.tryParse(
            json['createdAt']?.toString() ??
                json['timestamp']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      type: json['type'] as String? ?? 'text',
      attachmentUrl: json['attachmentUrl'] as String?,
      status: json['readAt'] != null
          ? MessageStatus.read
          : (json['deliveredAt'] != null
              ? MessageStatus.delivered
              : _parseMessageStatus(json['status']?.toString())),
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'].toString())
          : null,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
      replyToId: parsedReplyToId,
    );
  }

  static MessageStatus _parseMessageStatus(String? status) {
    if (status == null) return MessageStatus.sent;
    switch (status.toLowerCase()) {
      case 'pending':
        return MessageStatus.pending;
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  final String id;
  final String jobId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final String type;
  final String? attachmentUrl;
  final MessageStatus status;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? replyToId;

  ChatMessage copyWith({
    String? id,
    String? jobId,
    String? senderId,
    String? senderName,
    String? text,
    DateTime? timestamp,
    String? type,
    String? attachmentUrl,
    MessageStatus? status,
    DateTime? deliveredAt,
    DateTime? readAt,
    String? replyToId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      status: status ?? this.status,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      replyToId: replyToId ?? this.replyToId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jobId': jobId,
      'senderId': senderId,
      'senderName': senderName,
      'content': text,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'attachmentUrl': attachmentUrl,
      'status': status.name,
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'replyToId': replyToId,
    };
  }
}
