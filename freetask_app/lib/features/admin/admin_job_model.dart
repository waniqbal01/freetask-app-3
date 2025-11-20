class AdminJob {
  AdminJob({
    required this.id,
    required this.title,
    required this.status,
    required this.clientName,
    required this.freelancerName,
    required this.createdAt,
  });

  factory AdminJob.fromJson(Map<String, dynamic> json) {
    return AdminJob(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? 'Job tanpa tajuk',
      status: json['status']?.toString() ?? 'UNKNOWN',
      clientName: json['clientName']?.toString() ?? json['client']?['name']?.toString() ?? '-',
      freelancerName:
          json['freelancerName']?.toString() ?? json['freelancer']?['name']?.toString() ?? '-',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  final int id;
  final String title;
  final String status;
  final String clientName;
  final String freelancerName;
  final DateTime createdAt;
}
