import 'package:dio/dio.dart';

import '../models/customer.dart';
import 'api_exception.dart';

/// No branch concept anywhere in this module (customer doc §0) — every
/// HOST/AGENT sees and can edit the full cross-branch customer base,
/// unlike Transactions/Inventory. 4 of 5 endpoints are `EXEMPT_AGENT`;
/// only [setActive] is HOST-only and fully `ENFORCED`.
class CustomerService {
  CustomerService(this._dio);

  final Dio _dio;

  /// No pagination on this endpoint at all (doc §2) — omitting
  /// `search` returns the entire customer base in one response. The UI
  /// is responsible for not calling this without a non-trivial query;
  /// this method doesn't second-guess that policy itself.
  Future<List<Customer>> search({String? search}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/customers',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      return (response.data!['data']['customers'] as List)
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// A `201` here doesn't always mean a new record — a `phone` match
  /// against an existing customer returns that existing customer
  /// instead (doc §3). Always render the response, never the form
  /// input, for exactly this reason.
  Future<Customer> create({
    required String name,
    String? phone,
    String? email,
    CustomerGender? gender,
    DateTime? birthDate,
    String? address,
    String? notes,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/customers',
        data: {
          'name': name,
          'phone': ?phone,
          'email': ?email,
          if (gender != null) 'gender': gender.apiValue,
          if (birthDate != null) 'birthDate': birthDate.toIso8601String(),
          'address': ?address,
          'notes': ?notes,
        },
      );
      return _customerFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<Customer> detail(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/customers/$id',
      );
      return _customerFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// Backend accepts the 5 privileged fields from any role here, even
  /// though only HOST can ever read them back (doc §5) — callers
  /// (specifically the AGENT edit form) are responsible for simply
  /// never populating those fields, since the backend won't reject them.
  Future<Customer> update(
    String id, {
    String? name,
    String? phone,
    String? email,
    CustomerGender? gender,
    DateTime? birthDate,
    String? address,
    String? notes,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/customers/$id',
        data: {
          'name': ?name,
          'phone': ?phone,
          'email': ?email,
          if (gender != null) 'gender': gender.apiValue,
          if (birthDate != null) 'birthDate': birthDate.toIso8601String(),
          'address': ?address,
          'notes': ?notes,
        },
      );
      return _customerFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// HOST only (403 otherwise) — the one endpoint in this module AGENT
  /// can't reach at all.
  Future<Customer> setActive(String id, {required bool isActive}) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/customers/$id/status',
        data: {'isActive': isActive},
      );
      return _customerFrom(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Customer _customerFrom(Map<String, dynamic>? body) {
    final json = body?['data']?['customer'] as Map<String, dynamic>?;
    if (json == null) {
      throw ApiException('INVALID_RESPONSE', 'Respons server tidak valid.');
    }
    return Customer.fromJson(json);
  }
}
