import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../theme/thema.dart';
import '../widgets/header.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late String _outletId;
  late String _outletName;
  final SupabaseService _supabaseService = SupabaseService();
  final AuthService _authService = AuthService();

  // State for Stock Tab
  List<Map<String, dynamic>> _stocks = [];
  bool _loadingStocks = true;

  // State for Allocation Tab
  List<Map<String, dynamic>> _showcaseProducts = [];
  List<Map<String, dynamic>> _outlets = [];
  bool _loadingAllocation = true;
  String? _selectedProductId;
  String? _selectedOutletId;
  int _allocationQuantity = 1;

  // State for Return Tab
  List<Map<String, dynamic>> _pendingReturns = [];
  bool _loadingReturns = true;
  Map<String, int> _returnQuantities = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeManager();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeManager() async {
    try {
      final user = _authService.getSavedUser();
      if (user == null) return;

      setState(() {
        _outletId = user.outletId;
        _outletName = user.outlet?.name ?? 'Outlet';
      });

      await Future.wait([
        _loadStocks(),
        _loadAllocationData(),
        _loadReturns(),
      ]);
    } catch (e) {
      print('❌ Error initializing manager: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  // ==================== STOCK TAB ====================
  Future<void> _loadStocks() async {
    try {
      setState(() => _loadingStocks = true);

      // Get all ingredients with current stock levels
      final ingredients = await _supabaseService.getIngredients();
      
      // Get outlet stock for this outlet
      final outletStocks = await _supabaseService.getOutletStock(_outletId);
      
      // Map ingredients with their stock
      final stocks = <Map<String, dynamic>>[];
      for (final ingredient in ingredients) {
        final stock = outletStocks.firstWhere(
          (s) => s['ingredient_id'] == ingredient.id,
          orElse: () => {},
        );
        
        stocks.add({
          'id': ingredient.id,
          'name': ingredient.name,
          'unit': ingredient.unit,
          'cost': ingredient.cost,
          'quantity': (stock['quantity'] ?? 0) as int,
          'low_stock_threshold': 10, // Default threshold
        });
      }

      setState(() {
        _stocks = stocks;
        _loadingStocks = false;
      });
    } catch (e) {
      print('❌ Error loading stocks: $e');
      setState(() => _loadingStocks = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stocks: $e')),
        );
      }
    }
  }

  // ==================== ALLOCATION TAB ====================
  Future<void> _loadAllocationData() async {
    try {
      setState(() => _loadingAllocation = true);

      // Get showcase products
      final products = await _supabaseService.getProducts();
      
      // Get all outlets except current
      final allOutlets = await _supabaseService.getOutlets();
      final otherOutlets = allOutlets
          .where((o) => o.id != _outletId)
          .toList();

      setState(() {
        _showcaseProducts = products
            .map((p) => {
              'id': p.id,
              'name': p.name,
              'price': p.price,
              'hpp': p.hpp,
            })
            .toList();
        _outlets = otherOutlets
            .map((o) => {
              'id': o.id,
              'name': o.name,
            })
            .toList();
        _loadingAllocation = false;
      });
    } catch (e) {
      print('❌ Error loading allocation data: $e');
      setState(() => _loadingAllocation = false);
    }
  }

  Future<void> _allocateProduct() async {
    if (_selectedProductId == null || _selectedOutletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih produk dan outlet terlebih dahulu')),
      );
      return;
    }

    try {
      final user = _authService.getSavedUser();
      
      // Create allocation record
      await _supabaseService.allocateProductToOutlet(
        productId: _selectedProductId!,
        fromOutletId: _outletId,
        toOutletId: _selectedOutletId!,
        quantity: _allocationQuantity,
        allocatedBy: user?.id ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Alokasi berhasil: $_allocationQuantity produk dikirim'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reset form
        setState(() {
          _selectedProductId = null;
          _selectedOutletId = null;
          _allocationQuantity = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  // ==================== RETURN TAB ====================
  Future<void> _loadReturns() async {
    try {
      setState(() => _loadingReturns = true);

      // Get pending returns for this outlet
      final returns = await _supabaseService.getPendingReturns(_outletId);

      setState(() {
        _pendingReturns = returns;
        // Initialize return quantities
        for (var ret in returns) {
          _returnQuantities[ret['id']] = 0;
        }
        _loadingReturns = false;
      });
    } catch (e) {
      print('❌ Error loading returns: $e');
      setState(() => _loadingReturns = false);
    }
  }

  Future<void> _processReturn(Map<String, dynamic> returnRecord) async {
    final returnId = returnRecord['id'];
    final returnQty = _returnQuantities[returnId] ?? 0;

    if (returnQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan jumlah produk yang dikembalikan')),
      );
      return;
    }

    try {
      final user = _authService.getSavedUser();
      
      // Process return
      await _supabaseService.processProductReturn(
        returnId: returnId,
        acceptedQuantity: returnQty,
        processedBy: user?.id ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Return diproses: $returnQty produk diterima'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload returns
        await _loadReturns();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(
        title: '👨‍💼 Manager - $_outletName',
        onMenuPressed: () {
          Scaffold.of(context).openDrawer();
        },
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: AppColors.primary,
              ),
              child: const Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Pengaturan'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tab Bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.inventory_2), text: 'Stok'),
              Tab(icon: Icon(Icons.send), text: 'Alokasi'),
              Tab(icon: Icon(Icons.undo), text: 'Return'),
            ],
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStockTab(),
                _buildAllocationTab(),
                _buildReturnTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STOCK TAB UI ====================
  Widget _buildStockTab() {
    if (_loadingStocks) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada data stok',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStocks,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Bahan Baku',
                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_stocks.length} item',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // Low stock warning
                if (_stocks.where((s) => (s['quantity'] as int) < (s['low_stock_threshold'] as int)).isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⚠️ ${_stocks.where((s) => (s['quantity'] as int) < (s['low_stock_threshold'] as int)).length} item stok rendah',
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Stock List
          Text(
            'Daftar Bahan Baku',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ..._stocks.map((stock) {
            final isLowStock = (stock['quantity'] as int) < (stock['low_stock_threshold'] as int);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stock['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Unit: ${stock['unit']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isLowStock)
                          Chip(
                            label: const Text('Rendah'),
                            backgroundColor: Colors.orange[100],
                            labelStyle: const TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stok',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${stock['quantity']} ${stock['unit']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Harga Satuan',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Rp ${NumberFormat('#,##0', 'id_ID').format(stock['cost'])}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Nilai',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Rp ${NumberFormat('#,##0', 'id_ID').format((stock['quantity'] as int) * (stock['cost'] as int))}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ==================== ALLOCATION TAB UI ====================
  Widget _buildAllocationTab() {
    if (_loadingAllocation) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alokasi Produk ke Outlet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          // Product Selection
          Text(
            'Pilih Produk',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedProductId,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              hintText: 'Pilih produk',
            ),
            items: _showcaseProducts.map((product) {
              return DropdownMenuItem(
                value: product['id'] as String,
                child: Text(product['name'] as String),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedProductId = value);
            },
          ),
          const SizedBox(height: 20),
          // Outlet Selection
          Text(
            'Tujuan Outlet',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedOutletId,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              hintText: 'Pilih outlet',
            ),
            items: _outlets.map((outlet) {
              return DropdownMenuItem(
                value: outlet['id'] as String,
                child: Text(outlet['name'] as String),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedOutletId = value);
            },
          ),
          const SizedBox(height: 20),
          // Quantity
          Text(
            'Jumlah',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: '1',
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              hintText: 'Jumlah produk',
            ),
            onChanged: (value) {
              setState(() => _allocationQuantity = int.tryParse(value) ?? 1);
            },
          ),
          const SizedBox(height: 24),
          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: _allocateProduct,
              child: const Text(
                'Alokasikan Produk',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== RETURN TAB UI ====================
  Widget _buildReturnTab() {
    if (_loadingReturns) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingReturns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.undo, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada pengembalian pending',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReturns,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Proses Pengembalian Produk',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ..._pendingReturns.map((returnRecord) {
            final returnId = returnRecord['id'] as String;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                returnRecord['product_name'] ?? 'Unknown Product',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Return ID: ${returnId.substring(0, 8)}...',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text('${returnRecord['quantity']} item'),
                          backgroundColor: Colors.blue[100],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Jumlah yang Diterima',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: '0',
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hintText: 'Jumlah diterima',
                            ),
                            onChanged: (value) {
                              setState(() {
                                _returnQuantities[returnId] = int.tryParse(value) ?? 0;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            onPressed: () => _processReturn(returnRecord),
                            child: const Text(
                              'Terima',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((returnRecord['reason'] as String?).isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            'Alasan:',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            returnRecord['reason'] ?? '-',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
