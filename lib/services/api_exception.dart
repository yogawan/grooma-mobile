import 'package:dio/dio.dart';

/// Mirrors the `{ success: false, error: { code, message } }` shape used by
/// every Grooma API error response (auth doc §3, dashboard doc §4).
class ApiException implements Exception {
  ApiException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ApiException($code, $message)';
}

ApiException mapDioError(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['error'] is Map) {
    final error = data['error'] as Map;
    return ApiException(
      (error['code'] as String?) ?? 'UNKNOWN_ERROR',
      (error['message'] as String?) ?? 'Terjadi kesalahan.',
    );
  }
  return ApiException('NETWORK_ERROR', 'Tidak dapat terhubung ke server.');
}
