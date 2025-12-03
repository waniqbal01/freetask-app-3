/// Type-safe UserRole enum to replace string comparisons throughout the app
enum UserRole {
  client,
  freelancer,
  admin;

  /// Parse role string from API response
  static UserRole fromString(String role) {
    return UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == role.toLowerCase(),
      orElse: () => UserRole.client,
    );
  }

  /// Check if user is a client
  bool get isClient => this == UserRole.client;

  /// Check if user is a freelancer
  bool get isFreelancer => this == UserRole.freelancer;

  /// Check if user is an admin
  bool get isAdmin => this == UserRole.admin;

  /// Get display name for the role
  String get displayName {
    switch (this) {
      case UserRole.client:
        return 'Klien';
      case UserRole.freelancer:
        return 'Pekerja Bebas';
      case UserRole.admin:
        return 'Admin';
    }
  }
}
