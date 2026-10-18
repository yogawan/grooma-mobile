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
class DashboardService {
  DashboardService(this._dio);

  final Dio _dio;

  Future<DashboardSummary> summary({
    DashboardPeriod period = DashboardPeriod.month,
  }) async {
    final data = await _getData('/api/v1/dashboard/summary', {
      'period': period.apiValue,
    });
    return DashboardSummary.fromJson(data['summary'] as Map<String, dynamic>);
  }

  Future<RevenueData> revenue({
    DashboardPeriod period = DashboardPeriod.month,
  }) async {
    final data = await _getData('/api/v1/dashboard/revenue', {
      'period': period.apiValue,
    });
    return RevenueData.fromJson(data['revenue'] as Map<String, dynamic>);
  }

  Future<List<ServiceStat>> services({
    DashboardPeriod period = DashboardPeriod.month,
  }) async {
    final data = await _getData('/api/v1/dashboard/services', {
      'period': period.apiValue,
    });
    return (data['services'] as List)
        .map((e) => ServiceStat.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AgentStat>> agents({
    DashboardPeriod period = DashboardPeriod.month,
  }) async {
    final data = await _getData('/api/v1/dashboard/agents', {
      'period': period.apiValue,
    });
    return (data['agents'] as List)
        .map((e) => AgentStat.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TransactionStats> transactionsStats({
    DashboardPeriod period = DashboardPeriod.month,
  }) async {
    final data = await _getData('/api/v1/dashboard/transactions', {
      'period': period.apiValue,
    });
    return TransactionStats.fromJson(data['stats'] as Map<String, dynamic>);
  }

  Future<List<InventoryLowStockItem>> inventory() async {
    final data = await _getData('/api/v1/dashboard/inventory', const {});
    return (data['inventory'] as List)
        .map((e) => InventoryLowStockItem.fromJson(e as Map<String, dynamic>))
        .toList();
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
