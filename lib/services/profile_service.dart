import 'package:dio/dio.dart';

import '../models/profile.dart';
import 'api_exception.dart';

/// Unlike dashboard/*, these two endpoints are `EXEMPT_ALL` from HOST
/// subscription gating (profile doc §0) — they never 402, so callers
/// don't need a locked-state branch like DashboardScreen does.
class ProfileService {
  ProfileService(this._dio);

  final Dio _dio;

  Future<UserProfile> getProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/profile');
      return _userFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// Only `name`/`phone` are accepted by the backend — anything else is
  /// rejected with 400 (profile doc §2).
  Future<UserProfile> updateProfile({
    required String name,
    required String phone,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/profile',
        data: {'name': name, 'phone': phone},
      );
      return _userFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  UserProfile _userFrom(Map<String, dynamic>? body) {
    final userJson = body?['data']?['user'] as Map<String, dynamic>?;
    if (userJson == null) {
      throw ApiException('INVALID_RESPONSE', 'Respons server tidak valid.');
    }
    return UserProfile.fromJson(userJson);
  }
}
