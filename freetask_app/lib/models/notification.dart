class Notification {
  final int id;
  final DateTime createdAt;
  final int userId;
  final String title;
  final String body;
  final bool read;
  final String? type;
  final Map<String, dynamic>? data;

  Notification({
    required this.id,
    required this.createdAt,
    required this.userId,
    required this.title,
    required this.body,
    required this.read,
    this.type,
    this.data,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      userId: json['userId'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      read: json['read'] as bool,
      type: json['type'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'userId': userId,
      'title': title,
      'body': body,
      'read': read,
      'type': type,
      'data': data,
    };
  }
}
