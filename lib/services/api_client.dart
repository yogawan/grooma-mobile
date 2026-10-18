import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Wraps a [Dio] instance wired for Grooma's session-cookie auth model
/// (see docs/AUTH-MOBILE-API-INTEGRATION.md §1-2). One instance is created
/// at app start and reused for every request.
class ApiClient {
  ApiClient._(this.dio);

  final Dio dio;

  /// Invoked whenever any request comes back 401, so the app can clear
  /// local auth state and fall back to the login screen.
  VoidCallback? onUnauthenticated;

  static Future<ApiClient> create() async {
    const baseUrl = String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'http://localhost:3000',
    );

    final appDir = await getApplicationDocumentsDirectory();
    final cookieJar = PersistCookieJar(
      storage: FileStorage('${appDir.path}/.cookies/'),
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(CookieManager(cookieJar));

    final client = ApiClient._(dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            client.onUnauthenticated?.call();
          }
          handler.next(error);
        },
      ),
    );

    return client;
  }
}
