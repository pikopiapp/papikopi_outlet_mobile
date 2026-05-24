import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../theme/thema.dart';
import '../widgets/header.dart';

class InvestorScreen extends StatefulWidget {
  const InvestorScreen({super.key});

  @override
  State<InvestorScreen> createState() => _InvestorScreenState();
}

class _InvestorScreenState extends State<InvestorScreen> {
  final _supabaseService = SupabaseService();
  int _selectedIndex = 0;

  late final Future<void> _supabaseInitFuture;

  // 0: Profile, 1: Revenue, 2: Report Outlet, 3: Notifikasi
  final List<Widget> _screens = const [
    _InvestorProfilePlaceholder(),
    _InvestorRevenuePlaceholder(),
    _InvestorReportOutletPlaceholder(),
    _InvestorNotificationPlaceholder(),
  ];

  @override
  void initState() {
    super.initState();
    // Extra guard: pastikan Supabase sudah siap sebelum screen mulai query
    _supabaseInitFuture = _supabaseService.initialize();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleLogout() async {
    await _supabaseService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _handleProfile() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  void _handleSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings investor masih placeholder')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PapikopiAppBar(
        onLogout: _handleLogout,
        onProfile: _handleProfile,
        onSettings: _handleSettings,
      ),
      body: FutureBuilder<void>(
        future: _supabaseInitFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: _InfoBox(
                title: 'Error Supabase',
                value: 'Gagal menginisialisasi koneksi database.',
              ),
            );
          }

          return _screens[_selectedIndex];
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Revenue',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Report Outlet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_active),
            label: 'Notifikasi',
          ),
        ],
      ),
    );
  }
}

class _InvestorProfilePlaceholder extends StatefulWidget {
  const _InvestorProfilePlaceholder();

  @override
  State<_InvestorProfilePlaceholder> createState() => _InvestorProfilePlaceholderState();
}

class _InvestorProfilePlaceholderState extends State<_InvestorProfilePlaceholder> {
  final _supabaseService = SupabaseService();

  Future<List<Map<String, dynamic>>> _resolveInvestorOutlets() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) {
      return [];
    }

    // Fetch investor assignments with outlet details
    return _supabaseService.getInvestorAssignments(investorId: user.id);
  }

  Future<void> _seedTestData() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found')),
      );
      return;
    }

    try {
      await _supabaseService.seedTestInvestorAssignments(investorId: user.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Test data seeded successfully')),
      );
      // Refresh the UI
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
              'Kelola investasi Anda dan pantau performa outlet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Outlet yang diinvestasikan',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _resolveInvestorOutlets(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 56,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snap.hasError) {
                  return _InfoBox(
                    title: "Error",
                    value: "Gagal memuat outlet investor: ${snap.error}",
                  );
                }

                final rows = snap.data ?? [];
                if (rows.isNotEmpty) {
                }
                
                if (rows.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoBox(
                        title: "Outlet investor",
                        value: "Belum ada outlet yang diinvestasikan untuk user.id=${user?.id ?? '-'}",
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _seedTestData,
                        icon: const Icon(Icons.add),
                        label: const Text('Seed Test Data (Dev)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  );
                }

                // Calculate summary
                double totalInvestment = 0;
                double avgMargin = 0;
                for (final r in rows) {
                  final amount = (r['investment_amount'] as num?)?.toDouble() ?? 0.0;
                  final margin = (r['margin_percentage'] as num?)?.toDouble() ?? 0.0;
                  totalInvestment += amount;
                  avgMargin += margin;
                }
                avgMargin = rows.isNotEmpty ? avgMargin / rows.length : 0;

                final formattedTotal = totalInvestment.toStringAsFixed(0)
                    .replaceAllMapped(
                      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                      (match) => '${match.group(1)}.',
                    );

                return Column(
                  children: [
                    // Summary Table
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          // Row 1: Total Investasi
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Investasi',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Rp $formattedTotal',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: Colors.blue[200],
                          ),
                          // Row 2: Rata-rata Profit
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Rata-rata Profit',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${avgMargin.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: Colors.blue[200],
                          ),
                          // Row 3: Jumlah Outlet
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Jumlah Outlet',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${rows.length}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Outlet List
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final r = rows[index];
                        final outletName = (r['outlet_name'] as String?) ?? '-';
                        final outletType = (r['outlet_type'] as String?) ?? 'unknown';
                        final investmentAmount =
                            (r['investment_amount'] as num?)?.toDouble() ?? 0.0;
                        final marginPercentage =
                            (r['margin_percentage'] as num?)?.toDouble() ?? 0.0;
                        final status = (r['status'] as String?) ?? 'unknown';

                        // Format currency
                        final formattedAmount = investmentAmount.toStringAsFixed(0)
                            .replaceAllMapped(
                              RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                              (match) => '${match.group(1)}.',
                            );

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
                                    Colors.blue.shade50,
                                    Colors.blue.shade100,
                                  ],
                                ),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Color(0xFF1F4E5F),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              outletType
                                                  .replaceAll('_', ' ')
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: status == 'active'
                                              ? Colors.green[100]
                                              : Colors.orange[100],
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: status == 'active'
                                                ? Colors.green[400]!
                                                : Colors.orange[400]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: status == 'active'
                                                ? Colors.green[800]
                                                : Colors.orange[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 1,
                                    color: Colors.blue[200],
                                  ),
                                  const SizedBox(height: 12),
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
                                              'Modal Investasi',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.blue[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Rp $formattedAmount',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1F4E5F),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Bagian Profit',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.green[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${marginPercentage.toStringAsFixed(1)}%',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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

class _InvestorRevenuePlaceholder extends StatefulWidget {
  const _InvestorRevenuePlaceholder();

  @override
  State<_InvestorRevenuePlaceholder> createState() => _InvestorRevenuePlaceholderState();
}

class _InvestorRevenuePlaceholderState extends State<_InvestorRevenuePlaceholder> {
  final _supabaseService = SupabaseService();
  String _period = 'daily';

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
      selectedDate: DateTime.now(),
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
              const Text('Pilih periode:'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PillButton(
                    active: _period == 'daily',
                    label: 'Harian (Daily)',
                    onTap: () => setState(() => _period = 'daily'),
                  ),
                  _PillButton(
                    active: _period == 'weekly',
                    label: 'Mingguan (Weekly)',
                    onTap: () => setState(() => _period = 'weekly'),
                  ),
                  _PillButton(
                    active: _period == 'monthly',
                    label: 'Bulanan (Monthly)',
                    onTap: () => setState(() => _period = 'monthly'),
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

                  // Calculate total revenue across outlets
                  double totalRevenue = 0;
                  double totalInvestorShare = 0;
                  int totalTransactions = 0;

                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: Future.wait(
                      outlets.map((outlet) async {
                        final revenue = await _fetchRevenueForOutlet(
                          outlet['outlet_id'] as String? ?? '',
                        );
                        return {
                          ...outlet,
                          'revenue': revenue,
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
                      totalRevenue = 0;
                      totalInvestorShare = 0;
                      totalTransactions = 0;

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

                        totalRevenue += amount;
                        totalInvestorShare +=
                            (amount * margin / 100).toDouble();
                        totalTransactions += count;
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
                                          'Total Revenue',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.purple[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Rp ${_formatCurrency(totalRevenue)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple[800],
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
                                          'Bagian Anda',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.teal[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Rp ${_formatCurrency(totalInvestorShare)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal[800],
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
                                          'Transaksi',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '$totalTransactions',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[800],
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
                              final cash =
                                  (periodData['cash'] as num?)?.toDouble() ?? 0.0;
                              final qris =
                                  (periodData['qris'] as num?)?.toDouble() ?? 0.0;
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
                                          Colors.cyan.shade50,
                                          Colors.cyan.shade100,
                                        ],
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header: Outlet Name
                                        Text(
                                          outletName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Color(0xFF1F4E5F),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          height: 1,
                                          color: Colors.cyan[200],
                                        ),
                                        const SizedBox(height: 12),
                                        // Revenue Row 1
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
                                                    'Total Revenue',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.cyan[600],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Rp ${_formatCurrency(amount)}',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF1F4E5F),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    'Bagian Anda',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.green[600],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Rp ${_formatCurrency(investorShare)}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.green[700],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Revenue Row 2
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
                                                    'Transaksi',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.cyan[600],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '$count',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF1F4E5F),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    'Metode Pembayaran',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.cyan[600],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Cash: Rp ${_formatCurrency(cash)} | QRIS: Rp ${_formatCurrency(qris)}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.cyan[700],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
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

class _InvestorReportOutletPlaceholder extends StatefulWidget {
  const _InvestorReportOutletPlaceholder();

  @override
  State<_InvestorReportOutletPlaceholder> createState() =>
      _InvestorReportOutletPlaceholderState();
}

class _InvestorReportOutletPlaceholderState
    extends State<_InvestorReportOutletPlaceholder> {
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
              const SizedBox(height: 12),
              const Text(
                'Ringkasan outlet yang diinvestasikan.',
              ),
              const SizedBox(height: 24),
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
                                      'Total Outlet',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$totalOutlets',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[800],
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
                                      'Outlet Aktif',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$activeOutlets',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[800],
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
                                        color: Colors.orange[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rp ${_formatCurrency(totalInvestment)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[800],
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
                                      Colors.indigo.shade50,
                                      Colors.indigo.shade100,
                                    ],
                                  ),
                                ),
                                padding: const EdgeInsets.all(14),
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
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Color(0xFF1F4E5F),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                outletType
                                                    .replaceAll('_', ' ')
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.indigo[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: status == 'active'
                                                ? Colors.green[100]
                                                : Colors.orange[100],
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: status == 'active'
                                                  ? Colors.green[400]!
                                                  : Colors.orange[400]!,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: status == 'active'
                                                  ? Colors.green[800]
                                                  : Colors.orange[800],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 1,
                                      color: Colors.indigo[200],
                                    ),
                                    const SizedBox(height: 12),
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
                                                'Modal Investasi',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.indigo[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Rp ${_formatCurrency(investmentAmount)}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1F4E5F),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Margin Profit',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.green[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '${marginPercentage.toStringAsFixed(1)}%',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
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

class _InvestorNotificationPlaceholder extends StatefulWidget {
  const _InvestorNotificationPlaceholder();

  @override
  State<_InvestorNotificationPlaceholder> createState() =>
      _InvestorNotificationPlaceholderState();
}

class _InvestorNotificationPlaceholderState
    extends State<_InvestorNotificationPlaceholder> {
  final _supabaseService = SupabaseService();
  String _selectedTab = 'transactions'; // transactions, announcements, chat

  Future<String?> _resolveInvestorOutletId() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return null;

    final outlets = await _supabaseService.getActiveInvestorOutlets(
      investorId: user.id,
    );
    if (outlets.isEmpty) return null;

    return outlets.first.id;
  }

  Future<List<Map<String, dynamic>>> _fetchNotifications(String outletId) {
    return _supabaseService.getRecentTransactions(
      outletId: outletId,
      limit: 5,
    );
  }

  void _showAnnouncementDetail(Map<String, dynamic> announcement) {
    final title = announcement['title']?.toString() ?? 'Pengumuman';
    final content = announcement['description']?.toString() ?? '';
    final createdAt = announcement['created_at']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 40,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                createdAt,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
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
                'Notifikasi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Tab buttons - inline row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _PillButton(
                      active: _selectedTab == 'transactions',
                      label: '💳 Transaksi',
                      onTap: () => setState(() => _selectedTab = 'transactions'),
                    ),
                    const SizedBox(width: 8),
                    _PillButton(
                      active: _selectedTab == 'announcements',
                      label: '📢 Pengumuman',
                      onTap: () => setState(() => _selectedTab = 'announcements'),
                    ),
                    const SizedBox(width: 8),
                    _PillButton(
                      active: _selectedTab == 'chat',
                      label: '💬 Chat',
                      onTap: () => setState(() => _selectedTab = 'chat'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Content based on selected tab
              if (_selectedTab == 'transactions') ...[
                _buildTransactionsContent(),
              ] else if (_selectedTab == 'announcements') ...[
                _buildAnnouncementsContent(),
              ] else if (_selectedTab == 'chat') ...[
                _buildChatContent(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsContent() {
    return FutureBuilder<String?>(
      future: _resolveInvestorOutletId(),
      builder: (context, outletSnap) {
        final outletId = outletSnap.data;
        if (outletSnap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (outletId == null || outletId.isEmpty) {
          return const _InfoBox(
            title: 'Outlet investor',
            value: 'Belum ada data outlet active untuk investor.',
          );
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchNotifications(outletId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return _InfoBox(
                title: 'Error',
                value: 'Gagal memuat notifikasi: ${snapshot.error}',
              );
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return const _InfoBox(
                title: 'Kosong',
                value: 'Belum ada transaksi terbaru.',
              );
            }

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
                children: items.map((t) {
                  final id = t['id']?.toString() ?? '';
                  final total =
                      (t['total_amount'] as num?)?.toDouble() ?? 0.0;
                  final payment = t['payment_method']?.toString() ?? '';
                  final createdAt = t['created_at']?.toString() ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• Transaksi #$id',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '  Total: Rp${total.toStringAsFixed(0)} | ${payment.toUpperCase()}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '  Waktu: $createdAt',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnnouncementsContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _supabaseService.getAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _InfoBox(
            title: 'Error',
            value: 'Gagal memuat pengumuman: ${snapshot.error}',
          );
        }

        final announcements = snapshot.data ?? [];
        if (announcements.isEmpty) {
          return const _InfoBox(
            title: 'Kosong',
            value: 'Tidak ada pengumuman saat ini.',
          );
        }

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
            children: announcements.asMap().entries.map((entry) {
              final index = entry.key;
              final announcement = entry.value;

              final title = announcement['title']?.toString() ?? 'Pengumuman';
              final content = announcement['description']?.toString() ?? '';
              final createdAt = announcement['created_at']?.toString() ?? '';

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < announcements.length - 1 ? 12 : 0,
                ),
                child: InkWell(
                  onTap: () {
                    _showAnnouncementDetail(announcement);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        content,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              createdAt,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              _showAnnouncementDetail(announcement);
                            },
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text('Detail'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 0,
                              ),
                              minimumSize: const Size(0, 0),
                            ),
                          ),
                        ],
                      ),
                      if (index < announcements.length - 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Divider(
                            height: 1,
                            color: AppColors.altSurface,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildChatContent() {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId == null) {
      return const _InfoBox(
        title: 'Error',
        value: 'User tidak ditemukan. Silakan login kembali.',
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _supabaseService.getPrivateMessagesWithSenderInfo(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _InfoBox(
            title: 'Error',
            value: 'Gagal memuat chat: ${snapshot.error}',
          );
        }

        final messages = snapshot.data ?? [];
        if (messages.isEmpty) {
          return const _InfoBox(
            title: 'Kosong',
            value: 'Belum ada chat pribadi.',
          );
        }

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
            children: messages.asMap().entries.map((entry) {
              final index = entry.key;
              final message = entry.value;

              final senderName = message['sender_name']?.toString() ?? 'Unknown';
              final content = message['message']?.toString() ?? '';
              final createdAt = message['created_at']?.toString() ?? '';

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < messages.length - 1 ? 12 : 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '👤 $senderName',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      createdAt,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    if (index < messages.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Divider(
                          height: 1,
                          color: AppColors.altSurface,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
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
