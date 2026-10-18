import 'entity_ref.dart';
import 'pagination.dart';
import 'payment.dart';

/// `POST /transactions` response shape (POS core doc §1): the
/// transaction is always saved regardless of what happens with
/// `payment`/`paymentError` — a non-null `paymentError` on a QRIS
/// transaction means "sale recorded, QR failed", never "transaction
/// failed". Callers must check `paymentError` before assuming `payment`
/// is usable.
class CreateTransactionResult {
  const CreateTransactionResult({
    required this.transaction,
    required this.payment,
    required this.paymentError,
  });

  final Transaction transaction;
  final Payment? payment;
  final String? paymentError;

  factory CreateTransactionResult.fromJson(Map<String, dynamic> json) {
    return CreateTransactionResult(
      transaction: Transaction.fromJson(
        json['transaction'] as Map<String, dynamic>,
      ),
      payment: json['payment'] == null
          ? null
          : Payment.fromJson(json['payment'] as Map<String, dynamic>),
      paymentError: json['paymentError'] as String?,
    );
  }
}

/// Shared by TransactionService.list and ChangeRequestService.listPending
/// — both endpoints return `{ transactions: [...], pagination: {...} }`
/// (change-requests doc §3: "Key array-nya `transactions`, bukan
/// `changeRequests`").
class TransactionPage {
  const TransactionPage({required this.transactions, required this.pagination});

  final List<Transaction> transactions;
  final Pagination pagination;

  factory TransactionPage.fromJson(Map<String, dynamic> json) {
    return TransactionPage(
      transactions: (json['transactions'] as List)
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: Pagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }
}

enum PaymentMethod {
  cash,
  qris;

  static PaymentMethod fromApi(String value) {
    switch (value) {
      case 'CASH':
        return PaymentMethod.cash;
      case 'QRIS':
        return PaymentMethod.qris;
      default:
        throw FormatException('Unknown payment method: $value');
    }
  }

  String get apiValue => this == PaymentMethod.cash ? 'CASH' : 'QRIS';
  String get label => this == PaymentMethod.cash ? 'Cash' : 'QRIS';
}

/// Transaction-level payment status. Deliberately a separate enum from
/// [PaymentGatewayStatus] in payment.dart — the two have different
/// members (this one has no `EXPIRED`; that one does — transaction doc
/// §9 / change-requests doc §7.2 both warn these must not be conflated).
enum TransactionPaymentStatus {
  pending,
  paid,
  failed,
  refunded,
  partiallyRefunded;

  static TransactionPaymentStatus fromApi(String value) {
    switch (value) {
      case 'PENDING':
        return TransactionPaymentStatus.pending;
      case 'PAID':
        return TransactionPaymentStatus.paid;
      case 'FAILED':
        return TransactionPaymentStatus.failed;
      case 'REFUNDED':
        return TransactionPaymentStatus.refunded;
      case 'PARTIALLY_REFUNDED':
        return TransactionPaymentStatus.partiallyRefunded;
      default:
        throw FormatException('Unknown payment status: $value');
    }
  }

  String get apiValue => switch (this) {
    TransactionPaymentStatus.pending => 'PENDING',
    TransactionPaymentStatus.paid => 'PAID',
    TransactionPaymentStatus.failed => 'FAILED',
    TransactionPaymentStatus.refunded => 'REFUNDED',
    TransactionPaymentStatus.partiallyRefunded => 'PARTIALLY_REFUNDED',
  };

  String get label => switch (this) {
    TransactionPaymentStatus.pending => 'Menunggu Bayar',
    TransactionPaymentStatus.paid => 'Lunas',
    TransactionPaymentStatus.failed => 'Gagal',
    TransactionPaymentStatus.refunded => 'Direfund',
    TransactionPaymentStatus.partiallyRefunded => 'Direfund Sebagian',
  };
}

enum TransactionStatus {
  pending,
  inProgress,
  completed,
  cancelled;

  static TransactionStatus fromApi(String value) {
    switch (value) {
      case 'PENDING':
        return TransactionStatus.pending;
      case 'IN_PROGRESS':
        return TransactionStatus.inProgress;
      case 'COMPLETED':
        return TransactionStatus.completed;
      case 'CANCELLED':
        return TransactionStatus.cancelled;
      default:
        throw FormatException('Unknown transaction status: $value');
    }
  }

  String get apiValue => switch (this) {
    TransactionStatus.pending => 'PENDING',
    TransactionStatus.inProgress => 'IN_PROGRESS',
    TransactionStatus.completed => 'COMPLETED',
    TransactionStatus.cancelled => 'CANCELLED',
  };

  // `IN_PROGRESS` is in the enum but no endpoint ever sets it (POS core
  // doc §9) — the only real transitions are PENDING -> COMPLETED/CANCELLED.
  String get label => switch (this) {
    TransactionStatus.pending => 'Pending',
    TransactionStatus.inProgress => 'Dikerjakan',
    TransactionStatus.completed => 'Selesai',
    TransactionStatus.cancelled => 'Dibatalkan',
  };
}

enum ServiceHourType {
  regular,
  overtime;

  static ServiceHourType fromApi(String value) {
    switch (value) {
      case 'REGULAR':
        return ServiceHourType.regular;
      case 'OVERTIME':
        return ServiceHourType.overtime;
      default:
        throw FormatException('Unknown service hour type: $value');
    }
  }

  String get apiValue =>
      this == ServiceHourType.regular ? 'REGULAR' : 'OVERTIME';
  String get label => this == ServiceHourType.regular ? 'Reguler' : 'Lembur';
}

enum ChangeRequestStatus {
  none,
  pending,
  approved,
  rejected;

  static ChangeRequestStatus fromApi(String value) {
    switch (value) {
      case 'NONE':
        return ChangeRequestStatus.none;
      case 'PENDING':
        return ChangeRequestStatus.pending;
      case 'APPROVED':
        return ChangeRequestStatus.approved;
      case 'REJECTED':
        return ChangeRequestStatus.rejected;
      default:
        throw FormatException('Unknown change request status: $value');
    }
  }

  String get label => switch (this) {
    ChangeRequestStatus.none => 'Tidak ada pengajuan',
    ChangeRequestStatus.pending => 'Menunggu Persetujuan',
    ChangeRequestStatus.approved => 'Disetujui',
    ChangeRequestStatus.rejected => 'Ditolak',
  };
}

class ServiceSnapshot {
  const ServiceSnapshot({
    required this.name,
    required this.price,
    required this.ownerPercentage,
    required this.employeePercentage,
  });

  final String name;
  final num price;
  final num ownerPercentage;
  final num employeePercentage;

  factory ServiceSnapshot.fromJson(Map<String, dynamic> json) {
    return ServiceSnapshot(
      name: json['name'] as String,
      price: json['price'] as num,
      ownerPercentage: json['ownerPercentage'] as num,
      employeePercentage: json['employeePercentage'] as num,
    );
  }
}

class ReceiptInfo {
  const ReceiptInfo({
    required this.printed,
    required this.printCount,
    this.printedAt,
  });

  final bool printed;
  final int printCount;
  final DateTime? printedAt;

  factory ReceiptInfo.fromJson(Map<String, dynamic> json) {
    return ReceiptInfo(
      printed: json['printed'] as bool,
      printCount: json['printCount'] as int,
      printedAt: json['printedAt'] == null
          ? null
          : DateTime.parse(json['printedAt'] as String),
    );
  }
}

/// What was asked for in a change request. `customerId` being
/// explicitly `null` (vs. simply absent) is a valid, distinct request
/// ("make this transaction have no customer") per change-requests doc
/// §2 — the edit form in this app doesn't expose that specific case yet
/// (only "leave customer unchanged" or "set a new customer id"), so we
/// only ever read it here, never build an explicit-null request.
class RequestedChanges {
  const RequestedChanges({
    this.serviceId,
    this.customerId,
    this.discountAmount,
    this.serviceHourType,
  });

  final String? serviceId;
  final String? customerId;
  final num? discountAmount;
  final ServiceHourType? serviceHourType;

  factory RequestedChanges.fromJson(Map<String, dynamic> json) {
    return RequestedChanges(
      serviceId: json['serviceId'] as String?,
      customerId: json['customerId'] as String?,
      discountAmount: json['discountAmount'] as num?,
      serviceHourType: json['serviceHourType'] == null
          ? null
          : ServiceHourType.fromApi(json['serviceHourType'] as String),
    );
  }
}

/// Embedded directly on [Transaction] — there is no standalone change
/// request entity/id (change-requests doc §0, §7: "jangan bangun model
/// ChangeRequest dengan id sendiri").
class ChangeRequestInfo {
  const ChangeRequestInfo({
    required this.status,
    this.requestedBy,
    this.reason,
    this.requestedChanges,
    this.requestedAt,
    this.reviewedBy,
    this.reviewNote,
    this.reviewedAt,
  });

  final ChangeRequestStatus status;
  final EntityRef? requestedBy;
  final String? reason;
  final RequestedChanges? requestedChanges;
  final DateTime? requestedAt;
  final EntityRef? reviewedBy;
  final String? reviewNote;
  final DateTime? reviewedAt;

  factory ChangeRequestInfo.fromJson(Map<String, dynamic> json) {
    return ChangeRequestInfo(
      status: ChangeRequestStatus.fromApi(json['status'] as String),
      requestedBy: json['requestedBy'] == null
          ? null
          : EntityRef.fromDynamic(json['requestedBy']),
      reason: json['reason'] as String?,
      requestedChanges: json['requestedChanges'] == null
          ? null
          : RequestedChanges.fromJson(
              json['requestedChanges'] as Map<String, dynamic>,
            ),
      requestedAt: json['requestedAt'] == null
          ? null
          : DateTime.parse(json['requestedAt'] as String),
      reviewedBy: json['reviewedBy'] == null
          ? null
          : EntityRef.fromDynamic(json['reviewedBy']),
      reviewNote: json['reviewNote'] as String?,
      reviewedAt: json['reviewedAt'] == null
          ? null
          : DateTime.parse(json['reviewedAt'] as String),
    );
  }
}

/// One unified model for every transaction shape across both docs
/// (create/list/detail/complete/cancel/receipt/change-request
/// submit/queue/detail/approve/reject) — see [EntityRef] for how the
/// raw-id-vs-populated split is handled. `service` is always a raw id
/// (POS core doc §9: the display name always comes from
/// [serviceSnapshot], never from populating `service`).
///
/// A few fields (`subtotal`, `discountAmount`, `ownerRevenue`,
/// `employeeRevenue`, `changeRequest`, `receipt`) are parsed
/// defensively as optional/defaulted: the list-endpoint example in the
/// docs shows a trimmed item shape, and it's not clear whether that's
/// a real projection or just an abbreviated example — tolerating
/// absence costs nothing and avoids a crash either way.
class Transaction {
  const Transaction({
    required this.id,
    required this.transactionCode,
    required this.branch,
    required this.agent,
    required this.customer,
    required this.serviceId,
    required this.serviceSnapshot,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.transactionStatus,
    required this.serviceHourType,
    required this.subtotal,
    required this.discountAmount,
    required this.total,
    required this.ownerRevenue,
    required this.employeeRevenue,
    required this.pointsEarned,
    required this.paidAt,
    required this.completedAt,
    required this.changeRequest,
    required this.receipt,
    required this.createdAt,
  });

  final String id;
  final String transactionCode;
  final EntityRef branch;
  final EntityRef agent;
  final EntityRef? customer;
  final String serviceId;
  final ServiceSnapshot serviceSnapshot;
  final PaymentMethod paymentMethod;
  final TransactionPaymentStatus paymentStatus;
  final TransactionStatus transactionStatus;
  final ServiceHourType serviceHourType;
  final num subtotal;
  final num discountAmount;
  final num total;
  final num ownerRevenue;
  final num employeeRevenue;
  final int pointsEarned;
  final DateTime? paidAt;
  final DateTime? completedAt;
  final ChangeRequestInfo changeRequest;
  final ReceiptInfo? receipt;
  final DateTime createdAt;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['_id'] as String,
      transactionCode: json['transactionCode'] as String,
      branch: EntityRef.fromDynamic(json['branch']),
      agent: EntityRef.fromDynamic(json['agent']),
      customer: json['customer'] == null
          ? null
          : EntityRef.fromDynamic(json['customer']),
      serviceId: json['service'] as String,
      serviceSnapshot: ServiceSnapshot.fromJson(
        json['serviceSnapshot'] as Map<String, dynamic>,
      ),
      paymentMethod: PaymentMethod.fromApi(json['paymentMethod'] as String),
      paymentStatus: TransactionPaymentStatus.fromApi(
        json['paymentStatus'] as String,
      ),
      transactionStatus: TransactionStatus.fromApi(
        json['transactionStatus'] as String,
      ),
      serviceHourType: ServiceHourType.fromApi(
        json['serviceHourType'] as String,
      ),
      subtotal: (json['subtotal'] as num?) ?? 0,
      discountAmount: (json['discountAmount'] as num?) ?? 0,
      total: json['total'] as num,
      ownerRevenue: (json['ownerRevenue'] as num?) ?? 0,
      employeeRevenue: (json['employeeRevenue'] as num?) ?? 0,
      pointsEarned: (json['pointsEarned'] as int?) ?? 0,
      paidAt: json['paidAt'] == null
          ? null
          : DateTime.parse(json['paidAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      changeRequest: json['changeRequest'] == null
          ? const ChangeRequestInfo(status: ChangeRequestStatus.none)
          : ChangeRequestInfo.fromJson(
              json['changeRequest'] as Map<String, dynamic>,
            ),
      receipt: json['receipt'] == null
          ? null
          : ReceiptInfo.fromJson(json['receipt'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
