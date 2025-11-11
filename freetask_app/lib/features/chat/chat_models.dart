class ChatThread {
  const ChatThread({
    required this.id,
    required this.jobTitle,
    required this.participantName,
  });

  final String id;
  final String jobTitle;
  final String participantName;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    this.text,
    this.imagePath,
    required this.timestamp,
  }) : assert(text != null || imagePath != null, 'Message must have text or image.');

  final String id;
  final String sender;
  final String? text;
  final String? imagePath;
  final DateTime timestamp;

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
}
