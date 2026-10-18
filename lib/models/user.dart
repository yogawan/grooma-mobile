enum UserRole {
  host,
  agent;

  static UserRole fromApi(String value) {
    switch (value) {
      case 'HOST':
        return UserRole.host;
      case 'AGENT':
        return UserRole.agent;
      default:
        throw FormatException('Unknown role: $value');
    }
  }

  String get apiValue => this == UserRole.host ? 'HOST' : 'AGENT';
}

class Branch {
  const Branch({required this.id, required this.name});

  final String id;
  final String name;

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(id: json['id'] as String, name: json['name'] as String);
  }
}

/// Matches the fixed `data.user` shape returned by `/auth/login` and
/// `/auth/me` (see docs/AUTH-MOBILE-API-INTEGRATION.md §3). `branch` is
/// always null for HOST and always present for AGENT.
class User {
  const User({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    this.branch,
  });

  final String id;
  final String username;
  final String name;
  final UserRole role;
  final Branch? branch;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      name: json['name'] as String,
      role: UserRole.fromApi(json['role'] as String),
      branch: json['branch'] == null
          ? null
          : Branch.fromJson(json['branch'] as Map<String, dynamic>),
    );
  }
}
