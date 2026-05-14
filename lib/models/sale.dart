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
    return SaleItem(
      id: json['id'] as String,
      saleId: json['sale_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String? ?? 'Product',
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
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      baristaId: json['barista_id'] as String,
      paymentMethod: json['payment_method'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      totalHpp: (json['hpp_total'] as num).toDouble(),
      totalBonus: (json['bonus_amount'] as num).toDouble(),
      profit: (json['profit'] as num).toDouble(),
      items: (json['sale_items'] as List<dynamic>?)
              ?.map((item) => SaleItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
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
    };
  }
}
