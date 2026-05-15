class Order {
  final String id;
  final String outletId;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;

  /// List of items from UI. Shape:
  /// { product_id, product_name, quantity, unit_price, hpp }
  final List<Map<String, dynamic>> items;

  final double totalAmount;
  final double totalHpp;
  final String paymentMethod;
  final String? notes;

  final DateTime createdAt;

  Order({
    required this.id,
    required this.outletId,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.items,
    required this.totalAmount,
    required this.totalHpp,
    required this.paymentMethod,
    required this.notes,
    required this.createdAt,
  });
}
