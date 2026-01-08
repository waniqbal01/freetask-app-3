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
    this.hasPriceIssue = false,
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
    );
  }

  final String id;
  final String title;
  final String category;
  final String description;
  final String freelancerId;
  final String? freelancerName;
  final String? freelancerAvatarUrl;
  final double price;
  final bool hasPriceIssue;

  bool get isPriceUnavailable => hasPriceIssue || price <= 0;

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
