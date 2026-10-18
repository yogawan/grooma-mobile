import 'package:dio/dio.dart';

import '../models/user.dart';
import 'api_exception.dart';

class AuthService {
  AuthService(this._dio);

  final Dio _dio;

  Future<User> login(String username, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {'username': username.trim().toLowerCase(), 'password': password},
      );
      return _userFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// Used on app start to silently resume a session from the persisted
  /// cookie jar. Throws [ApiException] with code `UNAUTHENTICATED` when
  /// there is no valid session.
  Future<User> me() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/v1/auth/me');
      return _userFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/api/v1/auth/logout');
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  User _userFrom(Map<String, dynamic>? body) {
    final userJson = body?['data']?['user'] as Map<String, dynamic>?;
    if (userJson == null) {
      throw ApiException('INVALID_RESPONSE', 'Respons server tidak valid.');
    }
    return User.fromJson(userJson);
  }
}
