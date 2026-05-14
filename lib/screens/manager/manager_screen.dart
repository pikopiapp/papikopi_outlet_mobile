import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/thema.dart';
import '../stock_screen.dart';

/// Halaman khusus Manager.
///
/// Saat ini:
/// - Menampilkan fitur STOK (Stok Produk + Pindah Stok + Pengembalian)
///
/// Struktur sudah disiapkan supaya nanti bisa ditambahkan:
/// - UI alokasi product ke outlet
/// - UI review returns (pengelolaan kondisi/approval)
class ManagerScreen extends StatelessWidget {
  const ManagerScreen({super.key});

  bool _isManagerRole(String role) {
    final r = role.toLowerCase();
    return r == 'manager' || r == 'admin';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final role = auth.currentUser?.role ?? 'barista';

        if (!_isManagerRole(role)) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Manager'),
            ),
            body: Center(
              child: Text(
                'Akses ditolak. Role Anda: $role',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Manager'),
            centerTitle: false,
          ),
          body: const StockScreen(),
        );
      },
    );
  }
}

