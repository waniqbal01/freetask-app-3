import 'user_role.dart';

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.roleEnum,
    this.avatarUrl,
    this.bio,
    this.skills,
    this.rate,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final skills = json['skills'];
    final roleStr = json['role']?.toString() ?? '';
    return AppUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: roleStr,
      roleEnum: UserRole.fromString(roleStr),
      avatarUrl:
          json['avatar_url']?.toString() ?? json['avatarUrl']?.toString(),
      bio: json['bio']?.toString(),
      skills: skills is List
          ? skills.map((dynamic skill) => skill.toString()).toList()
          : null,
      rate: (json['rate'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String name;
  final String role; // Keep for backward compatibility
  final UserRole roleEnum; // Type-safe role enum
  final String? avatarUrl;
  final String? bio;
  final List<String>? skills;
  final double? rate;
}
