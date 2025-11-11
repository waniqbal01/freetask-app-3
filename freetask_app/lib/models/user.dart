class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.bio,
    this.skills,
    this.rate,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final skills = json['skills'];
    return AppUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ??
          json['avatarUrl']?.toString(),
      bio: json['bio']?.toString(),
      skills: skills is List
          ? skills.map((dynamic skill) => skill.toString()).toList()
          : null,
      rate: (json['rate'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String name;
  final String role;
  final String? avatarUrl;
  final String? bio;
  final List<String>? skills;
  final double? rate;
}
