import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/outlet.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';

import '../../providers/auth_provider.dart';


class ManagerOutletDetailScreen extends StatefulWidget {
  final String outletId;

  const ManagerOutletDetailScreen({
    super.key,
    required this.outletId,
  });

  @override
  State<ManagerOutletDetailScreen> createState() => _ManagerOutletDetailScreenState();
}

class _ManagerOutletDetailScreenState extends State<ManagerOutletDetailScreen> {
  // Palette hardcode untuk memenuhi permintaan desain
  static const _golkarYellow = Color(0xFFFFD600);
  static const _hijau = Color(0xFF388E3C);
  static const _hitam = Color(0xFF212121);
  static const _netralGrey = Color(0xFF757575);
  static const _putih = Color(0xFFFFFFFF);
  static const _greenSoft = Color(0xFFE8F5E9);

  final _supabase = SupabaseService();

  bool _loading = true;
  String? _error;

  Outlet? _outlet;
  Map<String, dynamic>? _salesSummary;
  List<Map<String, dynamic>> _productBatches = const [];
  List<Map<String, dynamic>> _productSales = const [];
  List<Map<String, dynamic>> _baristas = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!_supabase.isInitialized) {
        await _supabase.initialize();
      }

      final outlet = await _supabase.getOutlet(widget.outletId);
      final baristas = await _supabase.getBaristasByOutlet(outletId: widget.outletId);

      // Batches
      final batches = await _supabase.getProductBatchStock(widget.outletId);

      // Sales summary + product sales
      // We derive from sales + sale_items + products.
      final salesSummary = await _fetchSalesSummary(widget.outletId);
      final productSales = await _fetchProductSales(widget.outletId);

      setState(() {
        _outlet = outlet;
        _baristas = baristas;
        _productBatches = batches;
        _salesSummary = salesSummary;
        _productSales = productSales;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchSalesSummary(String outletId) async {
    // Uses existing supabase logic patterns: leverage 'sales' table.
    // Required fields aligned to web: total_revenue, total_profit, total_bonus,
    // total_hpp, total_transactions, today_revenue, today_transactions,
    // cash_revenue, qris_revenue.
    //
    // Mobile SupabaseService doesn't yet expose RPC summary for outlets,
    // so we compute directly.

    final now = DateTime.now();

    // Business-day alignment isn't defined here for sales_summary; web appears to use
    // sales_summary from backend that likely uses business-day. We'll approximate with
    // calendar day using created_at.
    final startToday = DateTime(now.year, now.month, now.day).toUtc();
    final endToday = DateTime(now.year, now.month, now.day).add(const Duration(days: 1)).toUtc().subtract(const Duration(seconds: 1));

    final allSales = await _supabase.client
        .from('sales')
        .select('total_amount, profit, bonus_amount, hpp_total, payment_method')
        .eq('outlet_id', outletId);

    final todaySales = await _supabase.client
        .from('sales')
        .select('total_amount, profit, bonus_amount, hpp_total, payment_method, created_at')
        .eq('outlet_id', outletId)
        .gte('created_at', startToday.toIso8601String())
        .lte('created_at', endToday.toIso8601String());

    double sumDouble(List<dynamic> rows, String key) {
      return rows.fold<double>(0, (acc, r) => acc + ((r[key] as num?)?.toDouble() ?? 0.0));
    }

    int sumInt(List<dynamic> rows) => rows.length;

    double totalRevenue = sumDouble(allSales, 'total_amount');
    double totalProfit = sumDouble(allSales, 'profit');
    double totalBonus = sumDouble(allSales, 'bonus_amount');
    double totalHpp = sumDouble(allSales, 'hpp_total');
    int totalTransactions = sumInt(allSales);

    double todayRevenue = sumDouble(todaySales, 'total_amount');
    int todayTransactions = sumInt(todaySales);

    double cashRevenue = (todaySales as List<dynamic>).fold<double>(0, (acc, r) {
      final method = (r['payment_method'] as String?)?.toUpperCase() ?? '';
      if (method == 'CASH') return acc + ((r['total_amount'] as num?)?.toDouble() ?? 0.0);
      return acc;
    });

    double qrisRevenue = (todaySales as List<dynamic>).fold<double>(0, (acc, r) {
      final method = (r['payment_method'] as String?)?.toUpperCase() ?? '';
      if (method == 'QRIS') return acc + ((r['total_amount'] as num?)?.toDouble() ?? 0.0);
      return acc;
    });

    return {
      'total_revenue': totalRevenue,
      'total_profit': totalProfit,
      'total_bonus': totalBonus,
      'total_hpp': totalHpp,
      'total_transactions': totalTransactions,
      'today_revenue': todayRevenue,
      'today_transactions': todayTransactions,
      'cash_revenue': cashRevenue,
      'qris_revenue': qrisRevenue,
    };
  }

  Future<List<Map<String, dynamic>>> _fetchProductSales(String outletId) async {
    // Derive from sale_items -> join products to get product name.
    // We return shape: product_id, product_name, quantity, revenue

    final sales = await _supabase.client
        .from('sales')
        .select('id')
        .eq('outlet_id', outletId);

    final saleIds = (sales as List<dynamic>)
        .map((s) => s['id'] as String?)
        .whereType<String>()
        .toList();

    if (saleIds.isEmpty) return const [];

    // Fetch sale items and products
    final items = await _supabase.client
        .from('sale_items')
        .select('product_id, quantity, price, products(name)')
        .inFilter('sale_id', saleIds);

    // Aggregate by product_id
    final agg = <String, Map<String, dynamic>>{};
    for (final row in items as List<dynamic>) {
      final productId = row['product_id'] as String?;
      if (productId == null) continue;

      final qty = (row['quantity'] as num?)?.toInt() ?? 0;
      final price = (row['price'] as num?)?.toDouble() ?? 0.0;
      final revenue = qty * price;

      final productName = (row['products']?['name'] as String?) ?? 'Unknown';

      agg.update(productId, (existing) {
        existing['quantity'] = (existing['quantity'] as int) + qty;
        existing['revenue'] = (existing['revenue'] as double) + revenue;
        return existing;
      }, ifAbsent: () {
        return {
          'product_id': productId,
          'product_name': productName,
          'quantity': qty,
          'revenue': revenue,
        };
      });
    }

    final result = agg.values.toList();
    result.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    return result;
  }

  String _formatRupiah(num value) {
    final v = value.toDouble();
    return 'Rp ${v.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\\d)(?=(\\d{3})+(?!\\d))'),
          (m) => '${m.group(1)}.',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    final title = _outlet?.name ?? 'Outlet';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'SiAGA',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 2),
            ),
            Text(
              'Sistem Aplikasi Pedagang Pasar',
style: TextStyle(fontSize: 12, color: _netralGrey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: $_error')))
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
          color: _hitam,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                      (_outlet?.location ?? 'Alamat belum tersedia'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.neutralGrey),
                      ),
                      const SizedBox(height: 16),

                      _salesSummarySection(),
                      const SizedBox(height: 16),

                      _baristaSection(),
                      const SizedBox(height: 16),

                      _productBatchesSection(),
                      const SizedBox(height: 16),

                      _productSalesSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _salesSummarySection() {
    final s = _salesSummary;
    if (s == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Sales summary belum tersedia'),
        ),
      );
    }

    final summary = s;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              runSpacing: 10,
              spacing: 10,
              children: [
                _miniStat('Total Revenue', _formatRupiah(summary['total_revenue'] ?? 0)),
                _miniStat('Today Revenue', _formatRupiah(summary['today_revenue'] ?? 0)),
                _miniStat('Total Profit', _formatRupiah(summary['total_profit'] ?? 0)),
                _miniStat('Total Bonus', _formatRupiah(summary['total_bonus'] ?? 0)),
                _miniStat('Transactions', '${summary['total_transactions'] ?? 0}'),
                _miniStat('Today Tx', '${summary['today_transactions'] ?? 0}'),
                _miniStat('Cash Today', _formatRupiah(summary['cash_revenue'] ?? 0)),
                _miniStat('QRIS Today', _formatRupiah(summary['qris_revenue'] ?? 0)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.putih,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.altSurface.withOpacity(0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutralGrey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.hitam)),
        ],
      ),
    );
  }

  Widget _baristaSection() {
    final barista = _baristas.isNotEmpty ? _baristas.first : null;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Barista', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (barista == null)
              Text('Barista belum ter-assign', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.neutralGrey))
            else
              Row(
                children: [
                  Icon(Icons.person, color: AppColors.hijau),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      barista['name']?.toString() ?? 'Barista',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.hitam),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _productBatchesSection() {
    if (_productBatches.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Available products (batches) belum tersedia'),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Available Products (Batches)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._productBatches.map((b) {
              final name = b['product_name']?.toString() ?? 'Produk';
              final qty = (b['quantity'] as num?)?.toInt() ?? 0;
              final batchCode = b['batch_code']?.toString() ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hijau.withOpacity(0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.inventory_2, color: AppColors.hijau),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.hitam)),
                          const SizedBox(height: 4),
                          if (batchCode.isNotEmpty)
                            Text('Batch: $batchCode', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutralGrey)),
                          Text('Stok: $qty unit', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.hijau)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _productSalesSection() {
    if (_productSales.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Product sales belum tersedia'),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product Sales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._productSales.take(5).map((sale) {
              final name = sale['product_name']?.toString() ?? 'Produk';
              final qty = (sale['quantity'] as num?)?.toInt() ?? 0;
              final revenue = (sale['revenue'] as num?)?.toDouble() ?? 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hijau.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, color: AppColors.hijau),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.hitam)),
                          const SizedBox(height: 4),
                          Text('$qty sold', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutralGrey)),
                        ],
                      ),
                    ),
                    Text(
                      _formatRupiah(revenue),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.hijau),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

