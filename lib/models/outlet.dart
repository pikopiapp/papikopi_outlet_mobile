class Outlet {
  final String id;
  final String name;
  final String type; // 'CART', 'SHOP', 'KIOSK'
  final String location;
  final String? phone;
  final String? whatsapp;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Outlet({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    this.phone,
    this.whatsapp,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      location: json['location'] as String,
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'location': location,
      'phone': phone,
      'whatsapp': whatsapp,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
