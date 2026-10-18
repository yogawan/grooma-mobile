import 'pagination.dart';

enum CustomerGender {
  male,
  female,
  other,
  unspecified;

  static CustomerGender fromApi(String value) {
    switch (value) {
      case 'MALE':
        return CustomerGender.male;
      case 'FEMALE':
        return CustomerGender.female;
      case 'OTHER':
        return CustomerGender.other;
      case 'UNSPECIFIED':
        return CustomerGender.unspecified;
      default:
        throw FormatException('Unknown gender: $value');
    }
  }

  String get apiValue => switch (this) {
    CustomerGender.male => 'MALE',
    CustomerGender.female => 'FEMALE',
    CustomerGender.other => 'OTHER',
    CustomerGender.unspecified => 'UNSPECIFIED',
  };

  String get label => switch (this) {
    CustomerGender.male => 'Pria',
    CustomerGender.female => 'Wanita',
    CustomerGender.other => 'Lainnya',
    CustomerGender.unspecified => 'Tidak disebutkan',
  };
}

/// `email`/`gender`/`birthDate`/`address`/`notes` are the 5 "privileged"
/// fields that are **completely absent** (not `null`) from every
/// response when the caller is AGENT (customer doc §0) — not just
/// nullable because they might be unset, but because Dart's `Map`
/// indexing already returns `null` for a missing key, `json['email']
/// as String?` handles both "key absent" and "key present but null"
/// identically for free. The important part is that none of these 5
/// fields are non-nullable here, or parsing an AGENT response throws.
///
/// Whether to *display* these fields should be driven by the
/// logged-in user's role, not by whether the parsed value happens to
/// be null — for a HOST, null genuinely means "not filled in"; for an
/// AGENT, it always means "not visible to you", a different thing.
class Customer {
  const Customer({
    required this.id,
    required this.customerCode,
    required this.name,
    required this.phone,
    required this.customerType,
    required this.loyaltyPoints,
    required this.lastVisitAt,
    required this.isActive,
    required this.email,
    required this.gender,
    required this.birthDate,
    required this.address,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? customerCode;
  final String name;
  final String? phone;
  // Always "REGULAR" today; kept as a raw string rather than an enum
  // since the doc itself flags a future "DECOY" classification with no
  // defined API surface yet (customer doc §3).
  final String customerType;
  final int loyaltyPoints;
  final DateTime? lastVisitAt;
  final bool isActive;
  final String? email;
  final CustomerGender? gender;
  final DateTime? birthDate;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      customerCode: json['customerCode'] as String?,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      customerType: json['customerType'] as String,
      loyaltyPoints: json['loyaltyPoints'] as int,
      lastVisitAt: json['lastVisitAt'] == null
          ? null
          : DateTime.parse(json['lastVisitAt'] as String),
      isActive: json['isActive'] as bool,
      email: json['email'] as String?,
      gender: json['gender'] == null
          ? null
          : CustomerGender.fromApi(json['gender'] as String),
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.parse(json['birthDate'] as String),
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// `GET /customers` result (AUTH doc §2.1.2/§2.1.4) — paginated like
/// every other list endpoint now, default 20 rows, no longer the full
/// cross-branch customer base in one response.
class CustomerPage {
  const CustomerPage({required this.customers, required this.pagination});

  final List<Customer> customers;
  final Pagination pagination;

  factory CustomerPage.fromJson(Map<String, dynamic> json) {
    return CustomerPage(
      customers: (json['customers'] as List)
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: Pagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }
}
