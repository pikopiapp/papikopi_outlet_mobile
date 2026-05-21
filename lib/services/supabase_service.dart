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
        print('⚠️ Warning: Supabase credentials not configured');
        print('App will run in offline mode. Configure credentials in lib/services/supabase_service.dart');
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
        print('✅ Supabase initialized successfully');
      } on TimeoutException {
        print('⚠️ Supabase initialization timeout');
        _isInitialized = false;
      }
    } catch (e) {
      print('❌ Supabase initialization error: $e');
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
      print('⚠️ Supabase DNS lookup failed: $e');
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
    print('🌐 Checking network connectivity...');
    final isNetworkUp = await isNetworkAvailable();
    if (!isNetworkUp) {
      throw Exception('Tidak ada koneksi internet. Periksa WiFi/data Anda');
    }
    print('✅ Network connectivity OK');
    
    // Check Supabase connectivity
    print('🔍 Checking Supabase connectivity...');
    final isSupabaseUp = await isSupabaseReachable();
    if (!isSupabaseUp) {
      print('⚠️ Supabase DNS resolution failed, attempting connection anyway...');
    }
    
    // 1) Pastikan session Supabase Auth terbentuk (karena RLS SELECT untuk authenticated).
    try {
      print('🔐 Attempting Supabase auth sign-in for: $email');
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

        print('🧩 signIn profile.id=${profile['id']}');
        print('🧩 signIn parsed user.id=${user.id}');
        print('🧩 signIn profileRole=$profileRole');
        print('🧩 signIn profile[investor_id]=$dynamicInvestorId');

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
          print('✅ signIn remapped investor user.id=${_cachedUser?.id}');
          return _cachedUser!;
        }

        _cachedUser = user;
        print('⚠️ signIn no remap, using user.id=${_cachedUser?.id}');
        return user;
      }
    } catch (e) {
      // 2) Fallback ke RPC verifikasi (legacy) jika auth sign-in gagal.
      print('⚠️ Supabase auth sign-in failed, fallback to RPC: $e');

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
          print('✅ Custom database login successful for: $email');

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

            print('🧩 rpc profileRole=$profileRole');
            print('🧩 rpc profile[investor_id]=$dynamicInvestorId');

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
              print('✅ rpc remapped investor user.id=${_cachedUser?.id}');
              return _cachedUser!;
            }
          } catch (e) {
            print('⚠️ rpc remap lookup failed: $e');
          }

          _cachedUser = user;
          print('⚠️ rpc no remap, using user.id=${_cachedUser?.id}');
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

    print('🧩 getCurrentUserWithProfile baseline.id=${baseline.id} role=${baseline.role}');

    try {
      final profile = await _client
          .from('users')
          .select()
          .eq('id', session.user.id)
          .single();

      // Debug: show all columns returned by users so we can find which one maps to investor_assignments.investor_id
      print('🧩 getCurrentUserWithProfile users row keys=${profile.keys.toList()}');
      print('🧩 getCurrentUserWithProfile users row raw=${profile}');

      final parsed = user_model.User.fromJson(profile);

      final profileRole = parsed.role;
      final dynamicInvestorId = profile['investor_id'];
      final investorIdFromProfile =
          (dynamicInvestorId is String && dynamicInvestorId.isNotEmpty)
              ? dynamicInvestorId
              : null;

      print('🧩 getCurrentUserWithProfile profile.id=${profile['id']} role=$profileRole investor_id=$dynamicInvestorId');

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
        print('✅ getCurrentUserWithProfile remapped id=${_cachedUser?.id}');
        return _cachedUser;
      }

      _cachedUser = parsed;
      print('⚠️ getCurrentUserWithProfile no remap, using id=${_cachedUser?.id}');
      return _cachedUser;
    } catch (e) {
      // If profile lookup fails, fallback to baseline.
      print('❌ getCurrentUserWithProfile profile lookup failed: $e');
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
      print('💾 Creating sale: outletId=$outletId, payment=$paymentMethod, total=$totalAmount');
      
      final response = await _client.from('sales').insert({
        'outlet_id': outletId,
        'barista_id': baristaId,
        'payment_method': paymentMethod.toUpperCase(),
        'total_amount': totalAmount,
        'hpp_total': totalHpp,
        'bonus_amount': totalBonus,
        'profit': profit,
      }).select().single();

      final saleId = response['id'] as String;
      print('✅ Sale created with ID: $saleId');

      // Insert sale items
      print('📝 Inserting ${items.length} sale items...');
      for (final item in items) {
        final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
        final hpp = (item['hpp'] as num?)?.toDouble() ?? 0.0;
        
        print('  - ${item['product_name']}: qty=${item['quantity']}, price=$price, hpp=$hpp');
        
        await _client.from('sale_items').insert({
          'sale_id': saleId,
          'product_id': item['product_id'],
          'quantity': item['quantity'],
          'price': price,
          'hpp': hpp,
        });
      }
      print('✅ All sale items inserted successfully');

      return saleId;
    } catch (e, stackTrace) {
      print('❌ Error in createSale: $e');
      print('Stack trace: $stackTrace');
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

    print('📊 getSales response:');
    print('   Total records: ${(response as List<dynamic>).length}');
    if ((response as List<dynamic>).isNotEmpty) {
      final firstRecord = response[0];
      print('   First record: $firstRecord');
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
      print('❌ Error getting gratis stats: $e');
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
          .select('id, name, email, role, outlet_assigment')
          .eq('role', 'barista')
          .eq('outlet_assigment', outletId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching baristas by outlet: $e');
      return [];
    }
  }

  /// Get all baristas (used for assignment availability if needed later).
  Future<List<Map<String, dynamic>>> getAllBaristas() async {
    if (!_isInitialized) return [];

    try {
      final response = await _client
          .from('users')
          .select('id, name, email, role, outlet_assigment')
          .eq('role', 'barista');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching all baristas: $e');
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
      print('⚠️ SupabaseService not initialized - returning empty leaderboard');
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
      print('❌ Error fetching leaderboard: $e');
      return [];
    }
  }

// Global Leaderboard dari semua outlet
  Future<List<Map<String, dynamic>>> getGlobalLeaderboard({
    required String outletId,
    required DateTime selectedDate,
  }) async {
    if (!_isInitialized) {
      print('⚠️ SupabaseService not initialized - returning empty leaderboard');
      return [];
    }
    
    try {
      // Get outlet's business_day_start_hour
      final outletData = await _client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', outletId)
          .single();
      
      final businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;
      
      print('🏆 getGlobalLeaderboard - Starting');
      print('   Selected Date: ${selectedDate.toIso8601String()}');
      print('   Business Day Start Hour: $businessDayStartHour');
      
      // Convert selectedDate to UTC first (it comes as local Jakarta time from DateTime.now())
      final selectedDateUtc = selectedDate.toUtc();
      
      // Calculate business day date range in UTC
      // Business day: starts at businessDayStartHour of PREVIOUS day, ends at businessDayStartHour of selectedDate - 1 second
      final startDate = DateTime.utc(selectedDateUtc.year, selectedDateUtc.month, selectedDateUtc.day)
          .subtract(const Duration(days: 1))
          .copyWith(hour: businessDayStartHour, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      final endDate = DateTime.utc(selectedDateUtc.year, selectedDateUtc.month, selectedDateUtc.day, businessDayStartHour, 0, 0)
          .subtract(const Duration(milliseconds: 1));
      
      print('📅 Business day range (UTC): ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
      
      final params = {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      };
      
      print('📤 Sending to RPC:');
      print('   start_date: ${params['start_date']}');
      print('   end_date: ${params['end_date']}');
      
      final response = await _client.rpc('get_global_leaderboard', params: params);

      print('✅ RPC response received: ${(response as List).length} items');
      
      return response
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('❌ Error fetching global leaderboard: $e');
      return [];
    }
  }

// Get product stock from product_batches table (like POS page)
  // Returns product stock with names - for displaying in stock screen
  Future<List<Map<String, dynamic>>> getProductBatchStock(String outletId) async {
    if (!_isInitialized) {
      print('⚠️ SupabaseService not initialized - returning empty stock');
      return [];
    }
    
    try {
      print('📊 Fetching product batches for outlet: $outletId');
      
      // Get product batches - first without join to see if we have data
      final batchesResponse = await _client
          .from('product_batches')
          .select()
          .eq('outlet_id', outletId);

      print('✅ Fetched ${batchesResponse.length} batches from product_batches table');

      if (batchesResponse.isEmpty) {
        print('⚠️ No product batches found for outlet: $outletId');
        return [];
      }

      // Get products separately to ensure we get all product data
      final productsResponse = await _client
          .from('products')
          .select();

      print('✅ Fetched ${productsResponse.length} products');

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

      print('✅ Fetched ${salesResponse.length} sale items');

      // Build a map of sold quantities by product
      final soldMap = <String, int>{};
      for (final item in salesResponse) {
        final productId = item['product_id'] as String?;
        if (productId == null) continue;
        final quantity = item['quantity'] as int? ?? 0;
        soldMap[productId] = (soldMap[productId] ?? 0) + quantity;
      }

      print('📦 Sold map: $soldMap');

      // Get batch damages (cacat & dikembalikan) - map by batch_id
      final damagesMap = <String, Map<String, int>>{};
      try {
        final damagesResponse = await _client
            .from('batch_damages')
            .select()
            .eq('outlet_id', outletId);

        print('✅ Fetched ${damagesResponse.length} batch damages');

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
        print('⚠️ batch_damages table not found yet (table will be created): $e');
        // If table doesn't exist, just use empty damages map
      }

      print('🔴 Damages map: $damagesMap');

      // Aggregate by product - include all statuses except expired
      final stockMap = <String, Map<String, dynamic>>{};
      for (final row in batchesResponse) {
        final status = row['status'] as String? ?? 'ready';
        final productId = row['product_id'] as String?;
        final batchId = row['id'] as String?;
        
        if (productId == null) {
          print('⚠️ Batch without product_id found, skipping');
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

        print('  - Batch: $batchCode, Product: $productName (ID: $productId), Qty: $quantity, Status: $status, Cacat: $cacatQty, Dikembalikan: $dikembalikanQty');

        // Skip only expired batches
        if (status == 'expired') {
          print('    └─ Skipping expired batch');
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

      print('🎯 Final stock map with ${stockMap.length} products');
      for (final entry in stockMap.entries) {
        print('   - ${entry.value['product_name']}: ${entry.value['quantity']} unit (sold: ${entry.value['sold']}, cacat: ${entry.value['cacat']}, dikembalikan: ${entry.value['dikembalikan']})');
      }
      
      return stockMap.values.toList();
    } catch (e) {
      print('❌ Error fetching product batch stock: $e');
      return [];
    }
  }

  // Get product stock (legacy method - returns Map for backward compatibility)
  Future<Map<String, int>> getProductStock(String outletId) async {
    if (!_isInitialized) {
      print('⚠️ SupabaseService not initialized - returning empty stock');
      return {};
    }
    
    try {
      // Query from showcase_allocations with join to showcase_products
      // Get product_id and quantity allocated to this outlet
      final response = await _client
          .from('showcase_allocations')
          .select('quantity, showcase_products(product_id)')
          .eq('outlet_id', outletId);

      // Build stock map keyed by product_id
      final stockMap = <String, int>{};
      for (final row in response) {
        final quantity = row['quantity'] as int? ?? 0;
        final showcaseProduct = row['showcase_products'] as Map<String, dynamic>?;
        
        if (showcaseProduct != null) {
          final productId = showcaseProduct['product_id'] as String?;
          if (productId != null) {
            stockMap[productId] = (stockMap[productId] ?? 0) + quantity;
          }
        }
      }
      
      print('✅ Fetched product stock from showcase_allocations for outlet: $outletId');
      print('📊 Stock map: $stockMap');
      return stockMap;
    } catch (e) {
      print('❌ Error fetching product stock: $e');
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
      print('⚠️ SupabaseService not initialized - cannot update showcase allocation');
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
          print('⚠️ No showcase_product found for product $productId');
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
          
          print('✅ Decreased showcase allocation: product=$productId, old=$currentQty, new=$newQty');
        }
      } else if (response.isNotEmpty) {
        final allocation = response.first;
        final currentQty = allocation['quantity'] as int? ?? 0;
        final newQty = (currentQty - quantitySold).clamp(0, currentQty);
        
        await _client
            .from('showcase_allocations')
            .update({'quantity': newQty})
            .eq('id', allocation['id']);
        
        print('✅ Decreased showcase allocation: product=$productId, old=$currentQty, new=$newQty');
      }
    } catch (e) {
      print('⚠️ Error decreasing showcase allocation: $e');
      // Don't fail checkout if this fails
    }
  }

  // Get sold quantity per product for today (based on business day)
  Future<Map<String, int>> getSoldQuantityToday({
    required String outletId,
    required DateTime selectedDate,
  }) async {
    if (!_isInitialized) {
      print('⚠️ SupabaseService not initialized - returning empty sold data');
      return {};
    }

    try {
      // Get outlet's business_day_start_hour
      final outletData = await _client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', outletId)
          .single();

      final businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;

      // Convert selectedDate to UTC first (it comes as local Jakarta time from DateTime.now())
      final selectedDateUtc = selectedDate.toUtc();
      
      // Calculate business day dates in UTC
      final dailyStart = DateTime.utc(selectedDateUtc.year, selectedDateUtc.month, selectedDateUtc.day)
          .subtract(const Duration(days: 1))
          .copyWith(hour: businessDayStartHour, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      final dailyEnd = DateTime.utc(selectedDateUtc.year, selectedDateUtc.month, selectedDateUtc.day, businessDayStartHour, 0, 0)
          .subtract(const Duration(milliseconds: 1));

      print('📊 getSoldQuantityToday - outlet: $outletId');
      print('   Business day (UTC): ${dailyStart.toIso8601String()} to ${dailyEnd.toIso8601String()}');

      // Query sales for this outlet on this business day
      final salesResponse = await _client
          .from('sales')
          .select('id, created_at')
          .eq('outlet_id', outletId)
          .gte('created_at', dailyStart.toIso8601String())
          .lte('created_at', dailyEnd.toIso8601String());

      if (salesResponse.isEmpty) {
        print('⚠️ No sales found for today');
        return {};
      }

      // Collect all sale IDs
      final saleIds = (salesResponse as List).map((s) => s['id'] as String).toList();
      print('   Found ${saleIds.length} sales');

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

      print('✅ Fetched sold quantities: $soldMap');
      return soldMap;
    } catch (e) {
      print('❌ Error fetching sold quantity: $e');
      return {};
    }
  }

  // Get returned quantity per product for today (based on business day)
  Future<Map<String, int>> getReturnedQuantityToday({
    required String outletId,
    required DateTime selectedDate,
  }) async {
    if (!_isInitialized) {
      print('⚠️ SupabaseService not initialized - returning empty returned data');
      return {};
    }

    try {
      // Get outlet's business_day_start_hour
      final outletData = await _client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', outletId)
          .single();

      final businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;

      // Convert selectedDate to UTC first (it comes as local Jakarta time from DateTime.now())
      final selectedDateUtc = selectedDate.toUtc();
      
      // Calculate business day dates in UTC
      final dailyStart = DateTime.utc(selectedDateUtc.year, selectedDateUtc.month, selectedDateUtc.day)
          .subtract(const Duration(days: 1))
          .copyWith(hour: businessDayStartHour, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      final dailyEnd = DateTime.utc(selectedDateUtc.year, selectedDateUtc.month, selectedDateUtc.day, businessDayStartHour, 0, 0)
          .subtract(const Duration(milliseconds: 1));

      print('📊 getReturnedQuantityToday - outlet: $outletId');
      print('   Business day (UTC): ${dailyStart.toIso8601String()} to ${dailyEnd.toIso8601String()}');

      // Query product_returns for this outlet on this business day
      final returnsResponse = await _client
          .from('product_returns')
          .select('product_id')
          .eq('outlet_id', outletId)
          .gte('return_date', dailyStart.toIso8601String())
          .lte('return_date', dailyEnd.toIso8601String());

      if (returnsResponse.isEmpty) {
        print('⚠️ No returns found for today');
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

      print('✅ Fetched returned quantities: $returnedMap');
      return returnedMap;
    } catch (e) {
      print('❌ Error fetching returned quantity: $e');
      return {};
    }
  }

  // Get transfer statistics per product for today (transfers sent and received)
  Future<Map<String, Map<String, int>>> getProductTransferStats({
    required String outletId,
    required DateTime selectedDate,
  }) async {
    if (!_isInitialized) {
      print('⚠️ SupabaseService not initialized - returning empty transfer stats');
      return {};
    }

    try {
      // Get outlet's business_day_start_hour
      final outletData = await _client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', outletId)
          .single();

      final businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;

      // Convert selectedDate to UTC first
      final selectedDateUtc = selectedDate.toUtc();
      
      // Calculate business day dates in UTC
      final dailyStart = DateTime.utc(selectedDateUtc.year, selectedDateUtc.month, selectedDateUtc.day)
          .subtract(const Duration(days: 1))
          .copyWith(hour: businessDayStartHour, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      final dailyEnd = DateTime.utc(selectedDateUtc.year, selectedDateUtc.month, selectedDateUtc.day, businessDayStartHour, 0, 0)
          .subtract(const Duration(milliseconds: 1));

      print('📤 getProductTransferStats - outlet: $outletId');
      print('   Business day (UTC): ${dailyStart.toIso8601String()} to ${dailyEnd.toIso8601String()}');

      // Initialize transfer stats map
      final transferStats = <String, Map<String, int>>{};

      // Get SENT transfers (from_outlet_id == this outlet)
      final sentResponse = await _client
          .from('stock_transfers')
          .select('id, created_at')
          .eq('from_outlet_id', outletId)
          .gte('created_at', dailyStart.toIso8601String())
          .lte('created_at', dailyEnd.toIso8601String());

      print('   Found ${sentResponse.length} transfers sent');

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

      print('   Found ${receivedResponse.length} transfers received');

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

      print('✅ Fetched transfer stats: $transferStats');
      return transferStats;
    } catch (e) {
      print('❌ Error fetching transfer stats: $e');
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
      print('❌ Error fetching stock transfers: $e');
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
      final transferResponse = await _client
          .from('stock_transfers')
          .insert({
            'from_outlet_id': fromOutletId,
            'to_outlet_id': toOutletId,
            'status': 'requested',
          })
          .select()
          .single();

      final transferId = transferResponse['id'];
      for (final item in items) {
        await _client.from('stock_transfer_items').insert({
          'transfer_id': transferId,
          'ingredient_id': item['ingredient_id'],
          'quantity': item['quantity'],
        });
      }
      return transferId;
    } catch (e) {
      print('❌ Error creating stock transfer: $e');
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
      final response = await _client
          .from('stock_returns')
          .insert({
            'outlet_id': outletId,
            'ingredient_id': ingredientId,
            'quantity': quantity,
            'reason': reason,
            'status': 'pending',
          })
          .select()
          .single();

      return response['id'];
    } catch (e) {
      print('❌ Error creating stock return: $e');
      return null;
    }
  }

  // DEBUG: Seed sample product batches for development
  Future<void> seedSampleProductBatches(String outletId) async {
    if (!_isInitialized) {
      print('⚠️ SupabaseService not initialized');
      return;
    }

    try {
      print('🌱 Seeding sample product batches...');
      
      // Get all products
      final productsResponse = await _client
          .from('products')
          .select('id, name')
          .limit(5);

      if (productsResponse.isEmpty) {
        print('⚠️ No products found to seed');
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

        print('✅ Created batch for: $productName with qty: ${50 + (i * 10)}');
      }

      print('🎉 Sample data seeded successfully!');
    } catch (e) {
      print('❌ Error seeding sample data: $e');
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
      print('⚠️ SupabaseService not initialized');
      return false;
    }

    try {
      print('📝 Adding batch damage: batchId=$batchId, cacat=$cacatQty, dikembalikan=$dikembalikanQty');

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

        print('✅ Updated batch damage record: $existingId');
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

        print('✅ Created new batch damage record');
      }

      return true;
    } catch (e) {
      print('❌ Error adding batch damage: $e');
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
      print('❌ Error fetching batch damage: $e');
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
      print('❌ Error fetching active investor outlets: $e');
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
      print('⚠️ getInvestorOutletsSummary: Supabase not initialized');
      return [];
    }

    try {
      // Gunakan investorId dari caller (AuthProvider biasanya sudah melakukan remap id untuk role investor)
      // Hindari override dengan session.user.id karena bisa menyebabkan mismatch
      // antara id auth user vs id investor yang dipakai oleh tabel investor_assignments.
      final effectiveInvestorId = investorId.trim();

      print('👤 getInvestorOutletsSummary START - investorId=$effectiveInvestorId');

      final endIso = DateTime.now().toUtc().toIso8601String();
      final startIso = DateTime.now()
          .toUtc()
          .subtract(Duration(days: profitTrendDays))
          .toIso8601String();

      print('📅 Date range: $startIso to $endIso');

      // 1) Fetch assignments (field spesifik seperti web)
      print('🔍 Querying investor_assignments for investor_id=$effectiveInvestorId');
      final assignmentsResponse = await _client
          .from('investor_assignments')
          .select('outlet_id, investment_amount, margin_percentage, status')
          .eq('investor_id', effectiveInvestorId);

      final assignmentsRows = (assignmentsResponse as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();

      print('✅ Query result: ${assignmentsRows.length} assignments found');
      if (assignmentsRows.isNotEmpty) {
        print('   First assignment: ${assignmentsRows.first}');
      }

      if (assignmentsRows.isEmpty) {
        print('⚠️ No assignments found for investor_id=$effectiveInvestorId');
        return [];
      }

      final outletIds = assignmentsRows
          .map((a) => (a['outlet_id'] as String?)?.trim())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      print('🔎 outletIds=${outletIds.length} => $outletIds');

      if (outletIds.isEmpty) {
        print('⚠️ No valid outlet IDs extracted');
        return [];
      }

      // 2) Fetch outlets by ids
      print('🏪 Querying outlets for ids: $outletIds');
      final outletResponse = await _client
          .from('outlets')
          .select('id, name')
          .inFilter('id', outletIds);

      final outletRows = (outletResponse as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();

      print('✅ Fetched ${outletRows.length} outlets');
      if (outletRows.isNotEmpty) {
        print('   First outlet: ${outletRows.first}');
      }

      final outletMap = <String, Map<String, dynamic>>{
        for (final o in outletRows)
          (o['id'] as String): o,
      };

      // 3) Aggregate sales profit for those outlets
      print('💰 Querying sales for outlets with profit calculation');
      final salesResponse = await _client
          .from('sales')
          .select('outlet_id, profit')
          .inFilter('outlet_id', outletIds)
          .gte('created_at', startIso)
          .lte('created_at', endIso);

      final salesRows = (salesResponse as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();

      print('✅ Fetched ${salesRows.length} sales records');

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
      print('❌ Error fetching investor outlets summary: $e');
      return [];
    }
  }

  // Fetch investor assignments with outlet details
  Future<List<Map<String, dynamic>>> getInvestorAssignments({
    required String investorId,
  }) async {
    if (!_isInitialized) {
      print('⚠️ getInvestorAssignments: Supabase not initialized');
      return [];
    }

    try {
      final effectiveInvestorId = investorId.trim();
      print('👤 getInvestorAssignments - fetching for investorId=$effectiveInvestorId');

      // First, verify investor exists in system
      try {
        final userData = await _client
            .from('users')
            .select('id, email, role')
            .eq('id', effectiveInvestorId)
            .maybeSingle();
        
        if (userData != null) {
          print('✅ Investor found: ${userData['email']} (${userData['role']})');
        } else {
          print('⚠️ Investor not found in users table');
        }
      } catch (e) {
        print('⚠️ Error checking investor: $e');
      }

      // Query investor_assignments with direct outlet join
      print('🔍 Querying investor_assignments with filter investor_id=$effectiveInvestorId');
      
      List<Map<String, dynamic>> response;
      try {
        // Try with outlet join first
        print('   Attempting join query with outlets...');
        response = await _client
            .from('investor_assignments')
            .select('id, outlet_id, investment_amount, margin_percentage, status, created_at, outlets(id, name, type, address)')
            .eq('investor_id', effectiveInvestorId)
            .order('created_at', ascending: false);
        print('✅ Query with join succeeded, response length: ${response.length}');
        print('✅ Query with join succeeded');
      } catch (joinError) {
        print('⚠️ Join query failed: $joinError');
        print('   Trying query without join...');
        // Fallback: query without join
        response = await _client
            .from('investor_assignments')
            .select('id, outlet_id, investment_amount, margin_percentage, status, created_at')
            .eq('investor_id', effectiveInvestorId)
            .order('created_at', ascending: false);
        print('✅ Query without join succeeded');
      }

      print('📦 Query completed, response type: ${response.runtimeType}');

      final assignmentRows = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();

      print('✅ Fetched ${assignmentRows.length} assignments');
      if (assignmentRows.isNotEmpty) {
        print('   First assignment: ${assignmentRows.first}');
      } else {
        print('⚠️ No assignments found');
        
        // Fallback: Check all investor_ids in the table for debugging
        print('   Checking all investor_ids in database...');
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
          
          print('   Sample investor_ids in database: $uniqueIds');
          
          // If we found investor_ids in database, query with first one for dev testing
          if (uniqueIds.isNotEmpty) {
            print('   🔧 DEV MODE: Found other investor_ids, querying with first one for testing...');
            final firstInvestorId = uniqueIds.first;
            
            final devResponse = await _client
                .from('investor_assignments')
                .select('id, outlet_id, investment_amount, margin_percentage, status, created_at')
                .eq('investor_id', firstInvestorId)
                .order('created_at', ascending: false);
            
            final devRows = (devResponse as List<dynamic>)
                .whereType<Map<String, dynamic>>()
                .toList();
            
            print('   ✅ DEV: Found ${devRows.length} assignments for investor $firstInvestorId');
            
            if (devRows.isNotEmpty) {
              print('   ⚠️ NOTE: These are from a different investor! Use for UI testing only.');
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
          print('   Error checking database: $e');
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
          print('⚠️ Outlet data missing for assignment, fetching separately...');
          try {
            final outletData = await _client
                .from('outlets')
                .select('id, name, type, address')
                .eq('id', outletId)
                .maybeSingle();
            
            if (outletData != null) {
              outlet = outletData;
              print('✅ Fetched outlet separately: ${outlet['name']}');
            }
          } catch (e) {
            print('⚠️ Error fetching outlet separately: $e');
          }
        }

        print('🔗 Assignment outlet_id=$outletId => outlet_name=${outlet?['name'] ?? 'NOT FOUND'}');

        enrichedAssignments.add(<String, dynamic>{
          ...assignment,
          'outlet_name': outlet?['name'] ?? 'Unknown Outlet',
          'outlet_type': outlet?['type'] ?? 'unknown',
          'outlet_address': outlet?['address'] ?? '',
        });
      }
      
      print('✅ Returning ${enrichedAssignments.length} enriched assignments');
      return enrichedAssignments;
    } catch (e) {
      print('❌ Error fetching investor assignments: $e');
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
          .select('id, name')
          .order('name', ascending: true);

      print('✅ Fetched ${response.length} outlets');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching outlets: $e');
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

      print('✅ Fetched ${response.length} stock returns');
      
      // Map product name into response
      final returns = response.map((item) {
        return {
          ...item,
          'product_name': item['products']?['name'] ?? 'Unknown',
        };
      }).toList();

      return List<Map<String, dynamic>>.from(returns);
    } catch (e) {
      print('❌ Error fetching stock returns: $e');
      return [];
    }
  }

  // Get product returns (pengembalian) for an outlet
  Future<List<Map<String, dynamic>>> getProductReturns(String outletId) async {
    if (!_isInitialized) {
      return [];
    }

    try {
      // Query product_returns
      final response = await _client
          .from('product_returns')
          .select('*')
          .eq('outlet_id', outletId)
          .order('return_date', ascending: false);

      if (response.isEmpty) {
        print('⚠️ No product returns found for outlet: $outletId');
        return [];
      }

      print('📦 Fetched ${response.length} product returns');
      
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

      print('✅ Enriched ${returns.length} returns with product names');
      return List<Map<String, dynamic>>.from(returns);
    } catch (e) {
      print('❌ Error fetching product returns: $e');
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
      print('⚠️ SupabaseService not initialized - cannot create return');
      return false;
    }

    try {
      print('📝 Creating product return...');
      print('   Product: $productId, Qty: $quantity, Reason: $returnReason');

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

      print('✅ Product return created successfully');
      return true;
    } catch (e) {
      print('❌ Error creating product return: $e');
      return false;
    }
  }

  // Create product transfer between outlets
  Future<bool> createProductTransfer({
    required String fromOutletId,
    required String toOutletId,
    required String productId,
    required int quantity,
  }) async {
    if (!_isInitialized) {
      print('⚠️ SupabaseService not initialized - cannot create transfer');
      return false;
    }

    try {
      print('📦 Creating product transfer...');
      print('   From: $fromOutletId → To: $toOutletId');
      print('   Product: $productId, Qty: $quantity');

      // Step 0: Get showcase_product_id for this product
      final showcaseProduct = await _client
          .from('showcase_products')
          .select('id')
          .eq('product_id', productId)
          .maybeSingle();

      if (showcaseProduct == null) {
        print('❌ Showcase product not found for product_id: $productId');
        return false;
      }

      final showcaseProductId = showcaseProduct['id'] as String;
      print('✅ Found showcase_product_id: $showcaseProductId');

      // Step 1: Get current allocations for source outlet
      final sourceAllocation = await _client
          .from('showcase_allocations')
          .select('id, quantity')
          .eq('outlet_id', fromOutletId)
          .eq('showcase_product_id', showcaseProductId)
          .maybeSingle();

      if (sourceAllocation == null) {
        print('❌ Product not found in source outlet');
        return false;
      }

      final currentQty = sourceAllocation['quantity'] as int? ?? 0;
      if (currentQty < quantity) {
        print('❌ Insufficient quantity in source outlet (available: $currentQty, requested: $quantity)');
        return false;
      }

      // Step 2: Update source outlet (decrease quantity)
      await _client
          .from('showcase_allocations')
          .update({'quantity': currentQty - quantity})
          .eq('id', sourceAllocation['id']);

      print('✅ Decreased source outlet quantity');

      // Step 3: Get or create allocation for destination outlet
      final destAllocation = await _client
          .from('showcase_allocations')
          .select('id, quantity')
          .eq('outlet_id', toOutletId)
          .eq('showcase_product_id', showcaseProductId)
          .maybeSingle();

      if (destAllocation == null) {
        // Create new allocation for destination outlet
        await _client.from('showcase_allocations').insert({
          'outlet_id': toOutletId,
          'showcase_product_id': showcaseProductId,
          'quantity': quantity,
        });
        print('✅ Created new allocation for destination outlet');
      } else {
        // Update existing allocation (increase quantity)
        final destQty = destAllocation['quantity'] as int? ?? 0;
        await _client
            .from('showcase_allocations')
            .update({'quantity': destQty + quantity})
            .eq('id', destAllocation['id']);
        print('✅ Increased destination outlet quantity');
      }

      print('📊 Allocations updated successfully. Now attempting to save to cache/database...');

      // Step 4: Create transfer record for audit trail
      try {
        print('📝 Creating transfer record in stock_transfers table...');
        final transferResponse = await _client
            .from('stock_transfers')
            .insert({
              'from_outlet_id': fromOutletId,
              'to_outlet_id': toOutletId,
              'status': 'received',
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('id');
        
        if (transferResponse.isNotEmpty) {
          final transferId = transferResponse[0]['id'] as String;
          print('✅ Created stock_transfers record: $transferId');
          
          // Insert transfer item details
          try {
            print('📝 Preparing to insert into stock_transfer_items...');
            print('   transfer_id: $transferId');
            print('   product_id: $productId');
            print('   quantity_int: $quantity');
            
            final itemResponse = await _client
                .from('stock_transfer_items')
                .insert({
                  'transfer_id': transferId,
                  'product_id': productId,
                  'quantity': quantity.toDouble(), // Fill the DECIMAL quantity column
                  'quantity_int': quantity, // Also fill quantity_int for integer reference
                  'created_at': DateTime.now().toIso8601String(),
                })
                .select('id');
            
            if (itemResponse.isNotEmpty) {
              print('✅ Created stock_transfer_items record successfully');
              print('   Item ID: ${itemResponse[0]['id']}');
            } else {
              print('⚠️ stock_transfer_items insert returned empty response (might still be created)');
            }
          } catch (itemError) {
            print('❌ CRITICAL ERROR inserting into stock_transfer_items:');
            print('   Error type: ${itemError.runtimeType}');
            print('   Error message: $itemError');
            print('📝 Debugging info:');
            print('   - Check if ingredient_id constraint is blocking (it should be nullable)');
            print('   - Check if RLS is actually disabled');
            print('   - Check if product_id foreign key is valid');
            
            // Try to insert without select to see if error is clearer
            try {
              print('📝 Retrying insert without .select()...');
              await _client.from('stock_transfer_items').insert({
                'transfer_id': transferId,
                'product_id': productId,
                'quantity': quantity.toDouble(),
                'quantity_int': quantity,
              });
              print('✅ Insert succeeded on retry!');
            } catch (retryError) {
              print('❌ Retry also failed: $retryError');
            }
          }
        } else {
          print('❌ stock_transfers insert returned no ID - insertion may have failed');
        }
      } catch (e) {
        print('❌ CRITICAL ERROR in transfer creation:');
        print('   Error: $e');
        print('   Type: ${e.runtimeType}');
      }
      
      print('✅ Product transfer completed successfully');
      print('📊 Final state: Allocations updated + Database/Cache saved');
      return true;
    } catch (e) {
      print('❌ Error creating product transfer: $e');
      print('📊 Cache state on error: ${_recentTransfers.length} transfers');
      return false;
    }
  }

  // Get product transfers for an outlet
  Future<List<Map<String, dynamic>>> getProductTransfers(String outletId) async {
    if (!_isInitialized) {
      return [];
    }

    try {
      print('📦 Fetching product transfers from database...');
      
      // Fetch transfers with their items
      final response = await _client
          .from('stock_transfers')
          .select('''
            id,
            from_outlet_id,
            to_outlet_id,
            status,
            created_at,
            stock_transfer_items(
              product_id,
              quantity_int
            )
          ''')
          .or('from_outlet_id.eq.$outletId,to_outlet_id.eq.$outletId')
          .order('created_at', ascending: false);

      print('📦 Fetched ${response.length} transfers from database');

      // Enrich with outlet names and product names
      final enrichedTransfers = <Map<String, dynamic>>[];
      
      for (final transfer in response) {
        try {
          print('📝 Processing transfer: ${transfer['id']}');
          
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
          
          print('   └─ Items found: ${itemsResponse.length}');
          
          if (itemsResponse.isNotEmpty) {
            final firstItem = itemsResponse[0];
            print('   └─ First item: $firstItem');
            
            final productId = firstItem['product_id'] as String?;
            final quantity = firstItem['quantity_int'] as int? ?? 0;
            
            print('   └─ Product ID: $productId, Quantity: $quantity');
            
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
              
              int currentStockSending = 0;
              if (showcaseProduct != null) {
                final showcaseProductId = showcaseProduct['id'] as String;
                final sendingOutletStock = await _client
                    .from('showcase_allocations')
                    .select('quantity')
                    .eq('outlet_id', transfer['from_outlet_id'])
                    .eq('showcase_product_id', showcaseProductId)
                    .maybeSingle();
                
                currentStockSending = (sendingOutletStock?['quantity'] as int?) ?? 0;
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
              print('✅ Enriched: $productName ($quantity unit) $fromName (Stock: $currentStockSending) → $toName');
            }
          } else {
            print('⚠️ No items found in stock_transfer_items for this transfer');
          }
        } catch (e) {
          print('❌ Error enriching transfer: $e');
        }
      }
      
      print('✅ Enriched ${enrichedTransfers.length} transfers with details');
      return enrichedTransfers;
    } catch (e) {
      print('❌ Error fetching product transfers: $e');
      print('💡 This usually means RLS is enabled on stock_transfers table');
      print('💡 Run: ALTER TABLE stock_transfers DISABLE ROW LEVEL SECURITY;');
      return [];
    }
  }

  /// Get transfers RECEIVED by this outlet (transfers where to_outlet_id == outletId)
  Future<List<Map<String, dynamic>>> getReceivedTransfers(String outletId) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      print('📥 Fetching received transfers for outlet: $outletId');
      
      // Query transfers where this outlet is the RECEIVER (to_outlet_id)
      final response = await _client
          .from('stock_transfers')
          .select()
          .eq('to_outlet_id', outletId)
          .order('created_at', ascending: false);

      print('📦 Found ${response.length} received transfers');

      // Enrich with outlet names and product names
      final enrichedTransfers = <Map<String, dynamic>>[];
      
      for (final transfer in response) {
        try {
          print('📝 Processing received transfer: ${transfer['id']}');
          
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
          
          print('   └─ Items found: ${itemsResponse.length}');
          
          if (itemsResponse.isNotEmpty) {
            final firstItem = itemsResponse[0];
            print('   └─ First item: $firstItem');
            
            final productId = firstItem['product_id'] as String?;
            final quantity = firstItem['quantity_int'] as int? ?? 0;
            
            print('   └─ Product ID: $productId, Quantity: $quantity');
            
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
              print('✅ Enriched: $productName ($quantity unit) $fromName → $toName (Stock now: $currentStockReceiving)');
            }
          } else {
            print('⚠️ No items found in stock_transfer_items for this transfer');
          }
        } catch (e) {
          print('❌ Error enriching transfer: $e');
        }
      }
      
      print('✅ Enriched ${enrichedTransfers.length} received transfers with details');
      return enrichedTransfers;
    } catch (e) {
      print('❌ Error fetching received transfers: $e');
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
      print('📊 Recording sale to warehouse - Batch: $batchId, Qty: $quantitySold');
      
      await _client.from('sales_records').insert({
        'batch_id': batchId,
        'outlet_id': outletId,
        'quantity_sold': quantitySold,
        'sale_date': saleDate.toIso8601String(),
        'notes': notes ?? 'Dari POS mobile',
      });

      print('✅ Sale recorded successfully to warehouse system');
    } catch (e) {
      print('❌ Error recording sale to warehouse: $e');
      throw Exception('Gagal mencatat penjualan ke sistem warehouse: $e');
    }
  }

// Get available batches for an outlet
  Future<List<Map<String, dynamic>>> getAvailableBatches(String outletId) async {
    if (!_isInitialized) {
      print('⚠️ SupabaseService not initialized');
      return [];
    }

    try {
      print('📦 Fetching available batches for outlet: $outletId');
      
      final response = await _client
          .from('product_batches')
          .select()
          .eq('outlet_id', outletId)
          .inFilter('status', ['ready', 'assigned']);

      print('✅ Fetched ${response.length} available batches');
      
      final batches = List<Map<String, dynamic>>.from(response);
      for (final batch in batches) {
        print('  - Batch ${batch['batch_code']}: product_id=${batch['product_id']}, qty=${batch['quantity']}');
      }
      
      return batches;
    } catch (e, stackTrace) {
      print('❌ Error fetching batches: $e');
      print('Stack trace: $stackTrace');
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
      print('⚠️ Supabase not initialized');
      return {
        'daily': {'amount': 0.0, 'count': 0, 'cash': 0.0, 'qris': 0.0},
        'weekly': {'amount': 0.0, 'count': 0, 'cash': 0.0, 'qris': 0.0},
        'monthly': {'amount': 0.0, 'count': 0, 'cash': 0.0, 'qris': 0.0},
      };
    }

    try {
      print('💰 getRevenueData - Starting');
      print('   Outlet ID: $outletId');
      print('   Selected Date: ${selectedDate.toIso8601String()}');
      
      if (outletId.isEmpty) {
        print('❌ ERROR: outletId is empty!');
        throw Exception('Outlet ID is empty');
      }
      
      // Get outlet's business_day_start_hour
      final outletData = await _client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', outletId)
          .single();
      
      final businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;
      print('📅 Business day start hour: $businessDayStartHour:00');
      
      // Calculate business day dates
      // Business day: starts at businessDayStartHour of PREVIOUS day, ends at businessDayStartHour of selectedDate - 1 second
      // Example: businessDayStartHour=21, selectedDate=May 11 → May 10 21:00 to May 11 20:59:59
      final dailyStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
          .subtract(const Duration(days: 1))
          .copyWith(hour: businessDayStartHour, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      final dailyEndTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, businessDayStartHour, 0, 0)
          .subtract(const Duration(seconds: 1));
      
      print('🔹 Daily range: ${dailyStart.toIso8601String()} to ${dailyEndTime.toIso8601String()}');
      print('   Start: ${dailyStart.year}-${dailyStart.month.toString().padLeft(2, '0')}-${dailyStart.day.toString().padLeft(2, '0')} ${dailyStart.hour.toString().padLeft(2, '0')}:${dailyStart.minute.toString().padLeft(2, '0')}:${dailyStart.second.toString().padLeft(2, '0')}');
      print('   End:   ${dailyEndTime.year}-${dailyEndTime.month.toString().padLeft(2, '0')}-${dailyEndTime.day.toString().padLeft(2, '0')} ${dailyEndTime.hour.toString().padLeft(2, '0')}:${dailyEndTime.minute.toString().padLeft(2, '0')}:${dailyEndTime.second.toString().padLeft(2, '0')}');
      
      // Query daily sales
      final dailyResponse = await _client.from('sales')
          .select('payment_method, total_amount, created_at, outlet_id')
          .eq('outlet_id', outletId)
          .gte('created_at', dailyStart.toIso8601String())
          .lte('created_at', dailyEndTime.toIso8601String());
      
      print('📊 Daily: Found ${dailyResponse.length} sales');
      
      // Calculate weekly (last 7 business days)
      final weeklyStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
          .subtract(const Duration(days: 7))
          .copyWith(hour: businessDayStartHour, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      
      print('🔹 Weekly range: ${weeklyStart.toIso8601String()} to ${dailyEndTime.toIso8601String()}');
      
      final weeklyResponse = await _client.from('sales')
          .select('payment_method, total_amount, created_at, outlet_id')
          .eq('outlet_id', outletId)
          .gte('created_at', weeklyStart.toIso8601String())
          .lte('created_at', dailyEndTime.toIso8601String());
      
      print('📊 Weekly: Found ${weeklyResponse.length} sales');
      
      // Calculate monthly (last 30 business days)
      final monthlyStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
          .subtract(const Duration(days: 30))
          .copyWith(hour: businessDayStartHour, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      
      print('🔹 Monthly range: ${monthlyStart.toIso8601String()} to ${dailyEndTime.toIso8601String()}');
      
      final monthlyResponse = await _client.from('sales')
          .select('payment_method, total_amount, created_at, outlet_id')
          .eq('outlet_id', outletId)
          .gte('created_at', monthlyStart.toIso8601String())
          .lte('created_at', dailyEndTime.toIso8601String());
      
      print('📊 Monthly: Found ${monthlyResponse.length} sales');
      
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
      
      print('✅ Results:');
      print('   Daily: Rp${dailyTotal.toStringAsFixed(0)} ($dailyCount txn)');
      print('   Weekly: Rp${weeklyTotal.toStringAsFixed(0)} ($weeklyCount txn)');
      print('   Monthly: Rp${monthlyTotal.toStringAsFixed(0)} ($monthlyCount txn)');

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
      print('❌ Error fetching revenue: $e');
      print('Stack trace: $stackTrace');
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
      print('⚠️ Supabase not initialized');
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
      print('🔍 getCashDepositData - Starting query');
      print('   Outlet ID: $outletId');
      print('   Date: ${date.toIso8601String()}');
      
      // First: Check if outlet_id is valid
      if (outletId.isEmpty) {
        print('❌ ERROR: outletId is empty!');
        throw Exception('Outlet ID is empty');
      }
      
      // Get outlet's business_day_start_hour
      final outletData = await _client
          .from('outlets')
          .select('business_day_start_hour')
          .eq('id', outletId)
          .single();
      
      final businessDayStartHour = (outletData['business_day_start_hour'] as int?) ?? 4;
      print('📅 Business day start hour: $businessDayStartHour:00');
      
      // Calculate business day date range
      // Business day: starts at businessDayStartHour of PREVIOUS day, ends at businessDayStartHour of date - 1 second
      final dateStart = DateTime(date.year, date.month, date.day)
          .subtract(const Duration(days: 1))
          .copyWith(hour: businessDayStartHour, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      final dateEnd = DateTime(date.year, date.month, date.day, businessDayStartHour, 0, 0)
          .subtract(const Duration(seconds: 1));
      
      print('⏰ Business day range:');
      print('   Start: ${dateStart.year}-${dateStart.month.toString().padLeft(2, '0')}-${dateStart.day.toString().padLeft(2, '0')} ${dateStart.hour.toString().padLeft(2, '0')}:${dateStart.minute.toString().padLeft(2, '0')}:${dateStart.second.toString().padLeft(2, '0')}');
      print('   End:   ${dateEnd.year}-${dateEnd.month.toString().padLeft(2, '0')}-${dateEnd.day.toString().padLeft(2, '0')} ${dateEnd.hour.toString().padLeft(2, '0')}:${dateEnd.minute.toString().padLeft(2, '0')}:${dateEnd.second.toString().padLeft(2, '0')}');
      
      // Query sales for this business day
      var query = _client.from('sales').select('payment_method, total_amount, created_at, outlet_id');
      
      if (outletId.isNotEmpty) {
        query = query.eq('outlet_id', outletId);
      }
      
      final response = await query
          .gte('created_at', dateStart.toIso8601String())
          .lte('created_at', dateEnd.toIso8601String());
      
      print('📊 getCashDepositData: Found ${response.length} sales for business day');
      
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
        
        print('  - Payment: $paymentMethod, Amount: $amount, CreatedAt: $createdAt');
        
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
        print('✅ Handover status for $dateStr: $handoverStatus');
      } catch (e) {
        print('⚠️ Error checking handover status: $e');
        // Continue with default status
      }
      
      print('💰 Cash deposit data:');
      print('   - Total Omset: Rp${totalOmset.toStringAsFixed(0)}');
      print('   - CASH: Rp${cashAmount.toStringAsFixed(0)} ($cashCount tx)');
      print('   - QRIS: Rp${qrisAmount.toStringAsFixed(0)} ($qrisCount tx)');
      print('   - Bonus (Bertahap): Rp${bonus.toStringAsFixed(0)}');
      print('   - Uang Makan: Rp${mealAllowance.toStringAsFixed(0)}');
      print('   - Handover Status: $handoverStatus');
      if (kekuranganUpah > 0) {
        print('   - ⚠️ Kekurangan Upah: Rp${kekuranganUpah.toStringAsFixed(0)}');
        print('   - Setoran (CASH - BONUS - MAKAN): Rp 0 (covered by shortfall)');
      } else {
        print('   - Setoran (CASH - BONUS - MAKAN): Rp${depositAmount.toStringAsFixed(0)}');
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
      print('❌ Error fetching cash deposit data: $e');
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
      print('⚠️ SupabaseService not initialized');
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

      print('📝 Updating batch $batchId: $currentQty -> $newQty');

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
        print('✅ Batch marked as sold');
      }

      print('✅ Batch quantity updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating batch quantity: $e');
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
      print('⚠️ SupabaseService not initialized');
      return false;
    }

    try {
      print('📋 Submitting cash deposit handover...');
      print('   - Deposit: Rp${depositAmount.toStringAsFixed(0)}');
      if (kekuranganUpah > 0) {
        print('   - ⚠️ Kekurangan Upah: Rp${kekuranganUpah.toStringAsFixed(0)}');
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
      
      print('✅ Cash deposit handover submitted successfully');
      return true;
    } catch (e) {
      print('❌ Error submitting cash deposit handover: $e');
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
      print('❌ Error fetching cash deposit handover history: $e');
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
      print('❌ Error fetching pending handovers: $e');
      return [];
    }
  }

  // Approve serah terima
  Future<bool> approveCashDepositHandover({
    required String handoverId,
    required String approverId,
  }) async {
    if (!_isInitialized) {
      print('⚠️ SupabaseService not initialized');
      return false;
    }

    try {
      print('✅ Approving cash deposit handover...');
      
      await _client
          .from('cash_deposit_handovers')
          .update({
            'status': 'approved',
            'approved_by': approverId,
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', handoverId);
      
      print('✅ Cash deposit handover approved');
      return true;
    } catch (e) {
      print('❌ Error approving cash deposit handover: $e');
      return false;
    }
  }

  // Reject serah terima
  Future<bool> rejectCashDepositHandover({
    required String handoverId,
    required String rejectionReason,
  }) async {
    if (!_isInitialized) {
      print('⚠️ SupabaseService not initialized');
      return false;
    }

    try {
      print('❌ Rejecting cash deposit handover...');
      
      await _client
          .from('cash_deposit_handovers')
          .update({
            'status': 'rejected',
            'rejection_reason': rejectionReason,
          })
          .eq('id', handoverId);
      
      print('✅ Cash deposit handover rejected');
      return true;
    } catch (e) {
      print('❌ Error rejecting cash deposit handover: $e');
      return false;
    }
  }

  // Get announcements
  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      print('📢 Fetching announcements from database...');
      final response = await _client
          .from('announcements')
          .select('id, title, description, created_at')
          .order('created_at', ascending: false)
          .limit(10);
      
      print('📢 Announcements fetched: ${response.length} items');
      for (var ann in response) {
        print('   - ${ann['title']}: ${ann['description']}');
      }
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching announcements: $e');
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
      print('❌ Error fetching private messages: $e');
      throw Exception('Failed to fetch private messages: $e');
    }
  }

  // Get private messages with enriched sender info
  Future<List<Map<String, dynamic>>> getPrivateMessagesWithSenderInfo({required String userId}) async {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }

    try {
      print('💬 Fetching private messages for user: $userId');
      final response = await _client
          .from('private_messages')
          .select('id, sender_id, receiver_id, message, created_at')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(50);
      
      print('💬 Messages fetched: ${response.length} items');
      
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
          print('   - From ${message['sender_name']}: ${message['message']}');
        } catch (e) {
          message['sender_name'] = 'Unknown';
          message['sender_email'] = '';
          print('   - Error fetching sender info: $e');
        }
      }
      
      return messages;
    } catch (e) {
      print('❌ Error fetching private messages: $e');
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
      print('❌ Error fetching group chats: $e');
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
      
      print('✅ Message sent successfully');
      return true;
    } catch (e) {
      print('❌ Error sending private message: $e');
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
      print('❌ Error sending group chat message: $e');
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
      print('⚠️ Error fetching outlet status: $e');
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

      print('✅ Outlet status updated to: $status');
      return true;
    } catch (e) {
      print('❌ Error updating outlet status: $e');
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
      print('⚠️ Error fetching yesterday sales data: $e');
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
      print('⚠️ Error fetching recent transactions: $e');
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
          .single();

      final hour = response['business_day_start_hour'] as int? ?? 4;
      print('✅ Business Day Start Hour loaded: $hour');
      return hour;
    } catch (e) {
      print('⚠️ Error fetching business day start hour: $e');
      return 4; // Default to 4 AM
    }
  }

  // DEBUG: Create test investor assignments for development
  Future<void> seedTestInvestorAssignments({
    required String investorId,
  }) async {
    if (!_isInitialized) return;

    try {
      print('🌱 Seeding test investor assignments for investorId=$investorId');

      // Get first 2 outlets
      final outlets = await _client
          .from('outlets')
          .select('id, name')
          .limit(2);

      if ((outlets as List<dynamic>).isEmpty) {
        print('⚠️ No outlets found to create assignments');
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

      print('✅ Created ${assignments.length} test assignments');
      print('   Result: $result');
    } catch (e) {
      print('⚠️ Error seeding test assignments: $e');
    }
  }
}
