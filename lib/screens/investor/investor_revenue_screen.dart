import 'package:flutter/material.dart';

import '../../theme/thema.dart';
import '../../utils/profit_margin_calculator.dart';
import '../../widgets/profit_breakdown_widget.dart';
import 'shared/investor_widgets.dart';
import 'shared/investor_data_mixin.dart';

class InvestorRevenueScreen extends StatefulWidget {
  const InvestorRevenueScreen({super.key});

  @override
  State<InvestorRevenueScreen> createState() => _InvestorRevenueScreenState();
}

class _InvestorRevenueScreenState extends State<InvestorRevenueScreen>
    with InvestorDataMixin {
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
    final baseNow = (now.hour < 4)
        ? DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 1))
        : DateTime(now.year, now.month, now.day);
    switch (_period) {
      case 'daily':
        _startDate = DateTime(baseNow.year, baseNow.month, baseNow.day - 1);
        _endDate = DateTime(baseNow.year, baseNow.month, baseNow.day);
        break;
      case 'weekly':
        _startDate = baseNow.subtract(const Duration(days: 7));
        _endDate = baseNow;
        break;
      case 'monthly':
      default:
        final nowUtc = now.toUtc();
        final nowInJakarta = nowUtc.add(const Duration(hours: 7));
        _startDate = DateTime.utc(
          nowInJakarta.year,
          nowInJakarta.month,
          1,
        ).subtract(const Duration(hours: 7));
        _endDate = nowUtc;
        break;
    }
  }

  Future<Map<String, dynamic>> _fetchRevenueForOutlet(String outletId) async {
    return supabaseService.getRevenueData(
      outletId: outletId,
      selectedDate: DateTime.now(),
    );
  }

  /// Get actual HPP data from Supabase for a given period
  Future<Map<String, dynamic>> _fetchHppForOutlet(
    String outletId,
    String? assignmentStartDate,
  ) async {
    return supabaseService.getHppSummary(
      outletId: outletId,
      startDate: _startDate,
      endDate: _endDate,
      assignmentStartDate: assignmentStartDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final baseNow = (now.hour < 4)
        ? DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 1))
        : DateTime(now.year, now.month, now.day);
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
                  const Text('Pilih periode:', style: TextStyle(fontSize: 13)),
                  Row(
                    spacing: 8,
                    children: [
                      PillButton(
                        active: _period == 'daily',
                        label: 'Hari',
                        onTap: () => setState(() {
                          _period = 'daily';
                          _updateDateRange();
                        }),
                      ),
                      PillButton(
                        active: _period == 'weekly',
                        label: 'Minggu',
                        onTap: () => setState(() {
                          _period = 'weekly';
                          _updateDateRange();
                        }),
                      ),
                      PillButton(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                            const Icon(
                              Icons.edit,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                            lastDate: baseNow,
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
                            const Icon(
                              Icons.edit,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: resolveInvestorOutlets(),
                builder: (context, outletsSnap) {
                  if (outletsSnap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 140,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (outletsSnap.hasError) {
                    return InfoBox(
                      title: 'Error',
                      value:
                          'Gagal memuat outlets investor: ${outletsSnap.error}',
                    );
                  }

                  final outlets = outletsSnap.data ?? [];
                  if (outlets.isEmpty) {
                    return const InfoBox(
                      title: 'Outlet investor',
                      value: 'Belum ada outlet yang diinvestasikan.',
                    );
                  }

                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: Future.wait(
                      outlets.map((outlet) async {
                        final outletId = outlet['outlet_id'] as String? ?? '';
                        final revenue = await _fetchRevenueForOutlet(outletId);
                        final hpp = await _fetchHppForOutlet(
                          outletId,
                          outlet['start_date'] as String?,
                        );
                        return {...outlet, 'revenue': revenue, 'hpp': hpp};
                      }),
                    ),
                    builder: (context, revenueSnap) {
                      if (revenueSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox(
                          height: 140,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (revenueSnap.hasError) {
                        return InfoBox(
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
                        final hpp =
                            (item['hpp'] as Map<String, dynamic>?) ?? {};
                        final profit =
                            (hpp['totalProfit'] as num?)?.toDouble() ?? 0.0;
                        final cash =
                            (periodData['cash'] as num?)?.toDouble() ?? 0.0;
                        final qris =
                            (periodData['qris'] as num?)?.toDouble() ?? 0.0;

                        totalRevenue += amount;
                        totalInvestorShare += (profit * margin / 100)
                            .toDouble();
                        totalTransactions += count;
                        totalCash += cash;
                        totalQris += qris;
                      }

                      final avgTransactionValue = totalTransactions > 0
                          ? totalRevenue / totalTransactions
                          : 0.0;

                      return Column(
                        children: [
                          // Mixed Layout: 2-col, 2-col, Full to avoid empty space
                          Column(
                            children: [
                              // Row 1: Card 1 + Card 2 (2 columns)
                              Row(
                                children: [
                                  Expanded(
                                    child: SummaryCard(
                                      label: 'Total Revenue',
                                      value:
                                          'Rp${formatCurrency(totalRevenue)}',
                                      bgColor: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: SummaryCard(
                                      label: 'Share Investor',
                                      value:
                                          'Rp${formatCurrency(totalInvestorShare)}',
                                      bgColor: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Row 2: Card 3 + Card 4 (2 columns)
                              Row(
                                children: [
                                  Expanded(
                                    child: SummaryCard(
                                      label: 'Transaksi',
                                      value: '$totalTransactions',
                                      bgColor: Colors.purple,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: SummaryCard(
                                      label: 'Avg Transaksi',
                                      value:
                                          'Rp${formatCurrency(avgTransactionValue)}',
                                      bgColor: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Row 3: Card 5 + Card 6 (2 columns)
                              Row(
                                children: [
                                  Expanded(
                                    child: SummaryCard(
                                      label: 'CASH',
                                      value: 'Rp${formatCurrency(totalCash)}',
                                      bgColor: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: SummaryCard(
                                      label: 'QRIS',
                                      value: 'Rp${formatCurrency(totalQris)}',
                                      bgColor: Colors.teal,
                                    ),
                                  ),
                                ],
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
                              final hpp =
                                  (item['hpp'] as Map<String, dynamic>?) ?? {};
                              final profit =
                                  (hpp['totalProfit'] as num?)?.toDouble() ??
                                  0.0;
                              final investorShare = (profit * margin / 100)
                                  .toDouble();

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
                                        // 2 Column Grid for Profit Detail
                                        Column(
                                          children: [
                                            // Row 1: Revenue + Investor Share
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Revenue',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Rp${formatCurrency(amount)}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        'Investor Share',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Rp${formatCurrency(investorShare)}',
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
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            // Row 2: Margin + Transaksi
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Margin',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.grey[600],
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
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        'Transaksi',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.grey[600],
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
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Profit Breakdown Section - Using real HPP from database
                                        Builder(
                                          builder: (context) {
                                            final actualHpp =
                                                (hpp['totalHpp'] as num?)
                                                    ?.toDouble() ??
                                                0.0;
                                            final actualSales =
                                                (hpp['totalSales'] as num?)
                                                    ?.toDouble() ??
                                                amount;
                                            final actualBonus =
                                                (hpp['totalBonus'] as num?)
                                                    ?.toDouble() ??
                                                0.0;
                                            final actualMeal =
                                                (hpp['totalMealAllowance']
                                                        as num?)
                                                    ?.toDouble() ??
                                                0.0;
                                            final actualProfit =
                                                (hpp['totalProfit'] as num?)
                                                    ?.toDouble() ??
                                                0.0;
                                            final actualInvestorShare =
                                                actualProfit * margin / 100;
                                            return ProfitBreakdownCard(
                                              result: ProfitCalculationResult(
                                                totalSales: actualSales,
                                                totalHpp: actualHpp,
                                                bonusBarista: actualBonus,
                                                mealAllowance: actualMeal,
                                                totalExpenses:
                                                    actualBonus + actualMeal,
                                                netProfit: actualProfit,
                                                investorPercentage: margin,
                                                investorProfit:
                                                    actualInvestorShare,
                                                outletProfit:
                                                    actualProfit -
                                                    actualInvestorShare,
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
