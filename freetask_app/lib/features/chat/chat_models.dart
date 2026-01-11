class ChatThread {
  const ChatThread({
    required this.id,
    required this.jobTitle,
    required this.participantName,
    this.lastMessage,
    this.lastAt,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id']?.toString() ?? '',
      jobTitle:
          json['job_title']?.toString() ?? json['jobTitle']?.toString() ?? '',
      participantName: json['participant_name']?.toString() ??
          json['participantName']?.toString() ??
          '',
      lastMessage:
          json['last_message']?.toString() ?? json['lastMessage']?.toString(),
      lastAt: DateTime.tryParse(
        json['lastAt']?.toString() ?? json['last_at']?.toString() ?? '',
      ),
    );
  }

  final String id;
  final String jobTitle;
  final String participantName;
  final String? lastMessage;
  final DateTime? lastAt;
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
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      jobId: json['jobId']?.toString() ?? json['job_id']?.toString() ?? '',
      senderId:
          json['senderId']?.toString() ?? json['sender_id']?.toString() ?? '',
      senderName: json['senderName']?.toString() ??
          json['sender_name']?.toString() ??
          '',
      text: json['content']?.toString() ?? json['text']?.toString() ?? '',
      timestamp: DateTime.tryParse(
            json['createdAt']?.toString() ??
                json['timestamp']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      type: json['type'] as String? ?? 'text',
      attachmentUrl: json['attachmentUrl'] as String?,
    );
  }

  final String id;
  final String jobId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final String type;
  final String? attachmentUrl;
}
