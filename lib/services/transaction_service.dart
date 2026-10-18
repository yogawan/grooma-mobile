import 'dart:math';

import 'package:dio/dio.dart';

import '../models/payment.dart';
import '../models/transaction.dart';
import 'api_exception.dart';

/// POS core: create/list/detail/complete/cancel/receipt + the two
/// `/payments/*` endpoints needed to finish a QRIS flow. Subscription
/// gating here is `EXEMPT_AGENT` (transaction doc §0) — unlike the
/// change-requests module, AGENT calls never 402, only HOST's GET/cancel
/// calls can.
class TransactionService {
  TransactionService(this._dio);

  final Dio _dio;

  /// AGENT only. Generates a fresh Idempotency-Key per call (transaction
  /// doc §1.4) — since this app has no automatic retry-on-failure, every
  /// call here already corresponds to one distinct user-initiated submit
  /// attempt, so "fresh key per call" matches the doc's "one key per
  /// attempt" rule without extra bookkeeping.
  Future<CreateTransactionResult> create({
    String? customerId,
    required String serviceId,
    required PaymentMethod paymentMethod,
    num discountAmount = 0,
    ServiceHourType serviceHourType = ServiceHourType.regular,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/transactions',
        data: {
          'customerId': ?customerId,
          'serviceId': serviceId,
          'paymentMethod': paymentMethod.apiValue,
          'discountAmount': discountAmount,
          'serviceHourType': serviceHourType.apiValue,
        },
        options: Options(headers: {'Idempotency-Key': _generateUuidV4()}),
      );
      return CreateTransactionResult.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<TransactionPage> list({
    int page = 1,
    int limit = 20,
    String? search,
    TransactionPaymentStatus? paymentStatus,
    TransactionStatus? transactionStatus,
    DateTime? from,
    DateTime? to,
    String? branchId,
    String? agentId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/transactions',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null && search.isNotEmpty) 'search': search,
          if (paymentStatus != null) 'paymentStatus': paymentStatus.apiValue,
          if (transactionStatus != null)
            'transactionStatus': transactionStatus.apiValue,
          if (from != null) 'from': from.toIso8601String(),
          if (to != null) 'to': to.toIso8601String(),
          'branchId': ?branchId,
          'agentId': ?agentId,
        },
      );
      return TransactionPage.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<Transaction> detail(String id) =>
      _getTransaction('/api/v1/transactions/$id');

  /// AGENT only.
  Future<Transaction> complete(String id) =>
      _postForTransaction('/api/v1/transactions/$id/complete');

  Future<Transaction> cancel(String id) =>
      _postForTransaction('/api/v1/transactions/$id/cancel');

  /// Has a server-side side effect (increments `receipt.printCount`) on
  /// every call (transaction doc §6) — only call this when actually
  /// about to show/print a receipt, never for a plain preview. Use
  /// [detail] for read-only previews instead.
  Future<Transaction> receipt(String id) =>
      _getTransaction('/api/v1/transactions/$id/receipt');

  /// AGENT only. Also used for retrying after `paymentError` on create,
  /// or after a QR expired — same endpoint for "first" and "retry"
  /// (transaction doc §7.1).
  Future<Payment> createOrRetryQris(String transactionId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/payments/qris',
        data: {'transactionId': transactionId},
      );
      return Payment.fromJson(
        response.data!['data']['payment'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<Payment> getPayment(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/payments/$id',
      );
      return Payment.fromJson(
        response.data!['data']['payment'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<Transaction> _getTransaction(String path) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      return Transaction.fromJson(
        response.data!['data']['transaction'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<Transaction> _postForTransaction(String path) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path);
      return Transaction.fromJson(
        response.data!['data']['transaction'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

String _generateUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx

  String hex(int start, int end) => bytes
      .sublist(start, end)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
