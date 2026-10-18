import 'package:dio/dio.dart';

import '../models/inventory.dart';
import 'api_exception.dart';

/// CRUD for items + stock movement history. Subscription gating here is
/// `ENFORCED` for both roles (inventory doc §0) — unlike TransactionService
/// (EXEMPT_AGENT), AGENT calls in this module can 402 too.
class InventoryService {
  InventoryService(this._dio);

  final Dio _dio;

  Future<InventoryPage> list({
    int page = 1,
    int limit = 20,
    String? branchId,
    String? search,
    bool? lowStockOnly,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/inventory',
        queryParameters: {
          'page': page,
          'limit': limit,
          'branchId': ?branchId,
          if (search != null && search.isNotEmpty) 'search': search,
          'lowStockOnly': ?lowStockOnly,
        },
      );
      return InventoryPage.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// `branchId` is required for HOST (no "own branch" to default to)
  /// and ignored for AGENT, who always gets their session branch
  /// (inventory doc §2).
  Future<InventoryItem> create({
    required String itemCode,
    String? branchId,
    required String name,
    InventoryCategory category = InventoryCategory.other,
    String unit = 'PCS',
    int quantity = 0,
    num unitCost = 0,
    int minimumStock = 5,
    String? supplier,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/inventory',
        data: {
          'itemCode': itemCode,
          'branchId': ?branchId,
          'name': name,
          'category': category.apiValue,
          'unit': unit,
          'quantity': quantity,
          'unitCost': unitCost,
          'minimumStock': minimumStock,
          'supplier': ?supplier,
        },
      );
      return InventoryItem.fromJson(
        response.data!['data']['item'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<InventoryItem> detail(String id) => _getItem('/api/v1/inventory/$id');

  /// `itemCode`/`branchId`/`quantity` are not accepted here at all —
  /// the backend schema doesn't know those fields on this endpoint
  /// (inventory doc §4). Use [recordIn]/[recordOut]/[recordAdjustment]
  /// to change `quantity`.
  Future<InventoryItem> update(
    String id, {
    String? name,
    InventoryCategory? category,
    String? unit,
    num? unitCost,
    int? minimumStock,
    String? supplier,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/inventory/$id',
        data: {
          'name': ?name,
          if (category != null) 'category': category.apiValue,
          'unit': ?unit,
          'unitCost': ?unitCost,
          'minimumStock': ?minimumStock,
          'supplier': ?supplier,
        },
      );
      return InventoryItem.fromJson(
        response.data!['data']['item'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// Soft delete — sets `isActive: false`, never removes the row
  /// (inventory doc §5). Still returns `200` + the updated item.
  Future<InventoryItem> deactivate(String id) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/api/v1/inventory/$id',
      );
      return InventoryItem.fromJson(
        response.data!['data']['item'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<StockMovementPage> listStockMovements(
    String id, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/inventory/$id/stock-movements',
        queryParameters: {'page': page, 'limit': limit},
      );
      return StockMovementPage.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// Stock added — `quantity` is a positive delta added to the current
  /// total (inventory doc §7).
  Future<RecordMovementResult> recordIn(
    String id, {
    required int quantity,
    required String reason,
  }) => _recordMovement(id, {
    'movementType': 'IN',
    'quantity': quantity,
    'reason': reason,
  });

  /// Stock removed/used — `quantity` is a positive delta subtracted
  /// from the current total (inventory doc §7). Rejected 422 if it
  /// would make stock negative.
  Future<RecordMovementResult> recordOut(
    String id, {
    required int quantity,
    required String reason,
  }) => _recordMovement(id, {
    'movementType': 'OUT',
    'quantity': quantity,
    'reason': reason,
  });

  /// Physical stock-take correction — `newQuantity` is the **absolute**
  /// resulting value, not a delta (inventory doc §7: this is a
  /// discriminated union, sending `quantity` here instead gets 400).
  Future<RecordMovementResult> recordAdjustment(
    String id, {
    required int newQuantity,
    required String reason,
  }) => _recordMovement(id, {
    'movementType': 'ADJUSTMENT',
    'newQuantity': newQuantity,
    'reason': reason,
  });

  Future<RecordMovementResult> _recordMovement(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/inventory/$id/stock-movements',
        data: data,
      );
      return RecordMovementResult.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<InventoryItem> _getItem(String path) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      return InventoryItem.fromJson(
        response.data!['data']['item'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
