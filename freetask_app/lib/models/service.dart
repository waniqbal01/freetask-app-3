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

  static DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
