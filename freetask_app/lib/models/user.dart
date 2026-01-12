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
    this.rating,
    this.reviewCount,
    this.phoneNumber,
    this.location,
    this.isAvailable = true,
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
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: json['reviewCount'] as int?,
      phoneNumber: json['phoneNumber'] as String?,
      location: json['location'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? true,
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
  final double? rating;
  final int? reviewCount;
  final String? phoneNumber;
  final String? location;
  final bool isAvailable;
}
