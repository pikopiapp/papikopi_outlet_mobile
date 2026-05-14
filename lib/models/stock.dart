class OutletStock {
  final String id;
  final String outletId;
  final String ingredientId;
  final String ingredientName;
  final double quantity;
  final DateTime updatedAt;

  OutletStock({
    required this.id,
    required this.outletId,
    required this.ingredientId,
    required this.ingredientName,
    required this.quantity,
    required this.updatedAt,
  });

  factory OutletStock.fromJson(Map<String, dynamic> json) {
    return OutletStock(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      ingredientId: json['ingredient_id'] as String,
      ingredientName: json['ingredient_name'] as String? ?? 'Unknown',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlet_id': outletId,
      'ingredient_id': ingredientId,
      'quantity': quantity,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class StockTransfer {
  final String id;
  final String fromOutletId;
  final String toOutletId;
  final String status; // 'requested', 'approved', 'sent', 'received'
  final List<StockTransferItem> items;
  final DateTime createdAt;

  StockTransfer({
    required this.id,
    required this.fromOutletId,
    required this.toOutletId,
    required this.status,
    required this.items,
    required this.createdAt,
  });

  factory StockTransfer.fromJson(Map<String, dynamic> json) {
    return StockTransfer(
      id: json['id'] as String,
      fromOutletId: json['from_outlet_id'] as String,
      toOutletId: json['to_outlet_id'] as String,
      status: json['status'] as String? ?? 'requested',
      items: (json['stock_transfer_items'] as List<dynamic>?)
              ?.map((item) => StockTransferItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}

class StockTransferItem {
  final String id;
  final String transferId;
  final String ingredientId;
  final String ingredientName;
  final double quantity;

  StockTransferItem({
    required this.id,
    required this.transferId,
    required this.ingredientId,
    required this.ingredientName,
    required this.quantity,
  });

  factory StockTransferItem.fromJson(Map<String, dynamic> json) {
    return StockTransferItem(
      id: json['id'] as String,
      transferId: json['transfer_id'] as String,
      ingredientId: json['ingredient_id'] as String,
      ingredientName: json['ingredient_name'] as String? ?? 'Unknown',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class StockReturn {
  final String id;
  final String outletId;
  final String ingredientId;
  final String ingredientName;
  final double quantity;
  final String reason;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;

  StockReturn({
    required this.id,
    required this.outletId,
    required this.ingredientId,
    required this.ingredientName,
    required this.quantity,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory StockReturn.fromJson(Map<String, dynamic> json) {
    return StockReturn(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      ingredientId: json['ingredient_id'] as String,
      ingredientName: json['ingredient_name'] as String? ?? 'Unknown',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
