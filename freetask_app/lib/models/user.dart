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

  final String id;
  final String name;
  final String role;
  final String? avatarUrl;
  final String? bio;
  final List<String>? skills;
  final double? rate;
}
