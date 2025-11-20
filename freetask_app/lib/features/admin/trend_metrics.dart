class TrendDataPoint {
  TrendDataPoint({required this.date, required this.count});

  factory TrendDataPoint.fromJson(Map<String, dynamic> json) {
    return TrendDataPoint(
      date: json['date']?.toString() ?? '',
      count: json['count'] as int? ?? 0,
    );
  }

  final String date;
  final int count;
}

class TrendMetrics {
  TrendMetrics({required this.jobsPerDay, required this.servicesPerDay, required this.usersPerDay});

  factory TrendMetrics.fromJson(Map<String, dynamic> json) {
    List<TrendDataPoint> parseList(String key) {
      final data = json[key] as List<dynamic>? ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(TrendDataPoint.fromJson)
          .toList(growable: false);
    }

    return TrendMetrics(
      jobsPerDay: parseList('jobsPerDay'),
      servicesPerDay: parseList('servicesPerDay'),
      usersPerDay: parseList('usersPerDay'),
    );
  }

  final List<TrendDataPoint> jobsPerDay;
  final List<TrendDataPoint> servicesPerDay;
  final List<TrendDataPoint> usersPerDay;
}
