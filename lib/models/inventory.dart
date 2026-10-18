import 'entity_ref.dart';
import 'pagination.dart';

enum InventoryCategory {
  hairProduct,
  equipment,
  consumable,
  other;

  static InventoryCategory fromApi(String value) {
    switch (value) {
      case 'HAIR_PRODUCT':
        return InventoryCategory.hairProduct;
      case 'EQUIPMENT':
        return InventoryCategory.equipment;
      case 'CONSUMABLE':
        return InventoryCategory.consumable;
      case 'OTHER':
        return InventoryCategory.other;
      default:
        throw FormatException('Unknown inventory category: $value');
    }
  }

  String get apiValue => switch (this) {
    InventoryCategory.hairProduct => 'HAIR_PRODUCT',
    InventoryCategory.equipment => 'EQUIPMENT',
    InventoryCategory.consumable => 'CONSUMABLE',
    InventoryCategory.other => 'OTHER',
  };

  String get label => switch (this) {
    InventoryCategory.hairProduct => 'Produk Rambut',
    InventoryCategory.equipment => 'Peralatan',
    InventoryCategory.consumable => 'Habis Pakai',
    InventoryCategory.other => 'Lainnya',
  };
}

/// `GET /inventory` key is `items` — **not** `inventory`, which is the
/// key used by the unrelated `GET /dashboard/inventory` endpoint
/// (inventory doc §1 explicitly warns not to mix these two up).
/// `totalValue`/`isLowStock` are server-computed virtual fields, never
/// recomputed client-side.
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.itemCode,
    required this.branch,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.unitCost,
    required this.minimumStock,
    required this.supplier,
    required this.isActive,
    required this.totalValue,
    required this.isLowStock,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String itemCode;
  final EntityRef branch;
  final String name;
  final InventoryCategory category;
  final String unit;
  final int quantity;
  final num unitCost;
  final int minimumStock;
  final String? supplier;
  final bool isActive;
  final num totalValue;
  final bool isLowStock;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['_id'] as String,
      itemCode: json['itemCode'] as String,
      branch: EntityRef.fromDynamic(json['branch']),
      name: json['name'] as String,
      category: InventoryCategory.fromApi(json['category'] as String),
      unit: json['unit'] as String,
      quantity: json['quantity'] as int,
      unitCost: json['unitCost'] as num,
      minimumStock: json['minimumStock'] as int,
      supplier: json['supplier'] as String?,
      isActive: json['isActive'] as bool,
      totalValue: json['totalValue'] as num,
      isLowStock: json['isLowStock'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class InventoryPage {
  const InventoryPage({required this.items, required this.pagination});

  final List<InventoryItem> items;
  final Pagination pagination;

  factory InventoryPage.fromJson(Map<String, dynamic> json) {
    return InventoryPage(
      items: (json['items'] as List)
          .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: Pagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }
}

enum StockMovementType {
  stockIn,
  stockOut,
  adjustment;

  static StockMovementType fromApi(String value) {
    switch (value) {
      case 'IN':
        return StockMovementType.stockIn;
      case 'OUT':
        return StockMovementType.stockOut;
      case 'ADJUSTMENT':
        return StockMovementType.adjustment;
      default:
        throw FormatException('Unknown movement type: $value');
    }
  }

  String get apiValue => switch (this) {
    StockMovementType.stockIn => 'IN',
    StockMovementType.stockOut => 'OUT',
    StockMovementType.adjustment => 'ADJUSTMENT',
  };

  String get label => switch (this) {
    StockMovementType.stockIn => 'Masuk',
    StockMovementType.stockOut => 'Keluar',
    StockMovementType.adjustment => 'Penyesuaian',
  };
}

/// `quantity` here is always the **absolute** difference
/// (`|newQuantity - previousQuantity|`) — never negative, even for an
/// ADJUSTMENT that lowered stock (inventory doc §7). Compare
/// `newQuantity` vs `previousQuantity` to know direction for ADJUSTMENT.
///
/// `performedBy` is populated `{_id, name}` on the history list (§6)
/// but a raw id on the create response (§7) — same tolerant
/// [EntityRef] handling as everywhere else.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.branch,
    required this.movementType,
    required this.quantity,
    required this.previousQuantity,
    required this.newQuantity,
    required this.reason,
    required this.performedBy,
    required this.createdAt,
  });

  final String id;
  final EntityRef branch;
  final StockMovementType movementType;
  final int quantity;
  final int previousQuantity;
  final int newQuantity;
  final String reason;
  final EntityRef performedBy;
  final DateTime createdAt;

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: json['_id'] as String,
      branch: EntityRef.fromDynamic(json['branch']),
      movementType: StockMovementType.fromApi(json['movementType'] as String),
      quantity: json['quantity'] as int,
      previousQuantity: json['previousQuantity'] as int,
      newQuantity: json['newQuantity'] as int,
      reason: json['reason'] as String,
      performedBy: EntityRef.fromDynamic(json['performedBy']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class StockMovementPage {
  const StockMovementPage({required this.movements, required this.pagination});

  final List<StockMovement> movements;
  final Pagination pagination;

  factory StockMovementPage.fromJson(Map<String, dynamic> json) {
    return StockMovementPage(
      movements: (json['movements'] as List)
          .map((e) => StockMovement.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: Pagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }
}

/// `POST .../stock-movements` response (inventory doc §7): the item is
/// already updated server-side, so callers don't need a separate
/// refetch to see the new `quantity`.
class RecordMovementResult {
  const RecordMovementResult({required this.item, required this.movement});

  final InventoryItem item;
  final StockMovement movement;

  factory RecordMovementResult.fromJson(Map<String, dynamic> json) {
    return RecordMovementResult(
      item: InventoryItem.fromJson(json['item'] as Map<String, dynamic>),
      movement: StockMovement.fromJson(
        json['movement'] as Map<String, dynamic>,
      ),
    );
  }
}
