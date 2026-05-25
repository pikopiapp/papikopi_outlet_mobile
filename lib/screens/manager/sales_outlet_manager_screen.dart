import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';
import '../../utils/holiday_detector.dart';

class SalesOutletManagerScreen extends StatefulWidget {
  const SalesOutletManagerScreen({super.key});

  @override
  State<SalesOutletManagerScreen> createState() =>
      _SalesOutletManagerScreenState();
}

class _SalesOutletManagerScreenState extends State<SalesOutletManagerScreen>
    with SingleTickerProviderStateMixin {
  final _supabaseService = SupabaseService();

  late TabController _tabController;
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _baristaList = [];
  Map<String, dynamic> _selectedOutletSales = {};
  Map<String, String> _baristaNameMap = {}; // Map baristaId to name
  Map<String, String> _outletBaristaMap = {}; // Map outletId to primary barista name
  Map<String, String> _productNameMap = {}; // Map productId to name

  bool _isLoading = true;
  String? _error;

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _fetchOutletsAndSales();
  }

  Future<void> _fetchOutletsAndSales() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch all outlets
      final outletsData = await _supabaseService.fetchOutlets();

      // Fetch baristas for all outlets to build outlet-barista mapping
      Map<String, String> outletBaristaMap = {};
      for (final outlet in outletsData) {
        final outletId = outlet['id'] as String?;
        if (outletId != null) {
          try {
            final baristas = await _supabaseService.getBaristasByOutlet(outletId: outletId);
            if (baristas.isNotEmpty) {
              final primaryBarista = baristas[0];
              final baristaName = primaryBarista['name'] as String? ?? 'Unknown';
              outletBaristaMap[outletId] = baristaName;
            }
          } catch (e) {
            print('[SalesOutletManager] Error fetching baristas for outlet $outletId: $e');
          }
        }
      }

      setState(() {
        _outlets = outletsData;
        _outletBaristaMap = outletBaristaMap;
        _isLoading = false;
      });

      // Fetch detailed sales for first outlet (or selected)
      if (_outlets.isNotEmpty) {
        await _fetchOutletDetailedSales(_outlets[0]['id']);
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchOutletDetailedSales(String outletId) async {
    try {
      // Fetch baristas for this outlet
      final baristas = await _supabaseService.getBaristasByOutlet(outletId: outletId);
      
      final salesList = await _supabaseService.getSales(outletId: outletId);

      // Filter by selected date and calculate totals
      final startDate = DateTime.utc(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endDate = startDate.add(const Duration(days: 1));

      int totalItems = 0;
      double totalRevenue = 0.0;
      Map<String, int> productCount = {};
      Map<String, double> productRevenue = {};
      Map<String, String> productNames = {}; // productId -> productName
      Map<String, int> baristaItemCount = {};
      Map<String, double> baristaRevenue = {}; // Track revenue per barista
      
      // Payment breakdown per barista
      Map<String, double> baristaCashRevenue = {}; // baristaId -> cash amount
      Map<String, double> baristaQrisRevenue = {}; // baristaId -> QRIS amount
      Map<String, int> baristaFreeCount = {}; // baristaId -> free transaction count

      for (final sale in salesList) {
        if (sale.createdAt.isAfter(startDate) && sale.createdAt.isBefore(endDate)) {
          for (final item in sale.items) {
            totalItems += item.quantity;
            totalRevenue += item.unitPrice * item.quantity;
            
            productCount[item.productId] = (productCount[item.productId] ?? 0) + item.quantity;
            productRevenue[item.productId] = (productRevenue[item.productId] ?? 0) + (item.unitPrice * item.quantity);
            productNames[item.productId] = item.productName; // Store product name
            
            // Track revenue per barista for bonus calculation
            baristaRevenue[sale.baristaId] = (baristaRevenue[sale.baristaId] ?? 0.0) + (item.unitPrice * item.quantity);
          }

          // Count items per barista
          baristaItemCount[sale.baristaId] = (baristaItemCount[sale.baristaId] ?? 0) + sale.items.length;
          
          // Track payment method breakdown per barista
          if (sale.totalAmount > 0) {
            if (sale.paymentMethod.toUpperCase() == 'CASH') {
              baristaCashRevenue[sale.baristaId] = (baristaCashRevenue[sale.baristaId] ?? 0.0) + sale.totalAmount;
            } else if (sale.paymentMethod.toUpperCase() == 'QRIS') {
              baristaQrisRevenue[sale.baristaId] = (baristaQrisRevenue[sale.baristaId] ?? 0.0) + sale.totalAmount;
            }
          } else {
            // Free transaction
            baristaFreeCount[sale.baristaId] = (baristaFreeCount[sale.baristaId] ?? 0) + 1;
          }
        }
      }

      setState(() {
        _baristaList = baristas;
        _selectedOutletSales = {
          'outlet_id': outletId,
          'total_items': totalItems,
          'total_revenue': totalRevenue,
          'product_count': productCount,
          'product_revenue': productRevenue,
          'product_names': productNames,
          'barista_count': baristaItemCount,
          'barista_revenue': baristaRevenue,
          'barista_cash': baristaCashRevenue,
          'barista_qris': baristaQrisRevenue,
          'barista_free': baristaFreeCount,
        };
        // Build barista name map for quick lookup
        _baristaNameMap = {};
        for (final barista in baristas) {
          final id = barista['id'] as String?;
          final name = barista['name'] as String? ?? 'Unknown';
          if (id != null) {
            _baristaNameMap[id] = name;
          }
        }
        // Update product name map for later use
        _productNameMap.addAll(productNames);
      });

      print('[SalesOutletManager] Outlet $outletId: $totalItems items, Rp${totalRevenue.toStringAsFixed(0)} revenue');
      print('[SalesOutletManager] Baristas in outlet: ${baristas.length}');
    } catch (e) {
      print('[SalesOutletManager] Error fetching outlet sales: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          color: AppColors.background,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Penjualan Outlet'),
              Tab(text: 'Bonus Barista'),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSalesTab(),
              _buildBaristaTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalesTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Text('Error: $_error'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date picker
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2026, 1, 1),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _selectedDate = pickedDate;
                      });
                      await _fetchOutletsAndSales();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Icon(Icons.calendar_today),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Outlets list
          Text(
            'Ringkasan Penjualan per Outlet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _outlets.length,
            itemBuilder: (context, index) {
              final outlet = _outlets[index];
              return _buildOutletCard(outlet);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOutletCard(Map<String, dynamic> outlet) {
    final outletId = outlet['id'] as String?;
    final outletName = outlet['name'] as String? ?? 'Unknown';
    final baristaName = outletId != null ? _outletBaristaMap[outletId] ?? 'No barista' : 'No barista';

    return GestureDetector(
      onTap: () {
        if (outletId != null) {
          _fetchOutletDetailedSales(outletId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedOutletSales['outlet_id'] == outletId
                ? AppColors.primary
                : Colors.grey.withValues(alpha: 0.3),
            width: _selectedOutletSales['outlet_id'] == outletId ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outletName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Barista: $baristaName',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedOutletSales['outlet_id'] == outletId) ...[
              _buildSalesStat(
                'Total Penjualan',
                '${_selectedOutletSales['total_items'] ?? 0} items',
              ),
              const SizedBox(height: 8),
              _buildSalesStat(
                'Total Revenue',
                'Rp${NumberFormat('#,##0', 'id_ID').format(_selectedOutletSales['total_revenue'] ?? 0)}',
              ),
              const SizedBox(height: 12),
              // Top products
              if ((_selectedOutletSales['product_count'] as Map? ?? {}).isNotEmpty) ...[
                Text(
                  'Produk Terlaris',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                ..._buildTopProducts(),
              ],
            ] else
              Text(
                'Tap untuk detail penjualan',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTopProducts() {
    final products = (_selectedOutletSales['product_count'] as Map? ?? {});
    final productNames = (_selectedOutletSales['product_names'] as Map? ?? {});
    if (products.isEmpty) return [];

    final sorted = products.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return sorted.take(3).map((entry) {
      final productId = entry.key as String;
      final quantity = entry.value as int;
      final productName = productNames[productId] ?? productId;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                productName,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${quantity}x',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSalesStat(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
        ),
      ],
    );
  }

  Widget _buildBaristaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manajemen Bonus Barista',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          // Info Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              border: Border.all(color: AppColors.accent, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bonus dihitung berdasarkan total omset harian dengan sistem bertingkat',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Bonus Tier Info
          _buildBonusTierInfo(),
          const SizedBox(height: 24),
          if (_baristaList.isNotEmpty) ...[
            Text(
              'Daftar Barista (${_baristaList.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _baristaList.length,
              itemBuilder: (context, index) {
                final barista = _baristaList[index];
                final baristaId = barista['id'] as String? ?? '';
                final cashAmount = (_selectedOutletSales['barista_cash'] as Map? ?? {})[baristaId] as double? ?? 0.0;
                final qrisAmount = (_selectedOutletSales['barista_qris'] as Map? ?? {})[baristaId] as double? ?? 0.0;
                final freeCount = (_selectedOutletSales['barista_free'] as Map? ?? {})[baristaId] as int? ?? 0;
                
                // Calculate bonus and settlement using finance_screen formula
                final Map<String, dynamic> bonusCalc = _calculateBonusAndMeal(cashAmount, qrisAmount, freeCount);
                final double omset = bonusCalc['omset'] as double;
                final double bonus = bonusCalc['bonus'] as double;
                final double mealAllowance = bonusCalc['mealAllowance'] as double;
                final String settlementType = bonusCalc['settlementType'] as String;
                final double settlementAmount = bonusCalc['settlementAmount'] as double;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.altSurface),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(
                              (barista['name'] as String? ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  barista['name'] ?? 'Unknown',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  barista['email'] ?? '',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Omset Breakdown Section
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Omset:',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            _buildBonusLine(
                              'Penjualan',
                              'Rp ${NumberFormat('#,##0', 'id_ID').format(omset.toInt())}',
                              Colors.black,
                            ),
                            const SizedBox(height: 4),
                            _buildBonusLine(
                              '  ├─ Cash',
                              'Rp ${NumberFormat('#,##0', 'id_ID').format(cashAmount.toInt())}',
                              Colors.black87,
                            ),
                            const SizedBox(height: 4),
                            _buildBonusLine(
                              '  └─ QRIS',
                              'Rp ${NumberFormat('#,##0', 'id_ID').format(qrisAmount.toInt())}',
                              Colors.black87,
                            ),
                            if (freeCount > 0) ...[
                              const SizedBox(height: 4),
                              _buildBonusLine(
                                'Gratis',
                                '$freeCount transaksi',
                                Colors.black87,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Holiday Bonus Indicator
                      if (bonusCalc['isHolidayDate'] == true)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purple, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                '🎉',
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bonus ${getHolidayDescription(_selectedDate)}: Semua Tier 20%',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.purple,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (bonusCalc['isHolidayDate'] == true) const SizedBox(height: 12),
                      // Settlement Calculation Section (Finance Screen Formula)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: settlementType == 'deposit'
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: settlementType == 'deposit' ? Colors.green : Colors.orange,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rincian Setoran',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            _buildBonusLine(
                              'CASH Diterima',
                              'Rp ${NumberFormat('#,##0', 'id_ID').format(cashAmount.toInt())}',
                              Colors.black,
                            ),
                            const SizedBox(height: 4),
                            _buildBonusLine(
                              '- Bonus (Bertahap)',
                              '-Rp ${NumberFormat('#,##0', 'id_ID').format(bonus.toInt())}',
                              Colors.red,
                            ),
                            const SizedBox(height: 4),
                            _buildBonusLine(
                              '- Uang Makan',
                              '-Rp ${NumberFormat('#,##0', 'id_ID').format(mealAllowance.toInt())}',
                              Colors.red,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: AppColors.altSurface, width: 1)),
                              ),
                              child: _buildBonusLine(
                                settlementType == 'deposit'
                                    ? '= Setoran ke Papikopi'
                                    : '= Kekurangan (dari Papikopi)',
                                'Rp ${NumberFormat('#,##0', 'id_ID').format(settlementAmount.toInt())}',
                                settlementType == 'deposit' ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Info formula
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Text(
                          'Rumus: Setoran = CASH - Bonus - Uang Makan\nQRIS langsung ke rekening toko',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: Colors.blue.shade700,
                                height: 1.3,
                              ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Tidak ada data barista untuk outlet ini',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBonusTierInfo() {
    final bool isHolidayDate = isHoliday(_selectedDate);
    final String holidayDescription = isHolidayDate ? getHolidayDescription(_selectedDate) : '';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHolidayDate ? Colors.purple.withValues(alpha: 0.05) : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHolidayDate ? Colors.purple : AppColors.altSurface,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isHolidayDate) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bonus $holidayDescription: Semua Tier 20%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            isHolidayDate ? 'Sistem Bonus (Hari Libur)' : 'Sistem Bonus Bertingkat',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isHolidayDate ? Colors.purple : AppColors.primary,
                ),
          ),
          const SizedBox(height: 8),
          if (isHolidayDate)
            _buildBonusLine('Semua omset', '20%', Colors.purple)
          else ...[
            _buildBonusLine('Rp 0 - 200.000', '10%', Colors.black87),
            const SizedBox(height: 4),
            _buildBonusLine('Rp 200.000 - 350.000', '12%', Colors.black87),
            const SizedBox(height: 4),
            _buildBonusLine('Rp 350.000 - 500.000', '15%', Colors.black87),
            const SizedBox(height: 4),
            _buildBonusLine('> Rp 500.000', '20%', Colors.black87),
          ],
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Uang Makan:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
          ),
          const SizedBox(height: 4),
          _buildBonusLine('< Rp 300.000', 'Rp 25.000', Colors.black87),
          const SizedBox(height: 4),
          _buildBonusLine('≥ Rp 300.000', 'Rp 34.000', Colors.black87),
        ],
      ),
    );
  }

  Widget _buildBonusLine(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
        ),
      ],
    );
  }

  Map<String, dynamic> _calculateBonusAndMeal(double cashAmount, double qrisAmount, int freeCount) {
    double omset = cashAmount + qrisAmount; // Total omset (excluding free)
    double mealAllowance = omset >= 300000 ? 34000 : 25000;
    double bonusAmount = 0.0;
    
    // Check if selected date is a holiday or weekend using holiday_detector utility
    // isHoliday checks for both weekends and Indonesian national holidays
    final bool isHolidayDate = isHoliday(_selectedDate);
    
    if (isHolidayDate) {
      // Holiday calculation: 20% for all tiers
      bonusAmount = omset * 0.20;
    } else {
      // Regular tiered calculation
      if (omset <= 200000) {
        bonusAmount = omset * 0.10;
      } else if (omset <= 350000) {
        bonusAmount = (200000 * 0.10) + ((omset - 200000) * 0.12);
      } else if (omset <= 500000) {
        bonusAmount = (200000 * 0.10) + (150000 * 0.12) + ((omset - 350000) * 0.15);
      } else {
        bonusAmount = (200000 * 0.10) + (150000 * 0.12) + (150000 * 0.15) + ((omset - 500000) * 0.20);
      }
    }

    // Calculate final settlement using finance_screen formula:
    // Setoran = CASH - Bonus - Uang Makan
    double depositAmount = cashAmount - bonusAmount - mealAllowance;
    
    // Determine settlement type and amount
    String settlementType = 'deposit'; // 'deposit' (positive), 'shortfall' (negative)
    double settlementAmount = depositAmount;
    
    if (depositAmount < 0) {
      settlementType = 'shortfall';
      settlementAmount = depositAmount.abs(); // Make positive for display
    }

    return {
      'omset': omset,
      'cashAmount': cashAmount,
      'qrisAmount': qrisAmount,
      'freeCount': freeCount,
      'bonus': bonusAmount,
      'mealAllowance': mealAllowance,
      'depositAmount': depositAmount,
      'settlementType': settlementType, // 'deposit' or 'shortfall'
      'settlementAmount': settlementAmount,
      'isHolidayDate': isHolidayDate,
    };
  }
}
