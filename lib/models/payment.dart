/// Payment-gateway status. Deliberately a separate enum from
/// [TransactionPaymentStatus] in transaction.dart — this one has
/// `EXPIRED`, which the transaction's own `paymentStatus` never does.
/// POS core doc §7.2: when a Payment expires, `Transaction.paymentStatus`
/// stays `PENDING`, it does not become `EXPIRED` — the two fields are
/// not kept in sync.
enum PaymentGatewayStatus {
  pending,
  paid,
  failed,
  expired,
  refunded;

  static PaymentGatewayStatus fromApi(String value) {
    switch (value) {
      case 'PENDING':
        return PaymentGatewayStatus.pending;
      case 'PAID':
        return PaymentGatewayStatus.paid;
      case 'FAILED':
        return PaymentGatewayStatus.failed;
      case 'EXPIRED':
        return PaymentGatewayStatus.expired;
      case 'REFUNDED':
        return PaymentGatewayStatus.refunded;
      default:
        throw FormatException('Unknown payment gateway status: $value');
    }
  }

  String get label => switch (this) {
    PaymentGatewayStatus.pending => 'Menunggu Pembayaran',
    PaymentGatewayStatus.paid => 'Berhasil Dibayar',
    PaymentGatewayStatus.failed => 'Gagal',
    PaymentGatewayStatus.expired => 'Kedaluwarsa',
    PaymentGatewayStatus.refunded => 'Direfund',
  };
}

class Payment {
  const Payment({
    required this.id,
    required this.transactionId,
    required this.status,
    required this.grossAmount,
    this.qrCodeUrl,
    this.qrString,
    this.expiresAt,
    this.paidAt,
  });

  final String id;
  final String transactionId;
  final PaymentGatewayStatus status;
  final num grossAmount;
  final String? qrCodeUrl;
  final String? qrString;
  final DateTime? expiresAt;
  final DateTime? paidAt;

  factory Payment.fromJson(Map<String, dynamic> json) {
    final transactionRaw = json['transaction'];
    final transactionId = transactionRaw is String
        ? transactionRaw
        : (transactionRaw as Map<String, dynamic>)['_id'] as String;

    return Payment(
      id: json['_id'] as String,
      transactionId: transactionId,
      status: PaymentGatewayStatus.fromApi(json['status'] as String),
      grossAmount: json['grossAmount'] as num,
      qrCodeUrl: json['qrCodeUrl'] as String?,
      qrString: json['qrString'] as String?,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      paidAt: json['paidAt'] == null
          ? null
          : DateTime.parse(json['paidAt'] as String),
    );
  }
}
