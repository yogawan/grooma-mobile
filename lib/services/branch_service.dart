import 'package:dio/dio.dart';

import '../models/managed_branch.dart';
import 'api_exception.dart';

/// `/api/v1/branches`. Read is HOST+AGENT (AGENT only ever gets their
/// own branch back), write is HOST only. `ENFORCED` gating applies to
/// both roles (Kelola doc §0) — unlike Services' read side, there's no
/// AGENT exemption here. No pagination on the list endpoint at all.
class BranchService {
  BranchService(this._dio);

  final Dio _dio;

  Future<List<ManagedBranch>> list() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/v1/branches');
      return (response.data!['data']['branches'] as List)
          .map((e) => ManagedBranch.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
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
        '/api/v1/branches',
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
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/branches/$id',
      );
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
        '/api/v1/branches/$id',
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
        '/api/v1/branches/$id/status',
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
