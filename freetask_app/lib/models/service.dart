class Service {
  Service({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.price,
    required this.deliveryDays,
    required this.includes,
    required this.freelancerId,
    required this.rating,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    final includes = json['includes'];
    return Service(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      deliveryDays: json['delivery_days'] as int? ??
          json['deliveryDays'] as int? ??
          0,
      includes: includes is List
          ? includes.map((dynamic item) => item.toString()).toList()
          : <String>[],
      freelancerId: json['freelancer_id']?.toString() ??
          json['freelancerId']?.toString() ??
          '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
    );
  }

  final String id;
  final String title;
  final String category;
  final String description;
  final double price;
  final int deliveryDays;
  final List<String> includes;
  final String freelancerId;
  final double rating;
}
