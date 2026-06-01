import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';
import '../../utils/profit_margin_calculator.dart';
import '../../widgets/profit_breakdown_widget.dart';

class InvestorRevenueScreen extends StatefulWidget {
  const InvestorRevenueScreen({super.key});

  @override
  State<InvestorRevenueScreen> createState() => _InvestorRevenueScreenState();
}

class _InvestorRevenueScreenState extends State<InvestorRevenueScreen> {
  final _supabaseService = SupabaseService();
  String _period = 'daily';
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _updateDateRange();
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_period) {
      case 'daily':
        _startDate = DateTime(now.year, now.month, now.day - 1);
        _endDate = DateTime(now.year, now.month, now.day);
        break;
      case 'weekly':
        _startDate = now.subtract(const Duration(days: 7));
        _endDate = now;
        break;
      case 'monthly':
      default:
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
        break;
    }
  }

  Future<List<Map<String, dynamic>>> _resolveInvestorOutlets() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return [];

    try {
      return await _supabaseService.getInvestorAssignments(investorId: user.id);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _fetchRevenueForOutlet(String outletId) async {
    return _supabaseService.getRevenueData(
      outletId: outletId,
      selectedDate: _endDate,
    );
  }

  /// Get actual HPP data from Supabase for a given period
  Future<Map<String, dynamic>> _fetchHppForOutlet(String outletId) async {
    return _supabaseService.getHppSummary(
      outletId: outletId,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0)
        .replaceAllMapped(
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
              const Text(
                'Revenue Investor',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Periode Selector - Inline
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih periode:',
                    style: TextStyle(fontSize: 13),
                  ),
                  Row(
                    spacing: 8,
                    children: [
                      _PillButton(
                        active: _period == 'daily',
                        label: 'Hari',
                        onTap: () => setState(() {
                          _period = 'daily';
                          _updateDateRange();
                        }),
                      ),
                      _PillButton(
                        active: _period == 'weekly',
                        label: 'Minggu',
                        onTap: () => setState(() {
                          _period = 'weekly';
                          _updateDateRange();
                        }),
                      ),
                      _PillButton(
                        active: _period == 'monthly',
                        label: 'Bulan',
                        onTap: () => setState(() {
                          _period = 'monthly';
                          _updateDateRange();
                        }),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Date Picker - Full Width with Equal Width
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.altSurface),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2020),
                            lastDate: _endDate,
                          );
                          if (picked != null) {
                            setState(() => _startDate = picked);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dari',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.edit, size: 18, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.altSurface),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _endDate,
                            firstDate: _startDate,
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _endDate = picked);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sampai',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.edit, size: 18, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _resolveInvestorOutlets(),
                builder: (context, outletsSnap) {
                  if (outletsSnap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 140,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (outletsSnap.hasError) {
                    return _InfoBox(
                      title: 'Error',
                      value: 'Gagal memuat outlets investor: ${outletsSnap.error}',
                    );
                  }

                  final outlets = outletsSnap.data ?? [];
                  if (outlets.isEmpty) {
                    return const _InfoBox(
                      title: 'Outlet investor',
                      value: 'Belum ada outlet yang diinvestasikan.',
                    );
                  }

                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: Future.wait(
                      outlets.map((outlet) async {
                        final outletId = outlet['outlet_id'] as String? ?? '';
                        final revenue = await _fetchRevenueForOutlet(outletId);
                        final hpp = await _fetchHppForOutlet(outletId);
                        return {
                          ...outlet,
                          'revenue': revenue,
                          'hpp': hpp,
                        };
                      }),
                    ),
                    builder: (context, revenueSnap) {
                      if (revenueSnap.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 140,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (revenueSnap.hasError) {
                        return _InfoBox(
                          title: 'Error',
                          value: 'Gagal memuat revenue: ${revenueSnap.error}',
                        );
                      }

                      final outletData = revenueSnap.data ?? [];

                      // Calculate summary
                      double totalRevenue = 0;
                      double totalInvestorShare = 0;
                      int totalTransactions = 0;
                      double totalCash = 0;
                      double totalQris = 0;

                      for (final item in outletData) {
                        final revenue =
                            (item['revenue'] as Map<String, dynamic>?) ?? {};
                        final periodData =
                            (revenue[_period] as Map<String, dynamic>?) ?? {};
                        final amount =
                            (periodData['amount'] as num?)?.toDouble() ?? 0.0;
                        final count =
                            (periodData['count'] as num?)?.toInt() ?? 0;
                        final margin =
                            (item['margin_percentage'] as num?)?.toDouble() ??
                                0.0;
                        final cash =
                            (periodData['cash'] as num?)?.toDouble() ?? 0.0;
                        final qris =
                            (periodData['qris'] as num?)?.toDouble() ?? 0.0;

                        totalRevenue += amount;
                        totalInvestorShare +=
                            (amount * margin / 100).toDouble();
                        totalTransactions += count;
                        totalCash += cash;
                        totalQris += qris;
                      }

                      final avgTransactionValue =
                          totalTransactions > 0 ? totalRevenue / totalTransactions : 0.0;

                      return Column(
                        children: [
                          // Summary Cards
                          Row(
                            children: [
                              Expanded(
                                child: Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.shade50,
                                          Colors.blue.shade100,
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Total Revenue',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Rp${_formatCurrency(totalRevenue)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.green.shade50,
                                          Colors.green.shade100,
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Share Investor',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Rp${_formatCurrency(totalInvestorShare)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.purple.shade50,
                                          Colors.purple.shade100,
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Transaksi',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '$totalTransactions',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepPurple,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Row 2: Avg Transaction Value & Payment Breakdown
                          Row(
                            children: [
                              Expanded(
                                child: Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.amber.shade50,
                                          Colors.amber.shade100,
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Avg Transaksi',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Rp${_formatCurrency(avgTransactionValue)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.red.shade50,
                                          Colors.red.shade100,
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'CASH',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Rp${_formatCurrency(totalCash)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.teal.shade50,
                                          Colors.teal.shade100,
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'QRIS',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Rp${_formatCurrency(totalQris)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Per-Outlet Revenue Cards
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: outletData.length,
                            itemBuilder: (context, index) {
                              final item = outletData[index];
                              final outletName =
                                  (item['outlet_name'] as String?) ?? '-';
                              final revenue =
                                  (item['revenue'] as Map<String, dynamic>?) ??
                                      {};
                              final periodData =
                                  (revenue[_period] as Map<String, dynamic>?) ??
                                      {};
                              final amount =
                                  (periodData['amount'] as num?)?.toDouble() ??
                                      0.0;
                              final count =
                                  (periodData['count'] as num?)?.toInt() ?? 0;
                              final margin =
                                  (item['margin_percentage'] as num?)
                                      ?.toDouble() ??
                                      0.0;
                              final investorShare =
                                  (amount * margin / 100).toDouble();

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.orange.shade50,
                                          Colors.orange.shade100,
                                        ],
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          outletName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          height: 1,
                                          color: Colors.orange[200],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Revenue',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Rp${_formatCurrency(amount)}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Investor Share',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Rp${_formatCurrency(investorShare)}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Margin',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '$margin%',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Transaksi',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '$count',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Profit Breakdown Section - Using real HPP from database
                                        Builder(
                                          builder: (context) {
                                            final hpp =
                                                (item['hpp'] as Map<String, dynamic>?)
                                                    ?? {};
                                            final actualHpp =
                                                (hpp['totalHpp'] as num?)
                                                        ?.toDouble() ??
                                                    0.0;
                                            final actualSales =
                                                (hpp['totalSales'] as num?)
                                                        ?.toDouble() ??
                                                    amount;
                                            return ProfitBreakdownCard(
                                              result: ProfitMarginCalculator
                                                  .calculateFromAggregatedData(
                                                totalSales: actualSales,
                                                totalHpp: actualHpp,
                                                totalOmset: actualSales,
                                                investorPercentage: margin,
                                                isHoliday: false,
                                              ),
                                              outletName: outletName,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(0.14) : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primary.withOpacity(0.55) : AppColors.altSurface,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String value;

  const _InfoBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.altSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(value),
        ],
      ),
    );
  }
}
