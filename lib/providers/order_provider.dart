import 'package:flutter/foundation.dart';
import '../models/order.dart';

/// Minimal OrderProvider agar aplikasi bisa compile.
/// Nanti bisa kamu perluas dengan integrasi Supabase/REST sesuai backend.
class OrderProvider extends ChangeNotifier {
  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  Future<Order?> createOrder({
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
    _isSubmitting = true;
    notifyListeners();

    try {
      // TODO: implement call ke backend (Supabase/REST) sesuai skema proyek.
      // Untuk sementara return dummy agar UI flow jalan.
      await Future.delayed(const Duration(milliseconds: 300));

      return Order(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        outletId: outletId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        items: items,
        totalAmount: totalAmount,
        totalHpp: totalHpp,
        paymentMethod: paymentMethod,
        notes: notes,
        createdAt: DateTime.now(),
      );
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
