import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/thema.dart';
import '../../services/supabase_service.dart';
import 'manager_outlet_screen.dart';
import 'expense_management_screen.dart';
import 'barista_payment_screen.dart';
import 'investor_profit_payment_screen.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  late SupabaseService supabaseService;
  bool isLoading = true;
  
  late DateTime selectedDate;
  double todaySales = 0;
  int totalTransactions = 0;
  List<Map<String, dynamic>> recentTransactions = [];
  List<Map<String, dynamic>> topOutlets = [];

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    supabaseService = SupabaseService();
    _loadDashboardData();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        _loadDateSales(),
        _loadDateTransactions(),
        _loadDateTopOutlets(),
      ]);
      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _loadDateSales() async {
    try {
      final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await supabaseService.client
          .from('sales')
          .select('total_amount')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());

      double total = 0;
      for (var sale in response) {
        total += (sale['total_amount'] as num?)?.toDouble() ?? 0;
      }

      setState(() => todaySales = total);
    } catch (e) {
      print('Error loading date sales: $e');
    }
  }

  Future<void> _loadDateTransactions() async {
    try {
      final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await supabaseService.client
          .from('sales')
          .select('id, total_amount, outlet_id, created_at, outlets(name)')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .order('created_at', ascending: false)
          .limit(5);

      List<Map<String, dynamic>> transactions = [];
      for (var sale in response) {
        transactions.add({
          'id': sale['id'],
          'amount': sale['total_amount'],
          'outlet': sale['outlets']?['name'] ?? 'Unknown',
          'time': sale['created_at'],
        });
      }

      setState(() {
        recentTransactions = transactions;
        totalTransactions = response.length;
      });
    } catch (e) {
      print('Error loading date transactions: $e');
    }
  }

  Future<void> _loadDateTopOutlets() async {
    try {
      final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await supabaseService.client
          .from('sales')
          .select('outlet_id, total_amount, outlets(name)')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());

      Map<String, double> outletSales = {};
      Map<String, String> outletNames = {};

      for (var sale in response) {
        final outletId = sale['outlet_id'];
        final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;
        final name = sale['outlets']?['name'] ?? 'Unknown';

        outletNames[outletId] = name;
        outletSales[outletId] = (outletSales[outletId] ?? 0) + amount;
      }

      // Sort by sales amount
      final sorted = outletSales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      List<Map<String, dynamic>> topList = sorted.take(3).map((entry) {
        return {
          'name': outletNames[entry.key] ?? 'Unknown',
          'amount': entry.value,
          'rank': sorted.indexOf(entry) + 1,
        };
      }).toList();

      setState(() => topOutlets = topList);
    } catch (e) {
      print('Error loading date top outlets: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');
    final dayFormat = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');
    final isToday = DateTime.now().day == selectedDate.day &&
        DateTime.now().month == selectedDate.month &&
        DateTime.now().year == selectedDate.year;

    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: media.padding.bottom + 100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header dengan date picker
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dashboard',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'manager',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.altSurface),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isToday ? 'Hari Ini' : dayFormat.format(selectedDate),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      if (isToday)
                                        Text(
                                          dateFormat.format(selectedDate),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.expand_more,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Management Features Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.altSurface),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fitur Manajemen',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const ManagerOutletScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.storefront_outlined, size: 20),
                                    label: const Text('Outlet'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade600,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const ExpenseManagementScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.receipt_long_outlined, size: 20),
                                    label: const Text('Pengeluaran'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple.shade600,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const BaristaPaymentScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.payments_outlined, size: 20),
                                label: const Text('Pembayaran Bonus Barista'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade600,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const InvestorProfitPaymentScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.trending_up_outlined, size: 20),
                                label: const Text('Pembayaran Profit Investor'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sales Summary Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isToday ? 'Penjualan Hari Ini' : 'Penjualan ${dayFormat.format(selectedDate)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.trending_up,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              currencyFormat.format(todaySales),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Total dari ${recentTransactions.length} transaksi',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Quick Stats
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'Transaksi',
                              value: recentTransactions.length.toString(),
                              icon: Icons.receipt,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Rata-rata',
                              value: recentTransactions.isEmpty
                                  ? 'Rp 0'
                                  : currencyFormat.format(
                                      todaySales / recentTransactions.length,
                                    ),
                              icon: Icons.calculate,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Top Performing Outlets
                      Text(
                        isToday ? 'Outlet Terbaik Hari Ini' : 'Outlet Terbaik ${dateFormat.format(selectedDate)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 12),
                      topOutlets.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.altSurface),
                              ),
                              child: Center(
                                child: Text(
                                  'Belum ada data penjualan',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ),
                            )
                          : Column(
                              children: List.generate(topOutlets.length, (index) {
                                final outlet = topOutlets[index];
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index < topOutlets.length - 1 ? 12 : 0,
                                  ),
                                  child: _buildOutletCard(
                                    rank: outlet['rank'],
                                    name: outlet['name'],
                                    sales: outlet['amount'],
                                    currencyFormat: currencyFormat,
                                  ),
                                );
                              }),
                            ),
                      const SizedBox(height: 24),

                      // Recent Transactions
                      Text(
                        isToday ? 'Transaksi Terbaru' : 'Transaksi ${dateFormat.format(selectedDate)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 12),
                      recentTransactions.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.altSurface),
                              ),
                              child: Center(
                                child: Text(
                                  isToday ? 'Belum ada transaksi hari ini' : 'Belum ada transaksi pada tanggal tersebut',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ),
                            )
                          : Column(
                              children: List.generate(recentTransactions.length, (index) {
                                final tx = recentTransactions[index];
                                final timestamp = DateTime.parse(tx['time']);
                                final timeString =
                                    DateFormat('HH:mm', 'id_ID').format(timestamp);

                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index < recentTransactions.length - 1 ? 12 : 0,
                                  ),
                                  child: _buildTransactionCard(
                                    outlet: tx['outlet'],
                                    amount: tx['amount'],
                                    time: timeString,
                                    currencyFormat: currencyFormat,
                                  ),
                                );
                              }),
                            ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1F1F1F),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOutletCard({
    required int rank,
    required String name,
    required double sales,
    required NumberFormat currencyFormat,
  }) {
    final colors = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];
    final color = rank <= 3 ? colors[rank - 1] : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1F1F1F),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormat.format(sales),
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.trending_up, color: color, size: 20),
        ],
      ),
    );
  }

  Widget _buildTransactionCard({
    required String outlet,
    required double amount,
    required String time,
    required NumberFormat currencyFormat,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.check_circle, color: AppColors.success, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outlet,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1F1F1F),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            currencyFormat.format(amount),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

