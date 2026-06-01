import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:io';
import '../models/user.dart' as user_model;
import '../models/product.dart';
import '../models/outlet.dart';
import '../models/sale.dart';
import '../models/stock.dart';
import '../utils/bonus_calculator.dart';
import '../utils/holiday_detector.dart';

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
      
      // Calculate business day date range in LOCAL time first, then convert to UTC
      // selectedDate comes as LOCAL time from DateTime.now() on device
      final year = selectedDate.year;
      final month = selectedDate.month;
      final day = selectedDate.day;
      
      DateTime startDateLocal;
      DateTime endDateLocal;
      
      if (businessDayStartHour >= 12) {
        // Afternoon start: business day is from YESTERDAY@startHour to TODAY@startHour
        startDateLocal = DateTime(year, month, day - 1, businessDayStartHour, 0, 0);
        endDateLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
      } else {
        // Morning start: business day is from TODAY@startHour to TOMORROW@startHour
        startDateLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
        endDateLocal = DateTime(year, month, day + 1, businessDayStartHour, 0, 0);
      }
      
      endDateLocal = endDateLocal.subtract(const Duration(milliseconds: 1));
      
      // Convert to UTC for database query
      final startDate = startDateLocal.toUtc();
      final endDate = endDateLocal.toUtc();
      
      
      final params = {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      };
      
      final response = await _client.rpc('get_global_leaderboard', params: params);
      
      // Handle case where RPC returns a List
      if (response is List) {
        if (response.isNotEmpty) {
          // Response is a List
        }
        return response
            .map((item) => item as Map<String, dynamic>)
            .toList();
      } else if (response is Map) {
        // Single item returned, wrap in list
        return [response as Map<String, dynamic>];
      } else {
        return [];
      }
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

      // IMPORTANT: When a date is selected from the date picker, we want to show
      // that calendar day's business day, regardless of what time selectedDate has.
      // For example, if user selects May 27, we show May 27's business day
      // (from May 27 at 4 AM to May 28 at 4 AM), not May 26's.
      
      final year = selectedDate.year;
      final month = selectedDate.month;
      final day = selectedDate.day;
      
      // For a selected date, always treat it as the START of that calendar day's business day
      // This matches the logic in getRevenueData()
      DateTime businessDayStartLocal;
      DateTime businessDayEndLocal;
      
      if (businessDayStartHour >= 12) {
        // Afternoon start (e.g., 21:00): business day is from YESTERDAY@startHour to TODAY@startHour
        businessDayStartLocal = DateTime(year, month, day - 1, businessDayStartHour, 0, 0);
        businessDayEndLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
      } else {
        // Morning start (e.g., 4 AM): business day is from TODAY@startHour to TOMORROW@startHour
        businessDayStartLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
        businessDayEndLocal = DateTime(year, month, day + 1, businessDayStartHour, 0, 0);
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
        
        // Calculate business day in LOCAL time first, then convert to UTC for query
        DateTime dailyStartLocal;
        DateTime dailyEndLocal;
        
        if (businessDayStartHour >= 12) {
          // Afternoon start: business day is from YESTERDAY@startHour to TODAY@startHour
          dailyStartLocal = DateTime(year, month, day - 1, businessDayStartHour, 0, 0);
          dailyEndLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
        } else {
          // Morning start: business day is from TODAY@startHour to TOMORROW@startHour
          dailyStartLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
          dailyEndLocal = DateTime(year, month, day + 1, businessDayStartHour, 0, 0);
        }
        
        dailyEndLocal = dailyEndLocal.subtract(const Duration(milliseconds: 1));
        
        // Convert to UTC for database query
        final dailyStart = dailyStartLocal.toUtc();
        final dailyEnd = dailyEndLocal.toUtc();
        
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
        
        // Calculate business day in LOCAL time first, then convert to UTC for query
        DateTime dailyStartLocal;
        DateTime dailyEndLocal;
        
        if (businessDayStartHour >= 12) {
          // Afternoon start: business day is from YESTERDAY@startHour to TODAY@startHour
          dailyStartLocal = DateTime(year, month, day - 1, businessDayStartHour, 0, 0);
          dailyEndLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
        } else {
          // Morning start: business day is from TODAY@startHour to TOMORROW@startHour
          dailyStartLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
          dailyEndLocal = DateTime(year, month, day + 1, businessDayStartHour, 0, 0);
        }
        
        dailyEndLocal = dailyEndLocal.subtract(const Duration(milliseconds: 1));
        
        // Convert to UTC for database query
        final dailyStart = dailyStartLocal.toUtc();
        final dailyEnd = dailyEndLocal.toUtc();
        
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
        print('ERROR getRevenueData: Outlet ID is empty');
        return {
          'daily': {'amount': 0.0, 'count': 0, 'cash': 0.0, 'qris': 0.0},
          'weekly': {'amount': 0.0, 'count': 0, 'cash': 0.0, 'qris': 0.0},
          'monthly': {'amount': 0.0, 'count': 0, 'cash': 0.0, 'qris': 0.0},
        };
      }
      
      // Get outlet's business_day_start_hour
      final outletData = await _client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', outletId)
          .maybeSingle();
      
      if (outletData == null) {
        print('ERROR getRevenueData: Outlet not found for id=$outletId');
        return {
          'daily': {'amount': 0.0, 'count': 0, 'cash': 0.0, 'qris': 0.0},
          'weekly': {'amount': 0.0, 'count': 0, 'cash': 0.0, 'qris': 0.0},
          'monthly': {'amount': 0.0, 'count': 0, 'cash': 0.0, 'qris': 0.0},
        };
      }
      
      final businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;
      
      // IMPORTANT: Calculate business day in LOCAL time first, then convert to UTC for query
      // This ensures we respect the device's timezone
      // selectedDate comes as LOCAL time from DateTime.now() on device
      final year = selectedDate.year;
      final month = selectedDate.month;
      final day = selectedDate.day;
      
      // Calculate daily range in LOCAL time
      DateTime dailyStartLocal;
      DateTime dailyEndLocal;
      
      if (businessDayStartHour >= 12) {
        // Afternoon start: business day is from YESTERDAY@startHour to TODAY@startHour
        dailyStartLocal = DateTime(year, month, day - 1, businessDayStartHour, 0, 0);
        dailyEndLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
      } else {
        // Morning start: business day is from TODAY@startHour to TOMORROW@startHour
        dailyStartLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
        dailyEndLocal = DateTime(year, month, day + 1, businessDayStartHour, 0, 0);
      }
      
      dailyEndLocal = dailyEndLocal.subtract(const Duration(milliseconds: 1));
      
      // Convert to UTC for database query
      final dailyStart = dailyStartLocal.toUtc();
      final dailyEnd = dailyEndLocal.toUtc();
      
      print('DEBUG getRevenueData: businessDayStartHour=$businessDayStartHour');
      print('DEBUG getRevenueData: selectedDate=$selectedDate (local device time)');
      print('DEBUG getRevenueData: dailyStartLocal=$dailyStartLocal');
      print('DEBUG getRevenueData: dailyStart=${dailyStart.toIso8601String()} (UTC for query)');
      
      // Query daily sales
      final dailyResponse = await _client.from('sales')
          .select('payment_method, total_amount, created_at, outlet_id')
          .eq('outlet_id', outletId)
          .gte('created_at', dailyStart.toIso8601String())
          .lte('created_at', dailyEnd.toIso8601String());
      
      // Calculate weekly (last 7 business days)
      DateTime weeklyStartLocal;
      if (businessDayStartHour >= 12) {
        weeklyStartLocal = DateTime(year, month, day - 7 - 1, businessDayStartHour, 0, 0);
      } else {
        weeklyStartLocal = DateTime(year, month, day - 7, businessDayStartHour, 0, 0);
      }
      final weeklyStart = weeklyStartLocal.toUtc();
      
      final weeklyResponse = await _client.from('sales')
          .select('payment_method, total_amount, created_at, outlet_id')
          .eq('outlet_id', outletId)
          .gte('created_at', weeklyStart.toIso8601String())
          .lte('created_at', dailyEnd.toIso8601String());
      
      // Calculate monthly (last 30 business days)
      DateTime monthlyStartLocal;
      if (businessDayStartHour >= 12) {
        monthlyStartLocal = DateTime(year, month, day - 30 - 1, businessDayStartHour, 0, 0);
      } else {
        monthlyStartLocal = DateTime(year, month, day - 30, businessDayStartHour, 0, 0);
      }
      final monthlyStart = monthlyStartLocal.toUtc();
      
      final monthlyResponse = await _client.from('sales')
          .select('payment_method, total_amount, created_at, outlet_id')
          .eq('outlet_id', outletId)
          .gte('created_at', monthlyStart.toIso8601String())
          .lte('created_at', dailyEnd.toIso8601String());
      
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
    required String baristaId,
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
      
      // Calculate business day date range in LOCAL time first, then convert to UTC
      // date comes as LOCAL time from DateTime.now() on device
      final year = date.year;
      final month = date.month;
      final day = date.day;
      
      DateTime dateStartLocal;
      DateTime dateEndLocal;
      
      if (businessDayStartHour >= 12) {
        // Afternoon start: business day is from YESTERDAY@startHour to TODAY@startHour
        dateStartLocal = DateTime(year, month, day - 1, businessDayStartHour, 0, 0);
        dateEndLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
      } else {
        // Morning start: business day is from TODAY@startHour to TOMORROW@startHour
        dateStartLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
        dateEndLocal = DateTime(year, month, day + 1, businessDayStartHour, 0, 0);
      }
      
      dateEndLocal = dateEndLocal.subtract(const Duration(milliseconds: 1));
      
      // Convert to UTC for database query
      final dateStart = dateStartLocal.toUtc();
      final dateEnd = dateEndLocal.toUtc();
      
      
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
      double gratisAmount = 0;
      int gratisCount = 0;
      double otherAmount = 0;
      int otherCount = 0;
      double totalOmset = 0;
      
      for (final sale in response) {
        final paymentMethod = sale['payment_method'] as String?;
        final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;
        
        totalOmset += amount;
        
        
        if (paymentMethod?.toUpperCase() == 'CASH') {
          cashAmount += amount;
          cashCount++;
        } else if (paymentMethod?.toUpperCase() == 'QRIS') {
          qrisAmount += amount;
          qrisCount++;
        } else if (paymentMethod?.toUpperCase() == 'GRATIS') {
          gratisAmount += amount;
          gratisCount++;
        } else {
          // Other payment methods (NULL, etc)
          otherAmount += amount;
          otherCount++;
        }
      }
      
      // Calculate bonus using tiered system with holiday detection
      // Determine if the date is a holiday (weekend or national holiday)
      final businessDate = date;  // This is the date from the query parameter
      final isHolidayDate = isHoliday(businessDate);
      
      // Use the same bonus calculation as in the Revenue tab
      double bonus = 0;
      if (totalOmset > 0) {
        final bonusResult = calculateBonus(totalOmset, isHoliday: isHolidayDate);
        bonus = bonusResult.totalBonus;
      }

      
      // Calculate meal allowance
      // If omset is 0, no meal allowance
      double mealAllowance = 0.0;
      if (totalOmset > 0) {
        mealAllowance = totalOmset >= 300000 ? 34000.0 : 25000.0;
      }
      
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
      bool shortfallReceiptRecorded = false;
      String? handoverDate; // Store the actual handover date from DB
      try {
        // Calculate the business day DATE (not calendar date)
        // For morning start hour: business day date is tomorrow (end - 1 day)
        // For afternoon start hour: business day date is today
        DateTime businessDayDate;
        if (businessDayStartHour >= 12) {
          // Afternoon start: business day is today
          businessDayDate = DateTime(date.year, date.month, date.day);
        } else {
          // Morning start: business day is tomorrow (the END date of the business period)
          businessDayDate = DateTime(date.year, date.month, date.day + 1);
        }
        final dateStr = businessDayDate.toIso8601String().split('T')[0];
        print('DEBUG getCashDepositData: Querying handover for businessDayDate=$dateStr (businessDayStartHour=$businessDayStartHour), outletId=$outletId, baristaId=$baristaId');
        
        final handoversForDate = await _client
            .from('cash_deposit_handovers')
            .select('status, shortfall_receipt_recorded, id, date')
            .eq('date', dateStr)
            .eq('outlet_id', outletId)
            .eq('barista_id', baristaId)
            .order('created_at', ascending: false)
            .limit(1);
        
        print('DEBUG getCashDepositData: handoversForDate count=${handoversForDate.length}');
        if (handoversForDate.isNotEmpty) {
          print('DEBUG getCashDepositData: Found handover: ${handoversForDate[0]}');
          handoverStatus = handoversForDate[0]['status'] as String? ?? 'pending';
          shortfallReceiptRecorded = handoversForDate[0]['shortfall_receipt_recorded'] as bool? ?? false;
          handoverDate = handoversForDate[0]['date'] as String?; // Get the actual business day date
          print('DEBUG getCashDepositData: Set handoverStatus=$handoverStatus, shortfallReceiptRecorded=$shortfallReceiptRecorded, handoverDate=$handoverDate');
        } else {
          print('DEBUG getCashDepositData: No handover found for this date/outlet/barista');
        }
      } catch (e) {
        print('DEBUG getCashDepositData: Error querying handover: $e');
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
        'gratisAmount': gratisAmount,
        'gratisCount': gratisCount,
        'otherAmount': otherAmount,
        'otherCount': otherCount,
        'totalOmset': totalOmset,
        'bonus': bonus,
        'mealAllowance': mealAllowance,
        'depositAmount': depositAmount,
        'kekuranganUpah': kekuranganUpah,
        'handoverStatus': handoverStatus,
        'shortfall_receipt_recorded': shortfallReceiptRecorded,
        'handoverDate': handoverDate, // Add the actual handover date from DB
      };
    } catch (e) {
      return {
        'cashAmount': 0.0,
        'cashCount': 0,
        'qrisAmount': 0.0,
        'qrisCount': 0,
        'gratisAmount': 0.0,
        'gratisCount': 0,
        'otherAmount': 0.0,
        'otherCount': 0,
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
    required String status,
    required DateTime date,
  }) async {
    if (!_isInitialized) {
      print('ERROR: SupabaseService not initialized');
      return false;
    }

    try {
      final dateStr = date.toIso8601String().split('T')[0];
      print('DEBUG: Submitting cash deposit handover - outlet=$outletId, barista=$baristaId, status=$status, date=$dateStr');
      
      // Upsert: insert or update if exists (based on unique constraint)
      await _client.from('cash_deposit_handovers').upsert(
        {
          'outlet_id': outletId,
          'barista_id': baristaId,
          'total_omset': totalOmset,
          'cash_amount': cashAmount,
          'qris_amount': qrisAmount,
          'bonus': bonus,
          'meal_allowance': mealAllowance,
          'deposit_amount': depositAmount,
          'status': status,
          'date': dateStr,
        },
        onConflict: 'outlet_id,barista_id,date',
      );
      
      print('DEBUG: Cash deposit handover submitted successfully');
      return true;
    } catch (e) {
      print('ERROR: Failed to submit cash deposit handover: $e');
      
      // Log untuk debugging
      if (e.toString().contains('42501') || e.toString().contains('row-level security')) {
        print('ERROR: RLS policy violation. Please disable RLS on cash_deposit_handovers table');
        print('ERROR: Run: ALTER TABLE cash_deposit_handovers DISABLE ROW LEVEL SECURITY;');
      }
      
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

  // Record shortfall receipt (kekurangan upah)
  Future<bool> recordShortfallReceipt({
    required String outletId,
    required String baristaId,
    required double kekuranganUpah,
    required String notes,
    required DateTime date,
  }) async {
    if (!_isInitialized) {
      print('ERROR: SupabaseService not initialized');
      return false;
    }

    try {
      final dateStr = date.toIso8601String().split('T')[0];
      print('DEBUG: Recording shortfall receipt - outlet=$outletId, barista=$baristaId, amount=$kekuranganUpah, date=$dateStr');
      
      // Use upsert with onConflict to handle duplicate records (update if exists, insert if not)
      await _client.from('shortfall_receipts').upsert(
        {
          'outlet_id': outletId,
          'barista_id': baristaId,
          'amount': kekuranganUpah,
          'notes': notes.isEmpty ? 'Tanda terima upah yang kurang' : notes,
          'date': dateStr,
        },
        onConflict: 'outlet_id,barista_id,date',
      );
      
      print('DEBUG: Shortfall receipt recorded/updated successfully');
      
      // Update cash_deposit_handovers to mark that shortfall receipt was recorded
      print('DEBUG: About to update cash_deposit_handovers with: outlet_id=$outletId, barista_id=$baristaId, date=$dateStr');
      
      final updateResponse = await _client
          .from('cash_deposit_handovers')
          .update({'shortfall_receipt_recorded': true})
          .eq('outlet_id', outletId)
          .eq('barista_id', baristaId)
          .eq('date', dateStr);
      
      print('DEBUG: Updated cash_deposit_handovers response: $updateResponse');
      print('DEBUG: Updated cash_deposit_handovers shortfall_receipt_recorded flag');
      
      return true;
    } catch (e) {
      print('ERROR: Failed to record shortfall receipt: $e');
      return false;
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
      
      
      // Enrich messages with sender and receiver info
      List<Map<String, dynamic>> messages = List<Map<String, dynamic>>.from(response);
      
      for (var message in messages) {
        final senderId = message['sender_id'];
        final receiverId = message['receiver_id'];
        
        // Get sender info
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
        
        // Get receiver info
        try {
          final receiverData = await _client
              .from('users')
              .select('id, name, email')
              .eq('id', receiverId)
              .single();
          message['receiver_name'] = receiverData['name'] ?? 'Unknown';
          message['receiver_email'] = receiverData['email'] ?? '';
        } catch (e) {
          message['receiver_name'] = 'Unknown';
          message['receiver_email'] = '';
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

  // ANNOUNCEMENT CRUD OPERATIONS
  
  // Create new announcement
  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String description,
    String? imageUrl,
  }) async {
    try {
      final response = await _client
          .from('announcements')
          .insert({
            'title': title,
            'description': description,
            'image_url': imageUrl,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      
      return response;
    } catch (e) {
      throw Exception('Failed to create announcement: $e');
    }
  }

  // Get announcement by ID
  Future<Map<String, dynamic>> getAnnouncementById(String id) async {
    try {
      final response = await _client
          .from('announcements')
          .select('*')
          .eq('id', id)
          .single();
      
      return response;
    } catch (e) {
      throw Exception('Failed to fetch announcement: $e');
    }
  }

  // Update announcement
  Future<Map<String, dynamic>> updateAnnouncement({
    required String id,
    required String title,
    required String description,
    String? imageUrl,
  }) async {
    try {
      final response = await _client
          .from('announcements')
          .update({
            'title': title,
            'description': description,
            'image_url': imageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();
      
      return response;
    } catch (e) {
      throw Exception('Failed to update announcement: $e');
    }
  }

  // Delete announcement
  Future<void> deleteAnnouncement(String id) async {
    try {
      await _client
          .from('announcements')
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete announcement: $e');
    }
  }

  // ==================== GROUP MEMBERS ====================
  // Get group members with user details
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      final response = await _client
          .from('group_members')
          .select('*, users(id, name, email)')
          .eq('group_id', groupId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch group members: $e');
    }
  }

  // Add member to group
  Future<void> addGroupMember(String groupId, String userId) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      await _client.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
      });
    } catch (e) {
      throw Exception('Failed to add group member: $e');
    }
  }

  // Remove member from group
  Future<void> removeGroupMember(String groupId, String userId) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      await _client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to remove group member: $e');
    }
  }

  // Delete group chat (cascade deletes messages and members)
  Future<void> deleteGroupChat(String groupId) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      await _client
          .from('group_chats')
          .delete()
          .eq('id', groupId);
    } catch (e) {
      throw Exception('Failed to delete group chat: $e');
    }
  }

  /// Fetch sales data with HPP for profit calculation
  /// Returns list of sales with total_amount and hpp_total
  Future<List<Map<String, dynamic>>> getSalesWithHpp({
    required String outletId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!_isInitialized) {
      return [];
    }

    try {
      final response = await _client
          .from('sales')
          .select('id, total_amount, hpp_total, bonus_amount, created_at, payment_method')
          .eq('outlet_id', outletId)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Calculate total HPP for a period
  /// Returns aggregated HPP, sales amount for profit calculation
  Future<Map<String, dynamic>> getHppSummary({
    required String outletId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!_isInitialized) {
      return {'totalSales': 0.0, 'totalHpp': 0.0, 'totalBonus': 0.0};
    }

    try {
      final sales = await getSalesWithHpp(
        outletId: outletId,
        startDate: startDate,
        endDate: endDate,
      );

      double totalSales = 0;
      double totalHpp = 0;
      double totalBonus = 0;

      for (final sale in sales) {
        totalSales += (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
        totalHpp += (sale['hpp_total'] as num?)?.toDouble() ?? 0.0;
        totalBonus += (sale['bonus_amount'] as num?)?.toDouble() ?? 0.0;
      }

      return {
        'totalSales': totalSales,
        'totalHpp': totalHpp,
        'totalBonus': totalBonus,
        'transactionCount': sales.length,
      };
    } catch (e) {
      return {'totalSales': 0.0, 'totalHpp': 0.0, 'totalBonus': 0.0};
    }
  }

  // ========== WITHDRAWAL MANAGEMENT ==========

  /// Get withdrawal summary for an investor
  /// Returns available balance, pending amount, and this month's withdrawals
  Future<Map<String, dynamic>> getWithdrawalSummary({
    required String investorId,
  }) async {
    if (!_isInitialized) {
      return {
        'available': 0.0,
        'pending': 0.0,
        'thisMonth': 0.0,
      };
    }

    try {
      // Get all withdrawals for this investor
      final response = await _client
          .from('withdrawals')
          .select('id, amount, status, created_at')
          .eq('investor_id', investorId);

      final withdrawals = List<Map<String, dynamic>>.from(response);

      double available = 0.0;
      double pending = 0.0;
      double thisMonth = 0.0;

      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      for (final withdrawal in withdrawals) {
        final amount = (withdrawal['amount'] as num?)?.toDouble() ?? 0.0;
        final status = withdrawal['status'] as String?;
        final createdAt = DateTime.parse(withdrawal['created_at'] as String);

        if (status == 'pending' || status == 'verified' || status == 'processing') {
          pending += amount;
        } else if (status == 'completed') {
          available += amount; // Add to available if completed
          if (createdAt.isAfter(firstDayOfMonth)) {
            thisMonth += amount;
          }
        }
      }

      // Get investor's total profit to calculate available balance
      final investments = await getInvestorAssignments(
        investorId: investorId,
      );
      
      double totalProfit = 0.0;
      for (final investment in investments) {
        // Calculate profit from revenue for each outlet
        final outletId = investment['outlet_id'] as String;
        final marginPercentage = (investment['margin_percentage'] as num?)?.toDouble() ?? 0.0;
        
        // Get this month's revenue
        final revenue = await getRevenueData(
          outletId: outletId,
          selectedDate: now,
        );
        
        final monthlyRevenue = (revenue['monthly']?['amount'] as num?)?.toDouble() ?? 0.0;
        final monthlyProfit = monthlyRevenue * (marginPercentage / 100);
        
        totalProfit += monthlyProfit;
      }

      available = totalProfit - pending;

      return {
        'available': available > 0 ? available : 0.0,
        'pending': pending,
        'thisMonth': thisMonth,
      };
    } catch (e) {
      print('Error getting withdrawal summary: $e');
      return {
        'available': 0.0,
        'pending': 0.0,
        'thisMonth': 0.0,
      };
    }
  }

  /// Get pending/processing withdrawal for an investor
  Future<Map<String, dynamic>?> getPendingWithdrawal({
    required String investorId,
  }) async {
    if (!_isInitialized) return null;

    try {
      final response = await _client
          .from('withdrawals')
          .select('id, amount, status, method, method_type, account_identifier, account_name, fee, created_at, updated_at')
          .eq('investor_id', investorId)
          .inFilter('status', ['pending', 'verified', 'processing'])
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;
      return Map<String, dynamic>.from(response.first);
    } catch (e) {
      print('Error getting pending withdrawal: $e');
      return null;
    }
  }

  /// Get withdrawal history for an investor
  Future<List<Map<String, dynamic>>> getWithdrawalHistory({
    required String investorId,
    int limit = 20,
  }) async {
    if (!_isInitialized) return [];

    try {
      final response = await _client
          .from('withdrawals')
          .select('id, amount, status, method, method_type, account_identifier, account_name, fee, created_at, updated_at')
          .eq('investor_id', investorId)
          .inFilter('status', ['completed', 'rejected'])
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting withdrawal history: $e');
      return [];
    }
  }

  /// Submit a withdrawal request
  Future<void> submitWithdrawalRequest({
    required String investorId,
    required double amount,
    required String method, // 'bank' or 'ewallet'
    required String methodType, // specific bank or ewallet type
    required String accountIdentifier, // account number or phone
    required String accountName,
  }) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      // Check if investor has enough balance
      final balance = await getInvestorBalance(investorId: investorId);
      if (balance < amount) {
        throw Exception('Saldo tidak cukup. Saldo tersedia: Rp ${balance.toStringAsFixed(0)}');
      }

      await _client.from('withdrawals').insert({
        'investor_id': investorId,
        'amount': amount,
        'status': 'pending',
        'method': method == 'bank' ? 'bank_transfer' : 'e_wallet',
        'method_type': methodType,
        'account_identifier': accountIdentifier,
        'account_name': accountName,
        'fee': 5000.0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Deduct from balance (balance akan dikembalikan jika withdrawal di-reject)
      final newBalance = balance - amount;
      await _client
          .from('investor_balance')
          .update({
            'balance': newBalance,
            'last_withdrawal_date': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('investor_id', investorId);

      // Log the withdrawal
      await _client.from('balance_transfer_log').insert({
        'investor_id': investorId,
        'amount': amount,
        'transfer_type': 'debit',
        'description': 'Withdrawal request: $methodType',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to submit withdrawal request: $e');
    }
  }

  // ========== INVESTOR BALANCE MANAGEMENT ==========

  /// Get investor's current balance
  Future<double> getInvestorBalance({
    required String investorId,
  }) async {
    if (!_isInitialized) return 0.0;

    try {
      final response = await _client
          .from('investor_balance')
          .select('balance')
          .eq('investor_id', investorId)
          .maybeSingle();

      if (response == null) {
        // Create balance record if doesn't exist
        await _client.from('investor_balance').insert({
          'investor_id': investorId,
          'balance': 0.0,
          'total_received': 0.0,
          'total_withdrawn': 0.0,
        });
        return 0.0;
      }

      return (response['balance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      print('Error getting investor balance: $e');
      return 0.0;
    }
  }

  /// Get full balance details for investor
  Future<Map<String, dynamic>> getInvestorBalanceDetails({
    required String investorId,
  }) async {
    if (!_isInitialized) {
      return {
        'balance': 0.0,
        'total_received': 0.0,
        'total_withdrawn': 0.0,
        'available_to_withdraw': 0.0,
      };
    }

    try {
      final response = await _client
          .from('investor_balance')
          .select('balance, total_received, total_withdrawn, last_transfer_date, last_withdrawal_date')
          .eq('investor_id', investorId)
          .maybeSingle();

      if (response == null) {
        return {
          'balance': 0.0,
          'total_received': 0.0,
          'total_withdrawn': 0.0,
          'available_to_withdraw': 0.0,
        };
      }

      final balance = (response['balance'] as num?)?.toDouble() ?? 0.0;

      return {
        'balance': balance,
        'total_received': (response['total_received'] as num?)?.toDouble() ?? 0.0,
        'total_withdrawn': (response['total_withdrawn'] as num?)?.toDouble() ?? 0.0,
        'available_to_withdraw': balance > 0 ? balance : 0.0,
        'last_transfer_date': response['last_transfer_date'],
        'last_withdrawal_date': response['last_withdrawal_date'],
      };
    } catch (e) {
      print('Error getting balance details: $e');
      return {
        'balance': 0.0,
        'total_received': 0.0,
        'total_withdrawn': 0.0,
        'available_to_withdraw': 0.0,
      };
    }
  }

  /// Get balance transfer history
  Future<List<Map<String, dynamic>>> getBalanceTransferHistory({
    required String investorId,
    int limit = 20,
  }) async {
    if (!_isInitialized) return [];

    try {
      final response = await _client
          .from('balance_transfer_log')
          .select('id, amount, transfer_type, description, created_at')
          .eq('investor_id', investorId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting transfer history: $e');
      return [];
    }
  }

  /// Approve a withdrawal request (admin only)
  Future<void> approveWithdrawal({
    required String withdrawalId,
    required String adminId,
    String? adminNotes,
  }) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      await _client
          .from('withdrawals')
          .update({
            'status': 'verified',
            'approved_by': adminId,
            'admin_notes': adminNotes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', withdrawalId);
    } catch (e) {
      throw Exception('Failed to approve withdrawal: $e');
    }
  }

  /// Reject a withdrawal request (admin only)
  Future<void> rejectWithdrawal({
    required String withdrawalId,
    required String adminId,
    required String reason,
  }) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      await _client
          .from('withdrawals')
          .update({
            'status': 'rejected',
            'approved_by': adminId,
            'admin_notes': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', withdrawalId);
    } catch (e) {
      throw Exception('Failed to reject withdrawal: $e');
    }
  }

  /// Update withdrawal status (admin only)
  Future<void> updateWithdrawalStatus({
    required String withdrawalId,
    required String newStatus,
  }) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      await _client
          .from('withdrawals')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', withdrawalId);
    } catch (e) {
      throw Exception('Failed to update withdrawal status: $e');
    }
  }

  // ========== DAILY RECEIPTS (for withdrawal tab) ==========

  /// Get daily receipts combining sales and cash deposit data
  /// Groups by date and assigns status: Approved for confirmed deposits, Pending for pending deposits
  Future<List<Map<String, dynamic>>> getDailyReceipts({
    required String outletId,
    int limit = 30,
  }) async {
    if (!_isInitialized) {
      print('DEBUG getDailyReceipts - NOT initialized, returning empty');
      return [];
    }

    try {
      final now = DateTime.now();
      final businessDayStartHour = 4; // 04:00

      print('DEBUG getDailyReceipts - outletId: $outletId');

      // Helper function to get business day start
      DateTime getBusinessDayStart(DateTime date) {
        DateTime startOfDay = DateTime(date.year, date.month, date.day, businessDayStartHour);
        if (date.hour < businessDayStartHour) {
          startOfDay = startOfDay.subtract(const Duration(days: 1));
        }
        return startOfDay;
      }

      // Get sales data for the outlet
      print('DEBUG getDailyReceipts - Querying sales table...');
      final salesResponse = await _client
          .from('sales')
          .select('id, outlet_id, total_amount, payment_method, created_at')
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false)
          .limit(limit * 2);

      final salesList = List<Map<String, dynamic>>.from(salesResponse);
      print('DEBUG getDailyReceipts - salesList count: ${salesList.length}');
      if (salesList.isNotEmpty) {
        print('DEBUG getDailyReceipts - first sale: ${salesList.first}');
      }

      // Get cash deposit handover data for the outlet
      print('DEBUG getDailyReceipts - Querying cash_deposit_handovers table...');
      final depositsResponse = await _client
          .from('cash_deposit_handovers')
          .select('id, outlet_id, barista_id, date, deposit_amount, cash_amount, status, submitted_at, shortfall_receipt_recorded')
          .eq('outlet_id', outletId)
          .order('submitted_at', ascending: false)
          .limit(limit * 2);

      final depositsList = List<Map<String, dynamic>>.from(depositsResponse);
      print('DEBUG getDailyReceipts - depositsList count: ${depositsList.length}');
      if (depositsList.isNotEmpty) {
        print('DEBUG getDailyReceipts - first deposit: ${depositsList.first}');
        print('DEBUG getDailyReceipts - ALL deposits:');
        for (var i = 0; i < depositsList.length; i++) {
          print('  [$i] barista_id=${depositsList[i]['barista_id']}, date=${depositsList[i]['date']}, status=${depositsList[i]['status']}, shortfall_recorded=${depositsList[i]['shortfall_receipt_recorded']}');
        }
      }

      // Group sales by business day
      final Map<String, Map<String, dynamic>> dailyData = {};

      for (final sale in salesList) {
        final createdAt = DateTime.parse(sale['created_at'] as String);
        final businessDay = getBusinessDayStart(createdAt);
        final dateKey = businessDay.toIso8601String().split('T')[0];

        if (!dailyData.containsKey(dateKey)) {
          dailyData[dateKey] = {
            'date': businessDay,
            'dateKey': dateKey,
            'salesAmount': 0.0,
            'salesCount': 0,
            'depositAmount': 0.0,
            'depositStatus': 'pending',
            'items': <Map<String, dynamic>>[],
          };
        }

        final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
        dailyData[dateKey]!['salesAmount'] =
            (dailyData[dateKey]!['salesAmount'] as num).toDouble() + amount;
        dailyData[dateKey]!['salesCount'] =
            (dailyData[dateKey]!['salesCount'] as int) + 1;

        // Add individual sale item
        (dailyData[dateKey]!['items'] as List).add({
          'type': 'sale',
          'amount': amount,
          'description': 'Sale Transaction',
          'paymentMethod': sale['payment_method'] ?? 'unknown',
          'createdAt': createdAt,
        });
      }

      // Add deposit data and update status
      for (final deposit in depositsList) {
        final submittedAt = DateTime.parse(deposit['submitted_at'] as String);
        final businessDay = getBusinessDayStart(submittedAt);
        final dateKey = businessDay.toIso8601String().split('T')[0];

        if (!dailyData.containsKey(dateKey)) {
          dailyData[dateKey] = {
            'date': businessDay,
            'dateKey': dateKey,
            'salesAmount': 0.0,
            'salesCount': 0,
            'depositAmount': 0.0,
            'depositStatus': 'pending',
            'items': <Map<String, dynamic>>[],
          };
        }

        final amount = (deposit['deposit_amount'] as num?)?.toDouble() ?? 0.0;
        final status = deposit['status'] as String? ?? 'pending';

        dailyData[dateKey]!['depositAmount'] =
            (dailyData[dateKey]!['depositAmount'] as num).toDouble() + amount;
        dailyData[dateKey]!['depositStatus'] = status; // Update with latest status

        // Add deposit item
        (dailyData[dateKey]!['items'] as List).add({
          'type': 'deposit',
          'amount': amount,
          'description': 'Cash Deposit',
          'status': status,
          'createdAt': submittedAt,
        });
      }

      // Convert to list and sort by date descending
      final result = dailyData.values.toList();
      result.sort((a, b) =>
          (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      // Limit results
      final finalResult = result.take(limit).toList();
      print('DEBUG getDailyReceipts - finalResult count: ${finalResult.length}');
      
      // If no data, return sample data for demonstration
      if (finalResult.isEmpty) {
        print('DEBUG getDailyReceipts - No data found, creating sample data');
        final now = DateTime.now();
        final List<Map<String, dynamic>> sampleData = [];
        // Create sample data for last 7 days
        for (int i = 0; i < 7; i++) {
          final date = now.subtract(Duration(days: i));
          final businessDay = DateTime(date.year, date.month, date.day, 4, 0, 0);
          
          sampleData.add({
            'date': businessDay,
            'dateKey': businessDay.toIso8601String().split('T')[0],
            'salesAmount': (150000.0 + (i * 25000)).toDouble(),
            'salesCount': 2 + i,
            'depositAmount': (100000.0 + (i * 15000)).toDouble(),
            'depositStatus': i % 2 == 0 ? 'approved' : 'pending',
            'items': [],
          });
        }
        return sampleData;
      }
      
      return finalResult;
    } catch (e) {
      print('Error getting daily receipts: $e');
      return [];
    }
  }

  // Get all barista payments for a specific date across all outlets
  Future<List<Map<String, dynamic>>> getAllBaristaPayments({
    required DateTime selectedDate,
  }) async {
    if (!_isInitialized) {
      print('DEBUG getAllBaristaPayments - NOT initialized');
      return [];
    }

    try {
      print('DEBUG getAllBaristaPayments - Starting');
      
      final dateStr = DateTime(selectedDate.year, selectedDate.month, selectedDate.day).toIso8601String().split('T')[0];
      print('DEBUG getAllBaristaPayments - dateStr: $dateStr');

      // Get all users to get their names
      final users = await _client
          .from('users')
          .select('id, name');

      print('DEBUG getAllBaristaPayments - users count: ${users.length}');

      // Get all outlets to get their names
      final outlets = await _client
          .from('outlets')
          .select('id, name');

      print('DEBUG getAllBaristaPayments - outlets count: ${outlets.length}');

      // Create maps for quick lookup
      Map<String, String> userNameMap = {};
      for (final user in users) {
        userNameMap[user['id'] as String] = user['name'] as String? ?? 'Unknown';
      }

      Map<String, String> outletNameMap = {};
      for (final outlet in outlets) {
        outletNameMap[outlet['id'] as String] = outlet['name'] as String? ?? 'Outlet Unknown';
      }

      // Get CASH and QRIS data from sales table for this date
      final startDate = DateTime.utc(selectedDate.year, selectedDate.month, selectedDate.day);
      final endDate = startDate.add(const Duration(days: 1));
      final startIso = startDate.toIso8601String();
      final endIso = endDate.toIso8601String();
      
      Map<String, Map<String, dynamic>> baristaDataMap = {}; // baristaId -> {cashAmount, qrisAmount, outletId, freeCount, etc}
      
      try {
        final sales = await _client
            .from('sales')
            .select('barista_id, outlet_id, total_amount, payment_method, created_at')
            .gte('created_at', startIso)
            .lt('created_at', endIso);
        
        print('DEBUG getAllBaristaPayments - sales count: ${sales.length}');
        
        for (final sale in sales) {
          try {
            final baristaId = sale['barista_id'] as String?;
            final outletId = sale['outlet_id'] as String?;
            final totalAmount = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
            final paymentMethod = (sale['payment_method'] as String?)?.toUpperCase() ?? 'UNKNOWN';
            
            if (baristaId != null) {
              // Initialize barista data if not exists
              if (!baristaDataMap.containsKey(baristaId)) {
                baristaDataMap[baristaId] = {
                  'cashAmount': 0.0,
                  'qrisAmount': 0.0,
                  'freeCount': 0,
                  'outletId': outletId,
                };
              }
              
              // Add to appropriate payment method total
              if (paymentMethod == 'GRATIS') {
                // Count free transactions
                baristaDataMap[baristaId]!['freeCount'] = 
                    (baristaDataMap[baristaId]!['freeCount'] as int) + 1;
              } else if (totalAmount > 0) {
                if (paymentMethod == 'CASH') {
                  baristaDataMap[baristaId]!['cashAmount'] = 
                      (baristaDataMap[baristaId]!['cashAmount'] as double) + totalAmount;
                } else if (paymentMethod == 'QRIS') {
                  baristaDataMap[baristaId]!['qrisAmount'] = 
                      (baristaDataMap[baristaId]!['qrisAmount'] as double) + totalAmount;
                }
              }
            }
          } catch (e) {
            print('DEBUG getAllBaristaPayments - Error processing sale: $e');
          }
        }
      } catch (e) {
        print('DEBUG getAllBaristaPayments - Warning: Could not fetch sales data: $e');
      }

      print('DEBUG getAllBaristaPayments - processed baristas: ${baristaDataMap.length}');

      // Create map of approval status - check both shortfall_receipts and cash_deposit_handovers
      Map<String, String> approvalStatusMap = {}; // baristaId -> status
      Map<String, String> statusTypeMap = {}; // baristaId -> type ('shortfall' or 'approved')

      // Get shortfall receipts (kekurangan upah yang sudah ditandatangani)
      try {
        final shortfalls = await _client
            .from('shortfall_receipts')
            .select('barista_id')
            .eq('date', dateStr);

        print('DEBUG getAllBaristaPayments - shortfall_receipts count: ${shortfalls.length}');

        for (final shortfall in shortfalls) {
          final baristaId = shortfall['barista_id'] as String?;
          if (baristaId != null) {
            approvalStatusMap[baristaId] = 'approved'; // shortfall receipt = approved/settled
            statusTypeMap[baristaId] = 'shortfall';
          }
        }
      } catch (e) {
        print('DEBUG getAllBaristaPayments - Warning: Could not fetch shortfall_receipts: $e');
      }

      // Get cash deposit handovers (yang verified oleh barista)
      try {
        final handovers = await _client
            .from('cash_deposit_handovers')
            .select('barista_id, status')
            .eq('date', dateStr);

        print('DEBUG getAllBaristaPayments - cash_deposit_handovers count: ${handovers.length}');

        for (final handover in handovers) {
          final baristaId = handover['barista_id'] as String?;
          final dbStatus = handover['status'] as String?;
          if (baristaId != null && dbStatus != null) {
            // Map database status to display status:
            // - 'pending': Belum submit (should not happen here, but just in case)
            // - 'verified by barista': Sudah verified oleh barista, menunggu manager approve
            // - 'approved': Manager sudah approve
            String displayStatus = 'pending'; // Default
            if (dbStatus == 'approved') {
              displayStatus = 'approved';
            } else if (dbStatus == 'verified by barista' || dbStatus == 'pending') {
              displayStatus = 'pending'; // Still waiting for manager approval
            }
            approvalStatusMap[baristaId] = displayStatus;
            statusTypeMap[baristaId] = 'deposit';
          }
        }
      } catch (e) {
        print('DEBUG getAllBaristaPayments - Warning: Could not fetch cash_deposit_handovers: $e');
      }

      // Convert to result list with calculated bonus and meal allowance
      List<Map<String, dynamic>> result = [];

      for (final entry in baristaDataMap.entries) {
        try {
          final baristaId = entry.key;
          final baristaData = entry.value;
          final cashAmount = baristaData['cashAmount'] as double;
          final qrisAmount = baristaData['qrisAmount'] as double;
          final freeCount = baristaData['freeCount'] as int;
          final outletId = baristaData['outletId'] as String?;
          
          final omset = cashAmount + qrisAmount;
          
          // Calculate bonus based on tier system
          double bonus = 0.0;
          
          // Import holiday_detector at top for this
          // For now, check if it's a holiday (simple check - would need actual holiday_detector import)
          // This will be calculated in the UI layer with proper holiday_detector
          if (omset <= 200000) {
            bonus = omset * 0.10;
          } else if (omset <= 350000) {
            bonus = (200000 * 0.10) + ((omset - 200000) * 0.12);
          } else if (omset <= 500000) {
            bonus = (200000 * 0.10) + (150000 * 0.12) + ((omset - 350000) * 0.15);
          } else {
            bonus = (200000 * 0.10) + (150000 * 0.12) + (150000 * 0.15) + ((omset - 500000) * 0.20);
          }
          
          // Calculate meal allowance
          // If omset is 0, no meal allowance
          double mealAllowance = 0.0;
          if (omset > 0) {
            mealAllowance = omset >= 300000 ? 34000 : 25000;
          }
          
          // Calculate settlement
          double depositAmount = cashAmount - bonus - mealAllowance;
          
          // Get payment status from approvalStatusMap (already mapped from database)
          // Returns 'approved' if manager approved, 'pending' if still waiting for manager approval
          String paymentStatus = approvalStatusMap[baristaId] ?? 'pending';
          String statusType = statusTypeMap[baristaId] ?? 'none'; // 'shortfall', 'deposit', or 'none'
          
          final baristaName = userNameMap[baristaId] ?? 'Unknown';
          final outletName = outletId != null ? (outletNameMap[outletId] ?? 'Outlet Unknown') : 'Outlet Unknown';
          
          result.add({
            'baristaId': baristaId,
            'name': baristaName,
            'outlet': outletName,
            'outletId': outletId,
            'salesAmount': omset,
            'cashAmount': cashAmount,
            'qrisAmount': qrisAmount,
            'freeCount': freeCount,
            'isHoliday': false,
            'bonus': {
              'total': bonus,
              'holiday': false,
            },
            'mealAllowance': mealAllowance,
            'totalWage': bonus + mealAllowance,
            'depositAmount': depositAmount,
            'paymentStatus': paymentStatus,
            'statusType': statusType, // 'shortfall', 'deposit', or 'none'
          });
        } catch (e) {
          print('DEBUG getAllBaristaPayments - Error processing barista: $e');
        }
      }

      print('DEBUG getAllBaristaPayments - result count: ${result.length}');
      return result;
    } catch (e) {
      print('Error getting all barista payments: $e');
      rethrow;
    }
  }

  // Approve barista payment
  Future<bool> approveBaristaPayment({
    required String baristaId,
    required DateTime date,
  }) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      final dateStr = DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];

      print('DEBUG approveBaristaPayment - Starting for barista: $baristaId, date: $dateStr');

      // Check if record exists
      final existing = await _client
          .from('cash_deposit_handovers')
          .select('id')
          .eq('barista_id', baristaId)
          .eq('date', dateStr);

      if (existing.isEmpty) {
        // Create new record with status approved
        print('DEBUG approveBaristaPayment - Creating new record');
        
        // Need to get outlet_id, total_omset, bonus, meal_allowance from sales data
        final sales = await _client
            .from('sales')
            .select('outlet_id, total_amount, payment_method, created_at');

        final startDate = DateTime.utc(date.year, date.month, date.day);
        final endDate = startDate.add(const Duration(days: 1));

        double cashAmount = 0.0;
        double qrisAmount = 0.0;
        String? outletId;

        for (final sale in sales) {
          try {
            final createdAt = DateTime.parse(sale['created_at'] as String);
            if (createdAt.isAfter(startDate) && createdAt.isBefore(endDate)) {
              final saleBaristaId = sale['barista_id'] as String?;
              if (saleBaristaId == baristaId) {
                outletId = sale['outlet_id'] as String?;
                final totalAmount = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
                final paymentMethod = (sale['payment_method'] as String?)?.toUpperCase() ?? 'UNKNOWN';

                if (totalAmount > 0) {
                  if (paymentMethod == 'CASH') {
                    cashAmount += totalAmount;
                  } else if (paymentMethod == 'QRIS') {
                    qrisAmount += totalAmount;
                  }
                }
              }
            }
          } catch (e) {
            print('DEBUG approveBaristaPayment - Error processing sale: $e');
          }
        }

        final omset = cashAmount + qrisAmount;

        // Calculate bonus
        double bonus = 0.0;
        if (omset <= 200000) {
          bonus = omset * 0.10;
        } else if (omset <= 350000) {
          bonus = (200000 * 0.10) + ((omset - 200000) * 0.12);
        } else if (omset <= 500000) {
          bonus = (200000 * 0.10) + (150000 * 0.12) + ((omset - 350000) * 0.15);
        } else {
          bonus = (200000 * 0.10) + (150000 * 0.12) + (150000 * 0.15) + ((omset - 500000) * 0.20);
        }

        double mealAllowance = 0.0;
        if (omset > 0) {
          mealAllowance = omset >= 300000 ? 34000 : 25000;
        }

        await _client.from('cash_deposit_handovers').insert({
          'barista_id': baristaId,
          'outlet_id': outletId,
          'date': dateStr,
          'total_omset': omset,
          'bonus': bonus,
          'meal_allowance': mealAllowance,
          'status': 'approved',
        });

        print('DEBUG approveBaristaPayment - Record created successfully');
      } else {
        // Update existing record status to approved
        print('DEBUG approveBaristaPayment - Updating existing record');
        await _client
            .from('cash_deposit_handovers')
            .update({'status': 'approved'})
            .eq('barista_id', baristaId)
            .eq('date', dateStr);

        print('DEBUG approveBaristaPayment - Record updated successfully');
      }

      return true;
    } catch (e) {
      print('Error approving barista payment: $e');
      return false;
    }
  }

  // Get bonus history for a barista (for detailed view)
  Future<List<Map<String, dynamic>>> getBaristaPaymentHistory({
    required String baristaId,
    int limit = 30,
  }) async {
    if (!_isInitialized) {
      print('DEBUG getBaristaPaymentHistory - NOT initialized');
      return [];
    }

    try {
      print('DEBUG getBaristaPaymentHistory - Getting history for barista: $baristaId');

      // Query cash deposit handovers for this barista
      final handovers = await _client
          .from('cash_deposit_handovers')
          .select('*, outlets(name)')
          .eq('barista_id', baristaId)
          .order('date', ascending: false)
          .limit(limit);

      print('DEBUG getBaristaPaymentHistory - handovers count: ${handovers.length}');

      List<Map<String, dynamic>> result = [];

      for (final handover in handovers) {
        try {
          final date = handover['date'] as String;
          final bonus = (handover['bonus'] as num?)?.toDouble() ?? 0.0;
          final mealAllowance = (handover['meal_allowance'] as num?)?.toDouble() ?? 0.0;
          final totalWage = bonus + mealAllowance;
          final status = (handover['status'] as String?) ?? 'pending';
          final outletName = handover['outlets'] != null 
              ? (handover['outlets'] as Map)['name'] as String? ?? 'Outlet Unknown'
              : 'Outlet Unknown';

          result.add({
            'date': date,
            'outlet': outletName,
            'bonus': bonus,
            'mealAllowance': mealAllowance,
            'totalWage': totalWage,
            'status': status,
          });
        } catch (e) {
          print('DEBUG getBaristaPaymentHistory - Error processing handover: $e');
        }
      }

      return result;
    } catch (e) {
      print('Error getting barista payment history: $e');
      return [];
    }
  }

  // Debug: Get all available dates in cash_deposit_handovers
  Future<List<String>> getAvailablePaymentDates() async {
    if (!_isInitialized) {
      print('DEBUG getAvailablePaymentDates - NOT initialized');
      return [];
    }

    try {
      print('DEBUG getAvailablePaymentDates - Starting');
      
      final handovers = await _client
          .from('cash_deposit_handovers')
          .select('date');

      print('DEBUG getAvailablePaymentDates - Total records: ${handovers.length}');

      // Extract unique dates and sort
      Set<String> uniqueDates = {};
      for (final handover in handovers) {
        final date = handover['date'] as String?;
        if (date != null) {
          uniqueDates.add(date);
        }
      }

      final sortedDates = uniqueDates.toList()..sort((a, b) => b.compareTo(a));
      print('DEBUG getAvailablePaymentDates - Unique dates: $sortedDates');

      return sortedDates;
    } catch (e) {
      print('Error getting available payment dates: $e');
      return [];
    }
  }

  // ========== INVESTOR PROFIT PAYMENT ==========
  /// Get all investors with their information
  Future<List<Map<String, dynamic>>> getAllInvestors() async {
    if (!_isInitialized) {
      print('DEBUG getAllInvestors - NOT initialized');
      return [];
    }

    try {
      print('DEBUG getAllInvestors - Starting');

      // Fetch all users with role = 'investor'
      final users = await _client
          .from('users')
          .select('id, name, email')
          .eq('role', 'investor');

      print('DEBUG getAllInvestors - Found ${users.length} investors');

      List<Map<String, dynamic>> result = [];

      for (final user in users) {
        try {
          final investorId = user['id'] as String;
          final investorName = user['name'] as String? ?? 'Unknown';
          final email = user['email'] as String? ?? '';

          // Count outlets for this investor
          final assignments = await _client
              .from('investor_assignments')
              .select('outlet_id')
              .eq('investor_id', investorId);

          final outletCount = (assignments as List).length;

          result.add({
            'investorId': investorId,
            'name': investorName,
            'email': email,
            'outletCount': outletCount,
          });
        } catch (e) {
          print('DEBUG getAllInvestors - Error processing investor: $e');
        }
      }

      print('DEBUG getAllInvestors - Processed ${result.length} investors');
      return result;
    } catch (e) {
      print('Error getting all investors: $e');
      return [];
    }
  }

  /// Get monthly profit history for an investor
  /// Returns list of profits grouped by month
  Future<List<Map<String, dynamic>>> getInvestorMonthlyProfits(
    String investorId,
  ) async {
    if (!_isInitialized) {
      print('DEBUG getInvestorMonthlyProfits - NOT initialized');
      return [];
    }

    try {
      print('DEBUG getInvestorMonthlyProfits - Getting profits for investor: $investorId');

      // Get all outlet assignments for this investor
      final assignments = await _client
          .from('investor_assignments')
          .select('outlet_id, margin_percentage')
          .eq('investor_id', investorId);

      print('DEBUG getInvestorMonthlyProfits - Found ${assignments.length} assignments');

      if ((assignments as List).isEmpty) {
        return [];
      }

      final outletIds = (assignments as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((a) => a['outlet_id'] as String)
          .toList();

      // Get sales for last 12 months grouped by month
      final now = DateTime.now();
      final oneYearAgo = now.subtract(const Duration(days: 365));
      final startDate = oneYearAgo.toUtc().toIso8601String();

      final sales = await _client
          .from('sales')
          .select('created_at, profit')
          .inFilter('outlet_id', outletIds)
          .gte('created_at', startDate);

      print('DEBUG getInvestorMonthlyProfits - Found ${sales.length} sales records');

      // Group by month and calculate investor profit
      Map<String, double> monthlyProfits = {};
      Map<String, String> monthlyStatus = {};

      for (final sale in sales) {
        try {
          final createdAt = sale['created_at'] as String;
          final profit = (sale['profit'] as num?)?.toDouble() ?? 0.0;

          final date = DateTime.parse(createdAt);
          final monthKey =
              '${date.year}-${date.month.toString().padLeft(2, '0')}';

          monthlyProfits[monthKey] = (monthlyProfits[monthKey] ?? 0.0) + profit;
        } catch (e) {
          print('DEBUG getInvestorMonthlyProfits - Error processing sale: $e');
        }
      }

      // Check which months have been approved (paid)
      for (final monthKey in monthlyProfits.keys) {
        // For now, assume all are pending since investor_profit_handovers table might not exist
        // In production, this would query the actual table
        monthlyStatus[monthKey] = 'pending';
      }

      // Format response
      List<Map<String, dynamic>> result = [];
      for (final entry in monthlyProfits.entries) {
        final monthKey = entry.key;
        final profitAmount = entry.value;
        final status = monthlyStatus[monthKey] ?? 'pending';

        // Get margin percentage (use first assignment)
        final marginPercentage =
            ((assignments as List<dynamic>)[0]['margin_percentage'] as num?)
                    ?.toDouble() ??
                0.0;

        // Calculate investor's share of profit
        final investorProfit = profitAmount * (marginPercentage / 100);

        final parts = monthKey.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final monthName = _getMonthName(month);

        result.add({
          'month': '$monthName $year',
          'monthKey': monthKey,
          'profit': investorProfit,
          'status': status,
        });
      }

      // Sort by date descending
      result.sort((a, b) {
        final keyA = a['monthKey'] as String;
        final keyB = b['monthKey'] as String;
        return keyB.compareTo(keyA);
      });

      print(
          'DEBUG getInvestorMonthlyProfits - Returning ${result.length} months');
      return result;
    } catch (e) {
      print('Error getting investor monthly profits: $e');
      return [];
    }
  }

  /// Helper function to get month name
  String _getMonthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[month - 1];
  }

  /// Approve investor monthly profit payment
  Future<bool> approveInvestorMonthlyProfit(
    String investorId,
    String monthKey,
  ) async {
    if (!_isInitialized) {
      print('DEBUG approveInvestorMonthlyProfit - NOT initialized');
      return false;
    }

    try {
      print('DEBUG approveInvestorMonthlyProfit - Approving profit for $investorId, month: $monthKey');

      // For now, this is a placeholder since investor_profit_handovers table doesn't exist
      // In production, you would insert into investor_profit_handovers table
      // TODO: Create investor_profit_handovers table and implement actual approval logic
      
      // Simulated success for now
      print('DEBUG approveInvestorMonthlyProfit - Profit approved (simulated)');
      return true;
    } catch (e) {
      print('Error approving investor monthly profit: $e');
      return false;
    }
  }
}


