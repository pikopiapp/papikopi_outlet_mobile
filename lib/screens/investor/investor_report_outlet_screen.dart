import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';

class InvestorReportOutletScreen extends StatefulWidget {
  const InvestorReportOutletScreen({super.key});

  @override
  State<InvestorReportOutletScreen> createState() =>
      _InvestorReportOutletScreenState();
}

class _InvestorReportOutletScreenState
    extends State<InvestorReportOutletScreen> {
  final _supabaseService = SupabaseService();

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

  /// Get monthly HPP data for ROI calculation
  Future<double> _fetchActualMonthlyRevenue(String outletId) async {
    try {
      final now = DateTime.now();

      final revenueData = await _supabaseService.getRevenueData(
        outletId: outletId,
        selectedDate: now,
      );

      // Extract monthly revenue from aggregated data
      final monthlyAmount = (revenueData['monthly']?['amount'] as num?)?.toDouble() ?? 0.0;
      return monthlyAmount;
    } catch (e) {
      return 0.0;
    }
  }

  double _calculateAnnualROI(double investmentAmount, double marginPercentage, double actualMonthlyRevenue) {
    // Use actual monthly revenue if available, otherwise fallback to estimation
    final monthlyRevenue = actualMonthlyRevenue > 0 
      ? actualMonthlyRevenue 
      : investmentAmount * 1.5;
    final monthlyProfit = monthlyRevenue * (marginPercentage / 100);
    final annualProfit = monthlyProfit * 12;
    return (annualProfit / investmentAmount) * 100;
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
                'Report Outlet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ringkasan outlet yang diinvestasikan.',
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _resolveInvestorOutlets(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _InfoBox(
                      title: 'Error',
                      value: 'Gagal memuat outlets investor: ${snapshot.error}',
                    );
                  }

                  final outlets = snapshot.data ?? [];
                  if (outlets.isEmpty) {
                    return const _InfoBox(
                      title: 'Outlet investor',
                      value: 'Belum ada outlet yang diinvestasikan.',
                    );
                  }

                  // Calculate summary
                  int totalOutlets = outlets.length;
                  int activeOutlets = outlets
                      .where((o) => (o['status'] as String?) == 'active')
                      .length;
                  double totalInvestment = 0;
                  for (final o in outlets) {
                    final amount =
                        (o['investment_amount'] as num?)?.toDouble() ?? 0.0;
                    totalInvestment += amount;
                  }

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
                                padding: const EdgeInsets.all(10),
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
                                      'Total Outlet',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$totalOutlets',
                                      style: const TextStyle(
                                        fontSize: 18,
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
                                padding: const EdgeInsets.all(10),
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
                                      'Outlet Aktif',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$activeOutlets',
                                      style: const TextStyle(
                                        fontSize: 18,
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
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.orange.shade50,
                                      Colors.orange.shade100,
                                    ],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Investasi',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Rp${_formatCurrency(totalInvestment)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
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
                      // Outlet List
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: outlets.length,
                        itemBuilder: (context, index) {
                          final outlet = outlets[index];
                          final outletName =
                              (outlet['outlet_name'] as String?) ?? '-';
                          final outletType =
                              (outlet['outlet_type'] as String?) ?? 'unknown';
                          final investmentAmount =
                              (outlet['investment_amount'] as num?)?.toDouble() ??
                                  0.0;
                          final marginPercentage =
                              (outlet['margin_percentage'] as num?)
                                  ?.toDouble() ??
                                  0.0;
                          final status =
                              (outlet['status'] as String?) ?? 'unknown';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
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
                                      Colors.indigo.shade50,
                                      Colors.indigo.shade100,
                                    ],
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Header: Outlet Name + Status Badge
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
                                                outletName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                outletType,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: status == 'active'
                                                ? Colors.green.shade100
                                                : Colors.orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: status == 'active'
                                                  ? Colors.green[700]
                                                  : Colors.orange[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 1,
                                      color: Colors.indigo[200],
                                    ),
                                    const SizedBox(height: 8),
                                    // Investment Details
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
                                                'Investasi',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Rp${_formatCurrency(investmentAmount)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
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
                                                'Margin Profit',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$marginPercentage%',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // ROI Estimate - Fetch Real Revenue
                                    FutureBuilder<double>(
                                      future: _fetchActualMonthlyRevenue(
                                          outlet['outlet_id'] as String? ?? ''),
                                      builder: (context, revenuSnapshot) {
                                        final actualMonthlyRevenue =
                                            revenuSnapshot.data ?? 0.0;
                                        final roiValue = _calculateAnnualROI(
                                          investmentAmount,
                                          marginPercentage,
                                          actualMonthlyRevenue,
                                        );

                                        return Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.blue.shade200),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Estimasi ROI Tahunan',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              if (revenuSnapshot.connectionState ==
                                                  ConnectionState.waiting)
                                                const SizedBox(
                                                  height: 16,
                                                  child: Center(
                                                    child: SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              else
                                                Text(
                                                  '${roiValue.toStringAsFixed(1)}%',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              if (actualMonthlyRevenue > 0)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4),
                                                  child: Text(
                                                    'Revenue: Rp ${_formatCurrency(actualMonthlyRevenue)}',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
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
              ),
            ],
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
