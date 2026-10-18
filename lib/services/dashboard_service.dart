import 'package:dio/dio.dart';

import '../models/dashboard.dart';
import 'api_exception.dart';

/// All 6 endpoints are GET, gated by the same session cookie as the auth
/// module, and gated as a whole by HOST subscription status (dashboard
/// doc §0, §4: a `PAYMENT_REQUIRED` 402 applies uniformly here for both
/// HOST and AGENT, unlike most other modules).
///
/// `branchId`/`agentId` HOST filters and the `compare`/`threshold` params
/// are intentionally not exposed yet — scope is always whatever the
/// session resolves to by default, matching the "simple UI first" pass.
///
/// Every query map here is hand-built per method, deliberately — this
/// module's schema is strict and `page`/`limit` are NOT interchangeable
/// across its 6 endpoints (dashboard doc §2): `limit` is only valid on
/// `services`/`agents`/`inventory`, `page` is invalid everywhere here
/// (there's no pagination concept, only a ranking/worklist depth — see
/// [DashboardMeta]), and sending either where it doesn't belong is a
/// `400`. Don't introduce a shared "attach page/limit" request helper
/// that would apply to this service too.
class DashboardService {
  DashboardService(this._dio);

  final Dio _dio;

  Future<DashboardSummary> summary({
    DashboardPeriod period = DashboardPeriod.month,
  }) async {
    final data = await _getData('/dashboard/summary', {
      'period': period.apiValue,
    });
    return DashboardSummary.fromJson(data['summary'] as Map<String, dynamic>);
  }

  /// `from`/`to` (and the new too-wide-a-range `400`, doc §3.2) aren't
  /// exposed here — this app only ever sends `period` presets, whose
  /// default ranges are always narrow enough to never hit that limit.
  Future<RevenueData> revenue({
    DashboardPeriod period = DashboardPeriod.month,
  }) async {
    final data = await _getData('/dashboard/revenue', {
      'period': period.apiValue,
    });
    return RevenueData.fromJson(data['revenue'] as Map<String, dynamic>);
  }

  /// `limit` default/max match the backend's own (doc §3.3): ranking
  /// depth, not a page — there is still no `page` on this endpoint.
  Future<ServiceStatsResult> services({
    DashboardPeriod period = DashboardPeriod.month,
    int limit = 10,
  }) async {
    final data = await _getData('/dashboard/services', {
      'period': period.apiValue,
      'limit': limit,
    });
    return ServiceStatsResult.fromJson(data);
  }

  /// `limit` default/max match the backend's own (doc §3.4).
  Future<AgentStatsResult> agents({
    DashboardPeriod period = DashboardPeriod.month,
    int limit = 50,
  }) async {
    final data = await _getData('/dashboard/agents', {
      'period': period.apiValue,
      'limit': limit,
    });
    return AgentStatsResult.fromJson(data);
  }

  Future<TransactionStats> transactionsStats({
    DashboardPeriod period = DashboardPeriod.month,
  }) async {
    final data = await _getData('/dashboard/transactions', {
      'period': period.apiValue,
    });
    return TransactionStats.fromJson(data['stats'] as Map<String, dynamic>);
  }

  /// `limit` default/max match the backend's own (doc §3.6) —
  /// `meta.total` here is the one worth surfacing in the UI: unlike the
  /// other two, this is a restock worklist, not a ranking, so a silent
  /// truncation has real operational consequences.
  Future<LowStockResult> inventory({int limit = 20}) async {
    final data = await _getData('/dashboard/inventory', {'limit': limit});
    return LowStockResult.fromJson(data);
  }

  Future<Map<String, dynamic>> _getData(
    String path,
    Map<String, dynamic> query,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw ApiException('INVALID_RESPONSE', 'Respons server tidak valid.');
      }
      return data;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
