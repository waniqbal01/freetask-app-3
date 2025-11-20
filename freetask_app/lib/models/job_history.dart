class JobHistory {
  JobHistory({
    required this.id,
    required this.jobId,
    this.actorId,
    this.actorName,
    required this.action,
    this.message,
    required this.createdAt,
  });

  factory JobHistory.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    return JobHistory(
      id: json['id']?.toString() ?? '',
      jobId: json['jobId']?.toString() ?? '',
      actorId: actor?['id']?.toString() ?? json['actorId']?.toString(),
      actorName: actor?['name']?.toString(),
      action: json['action']?.toString() ?? '',
      message: json['message']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  final String id;
  final String jobId;
  final String? actorId;
  final String? actorName;
  final String action;
  final String? message;
  final DateTime createdAt;
}
