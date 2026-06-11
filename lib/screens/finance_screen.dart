import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../theme/thema.dart';
import '../widgets/header.dart';
import '../widgets/daily_bonus_card.dart';
import '../utils/bonus_calculator.dart';
import '../utils/holiday_detector.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'approval_screen.dart';
import 'bonus_calculator_screen.dart';

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
  late String _outletId = '';
  late String _baristaId = ''; // 🆕 Cache barista ID
  late int _businessDayStartHour = 4; // 🆕 Cache business day start hour

  @override
  void initState() {
    super.initState();
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
      try {
        final authProvider = context.read<AuthProvider>();
        if (authProvider.currentUser != null) {
          _outletId = authProvider.currentUser!.outletId;
          _baristaId = authProvider.currentUser!.id; // 🆕 Cache barista ID
          
          // Load business day start hour for this outlet
          _loadBusinessDayStartHour();
          
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
          _baristaId = '';
        }
      } catch (e) {
        // Error in PostFrameCallback
      }
    });
  }

  Future<void> _loadCashDeposit() async {
    final supabaseService = SupabaseService();
    
    try {
      print('DEBUG: Starting _loadCashDeposit, baristaId=$_baristaId');
      final data = await supabaseService.getCashDepositData(
        outletId: _outletId,
        baristaId: _baristaId,
        date: _selectedDate,
      );
      
      if (!mounted) {
        return;
      }
      
      setState(() {
        _cashDepositData = data;
        _isLoadingCashDeposit = false;
      });
      print('DEBUG: _loadCashDeposit completed');
      
    } catch (e) {
      print('DEBUG: Error in _loadCashDeposit: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingCashDeposit = false;
      });
    }
  }

  Future<void> _loadBusinessDayStartHour() async {
    try {
      final supabaseService = SupabaseService();
      // Query outlet business_day_start_hour directly
      final response = await supabaseService.client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', _outletId)
          .single();
      
      _businessDayStartHour = (response['business_day_start_hour'] as int?) ?? 4;
      print('DEBUG: Loaded businessDayStartHour=$_businessDayStartHour for outlet=$_outletId');
    } catch (e) {
      print('DEBUG: Error loading businessDayStartHour: $e');
      _businessDayStartHour = 4; // default
    }
  }

  // Helper method to reload and ensure UI updates
  Future<void> _reloadCashDepositWithRetry() async {
    try {
      print('DEBUG: Starting _reloadCashDepositWithRetry, baristaId=$_baristaId');
      if (_baristaId.isEmpty) {
        print('DEBUG: baristaId is empty, returning');
        if (mounted) {
          setState(() {
            _isLoadingCashDeposit = false;
          });
        }
        return;
      }
      
      // Wait a bit for database to process insert
      await Future.delayed(const Duration(milliseconds: 1500));
      print('DEBUG: Delay completed, now fetching data');
      
      final supabaseService = SupabaseService();
      
      // Add timeout to prevent infinite wait
      final data = await supabaseService.getCashDepositData(
        outletId: _outletId,
        baristaId: _baristaId,
        date: _selectedDate,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('DEBUG: getCashDepositData timeout!');
          return {
            'cashAmount': 0.0,
            'cashCount': 0,
            'qrisAmount': 0.0,
            'qrisCount': 0,
            'totalOmset': 0.0,
            'bonus': 0.0,
            'mealAllowance': 0.0,
            'depositAmount': 0.0,
            'handoverStatus': 'pending',
          };
        },
      );
      print('DEBUG: Data fetched, handoverStatus=${data['handoverStatus']}');
      
      if (mounted) {
        setState(() {
          _cashDepositData = data;
          _isLoadingCashDeposit = false;
        });
        print('DEBUG: setState completed, loading should be false now');
      } else {
        print('DEBUG: Not mounted, cannot setState');
      }
    } catch (e) {
      print('DEBUG: Error in _reloadCashDepositWithRetry: $e');
      if (mounted) {
        setState(() {
          _isLoadingCashDeposit = false;
        });
      }
    }
  }

  // Reload with a specific date (used after recording shortfall to query the correct business day)
  Future<void> _reloadCashDepositWithRetryForDate(DateTime dateToQuery) async {
    try {
      print('DEBUG: Starting _reloadCashDepositWithRetryForDate with dateToQuery=$dateToQuery, baristaId=$_baristaId');
      if (_baristaId.isEmpty) {
        print('DEBUG: baristaId is empty, returning');
        if (mounted) {
          setState(() {
            _isLoadingCashDeposit = false;
          });
        }
        return;
      }
      
      // Wait a bit for database to process insert
      await Future.delayed(const Duration(milliseconds: 1500));
      print('DEBUG: Delay completed, now fetching data with dateToQuery=$dateToQuery');
      
      final supabaseService = SupabaseService();
      
      // Add timeout to prevent infinite wait
      final data = await supabaseService.getCashDepositData(
        outletId: _outletId,
        baristaId: _baristaId,
        date: dateToQuery,  // Use the date we recorded for, not current _selectedDate
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('DEBUG: getCashDepositData timeout!');
          return {
            'cashAmount': 0.0,
            'cashCount': 0,
            'qrisAmount': 0.0,
            'qrisCount': 0,
            'totalOmset': 0.0,
            'bonus': 0.0,
            'mealAllowance': 0.0,
            'depositAmount': 0.0,
            'handoverStatus': 'pending',
          };
        },
      );
      print('DEBUG: Data fetched with dateToQuery=$dateToQuery, handoverStatus=${data['handoverStatus']}, shortfall_recorded=${data['shortfall_receipt_recorded']}');
      
      if (mounted) {
        setState(() {
          _cashDepositData = data;
          _isLoadingCashDeposit = false;
        });
        print('DEBUG: setState completed, loading should be false now');
      } else {
        print('DEBUG: Not mounted, cannot setState');
      }
    } catch (e) {
      print('DEBUG: Error in _reloadCashDepositWithRetryForDate: $e');
      if (mounted) {
        setState(() {
          _isLoadingCashDeposit = false;
        });
      }
    }
  }

  Future<void> _loadRevenue() async {
    final supabaseService = SupabaseService();
    
    try {
      final data = await supabaseService.getRevenueData(
        outletId: _outletId,
        selectedDate: _selectedDate,
      );
      
      // Check mounted BEFORE calling setState
      if (!mounted) {
        return;
      }
      
      setState(() {
        _revenueData = data;
        _isLoadingRevenue = false;
      });
      
    } catch (e) {
      if (!mounted) {
        return;
      }
      
      setState(() {
        _isLoadingRevenue = false;
      });
    }
  }

  void _loadLeaderboard() {
    final supabaseService = SupabaseService();

    // Fetch leaderboard from all outlets using business day
    // Assign future outside heavy setState to avoid race conditions
    setState(() {
      _isLoadingLeaderboard = true;
      // keep previous future until we assign the real one below
      _leaderboardFuture = Future.value(<Map<String, dynamic>>[]);
    });

    final future = supabaseService
        .getGlobalLeaderboard(
      outletId: _outletId,
      selectedDate: _selectedDate,
    )
        .then((data) {
      return data;
    }).catchError((error) {
      return <Map<String, dynamic>>[];
    }).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _isLoadingLeaderboard = false;
      });
    });

    // finally assign the future so FutureBuilder listens to it
    setState(() {
      _leaderboardFuture = future;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshAnimationController.dispose();
    super.dispose();
  }

  // Skeleton loaders for smooth loading experience
  Widget _buildRevenueTabSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info box skeleton
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 250,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Revenue cards skeleton
          ..._buildRevenueCardSkeletons(),
          const SizedBox(height: 16),
          // Bonus calculator skeleton
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.altSurface),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(3, (i) {
                return Padding(
                  padding: EdgeInsets.only(bottom: i < 2 ? 16 : 0),
                  child: Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRevenueCardSkeletons() {
    return [
      // Daily, Weekly, Monthly cards
      Row(
        children: [
          Expanded(
            child: _buildRevenueCardSkeleton('Daily'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildRevenueCardSkeleton('Weekly'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _buildRevenueCardSkeleton('Monthly'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.altSurface),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 20,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildRevenueCardSkeleton(String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.altSurface),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 12,
            width: 50,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 20,
            width: 100,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 10,
            width: 80,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashDepositTabSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top cards skeleton (Total & Kekurangan)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight.withOpacity(0.2),
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 18,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 18,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Deposit list skeleton
          ..._buildCashDepositCardSkeletons(4),
        ],
      ),
    );
  }

  List<Widget> _buildCashDepositCardSkeletons(int count) {
    return List.generate(
      count,
      (index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardTabSkeleton() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 10,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    height: 12,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshData() async {
    
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
                  icon: Icon(Icons.account_balance_wallet),
                  text: 'Penarikan',
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
              isScrollable: true,
              tabAlignment: TabAlignment.start,
            ),
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRevenueTab(),
                _buildCashDepositTab(),
                _buildWithdrawTab(),
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

    // Calculate business day range for the selected date
    final businessDayStartHour = 4;
    final businessDayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, businessDayStartHour);
    final businessDayEnd = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day + 1, businessDayStartHour);
    final endHour = (businessDayStartHour - 1 < 0 ? 23 : businessDayStartHour - 1).toString().padLeft(2, '0');
    final startHourPadded = businessDayStartHour.toString().padLeft(2, '0');
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final startMonth = monthNames[businessDayStart.month - 1];
    final endMonth = monthNames[businessDayEnd.month - 1];
    final businessDayDisplay = '${businessDayStart.day} $startMonth $startHourPadded:00 - ${businessDayEnd.day} $endMonth $endHour:59';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingRevenue)
            _buildRevenueTabSkeleton()
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hari Bisnis: $businessDayDisplay',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Penjualan sebelum 04:00 dihitung untuk hari sebelumnya',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.accent,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
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

            // Button: Lihat Calculator
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const BonusCalculatorScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.calculate),
                label: const Text('Lihat Calculator Bonus'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
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
          return _buildLeaderboardTabSkeleton();
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
      'gratisAmount': 0.0,
      'gratisCount': 0,
      'otherAmount': 0.0,
      'otherCount': 0,
    };
    
    final cashAmount = (cashData['cashAmount'] as num?)?.toDouble() ?? 0.0;
    final cashCount = (cashData['cashCount'] as int?) ?? 0;
    final qrisAmount = (cashData['qrisAmount'] as num?)?.toDouble() ?? 0.0;
    final qrisCount = (cashData['qrisCount'] as int?) ?? 0;
    final gratisAmount = (cashData['gratisAmount'] as num?)?.toDouble() ?? 0.0;
    final gratisCount = (cashData['gratisCount'] as int?) ?? 0;
    final otherAmount = (cashData['otherAmount'] as num?)?.toDouble() ?? 0.0;
    final otherCount = (cashData['otherCount'] as int?) ?? 0;
    final totalOmset = (cashData['totalOmset'] as num?)?.toDouble() ?? 0.0;
    final bonus = (cashData['bonus'] as num?)?.toDouble() ?? 0.0;
    final mealAllowance = (cashData['mealAllowance'] as num?)?.toDouble() ?? 0.0;
    final depositAmount = (cashData['depositAmount'] as num?)?.toDouble() ?? 0.0;
    final handoverStatus = (cashData['handoverStatus'] as String?) ?? 'pending';
    final shortfallReceiptRecorded = (cashData['shortfall_receipt_recorded'] as bool?) ?? false;
    
    // Format date for display
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dateLabel = isToday ? 'Hari Ini' : DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate);
    
    // Get status display
    Color statusColor = Colors.grey;
    String statusText = 'PENDING';
    IconData statusIcon = Icons.schedule;
    
    if (handoverStatus == 'verified' || handoverStatus == 'verified by barista') {
      statusColor = Colors.blue;
      statusText = 'SUDAH DIVERIFIKASI BARISTA';
      statusIcon = Icons.verified;
    } else if (handoverStatus == 'approved') {
      statusColor = Colors.green;
      statusText = 'SUDAH DISETUJUI MANAGER';
      statusIcon = Icons.check_circle;
    } else if (handoverStatus == 'completed') {
      statusColor = Colors.green;
      statusText = 'SELESAI';
      statusIcon = Icons.done_all;
    } else if (handoverStatus == 'rejected') {
      statusColor = Colors.red;
      statusText = 'DITOLAK';
      statusIcon = Icons.cancel;
    }
    
    if (_isLoadingCashDeposit) {
      return _buildCashDepositTabSkeleton();
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kekurangan Upah Card
          // Show if: has shortfall value OR recorded OR (both deposit and shortfall are 0)
          if (((cashData['kekuranganUpah'] as num?)?.toDouble() ?? 0) > 0 || shortfallReceiptRecorded || (depositAmount == 0 && ((cashData['kekuranganUpah'] as num?)?.toDouble() ?? 0) == 0))
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: shortfallReceiptRecorded ? Colors.green : Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: shortfallReceiptRecorded ? Colors.green.shade50 : Colors.orange.shade50,
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
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: shortfallReceiptRecorded ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                          border: Border.all(color: shortfallReceiptRecorded ? Colors.green : Colors.orange),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(shortfallReceiptRecorded ? Icons.check_circle : Icons.pending_actions, color: shortfallReceiptRecorded ? Colors.green : Colors.orange, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              shortfallReceiptRecorded ? 'SUDAH DICATAT' : 'MENUNGGU DICATAT',
                              style: TextStyle(
                                color: shortfallReceiptRecorded ? Colors.green : Colors.orange,
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
                    'Rp ${formatRupiah((cashData['kekuranganUpah'] as num?)?.toDouble() ?? 0)}',
                    style: TextStyle(
                      color: shortfallReceiptRecorded ? Colors.green : Colors.orange,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dari Manajemen Papi Kopi',
                    style: TextStyle(
                      color: shortfallReceiptRecorded ? Colors.green.shade700 : Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 20),
          
          // Total Setoran Card
          // Show if: has value OR both deposit and shortfall are 0
          if (depositAmount > 0 || (depositAmount == 0 && ((cashData['kekuranganUpah'] as num?)?.toDouble() ?? 0) == 0))
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
                          'CASH: ${cashCount}tx | QRIS: ${qrisCount}tx | GRATIS: ${gratisCount}tx',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
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
          _buildDepositItem('  ├─ Pembayaran QRIS', 'Rp ${formatRupiah(qrisAmount)}', '$qrisCount transaksi'),
          _buildDepositItem('  ├─ Pembayaran GRATIS', 'Rp ${formatRupiah(gratisAmount)}', '$gratisCount transaksi'),
          if (otherAmount > 0)
            _buildDepositItem('  └─ Pembayaran Lainnya', 'Rp ${formatRupiah(otherAmount)}', '$otherCount transaksi'),
          
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
                onPressed: (!shortfallReceiptRecorded && !_isLoadingCashDeposit) ? () {
                  final kekuranganUpah = (_cashDepositData?['kekuranganUpah'] as num?)?.toDouble() ?? 0;
                  final handoverDate = _cashDepositData?['handoverDate'] as String?; // Get actual handover date from DB
                  _showShortfallReceipt(kekuranganUpah, handoverDate);
                } : null,
                icon: const Icon(Icons.receipt),
                label: Text(
                  shortfallReceiptRecorded
                    ? '✅ Tanda Terima Sudah Dicatat'
                    : '📋 Catat Tanda Terima Kekurangan Upah',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: shortfallReceiptRecorded ? Colors.green : Colors.orange,
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
    // Get current user from AuthProvider instead of SupabaseService
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    
    if (currentUser == null) {
      _showErrorSnackBar('User tidak valid');
      return;
    }
    
    final supabaseService = SupabaseService();

    // 🆕 Status options based on role
    String selectedStatus = currentUser.role == 'manager' ? 'pending' : 'verified by barista';
    
    // Determine available status options based on role
    List<String> availableStatuses = currentUser.role == 'manager'
        ? ['pending', 'approved', 'rejected']
        : ['verified by barista']; // Barista can only set verified by barista

    // Show confirmation dialog with status selection
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) => AlertDialog(
          title: const Text('Konfirmasi Serah Terima Setoran'),
          content: SingleChildScrollView(
            child: Column(
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
                // 🆕 Status selection
                const SizedBox(height: 16),
                Text(
                  'Status Setoran',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: selectedStatus,
                    isExpanded: true,
                    underline: const SizedBox(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    items: availableStatuses.map((status) {
                      String label = '';
                      if (status == 'pending') {
                        label = '⏳ Pending (Menunggu Verifikasi)';
                      } else if (status == 'verified by barista') {
                        label = '✅ Verified by Barista';
                      } else if (status == 'approved') {
                        label = '👍 Approved (Disetujui Manager)';
                      } else if (status == 'rejected') {
                        label = '❌ Rejected (Ditolak)';
                      }
                      return DropdownMenuItem(
                        value: status,
                        child: Text(label, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        dialogSetState(() => selectedStatus = value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Save main screen context before closing dialog
                final mainScreenContext = context;
                
                Navigator.pop(dialogContext); // Close dialog first
                
                // Show loading overlay using OverlayEntry
                final overlayEntry = OverlayEntry(
                  builder: (overlayContext) => const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: Colors.black54,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                );
                
                // Track if overlay is still mounted
                bool overlayMounted = true;
                
                try {
                  Overlay.of(mainScreenContext).insert(overlayEntry);
                } catch (e) {
                  overlayMounted = false;
                  print('DEBUG: Could not insert overlay: $e');
                }
                
                try {
                  print('DEBUG: Starting submit cash deposit handover');
                  
                  // Calculate business day date to match database storage
                  DateTime submitDate = _selectedDate;
                  if (_businessDayStartHour < 12) {
                    // Morning start: business day is tomorrow
                    submitDate = _selectedDate.add(const Duration(days: 1));
                  }
                  print('DEBUG: Calculated submitDate=$submitDate for businessDayStartHour=$_businessDayStartHour');
                  
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
                    status: selectedStatus,
                    date: submitDate,
                  );
                  print('DEBUG: Submit completed, success=$success');
                  
                  // Remove loading overlay
                  if (overlayMounted) {
                    try {
                      overlayEntry.remove();
                      overlayMounted = false;
                    } catch (e) {
                      print('DEBUG: Error removing overlay: $e');
                    }
                  }
                  
                  // Only update screen state if still mounted
                  // Dialog is already closed, so only update main screen
                  if (!mounted) {
                    print('DEBUG: Screen not mounted, skipping state updates');
                    return;
                  }
                  
                  if (success) {
                    _showSuccessSnackBar('✅ Serah terima berhasil disubmit');
                    
                    // Only update screen state if still mounted
                    if (mounted) {
                      setState(() {
                        _isLoadingCashDeposit = true;
                      });
                    }
                    
                    // Reload data
                    await _reloadCashDepositWithRetry();
                    
                    // Final state update
                    if (mounted) {
                      setState(() {});
                    }
                  } else {
                    _showErrorSnackBar('Gagal submit serah terima');
                  }
                } catch (e) {
                  print('DEBUG: Error in submit: $e');
                  
                  // Remove loading overlay even on error
                  if (overlayMounted) {
                    try {
                      overlayEntry.remove();
                      overlayMounted = false;
                    } catch (e2) {
                      print('DEBUG: Error removing overlay on exception: $e2');
                    }
                  }
                  
                  if (mounted) {
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

  void _showShortfallReceipt(double kekuranganUpah, String? handoverDate) {
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
              final notes = noteController.text;
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
                // Parse handoverDate string to DateTime, or use selected date as fallback
                DateTime recordDate = _selectedDate;
                if (handoverDate != null && handoverDate.isNotEmpty) {
                  try {
                    recordDate = DateTime.parse(handoverDate);
                  } catch (e) {
                    print('DEBUG: Failed to parse handoverDate=$handoverDate, using _selectedDate=$_selectedDate');
                  }
                }
                
                // Record shortfall receipt to database using the actual handover date from DB
                final success = await SupabaseService().recordShortfallReceipt(
                  outletId: _outletId,
                  baristaId: _baristaId,
                  kekuranganUpah: kekuranganUpah,
                  notes: notes,
                  date: recordDate,
                );
                
                if (success) {
                  _showSuccessSnackBar('✅ Tanda terima kekurangan upah dicatat');
                  
                  // Initial delay before first query
                  await Future.delayed(const Duration(milliseconds: 800));
                  
                  // Reload data with retry using the same date we recorded for (important!)
                  if (mounted) {
                    overlayEntry.remove();
                    
                    setState(() {
                      _isLoadingCashDeposit = true;
                    });
                    // Pass recordDate so we reload with the correct business day date
                    await _reloadCashDepositWithRetryForDate(recordDate);
                    
                    // Final force rebuild to ensure UI updates
                    if (mounted) {
                      setState(() {});
                    }
                  }
                } else {
                  if (mounted) {
                    overlayEntry.remove();
                    _showErrorSnackBar('Gagal mencatat tanda terima kekurangan upah');
                  }
                }
              } catch (e) {
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
  Widget _buildWithdrawTab() {
    print('DEBUG _buildWithdrawTab - _outletId: $_outletId');
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService().getDailyReceipts(
        outletId: _outletId,
        limit: 30,
      ),
      builder: (context, snapshot) {
        print('DEBUG _buildWithdrawTab - snapshot state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Memuat data penerimaan...',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          print('DEBUG _buildWithdrawTab - Error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red.shade400,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Gagal memuat data',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        final dailyReceipts = snapshot.data ?? [];

        if (dailyReceipts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  color: Colors.grey.shade400,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum ada data penerimaan',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        // Calculate summaries from real data
        int approvedCount = 0;
        double approvedAmount = 0.0;
        int pendingCount = 0;
        double pendingAmount = 0.0;

        for (final daily in dailyReceipts) {
          final dateTime = daily['date'] as DateTime;
          final salesAmount = (daily['salesAmount'] as num).toDouble();
          final depositStatus = daily['depositStatus'] as String;
          
          // Calculate upah using proper bonus calculator
          final isHolidayDate = isHoliday(dateTime);
          final bonusData = calculateBonus(salesAmount, isHoliday: isHolidayDate);
          final totalBonus = bonusData.totalBonus;
          
          // Calculate meal allowance
          final mealAllowance = salesAmount >= 300000 ? 34000.0 : 25000.0;
          final totalWage = totalBonus + mealAllowance;

          if (depositStatus == 'approved' || depositStatus == 'Approved') {
            approvedCount++;
            approvedAmount += totalWage;
          } else if (depositStatus == 'pending' || depositStatus == 'Pending') {
            pendingCount++;
            pendingAmount += totalWage;
          }
        }

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
                    colors: [Colors.blue.shade600, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💰 Penarikan Upah Harian',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Daftar upah harian (bonus + uang makan) dengan status persetujuan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildWithdrawSummaryCard(
                      title: 'Approved',
                      count: approvedCount.toString(),
                      amount: 'Rp ${formatRupiah(approvedAmount)}',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildWithdrawSummaryCard(
                      title: 'Pending',
                      count: pendingCount.toString(),
                      amount: 'Rp ${formatRupiah(pendingAmount)}',
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Daftar Upah Harian
              const Text(
                '📋 Daftar Upah Harian',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // List Items from real data
              ...dailyReceipts.map((daily) {
                final dateTime = daily['date'] as DateTime;
                final salesAmount = (daily['salesAmount'] as num).toDouble();
                final depositStatus = (daily['depositStatus'] as String).toLowerCase();
                
                // Calculate upah using proper bonus calculator
                final isHolidayDate = isHoliday(dateTime);
                final bonusData = calculateBonus(salesAmount, isHoliday: isHolidayDate);
                final totalBonus = bonusData.totalBonus;
                
                // Calculate meal allowance
                final mealAllowance = salesAmount >= 300000 ? 34000.0 : 25000.0;
                final totalWage = totalBonus + mealAllowance;

                final statusColor =
                    depositStatus == 'approved' ? Colors.green : Colors.orange;
                final statusIcon = depositStatus == 'approved'
                    ? Icons.check_circle
                    : Icons.schedule;

                // Format business day range: e.g. "27 Apr 04:00 - 28 Apr 03:59"
                final businessDayStartHour = 4; // Default, should match outlet settings
                final startHour = businessDayStartHour.toString().padLeft(2, '0');
                final endHour = (businessDayStartHour - 1 < 0 
                    ? 23 
                    : businessDayStartHour - 1).toString().padLeft(2, '0');
                
                // When user selects a date (e.g., May 27), they want to see business day data for that date
                // Business day: from 04:00 on that date to 03:59 on the next date
                DateTime businessDayStart;
                DateTime businessDayEnd;
                
                businessDayStart = DateTime(dateTime.year, dateTime.month, dateTime.day, businessDayStartHour);
                businessDayEnd = DateTime(dateTime.year, dateTime.month, dateTime.day + 1, businessDayStartHour);
                
                final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
                final startMonth = monthNames[businessDayStart.month - 1];
                final endMonth = monthNames[businessDayEnd.month - 1];
                
                final dateDisplay = '${businessDayStart.day} $startMonth $startHour:00 - ${businessDayEnd.day} $endMonth $endHour:59';

                return _buildWithdrawListItem(
                  date: dateDisplay,
                  amount: 'Rp ${formatRupiah(totalWage)}',
                  status: depositStatus == 'approved' ? 'Approved' : 'Pending',
                  statusColor: statusColor,
                  statusIcon: statusIcon,
                  data: daily,
                );
              }).toList(),

              // Keterangan Status
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  border: Border.all(color: AppColors.primary, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📌 Keterangan Status',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Approved = Upah telah disetujui dan siap ditransfer',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Pending = Upah menunggu persetujuan pihak manajemen',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWithdrawSummaryCard({
    required String title,
    required String count,
    required String amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawListItem({
    required String date,
    required String amount,
    required String status,
    required Color statusColor,
    required IconData statusIcon,
    Map<String, dynamic>? data,
  }) {
    return GestureDetector(
      onTap: () {
        if (data != null) {
          _showWithdrawDetailBottomSheet(data);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hari Bisnis: $date',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    statusIcon,
                    color: statusColor,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawDetailBottomSheet(Map<String, dynamic> daily) {
    final dateTime = daily['date'] as DateTime;
    final salesAmount = (daily['salesAmount'] as num).toDouble();
    final depositStatus = daily['depositStatus'] as String;
    
    // Calculate upah components
    final isHolidayDate = isHoliday(dateTime);
    final bonusData = calculateBonus(salesAmount, isHoliday: isHolidayDate);
    final totalBonus = bonusData.totalBonus;
    final mealAllowance = salesAmount >= 300000 ? 34000.0 : 25000.0;
    final totalWage = totalBonus + mealAllowance;
    
    // Format date
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final monthName = monthNames[dateTime.month - 1];
    final dateDisplay = '${dateTime.day} $monthName ${dateTime.year}';
    
    final statusColor = depositStatus.toLowerCase() == 'approved' ? Colors.green : Colors.orange;
    final statusText = depositStatus.toLowerCase() == 'approved' ? 'Disetujui' : 'Menunggu Persetujuan';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Title & Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detail Upah Harian',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateDisplay,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        border: Border.all(color: statusColor),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Total Upah Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade500, Colors.green.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Upah',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rp ${formatRupiah(totalWage)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Breakdown
                const Text(
                  'Rincian Perhitungan Upah',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Omset
                _buildDetailItem(
                  'Omset Penjualan',
                  'Rp ${formatRupiah(salesAmount)}',
                  Icons.shopping_cart,
                ),
                const SizedBox(height: 8),
                
                // Holiday indicator
                if (isHolidayDate)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.celebration, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Hari Libur/Istimewa - Bonus x2',
                            style: TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 0),
                
                if (isHolidayDate) const SizedBox(height: 8),
                
                // Bonus
                _buildDetailItem(
                  'Bonus Penjualan',
                  'Rp ${formatRupiah(totalBonus)}',
                  Icons.trending_up,
                ),
                const SizedBox(height: 8),
                
                // Meal Allowance
                _buildDetailItem(
                  'Uang Makan',
                  'Rp ${formatRupiah(mealAllowance)}',
                  Icons.restaurant,
                ),
                const SizedBox(height: 16),
                
                // Total separator
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 12),
                
                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Upah',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rp ${formatRupiah(totalWage)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Rincian Setoran Section
                const Text(
                  'Rincian Setoran (CASH - Bonus - Uang Makan)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Assuming 100% CASH payment for now (would need actual data for breakdown)
                // For complete solution, would need payment method breakdown from daily data
                _buildDetailItem(
                  'Pembayaran CASH',
                  'Rp ${formatRupiah(salesAmount)}',
                  Icons.attach_money,
                ),
                const SizedBox(height: 8),
                
                _buildDetailItem(
                  'Bonus (Berkurang)',
                  '-Rp ${formatRupiah(totalBonus)}',
                  Icons.trending_down,
                ),
                const SizedBox(height: 8),
                
                _buildDetailItem(
                  'Uang Makan (Berkurang)',
                  '-Rp ${formatRupiah(mealAllowance)}',
                  Icons.dining,
                ),
                const SizedBox(height: 12),
                
                // Calculate deposit amount and shortfall
                Builder(
                  builder: (context) {
                    final depositAmount = salesAmount - totalBonus - mealAllowance;
                    final shortfall = depositAmount < 0 ? (depositAmount * -1) : 0.0;
                    
                    return Column(
                      children: [
                        if (shortfall > 0)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              border: Border.all(color: Colors.orange),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '⚠️ Kekurangan yang Harus Dibayar',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Dari Manajemen Papi Kopi',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Rp ${formatRupiah(shortfall)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        Container(
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
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                depositAmount > 0 
                                  ? 'Rp ${formatRupiah(depositAmount)}' 
                                  : 'Rp 0',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.grey.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }



  void _handleLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final auth = context.read<AuthProvider>();
              await auth.signOut();

              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
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
