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
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final double price;
  final int deliveryDays;
  final List<String> includes;
  final String freelancerId;
}
