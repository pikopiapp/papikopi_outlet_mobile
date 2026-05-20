import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../theme/thema.dart';
import '../widgets/header.dart';
import '../widgets/bonus_calculator_widget.dart';
import '../widgets/daily_bonus_card.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'approval_screen.dart';

// Helper function to format Rupiah with thousand separator (dots)
String formatRupiah(num? amount) {
  if (amount == null) return '0';
  final formatter = NumberFormat('#,###', 'id_ID');
  return formatter.format(amount.toInt());
}

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _refreshAnimationController;
  late Future<List<Map<String, dynamic>>> _leaderboardFuture;
  Map<String, dynamic>? _revenueData;
  bool _isLoadingRevenue = true;
  Map<String, dynamic>? _cashDepositData;
  bool _isLoadingCashDeposit = true;
  late DateTime _selectedDate;
  bool _isLoadingLeaderboard = true;
  bool _isRefreshing = false;
  late String _outletId;

  @override
  void initState() {
    super.initState();
    print('🔵 FinanceScreen initState called');
    // Initialize future dulu
    _selectedDate = DateTime.now();
    _leaderboardFuture = Future.value([]);
    // Initialize TabController
    _tabController = TabController(length: 4, vsync: this);
    // Initialize refresh animation controller
    _refreshAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    // Get outlet ID from AuthProvider
    // Note: We'll get it in the callback to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.currentUser != null) {
        _outletId = authProvider.currentUser!.outletId;
        print('🏪 Finance Screen - Outlet ID from AuthProvider: $_outletId');
        
        // Set loading states
        if (mounted) {
          setState(() {
            _isLoadingRevenue = true;
            _isLoadingCashDeposit = true;
            _isLoadingLeaderboard = true;
          });
        }
        
        // Load data
        _loadLeaderboard();
        _loadRevenue();
        _loadCashDeposit();
      } else {
        _outletId = '';
        print('⚠️ No user found in AuthProvider');
      }
    });
  }

  Future<void> _loadCashDeposit() async {
    final supabaseService = SupabaseService();
    
    try {
      final data = await supabaseService.getCashDepositData(
        outletId: _outletId,
        date: _selectedDate,
      );
      if (mounted) {
        setState(() {
          _cashDepositData = data;
          _isLoadingCashDeposit = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCashDeposit = false;
        });
      }
    }
  }

  // Helper method to reload and ensure UI updates
  Future<void> _reloadCashDepositWithRetry({int retries = 3}) async {
    try {
      for (int i = 0; i < retries; i++) {
        try {
          await Future.delayed(Duration(milliseconds: 500 + (i * 500)));
          
          final supabaseService = SupabaseService();
          final data = await supabaseService.getCashDepositData(
            outletId: _outletId,
            date: _selectedDate,
          );
          
          if (mounted) {
            setState(() {
              _cashDepositData = data;
              _isLoadingCashDeposit = false;
            });
          }
          
          // Check if status has updated
          final currentStatus = (data['handoverStatus'] as String?) ?? 'pending';
          print('🔄 Reload attempt ${i + 1}: handoverStatus = $currentStatus');
          
          if (currentStatus != 'pending') {
            // Status has been updated, force rebuild and stop retrying
            print('✅ Status updated to: $currentStatus, stopping retry');
            if (mounted) {
              setState(() {});
            }
            break;
          }
          
          // If this is the last retry, still update UI to stop loading
          if (i == retries - 1) {
            print('⚠️ Max retries reached, stopping with status: $currentStatus');
            if (mounted) {
              setState(() {
                _isLoadingCashDeposit = false;
              });
            }
          }
        } catch (e) {
          print('❌ Retry attempt ${i + 1} failed: $e');
          
          // On last attempt, stop loading regardless of error
          if (i == retries - 1) {
            print('⚠️ Max retries reached with error, stopping loading state');
            if (mounted) {
              setState(() {
                _isLoadingCashDeposit = false;
              });
            }
          }
        }
      }
    } catch (e) {
      print('❌ Fatal error in retry loop: $e');
      if (mounted) {
        setState(() {
          _isLoadingCashDeposit = false;
        });
      }
    }
  }

  Future<void> _loadRevenue() async {
    final supabaseService = SupabaseService();
    
    // Note: getRevenueData now takes selectedDate and calculates business day internally
    print('💰 Loading revenue for outlet: $_outletId');
    print('📅 Date: ${_selectedDate.toIso8601String()}');

    try {
      final data = await supabaseService.getRevenueData(
        outletId: _outletId,
        selectedDate: _selectedDate,
      );
      if (mounted) {
        setState(() {
          _revenueData = data;
          _isLoadingRevenue = false;
        });
      }
    } catch (e) {
      print('❌ Error loading revenue: $e');
      if (mounted) {
        setState(() {
          _isLoadingRevenue = false;
        });
      }
    }
  }

  void _loadLeaderboard() {
    final supabaseService = SupabaseService();

    print('🏆 _loadLeaderboard called');
    print('   Outlet ID: $_outletId');
    print('   Selected Date: ${_selectedDate.toIso8601String()}');

    // Fetch leaderboard from all outlets using business day
    setState(() {
      _isLoadingLeaderboard = true;
      _leaderboardFuture = supabaseService.getGlobalLeaderboard(
        outletId: _outletId,
        selectedDate: _selectedDate,
      ).then((data) {
        print('✅ Leaderboard data received: ${data.length} items');
        for (var item in data) {
          print('   - ${item['barista_name']}: Rp ${item['total_sales']}');
        }
        return data;
      }).catchError((error) {
        print('❌ Leaderboard error: $error');
        return <Map<String, dynamic>>[];
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshAnimationController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    print('🔄 Refreshing finance screen data...');
    
    // Prevent multiple simultaneous refreshes
    if (_isRefreshing) {
      _showErrorSnackBar('⏳ Refresh sedang berjalan, tunggu sebentar...');
      return;
    }
    
    setState(() {
      _isRefreshing = true;
    });
    
    // Start animation loop
    _refreshAnimationController.repeat();
    
    try {
      setState(() {
        _isLoadingRevenue = true;
        _isLoadingCashDeposit = true;
        _isLoadingLeaderboard = true;
      });
      
      await Future.wait([
        _loadRevenue(),
        _loadCashDeposit(),
      ]);
      
      _loadLeaderboard();
      
      _showSuccessSnackBar('✅ Data berhasil diperbarui');
    } catch (e) {
      print('❌ Error refreshing data: $e');
      _showErrorSnackBar('❌ Gagal memperbarui data: $e');
    } finally {
      // Stop animation
      _refreshAnimationController.stop();
      
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService();
    final currentUser = supabaseService.getCurrentUser();
    final isManager = currentUser?.role == 'manager' || currentUser?.role == 'admin';

    return Scaffold(
      appBar: PapikopiAppBar(
        onLogout: _handleLogout,
        onProfile: _handleProfile,
        onSettings: _handleSettings,
        onRefresh: _refreshData,
      ),
      body: Column(
        children: [
          // Date Picker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.background,
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _selectedDate = pickedDate;
                          _isLoadingRevenue = true;
                          _isLoadingCashDeposit = true;
                          _isLoadingLeaderboard = true;
                          _loadRevenue();
                          _loadCashDeposit();
                          _loadLeaderboard();
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime.now();
                      _isLoadingRevenue = true;
                      _isLoadingCashDeposit = true;
                      _isLoadingLeaderboard = true;
                      _loadRevenue();
                      _loadCashDeposit();
                      _loadLeaderboard();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text(
                    'Hari Ini',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          // Tab Bar
          Container(
            color: AppColors.background,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.trending_up),
                  text: 'Revenue',
                ),
                Tab(
                  icon: Icon(Icons.payment),
                  text: 'Setoran',
                ),
                Tab(
                  icon: Icon(Icons.calculate),
                  text: 'Calculator',
                ),
                Tab(
                  icon: Icon(Icons.star),
                  text: 'Top Rank',
                ),
              ],
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
            ),
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRevenueTab(),
                _buildCashDepositTab(),
                _buildBonusTab(),
                _buildLeaderboardTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ApprovalScreen(),
                  ),
                );
              },
              backgroundColor: Colors.blue,
              icon: const Icon(Icons.check_circle),
              label: const Text('Approval Serah Terima'),
            )
          : null,
    );
  }

  // ==================== REVENUE TAB ====================
  Widget _buildRevenueTab() {
    final dailyData = _revenueData?['daily'] ?? {'amount': 0.0, 'count': 0};
    final weeklyData = _revenueData?['weekly'] ?? {'amount': 0.0, 'count': 0};
    final monthlyData = _revenueData?['monthly'] ?? {'amount': 0.0, 'count': 0};

    // Get omset for bonus calculation
    final omset = (dailyData['amount'] as num?)?.toDouble() ?? 0.0;
    
    // Format date for display
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dateLabel = isToday ? 'Hari Ini' : DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingRevenue)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Info: Business Day Explanation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                border: Border.all(color: AppColors.accent, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hari Bisnis: 04:00 - 03:59 (penjualan 00:00-03:59 = hari kemarin)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.accent,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Daily Bonus Card
            DailyBonusCard(
              omset: omset,
              isLoading: _isLoadingRevenue,
              selectedDate: _selectedDate,
            ),
            const SizedBox(height: 16),

            // Daily Revenue Card
            _buildRevenueCard(
              title: 'Pendapatan - $dateLabel',
              amount: 'Rp ${formatRupiah(dailyData['amount'])}',
              subtitle: '${dailyData['count'] ?? 0} transaksi',
              icon: Icons.calendar_today,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),

            // Weekly Revenue Card
            _buildRevenueCard(
              title: 'Pendapatan Minggu Ini',
              amount: 'Rp ${formatRupiah(weeklyData['amount'])}',
              subtitle: '${weeklyData['count'] ?? 0} transaksi',
              icon: Icons.calendar_view_week,
              color: AppColors.accent,
            ),
            const SizedBox(height: 12),

            // Monthly Revenue Card
            _buildRevenueCard(
              title: 'Pendapatan Bulan Ini',
              amount: 'Rp ${formatRupiah(monthlyData['amount'])}',
              subtitle: '${monthlyData['count'] ?? 0} transaksi',
              icon: Icons.date_range,
              color: AppColors.primaryDark,
            ),
            const SizedBox(height: 24),

            // Revenue Breakdown Title
            const Text(
              'Rincian Pendapatan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Revenue Breakdown Items
            _buildBreakdownItem('Penjualan Produk', 'Rp ${formatRupiah(dailyData['amount'])}', '100%'),
            _buildBreakdownItem('Layanan Tambahan', 'Rp 0', '0%'),
            _buildBreakdownItem('Diskon & Promo', '-Rp 0', '0%'),
          ],
        ],
      ),
    );
  }

  Widget _buildRevenueCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(String label, String amount, String percentage) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.altSurface, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              percentage,
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== LEADERBOARD TAB ====================
  Widget _buildLeaderboardTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _leaderboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final leaderboard = snapshot.data ?? [];

        if (leaderboard.isEmpty) {
          return const Center(
            child: Text('Belum ada data leaderboard'),
          );
        }

        return ListView.builder(
          itemCount: leaderboard.length,
          itemBuilder: (context, index) {
            final item = leaderboard[index];
            final rank = index + 1;
            final isTop3 = rank <= 3;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isTop3
                    ? AppColors.accentLight.withOpacity(0.2)
                    : AppColors.surface,
                border: Border.all(
                  color: isTop3
                      ? AppColors.accent
                      : AppColors.altSurface,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Rank Badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isTop3 ? AppColors.accent : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '#$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Barista & Outlet Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['barista_name'] ?? 'Barista',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          item['outlet_name'] ?? 'Outlet',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item['transaction_count'] ?? 0} transaksi',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sales Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
'Rp ${formatRupiah(item['total_sales'])}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isTop3 ? AppColors.accent : AppColors.primary,
                        ),
                      ),
                      if (item['sales_percentage'] != null)
                        Text(
                          '${(item['sales_percentage'] as num).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==================== SETOR TUNAI TAB ====================
  Widget _buildCashDepositTab() {
    final cashData = _cashDepositData ?? {
      'cashAmount': 0.0,
      'cashCount': 0,
      'qrisAmount': 0.0,
      'qrisCount': 0,
    };
    
    final cashAmount = (cashData['cashAmount'] as num?)?.toDouble() ?? 0.0;
    final cashCount = (cashData['cashCount'] as int?) ?? 0;
    final qrisAmount = (cashData['qrisAmount'] as num?)?.toDouble() ?? 0.0;
    final qrisCount = (cashData['qrisCount'] as int?) ?? 0;
    final totalOmset = (cashData['totalOmset'] as num?)?.toDouble() ?? 0.0;
    final bonus = (cashData['bonus'] as num?)?.toDouble() ?? 0.0;
    final mealAllowance = (cashData['mealAllowance'] as num?)?.toDouble() ?? 0.0;
    final depositAmount = (cashData['depositAmount'] as num?)?.toDouble() ?? 0.0;
    final handoverStatus = (cashData['handoverStatus'] as String?) ?? 'pending';
    
    // Format date for display
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dateLabel = isToday ? 'Hari Ini' : DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate);
    
    // Get status display
    Color statusColor = Colors.grey;
    String statusText = 'PENDING';
    IconData statusIcon = Icons.schedule;
    
    if (handoverStatus == 'approved') {
      statusColor = Colors.green;
      statusText = 'SUDAH DIBAYAR';
      statusIcon = Icons.check_circle;
    } else if (handoverStatus == 'completed') {
      statusColor = Colors.blue;
      statusText = 'SELESAI';
      statusIcon = Icons.done_all;
    } else if (handoverStatus == 'rejected') {
      statusColor = Colors.red;
      statusText = 'DITOLAK';
      statusIcon = Icons.cancel;
    }
    
    if (_isLoadingCashDeposit) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Setoran Card + Kekurangan Upah Card
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accentDark, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Total Setoran - $dateLabel',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.3),
                              border: Border.all(color: Colors.white),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Rp ${formatRupiah(depositAmount)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'CASH: ${cashCount}tx | QRIS: ${qrisCount}tx',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (((cashData['kekuranganUpah'] as num?)?.toDouble() ?? 0) > 0)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.orange.shade50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Kekurangan yang\nHarus Diterima',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.3),
                                border: Border.all(color: Colors.orange),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.pending_actions, color: Colors.orange, size: 12),
                                  SizedBox(width: 3),
                                  Text(
                                    'PENDING',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Rp ${formatRupiah((cashData['kekuranganUpah'] as num?)?.toDouble() ?? 0)}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dari Manajemen Papi Kopi',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Payment Breakdown
          const Text(
            'Rincian Pembayaran Pelanggan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildDepositItem('Total Omset', 'Rp ${formatRupiah(totalOmset)}', 'Semua pembayaran'),
          _buildDepositItem('  ├─ Pembayaran CASH', 'Rp ${formatRupiah(cashAmount)}', '$cashCount transaksi'),
          _buildDepositItem('  └─ Pembayaran QRIS', 'Rp ${formatRupiah(qrisAmount)}', '$qrisCount transaksi'),
          
          const SizedBox(height: 24),
          
          // Detail Setoran
          const Text(
            'Rincian Setoran (CASH - Bonus - Uang Makan)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          _buildDepositItem('Pembayaran CASH', 'Rp ${formatRupiah(cashAmount)}', 'Uang tunai diterima'),
          _buildDepositItem('Bonus (Bertahap)', '-Rp ${formatRupiah(bonus)}', 'Untuk barista'),
          _buildDepositItem('Uang Makan', '-Rp ${formatRupiah(mealAllowance)}', 'Untuk barista'),
          if (((cashData['kekuranganUpah'] as num?)?.toDouble() ?? 0) > 0)
            _buildDepositItem(
              '⚠️ Kekurangan yang Harus Dibayar',
              'Rp ${formatRupiah((cashData['kekuranganUpah'] as num?)?.toDouble() ?? 0)}',
              'Dari Manajemen Papi Kopi',
            ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Disetor ke Papi Kopi',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Rp ${formatRupiah(depositAmount)}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Rumus:\nSetoran = CASH Diterima - Bonus Barista - Uang Makan\n\nPembayaran QRIS langsung masuk rekening toko.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade900,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Tanda Terima Button (for shortfall if exists)
          if (((cashData['kekuranganUpah'] as num?)?.toDouble() ?? 0) > 0)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (handoverStatus == 'pending' && !_isLoadingCashDeposit) ? () {
                  final kekuranganUpah = (_cashDepositData?['kekuranganUpah'] as num?)?.toDouble() ?? 0;
                  _showShortfallReceipt(kekuranganUpah);
                } : null,
                icon: const Icon(Icons.receipt),
                label: Text(
                  handoverStatus == 'pending'
                    ? '📋 Catat Tanda Terima Kekurangan Upah'
                    : '✅ Sudah Dicatat',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: handoverStatus == 'pending' ? Colors.orange : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          
          const SizedBox(height: 12),
          
          // Serah Terima Button
          if (depositAmount > 0)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (handoverStatus == 'pending' && !_isLoadingCashDeposit) ? () {
                  final kekuranganUpah = (_cashDepositData?['kekuranganUpah'] as num?)?.toDouble() ?? 0;
                  _submitSerahTerima(
                    totalOmset: totalOmset,
                    cashAmount: cashAmount,
                    qrisAmount: qrisAmount,
                    bonus: bonus,
                    mealAllowance: mealAllowance,
                    depositAmount: depositAmount,
                    kekuranganUpah: kekuranganUpah,
                  );
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: handoverStatus == 'pending' && !_isLoadingCashDeposit ? Colors.green : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  handoverStatus == 'pending' 
                    ? '📋 Serah Terima Setoran'
                    : '✅ ${statusText.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submitSerahTerima({
    required double totalOmset,
    required double cashAmount,
    required double qrisAmount,
    required double bonus,
    required double mealAllowance,
    required double depositAmount,
    required double kekuranganUpah,
  }) async {
    final supabaseService = SupabaseService();
    final currentUser = supabaseService.getCurrentUser();
    
    if (currentUser == null) {
      _showErrorSnackBar('User tidak valid');
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Serah Terima Setoran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Omset: Rp ${formatRupiah(totalOmset)}'),
            Text('Pembayaran CASH: Rp ${formatRupiah(cashAmount)}'),
            Text('Pembayaran QRIS: Rp ${formatRupiah(qrisAmount)}'),
            const SizedBox(height: 12),
            Text('Bonus Anda: Rp ${formatRupiah(bonus)}'),
            Text('Uang Makan: Rp ${formatRupiah(mealAllowance)}'),
            if (kekuranganUpah > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ Kekurangan Upah',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${formatRupiah(kekuranganUpah)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '(Toko akan memberikan kekurangan ini)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green),
              ),
              child: Text(
                'Total Disetor: Rp ${formatRupiah(depositAmount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                final success = await supabaseService.submitCashDepositHandover(
                  outletId: _outletId,
                  baristaId: currentUser.id,
                  totalOmset: totalOmset,
                  cashAmount: cashAmount,
                  qrisAmount: qrisAmount,
                  bonus: bonus,
                  mealAllowance: mealAllowance,
                  depositAmount: depositAmount,
                  kekuranganUpah: kekuranganUpah,
                  date: DateTime.now(),
                );
                
                if (mounted) {
                  Navigator.pop(context); // Close loading
                  
                  if (success) {
                    _showSuccessSnackBar('✅ Serah terima berhasil disubmit');
                    // Initial delay before first query
                    await Future.delayed(const Duration(milliseconds: 800));
                    // Reload data with retry to ensure status is updated
                    if (mounted) {
                      setState(() {
                        _isLoadingCashDeposit = true;
                      });
                      await _reloadCashDepositWithRetry(retries: 5);
                      // Final force rebuild to ensure UI updates
                      if (mounted) {
                        setState(() {});
                      }
                    }
                  } else {
                    _showErrorSnackBar('Gagal submit serah terima');
                  }
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Close loading
                  _showErrorSnackBar('Error: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Serah Terima'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showShortfallReceipt(double kekuranganUpah) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Catat Tanda Terima - Kekurangan Upah'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kekurangan Upah',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Rp ${formatRupiah(kekuranganUpah)}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manajemen Papi Kopi memberikan kompensasi kekurangan upah kepada karyawan',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Catatan (opsional)...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              // Create overlay entry for loading
              final overlayEntry = OverlayEntry(
                builder: (context) => Material(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
              
              if (mounted) {
                Overlay.of(context).insert(overlayEntry);
              }
              
              try {
                _showSuccessSnackBar('✅ Tanda terima kekurangan upah dicatat');
                
                // Initial delay before first query
                await Future.delayed(const Duration(milliseconds: 800));
                
                // Reload data with retry to ensure status is updated
                if (mounted) {
                  overlayEntry.remove();
                  
                  setState(() {
                    _isLoadingCashDeposit = true;
                  });
                  await _reloadCashDepositWithRetry(retries: 5);
                  
                  // Final force rebuild to ensure UI updates
                  if (mounted) {
                    setState(() {});
                  }
                }
              } catch (e) {
                print('❌ Error in _showShortfallReceipt: $e');
                if (mounted) {
                  overlayEntry.remove();
                  _showErrorSnackBar('Error: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Catat Tanda Terima'),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositItem(String label, String amount, String note) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.altSurface, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                note,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: amount.startsWith('-') ? Colors.red : AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BONUS TAB ====================
  Widget _buildBonusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🧮 Calculator Bonus',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hitung bonus penjualan berdasarkan metode berjenjang (progressive). Semakin besar omset, semakin banyak layer bonus yang didapat.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tier Structure Reference
          const Text(
            '📋 Struktur Tier Bonus',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _buildTierCard('Tier 1', '10%', '0 - 200rb'),
              _buildTierCard('Tier 2', '12%', '200rb - 350rb'),
              _buildTierCard('Tier 3', '15%', '350rb - 500rb'),
              _buildTierCard('Tier 4', '20%', '500rb+'),
            ],
          ),
          const SizedBox(height: 24),

          // Bonus Calculator Widget
          const BonusCalculatorWidget(showBreakdown: true),

          const SizedBox(height: 24),

          // Test Card untuk menunjukkan contoh bonus
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📌 Contoh Perhitungan Bonus',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Omset: Rp 450.000',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  '- Tier 1 (Rp 0-200rb × 10%) = Rp 20.000',
                  style: TextStyle(fontSize: 11),
                ),
                const Text(
                  '- Tier 2 (Rp 200-350rb × 12%) = Rp 18.000',
                  style: TextStyle(fontSize: 11),
                ),
                const Text(
                  '- Tier 3 (Rp 350-450rb × 15%) = Rp 15.000',
                  style: TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Total Bonus = Rp 53.000',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard(String tier, String percentage, String range) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tier,
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            percentage,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            range,
            style: TextStyle(
              fontSize: 11,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    // Implement logout
  }

  void _handleProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  void _handleSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }
}
