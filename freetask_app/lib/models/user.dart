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
    this.state,
    this.district,
    this.latitude,
    this.longitude,
    this.coverageRadius,
    this.acceptsOutstation = false,
    this.isAvailable = true,
    this.bankCode,
    this.bankAccount,
    this.bankHolderName,
    this.bankVerified = false,
    this.level = 'NEWBIE',
    this.totalCompletedJobs = 0,
    this.totalReviews = 0,
    this.replyRate,
    this.serviceNames,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final skills = json['skills'];
    final services = json['services'];
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
      state: json['state'] as String?,
      district: json['district'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      coverageRadius: json['coverageRadius'] as int?,
      acceptsOutstation: json['acceptsOutstation'] as bool? ?? false,
      isAvailable: json['isAvailable'] as bool? ?? true,
      bankCode: json['bankCode']?.toString(),
      bankAccount: json['bankAccount']?.toString(),
      bankHolderName: json['bankHolderName']?.toString(),
      bankVerified: json['bankVerified'] as bool? ?? false,
      level: json['level']?.toString() ?? 'NEWBIE',
      totalCompletedJobs: json['totalCompletedJobs'] as int? ?? 0,
      totalReviews: json['totalReviews'] as int? ?? 0,
      replyRate: (json['replyRate'] as num?)?.toDouble(),
      serviceNames: services is List
          ? services
              .map((dynamic service) => service['title']?.toString())
              .whereType<String>()
              .toList()
          : null,
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
  final String? state;
  final String? district;
  final double? latitude;
  final double? longitude;
  final int? coverageRadius;
  final bool acceptsOutstation;
  final bool isAvailable;

  // Bank Details
  final String? bankCode;
  final String? bankAccount;
  final String? bankHolderName;
  final bool bankVerified;

  // Freelancer Level and Stats
  final String level;
  final int totalCompletedJobs;
  final int totalReviews;
  final double? replyRate;
  final List<String>? serviceNames;
}
