import 'user.dart';

enum UserStatus {
  active,
  inactive;

  static UserStatus fromApi(String value) {
    switch (value) {
      case 'ACTIVE':
        return UserStatus.active;
      case 'INACTIVE':
        return UserStatus.inactive;
      default:
        throw FormatException('Unknown status: $value');
    }
  }

  String get apiValue => this == UserStatus.active ? 'ACTIVE' : 'INACTIVE';
}

/// `GET`/`PATCH /api/v1/profile` use a different serializer than
/// `/auth/login`/`/auth/me` (profile doc §1) — this is intentionally a
/// separate model from [User], not a reuse of it, since it carries 4
/// extra fields (`phone`, `status`, `createdAt`, `updatedAt`) that the
/// auth serializer never returns.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.branch,
    required this.phone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String username;
  final String name;
  final UserRole role;
  final Branch? branch;
  final String? phone;
  final UserStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      name: json['name'] as String,
      role: UserRole.fromApi(json['role'] as String),
      branch: json['branch'] == null
          ? null
          : Branch.fromJson(json['branch'] as Map<String, dynamic>),
      phone: json['phone'] as String?,
      status: UserStatus.fromApi(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
