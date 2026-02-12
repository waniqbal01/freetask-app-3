enum MessageStatus {
  pending, // ⏱️ Sending...
  sent, // ✓ Sent to server
  delivered, // ✓✓ Delivered to recipient
  read, // ✓✓ (blue) Read by recipient
  failed, // ❌ Failed to send
}

enum ConnectionStatus {
  connected,
  connecting,
  disconnected,
  reconnecting,
}

class PresenceStatus {
  const PresenceStatus({
    required this.userId,
    required this.isOnline,
    this.lastSeen,
  });

  factory PresenceStatus.fromJson(Map<String, dynamic> json) {
    return PresenceStatus(
      userId: json['userId']?.toString() ?? '',
      isOnline: json['isOnline'] == true,
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'].toString())
          : null,
    );
  }

  final String userId;
  final bool isOnline;
  final DateTime? lastSeen;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }
}
