enum BranchStatus {
  active,
  inactive;

  static BranchStatus fromApi(String value) {
    switch (value) {
      case 'ACTIVE':
        return BranchStatus.active;
      case 'INACTIVE':
        return BranchStatus.inactive;
      default:
        throw FormatException('Unknown branch status: $value');
    }
  }

  String get apiValue => this == BranchStatus.active ? 'ACTIVE' : 'INACTIVE';
  String get label => this == BranchStatus.active ? 'Aktif' : 'Nonaktif';
}

/// The full branch entity from `/api/v1/branches` (Kelola doc §1) —
/// deliberately named `ManagedBranch`, not `Branch`, to avoid colliding
/// with the lightweight `Branch` (`{id, name}`) already used on `User`/
/// `UserProfile` elsewhere; the two aren't interchangeable (this one
/// has the full CRUD fields, that one is just a reference).
class ManagedBranch {
  const ManagedBranch({
    required this.id,
    required this.branchCode,
    required this.name,
    required this.address,
    required this.phone,
    required this.timezone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String branchCode;
  final String name;
  final String? address;
  final String? phone;
  final String timezone;
  final BranchStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ManagedBranch.fromJson(Map<String, dynamic> json) {
    return ManagedBranch(
      id: json['_id'] as String,
      branchCode: json['branchCode'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      timezone: json['timezone'] as String,
      status: BranchStatus.fromApi(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
