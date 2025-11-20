class AdminReport {
  AdminReport({
    required this.id,
    required this.reason,
    required this.status,
    this.reporterName,
    this.reportedUserName,
    this.reportedServiceTitle,
    this.createdAt,
  });

  factory AdminReport.fromJson(Map<String, dynamic> json) {
    final reporter = json['reporter'] as Map<String, dynamic>?;
    final reportedUser = json['reportedUser'] as Map<String, dynamic>?;
    final reportedService = json['reportedService'] as Map<String, dynamic>?;
    return AdminReport(
      id: json['id'] as int? ?? 0,
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OPEN',
      reporterName: reporter?['name']?.toString(),
      reportedUserName: reportedUser?['name']?.toString(),
      reportedServiceTitle: reportedService?['title']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  final int id;
  final String reason;
  final String status;
  final String? reporterName;
  final String? reportedUserName;
  final String? reportedServiceTitle;
  final DateTime? createdAt;
}
