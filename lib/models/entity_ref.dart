/// Represents a reference to another entity (branch/agent/customer/
/// requestedBy/reviewedBy/performedBy, ...) across every module read so
/// far. These fields come back as a **raw ObjectId string on
/// create-like responses** and as a **populated `{_id, name, ...}`
/// object on read-like responses** (first seen in the transaction docs,
/// §9/§0; the same split recurs in the inventory doc for
/// `stock-movements.performedBy`) — rather than one parallel model per
/// call site, this single type tolerates both shapes; `name` (and
/// friends) is simply null when the backend only gave us an id.
class EntityRef {
  const EntityRef({
    required this.id,
    this.name,
    this.phone,
    this.branchCode,
    this.address,
  });

  final String id;
  final String? name;
  final String? phone; // customer phone, or receipt-branch phone
  final String? branchCode; // receipt-branch only
  final String? address; // receipt-branch only

  /// Falls back to the raw id when the backend didn't populate a name,
  /// so call sites never have to null-check just to render something.
  String get displayName => name ?? id;

  factory EntityRef.fromDynamic(dynamic value) {
    if (value is String) return EntityRef(id: value);
    final map = value as Map<String, dynamic>;
    return EntityRef(
      id: map['_id'] as String,
      name: map['name'] as String?,
      phone: map['phone'] as String?,
      branchCode: map['branchCode'] as String?,
      address: map['address'] as String?,
    );
  }
}
