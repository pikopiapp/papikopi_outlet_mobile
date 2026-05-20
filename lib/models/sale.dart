class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double hpp;
  final DateTime createdAt;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.hpp,
    required this.createdAt,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    // Get product name from direct field or from nested products relationship
    String productName = 'Product'; // Default fallback
    
    // Try direct product_name field first
    if (json['product_name'] != null) {
      productName = json['product_name'] as String;
    }
    // Try nested products relationship (from JOIN)
    else if (json['products'] != null) {
      final productsData = json['products'];
      if (productsData is Map<String, dynamic> && productsData['name'] != null) {
        productName = productsData['name'] as String;
      }
    }
    
    return SaleItem(
      id: json['id'] as String,
      saleId: json['sale_id'] as String,
      productId: json['product_id'] as String,
      productName: productName,
      quantity: json['quantity'] as int,
      unitPrice: (json['price'] as num).toDouble(),
      hpp: (json['hpp'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  double get subtotal => quantity * unitPrice;
  double get totalHpp => quantity * hpp;
  double get profit => subtotal - totalHpp;
}

class Sale {
  final String id;
  final String outletId;
  final String baristaId;
  final String paymentMethod; // 'CASH', 'QRIS', 'CARD'
  final double totalAmount;
  final double totalHpp;
  final double totalBonus;
  final double profit;
  final List<SaleItem> items;
  final DateTime createdAt;
  final bool isEdited; // 🔧 NEW: Track if transaction has been edited
  final DateTime? editedAt; // 🔧 NEW: Track when it was edited

  Sale({
    required this.id,
    required this.outletId,
    required this.baristaId,
    required this.paymentMethod,
    required this.totalAmount,
    required this.totalHpp,
    required this.totalBonus,
    required this.profit,
    required this.items,
    required this.createdAt,
    this.isEdited = false, // 🔧 NEW
    this.editedAt, // 🔧 NEW
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['sale_items'] as List<dynamic>?)
            ?.map((item) => SaleItem.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];
    
    print('📦 Sale.fromJson() - ID: ${(json['id'] as String).substring(0, 8)}, items count: ${itemsList.length}');
    if (itemsList.isNotEmpty) {
      for (var i = 0; i < itemsList.length; i++) {
        print('   Item $i: ${itemsList[i].productName} x${itemsList[i].quantity}');
      }
    }
    
    return Sale(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      baristaId: json['barista_id'] as String,
      paymentMethod: json['payment_method'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      totalHpp: (json['hpp_total'] as num).toDouble(),
      totalBonus: (json['bonus_amount'] as num).toDouble(),
      profit: (json['profit'] as num).toDouble(),
      items: itemsList,
      createdAt: DateTime.parse(json['created_at'] as String),
      isEdited: json['is_edited'] as bool? ?? false, // 🔧 NEW
      editedAt: json['edited_at'] != null ? DateTime.parse(json['edited_at'] as String) : null, // 🔧 NEW
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlet_id': outletId,
      'barista_id': baristaId,
      'payment_method': paymentMethod,
      'total_amount': totalAmount,
      'total_hpp': totalHpp,
      'total_bonus': totalBonus,
      'profit': profit,
      'created_at': createdAt.toIso8601String(),
      'is_edited': isEdited, // 🔧 NEW
      'edited_at': editedAt?.toIso8601String(), // 🔧 NEW
    };
  }
}
