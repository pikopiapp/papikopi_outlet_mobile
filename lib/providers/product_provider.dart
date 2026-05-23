import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/outlet.dart';
import '../services/supabase_service.dart';

class ProductProvider extends ChangeNotifier {
  final List<Product> _products = [];
  final List<Category> _categories = [];
  Outlet? _currentOutlet;
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  Outlet? get currentOutlet => _currentOutlet;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final _supabaseService = SupabaseService();

  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (!_supabaseService.isInitialized) {
        // Demo products
        _products.clear();
        _products.addAll([
          Product(
            id: 'espresso-demo',
            categoryId: 'coffee',
            name: 'Espresso',
            description: 'Strong shot of espresso',
            price: 20000,
            hpp: 8000,
            isActive: true,
            stock: 50,
            createdAt: DateTime.now(),
          ),
          Product(
            id: 'americano-demo',
            categoryId: 'coffee',
            name: 'Americano',
            description: 'Espresso with hot water',
            price: 25000,
            hpp: 10000,
            isActive: true,
            stock: 30,
            createdAt: DateTime.now(),
          ),
          Product(
            id: 'latte-demo',
            categoryId: 'coffee',
            name: 'Latte',
            description: 'Espresso with steamed milk',
            price: 35000,
            hpp: 15000,
            isActive: true,
            stock: 20,
            createdAt: DateTime.now(),
          ),
          Product(
            id: 'cappuccino-demo',
            categoryId: 'coffee',
            name: 'Cappuccino',
            description: 'Espresso with foam',
            price: 35000,
            hpp: 15000,
            isActive: true,
            stock: 0,
            createdAt: DateTime.now(),
          ),
        ]);
        notifyListeners();
        return;
      }

      final products = await _supabaseService.getProducts();
      _products.clear();
      _products.addAll(products);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (!_supabaseService.isInitialized) {
        // Demo categories
        _categories.clear();
        _categories.addAll([
          Category(
            id: 'coffee',
            name: 'Coffee',
            createdAt: DateTime.now(),
          ),
          Category(
            id: 'tea',
            name: 'Tea',
            createdAt: DateTime.now(),
          ),
          Category(
            id: 'food',
            name: 'Food',
            createdAt: DateTime.now(),
          ),
        ]);
        notifyListeners();
        return;
      }

      final categories = await _supabaseService.getCategories();
      _categories.clear();
      _categories.addAll(categories);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOutlet(String outletId) async {
    try {
      final outlet = await _supabaseService.getOutlet(outletId);
      _currentOutlet = outlet;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  List<Product> getProductsByCategory(String categoryId) {
    return _products.where((p) => p.categoryId == categoryId).toList();
  }

  // Load products with stock for a specific outlet
  Future<void> loadProductsWithStock(String outletId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // First load products
      if (!_supabaseService.isInitialized) {
        // Demo products with stock
        _products.clear();
        _products.addAll([
          Product(
            id: 'espresso-demo',
            categoryId: 'coffee',
            name: 'Espresso',
            description: 'Strong shot of espresso',
            price: 20000,
            hpp: 8000,
            isActive: true,
            stock: 50,
            createdAt: DateTime.now(),
          ),
          Product(
            id: 'americano-demo',
            categoryId: 'coffee',
            name: 'Americano',
            description: 'Espresso with hot water',
            price: 25000,
            hpp: 10000,
            isActive: true,
            stock: 30,
            createdAt: DateTime.now(),
          ),
          Product(
            id: 'latte-demo',
            categoryId: 'coffee',
            name: 'Latte',
            description: 'Espresso with steamed milk',
            price: 35000,
            hpp: 15000,
            isActive: true,
            stock: 20,
            createdAt: DateTime.now(),
          ),
          Product(
            id: 'cappuccino-demo',
            categoryId: 'coffee',
            name: 'Cappuccino',
            description: 'Espresso with foam',
            price: 35000,
            hpp: 15000,
            isActive: true,
            stock: 0,
            createdAt: DateTime.now(),
          ),
        ]);
        notifyListeners();
        return;
      }

      // Get products and stock from Supabase
      final products = await _supabaseService.getProducts();
      
      // Use TODAY's date for stock filtering in POS (DateTime.now() in local time)
      // This must match stock_screen's selectedDate calculation
      final today = DateTime.now();
      
      // Fetch outlet's business_day_start_hour for proper business day calculation
      // Get it directly from Supabase since Outlet model doesn't have this field yet
      int businessDayStartHour = 4; // Default
      try {
        final outletData = await _supabaseService.client
            .from('outlets')
            .select('business_day_start_hour')
            .eq('id', outletId)
            .single();
        businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;
      } catch (e) {
        print('⚠️ Could not fetch business_day_start_hour, using default: $businessDayStartHour');
      }
      
      print('🛒 POS loadProductsWithStock:');
      print('   Today (Local): ${today.toIso8601String()}');
      print('   Outlet: $outletId');
      print('   Business Day Start Hour: $businessDayStartHour');
      
      // Calculate business day range in LOCAL time (same as stock_screen)
      final year = today.year;
      final month = today.month;
      final day = today.day;
      
      DateTime businessDayStartLocal;
      DateTime businessDayEndLocal;
      
      if (businessDayStartHour >= 12) {
        // Afternoon start: business day is from YESTERDAY@startHour to TODAY@startHour
        businessDayStartLocal = DateTime(year, month, day - 1, businessDayStartHour, 0, 0);
        businessDayEndLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
      } else {
        // Morning start: business day is from TODAY@startHour to TOMORROW@startHour
        businessDayStartLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
        businessDayEndLocal = DateTime(year, month, day + 1, businessDayStartHour, 0, 0);
      }
      
      businessDayEndLocal = businessDayEndLocal.subtract(const Duration(milliseconds: 1));
      
      print('   Business Day (Local): ${businessDayStartLocal.toIso8601String()} to ${businessDayEndLocal.toIso8601String()}');
      
      final stockMap = await _supabaseService.getProductStock(
        outletId,
        selectedDate: today,
      );
      final soldMap = await _supabaseService.getSoldQuantityToday(
        outletId: outletId,
        selectedDate: today,
      );
      final returnedMap = await _supabaseService.getReturnedQuantityToday(
        outletId: outletId,
        selectedDate: today,
      );
      final transferStats = await _supabaseService.getProductTransferStats(
        outletId: outletId,
        selectedDate: today,
      );

      // Add stock info to products
      // stock = quantity from showcase_allocations (no deductions)
      // tersedia = sisa after deductions (sold, returned, transfers)
      _products.clear();
      
      print('🛒 POS loadProductsWithStock - Calculation Debug:');
      print('   Today: ${today.toIso8601String()}');
      print('   Stock Map (quantity): $stockMap');
      print('   Sold Map: $soldMap');
      print('   Returned Map: $returnedMap');
      print('   Transfer Stats: $transferStats');
      
      for (final product in products) {
        final quantity = stockMap[product.id] ?? 0;  // Stok allocated in business day
        final sold = soldMap[product.id] ?? 0;
        final returned = returnedMap[product.id] ?? 0;
        final transfers = transferStats[product.id] ?? {'dikirim': 0, 'diterima': 0};
        
        // Calculate remaining stock (tersedia = sisa after deductions)
        final dikirim = (transfers['dikirim'] ?? 0) as num;
        final diterima = (transfers['diterima'] ?? 0) as num;
        final sisa = quantity - sold - returned - dikirim.toInt() + diterima.toInt();
        
        print('   📦 ${product.name}: stock=$quantity (no deductions), tersedia=$sisa (after sold=$sold, returned=$returned, dikirim=$dikirim, diterima=$diterima)');
        
        // Create product with both stock and tersedia values
        final productWithStock = Product(
          id: product.id,
          categoryId: product.categoryId,
          name: product.name,
          description: product.description,
          price: product.price,
          hpp: product.hpp,
          isActive: product.isActive,
          stock: quantity,  // Quantity from showcase_allocations (no deductions)
          tersedia: sisa > 0 ? sisa : 0,  // Tersedia after deductions
          createdAt: product.createdAt,
          updatedAt: product.updatedAt,
        );
        _products.add(productWithStock);
      }
      
      print('✅ Products loaded: ${_products.length} items');
      print('   Note: stock = quantity (no deductions), tersedia = sisa (after sales/returns/transfers)');
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
