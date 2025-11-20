class OverviewStats {
  OverviewStats({
    required this.totalUsers,
    required this.totalClients,
    required this.totalFreelancers,
    required this.totalServices,
    required this.totalJobs,
    this.totalCompletedJobs = 0,
    this.totalDisputedJobs = 0,
    Map<String, int>? jobsByStatus,
  }) : jobsByStatus = jobsByStatus ?? <String, int>{};

  factory OverviewStats.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? statusCounts =
        json['jobsByStatus'] as Map<String, dynamic>?;
    return OverviewStats(
      totalUsers: _parseInt(json['totalUsers']),
      totalClients: _parseInt(json['totalClients']),
      totalFreelancers: _parseInt(json['totalFreelancers']),
      totalServices: _parseInt(json['totalServices']),
      totalJobs: _parseInt(json['totalJobs']),
      totalCompletedJobs: _parseInt(json['totalCompletedJobs']),
      totalDisputedJobs: _parseInt(json['totalDisputedJobs']),
      jobsByStatus: statusCounts?.map(
            (String key, dynamic value) => MapEntry<String, int>(
              key,
              _parseInt(value),
            ),
          ) ??
          <String, int>{},
    );
  }

  final int totalUsers;
  final int totalClients;
  final int totalFreelancers;
  final int totalServices;
  final int totalJobs;
  final int totalCompletedJobs;
  final int totalDisputedJobs;
  final Map<String, int> jobsByStatus;

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
