class Category {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class Product {
  final String id;
  final String categoryId;
  final String name;
  final String? description;
  final double price;
  final double? hpp; // Harga pokok penjualan
  final bool isActive;
  final int stock; // Quantity from showcase_allocations in business day (no deductions)
  final int tersedia; // Available after deductions (sold, returned, transfers)
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    required this.price,
    this.hpp,
    required this.isActive,
    this.stock = 0,
    this.tersedia = 0,
    this.imageUrl,
    required this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      hpp: json['hpp'] != null ? (json['hpp'] as num).toDouble() : null,
      isActive: json['is_active'] as bool? ?? true,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      tersedia: (json['tersedia'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'price': price,
      'hpp': hpp,
      'is_active': isActive,
      'stock': stock,
      'tersedia': tersedia,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  double get margin => (price - (hpp ?? 0));
  double get marginPercent => hpp != null && hpp! > 0 
      ? ((price - hpp!) / hpp! * 100) 
      : 0;

  /// Generate QR code data for this product
  /// Returns JSON with product information that can be encoded in QR code
  /// Format matches web dashboard batch QR code structure
  String getQRData() {
    return '{\"product\":\"$name\",\"id\":\"$id\",\"price\":$price}';
  }
}
