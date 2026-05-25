import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:io';
import '../models/user.dart' as user_model;
import '../models/product.dart';
import '../models/outlet.dart';
import '../models/sale.dart';
import '../models/stock.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  static late final SupabaseClient _client;
  static bool _isInitialized = false;
  static Future<void>? _initializationFuture;
  
  // Cache for current user to avoid depending on userMetadata
  static user_model.User? _cachedUser;
  
  // Local cache for recent transfers (since stock_transfers table has RLS issues)
  static final List<Map<String, dynamic>> _recentTransfers = [];

  SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  // TODO: Replace with your actual Supabase credentials
  // Get these from https://supabase.com/dashboard/project/_/settings/api
  static const String supabaseUrl = 'https://hmihxkmrsmztuyvtykrj.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhtaWh4a21yc216dHV5dnR5a3JqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0ODcxMTgsImV4cCI6MjA5MzA2MzExOH0.dnp4hNTeoy3xTJ20LEgQKNydTra48_Sw27hwQJk68A4';

  SupabaseClient get client => _client;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    // Prevent multiple initialization attempts
    if (_isInitialized) return;
    
    _initializationFuture ??= _performInitialization();
    await _initializationFuture;
  }

  static Future<void> _performInitialization() async {
    try {
      // Check if credentials are configured
      if (supabaseUrl.startsWith('YOUR_') || supabaseAnonKey.startsWith('YOUR_')) {
        _isInitialized = false;
        return;
      }

      try {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
        ).timeout(
          const Duration(seconds: 10),
        );
        
        _client = Supabase.instance.client;
        _isInitialized = true;
      } on TimeoutException {
        _isInitialized = false;
      }
    } catch (e) {
      _isInitialized = false;
    }
  }

  // Helper method to check network connectivity
  static Future<bool> isNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('8.8.8.8');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Helper method to test Supabase connectivity
  static Future<bool> isSupabaseReachable() async {
    try {
      final result = await InternetAddress.lookup('hmihxkmrsmztuyvtykrj.supabase.co');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Authentication
  Future<user_model.User> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }
    
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('Sign up failed');
    }

    return user_model.User(
      id: response.user!.id,
      email: email,
      name: name,
      role: 'barista',
      outletId: '',
      createdAt: DateTime.now(),
    );
  }

  Future<user_model.User> signIn({
    required String email,
    required String password,
  }) async {
    if (!_isInitialized) {
      throw Exception('Koneksi ke server gagal. Supabase belum terinisialisasi. Pastikan kredensial Supabase sudah dikonfigurasi.');
    }
    
    // Check network connectivity first
    final isNetworkUp = await isNetworkAvailable();
    if (!isNetworkUp) {
      throw Exception('Tidak ada koneksi internet. Periksa WiFi/data Anda');
    }
    
    // Check Supabase connectivity
    final isSupabaseUp = await isSupabaseReachable();
    if (!isSupabaseUp) {
    }
    
    // 1) Pastikan session Supabase Auth terbentuk (karena RLS SELECT untuk authenticated).
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout: Koneksi server terlalu lama'),
      );

      final sessionUser = res.user;
      final session = _client.auth.currentSession;

      if (sessionUser != null && session != null) {
        // Ambil user profile dari tabel untuk isi role/outletId seperti model app.
        final profile = await _client
            .from('users')
            .select()
            .eq('id', sessionUser.id)
            .single();

        final user = user_model.User.fromJson(profile);

        final profileRole = user.role;
        final dynamicInvestorId = profile['investor_id'];
        final investorIdFromProfile =
            (dynamicInvestorId is String && dynamicInvestorId.isNotEmpty)
                ? dynamicInvestorId
                : null;


        if (profileRole == 'investor' && investorIdFromProfile != null) {
          _cachedUser = user_model.User(
            id: investorIdFromProfile,
            email: user.email,
            name: user.name,
            role: user.role,
            outletId: user.outletId,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
          );
          return _cachedUser!;
        }

        _cachedUser = user;
        return user;
      }
    } catch (e) {
      // 2) Fallback ke RPC verifikasi (legacy) jika auth sign-in gagal.

      final response = await _client.rpc(
        'verify_user_password',
        params: {
          'user_email': email,
          'user_password': password,
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout: Koneksi server terlalu lama'),
      );

      if (response != null && response is Map<String, dynamic>) {
        final success = response['success'] as bool? ?? false;

        if (success) {

          final userData = response['user'] as Map<String, dynamic>;
          final user = user_model.User.fromJson(userData);

          // When using fallback RPC, we may miss investor id remapping.
          // Fetch full users row and, if role == investor, remap user.id from users.investor_id.
          try {
            final profile = await _client
                .from('users')
                .select()
                .eq('id', user.id)
                .single();

            final profileRole = (profile['role'] as String?) ?? user.role;
            final dynamicInvestorId = profile['investor_id'];

            final investorIdFromProfile =
                (dynamicInvestorId is String && dynamicInvestorId.isNotEmpty)
                    ? dynamicInvestorId
                    : null;


            if (profileRole == 'investor' && investorIdFromProfile != null) {
              _cachedUser = user_model.User(
                id: investorIdFromProfile,
                email: user.email,
                name: user.name,
                role: user.role,
                outletId: user.outletId,
                createdAt: user.createdAt,
                updatedAt: user.updatedAt,
              );
              return _cachedUser!;
            }
          } catch (e) {
          }

          _cachedUser = user;
          return user;
        } else {
          final message = response['message'] as String? ?? 'Login gagal - alasan tidak diketahui';
          throw Exception(message);
        }
      }
      throw Exception('Response tidak valid dari server');
    }

    // Kalau sampai sini, sign-in tidak membentuk session dan RPC juga tidak return.
    throw Exception('Login gagal - tidak bisa membentuk session authenticated');
  }

  Future<void> signOut() async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }
    
    _cachedUser = null; // Clear cached user
    await _client.auth.signOut();
  }

  user_model.User? getCurrentUser() {
    // Return cached user first
    if (_cachedUser != null) {
      return _cachedUser;
    }
    
    final session = _client.auth.currentSession;
    if (session == null) return null;

    // Create user from session metadata if cache is empty
    final user = user_model.User(
      id: session.user.id,
      email: session.user.email ?? '',
      name: session.user.userMetadata?['name'] ?? 'User',
      role: session.user.userMetadata?['role'] ?? 'barista',
      outletId: session.user.userMetadata?['outlet_id'] ?? '',
      createdAt: DateTime.parse(session.user.createdAt),
    );
    
    return user;
  }

  /// Async variant: resolve investor remap from `users` table using the current session.
  /// This fixes the case where we load "saved user" without re-running `signIn()`.
  Future<user_model.User?> getCurrentUserWithProfile() async {
    // If we already have a remapped cached user, use it.
    if (_cachedUser != null) return _cachedUser;

    final session = _client.auth.currentSession;
    if (session == null) return null;

    // Baseline user from session
    final baseline = user_model.User(
      id: session.user.id,
      email: session.user.email ?? '',
      name: session.user.userMetadata?['name'] ?? 'User',
      role: session.user.userMetadata?['role'] ?? 'barista',
      outletId: session.user.userMetadata?['outlet_id'] ?? '',
      createdAt: DateTime.parse(session.user.createdAt),
    );


    try {
      final profile = await _client
          .from('users')
          .select()
          .eq('id', session.user.id)
          .single();

      // Debug: show all columns returned by users so we can find which one maps to investor_assignments.investor_id

      final parsed = user_model.User.fromJson(profile);

      final profileRole = parsed.role;
      final dynamicInvestorId = profile['investor_id'];
      final investorIdFromProfile =
          (dynamicInvestorId is String && dynamicInvestorId.isNotEmpty)
              ? dynamicInvestorId
              : null;


      if (profileRole == 'investor' && investorIdFromProfile != null) {
        _cachedUser = user_model.User(
          id: investorIdFromProfile,
          email: parsed.email,
          name: parsed.name,
          role: parsed.role,
          outletId: parsed.outletId,
          createdAt: parsed.createdAt,
          updatedAt: parsed.updatedAt,
        );
        return _cachedUser;
      }

      _cachedUser = parsed;
      return _cachedUser;
    } catch (e) {
      // If profile lookup fails, fallback to baseline.
      return baseline;
    }
  }
  
  void setCurrentUser(user_model.User user) {
    _cachedUser = user;
  }

  // Products
  Future<List<Product>> getProducts() async {
    final response = await _client
        .from('products')
        .select()
        .eq('is_active', true);

    return (response as List<dynamic>)
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Product>> getProductsByCategory(String categoryId) async {
    final response = await _client
        .from('products')
        .select()
        .eq('category_id', categoryId)
        .eq('is_active', true);

    return (response as List<dynamic>)
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // Categories
  Future<List<Category>> getCategories() async {
    final response = await _client.from('categories').select();

    return (response as List<dynamic>)
        .map((item) => Category.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // Sales
  Future<String> createSale({
    required String outletId,
    required String baristaId,
    required String paymentMethod,
    required double totalAmount,
    required double totalHpp,
    required double totalBonus,
    required double profit,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      
      final response = await _client.from('sales').insert({
        'outlet_id': outletId,
        'barista_id': baristaId,
        'payment_method': paymentMethod.toUpperCase(),
        'total_amount': totalAmount,
        'hpp_total': totalHpp,
        'bonus_amount': totalBonus,
        'profit': profit,
      });

      // Get the ID of the newly created sale by querying the latest one
      final latestSale = await _client
          .from('sales')
          .select('id')
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false)
          .limit(1);

      if (latestSale.isEmpty) {
        throw Exception('Could not retrieve created sale ID');
      }

      final saleId = latestSale[0]['id'] as String;

      // Insert sale items
      for (final item in items) {
        final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
        final hpp = (item['hpp'] as num?)?.toDouble() ?? 0.0;
        
        
        await _client.from('sale_items').insert({
          'sale_id': saleId,
          'product_id': item['product_id'],
          'quantity': item['quantity'],
          'price': price,
          'hpp': hpp,
        });
      }

      return saleId;
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  Future<List<Sale>> getSales({String? outletId, String? baristaId}) async {
    var query = _client.from('sales').select(
      'id, outlet_id, barista_id, payment_method, total_amount, hpp_total, bonus_amount, profit, created_at, is_edited, edited_at, sale_items(id, sale_id, product_id, quantity, price, hpp, created_at, products(name))',
    );

    if (outletId != null) {
      query = query.eq('outlet_id', outletId);
    }

    if (baristaId != null) {
      query = query.eq('barista_id', baristaId);
    }

    final response = await query.order('created_at', ascending: false);

    if ((response as List<dynamic>).isNotEmpty) {
      final firstRecord = response[0];
    }

    return (response as List<dynamic>)
        .map((item) => Sale.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Get monthly gratis transaction statistics
  Future<Map<String, int>> getMonthlyGratisStats({
    required String outletId,
    required DateTime monthStart,
  }) async {
    try {
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
      
      // Get all sales for this month
      final response = await _client
          .from('sales')
          .select('id, payment_method')
          .eq('outlet_id', outletId)
          .gte('created_at', monthStart.toIso8601String())
          .lte('created_at', monthEnd.toIso8601String());
      
      final salesList = response as List<dynamic>;
      final gratisCount = salesList
          .where((sale) => (sale['payment_method'] as String?)?.toUpperCase() == 'GRATIS')
          .length;
      
      return {
        'total': salesList.length,
        'gratis_count': gratisCount,
      };
    } catch (e) {
      return {'total': 0, 'gratis_count': 0};
    }
  }

  // Outlet
  Future<Outlet?> getOutlet(String outletId) async {
    try {
      final response = await _client
          .from('outlets')
          .select()
          .eq('id', outletId)
          .single();

      return Outlet.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Get barista assigned to a specific outlet.
  /// Web logic uses: /api/staff?role=barista then /api/outlets/${outletId}/baristas
  /// Mobile maps it to users table where role='barista' and outlet assignment column.
  ///
  /// NOTE: sesuai info user, kolom assignment outlet pada barista adalah `outlet_assigment`.
  Future<List<Map<String, dynamic>>> getBaristasByOutlet({
    required String outletId,
  }) async {
    if (!_isInitialized) return [];

    try {
      final response = await _client
          .from('users')
          .select('id, name, email, role, outlet_id')
          .eq('role', 'barista')
          .eq('outlet_id', outletId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Get all baristas (used for assignment availability if needed later).
  Future<List<Map<String, dynamic>>> getAllBaristas() async {
    if (!_isInitialized) return [];

    try {
      final response = await _client
          .from('users')
          .select('id, name, email, role, outlet_id')
          .eq('role', 'barista');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }


  // Leaderboard
  Future<List<Map<String, dynamic>>> getLeaderboard({
    required String outletId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!_isInitialized) {
      return [];
    }
    
    try {
      final response = await _client.rpc('get_barista_leaderboard', params: {
        'outlet_id': outletId,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      });

      return (response as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } catch (e) {
      return [];
    }
  }

// Global Leaderboard dari semua outlet
  Future<List<Map<String, dynamic>>> getGlobalLeaderboard({
    required String outletId,
    required DateTime selectedDate,
  }) async {
    if (!_isInitialized) {
      return [];
    }
    
    try {
      // Get outlet's business_day_start_hour
      final outletData = await _client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', outletId)
          .maybeSingle();
      
      if (outletData == null) {
        return [];
      }
      
      final businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;
      
      
      // Convert selectedDate to UTC first (it comes as local Jakarta time from DateTime.now())
      final selectedDateUtc = selectedDate.toUtc();
      
      // Calculate business day date range in UTC
      // Business day: starts at businessDayStartHour of PREVIOUS day, ends at businessDayStartHour of selectedDate - 1 second
      final startDate = DateTime.utc(selectedDateUtc.year, selectedDateUtc.month, selectedDateUtc.day)
          .subtract(const Duration(days: 1))
          .copyWith(hour: businessDayStartHour, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      final endDate = DateTime.utc(selectedDateUtc.year, selectedDateUtc.month, selectedDateUtc.day, businessDayStartHour, 0, 0)
          .subtract(const Duration(milliseconds: 1));
      
      
      final params = {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      };
      
      
      final response = await _client.rpc('get_global_leaderboard', params: params);

      
      return response
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } catch (e) {
      return [];
    }
  }

// Get product stock from product_batches table (like POS page)
  // Returns product stock with names - for displaying in stock screen
  Future<List<Map<String, dynamic>>> getProductBatchStock(String outletId) async {
    if (!_isInitialized) {
      return [];
    }
    
    try {
      
      // Get product batches - first without join to see if we have data
      final batchesResponse = await _client
          .from('product_batches')
          .select()
          .eq('outlet_id', outletId);


      if (batchesResponse.isEmpty) {
        return [];
      }

      // Get products separately to ensure we get all product data
      final productsResponse = await _client
          .from('products')
          .select();


      // Build product map for quick lookup
      final productMap = <String, Map<String, dynamic>>{};
      for (final product in productsResponse) {
        final productId = product['id'] as String?;
        if (productId != null) {
          productMap[productId] = product;
        }
      }

      // Get all sales data to calculate sold quantities per product
      final salesResponse = await _client
          .from('sale_items')
          .select('product_id, quantity');


      // Build a map of sold quantities by product
      final soldMap = <String, int>{};
      for (final item in salesResponse) {
        final productId = item['product_id'] as String?;
        if (productId == null) continue;
        final quantity = item['quantity'] as int? ?? 0;
        soldMap[productId] = (soldMap[productId] ?? 0) + quantity;
      }


      // Get batch damages (cacat & dikembalikan) - map by batch_id
      final damagesMap = <String, Map<String, int>>{};
      try {
        final damagesResponse = await _client
            .from('batch_damages')
            .select()
            .eq('outlet_id', outletId);


        // Build damage maps by batch_id
        for (final damage in damagesResponse) {
          final batchId = damage['batch_id'] as String?;
          if (batchId != null) {
            damagesMap[batchId] = {
              'cacat': damage['cacat_quantity'] as int? ?? 0,
              'dikembalikan': damage['dikembalikan_quantity'] as int? ?? 0,
            };
          }
        }
      } catch (e) {
        // If table doesn't exist, just use empty damages map
      }


      // Aggregate by product - include all statuses except expired
      final stockMap = <String, Map<String, dynamic>>{};
      for (final row in batchesResponse) {
        final status = row['status'] as String? ?? 'ready';
        final productId = row['product_id'] as String?;
        final batchId = row['id'] as String?;
        
        if (productId == null) {
          continue;
        }

        // Get product details
        final product = productMap[productId];
        final productName = product?['name'] as String? ?? 'Unknown Product';
        final price = product?['price'] as num? ?? 0;
        final hpp = product?['hpp'] as num? ?? 0;

        final quantity = row['quantity'] as int? ?? 0;
        final batchCode = row['batch_code'] as String? ?? '';

        // Get damages for this batch
        final batchDamages = damagesMap[batchId];
        final cacatQty = batchDamages?['cacat'] ?? 0;
        final dikembalikanQty = batchDamages?['dikembalikan'] ?? 0;


        // Skip only expired batches
        if (status == 'expired') {
          continue;
        }
        
        if (stockMap.containsKey(productId)) {
          // Update existing product
          final currentQty = stockMap[productId]!['quantity'] as int;
          final currentCacat = stockMap[productId]!['cacat'] as int;
          final currentDikembalikan = stockMap[productId]!['dikembalikan'] as int;
          stockMap[productId]!['quantity'] = currentQty + quantity;
          stockMap[productId]!['unsold'] = (stockMap[productId]!['unsold'] as int) + quantity;
          stockMap[productId]!['cacat'] = currentCacat + cacatQty;
          stockMap[productId]!['dikembalikan'] = currentDikembalikan + dikembalikanQty;
        } else {
          // Add new product
          stockMap[productId] = {
            'product_id': productId,
            'product_name': productName,
            'quantity': quantity,
            'price': price,
            'hpp': hpp,
            'sold': soldMap[productId] ?? 0,
            'unsold': quantity,
            'cacat': cacatQty,
            'dikembalikan': dikembalikanQty,
          };
        }
      }

      for (final entry in stockMap.entries) {
      }
      
      return stockMap.values.toList();
    } catch (e) {
      return [];
    }
  }

  // Get product stock (legacy method - returns Map for backward compatibility)
  // Calculate product stock at a specific date (historical stock)
  Future<Map<String, int>> getProductStockAtDate(String outletId, DateTime selectedDate) async {
    if (!_isInitialized) {
      return {};
    }
    
    try {
      // Get outlet's business_day_start_hour
      final outletData = await _client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', outletId)
          .maybeSingle();
      
      if (outletData == null) {
        return {};
      }
      
      final businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;

      // IMPORTANT: selectedDate comes as local time from DateTime.now() on device
      // Device is in UTC+7 (Indonesia), so we need to convert properly
      // 
      // Strategy: Work in UTC throughout to avoid confusion
      // 1. Take the local selectedDate and convert to UTC
      // 2. Calculate what the business day should be based on local time interpretation
      // 3. Since display says "business day starts at 21:00 local time", 
      //    we calculate based on wall-clock time in UTC+7, then convert to UTC for query
      
      // First, understand the device timezone offset
      // Dart's DateTime.now() is local time, and .toUtc() assumes device is in local timezone
      final nowLocal = DateTime.now();
      final nowUtc = nowLocal.toUtc();
      final deviceTimezoneOffset = nowLocal.difference(nowUtc);
      

      // selectedDate is in local time (what user sees on screen)
      // Business day calculation should be based on local wall-clock time
      // Check if current hour is at or after the business day start hour
      
      final year = selectedDate.year;
      final month = selectedDate.month;
      final day = selectedDate.day;
      final hour = selectedDate.hour;
      
      // Calculate business day start/end in LOCAL time
      DateTime businessDayStartLocal;
      DateTime businessDayEndLocal;
      
      if (hour >= businessDayStartHour) {
        // Current time is at or after business day start hour
        // So we're in TODAY's business day (start@hour today, end@hour tomorrow)
        businessDayStartLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
        businessDayEndLocal = DateTime(year, month, day + 1, businessDayStartHour, 0, 0);
      } else {
        // Current time is before business day start hour
        // So we're in YESTERDAY's business day (start@hour yesterday, end@hour today)
        businessDayStartLocal = DateTime(year, month, day - 1, businessDayStartHour, 0, 0);
        businessDayEndLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
      }
      
      // Subtract 1 millisecond from end to exclude the exact end time
      businessDayEndLocal = businessDayEndLocal.subtract(const Duration(milliseconds: 1));

      // Convert to UTC for database query
      // This is where the magic happens - .toUtc() assumes the DateTime is in device local timezone
      final businessDayStartUtc = businessDayStartLocal.toUtc();
      final businessDayEndUtc = businessDayEndLocal.toUtc();


      // Query: Get allocations created within the business day range (UTC)
      final currentResponse = await _client
          .from('showcase_allocations')
          .select('id, quantity, showcase_product_id, created_at')
          .eq('outlet_id', outletId)
          .gte('created_at', businessDayStartUtc.toIso8601String())
          .lte('created_at', businessDayEndUtc.toIso8601String());

      
      if ((currentResponse as List).isNotEmpty) {
        for (int i = 0; i < currentResponse.length && i < 5; i++) {
          final row = currentResponse[i];
          final allocTime = DateTime.parse(row['created_at'] as String);
          final allocTimeLocal = allocTime.toLocal();
        }
      }

      // Get all showcase products to map showcase_product_id -> product_id
      final showcaseProducts = await _client
          .from('showcase_products')
          .select('id, product_id');
      
      final showcaseProductMap = <String, String>{};
      for (final sp in showcaseProducts) {
        final id = sp['id'] as String?;
        final productId = sp['product_id'] as String?;
        if (id != null && productId != null) {
          showcaseProductMap[id] = productId;
        }
      }

      // Aggregate quantities by product_id
      final stockMap = <String, int>{};
      for (final row in currentResponse) {
        final quantity = row['quantity'] as int? ?? 0;
        final showcaseProductId = row['showcase_product_id'] as String?;
        
        if (showcaseProductId != null && showcaseProductMap.containsKey(showcaseProductId)) {
          final productId = showcaseProductMap[showcaseProductId]!;
          stockMap[productId] = (stockMap[productId] ?? 0) + quantity;
        }
      }
      
      if (stockMap.isEmpty) {
        return {};
      }

      for (final entry in stockMap.entries) {
      }
      return stockMap;
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, int>> getProductStock(String outletId, {DateTime? selectedDate}) async {
    if (!_isInitialized) {
      return {};
    }
    
    // If selectedDate is provided, use historical stock calculation
    if (selectedDate != null) {
      return getProductStockAtDate(outletId, selectedDate);
    }
    
    try {
      // Query current stock from showcase_allocations with showcase_product mapping
      final response = await _client
          .from('showcase_allocations')
          .select('quantity, showcase_product_id')
          .eq('outlet_id', outletId);

      // Get all showcase products to map showcase_product_id -> product_id
      final showcaseProducts = await _client
          .from('showcase_products')
          .select('id, product_id');
      
      final showcaseProductMap = <String, String>{};
      for (final sp in showcaseProducts) {
        final id = sp['id'] as String?;
        final productId = sp['product_id'] as String?;
        if (id != null && productId != null) {
          showcaseProductMap[id] = productId;
        }
      }

      // Build stock map keyed by product_id
      final stockMap = <String, int>{};
      for (final row in response) {
        final quantity = row['quantity'] as int? ?? 0;
        final showcaseProductId = row['showcase_product_id'] as String?;
        
        if (showcaseProductId != null && showcaseProductMap.containsKey(showcaseProductId)) {
          final productId = showcaseProductMap[showcaseProductId]!;
          stockMap[productId] = (stockMap[productId] ?? 0) + quantity;
        }
      }
      
      return stockMap;
    } catch (e) {
      return {};
    }
  }

  // Decrease showcase allocation when product is sold
  Future<void> decreaseShowcaseAllocation({
    required String outletId,
    required String productId,
    required int quantitySold,
  }) async {
    if (!_isInitialized) {
      return;
    }

    try {
      // Get current allocation from showcase_products for this outlet + product
      final response = await _client
          .from('showcase_allocations')
          .select('id, quantity')
          .eq('outlet_id', outletId)
          .match({
            'showcase_products': {
              'product_id': productId
            }
          });

      // If no direct match, try a simpler query using showcase_products join
      if (response.isEmpty) {
        // First get the showcase_product id for this product
        final showcaseProduct = await _client
            .from('showcase_products')
            .select('id')
            .eq('product_id', productId)
            .maybeSingle();

        if (showcaseProduct == null) {
          return;
        }

        final showcaseProductId = showcaseProduct['id'] as String;

        // Now get the allocation
        final allocation = await _client
            .from('showcase_allocations')
            .select('id, quantity')
            .eq('outlet_id', outletId)
            .eq('showcase_product_id', showcaseProductId)
            .maybeSingle();

        if (allocation != null) {
          final currentQty = allocation['quantity'] as int? ?? 0;
          final newQty = (currentQty - quantitySold).clamp(0, currentQty);
          
          await _client
              .from('showcase_allocations')
              .update({'quantity': newQty})
              .eq('id', allocation['id']);
          
        }
      } else if (response.isNotEmpty) {
        final allocation = response.first;
        final currentQty = allocation['quantity'] as int? ?? 0;
        final newQty = (currentQty - quantitySold).clamp(0, currentQty);
        
        await _client
            .from('showcase_allocations')
            .update({'quantity': newQty})
            .eq('id', allocation['id']);
        
      }
    } catch (e) {
      // Don't fail checkout if this fails
    }
  }

  // Get sold quantity per product for today (based on business day)
  Future<Map<String, int>> getSoldQuantityToday({
    required String outletId,
    required DateTime selectedDate,
  }) async {
    if (!_isInitialized) {
      return {};
    }

    try {
      // Get outlet's business_day_start_hour
      final outletData = await _client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', outletId)
          .maybeSingle();

      if (outletData == null) {
        return {};
      }

      final businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;

      // selectedDate comes as LOCAL time from DateTime.now() on device
      // Calculate business day in LOCAL time first, then convert to UTC for query
      final year = selectedDate.year;
      final month = selectedDate.month;
      final day = selectedDate.day;
      
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

      // Convert to UTC for database query
      final dailyStart = businessDayStartLocal.toUtc();
      final dailyEnd = businessDayEndLocal.toUtc();


      // Query sales for this outlet on this business day
      final salesResponse = await _client
          .from('sales')
          .select('id, created_at')
          .eq('outlet_id', outletId)
          .gte('created_at', dailyStart.toIso8601String())
          .lte('created_at', dailyEnd.toIso8601String());

      if (salesResponse.isEmpty) {
        return {};
      }

      // Collect all sale IDs
      final saleIds = (salesResponse as List).map((s) => s['id'] as String).toList();

      // Query sale_items to get product quantities
      final itemsResponse = await _client
          .from('sale_items')
          .select('product_id, quantity')
          .inFilter('sale_id', saleIds);

      // Build sold map keyed by product_id
      final soldMap = <String, int>{};
      for (final item in itemsResponse) {
        final productId = item['product_id'] as String?;
        final quantity = item['quantity'] as int? ?? 0;

        if (productId != null) {
          soldMap[productId] = (soldMap[productId] ?? 0) + quantity;
        }
      }

      return soldMap;
    } catch (e) {
      return {};
    }
  }

  // Get returned quantity per product for today (based on business day)
  Future<Map<String, int>> getReturnedQuantityToday({
    required String outletId,
    required DateTime selectedDate,
  }) async {
    if (!_isInitialized) {
      return {};
    }

    try {
      // Get outlet's business_day_start_hour
      final outletData = await _client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', outletId)
          .maybeSingle();

      if (outletData == null) {
        return {};
      }

      final businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;

      // selectedDate comes as LOCAL time from DateTime.now() on device
      // Calculate business day in LOCAL time first, then convert to UTC for query
      final year = selectedDate.year;
      final month = selectedDate.month;
      final day = selectedDate.day;
      
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

      // Convert to UTC for database query
      final dailyStart = businessDayStartLocal.toUtc();
      final dailyEnd = businessDayEndLocal.toUtc();


      // Query product_returns for this outlet on this business day
      final returnsResponse = await _client
          .from('product_returns')
          .select('product_id')
          .eq('outlet_id', outletId)
          .gte('return_date', dailyStart.toIso8601String())
          .lte('return_date', dailyEnd.toIso8601String());

      if (returnsResponse.isEmpty) {
        return {};
      }

      // Build returned map - count occurrences of each product_id
      final returnedMap = <String, int>{};
      for (final item in returnsResponse) {
        final productId = item['product_id'] as String?;

        if (productId != null) {
          returnedMap[productId] = (returnedMap[productId] ?? 0) + 1;
        }
      }

      return returnedMap;
    } catch (e) {
      return {};
    }
  }

  // Get transfer statistics per product for today (transfers sent and received)
  Future<Map<String, Map<String, int>>> getProductTransferStats({
    required String outletId,
    required DateTime selectedDate,
  }) async {
    if (!_isInitialized) {
      return {};
    }

    try {
      // Get outlet's business_day_start_hour
      final outletData = await _client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', outletId)
          .maybeSingle();

      if (outletData == null) {
        return {};
      }

      final businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;

      // selectedDate comes as LOCAL time from DateTime.now() on device
      // Calculate business day in LOCAL time first, then convert to UTC for query
      final year = selectedDate.year;
      final month = selectedDate.month;
      final day = selectedDate.day;
      
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

      // Convert to UTC for database query
      final dailyStart = businessDayStartLocal.toUtc();
      final dailyEnd = businessDayEndLocal.toUtc();


      // Initialize transfer stats map
      final transferStats = <String, Map<String, int>>{};

      // Get SENT transfers (from_outlet_id == this outlet)
      final sentResponse = await _client
          .from('stock_transfers')
          .select('id, created_at')
          .eq('from_outlet_id', outletId)
          .gte('created_at', dailyStart.toIso8601String())
          .lte('created_at', dailyEnd.toIso8601String());


      if (sentResponse.isNotEmpty) {
        final sentTransferIds = (sentResponse as List).map((s) => s['id'] as String).toList();
        
        // Get items from sent transfers
        final sentItemsResponse = await _client
            .from('stock_transfer_items')
            .select('product_id, quantity_int')
            .inFilter('transfer_id', sentTransferIds);

        for (final item in sentItemsResponse) {
          final productId = item['product_id'] as String?;
          final quantity = item['quantity_int'] as int? ?? 0;

          if (productId != null) {
            if (!transferStats.containsKey(productId)) {
              transferStats[productId] = {'dikirim': 0, 'diterima': 0};
            }
            transferStats[productId]!['dikirim'] = (transferStats[productId]!['dikirim'] ?? 0) + quantity;
          }
        }
      }

      // Get RECEIVED transfers (to_outlet_id == this outlet)
      final receivedResponse = await _client
          .from('stock_transfers')
          .select('id, created_at')
          .eq('to_outlet_id', outletId)
          .gte('created_at', dailyStart.toIso8601String())
          .lte('created_at', dailyEnd.toIso8601String());


      if (receivedResponse.isNotEmpty) {
        final receivedTransferIds = (receivedResponse as List).map((s) => s['id'] as String).toList();
        
        // Get items from received transfers
        final receivedItemsResponse = await _client
            .from('stock_transfer_items')
            .select('product_id, quantity_int')
            .inFilter('transfer_id', receivedTransferIds);

        for (final item in receivedItemsResponse) {
          final productId = item['product_id'] as String?;
          final quantity = item['quantity_int'] as int? ?? 0;

          if (productId != null) {
            if (!transferStats.containsKey(productId)) {
              transferStats[productId] = {'dikirim': 0, 'diterima': 0};
            }
            transferStats[productId]!['diterima'] = (transferStats[productId]!['diterima'] ?? 0) + quantity;
          }
        }
      }

      return transferStats;
    } catch (e) {
      return {};
    }
  }

  // Get stock transfers for an outlet
  Future<List<StockTransfer>> getStockTransfers(String outletId) async {
    if (!_isInitialized) {
      return [];
    }
    
    try {
      final response = await _client
          .from('stock_transfers')
          .select('*, stock_transfer_items(*), outlets!inner(name)')
          .or('from_outlet_id.eq.$outletId,to_outlet_id.eq.$outletId')
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => StockTransfer.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get user profile
  Future<user_model.User> getUserProfile(String userId) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }
    
    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    return user_model.User.fromJson(response);
  }

  // Create stock transfer
  Future<String?> createStockTransfer({
    required String fromOutletId,
    required String toOutletId,
    required List<Map<String, dynamic>> items,
  }) async {
    if (!_isInitialized) {
      return null;
    }
    
    try {
      await _client
          .from('stock_transfers')
          .insert({
            'from_outlet_id': fromOutletId,
            'to_outlet_id': toOutletId,
            'status': 'requested',
          });

      // Get the ID of the newly created transfer by querying the latest one
      final latestTransfer = await _client
          .from('stock_transfers')
          .select('id')
          .eq('from_outlet_id', fromOutletId)
          .eq('to_outlet_id', toOutletId)
          .order('created_at', ascending: false)
          .limit(1);

      if (latestTransfer.isEmpty) {
        throw Exception('Could not retrieve created transfer ID');
      }

      final transferId = latestTransfer[0]['id'];
      for (final item in items) {
        await _client.from('stock_transfer_items').insert({
          'transfer_id': transferId,
          'ingredient_id': item['ingredient_id'],
          'quantity': item['quantity'],
        });
      }
      return transferId;
    } catch (e) {
      return null;
    }
  }

  // Create stock return
  Future<String?> createStockReturn({
    required String outletId,
    required String ingredientId,
    required double quantity,
    required String reason,
  }) async {
    if (!_isInitialized) {
      return null;
    }
    
    try {
      await _client
          .from('stock_returns')
          .insert({
            'outlet_id': outletId,
            'ingredient_id': ingredientId,
            'quantity': quantity,
            'reason': reason,
            'status': 'pending',
          });

      // Get the ID of the newly created return by querying the latest one
      final latestReturn = await _client
          .from('stock_returns')
          .select('id')
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false)
          .limit(1);

      if (latestReturn.isEmpty) {
        throw Exception('Could not retrieve created return ID');
      }

      return latestReturn[0]['id'];
    } catch (e) {
      return null;
    }
  }

  // DEBUG: Seed sample product batches for development
  Future<void> seedSampleProductBatches(String outletId) async {
    if (!_isInitialized) {
      return;
    }

    try {
      
      // Get all products
      final productsResponse = await _client
          .from('products')
          .select('id, name')
          .limit(5);

      if (productsResponse.isEmpty) {
        return;
      }

      // Delete existing batches for this outlet first
      await _client
          .from('product_batches')
          .delete()
          .eq('outlet_id', outletId);

      // Insert sample batches
      for (int i = 0; i < productsResponse.length; i++) {
        final product = productsResponse[i];
        final productId = product['id'] as String;
        final productName = product['name'] as String;
        
        await _client
            .from('product_batches')
            .insert({
              'batch_code': 'BATCH-${DateTime.now().millisecondsSinceEpoch}-$i',
              'product_id': productId,
              'quantity': 50 + (i * 10),
              'production_date': DateTime.now().toIso8601String().split('T')[0],
              'expired_date': DateTime.now().add(Duration(days: 30)).toIso8601String().split('T')[0],
              'status': 'ready',
              'outlet_id': outletId,
              'notes': 'Sample batch for $productName',
            });

      }

    } catch (e) {
    }
  }

  // Add or update batch damage record (cacat/dikembalikan)
  Future<bool> addBatchDamage({
    required String batchId,
    required String outletId,
    required int cacatQty,
    required int dikembalikanQty,
    required String userId,
    String reason = '',
    String notes = '',
  }) async {
    if (!_isInitialized) {
      return false;
    }

    try {

      // Check if damage record already exists for this batch
      final existingResponse = await _client
          .from('batch_damages')
          .select()
          .eq('batch_id', batchId)
          .eq('outlet_id', outletId)
          .limit(1);

      if (existingResponse.isNotEmpty) {
        // Update existing record
        final existingId = existingResponse[0]['id'] as String;
        await _client
            .from('batch_damages')
            .update({
              'cacat_quantity': cacatQty,
              'dikembalikan_quantity': dikembalikanQty,
              'reason': reason,
              'notes': notes,
            })
            .eq('id', existingId);

      } else {
        // Create new record
        await _client
            .from('batch_damages')
            .insert({
              'batch_id': batchId,
              'outlet_id': outletId,
              'cacat_quantity': cacatQty,
              'dikembalikan_quantity': dikembalikanQty,
              'reason': reason,
              'notes': notes,
              'created_by': userId,
            });

      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get batch damage record by batch ID
  Future<Map<String, dynamic>?> getBatchDamage(String batchId, String outletId) async {
    if (!_isInitialized) {
      return null;
    }

    try {
      final response = await _client
          .from('batch_damages')
          .select()
          .eq('batch_id', batchId)
          .eq('outlet_id', outletId)
          .limit(1);

      if (response.isEmpty) {
        return null;
      }

      return response[0];
    } catch (e) {
      return null;
    }
  }

  // Investor assignments: ambil outlet aktif milik investor
  // NOTE: Hindari join outlets!inner supaya REST/alias relasi tidak bergantung pada konfigurasi FK/RLS.
  Future<List<Outlet>> getActiveInvestorOutlets({
    required String investorId,
  }) async {
    if (!_isInitialized) {
      return [];
    }

    try {
      final response = await _client
          .from('investor_assignments')
          .select('outlet_id')
          .eq('investor_id', investorId)
          .eq('status', 'active');

      final rows = response as List<dynamic>;
      final outletIds = rows
          .map((r) => r['outlet_id']?.toString())
          .whereType<String>()
          .toList();

      final outlets = <Outlet>[];
      for (final outletId in outletIds) {
        final outlet = await getOutlet(outletId);
        if (outlet != null) {
          outlets.add(outlet);
        }
      }

      return outlets;
    } catch (e) {
      return [];
    }
  }

  /// Enhanced investor outlet summary (match web dashboard logic)
  ///
  /// Equivalent logic:
  /// - Fetch investor_assignments (all for investor)
  /// - Fetch outlets by ids
  /// - Fetch sales profit for last 30 days
  /// - Compute investor_share = outlet_profit * margin_percentage / 100
  Future<List<Map<String, dynamic>>> getInvestorOutletsSummary({
    required String investorId,
    int profitTrendDays = 30,
  }) async {
    if (!_isInitialized) {
      return [];
    }

    try {
      // Gunakan investorId dari caller (AuthProvider biasanya sudah melakukan remap id untuk role investor)
      // Hindari override dengan session.user.id karena bisa menyebabkan mismatch
      // antara id auth user vs id investor yang dipakai oleh tabel investor_assignments.
      final effectiveInvestorId = investorId.trim();


      final endIso = DateTime.now().toUtc().toIso8601String();
      final startIso = DateTime.now()
          .toUtc()
          .subtract(Duration(days: profitTrendDays))
          .toIso8601String();


      // 1) Fetch assignments (field spesifik seperti web)
      final assignmentsResponse = await _client
          .from('investor_assignments')
          .select('outlet_id, investment_amount, margin_percentage, status')
          .eq('investor_id', effectiveInvestorId);

      final assignmentsRows = (assignmentsResponse as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();

      if (assignmentsRows.isNotEmpty) {
      }

      if (assignmentsRows.isEmpty) {
        return [];
      }

      final outletIds = assignmentsRows
          .map((a) => (a['outlet_id'] as String?)?.trim())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();


      if (outletIds.isEmpty) {
        return [];
      }

      // 2) Fetch outlets by ids
      final outletResponse = await _client
          .from('outlets')
          .select('id, name')
          .inFilter('id', outletIds);

      final outletRows = (outletResponse as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();

      if (outletRows.isNotEmpty) {
      }

      final outletMap = <String, Map<String, dynamic>>{
        for (final o in outletRows)
          (o['id'] as String): o,
      };

      // 3) Aggregate sales profit for those outlets
      final salesResponse = await _client
          .from('sales')
          .select('outlet_id, profit')
          .inFilter('outlet_id', outletIds)
          .gte('created_at', startIso)
          .lte('created_at', endIso);

      final salesRows = (salesResponse as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();


      final profitMap = <String, double>{};
      for (final sale in salesRows) {
        final outletId = (sale['outlet_id'] as String?)?.trim();
        if (outletId == null || outletId.isEmpty) continue;

        final profit = (sale['profit'] as num?)?.toDouble() ?? 0.0;
        profitMap[outletId] = (profitMap[outletId] ?? 0.0) + profit;
      }

      // 4) Build summary per assignment row
      return assignmentsRows.map((assignment) {
        final outletId = (assignment['outlet_id'] as String?)?.trim() ?? '';
        final outlet = outletMap[outletId];
        final outletProfit = profitMap[outletId] ?? 0.0;

        final investmentAmount =
            (assignment['investment_amount'] as num?)?.toDouble() ?? 0.0;
        final marginPercentage =
            (assignment['margin_percentage'] as num?)?.toDouble() ?? 0.0;

        final investorShare = outletProfit * marginPercentage / 100.0;
        final status = (assignment['status'] as String?) ?? 'unknown';

        return <String, dynamic>{
          'outlet_id': outletId,
          'outlet_name': outlet?['name'] ?? 'Unknown',
          'investment_amount': investmentAmount,
          'margin_percentage': marginPercentage,
          'outlet_profit': outletProfit,
          'investor_share': investorShare,
          'status': status,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Fetch investor assignments with outlet details
  Future<List<Map<String, dynamic>>> getInvestorAssignments({
    required String investorId,
  }) async {
    if (!_isInitialized) {
      return [];
    }

    try {
      final effectiveInvestorId = investorId.trim();

      // First, verify investor exists in system
      try {
        final userData = await _client
            .from('users')
            .select('id, email, role')
            .eq('id', effectiveInvestorId)
            .maybeSingle();
        
        if (userData != null) {
        } else {
        }
      } catch (e) {
      }

      // Query investor_assignments with direct outlet join
      
      List<Map<String, dynamic>> response;
      try {
        // Try with outlet join first
        response = await _client
            .from('investor_assignments')
            .select('id, outlet_id, investment_amount, margin_percentage, status, created_at, outlets(id, name, type, address)')
            .eq('investor_id', effectiveInvestorId)
            .order('created_at', ascending: false);
      } catch (joinError) {
        // Fallback: query without join
        response = await _client
            .from('investor_assignments')
            .select('id, outlet_id, investment_amount, margin_percentage, status, created_at')
            .eq('investor_id', effectiveInvestorId)
            .order('created_at', ascending: false);
      }


      final assignmentRows = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();

      if (assignmentRows.isNotEmpty) {
      } else {
        
        // Fallback: Check all investor_ids in the table for debugging
        try {
          final allAssignments = await _client
              .from('investor_assignments')
              .select('investor_id')
              .limit(5);
          
          final uniqueIds = <String>{};
          (allAssignments as List<dynamic>?)?.forEach((row) {
            final id = (row as Map<String, dynamic>)['investor_id'] as String?;
            if (id != null) uniqueIds.add(id);
          });
          
          
          // If we found investor_ids in database, query with first one for dev testing
          if (uniqueIds.isNotEmpty) {
            final firstInvestorId = uniqueIds.first;
            
            final devResponse = await _client
                .from('investor_assignments')
                .select('id, outlet_id, investment_amount, margin_percentage, status, created_at')
                .eq('investor_id', firstInvestorId)
                .order('created_at', ascending: false);
            
            final devRows = (devResponse as List<dynamic>)
                .whereType<Map<String, dynamic>>()
                .toList();
            
            
            if (devRows.isNotEmpty) {
              return devRows.map((assignment) {
                return <String, dynamic>{
                  ...assignment,
                  'outlet_name': 'Test Outlet (Dev)',
                  'outlet_type': 'dev_test',
                  'outlet_address': 'Development Testing',
                };
              }).toList();
            }
          }
        } catch (e) {
        }
      }

      if (assignmentRows.isEmpty) {
        return [];
      }

      // For each assignment, fetch outlet data if not in join
      final enrichedAssignments = <Map<String, dynamic>>[];
      
      for (final assignment in assignmentRows) {
        final outletId = (assignment['outlet_id'] as String?)?.trim() ?? '';
        var outlet = assignment['outlets'] as Map<String, dynamic>?;
        
        // If outlet data not in join, fetch it separately
        if (outlet == null || outlet.isEmpty) {
          try {
            final outletData = await _client
                .from('outlets')
                .select('id, name, type, address')
                .eq('id', outletId)
                .maybeSingle();
            
            if (outletData != null) {
              outlet = outletData;
            }
          } catch (e) {
          }
        }


        enrichedAssignments.add(<String, dynamic>{
          ...assignment,
          'outlet_name': outlet?['name'] ?? 'Unknown Outlet',
          'outlet_type': outlet?['type'] ?? 'unknown',
          'outlet_address': outlet?['address'] ?? '',
        });
      }
      
      return enrichedAssignments;
    } catch (e) {
      return [];
    }
  }

  // Get all outlets
  Future<List<Map<String, dynamic>>> getOutlets() async {

    if (!_isInitialized) {
      return [];
    }

    try {
      final response = await _client
          .from('outlets')
          .select('id, name, business_day_start_hour')
          .order('name', ascending: true);

      print('[SupabaseService] getOutlets() - Total outlets: ${(response as List).length}');
      for (final outlet in response as List) {
        print('  - ${outlet['name']} (id: ${outlet['id']})');
      }
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('[SupabaseService] Error in getOutlets(): $e');
      return [];
    }
  }

  // Get stock returns for an outlet
  Future<List<Map<String, dynamic>>> getStockReturns(String outletId) async {
    if (!_isInitialized) {
      return [];
    }

    try {
      final response = await _client
          .from('stock_returns')
          .select('*, products(name)')
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false);

      
      // Map product name into response
      final returns = response.map((item) {
        return {
          ...item,
          'product_name': item['products']?['name'] ?? 'Unknown',
        };
      }).toList();

      return List<Map<String, dynamic>>.from(returns);
    } catch (e) {
      return [];
    }
  }

  // Get product returns (pengembalian) for an outlet
  Future<List<Map<String, dynamic>>> getProductReturns(String outletId, {DateTime? selectedDate}) async {
    if (!_isInitialized) {
      return [];
    }

    try {
      // Get outlet's business_day_start_hour if filtering by date
      int businessDayStartHour = 4; // default
      if (selectedDate != null) {
        try {
          final outletData = await _client
              .from('outlets')
              .select('business_day_start_hour')
              .eq('id', outletId)
              .maybeSingle();
          if (outletData != null) {
            businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;
          }
        } catch (e) {
        }
      }

      // Build query
      var query = _client
          .from('product_returns')
          .select('*')
          .eq('outlet_id', outletId);

      // Add date filter if provided
      if (selectedDate != null) {
        final selectedDateUtc = selectedDate.toUtc();
        final dailyStart = DateTime.utc(selectedDateUtc.year, selectedDateUtc.month, selectedDateUtc.day)
            .subtract(const Duration(days: 1))
            .copyWith(hour: businessDayStartHour, minute: 0, second: 0, millisecond: 0, microsecond: 0);
        final dailyEnd = DateTime.utc(selectedDateUtc.year, selectedDateUtc.month, selectedDateUtc.day, businessDayStartHour, 0, 0)
            .subtract(const Duration(milliseconds: 1));
        
        query = query
            .gte('return_date', dailyStart.toIso8601String())
            .lte('return_date', dailyEnd.toIso8601String());
      }

      final response = await query.order('return_date', ascending: false);

      if (response.isEmpty) {
        return [];
      }

      
      // Get all products to enrich with product names
      final products = await getProducts();
      final productMap = {for (var p in products) p.id: p.name};

      // Map product name into response
      final returns = (response as List).map((item) {
        final itemMap = Map<String, dynamic>.from(item as Map);
        final productId = itemMap['product_id'] as String?;
        final productName = productId != null ? productMap[productId] : null;
        
        return {
          ...itemMap,
          'product_name': productName ?? 'Unknown',
        };
      }).toList();

      return List<Map<String, dynamic>>.from(returns);
    } catch (e) {
      return [];
    }
  }

  // Create product return record
  Future<bool> createProductReturn({
    required String outletId,
    required String productId,
    required int quantity,
    required String returnReason,
    String? conditionNotes,
  }) async {
    if (!_isInitialized) {
      return false;
    }

    try {

      // Create product_returns records (one per unit returned)
      // Condition status must be one of: 'sellable', 'damaged', 'partially_damaged'
      // Default to 'damaged' for returns - can be changed during inspection
      final returnData = List.generate(
        quantity,
        (index) => {
          'product_id': productId,
          'outlet_id': outletId,
          'return_reason': returnReason,
          'condition_status': 'damaged', // Valid constraint value
          'condition_notes': conditionNotes,
          'return_date': DateTime.now().toIso8601String(),
        },
      );

      await _client.from('product_returns').insert(returnData);

      return true;
    } catch (e) {
      return false;
    }
  }

  // Create product transfer between outlets
  Future<bool> createProductTransfer({
    required String fromOutletId,
    required String toOutletId,
    required String productId,
    required int quantity,
    DateTime? selectedDate,
  }) async {
    if (!_isInitialized) {
      return false;
    }

    try {

      // Step 0: Get showcase_allocation for source outlet to find showcase_product_id
      try {
        // First, get the showcase_product_id from showcase_products table
        final showcaseProducts = await _client
            .from('showcase_products')
            .select('id')
            .eq('product_id', productId);
        
        
        if (showcaseProducts.isEmpty) {
          return false;
        }

        // If multiple, just use the first one
        final showcaseProductId = showcaseProducts[0]['id'] as String;

        // Now query showcase_allocations using showcase_product_id
        final allocations = await _client
            .from('showcase_allocations')
            .select('id, quantity, showcase_product_id')
            .eq('outlet_id', fromOutletId)
            .eq('showcase_product_id', showcaseProductId)
            .limit(1);

        if (allocations.isEmpty) {
          return false;
        }

        final sourceAllocation = allocations[0] as Map<String, dynamic>;
        final currentQty = sourceAllocation['quantity'] as int? ?? 0;
        
        // Calculate "sisa" (remaining stock) using the same formula as UI:
        // sisa = quantity - sold - returned - dikirim + diterima
        final checkDate = selectedDate ?? DateTime.now();
        final soldMap = await getSoldQuantityToday(outletId: fromOutletId, selectedDate: checkDate);
        final returnedMap = await getReturnedQuantityToday(outletId: fromOutletId, selectedDate: checkDate);
        final transferStats = await getProductTransferStats(outletId: fromOutletId, selectedDate: checkDate);
        
        final sold = soldMap[productId] ?? 0;
        final returned = returnedMap[productId] ?? 0;
        final transfers = transferStats[productId] ?? {'dikirim': 0, 'diterima': 0};
        final dikirim = (transfers['dikirim'] ?? 0) as num;
        final diterima = (transfers['diterima'] ?? 0) as num;
        final sisa = currentQty - sold - returned - dikirim.toInt() + diterima.toInt();
        
        
        if (sisa < quantity) {
          return false;
        }


        // Step 1: DON'T decrease quantity yet - only check availability
        // Quantity will be decreased when transfer is approved

        // Step 2: DO NOT update destination outlet quantity - only update when approved


        // Step 3: Create transfer record with 'requested' status (awaiting approval)
        try {
          // Don't use .select() here to avoid "single row" issues
          // Just insert without returning data, then query it
          try {
            await _client
                .from('stock_transfers')
                .insert({
                  'from_outlet_id': fromOutletId,
                  'to_outlet_id': toOutletId,
                  'status': 'requested',
                  // Let database set created_at to ensure correct server time
                });
            
          } catch (insertError) {
            throw insertError;
          }
          
          // Get the ID of the newly created transfer by querying the latest one
          try {
            final transferQuery = await _client
                .from('stock_transfers')
                .select('id')
                .eq('from_outlet_id', fromOutletId)
                .eq('to_outlet_id', toOutletId)
                .eq('status', 'requested')
                .order('created_at', ascending: false)
                .limit(1);
            
            if (transferQuery.isEmpty) {
              return false;
            }
            
            final transferId = transferQuery[0]['id'] as String;
            
            // Insert transfer item details
            try {
              
              // Just insert without .select() to avoid "single row" issues
              try {
                await _client
                    .from('stock_transfer_items')
                    .insert({
                      'transfer_id': transferId,
                      'product_id': productId,
                      'quantity': quantity.toDouble(), // Fill the DECIMAL quantity column
                      'quantity_int': quantity, // Also fill quantity_int for integer reference
                      'created_at': DateTime.now().toIso8601String(),
                    });
                
              } catch (itemInsertError) {
                throw itemInsertError;
              }
            } catch (itemError) {
              throw itemError;
            }
          } catch (queryError) {
            throw queryError;
          }
        } catch (e) {
          throw e;
        }
      } catch (allocError) {
        throw allocError;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get product transfers for an outlet
  Future<List<Map<String, dynamic>>> getProductTransfers(String outletId, {DateTime? selectedDate}) async {
    if (!_isInitialized) {
      return [];
    }

    try {
      
      // Get outlet's business_day_start_hour if filtering by date
      int businessDayStartHour = 4; // default
      if (selectedDate != null) {
        try {
          final outletData = await _client
              .from('outlets')
              .select('business_day_start_hour')
              .eq('id', outletId)
              .maybeSingle();
          if (outletData != null) {
            businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;
          }
        } catch (e) {
        }
      }
      
      // Build query
      var query = _client
          .from('stock_transfers')
          .select('''
            id,
            from_outlet_id,
            to_outlet_id,
            status,
            created_at
          ''')
          .or('from_outlet_id.eq.$outletId,to_outlet_id.eq.$outletId');

      // Filter by selected date (business day) if provided
      if (selectedDate != null) {
        final year = selectedDate.year;
        final month = selectedDate.month;
        final day = selectedDate.day;
        
        final dailyStart = DateTime.utc(year, month, day, businessDayStartHour, 0, 0);
        final dailyEnd = DateTime.utc(year, month, day + 1, businessDayStartHour, 0, 0).subtract(const Duration(seconds: 1));
        
        query = query
            .gte('created_at', dailyStart.toIso8601String())
            .lte('created_at', dailyEnd.toIso8601String());
      } else {
      }
      
      final response = await query.order('created_at', ascending: false);

      for (final t in response) {
      }

      // Enrich with outlet names and product names
      final enrichedTransfers = <Map<String, dynamic>>[];
      
      for (final transfer in response) {
        try {
          
          // Step 1: Get outlet names
          late final String fromName;
          late final String toName;
          try {
            final fromOutlet = await _client
                .from('outlets')
                .select('name')
                .eq('id', transfer['from_outlet_id'])
                .maybeSingle();
            fromName = (fromOutlet?['name'] as String?) ?? 'Unknown';
            
            final toOutlet = await _client
                .from('outlets')
                .select('name')
                .eq('id', transfer['to_outlet_id'])
                .maybeSingle();
            toName = (toOutlet?['name'] as String?) ?? 'Unknown';
          } catch (e) {
            continue;
          }
          
          // Step 2: Get transfer items
          late final List<dynamic> itemsResponse;
          try {
            itemsResponse = await _client
                .from('stock_transfer_items')
                .select('product_id, quantity_int')
                .eq('transfer_id', transfer['id']);
          } catch (e) {
            continue;
          }
          
          
          if (itemsResponse.isNotEmpty) {
            final firstItem = itemsResponse[0];
            
            final productId = firstItem['product_id'] as String?;
            final quantity = firstItem['quantity_int'] as int? ?? 0;
            
            
            if (productId != null) {
              // Step 3: Get product name
              late final String productName;
              try {
                final product = await _client
                    .from('products')
                    .select('name')
                    .eq('id', productId)
                    .maybeSingle();
                productName = (product?['name'] as String?) ?? 'Unknown';
              } catch (e) {
                continue;
              }
              
              // Step 4: Get showcase_product_id for current stock lookup
              int currentStockSending = 0;
              try {
                final showcaseProduct = await _client
                    .from('showcase_products')
                    .select('id')
                    .eq('product_id', productId)
                    .limit(1);
                
                if (showcaseProduct.isNotEmpty) {
                  final showcaseProductId = showcaseProduct[0]['id'] as String;
                  
                  // Step 5: Get current stock
                  try {
                    final sendingOutletStockList = await _client
                        .from('showcase_allocations')
                        .select('quantity')
                        .eq('outlet_id', transfer['from_outlet_id'])
                        .eq('showcase_product_id', showcaseProductId)
                        .limit(1)
                        .order('created_at', ascending: false);
                    
                    if (sendingOutletStockList.isNotEmpty) {
                      currentStockSending = (sendingOutletStockList[0]['quantity'] as int?) ?? 0;
                    }
                  } catch (e) {
                    currentStockSending = 0;
                  }
                }
              } catch (e) {
              }
              
              final enrichedTransfer = {
                'id': transfer['id'],
                'from_outlet_id': transfer['from_outlet_id'],
                'to_outlet_id': transfer['to_outlet_id'],
                'from_outlet_name': fromName,
                'to_outlet_name': toName,
                'product_id': productId,
                'product_name': productName,
                'quantity': quantity,
                'current_stock_at_sending_outlet': currentStockSending,
                'status': transfer['status'] ?? 'received',
                'created_at': transfer['created_at'],
              };
              
              enrichedTransfers.add(enrichedTransfer);
            }
          } else {
          }
        } catch (e) {
        }
      }
      
      for (final t in enrichedTransfers) {
      }
      return enrichedTransfers;
    } catch (e) {
      return [];
    }
  }

  /// Get transfers RECEIVED by this outlet (transfers where to_outlet_id == outletId)
  Future<List<Map<String, dynamic>>> getReceivedTransfers(String outletId, {DateTime? selectedDate}) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      
      // Get outlet's business_day_start_hour if filtering by date
      int businessDayStartHour = 4; // default
      if (selectedDate != null) {
        try {
          final outletData = await _client
              .from('outlets')
              .select('business_day_start_hour')
              .eq('id', outletId)
              .maybeSingle();
          if (outletData != null) {
            businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;
          }
        } catch (e) {
        }
      }
      
      // Build query
      var query = _client
          .from('stock_transfers')
          .select()
          .eq('to_outlet_id', outletId);

      // Add date filter if provided
      if (selectedDate != null) {
        // Convert selected date to UTC
        // selectedDate is DateTime.now() or picked by user (no time component)
        // Business day starts at businessDayStartHour on selectedDate
        // and ends at (businessDayStartHour - 1):59 on selectedDate + 1 day
        
        final year = selectedDate.year;
        final month = selectedDate.month;
        final day = selectedDate.day;
        
        final dailyStart = DateTime.utc(year, month, day, businessDayStartHour, 0, 0);
        final dailyEnd = DateTime.utc(year, month, day + 1, businessDayStartHour, 0, 0).subtract(const Duration(seconds: 1));
        
        query = query
            .gte('created_at', dailyStart.toIso8601String())
            .lte('created_at', dailyEnd.toIso8601String());
      }
      
      final response = await query.order('created_at', ascending: false);

      for (final t in response) {
      }

      // Enrich with outlet names and product names
      final enrichedTransfers = <Map<String, dynamic>>[];
      
      for (final transfer in response) {
        try {
          
          final fromOutlet = await _client
              .from('outlets')
              .select('name')
              .eq('id', transfer['from_outlet_id'])
              .maybeSingle();
          
          final toOutlet = await _client
              .from('outlets')
              .select('name')
              .eq('id', transfer['to_outlet_id'])
              .maybeSingle();
          
          final fromName = (fromOutlet?['name'] as String?) ?? 'Unknown';
          final toName = (toOutlet?['name'] as String?) ?? 'Unknown';
          
          // Get items from stock_transfer_items table directly (not nested)
          final itemsResponse = await _client
              .from('stock_transfer_items')
              .select('product_id, quantity_int')
              .eq('transfer_id', transfer['id']);
          
          
          if (itemsResponse.isNotEmpty) {
            final firstItem = itemsResponse[0];
            
            final productId = firstItem['product_id'] as String?;
            final quantity = firstItem['quantity_int'] as int? ?? 0;
            
            
            if (productId != null) {
              final product = await _client
                  .from('products')
                  .select('name')
                  .eq('id', productId)
                  .maybeSingle();
              
              final productName = (product?['name'] as String?) ?? 'Unknown';
              
              // Get showcase_product_id for current stock lookup
              final showcaseProduct = await _client
                  .from('showcase_products')
                  .select('id')
                  .eq('product_id', productId)
                  .maybeSingle();
              
              int currentStockReceiving = 0;
              if (showcaseProduct != null) {
                final showcaseProductId = showcaseProduct['id'] as String;
                final receivingOutletStock = await _client
                    .from('showcase_allocations')
                    .select('quantity')
                    .eq('outlet_id', transfer['to_outlet_id'])
                    .eq('showcase_product_id', showcaseProductId)
                    .maybeSingle();
                
                currentStockReceiving = (receivingOutletStock?['quantity'] as int?) ?? 0;
              }
              
              final enrichedTransfer = {
                'id': transfer['id'],
                'from_outlet_id': transfer['from_outlet_id'],
                'to_outlet_id': transfer['to_outlet_id'],
                'from_outlet_name': fromName,
                'to_outlet_name': toName,
                'product_id': productId,
                'product_name': productName,
                'quantity': quantity,
                'current_stock_at_receiving_outlet': currentStockReceiving,
                'status': transfer['status'] ?? 'received',
                'created_at': transfer['created_at'],
              };
              
              enrichedTransfers.add(enrichedTransfer);
            }
          } else {
          }
        } catch (e) {
        }
      }
      
      for (final t in enrichedTransfers) {
      }
      return enrichedTransfers;
    } catch (e) {
      return [];
    }
  }

  // Record sale to warehouse system (sales_records table)
  // This is called after a successful checkout to track batch sales
  Future<void> recordSaleToWarehouse({
    required String batchId,
    required String outletId,
    required int quantitySold,
    required DateTime saleDate,
    String? notes,
  }) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      
      await _client.from('sales_records').insert({
        'batch_id': batchId,
        'outlet_id': outletId,
        'quantity_sold': quantitySold,
        'sale_date': saleDate.toIso8601String(),
        'notes': notes ?? 'Dari POS mobile',
      });

    } catch (e) {
      throw Exception('Gagal mencatat penjualan ke sistem warehouse: $e');
    }
  }

// Get available batches for an outlet
  Future<List<Map<String, dynamic>>> getAvailableBatches(String outletId) async {
    if (!_isInitialized) {
      return [];
    }

    try {
      
      final response = await _client
          .from('product_batches')
          .select()
          .eq('outlet_id', outletId)
          .inFilter('status', ['ready', 'assigned']);

      
      final batches = List<Map<String, dynamic>>.from(response);
      for (final batch in batches) {
      }
      
      return batches;
    } catch (e, stackTrace) {
      return [];
    }
  }

// Get revenue data for finance screen
  // If outletId is empty, fetch global revenue from all outlets
  Future<Map<String, dynamic>> getRevenueData({
    required String outletId,
    required DateTime selectedDate,
  }) async {
    if (!_isInitialized) {
      return {
        'daily': {'amount': 0.0, 'count': 0, 'cash': 0.0, 'qris': 0.0},
        'weekly': {'amount': 0.0, 'count': 0, 'cash': 0.0, 'qris': 0.0},
        'monthly': {'amount': 0.0, 'count': 0, 'cash': 0.0, 'qris': 0.0},
      };
    }

    try {
      
      if (outletId.isEmpty) {
        throw Exception('Outlet ID is empty');
      }
      
      // Get outlet's business_day_start_hour
      final outletData = await _client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', outletId)
          .maybeSingle();
      
      if (outletData == null) {
        return {
          'daily': {'amount': 0.0, 'count': 0, 'cash': 0.0, 'qris': 0.0},
          'weekly': {'amount': 0.0, 'count': 0, 'cash': 0.0, 'qris': 0.0},
          'monthly': {'amount': 0.0, 'count': 0, 'cash': 0.0, 'qris': 0.0},
        };
      }
      
      final businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;
      
      // Calculate business day dates
      // Business day: starts at businessDayStartHour of PREVIOUS day, ends at businessDayStartHour of selectedDate - 1 second
      // Example: businessDayStartHour=21, selectedDate=May 11 → May 10 21:00 to May 11 20:59:59
      final dailyStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
          .subtract(const Duration(days: 1))
          .copyWith(hour: businessDayStartHour, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      final dailyEndTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, businessDayStartHour, 0, 0)
          .subtract(const Duration(seconds: 1));
      
      
      // Query daily sales
      final dailyResponse = await _client.from('sales')
          .select('payment_method, total_amount, created_at, outlet_id')
          .eq('outlet_id', outletId)
          .gte('created_at', dailyStart.toIso8601String())
          .lte('created_at', dailyEndTime.toIso8601String());
      
      
      // Calculate weekly (last 7 business days)
      final weeklyStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
          .subtract(const Duration(days: 7))
          .copyWith(hour: businessDayStartHour, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      
      
      final weeklyResponse = await _client.from('sales')
          .select('payment_method, total_amount, created_at, outlet_id')
          .eq('outlet_id', outletId)
          .gte('created_at', weeklyStart.toIso8601String())
          .lte('created_at', dailyEndTime.toIso8601String());
      
      
      // Calculate monthly (last 30 business days)
      final monthlyStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
          .subtract(const Duration(days: 30))
          .copyWith(hour: businessDayStartHour, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      
      
      final monthlyResponse = await _client.from('sales')
          .select('payment_method, total_amount, created_at, outlet_id')
          .eq('outlet_id', outletId)
          .gte('created_at', monthlyStart.toIso8601String())
          .lte('created_at', dailyEndTime.toIso8601String());
      
      
      // Process daily data
      double dailyTotal = 0, dailyCash = 0, dailyQris = 0;
      int dailyCount = 0;
      for (final sale in dailyResponse) {
        final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;
        final method = (sale['payment_method'] as String?)?.toUpperCase() ?? '';
        dailyTotal += amount;
        dailyCount++;
        if (method == 'CASH') dailyCash += amount;
        else if (method == 'QRIS') dailyQris += amount;
      }
      
      // Process weekly data
      double weeklyTotal = 0, weeklyCash = 0, weeklyQris = 0;
      int weeklyCount = 0;
      for (final sale in weeklyResponse) {
        final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;
        final method = (sale['payment_method'] as String?)?.toUpperCase() ?? '';
        weeklyTotal += amount;
        weeklyCount++;
        if (method == 'CASH') weeklyCash += amount;
        else if (method == 'QRIS') weeklyQris += amount;
      }
      
      // Process monthly data
      double monthlyTotal = 0, monthlyCash = 0, monthlyQris = 0;
      int monthlyCount = 0;
      for (final sale in monthlyResponse) {
        final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;
        final method = (sale['payment_method'] as String?)?.toUpperCase() ?? '';
        monthlyTotal += amount;
        monthlyCount++;
        if (method == 'CASH') monthlyCash += amount;
        else if (method == 'QRIS') monthlyQris += amount;
      }
      

      return {
        'daily': {
          'amount': dailyTotal,
          'count': dailyCount,
          'cash': dailyCash,
          'qris': dailyQris,
        },
        'weekly': {
          'amount': weeklyTotal,
          'count': weeklyCount,
          'cash': weeklyCash,
          'qris': weeklyQris,
        },
        'monthly': {
          'amount': monthlyTotal,
          'count': monthlyCount,
          'cash': monthlyCash,
          'qris': monthlyQris,
        },
      };
    } catch (e, stackTrace) {
      return {
        'daily': {'amount': 0.0, 'count': 0},
        'weekly': {'amount': 0.0, 'count': 0},
        'monthly': {'amount': 0.0, 'count': 0},
      };
    }
  }

  // Get cash deposit data for today using business day
  Future<Map<String, dynamic>> getCashDepositData({
    required String outletId,
    required DateTime date,
  }) async {
    if (!_isInitialized) {
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
    }

    try {
      
      // First: Check if outlet_id is valid
      if (outletId.isEmpty) {
        throw Exception('Outlet ID is empty');
      }
      
      // Get outlet's business_day_start_hour
      final outletData = await _client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', outletId)
          .maybeSingle();
      
      if (outletData == null) {
        throw Exception('Outlet not found');
      }
      
      final businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;
      
      // Calculate business day date range
      // Business day: starts at businessDayStartHour of PREVIOUS day, ends at businessDayStartHour of date - 1 second
      final dateStart = DateTime(date.year, date.month, date.day)
          .subtract(const Duration(days: 1))
          .copyWith(hour: businessDayStartHour, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      final dateEnd = DateTime(date.year, date.month, date.day, businessDayStartHour, 0, 0)
          .subtract(const Duration(seconds: 1));
      
      
      // Query sales for this business day
      var query = _client.from('sales').select('payment_method, total_amount, created_at, outlet_id');
      
      if (outletId.isNotEmpty) {
        query = query.eq('outlet_id', outletId);
      }
      
      final response = await query
          .gte('created_at', dateStart.toIso8601String())
          .lte('created_at', dateEnd.toIso8601String());
      
      
      double cashAmount = 0;
      int cashCount = 0;
      double qrisAmount = 0;
      int qrisCount = 0;
      double totalOmset = 0;
      
      for (final sale in response) {
        final paymentMethod = sale['payment_method'] as String?;
        final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;
        final createdAt = sale['created_at'];
        
        totalOmset += amount;
        
        
        if (paymentMethod?.toUpperCase() == 'CASH') {
          cashAmount += amount;
          cashCount++;
        } else if (paymentMethod?.toUpperCase() == 'QRIS') {
          qrisAmount += amount;
          qrisCount++;
        }
      }
      
      // Calculate bonus using tiered system
      double bonus = 0;
      if (totalOmset > 0) {
        // Tier 1: 0 - 200k = 10%
        // Tier 2: 200k - 350k = 12%
        // Tier 3: 350k - 500k = 15%
        // Tier 4: 500k+ = 20%
        
        if (totalOmset <= 200000) {
          bonus = totalOmset * 0.10;
        } else if (totalOmset <= 350000) {
          bonus = (200000 * 0.10) + ((totalOmset - 200000) * 0.12);
        } else if (totalOmset <= 500000) {
          bonus = (200000 * 0.10) + (150000 * 0.12) + ((totalOmset - 350000) * 0.15);
        } else {
          bonus = (200000 * 0.10) + (150000 * 0.12) + (150000 * 0.15) + ((totalOmset - 500000) * 0.20);
        }
      }
      
      // Calculate meal allowance
      double mealAllowance = totalOmset >= 300000 ? 34000.0 : 25000.0;
      
      // Calculate deposit amount: CASH - BONUS - MEAL ALLOWANCE
      double depositAmount = cashAmount - bonus - mealAllowance;
      
      // Calculate kekurangan upah (shortfall) if deposit is negative
      double kekuranganUpah = 0;
      if (depositAmount < 0) {
        kekuranganUpah = -depositAmount;  // Absolute value of deficit
        depositAmount = 0;  // Set deposit to 0, shortfall will be provided
      }

      // Check handover status for this date
      String handoverStatus = 'pending'; // default
      try {
        final dateStr = DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];
        final handoversForDate = await _client
            .from('cash_deposit_handovers')
            .select('status')
            .eq('date', dateStr)
            .order('created_at', ascending: false)
            .limit(1);
        
        if (handoversForDate.isNotEmpty) {
          handoverStatus = handoversForDate[0]['status'] as String? ?? 'pending';
        }
      } catch (e) {
        // Continue with default status
      }
      
      if (kekuranganUpah > 0) {
      } else {
      }
      
      return {
        'cashAmount': cashAmount,
        'cashCount': cashCount,
        'qrisAmount': qrisAmount,
        'qrisCount': qrisCount,
        'totalOmset': totalOmset,
        'bonus': bonus,
        'mealAllowance': mealAllowance,
        'depositAmount': depositAmount,
        'kekuranganUpah': kekuranganUpah,
        'handoverStatus': handoverStatus,
      };
    } catch (e) {
      return {
        'cashAmount': 0.0,
        'cashCount': 0,
        'qrisAmount': 0.0,
        'qrisCount': 0,
        'totalOmset': 0.0,
        'bonus': 0.0,
        'mealAllowance': 0.0,
        'depositAmount': 0.0,
        'kekuranganUpah': 0.0,
        'handoverStatus': 'pending',
      };
    }
  }

  // Update batch quantity after sale (reduce stock)
  Future<bool> updateBatchQuantity({
    required String batchId,
    required int quantitySold,
  }) async {
    if (!_isInitialized) {
      return false;
    }

    try {
      // Get current quantity
      final batch = await _client
          .from('product_batches')
          .select('quantity')
          .eq('id', batchId)
          .single();

      final currentQty = batch['quantity'] as int? ?? 0;
      final newQty = currentQty - quantitySold;


      // Update quantity
      await _client
          .from('product_batches')
          .update({'quantity': newQty})
          .eq('id', batchId);

      // If quantity reaches 0, mark as sold
      if (newQty <= 0) {
        await _client
            .from('product_batches')
            .update({'status': 'sold'})
            .eq('id', batchId);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Submit serah terima (handover) untuk setoran
  Future<bool> submitCashDepositHandover({
    required String outletId,
    required String baristaId,
    required double totalOmset,
    required double cashAmount,
    required double qrisAmount,
    required double bonus,
    required double mealAllowance,
    required double depositAmount,
    required double kekuranganUpah,
    required DateTime date,
  }) async {
    if (!_isInitialized) {
      return false;
    }

    try {
      if (kekuranganUpah > 0) {
      }
      
      await _client.from('cash_deposit_handovers').insert({
        'outlet_id': outletId,
        'barista_id': baristaId,
        'total_omset': totalOmset,
        'cash_amount': cashAmount,
        'qris_amount': qrisAmount,
        'bonus': bonus,
        'meal_allowance': mealAllowance,
        'deposit_amount': depositAmount,
        'kekurangan_upah': kekuranganUpah,
        'status': 'pending',
        'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD format
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get serah terima history
  Future<List<Map<String, dynamic>>> getCashDepositHandoverHistory({
    required String outletId,
    required String baristaId,
  }) async {
    if (!_isInitialized) {
      return [];
    }

    try {
      var query = _client
          .from('cash_deposit_handovers')
          .select('*, users!barista_id(id, full_name)')
          .eq('outlet_id', outletId);

      // If baristaId is empty, get all from outlet; otherwise filter by barista
      if (baristaId.isNotEmpty) {
        query = query.eq('barista_id', baristaId);
      }

      final response = await query
          .order('date', ascending: false)
          .limit(100);
      
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      return [];
    }
  }

  // Get pending handovers for approval
  Future<List<Map<String, dynamic>>> getPendingCashDepositHandovers({
    required String outletId,
  }) async {
    if (!_isInitialized) {
      return [];
    }

    try {
      final response = await _client
          .from('cash_deposit_handovers')
          .select('*, users!barista_id(id, full_name)')
          .eq('outlet_id', outletId)
          .eq('status', 'pending')
          .order('submitted_at', ascending: true);
      
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      return [];
    }
  }

  // Approve serah terima
  Future<bool> approveCashDepositHandover({
    required String handoverId,
    required String approverId,
  }) async {
    if (!_isInitialized) {
      return false;
    }

    try {
      
      await _client
          .from('cash_deposit_handovers')
          .update({
            'status': 'approved',
            'approved_by': approverId,
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', handoverId);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Reject serah terima
  Future<bool> rejectCashDepositHandover({
    required String handoverId,
    required String rejectionReason,
  }) async {
    if (!_isInitialized) {
      return false;
    }

    try {
      
      await _client
          .from('cash_deposit_handovers')
          .update({
            'status': 'rejected',
            'rejection_reason': rejectionReason,
          })
          .eq('id', handoverId);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get announcements
  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      final response = await _client
          .from('announcements')
          .select('id, title, description, created_at')
          .order('created_at', ascending: false)
          .limit(10);
      
      for (var ann in response) {
      }
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch announcements: $e');
    }
  }

  // Get private messages for a user
  Future<List<Map<String, dynamic>>> getPrivateMessages({required String userId}) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      final response = await _client
          .from('private_messages')
          .select('*')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(50);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch private messages: $e');
    }
  }

  // Get private messages with enriched sender info
  Future<List<Map<String, dynamic>>> getPrivateMessagesWithSenderInfo({required String userId}) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      final response = await _client
          .from('private_messages')
          .select('id, sender_id, receiver_id, message, created_at')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(50);
      
      
      // Enrich messages with sender info
      List<Map<String, dynamic>> messages = List<Map<String, dynamic>>.from(response);
      
      for (var message in messages) {
        final senderId = message['sender_id'];
        try {
          final senderData = await _client
              .from('users')
              .select('id, name, email')
              .eq('id', senderId)
              .single();
          message['sender_name'] = senderData['name'] ?? 'Unknown';
          message['sender_email'] = senderData['email'] ?? '';
        } catch (e) {
          message['sender_name'] = 'Unknown';
          message['sender_email'] = '';
        }
      }
      
      return messages;
    } catch (e) {
      throw Exception('Failed to fetch private messages: $e');
    }
  }

  // Get group chats for an outlet
  Future<List<Map<String, dynamic>>> getGroupChats() async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      final response = await _client
          .from('group_chats')
          .select('*')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch group chats: $e');
    }
  }

  // Send private message
  Future<bool> sendPrivateMessage({
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    if (!_isInitialized) return false;

    try {
      await _client
          .from('private_messages')
          .insert({
            'sender_id': senderId,
            'receiver_id': receiverId,
            'message': message,
            'created_at': DateTime.now().toIso8601String(),
          });
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Send group chat message
  Future<bool> sendGroupChatMessage({
    required String groupChatId,
    required String userId,
    required String message,
  }) async {
    if (!_isInitialized) return false;

    try {
      await _client
          .from('group_chat_messages')
          .insert({
            'group_chat_id': groupChatId,
            'user_id': userId,
            'message': message,
            'created_at': DateTime.now().toIso8601String(),
          });
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== OUTLET STATUS ====================
  Future<String> getOutletStatus({required String outletId}) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      final response = await _client
          .from('outlet_status')
          .select('status')
          .eq('outlet_id', outletId)
          .single();

      return response['status'] ?? 'active';
    } catch (e) {
      return 'active'; // Default to active
    }
  }

  Future<bool> updateOutletStatus({
    required String outletId,
    required String status,
    required String userId,
  }) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      await _client.from('outlet_status').upsert({
        'outlet_id': outletId,
        'status': status,
        'updated_by': userId,
        'updated_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== PERFORMANCE METRICS ====================
  Future<Map<String, dynamic>> getYesterdaySalesData({
    required String outletId,
  }) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final startOfYesterday = DateTime(yesterday.year, yesterday.month, yesterday.day);
      final endOfYesterday = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);

      final response = await _client
          .rpc('get_revenue_data', params: {
            'p_outlet_id': outletId,
            'p_start_date': startOfYesterday.toIso8601String(),
            'p_end_date': endOfYesterday.toIso8601String(),
          });

      return {
        'amount': (response?['daily']?['amount'] as num?)?.toDouble() ?? 0.0,
        'count': (response?['daily']?['count'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      return {'amount': 0.0, 'count': 0};
    }
  }

  // Fetch recent transactions
  Future<List<Map<String, dynamic>>> getRecentTransactions({
    required String outletId,
    int limit = 5,
  }) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      final response = await _client
          .from('sales')
          .select('id, total_amount, payment_method, created_at, notes')
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<int> getBusinessDayStartHour({required String outletId}) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      final response = await _client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', outletId)
          .maybeSingle();

      if (response == null) {
        return 4;
      }

      final hour = response['business_day_start_hour'] as int? ?? 4;
      return hour;
    } catch (e) {
      return 4; // Default to 4 AM
    }
  }

  // DEBUG: Create test investor assignments for development
  Future<void> seedTestInvestorAssignments({
    required String investorId,
  }) async {
    if (!_isInitialized) return;

    try {

      // Get first 2 outlets
      final outlets = await _client
          .from('outlets')
          .select('id, name')
          .limit(2);

      if ((outlets as List<dynamic>).isEmpty) {
        return;
      }

      // Create assignments
      final assignments = (outlets as List<dynamic>)
          .map((outlet) => {
                'investor_id': investorId,
                'outlet_id': outlet['id'],
                'investment_amount': 50000000,
                'margin_percentage': 10,
                'status': 'active',
              })
          .toList();

      final result = await _client.from('investor_assignments').insert(assignments);

    } catch (e) {
    }
  }

  /// Update transfer status (approve, reject, cancel)
  /// SIMPLIFIED: Only updates stock_transfers table, does NOT touch showcase_allocations
  Future<bool> updateTransferStatus(String transferId, String newStatus) async {
    if (!_isInitialized) {
      return false;
    }

    try {
      
      // If cancelling/rejecting transfer, delete it
      if ((newStatus.toLowerCase() == 'rejected' || newStatus.toLowerCase() == 'cancelled')) {
        try {
          await _client
              .from('stock_transfers')
              .delete()
              .eq('id', transferId);
          return true;
        } on PostgrestException catch (e) {
          if (e.code == '406' || e.code == 406) {
            return true;
          } else {
            return false;
          }
        }
      }
      
      // For approve or other statuses, just update stock_transfers status
      // NO showcase_allocations changes
      try {
        await _client
            .from('stock_transfers')
            .update({'status': newStatus})
            .eq('id', transferId);
      } on PostgrestException catch (e) {
        if (e.code == '406' || e.code == 406) {
          return true;
        } else {
          return false;
        }
      } catch (e) {
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Showcase Allocation Methods

  /// Fetch all showcase products with inventory
  Future<List<Map<String, dynamic>>> fetchShowcaseProducts() async {
    if (!_isInitialized) {
      return [];
    }

    try {
      final response = await _client
          .from('showcase_products')
          .select('id, product_id, product_name, total_quantity')
          .order('product_name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching showcase products: $e');
      return [];
    }
  }

  /// Fetch outlets for allocation
  Future<List<Map<String, dynamic>>> fetchOutlets() async {
    try {
      return await getOutlets();
    } catch (e) {
      print('Error fetching outlets: $e');
      return [];
    }
  }

  /// Get settings including business day start hour
  Future<Map<String, dynamic>?> getSettings() async {
    if (!_isInitialized) {
      return null;
    }

    try {
      final response = await _client
          .from('settings')
          .select('*')
          .limit(1)
          .single();

      return response;
    } catch (e) {
      print('Error fetching settings: $e');
      return null;
    }
  }

  /// Fetch assignments for a specific outlet and date range
  Future<List<Map<String, dynamic>>> fetchAssignmentsForOutlet({
    required String outletId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!_isInitialized) {
      return [];
    }

    try {
      final startISO = startDate.toIso8601String();
      final endISO = endDate.toIso8601String();

      print('=== FETCH ASSIGNMENTS START ===');
      print('Outlet: $outletId');
      print('Start (UTC): $startISO');
      print('End (UTC): $endISO');
      
      // Convert back to local to show user what range we're querying
      final startLocal = startDate.toLocal();
      final endLocal = endDate.toLocal();
      print('Start (local): ${startLocal.toIso8601String()}');
      print('End (local): ${endLocal.toIso8601String()}');

      // First, fetch ALL allocations for this outlet to see what we have
      print('--- Fetching ALL allocations (no filter) for comparison ---');
      final allAllocations = await _client
          .from('showcase_allocations')
          .select('*')
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false);
      
      print('Total allocations for outlet: ${(allAllocations as List).length}');
      for (int i = 0; i < (allAllocations as List).length && i < 5; i++) {
        final item = allAllocations[i];
        final createdAt = item['created_at'];
        print('  Alloc $i: created_at = $createdAt');
      }

      // Now fetch with date filter
      print('--- Fetching with DATE FILTER ---');
      final response = await _client
          .from('showcase_allocations')
          .select('*')
          .eq('outlet_id', outletId)
          .gte('created_at', startISO)
          .lte('created_at', endISO)
          .order('created_at', ascending: false);

      print('Filtered query result count: ${(response as List).length}');
      if ((response as List).isEmpty) {
        print('No allocations found in date range');
        print('Possible issue: Check if created_at values fall within range');
      } else {
        // Show first few results
        for (int i = 0; i < (response as List).length && i < 3; i++) {
          final item = response[i];
          final createdAt = item['created_at'];
          print('  - Item $i: created_at = $createdAt');
        }
      }

      // Get showcase products mapping
      final showcaseProductsResp = await _client
          .from('showcase_products')
          .select('id, product_name');
      
      final productMap = <String, String>{};
      for (final sp in showcaseProductsResp as List<dynamic>) {
        productMap[sp['id']] = sp['product_name'] as String;
      }

      // Build result with product_name
      final result = <Map<String, dynamic>>[];
      for (final item in response as List<dynamic>) {
        final showcaseProductId = item['showcase_product_id'] as String?;
        if (showcaseProductId != null && productMap.containsKey(showcaseProductId)) {
          result.add({
            'id': item['id'],
            'showcase_product_id': showcaseProductId,
            'product_name': productMap[showcaseProductId],
            'quantity': item['quantity'],
            'created_at': item['created_at'],
          });
        }
      }

      print('Final result: ${result.length} allocations');
      for (int i = 0; i < result.length && i < 3; i++) {
        print('  - ${result[i]['product_name']}: ${result[i]['quantity']} (created: ${result[i]['created_at']})');
      }
      print('=== FETCH ASSIGNMENTS END ===');
      return result;
    } catch (e) {
      print('Error fetching assignments: $e');
      return [];
    }
  }

  /// Allocate a showcase product to an outlet
  Future<Map<String, dynamic>> allocateShowcaseProduct({
    required String showcaseProductId,
    required String outletId,
    required int quantity,
  }) async {
    if (!_isInitialized) {
      return {'success': false, 'message': 'Service not initialized'};
    }

    try {
      print('=== ALLOCATE START ===');
      print('showcaseProductId: $showcaseProductId');
      print('outletId: $outletId');
      print('quantity: $quantity');
      
      // Insert directly into showcase_allocations table
      // IMPORTANT: Store created_at in UTC to match the business day range queries
      final createdAtUtc = DateTime.now().toUtc().toIso8601String();
      print('created_at (UTC): $createdAtUtc');
      
      final response = await _client
          .from('showcase_allocations')
          .insert({
            'showcase_product_id': showcaseProductId,
            'outlet_id': outletId,
            'quantity': quantity,
            'created_at': createdAtUtc,
          });

      print('Insert response: $response');
      print('=== ALLOCATE END (success) ===');

      return {
        'success': true,
        'message': 'Alokasi berhasil dilakukan',
        'data': response,
      };
    } catch (e) {
      print('=== ALLOCATE END (error) ===');
      print('Error allocating product: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Delete a showcase allocation
  Future<Map<String, dynamic>> deleteShowcaseAllocation(
      String allocationId) async {
    if (!_isInitialized) {
      return {'success': false, 'message': 'Service not initialized'};
    }

    try {
      await _client
          .from('showcase_allocations')
          .delete()
          .eq('id', allocationId);

      return {
        'success': true,
        'message': 'Alokasi berhasil dihapus',
      };
    } catch (e) {
      print('Error deleting allocation: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Fetch product returns for an outlet and date range
  Future<List<Map<String, dynamic>>> fetchProductReturnsForOutlet({
    required String outletId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!_isInitialized) {
      return [];
    }

    try {
      final startISO = startDate.toIso8601String().split('T')[0];
      final endISO = endDate.toIso8601String().split('T')[0];

      print('=== FETCH PRODUCT RETURNS START ===');
      print('Outlet: $outletId');
      print('Start (Date): $startISO');
      print('End (Date): $endISO');

      // Fetch all product returns for this outlet within the date range
      final response = await _client
          .from('product_returns')
          .select('*')
          .eq('outlet_id', outletId)
          .gte('return_date', startISO)
          .lte('return_date', endISO)
          .order('return_date', ascending: false);

      print('Query result count: ${(response as List).length}');

      // Get products mapping
      final productsResp = await _client
          .from('products')
          .select('id, name');

      final productMap = <String, String>{};
      for (final p in productsResp as List<dynamic>) {
        productMap[p['id']] = p['name'] as String;
      }

      // Build result with product_name
      final result = <Map<String, dynamic>>[];
      for (final item in response as List<dynamic>) {
        final productId = item['product_id'] as String?;
        if (productId != null && productMap.containsKey(productId)) {
          result.add({
            'id': item['id'],
            'product_id': productId,
            'product_name': productMap[productId],
            'quantity': 1, // Each row represents one return instance
            'return_reason': item['return_reason'] ?? '',
            'condition_status': item['condition_status'] ?? 'good',
            'resolution_status': item['resolution_status'] ?? 'pending',
            'return_date': item['return_date'],
          });
        }
      }

      print('Final result: ${result.length} returns');
      print('=== FETCH PRODUCT RETURNS END ===');
      return result;
    } catch (e) {
      print('Error fetching product returns: $e');
      return [];
    }
  }

  /// Create a product return record for manager returns
  Future<Map<String, dynamic>> recordProductReturn({
    required String productId,
    required String outletId,
    required int quantity,
    String returnReason = 'Tidak terjual',
  }) async {
    if (!_isInitialized) {
      return {'success': false, 'message': 'Service not initialized'};
    }

    try {
      print('=== RECORD PRODUCT RETURN START ===');
      print('productId: $productId');
      print('outletId: $outletId');
      print('quantity: $quantity');
      print('returnReason: $returnReason');

      // Insert into product_returns table with actual schema columns
      // Schema: product_id, outlet_id, return_reason, condition_status, resolution_status, return_date
      // Insert one record per unit (quantity) since the table tracks individual items
      final today = DateTime.now().toUtc().toIso8601String().split('T')[0];
      
      for (int i = 0; i < quantity; i++) {
        await _client.from('product_returns').insert({
          'product_id': productId,
          'outlet_id': outletId,
          'return_reason': returnReason,
          'condition_status': 'sellable',
          'resolution_status': 'pending',
          'return_date': today,
        });
      }

      print('=== RECORD PRODUCT RETURN END (success) ===');

      return {
        'success': true,
        'message': 'Pengembalian berhasil dicatat ($quantity unit)',
      };
    } catch (e) {
      print('=== RECORD PRODUCT RETURN END (error) ===');
      print('Error recording product return: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Delete a product return record
  Future<Map<String, dynamic>> deleteProductReturn(String returnId) async {
    if (!_isInitialized) {
      return {'success': false, 'message': 'Service not initialized'};
    }

    try {
      await _client.from('product_returns').delete().eq('id', returnId);

      return {
        'success': true,
        'message': 'Pengembalian berhasil dihapus',
      };
    } catch (e) {
      print('Error deleting product return: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }
}

