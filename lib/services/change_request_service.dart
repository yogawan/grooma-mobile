import 'package:dio/dio.dart';

import '../models/transaction.dart';
import 'api_exception.dart';

/// Approval workflow for post-transaction corrections. There is no
/// standalone change-request entity — every method here reads/writes
/// through the embedded `transaction.changeRequest` field (doc §0), so
/// every method takes/returns the **transaction** id and the shared
/// [Transaction] model, never a separate id.
///
/// Subscription gating here is `ENFORCED` for both roles (doc §1) —
/// unlike TransactionService, AGENT calls can 402 too. Callers need
/// their own locked-state handling for this module specifically; it
/// must not be merged with the EXEMPT_AGENT assumption used elsewhere.
class ChangeRequestService {
  ChangeRequestService(this._dio);

  final Dio _dio;

  /// HOST or AGENT (own branch). `requestedChanges` must have at least
  /// one non-null field — enforced server-side (400) but also worth
  /// validating client-side so the user gets instant feedback.
  Future<Transaction> submit(
    String transactionId, {
    required String reason,
    String? serviceId,
    String? customerId,
    num? discountAmount,
    ServiceHourType? serviceHourType,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/transactions/$transactionId/change-requests',
        data: {
          'reason': reason,
          'requestedChanges': {
            'serviceId': ?serviceId,
            'customerId': ?customerId,
            'discountAmount': ?discountAmount,
            if (serviceHourType != null)
              'serviceHourType': serviceHourType.apiValue,
          },
        },
      );
      return Transaction.fromJson(
        response.data!['data']['transaction'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// HOST only — the cross-branch "inbox" of PENDING requests (doc §3).
  /// No `branchId` filter is exposed by the backend; group by
  /// `transaction.branch` client-side if needed.
  Future<TransactionPage> listPending({int page = 1, int limit = 20}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/transaction-change-requests',
        queryParameters: {'page': page, 'limit': limit},
      );
      return TransactionPage.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// HOST, or the AGENT who submitted this specific request — not just
  /// any AGENT in the same branch (doc §4, a stricter rule than most
  /// other endpoints). This app's screens primarily read change-request
  /// state through TransactionService.detail instead, which already
  /// carries the same `changeRequest` field for same-branch access;
  /// this method exists for API completeness.
  Future<Transaction> getDetail(String transactionId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/transaction-change-requests/$transactionId',
      );
      return Transaction.fromJson(
        response.data!['data']['transaction'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// HOST only, and never the HOST who submitted the request themself
  /// (403 — separation of duties). A `422` here means the requested
  /// service/customer became unavailable between submit and approve;
  /// the request stays PENDING either way, so the UI should offer
  /// Reject as the way out rather than treating it as a dead end (doc §5).
  Future<Transaction> approve(
    String transactionId, {
    String? reviewNote,
    String? approvalReference,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/transaction-change-requests/$transactionId/approve',
        data: {
          'reviewNote': ?reviewNote,
          'approvalReference': ?approvalReference,
        },
      );
      return Transaction.fromJson(
        response.data!['data']['transaction'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// HOST only. Unlike [approve], `reviewNote` is required here (doc §6).
  Future<Transaction> reject(
    String transactionId, {
    required String reviewNote,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/transaction-change-requests/$transactionId/reject',
        data: {'reviewNote': reviewNote},
      );
      return Transaction.fromJson(
        response.data!['data']['transaction'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
