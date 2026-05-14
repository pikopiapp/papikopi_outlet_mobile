import 'package:flutter/material.dart';

/// Placeholder OrderProvider.
///
/// Di repo saat ini, `ordering_screen.dart` masih mengimpor `OrderProvider`.
/// Supaya project bisa compile, provider ini disediakan sebagai stubs.
/// Implementasi detail dapat ditambahkan setelah UI/flow pemesanan final.
class OrderProvider extends ChangeNotifier {
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  /// Stub untuk kebutuhan kompilasi.
  ///
  /// Signature disesuaikan dengan pemanggilan di `OrderingScreen`.
  /// Saat ini hanya membuat placeholder dan mengembalikan dummy `Order`.
  Future<Order> createOrder({
    required String outletId,
    required String customerName,
    String? customerPhone,
    String? customerEmail,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double totalHpp,
    required String paymentMethod,
    String? notes,
  }) async {
    setLoading(true);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      return Order(
        id: 'order_stub_${DateTime.now().millisecondsSinceEpoch}',
      );
    } finally {
      setLoading(false);
    }
  }
}

/// Stub model Order agar kompilasi berhasil.
class Order {
  final String id;

  Order({required this.id});
}

