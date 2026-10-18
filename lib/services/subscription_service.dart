import 'package:dio/dio.dart';

import '../models/subscription.dart';
import 'api_exception.dart';

/// `/api/v1/subscription*` — HOST only, entirely read-only (Kelola doc
/// §4: there is no `POST` anywhere in this module; "paying" an invoice
/// means showing the QR that's already attached to it, not calling an
/// endpoint). `EXEMPT_ALL` gating — this never 402s, since it's the one
/// escape hatch a lapsed HOST needs to be able to reach.
///
/// There is deliberately no `invoiceDetail(id)` method: `GET
/// /subscription/invoices/:id` is confirmed permanently broken (always
/// `403`, even for the invoice's rightful owner — doc §4.4). Everything
/// a detail screen would need (`amount`, `status`, `dueAt`,
/// `qrCodeUrl`, `qrString`, `expiresAt`) is already on each item from
/// [listInvoices]; render from that instead of adding a call that's
/// guaranteed to fail.
class SubscriptionService {
  SubscriptionService(this._dio);

  final Dio _dio;

  /// Returns `null` when the deployment has no subscription record at
  /// all — doc §4.2 is explicit that this is normal full-access
  /// behavior, not an error or a locked state.
  Future<Subscription?> getStatus() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/subscription');
      final json =
          response.data?['data']?['subscription'] as Map<String, dynamic>?;
      return json == null ? null : Subscription.fromJson(json);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// `status` is now genuinely applied server-side (fixed 2026-10-19,
  /// doc §4.3 — it used to be validated then silently discarded).
  /// Sending it narrows `pagination.total` to just that status too, so
  /// don't treat `total` from a filtered call as "all invoices".
  Future<InvoicePage> listInvoices({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/subscription/invoices',
        queryParameters: {'page': page, 'limit': limit, 'status': ?status},
      );
      return InvoicePage.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
