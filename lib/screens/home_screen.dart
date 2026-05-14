import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/header.dart';
import '../theme/thema.dart';
import '../widgets/animated_card.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'private_messages_screen.dart';
import 'pos_screen.dart';
import 'stock_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _isRefreshing = false;
  Map<String, dynamic>? _salesData;
  Map<String, dynamic>? _yesterdaySalesData;
  late TabController _tabController;
  List<Map<String, dynamic>> _announcements = [];
  String _outletStatus = 'active'; // active, libur, closed, maintenance
  List<Map<String, dynamic>> _lowStockProducts = [];
  List<Map<String, dynamic>> _recentTransactions = [];
  int _businessDayStartHour = 4; // Default 4 AM WIB

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHomeData();
    _loadOutletStatus();
    _loadLowStockProducts();
    _loadYesterdaySalesData();
    _loadRecentTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    try {
      final supabaseService = SupabaseService();
      final auth = context.read<AuthProvider>();
      
      if (auth.currentUser != null) {
        final outletId = auth.currentUser!.outletId;
        final userId = auth.currentUser!.id;
        
        print('🔍 Loading home data - User ID: $userId, Outlet: $outletId');
        
        // Get sales data for today, week, and month using business day
        final today = DateTime.now();
        
        // Fetch sales data using business day
        final revenueData = await supabaseService.getRevenueData(
          outletId: outletId,
          selectedDate: today,
        );
        
        // Fetch announcements, private messages, group chats
        List<Map<String, dynamic>>? announcements;
        List<Map<String, dynamic>>? privateMessages;
        List<Map<String, dynamic>>? groupChats;
        
        try {
          announcements = await supabaseService.getAnnouncements();
          print('✅ Announcements loaded: ${announcements.length} items');
          for (var ann in announcements) {
            print('   - Title: ${ann['title']}, Description: ${ann['description']}');
          }
        } catch (e) {
          print('⚠️ Announcements not available: $e');
          announcements = [];
        }
        
        try {
          privateMessages = await supabaseService.getPrivateMessagesWithSenderInfo(userId: userId);
          print('✅ Private messages loaded: ${privateMessages.length} items');
          for (var msg in privateMessages) {
            print('   - From ${msg['sender_id']} to ${msg['receiver_id']}: ${msg['message']}');
          }
        } catch (e) {
          print('⚠️ Private messages not available: $e');
          privateMessages = [];
        }
        
        try {
          groupChats = await supabaseService.getGroupChats();
          print('✅ Group chats loaded: ${groupChats.length} items');
        } catch (e) {
          print('⚠️ Group chats not available: $e');
          groupChats = [];
        }
        
        if (mounted) {
          setState(() {
            _salesData = revenueData;
            _announcements = announcements ?? [];
          });
        }
      }
    } catch (e) {
      print('❌ Error loading home data: $e');
    }
  }

  Future<void> _loadOutletStatus() async {
    try {
      final supabaseService = SupabaseService();
      final auth = context.read<AuthProvider>();
      
      if (auth.currentUser != null) {
        final outletId = auth.currentUser!.outletId;
        final status = await supabaseService.getOutletStatus(outletId: outletId);
        final businessDayStartHour = await supabaseService.getBusinessDayStartHour(outletId: outletId);
        
        if (mounted) {
          setState(() {
            _outletStatus = status;
            _businessDayStartHour = businessDayStartHour;
          });
        }
      }
    } catch (e) {
      print('⚠️ Error loading outlet status: $e');
    }
  }

  Future<void> _loadLowStockProducts() async {
    try {
      final supabaseService = SupabaseService();
      final auth = context.read<AuthProvider>();
      
      if (auth.currentUser != null) {
        final outletId = auth.currentUser!.outletId;
        
        // Fetch ingredients with stock <= 10 units
        final response = await supabaseService.client
            .from('outlet_stock')
            .select('ingredient_id, quantity')
            .eq('outlet_id', outletId)
            .lte('quantity', 10)
            .order('quantity', ascending: true);
        
        if (response.isNotEmpty) {
          // Fetch ingredient details
          final ingredientIds = List<String>.from(
            response.map((item) => item['ingredient_id']).toList(),
          );
          
          final ingredients = await supabaseService.client
              .from('ingredients')
              .select('id, name')
              .inFilter('id', ingredientIds);
          
          // Merge stock data with ingredient details
          final merged = response.map((stockItem) {
            final ingredient = ingredients.firstWhere(
              (p) => p['id'] == stockItem['ingredient_id'],
              orElse: () => {},
            );
            return {
              ...stockItem,
              'ingredient_name': ingredient['name'] ?? 'Unknown',
            };
          }).toList();
          
          if (mounted) {
            setState(() {
              _lowStockProducts = merged;
            });
          }
        }
      }
    } catch (e) {
      print('⚠️ Error loading low stock products: $e');
    }
  }

  Future<void> _loadYesterdaySalesData() async {
    try {
      final supabaseService = SupabaseService();
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser == null) return;

      final outletId = auth.currentUser!.outletId;

      final yesterdayData =
          await supabaseService.getYesterdaySalesData(
        outletId: outletId,
      );

      if (mounted) {
        setState(() {
          _yesterdaySalesData = yesterdayData;
        });
      }
    } catch (e) {
      print('⚠️ Error loading yesterday sales data: $e');
    }
  }

  Future<void> _loadRecentTransactions() async {
    try {
      final supabaseService = SupabaseService();
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser == null) return;

      final outletId = auth.currentUser!.outletId;

      final transactions =
          await supabaseService.getRecentTransactions(
        outletId: outletId,
        limit: 5,
      );

      if (mounted) {
        setState(() {
          _recentTransactions = transactions;
        });
      }
    } catch (e) {
      print('⚠️ Error loading recent transactions: $e');
    }
  }

  double _calculatePercentageChange(double today, double yesterday) {
    if (yesterday == 0) return today > 0 ? 100 : 0;
    return ((today - yesterday) / yesterday) * 100;
  }

  String _formatCurrency(double amount) {
    return 'Rp${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
        )}';
  }

  /// Format transaction time considering business day (default 4 AM)
  /// Converts from UTC to Jakarta timezone (WIB = UTC+7)
  /// Shows time in HH:MM format
  String _formatTransactionTime(DateTime timestamp) {
    // Convert UTC to Jakarta timezone (WIB = UTC+7)
    final jakartaTime = timestamp.add(const Duration(hours: 7));
    return '${jakartaTime.hour.toString().padLeft(2, '0')}:${jakartaTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatCompactCurrency(double amount) {
    if (amount >= 1000000) {
      return 'Rp${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return 'Rp${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return 'Rp${amount.toInt()}';
    }
  }

  Future<void> _refreshData() async {
    print('🔄 Refreshing Home screen data...');
    
    // Prevent multiple simultaneous refreshes
    if (_isRefreshing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ Refresh sedang berjalan, tunggu sebentar...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      await _loadHomeData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data berhasil diperbarui'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error refreshing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal memperbarui data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PapikopiAppBar(
        onProfile: _handleProfile,
        onSettings: _handleSettings,
        onLogout: _handleLogout,
        onMessages: _handleMessages,
        onRefresh: _refreshData,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Section - With margins
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildGreetingSection(),
            ),
            const SizedBox(height: 16),
            // Outlet Status Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildOutletStatusButton(),
            ),
            const SizedBox(height: 16),
            // Quick Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildQuickActionButtons(),
            ),
            const SizedBox(height: 16),
            // Low Stock Alerts
            if (_lowStockProducts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildLowStockAlerts(),
              ),
            const SizedBox(height: 24),
            // Pengumuman Section (Above tabs)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pengumuman (${_announcements.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (_announcements.isEmpty)
                    Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.altSurface),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: Row(
                            children: [
                              Icon(Icons.info, color: AppColors.textSecondary),
                              const SizedBox(width: 12),
                              Text(
                                'Belum ada pengumuman',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.altSurface),
                      ),
                      child: Column(
                        children: _announcements.take(3).toList().asMap().entries.map((entry) {
                          final index = entry.key;
                          final announcement = entry.value;
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      announcement['title'] ?? 'Pengumuman',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      announcement['description'] ?? '',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          _showAnnouncementDetail(announcement);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.accent,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          'Lihat Detail',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (index < (_announcements.take(3).length - 1))
                                Divider(color: AppColors.altSurface, height: 0, indent: 0),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Tabs for Sales & Transactions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.altSurface),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: UnderlineTabIndicator(
                        borderSide: BorderSide(
                          color: AppColors.accent,
                          width: 3,
                        ),
                      ),
                      labelColor: AppColors.accent,
                      unselectedLabelColor: AppColors.textSecondary,
                      tabs: const [
                        Tab(
                          child: Text(
                            'Ringkasan Penjualan',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Tab(
                          child: Text(
                            'Transaksi Terakhir',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tab Views
                  if (_salesData != null)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Tab 1: Ringkasan Penjualan
                          _buildSalesSummaryTab(),
                          // Tab 2: Transaksi Terakhir
                          _buildRecentTransactionsTab(),
                        ],
                      ),
                    )
                  else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
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

  // ==================== SALES SUMMARY TAB ====================
  Widget _buildSalesSummaryTab() {
    final dailyData = _salesData?['daily'] ?? {'amount': 0.0, 'count': 0};
    final weeklyData = _salesData?['weekly'] ?? {'amount': 0.0, 'count': 0};
    final monthlyData = _salesData?['monthly'] ?? {'amount': 0.0, 'count': 0};
    
    final todaySales = (dailyData['amount'] as num?)?.toDouble() ?? 0.0;
    final weekSales = (weeklyData['amount'] as num?)?.toDouble() ?? 0.0;
    final monthSales = (monthlyData['amount'] as num?)?.toDouble() ?? 0.0;
    final totalTransactions = (dailyData['count'] as num?)?.toInt() ?? 0;

    final yesterdaySales = (_yesterdaySalesData?['amount'] as num?)?.toDouble() ?? 0.0;
    final dailyChangePercent = _calculatePercentageChange(todaySales, yesterdaySales);

    return SingleChildScrollView(
      child: Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.altSurface),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hari Ini with percentage change
              Row(
                children: [
                  Expanded(
                    child: _buildSalesRow(
                      title: 'Penjualan Hari Ini',
                      amount: todaySales.toInt(),
                      icon: Icons.trending_up,
                      color: AppColors.accent,
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: dailyChangePercent >= 0
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          dailyChangePercent >= 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color:
                              dailyChangePercent >= 0 ? Colors.green : Colors.red,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${dailyChangePercent.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: dailyChangePercent >= 0
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Divider(color: AppColors.altSurface, height: 16),
              _buildSalesRow(
                title: 'Penjualan Minggu Ini',
                amount: weekSales.toInt(),
                icon: Icons.calendar_today,
                color: AppColors.primary,
              ),
              Divider(color: AppColors.altSurface, height: 16),
              _buildSalesRow(
                title: 'Penjualan Bulan Ini',
                amount: monthSales.toInt(),
                icon: Icons.date_range,
                color: AppColors.primaryLight,
              ),
              Divider(color: AppColors.altSurface, height: 16),
              _buildSalesRow(
                title: 'Total Transaksi Hari Ini',
                amount: totalTransactions,
                isTransaction: true,
                icon: Icons.receipt,
                color: Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== RECENT TRANSACTIONS TAB ====================
  Widget _buildRecentTransactionsTab() {
    if (_recentTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              'Belum ada transaksi',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Jam Bisnis: ${_businessDayStartHour.toString().padLeft(2, '0')}:00 - ${(_businessDayStartHour - 1).toString().padLeft(2, '0')}:59 (WIB)',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.altSurface),
          ),
          child: Column(
        children: _recentTransactions.asMap().entries.map((entry) {
          final index = entry.key;
          final transaction = entry.value;
          final amount = (transaction['total_amount'] as num?)?.toInt() ?? 0;
          final method = transaction['payment_method'] ?? 'Unknown';
          final createdAt = transaction['created_at'] != null
              ? DateTime.parse(transaction['created_at'].toString())
              : null;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.shopping_cart,
                        color: Colors.blue,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaksi #${index + 1}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            createdAt != null
                                ? _formatTransactionTime(createdAt)
                                : 'Unknown time',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(amount.toDouble()),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          method,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (index < _recentTransactions.length - 1)
                Divider(
                  color: AppColors.altSurface,
                  height: 0,
                  indent: 52,
                ),
            ],
          );
        }).toList(),
      ),
        ),
      ],
    );
  }

  // ==================== MESSAGING SECTION ====================
  // ==================== GREETING ====================
  Widget _buildGreetingSection() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final name = auth.currentUser?.name ?? 'Barista';
        final hour = DateTime.now().hour;
        final greeting = hour < 12
            ? '🌅 Pagi'
            : hour < 17
                ? '☀️ Siang'
                : '🌙 Malam';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selamat datang, $name! 👋',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now()),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOutletStatusButton() {
    const statusOptions = ['active', 'libur', 'closed', 'maintenance'];
    const statusLabels = {
      'active': 'Buka',
      'libur': 'Libur',
      'closed': 'Tutup',
      'maintenance': 'Maintenance',
    };
    const statusColors = {
      'active': Color(0xFF4CAF50),
      'libur': Color(0xFFFFC107),
      'closed': Color(0xFFF44336),
      'maintenance': Color(0xFF2196F3),
    };

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.altSurface),
        borderRadius: BorderRadius.circular(8),
      ),
      child: PopupMenuButton<String>(
        onSelected: (String value) async {
          setState(() {
            _outletStatus = value;
          });
          
          // Save to database
          try {
            final auth = context.read<AuthProvider>();
            if (auth.currentUser != null) {
              final supabaseService = SupabaseService();
              final success = await supabaseService.updateOutletStatus(
                outletId: auth.currentUser!.outletId,
                status: value,
                userId: auth.currentUser!.id,
              );
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Status outlet berhasil diubah menjadi: ${statusLabels[value]}'),
                    backgroundColor: statusColors[value],
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          } catch (e) {
            print('❌ Error saving outlet status: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gagal menyimpan status outlet'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        itemBuilder: (BuildContext context) =>
            statusOptions
                .map((String choice) => PopupMenuItem<String>(
                      value: choice,
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColors[choice],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(statusLabels[choice] ?? choice),
                        ],
                      ),
                    ))
                .toList(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Status Outlet: ', style: TextStyle(fontSize: 14)),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColors[_outletStatus],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusLabels[_outletStatus] ?? _outletStatus,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesRow({
    required String title,
    required dynamic amount,
    required IconData icon,
    required Color color,
    bool isTransaction = false,
  }) {
    String displayAmount;
    if (isTransaction) {
      displayAmount = '$amount transaksi';
    } else {
      displayAmount = _formatCompactCurrency((amount as int).toDouble());
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                displayAmount,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  void _handleMessages() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const PrivateMessagesScreen()),
    );
  }

  void _handleSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
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

  // ==================== QUICK ACTION BUTTONS ====================
  Widget _buildQuickActionButtons() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        _buildQuickActionButton(
          icon: Icons.shopping_cart,
          label: 'Pemesanan',
          color: AppColors.accent,
          onTap: () {
            Navigator.push(
              context,
              SlidePageTransition(page: const POSScreen()),
            );
          },
        ),
        _buildQuickActionButton(
          icon: Icons.inventory_2,
          label: 'Stok',
          color: AppColors.primary,
          onTap: () {
            Navigator.push(
              context,
              SlidePageTransition(page: const StockScreen()),
            );
          },
        ),
        _buildQuickActionButton(
          icon: Icons.people,
          label: 'Profil',
          color: Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              SlidePageTransition(page: const ProfileScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: color.withOpacity(0.4),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
            color: color.withOpacity(0.12),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.2),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== LOW STOCK ALERTS ====================
  Widget _buildLowStockAlerts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              'Stok Menipis',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _lowStockProducts.length,
          itemBuilder: (context, index) {
            final product = _lowStockProducts[index];
            final quantity = product['quantity'] as int? ?? 0;
            final isVeryLow = quantity <= 5;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isVeryLow ? Colors.red.withOpacity(0.5) : Colors.orange.withOpacity(0.5),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isVeryLow 
                    ? Colors.red.withOpacity(0.05)
                    : Colors.orange.withOpacity(0.05),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isVeryLow ? Colors.red : Colors.orange,
                      ),
                      child: Center(
                        child: Text(
                          quantity.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
                            product['ingredient_name'] ?? 'Bahan',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isVeryLow ? '⚠️ Stok SANGAT RENDAH!' : '⚡ Stok rendah',
                            style: TextStyle(
                              fontSize: 11,
                              color: isVeryLow ? Colors.red : Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_forward, 
                        color: isVeryLow ? Colors.red : Colors.orange,
                        size: 20,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          SlidePageTransition(page: const StockScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Show announcement detail in a dialog
  void _showAnnouncementDetail(Map<String, dynamic> announcement) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with close button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            announcement['title'] ?? 'Pengumuman',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: AppColors.altSurface, height: 0),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          announcement['description'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                        if (announcement['created_at'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              'Tanggal: ${_formatAnnouncementDate(announcement['created_at'])}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Format announcement date
  String _formatAnnouncementDate(dynamic dateStr) {
    try {
      final date = DateTime.parse(dateStr.toString());
      // Convert UTC to Jakarta timezone
      final jakartaTime = date.add(const Duration(hours: 7));
      return '${jakartaTime.day}/${jakartaTime.month}/${jakartaTime.year} ${jakartaTime.hour.toString().padLeft(2, '0')}:${jakartaTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Tanggal tidak diketahui';
    }
  }
}
