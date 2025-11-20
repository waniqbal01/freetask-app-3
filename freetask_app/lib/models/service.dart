class Service {
  Service({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.price,
    required this.freelancerId,
    this.freelancerName,
    this.createdAt,
    this.averageRating,
    this.reviewCount,
    this.completedJobs,
    this.thumbnailUrl,
    this.freelancerAvatarUrl,
    this.deliveryDays,
    this.active,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    final freelancer = json['freelancer'] as Map<String, dynamic>?;
    return Service(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      freelancerId: json['freelancer_id']?.toString() ??
          json['freelancerId']?.toString() ??
          freelancer?['id']?.toString() ??
          '',
      freelancerName: freelancer?['name']?.toString(),
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      averageRating: _parseDouble(json['averageRating'] ?? json['average_rating']),
      reviewCount: _parseInt(json['reviewCount'] ?? json['review_count']),
      completedJobs: _parseInt(json['completedJobs'] ?? json['completed_jobs']),
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? json['thumbnail_url']?.toString(),
      freelancerAvatarUrl: freelancer?['avatarUrl']?.toString() ??
          json['freelancerAvatar']?.toString(),
      deliveryDays: _parseInt(json['deliveryDays'] ?? json['delivery_days']),
      active: json['active'] as bool?,
    );
  }

  final String id;
  final String title;
  final String category;
  final String description;
  final double price;
  final String freelancerId;
  final String? freelancerName;
  final DateTime? createdAt;
  final double? averageRating;
  final int? reviewCount;
  final int? completedJobs;
  final String? thumbnailUrl;
  final String? freelancerAvatarUrl;
  final int? deliveryDays;
  final bool? active;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'price': price,
      'freelancerId': freelancerId,
      if (freelancerName != null) 'freelancerName': freelancerName,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (averageRating != null) 'averageRating': averageRating,
      if (reviewCount != null) 'reviewCount': reviewCount,
      if (completedJobs != null) 'completedJobs': completedJobs,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (freelancerAvatarUrl != null) 'freelancerAvatar': freelancerAvatarUrl,
      if (deliveryDays != null) 'deliveryDays': deliveryDays,
      if (active != null) 'active': active,
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
