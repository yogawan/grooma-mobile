import 'package:dio/dio.dart';

import '../models/managed_branch.dart';
import 'api_exception.dart';

/// `/api/v1/branches`. Read is HOST+AGENT (AGENT only ever gets their
/// own branch back), write is HOST only. `ENFORCED` gating applies to
/// both roles (Kelola doc §0) — unlike Services' read side, there's no
/// AGENT exemption here. Paginated like every other list endpoint
/// (AUTH doc §2.1).
class BranchService {
  BranchService(this._dio);

  final Dio _dio;

  /// Paginated now (AUTH doc §2.1.4) — default 20 rows, no longer the
  /// full branch list in one response.
  Future<BranchPage> list({int page = 1, int limit = 20}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/branches',
        queryParameters: {'page': page, 'limit': limit},
      );
      return BranchPage.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// For pickers that need the complete branch list (e.g. the branch
  /// dropdown on the staff form) rather than one page of it — AUTH doc
  /// §2.1.4 flags exactly this kind of picker as the most likely to
  /// silently break now that `/branches` defaults to 20 rows. Walks
  /// pages at the max `limit` (100) until `totalPages` is exhausted.
  Future<List<ManagedBranch>> listAll() async {
    final branches = <ManagedBranch>[];
    var page = 1;
    while (true) {
      final result = await list(page: page, limit: 100);
      branches.addAll(result.branches);
      if (!result.pagination.hasNextPage) break;
      page++;
    }
    return branches;
  }

  /// HOST only. `branchCode` is immutable once created (doc §1.2).
  Future<ManagedBranch> create({
    required String branchCode,
    required String name,
    String? address,
    String? phone,
    String timezone = 'Asia/Jakarta',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/branches',
        data: {
          'branchCode': branchCode,
          'name': name,
          'address': ?address,
          'phone': ?phone,
          'timezone': timezone,
        },
      );
      return _branchFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<ManagedBranch> detail(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/branches/$id');
      return _branchFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// HOST only. `branchCode` isn't accepted here at all (doc §1.4).
  Future<ManagedBranch> update(
    String id, {
    String? name,
    String? address,
    String? phone,
    String? timezone,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/branches/$id',
        data: {
          'name': ?name,
          'address': ?address,
          'phone': ?phone,
          'timezone': ?timezone,
        },
      );
      return _branchFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// HOST only. Enum string, like Staff — **not** boolean like Service
  /// (Kelola doc §0, the cross-module inconsistency called out
  /// explicitly). Mixing this up with [ServiceCatalogService.setActive]
  /// is exactly the bug the doc warns about.
  Future<ManagedBranch> setStatus(String id, BranchStatus status) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/branches/$id/status',
        data: {'status': status.apiValue},
      );
      return _branchFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  ManagedBranch _branchFrom(Map<String, dynamic>? body) {
    final json = body?['data']?['branch'] as Map<String, dynamic>?;
    if (json == null) {
      throw ApiException('INVALID_RESPONSE', 'Respons server tidak valid.');
    }
    return ManagedBranch.fromJson(json);
  }
}
