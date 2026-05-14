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
      final stockMap = await _supabaseService.getProductStock(outletId);

      // Add stock info to products
      _products.clear();
      for (final product in products) {
        final productWithStock = Product(
          id: product.id,
          categoryId: product.categoryId,
          name: product.name,
          description: product.description,
          price: product.price,
          hpp: product.hpp,
          isActive: product.isActive,
          stock: stockMap[product.id] ?? 0,
          createdAt: product.createdAt,
          updatedAt: product.updatedAt,
        );
        _products.add(productWithStock);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
