class Service {
  Service({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.price,
    required this.freelancerId,
    this.freelancerName,
    this.freelancerAvatarUrl,
    this.thumbnailUrl,
    this.deliveryTime,
    this.isActive = true,
    this.approvalStatus = 'PENDING',
    this.hasPriceIssue = false,
    this.rejectionReason,
    this.rating,
    this.reviewCount,
    this.completedJobsCount,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    final priceResult = _parsePrice(json['price']);
    final freelancer = json['freelancer'];
    return Service(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: priceResult.value,
      hasPriceIssue: priceResult.hadError,
      freelancerId: json['freelancer_id']?.toString() ??
          json['freelancerId']?.toString() ??
          freelancer?['id']?.toString() ??
          '',
      freelancerName: freelancer?['name']?.toString(),
      freelancerAvatarUrl: freelancer?['avatarUrl']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      deliveryTime: json['deliveryTime']?.toString(),
      isActive: json['isActive'] ?? true,
      approvalStatus: json['approvalStatus']?.toString() ?? 'PENDING',
      rejectionReason: json['rejectionReason']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: json['reviewCount'] as int?,
      completedJobsCount: json['completedJobsCount'] as int?,
    );
  }

  final String id;
  final String title;
  final String category;
  final String description;
  final String freelancerId;
  final String? freelancerName;
  final String? freelancerAvatarUrl;
  final String? thumbnailUrl;
  final String? deliveryTime;
  final bool isActive;
  final String approvalStatus;
  final double price;
  final bool hasPriceIssue;
  final String? rejectionReason;
  final double? rating;
  final int? reviewCount;
  final int? completedJobsCount;

  bool get isPriceUnavailable => hasPriceIssue || price <= 0;
  bool get isPending => approvalStatus == 'PENDING';
  bool get isRejected => approvalStatus == 'REJECTED';

  static ({double value, bool hadError}) _parsePrice(dynamic price) {
    if (price is num) {
      return (value: price.toDouble(), hadError: false);
    }

    if (price is String && price.trim().isNotEmpty) {
      final parsed = double.tryParse(price);
      if (parsed != null) {
        return (value: parsed, hadError: false);
      }
    }

    return (value: 0, hadError: true);
  }
}
