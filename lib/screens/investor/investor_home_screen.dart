import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';

class InvestorHomeScreen extends StatefulWidget {
  const InvestorHomeScreen({super.key, this.onNavigate});

  final Function(int)? onNavigate;

  @override
  State<InvestorHomeScreen> createState() => _InvestorHomeScreenState();
}

class _InvestorHomeScreenState extends State<InvestorHomeScreen> {
  final _supabaseService = SupabaseService();
  String _chartPeriod = 'daily'; // 'daily' or 'monthly'

  Future<List<Map<String, dynamic>>> _resolveInvestorOutlets() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) {
      return [];
    }
    return _supabaseService.getInvestorAssignments(investorId: user.id);
  }

  /// Fetch daily profit trend for last 30 days
  Future<List<FlSpot>> _fetchDailyChartData() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      if (user == null) return [];

      final outlets = await _supabaseService.getInvestorAssignments(investorId: user.id);
      if (outlets.isEmpty) return [];

      final spots = <FlSpot>[];
      final now = DateTime.now();

      // Get last 30 days of data
      for (int i = 29; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day, 21, 0);
        final endOfDay = DateTime(date.year, date.month, date.day + 1, 20, 59, 59);

        double totalProfit = 0;
        for (final outlet in outlets) {
          final outletId = outlet['outlet_id'] as String? ?? '';
          final margin = (outlet['margin_percentage'] as num?)?.toDouble() ?? 0.0;
          
          final hppData = await _supabaseService.getHppSummary(
            outletId: outletId,
            startDate: startOfDay,
            endDate: endOfDay,
          );

          final sales = (hppData['totalSales'] as num?)?.toDouble() ?? 0.0;
          final profit = sales * (margin / 100);
          totalProfit += profit;
        }

        spots.add(FlSpot(i.toDouble(), totalProfit / 1000000));
      }

      return spots;
    } catch (e) {
      return [];
    }
  }

  /// Fetch monthly profit trend for last 12 months
  Future<List<FlSpot>> _fetchMonthlyChartData() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      if (user == null) return [];

      final outlets = await _supabaseService.getInvestorAssignments(investorId: user.id);
      if (outlets.isEmpty) return [];

      final spots = <FlSpot>[];
      final now = DateTime.now();

      // Get last 12 months of data
      for (int i = 11; i >= 0; i--) {
        final monthDate = DateTime(now.year, now.month - i, 1);
        final startOfMonth = DateTime(monthDate.year, monthDate.month, 1);
        final endOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0, 23, 59, 59);

        double totalProfit = 0;
        for (final outlet in outlets) {
          final outletId = outlet['outlet_id'] as String? ?? '';
          final margin = (outlet['margin_percentage'] as num?)?.toDouble() ?? 0.0;
          
          final hppData = await _supabaseService.getHppSummary(
            outletId: outletId,
            startDate: startOfMonth,
            endDate: endOfMonth,
          );

          final sales = (hppData['totalSales'] as num?)?.toDouble() ?? 0.0;
          final profit = sales * (margin / 100);
          totalProfit += profit;
        }

        spots.add(FlSpot(i.toDouble(), totalProfit / 1000000));
      }

      return spots;
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat Datang, ${user?.name ?? "Investor"}! 👋',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Pantau performa investasi Anda',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              // Chart Header
              Text(
                'Tren Profit ${_chartPeriod == 'daily' ? '30 Hari Terakhir' : '12 Bulan Terakhir'}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Period Selection
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _chartPeriod = 'daily'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _chartPeriod == 'daily' 
                            ? AppColors.primary.withOpacity(0.2) 
                            : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _chartPeriod == 'daily' 
                              ? AppColors.primary 
                              : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          'Harian',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _chartPeriod == 'daily' 
                              ? AppColors.primary 
                              : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _chartPeriod = 'monthly'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _chartPeriod == 'monthly' 
                            ? AppColors.primary.withOpacity(0.2) 
                            : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _chartPeriod == 'monthly' 
                              ? AppColors.primary 
                              : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          'Bulanan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _chartPeriod == 'monthly' 
                              ? AppColors.primary 
                              : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Line Chart
              FutureBuilder<List<FlSpot>>(
                future: _chartPeriod == 'daily' 
                  ? _fetchDailyChartData() 
                  : _fetchMonthlyChartData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 250,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.altSurface),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                    return Container(
                      height: 250,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.altSurface),
                      ),
                      child: const Center(
                        child: Text('Tidak ada data untuk ditampilkan'),
                      ),
                    );
                  }

                  final spots = snapshot.data!;
                  final maxYValue = spots.isNotEmpty 
                    ? (spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2)
                    : 10.0;

                  return Container(
                    height: 250,
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.altSurface),
                    ),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxYValue / 4,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey[300],
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: _chartPeriod == 'daily' ? 5 : 2,
                              getTitlesWidget: (value, meta) {
                                if (_chartPeriod == 'daily') {
                                  final dayIndex = value.toInt();
                                  final now = DateTime.now();
                                  final date = now.subtract(Duration(days: 29 - dayIndex));
                                  if (dayIndex % 5 == 0) {
                                    return Text(
                                      '${date.day}/${date.month}',
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  }
                                  return const Text('');
                                } else {
                                  final monthIndex = value.toInt();
                                  final now = DateTime.now();
                                  final month = now.month - (11 - monthIndex);
                                  final displayMonth = month > 0 ? month : month + 12;
                                  if (monthIndex % 2 == 0) {
                                    return Text(
                                      '$displayMonth',
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  }
                                  return const Text('');
                                }
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: maxYValue / 4,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                              reservedSize: 40,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: _chartPeriod == 'daily' ? 29 : 11,
                        minY: 0,
                        maxY: maxYValue,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.6),
                              ],
                            ),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.2),
                                  AppColors.primary.withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true,
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor: AppColors.primary.withOpacity(0.8),
                            tooltipBorder: BorderSide(
                              color: AppColors.primary,
                              width: 1,
                            ),
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((barSpot) {
                                return LineTooltipItem(
                                  'Rp ${barSpot.y.toStringAsFixed(1)}M',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // 3 Summary Cards
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _resolveInvestorOutlets(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final outlets = snap.data ?? [];
                  
                  // Calculate summary
                  double totalInvestment = 0;
                  double avgMonthlyProfit = 0;
                  String bestPerformer = 'N/A';
                  double bestMargin = 0;
                  
                  for (final outlet in outlets) {
                    final amount = (outlet['investment_amount'] as num?)?.toDouble() ?? 0.0;
                    final margin = (outlet['margin_percentage'] as num?)?.toDouble() ?? 0.0;
                    totalInvestment += amount;
                    
                    if (margin > bestMargin) {
                      bestMargin = margin;
                      bestPerformer = (outlet['outlet_name'] as String?) ?? 'N/A';
                    }
                  }
                  
                  avgMonthlyProfit = (totalInvestment * (bestMargin / 100)) / 12;

                  final formattedTotal = totalInvestment.toStringAsFixed(0)
                      .replaceAllMapped(
                        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                        (match) => '${match.group(1)}.',
                      );
                  
                  final formattedProfit = avgMonthlyProfit.toStringAsFixed(0)
                      .replaceAllMapped(
                        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                        (match) => '${match.group(1)}.',
                      );

                  return Column(
                    children: [
                      // Card 1: Total Investment - Full Width, Bigger, Center Aligned
                      SizedBox(
                        width: double.infinity,
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [Colors.orange.shade50, Colors.orange.shade100],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Total Investasi',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Rp $formattedTotal',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Row 2: Profit Estimasi & Outlet Terbaik (2 columns)
                      Row(
                        children: [
                          // Card 2: Average Monthly Profit
                          Expanded(
                            child: Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    colors: [Colors.green.shade50, Colors.green.shade100],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Profit Estimasi/Bulan',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Rp $formattedProfit',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Card 3: Best Performing Outlet
                          Expanded(
                            child: Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Outlet Terbaik',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      bestPerformer,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$bestMargin% profit',
                                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Quick Links
                      const Text(
                        'Akses Cepat',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                // Navigate to Revenue screen
                                widget.onNavigate?.call(1);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.primary),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      '📊',
                                      style: TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Revenue',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Detail Analisis',
                                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                // Navigate to Report screen
                                widget.onNavigate?.call(2);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.primary),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      '🏪',
                                      style: TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Outlet',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Kelola Investasi',
                                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
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
