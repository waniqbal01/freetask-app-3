class PortfolioItem {
  final int id;
  final String title;
  final String? description;
  final String? category;
  final String? mediaUrl;
  final int freelancerId;

  PortfolioItem({
    required this.id,
    required this.title,
    this.description,
    this.category,
    this.mediaUrl,
    required this.freelancerId,
  });

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    return PortfolioItem(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      freelancerId: json['freelancerId'] as int,
    );
  }
}
