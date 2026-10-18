import 'package:dio/dio.dart';

import '../models/profile.dart';
import '../models/user.dart';
import 'api_exception.dart';

/// `/api/v1/users` — HOST only, every endpoint (Kelola doc §2). Reuses
/// [UserProfile] directly: the doc confirms this endpoint's item shape
/// is identical to `GET /profile`'s (`id`, not `_id`; `branch` as
/// `{id, name}`), so no separate model is needed.
///
/// There is deliberately no password-reset method here — the backend
/// has no such endpoint (Kelola doc §2.4): the only password-change
/// path requires the user to be logged in and know their old password.
/// If a HOST needs to recover a locked-out AGENT, the only real option
/// today is deactivate + recreate, not a reset flow.
class StaffService {
  StaffService(this._dio);

  final Dio _dio;

  Future<List<UserProfile>> list() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/v1/users');
      return (response.data!['data']['users'] as List)
          .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// `branchId` is required when `role` is AGENT and must be omitted
  /// when `role` is HOST — enforced server-side as a 400 either way
  /// (Kelola doc §2.2); the form is expected to pre-validate this so
  /// the user doesn't hit a confusing 400.
  Future<UserProfile> create({
    required String username,
    required String password,
    required String name,
    required UserRole role,
    String? branchId,
    String? phone,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/users',
        data: {
          'username': username,
          'password': password,
          'name': name,
          'role': role.apiValue,
          'branch': role == UserRole.agent ? branchId : null,
          'phone': ?phone,
        },
      );
      return _staffFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<UserProfile> detail(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/users/$id',
      );
      return _staffFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// `username`/`password` aren't accepted here at all (doc §2.4).
  /// When `role` is provided, `branch` is always sent alongside it
  /// (explicitly `null` for HOST) rather than omitted — omitting it
  /// while switching AGENT→HOST would leave the old branch in place
  /// server-side and fail the role/branch mutual-exclusion rule.
  Future<UserProfile> update(
    String id, {
    String? name,
    UserRole? role,
    String? branchId,
    String? phone,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/users/$id',
        data: {
          'name': ?name,
          if (role != null) 'role': role.apiValue,
          if (role != null) 'branch': role == UserRole.agent ? branchId : null,
          'phone': ?phone,
        },
      );
      return _staffFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// Enum string, like Branch — **not** boolean like Service (Kelola
  /// doc §0's explicitly-called-out inconsistency).
  Future<UserProfile> setStatus(String id, UserStatus status) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/users/$id/status',
        data: {'status': status.apiValue},
      );
      return _staffFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  UserProfile _staffFrom(Map<String, dynamic>? body) {
    final json = body?['data']?['user'] as Map<String, dynamic>?;
    if (json == null) {
      throw ApiException('INVALID_RESPONSE', 'Respons server tidak valid.');
    }
    return UserProfile.fromJson(json);
  }
}
