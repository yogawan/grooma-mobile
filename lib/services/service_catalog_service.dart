import 'package:dio/dio.dart';

import '../models/service_item.dart';
import 'api_exception.dart';

/// `/api/v1/services`. Read is `EXEMPT_AGENT` (AGENT can always browse
/// the catalog to build a transaction, even on a lapsed HOST
/// subscription); write is HOST-only and `ENFORCED` (Kelola doc §0).
/// The list endpoint's content itself also differs by role server-side
/// — HOST sees every service including inactive ones, AGENT only ever
/// sees active ones — with no client-side filtering needed either way.
class ServiceCatalogService {
  ServiceCatalogService(this._dio);

  final Dio _dio;

  /// Paginated now (AUTH doc §2.1.4) — default 20 rows, no longer the
  /// full catalog in one response.
  Future<ServicePage> list({int page = 1, int limit = 20}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/services',
        queryParameters: {'page': page, 'limit': limit},
      );
      return ServicePage.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// For the "pilih layanan" picker in the AGENT create-transaction flow
  /// — `/services` has no `search` param (Kelola doc §3.1), and that
  /// same doc flags this exact picker as the one that silently loses
  /// services past row 20 if it only fetches page 1. Walks pages at the
  /// max `limit` (100) until `totalPages` is exhausted, then the picker
  /// filters the full in-memory list by name/code as the user types.
  Future<List<ServiceItem>> listAll() async {
    final services = <ServiceItem>[];
    var page = 1;
    while (true) {
      final result = await list(page: page, limit: 100);
      services.addAll(result.services);
      if (!result.pagination.hasNextPage) break;
      page++;
    }
    return services;
  }

  /// Unlike the list endpoint, detail has no `isActive` filter at all
  /// — an inactive service's id still resolves here (doc §3.2). Don't
  /// treat a successful fetch as "this service is usable"; check
  /// `isActive` on the result.
  Future<ServiceItem> detail(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/services/$id');
      return _serviceFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// HOST only. `ownerPercentage + employeePercentage` must total
  /// exactly 100 (doc §3.3) — not validated client-side here, that's
  /// the form's job via a single slider that derives the other share.
  Future<ServiceItem> create({
    required String serviceCode,
    required String name,
    String? description,
    String? category,
    required num price,
    int durationMinutes = 30,
    required RevenueSharing revenueSharing,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/services',
        data: {
          'serviceCode': serviceCode,
          'name': name,
          'description': ?description,
          'category': ?category,
          'price': price,
          'durationMinutes': durationMinutes,
          'revenueSharing': revenueSharing.toJson(),
        },
      );
      return _serviceFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// HOST only. `serviceCode` immutable. `revenueSharing`, if sent at
  /// all, must include both percentages — the backend doesn't accept a
  /// partial update of just one side (doc §3.3), so this never sends
  /// one without the other.
  Future<ServiceItem> update(
    String id, {
    String? name,
    String? description,
    String? category,
    num? price,
    int? durationMinutes,
    RevenueSharing? revenueSharing,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/services/$id',
        data: {
          'name': ?name,
          'description': ?description,
          'category': ?category,
          'price': ?price,
          'durationMinutes': ?durationMinutes,
          if (revenueSharing != null) 'revenueSharing': revenueSharing.toJson(),
        },
      );
      return _serviceFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// Boolean, **not** an enum string like Branch/Staff (Kelola doc §0's
  /// explicitly-called-out inconsistency — see
  /// [BranchService.setStatus]/[StaffService.setStatus]).
  Future<ServiceItem> setActive(String id, bool isActive) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/services/$id/status',
        data: {'isActive': isActive},
      );
      return _serviceFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  ServiceItem _serviceFrom(Map<String, dynamic>? body) {
    final json = body?['data']?['service'] as Map<String, dynamic>?;
    if (json == null) {
      throw ApiException('INVALID_RESPONSE', 'Respons server tidak valid.');
    }
    return ServiceItem.fromJson(json);
  }
}
