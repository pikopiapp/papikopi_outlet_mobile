import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/thema.dart';
import 'shared/investor_data_mixin.dart';

class InvestorWithdrawalScreen extends StatefulWidget {
  const InvestorWithdrawalScreen({super.key});

  @override
  State<InvestorWithdrawalScreen> createState() =>
      _InvestorWithdrawalScreenState();
}

class _InvestorWithdrawalScreenState extends State<InvestorWithdrawalScreen>
    with InvestorDataMixin {
  List<Map<String, dynamic>> _withdrawalHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWithdrawalData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadWithdrawalData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      if (user == null) return;

      final monthlyProfits = await supabaseService.getInvestorMonthlyProfits(
        user.id,
      );

      setState(() {
        _withdrawalHistory = monthlyProfits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match.group(1)}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_withdrawalHistory.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Penarikan Pendapatan Bulanan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _withdrawalHistory.length,
                  itemBuilder: (context, index) {
                    final item = _withdrawalHistory[index];
                    final month = (item['month'] as String?) ?? '-';
                    final profit = (item['profit'] as num?)?.toDouble() ?? 0.0;
                    final status = (item['status'] as String?) ?? 'pending';

                    final isApproved = status == 'approved';
                    final isPending = status == 'pending';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isApproved
                              ? AppColors.success.withValues(alpha: 0.3)
                              : isPending
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : AppColors.error.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      month,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Pendapatan: Rp ${_formatCurrency(profit)}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isApproved
                                      ? AppColors.success.withValues(alpha: 0.15)
                                      : isPending
                                          ? AppColors.primary.withValues(alpha: 0.15)
                                          : AppColors.error.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isApproved
                                        ? AppColors.success
                                        : isPending
                                            ? AppColors.primary
                                            : AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isApproved
                                        ? AppColors.success.withValues(alpha: 0.15)
                                        : AppColors.altSurface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.checklist_rtl_rounded,
                                        size: 14,
                                        color: isApproved
                                            ? AppColors.success
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Transfer',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isApproved
                                              ? AppColors.success
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isApproved
                                        ? AppColors.success.withValues(alpha: 0.15)
                                        : AppColors.altSurface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.receipt_long_rounded,
                                        size: 14,
                                        color: isApproved
                                            ? AppColors.success
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Bukti',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isApproved
                                              ? AppColors.success
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}