class User {
  final String id;
  final String email;
  final String name;
  final String role; // 'barista', 'manager', 'admin'
  final String outletId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.outletId,
    required this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle null values safely
    final id = json['id'];
    final email = json['email'];
    final name = json['name'];
    final role = json['role'];
    final outletId = json['outlet_id'];
    final createdAt = json['created_at'];
    
    if (id == null) throw Exception('Missing required field: id');
    if (email == null) throw Exception('Missing required field: email');
    if (name == null) throw Exception('Missing required field: name');
    if (role == null) throw Exception('Missing required field: role');
    if (createdAt == null) throw Exception('Missing required field: created_at');
    
    // outlet_id can be null for some roles
    
    return User(
      id: id as String,
      email: email as String,
      name: name as String,
      role: role as String,
      outletId: (outletId as String?) ?? '',
      createdAt: DateTime.parse(createdAt as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'outlet_id': outletId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
