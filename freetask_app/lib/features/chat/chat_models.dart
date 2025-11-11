class ChatThread {
  const ChatThread({
    required this.id,
    required this.jobTitle,
    required this.participantName,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id']?.toString() ?? '',
      jobTitle: json['job_title']?.toString() ??
          json['jobTitle']?.toString() ??
          '',
      participantName: json['participant_name']?.toString() ??
          json['participantName']?.toString() ??
          '',
    );
  }

  final String id;
  final String jobTitle;
  final String participantName;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    this.text,
    this.imageUrl,
    required this.timestamp,
  }) : assert(text != null || imageUrl != null, 'Message must have text or image.');

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      sender: json['sender']?.toString() ?? '',
      text: json['text']?.toString(),
      imageUrl: json['image_url']?.toString() ??
          json['image_path']?.toString() ??
          json['imagePath']?.toString(),
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String sender;
  final String? text;
  final String? imageUrl;
  final DateTime timestamp;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}
