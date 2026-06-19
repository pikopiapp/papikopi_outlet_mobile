import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/thema.dart';
import '../../services/supabase_service.dart';
import '../../providers/auth_provider.dart';
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
    // Default selectedDate should follow business-day logic: if current
    // local time is before 04:00, treat selected date as previous calendar day.
    final now = DateTime.now();
    if (now.hour < 4) {
      final prev = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      selectedDate = prev;
    } else {
      selectedDate = DateTime(now.year, now.month, now.day);
    }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _loadDateSales() async {
    try {
      // Business day: 04:00 local (UTC+7) = 21:00 previous day UTC
      // For date 2026-06-11, business day is 2026-06-10 21:00 UTC to 2026-06-11 21:00 UTC
      final selectedLocal = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        4,
      );
      final startOfDay = selectedLocal.subtract(
        const Duration(hours: 7),
      ); // Convert to UTC
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
      debugPrint('Error loading date sales: $e');
    }
  }

  Future<void> _loadDateTransactions() async {
    try {
      // Business day: 04:00 local (UTC+7) = 21:00 previous day UTC
      final selectedLocal = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        4,
      );
      final startOfDayUtc = selectedLocal.subtract(const Duration(hours: 7)).toUtc();
      final endOfDayUtc = startOfDayUtc.add(const Duration(days: 1));

        // Get outlet id from AuthProvider
        final auth = context.read<AuthProvider>();
        // Managers should see all outlets (no outlet filter). Baristas see their outlet only.
        final outletId = auth.currentUser?.role == 'manager'
          ? null
          : auth.currentUser?.outletId;

      // Fetch sales using service helper (reuses Sale.fromJson parsing)
      final fetched = await supabaseService.getSales(outletId: outletId);
      debugPrint('[ManagerDashboard] fetched sales: ${fetched.length}, outletId: $outletId');

      // Filter by business-day UTC range
      final filtered = fetched.where((s) {
        final createdUtc = s.createdAt.toUtc();
        return !createdUtc.isBefore(startOfDayUtc) && createdUtc.isBefore(endOfDayUtc);
      }).toList();
      debugPrint('[ManagerDashboard] filtered sales by range (${startOfDayUtc.toIso8601String()} - ${endOfDayUtc.toIso8601String()}): ${filtered.length}');

      // Sort descending and take latest 5
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final top5 = filtered.take(5).toList();

      // Resolve outlet names (cache per id) to avoid showing raw ids
      final Map<String, String> outletNames = {};
      // Fetch outlet names from `outlets` table once to map ids -> names.
      try {
        final outletsResp = await supabaseService.client.from('outlets').select('id, name');
        for (var o in outletsResp) {
          outletNames[o['id']] = o['name'];
        }
      } catch (e) {
        debugPrint('[ManagerDashboard] failed to fetch outlets: $e');
      }

      final transactions = top5.map((sale) {
        final oid = sale.outletId;
        final displayTime = DateFormat('HH:mm', 'id_ID')
            .format(sale.createdAt.add(const Duration(hours: 7)));
        return {
          'id': sale.id,
          'amount': sale.totalAmount,
          'outlet': outletNames[oid] ?? 'Unknown',
          'time': displayTime,
          'payment_method': sale.paymentMethod,
        };
      }).toList();

      setState(() {
        recentTransactions = transactions;
        totalTransactions = filtered.length;
      });
    } catch (e) {
      debugPrint('Error loading date transactions: $e');
    }
  }

  Future<void> _loadDateTopOutlets() async {
    try {
      // Business day: 04:00 local (UTC+7) = 21:00 previous day UTC
      // For date 2026-06-11, business day is 2026-06-10 21:00 UTC to 2026-06-11 21:00 UTC
      final selectedLocal = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        4,
      );
      final startOfDay = selectedLocal.subtract(
        const Duration(hours: 7),
      ); // Convert to UTC
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
      debugPrint('Error loading date top outlets: $e');
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
    final isToday =
        DateTime.now().day == selectedDate.day &&
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
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'manager',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isToday
                                            ? 'Hari Ini'
                                            : dayFormat.format(selectedDate),
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
                              color: Colors.black.withValues(alpha: 0.05),
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
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ManagerOutletScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.storefront_outlined,
                                      size: 20,
                                    ),
                                    label: const Text('Outlet'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade600,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ExpenseManagementScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.receipt_long_outlined,
                                      size: 20,
                                    ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const BaristaPaymentScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.payments_outlined,
                                  size: 20,
                                ),
                                label: const Text('Pembayaran Bonus Barista'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade600,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const InvestorProfitPaymentScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.trending_up_outlined,
                                  size: 20,
                                ),
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
                              AppColors.primary.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
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
                                  isToday
                                      ? 'Penjualan Hari Ini'
                                      : 'Penjualan ${dayFormat.format(selectedDate)}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
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
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Total dari $totalTransactions transaksi',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
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
                              value: totalTransactions.toString(),
                              icon: Icons.receipt,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Rata-rata',
                              value: totalTransactions == 0
                                  ? 'Rp 0'
                                  : currencyFormat.format(
                                      todaySales / totalTransactions,
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
                        isToday
                            ? 'Outlet Terbaik Hari Ini'
                            : 'Outlet Terbaik ${dateFormat.format(selectedDate)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
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
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              children: List.generate(topOutlets.length, (
                                index,
                              ) {
                                final outlet = topOutlets[index];
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index < topOutlets.length - 1
                                        ? 12
                                        : 0,
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
                        isToday
                            ? '5 Transaksi Terbaru'
                            : '5 Transaksi ${dateFormat.format(selectedDate)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
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
                                  isToday
                                      ? 'Belum ada transaksi hari ini'
                                      : 'Belum ada transaksi pada tanggal tersebut',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              children: List.generate(
                                recentTransactions.length,
                                (index) {
                                  final tx = recentTransactions[index];
                                  // `tx['time']` is already a formatted string (HH:mm)
                                  final timeString = tx['time'] as String;

                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          index < recentTransactions.length - 1
                                          ? 12
                                          : 0,
                                    ),
                                    child: _buildTransactionCard(
                                      outlet: tx['outlet'],
                                      amount: tx['amount'],
                                      time: timeString,
                                      paymentMethod: tx['payment_method'] ?? '',
                                      currencyFormat: currencyFormat,
                                    ),
                                  );
                                },
                              ),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
            color: Colors.black.withValues(alpha: 0.08),
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
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.5)),
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
    required String paymentMethod,
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
            color: Colors.black.withValues(alpha: 0.08),
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
              color: AppColors.success.withValues(alpha: 0.1),
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
                Row(
                  children: [
                    Text(
                      time,
                      style: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (paymentMethod.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.altSurface),
                        ),
                        child: Text(
                          paymentMethod.toString().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
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
