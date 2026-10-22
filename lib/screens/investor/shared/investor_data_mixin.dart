import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/supabase_service.dart';

mixin InvestorDataMixin<T extends StatefulWidget> on State<T> {
  SupabaseService get supabaseService => SupabaseService();

  Future<List<Map<String, dynamic>>> resolveInvestorOutlets() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return [];

    return supabaseService.getInvestorAssignments(investorId: user.id);
  }

  Future<String?> resolveInvestorOutletId() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return null;

    final outlets = await supabaseService.getActiveInvestorOutlets(
      investorId: user.id,
    );
    if (outlets.isEmpty) return null;

    return outlets.first.id;
  }

  String formatCurrency(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match.group(1)}.',
        );
  }

  String formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}, '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }
}