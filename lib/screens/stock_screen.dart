import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../providers/product_provider.dart';
import '../theme/thema.dart';
import '../widgets/header.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

// Format currency helper
String formatCurrency(num value) {
  // Convert to integer and add thousand separator
  final intValue = value.toInt();
  return intValue.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.',
  );
}

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _refreshAnimationController;
  late Future<List<Map<String, dynamic>>> _stockFuture;
  late String _outletId;
  bool _isRefreshing = false;
  bool _showReceivedTransfers = false; // Toggle untuk Dikirim/Diterima

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Initialize refresh animation controller
    _refreshAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    // Get outlet ID from authenticated user
    final authService = AuthService();
    final user = authService.getSavedUser();
    _outletId = user?.outletId ?? '';
    
    if (_outletId.isEmpty) {
      // Fallback to default outlet if not logged in
      _outletId = '844a73e9-3673-4eaf-bd8e-2f661624f6b0';
    }
    
    _loadData();
  }

  void _loadData() {
    final supabaseService = SupabaseService();
    
    setState(() {
      _stockFuture = _getEnrichedProductStock(supabaseService);
    });
  }

  /// Get product stock enriched with product details (name, price)
  Future<List<Map<String, dynamic>>> _getEnrichedProductStock(
      SupabaseService supabaseService) async {
    try {
      // Get stock map from showcase_allocations
      final stockMap = await supabaseService.getProductStock(_outletId);
      
      if (stockMap.isEmpty) {
        print('⚠️ No stock data found for outlet: $_outletId');
        return [];
      }

      // Get sold quantity for today (business day)
      final soldMap = await supabaseService.getSoldQuantityToday(
        outletId: _outletId,
        selectedDate: DateTime.now(),
      );

      // Get returned quantity for today (business day)
      final returnedMap = await supabaseService.getReturnedQuantityToday(
        outletId: _outletId,
        selectedDate: DateTime.now(),
      );

      // Get transfer statistics for today (business day)
      final transferStats = await supabaseService.getProductTransferStats(
        outletId: _outletId,
        selectedDate: DateTime.now(),
      );

      // Get all products to enriched with product details
      final products = await supabaseService.getProducts();

      // Build enriched stock list with product details
      final enrichedStock = <Map<String, dynamic>>[];
      
      for (final product in products) {
        final quantity = stockMap[product.id] ?? 0;
        final sold = soldMap[product.id] ?? 0;
        final returned = returnedMap[product.id] ?? 0;
        final transfers = transferStats[product.id] ?? {'dikirim': 0, 'diterima': 0};
        
        // Calculate remaining stock (Sisa)
        // Formula: Stok - Terjual + Kembali - Dikirim + Diterima
        final dikirim = (transfers['dikirim'] ?? 0) as num;
        final diterima = (transfers['diterima'] ?? 0) as num;
        final sisa = quantity - sold + returned - dikirim.toInt() + diterima.toInt();
        
        // Only include products that have stock in this outlet or all products
        enrichedStock.add({
          'product_id': product.id,
          'product_name': product.name,
          'quantity': quantity,
          'price': product.price,
          'hpp': product.hpp,
          'sold': sold, // Sold quantity from sales_items today
          'unsold': sisa, // Remaining stock calculated
          'dikembalikan': returned, // Returned quantity from product_returns today
          'dikirim': dikirim, // Transferred out today
          'diterima': diterima, // Transferred in today
        });
      }

      print('✅ Enriched stock data with ${enrichedStock.length} products');
      print('   Quantities: $stockMap');
      print('   Sold today: $soldMap');
      print('   Returned today: $returnedMap');
      print('   Transfers: $transferStats');
      return enrichedStock;
    } catch (e) {
      print('❌ Error fetching enriched product stock: $e');
      rethrow;
    }
  }

  Future<void> _refreshData() async {
    print('🔄 Refreshing Stock screen data...');
    
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
    
    // Start animation loop
    _refreshAnimationController.repeat();
    
    try {
      _loadData();
      
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
  void dispose() {
    _tabController.dispose();
    _refreshAnimationController.dispose();
    super.dispose();
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PapikopiAppBar(
        onLogout: _handleLogout,
        onProfile: _handleProfile,
        onSettings: _handleSettings,
        onRefresh: _refreshData,
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: AppColors.background,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.inventory_2),
                  text: 'Stok Produk',
                ),
                Tab(
                  icon: Icon(Icons.send),
                  text: 'Pindah Stok',
                ),
                Tab(
                  icon: Icon(Icons.undo),
                  text: 'Pengembalian',
                ),
              ],
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStockTab(),
                _buildTransferTab(),
                _buildReturnTab(),
              ],
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

Widget _buildStockTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _stockFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        var stocks = snapshot.data ?? [];
        if (stocks.isEmpty) {
          return const Center(
            child: Text('Belum ada stok produk'),
          );
        }

        // Sort: products with stock > 0 first, then by stock descending
        stocks = [...stocks]..sort((a, b) {
          final stockA = a['quantity'] as int? ?? 0;
          final stockB = b['quantity'] as int? ?? 0;
          if (stockA > 0 && stockB <= 0) return -1;
          if (stockA <= 0 && stockB > 0) return 1;
          return stockB.compareTo(stockA);
        });

        // Calculate statistics
        final totalStock = stocks.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 0));
        final totalProducts = stocks.length;
        final totalSold = stocks.fold<int>(0, (sum, item) => sum + (item['sold'] as int? ?? 0));
        final lowStockCount = stocks.where((item) => (item['quantity'] as int? ?? 0) < 5 && (item['quantity'] as int? ?? 0) > 0).length;

        return Column(
          children: [
            // Statistics Header - 4 Cards Full Width
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.background,
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      label: 'Total Stok',
                      value: '$totalStock',
                      icon: Icons.inventory_2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      label: 'Terjual',
                      value: '$totalSold',
                      icon: Icons.shopping_cart,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      label: 'Produk',
                      value: '$totalProducts',
                      icon: Icons.coffee,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      label: 'Low Stock',
                      value: '$lowStockCount',
                      icon: Icons.warning_outlined,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            // Data Table with Header
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                          columnSpacing: 16,
                          horizontalMargin: 12,
                          headingRowColor: MaterialStateProperty.all(AppColors.background),
                          dataRowColor: MaterialStateProperty.all(AppColors.surface),
                          headingRowHeight: 50,
                          dataRowHeight: 56,
                          columns: [
                            DataColumn(
                              label: Text(
                                'Produk',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Harga',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text(
                                'Stok',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text(
                                'Terjual',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text(
                                'Kembali',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text(
                                'Transfer',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text(
                                'Sisa',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              numeric: true,
                            ),
                          ],
                          rows: stocks
                              .map((stock) {
                      final productName = stock['product_name'] as String? ?? 'Unknown';
                      final price = stock['price'] as num? ?? 0;
                      final quantity = stock['quantity'] as int? ?? 0;
                      final sold = stock['sold'] as int? ?? 0;
                      final unsold = stock['unsold'] as int? ?? 0;
                      final dikembalikan = stock['dikembalikan'] as int? ?? 0;
                      final dikirim = stock['dikirim'] as int? ?? 0;
                      final diterima = stock['diterima'] as int? ?? 0;
                      final isLowStock = quantity < 5;
                      final isOutOfStock = quantity <= 0;

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              productName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isOutOfStock
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DataCell(
                            Text(
                              formatCurrency(price),
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isLowStock
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : isOutOfStock
                                    ? Colors.grey[200]
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$quantity',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isOutOfStock
                                      ? AppColors.textSecondary
                                      : isLowStock
                                      ? Colors.red
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$sold',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$dikembalikan',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.send,
                                    size: 14,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$dikirim',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '|',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.call_received,
                                    size: 14,
                                    color: Colors.teal,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$diterima',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$unsold',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.altSurface),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

Widget _buildTransferTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getEnrichedProductStock(SupabaseService()),
      builder: (context, stockSnapshot) {
        if (stockSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final availableStock = stockSnapshot.data ?? [];

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _showReceivedTransfers 
              ? SupabaseService().getReceivedTransfers(_outletId)
              : SupabaseService().getProductTransfers(_outletId),
          builder: (context, transferSnapshot) {
            if (transferSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (transferSnapshot.hasError) {
              print('🔴 Transfer snapshot error: ${transferSnapshot.error}');
              return Center(
                child: Text('Error: ${transferSnapshot.error}'),
              );
            }

            final transfers = transferSnapshot.data ?? [];
            print('🟡 Transfer tab snapshot - outlet: $_outletId, transfers found: ${transfers.length}, mode: ${_showReceivedTransfers ? "Diterima" : "Dikirim"}');
            for (final transfer in transfers) {
              print('   └─ From: ${transfer['from_outlet_name']} → To: ${transfer['to_outlet_name']}');
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  // Toggle Dikirim / Diterima
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Dikirim'),
                                icon: Icon(Icons.arrow_upward),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Diterima'),
                                icon: Icon(Icons.arrow_downward),
                              ),
                            ],
                            selected: {_showReceivedTransfers},
                            multiSelectionEnabled: false,
                            onSelectionChanged: (value) {
                              setState(() {
                                _showReceivedTransfers = value.first;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  if (!_showReceivedTransfers)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton.icon(
                        onPressed: () => _showTransferDialog(context, availableStock),
                        icon: const Icon(Icons.add),
                        label: const Text('Pindah Stok Baru'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  if (transfers.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_showReceivedTransfers 
                            ? 'Belum ada transfer diterima'
                            : 'Belum ada pindah stok'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transfers.length,
                      itemBuilder: (context, index) {
                        final transfer = transfers[index];
                        return _buildTransferCard(context, transfer);
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTransferCard(BuildContext context, Map<String, dynamic> transfer) {
    final fromOutletName = transfer['from_outlet_name'] ?? 'Unknown';
    final toOutletName = transfer['to_outlet_name'] ?? 'Unknown';
    final productName = transfer['product_name'] ?? 'Unknown';
    final quantity = transfer['quantity'] ?? 0;
    final createdAt = transfer['created_at'];
    
    // Get stock info based on transfer direction
    final currentStockSending = transfer['current_stock_at_sending_outlet'] as int? ?? 0;
    final currentStockReceiving = transfer['current_stock_at_receiving_outlet'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.altSurface),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pindah: $quantity unit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Selesai',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Transfer info
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tanggal: ${createdAt != null ? createdAt.toString().split(' ')[0] : '-'}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dari: $fromOutletName',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ke: $toOutletName',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                // Stock info
                if (currentStockSending > 0)
                  _buildDetailRow(
                    label: 'Stok ${fromOutletName}:',
                    value: '$currentStockSending unit',
                    valueColor: Colors.orange,
                  ),
                if (currentStockReceiving > 0) ...[
                  const SizedBox(height: 4),
                  _buildDetailRow(
                    label: 'Stok ${toOutletName}:',
                    value: '$currentStockReceiving unit',
                    valueColor: Colors.green,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    Color valueColor = Colors.black,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

Widget _buildReturnTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getEnrichedProductStock(SupabaseService()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada stok',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final stocks = snapshot.data!;

        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Pengembalian Stok',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            // Tombol Buat Pengembalian
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showReturnDialog(context, stocks),
                  icon: const Icon(Icons.add),
                  label: const Text('Buat Pengembalian'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            // List return history
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: SupabaseService().getProductReturns(_outletId),
                builder: (context, returnSnapshot) {
                  if (returnSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!returnSnapshot.hasData || returnSnapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.undo, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada pengembalian',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  final returns = returnSnapshot.data!;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: returns.length,
                    itemBuilder: (context, index) {
                      final returnItem = returns[index];
                      final conditionStatus = returnItem['condition_status'] ?? 'pending';
                      final productName = returnItem['product_name'] ?? 'Unknown';
                      final returnReason = returnItem['return_reason'] ?? '-';
                      final returnDate = returnItem['return_date'];
                      final conditionNotes = returnItem['condition_notes'];
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Produk & Status
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          productName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: ${returnItem['id'] ?? '-'}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getReturnStatusColor(conditionStatus),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getReturnStatusLabel(conditionStatus),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Alasan Pengembalian
                              Text(
                                'Alasan: $returnReason',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (conditionNotes != null &&
                                  conditionNotes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Catatan: $conditionNotes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                'Tanggal: ${_formatDate(returnDate)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '-';
    }
  }

  Color _getReturnStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'sellable':
        return Colors.green;
      case 'damaged':
        return Colors.red;
      case 'partially_damaged':
        return Colors.orange;
      case 'pending':
        return Colors.orange;
      case 'checked':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getReturnStatusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'sellable':
        return 'Dapat Dijual';
      case 'damaged':
        return 'Rusak';
      case 'partially_damaged':
        return 'Rusak Sebagian';
      case 'pending':
        return 'Menunggu';
      case 'checked':
        return 'Diperiksa';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      default:
        return status ?? '-';
    }
  }

  void _showTransferDialog(BuildContext context, List<Map<String, dynamic>> availableStock) {
    String? selectedProductId;
    int transferQuantity = 1;
    String? targetOutletId;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Pindah Stok Produk'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pilih Produk
                  Text(
                    'Pilih Produk',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('-- Pilih Produk --'),
                    value: selectedProductId,
                    items: availableStock.map((stock) {
                      final productId = stock['product_id'] as String;
                      final productName = stock['product_name'] as String? ?? 'Unknown';
                      final quantity = stock['quantity'] as int? ?? 0;
                      return DropdownMenuItem(
                        value: productId,
                        child: Text('$productName (Stok: $quantity)'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedProductId = value;
                        transferQuantity = 1;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  if (selectedProductId != null) ...[
                    Text(
                      'Jumlah Dipindahkan',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: transferQuantity > 1
                              ? () => setState(() => transferQuantity--)
                              : null,
                        ),
                        Expanded(
                          child: TextField(
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            controller: TextEditingController(text: '$transferQuantity'),
                            onChanged: (value) {
                              setState(() {
                                transferQuantity = int.tryParse(value) ?? 1;
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(() => transferQuantity++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Stok tersedia: ${availableStock.firstWhere((s) => s['product_id'] == selectedProductId)['quantity'] ?? 0}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Text(
                      'Outlet Tujuan',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: SupabaseService().getOutlets(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 40,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text('Tidak ada outlet lain');
                        }
                        
                        final outletList = snapshot.data!
                            .where((outlet) => outlet['id'] != _outletId)
                            .toList();
                        
                        if (outletList.isEmpty) {
                          return const Text('Tidak ada outlet tujuan');
                        }
                        
                        return DropdownButton<String>(
                          isExpanded: true,
                          hint: const Text('-- Pilih Outlet Tujuan --'),
                          value: targetOutletId,
                          items: outletList.map((outlet) {
                            final outletId = outlet['id'] as String;
                            final outletName = outlet['name'] as String? ?? 'Unknown';
                            return DropdownMenuItem(
                              value: outletId,
                              child: Text(outletName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              targetOutletId = value;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: selectedProductId != null && 
                            transferQuantity > 0 &&
                            targetOutletId != null
                      ? () async {
                          final supabaseService = SupabaseService();
                          
                          final success = await supabaseService.createProductTransfer(
                            fromOutletId: _outletId,
                            toOutletId: targetOutletId!,
                            productId: selectedProductId!,
                            quantity: transferQuantity,
                          );

                          if (mounted) {
                            Navigator.pop(dialogContext);

                            if (success) {
                              // Get product name for display
                              final productName = availableStock
                                  .firstWhere((s) => s['product_id'] == selectedProductId)['product_name'] ?? 'Produk';

                              // Show success dialog
                              showDialog(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green, size: 28),
                                      SizedBox(width: 12),
                                      Text('Pindah Stok Berhasil'),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 16),
                                      Text(
                                        'Stok berhasil dipindahkan!',
                                        style: Theme.of(context).textTheme.bodyLarge,
                                      ),
                                      const SizedBox(height: 20),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Detail Pindah:',
                                              style: Theme.of(context).textTheme.labelLarge,
                                            ),
                                            const SizedBox(height: 12),
                                            _buildDetailRow(label: 'Produk', value: productName),
                                            const SizedBox(height: 8),
                                            _buildDetailRow(label: 'Jumlah', value: '$transferQuantity unit'),
                                            const SizedBox(height: 8),
                                            _buildDetailRow(label: 'Status', value: '✅ Selesai', valueColor: Colors.green),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(dialogContext);
                                        _loadData(); // Refresh data
                                      },
                                      icon: const Icon(Icons.done),
                                      label: const Text('Selesai'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              // Show error dialog
                              showDialog(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Row(
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red, size: 28),
                                      SizedBox(width: 12),
                                      Text('Pindah Stok Gagal'),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 16),
                                      Text(
                                        'Gagal memindahkan stok produk. Silakan coba lagi.',
                                        style: Theme.of(context).textTheme.bodyLarge,
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                                        ),
                                        child: const Text(
                                          'Kemungkinan penyebab:\n• Stok tidak cukup\n• Outlet tujuan tidak valid\n• Koneksi internet putus',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogContext),
                                      child: const Text('Tutup'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Pindahkan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReturnDialog(BuildContext context, List<Map<String, dynamic>> stocks) {
    String? selectedProductId;
    int returnQuantity = 1;
    String? selectedReason;
    final reasonsList = ['Outlet Tutup', 'Tidak Terjual', 'Expired/Kadaluarsa', 'Rusak', 'Lainnya'];
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Buat Pengembalian Stok'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pilih Produk
                  Text(
                    'Pilih Produk',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('-- Pilih Produk --'),
                    value: selectedProductId,
                    items: stocks.map((stock) {
                      final productId = stock['product_id'] as String;
                      final productName = stock['product_name'] as String? ?? 'Unknown';
                      final quantity = stock['quantity'] as int? ?? 0;
                      return DropdownMenuItem(
                        value: productId,
                        child: Text('$productName (Stok: $quantity)'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedProductId = value;
                        returnQuantity = 1;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  if (selectedProductId != null) ...[
                    // Input Jumlah
                    Text(
                      'Jumlah Dikembalikan',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: returnQuantity > 1
                              ? () => setState(() => returnQuantity--)
                              : null,
                        ),
                        Expanded(
                          child: TextField(
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            controller: TextEditingController(text: '$returnQuantity'),
                            onChanged: (value) {
                              setState(() {
                                returnQuantity = int.tryParse(value) ?? 1;
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(() => returnQuantity++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Pilih Alasan
                    Text(
                      'Alasan Pengembalian',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 10),
                    DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('-- Pilih Alasan --'),
                      value: selectedReason,
                      items: reasonsList.map((reason) {
                        return DropdownMenuItem(
                          value: reason,
                          child: Text(reason),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedReason = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Catatan
                    Text(
                      'Catatan (Opsional)',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        hintText: 'Tambahkan catatan jika diperlukan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    notesController.dispose();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: selectedProductId != null &&
                            returnQuantity > 0 &&
                            selectedReason != null
                      ? () async {
                          final supabaseService = SupabaseService();
                          
                          // Save product return to database
                          final success = await supabaseService.createProductReturn(
                            outletId: _outletId,
                            productId: selectedProductId!,
                            quantity: returnQuantity,
                            returnReason: selectedReason!,
                            conditionNotes: notesController.text.isNotEmpty ? notesController.text : null,
                          );

                          if (mounted) {
                            Navigator.pop(dialogContext);
                            notesController.dispose();

                            if (success) {
                              // 🔧 FIX #7: Refresh product stock and cart after return
                              print('🔄 Refreshing product stock and cart after return...');
                              try {
                                final productProvider = context.read<ProductProvider>();
                                await productProvider.loadProductsWithStock(_outletId);
                                print('✅ Product stock refreshed');
                              } catch (e) {
                                print('⚠️ Warning: Could not refresh product stock: $e');
                              }
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Pengembalian berhasil dibuat'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              _loadData(); // Refresh data
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('❌ Gagal membuat pengembalian'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Buat Pengembalian'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
