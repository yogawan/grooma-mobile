import 'pagination.dart';

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.price,
    required this.currency,
    required this.billingCycle,
    required this.graceDays,
    required this.maxBranches,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final num price;
  final String currency;
  final String billingCycle;
  final int graceDays;
  final int maxBranches;
  final bool isActive;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['_id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      price: json['price'] as num,
      currency: json['currency'] as String,
      billingCycle: json['billingCycle'] as String,
      graceDays: json['graceDays'] as int,
      maxBranches: json['maxBranches'] as int,
      isActive: json['isActive'] as bool,
    );
  }
}

enum SubscriptionStatus {
  active,
  pastDue,
  expired,
  cancelled;

  static SubscriptionStatus fromApi(String value) {
    switch (value) {
      case 'ACTIVE':
        return SubscriptionStatus.active;
      case 'PAST_DUE':
        return SubscriptionStatus.pastDue;
      case 'EXPIRED':
        return SubscriptionStatus.expired;
      case 'CANCELLED':
        return SubscriptionStatus.cancelled;
      default:
        throw FormatException('Unknown subscription status: $value');
    }
  }

  String get label => switch (this) {
    SubscriptionStatus.active => 'Aktif',
    SubscriptionStatus.pastDue => 'Jatuh Tempo',
    SubscriptionStatus.expired => 'Kedaluwarsa',
    SubscriptionStatus.cancelled => 'Dibatalkan',
  };

  bool get isLocked => this != SubscriptionStatus.active;
}

/// `GET /subscription`'s `data.subscription` can itself be `null` on a
/// freshly-provisioned deployment with no subscription record yet
/// (Kelola doc §4.2) — that's full normal access, not a locked state.
/// Callers must treat a null [Subscription] (the whole object, not a
/// field on it) as "no data yet", never as an error.
class Subscription {
  const Subscription({
    required this.id,
    required this.plan,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.graceEndsAt,
    required this.cancelledAt,
    required this.cancelReason,
  });

  final String id;
  // Always populated as a full object, never a raw id (doc §4.2).
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final DateTime? graceEndsAt;
  final DateTime? cancelledAt;
  final String? cancelReason;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['_id'] as String,
      plan: SubscriptionPlan.fromJson(json['plan'] as Map<String, dynamic>),
      status: SubscriptionStatus.fromApi(json['status'] as String),
      currentPeriodStart: DateTime.parse(json['currentPeriodStart'] as String),
      currentPeriodEnd: DateTime.parse(json['currentPeriodEnd'] as String),
      graceEndsAt: json['graceEndsAt'] == null
          ? null
          : DateTime.parse(json['graceEndsAt'] as String),
      cancelledAt: json['cancelledAt'] == null
          ? null
          : DateTime.parse(json['cancelledAt'] as String),
      cancelReason: json['cancelReason'] as String?,
    );
  }
}

/// `status` is kept as a raw string rather than a strict enum — the
/// doc's example only ever shows `"PENDING"` and never enumerates the
/// full set, so a strict enum risks a `FormatException` on a value we
/// just haven't seen documented yet. [isPayable] covers the one state
/// this app actually needs to branch on.
class Invoice {
  const Invoice({
    required this.id,
    required this.invoiceCode,
    required this.periodStart,
    required this.periodEnd,
    required this.amount,
    required this.status,
    required this.dueAt,
    required this.paidAt,
    required this.qrCodeUrl,
    required this.qrString,
    required this.expiresAt,
  });

  final String id;
  final String invoiceCode;
  final DateTime periodStart;
  final DateTime periodEnd;
  final num amount;
  final String status;
  final DateTime dueAt;
  final DateTime? paidAt;
  final String? qrCodeUrl;
  final String? qrString;
  final DateTime? expiresAt;

  bool get isPayable => paidAt == null && qrCodeUrl != null;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['_id'] as String,
      invoiceCode: json['invoiceCode'] as String,
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
      amount: json['amount'] as num,
      status: json['status'] as String,
      dueAt: DateTime.parse(json['dueAt'] as String),
      paidAt: json['paidAt'] == null
          ? null
          : DateTime.parse(json['paidAt'] as String),
      qrCodeUrl: json['qrCodeUrl'] as String?,
      qrString: json['qrString'] as String?,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
    );
  }
}

class InvoicePage {
  const InvoicePage({required this.invoices, required this.pagination});

  final List<Invoice> invoices;
  final Pagination pagination;

  factory InvoicePage.fromJson(Map<String, dynamic> json) {
    return InvoicePage(
      invoices: (json['invoices'] as List)
          .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: Pagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }
}
