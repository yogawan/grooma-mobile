/// `ownerPercentage + employeePercentage` must total exactly 100
/// (Kelola doc §3.3) — enforced server-side, but the form should only
/// ever expose one slider (owner share) and derive the other, so the
/// constraint can't be violated from the UI at all.
class RevenueSharing {
  const RevenueSharing({
    required this.ownerPercentage,
    required this.employeePercentage,
  });

  final num ownerPercentage;
  final num employeePercentage;

  factory RevenueSharing.fromJson(Map<String, dynamic> json) {
    return RevenueSharing(
      ownerPercentage: json['ownerPercentage'] as num,
      employeePercentage: json['employeePercentage'] as num,
    );
  }

  Map<String, dynamic> toJson() => {
    'ownerPercentage': ownerPercentage,
    'employeePercentage': employeePercentage,
  };
}

/// Named `ServiceItem`, not `Service`, to avoid colliding with Dart/
/// Flutter's own heavy use of "Service" as a word (and with this
/// codebase's `XxxService` API-client naming convention — `Service
/// service` would be actively confusing next to that).
class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.serviceCode,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.durationMinutes,
    required this.revenueSharing,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String serviceCode;
  final String name;
  final String? description;
  // Free text server-side ("bukan enum", Kelola doc §3.3), not an enum
  // here either.
  final String? category;
  final num price;
  final int durationMinutes;
  final RevenueSharing revenueSharing;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      id: json['_id'] as String,
      serviceCode: json['serviceCode'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      price: json['price'] as num,
      durationMinutes: json['durationMinutes'] as int,
      revenueSharing: RevenueSharing.fromJson(
        json['revenueSharing'] as Map<String, dynamic>,
      ),
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
