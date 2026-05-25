import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';
import '../qr_camera_screen.dart';

class ShowcaseAllocationScreen extends StatefulWidget {
  const ShowcaseAllocationScreen({super.key});

  @override
  State<ShowcaseAllocationScreen> createState() =>
      _ShowcaseAllocationScreenState();
}

class _ShowcaseAllocationScreenState extends State<ShowcaseAllocationScreen> {
  final _supabaseService = SupabaseService();

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _showcaseProducts = [];
  List<Map<String, dynamic>> _assignments = [];

  String? _selectedOutletId;
  DateTime _selectedDate = DateTime.now();
  int _businessDayStartHour = 21;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  String? _successMessage;
  int _currentTabIndex = 0;

  // Temporary buffer for scanned allocations (before batch submit)
  List<Map<String, dynamic>> _tempAllocations = [];
  DateTime? _tempAllocationsTimestamp;
  static const String _tempDataStorageKey = 'allocation_temp_data';
  static const String _selectedOutletStorageKey = 'allocation_selected_outlet';
  static const int _clearAfterHours = 8;

  late final Map<String, TextEditingController> _quantityControllers;

  @override
  void initState() {
    super.initState();
    _quantityControllers = {};
    _initialize();
  }

  Future<void> _initialize() async {
    // Load temp data first
    await _loadTempAllocations();
    
    await _fetchSettings();
    await _fetchOutlets();
    
    // Load saved outlet selection
    await _loadSelectedOutlet();
  }

  Future<void> _loadSelectedOutlet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOutletId = prefs.getString(_selectedOutletStorageKey);
      
      if (savedOutletId != null && _outlets.any((o) => o['id'] == savedOutletId)) {
        setState(() {
          _selectedOutletId = savedOutletId;
        });
        print('[ShowcaseAllocationScreen] Loaded selected outlet: $savedOutletId');
      }
    } catch (e) {
      print('[ShowcaseAllocationScreen] Error loading selected outlet: $e');
    }
  }

  Future<void> _saveSelectedOutlet(String? outletId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (outletId != null) {
        await prefs.setString(_selectedOutletStorageKey, outletId);
        print('[ShowcaseAllocationScreen] Saved selected outlet: $outletId');
      }
    } catch (e) {
      print('[ShowcaseAllocationScreen] Error saving selected outlet: $e');
    }
  }

  Future<void> _loadTempAllocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_tempDataStorageKey);
      
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final savedTime = DateTime.parse(data['timestamp'] as String);
        final hoursDiff = DateTime.now().difference(savedTime).inHours;
        
        // Auto-clear if older than threshold
        if (hoursDiff > _clearAfterHours) {
          print('[ShowcaseAllocationScreen] Temp data expired, clearing...');
          await prefs.remove(_tempDataStorageKey);
          return;
        }
        
        setState(() {
          _tempAllocations = List<Map<String, dynamic>>.from(
            data['allocations'] as List? ?? [],
          );
          _tempAllocationsTimestamp = savedTime;
        });
        
        print('[ShowcaseAllocationScreen] Loaded ${_tempAllocations.length} temp allocations from storage');
      }
    } catch (e) {
      print('[ShowcaseAllocationScreen] Error loading temp data: $e');
    }
  }

  Future<void> _saveTempAllocations() async {
    try {
      if (_tempAllocations.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tempDataStorageKey);
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now();
      final data = {
        'allocations': _tempAllocations,
        'timestamp': timestamp.toIso8601String(),
      };
      
      await prefs.setString(_tempDataStorageKey, jsonEncode(data));
      setState(() {
        _tempAllocationsTimestamp = timestamp;
      });
      
      print('[ShowcaseAllocationScreen] Saved temp allocations to storage');
    } catch (e) {
      print('[ShowcaseAllocationScreen] Error saving temp data: $e');
    }
  }

  Future<void> _fetchSettings() async {
    try {
      final settings = await _supabaseService.getSettings();
      if (settings != null && settings['businessDayStartHour'] != null) {
        setState(() {
          _businessDayStartHour = settings['businessDayStartHour'] as int;
        });
      }
    } catch (e) {
      // Use default value
    }
  }

  Future<void> _fetchOutlets() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final outletsData = await _supabaseService.fetchOutlets();
      print('[ShowcaseAllocationScreen] Fetched ${outletsData.length} outlets');
      for (final outlet in outletsData) {
        print('  - ${outlet['name']} (id: ${outlet['id']}, business_day_start_hour: ${outlet['business_day_start_hour']})');
      }
      
      setState(() {
        _outlets = outletsData;
        _isLoading = false;
      });
    } catch (e) {
      print('[ShowcaseAllocationScreen] Error fetching outlets: $e');
      setState(() {
        _error = 'Error fetching outlets: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchProductsAndAssignments() async {
    if (_selectedOutletId == null) {
      setState(() {
        _showcaseProducts = [];
        _assignments = [];
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch showcase products
      final productsData = await _supabaseService.fetchShowcaseProducts();

      // Fetch assignments with business day filter
      print('[ShowcaseAllocationScreen] Current date: $_selectedDate');
      print('[ShowcaseAllocationScreen] Business day start hour: $_businessDayStartHour');
      
      final range = _getBusinessDayRange(_selectedDate, _businessDayStartHour);
      print('[ShowcaseAllocationScreen] Business day range:');
      print('  Start (UTC): ${(range['start'] as DateTime).toIso8601String()}');
      print('  Start (local): ${(range['start'] as DateTime).toLocal().toIso8601String()}');
      print('  End (UTC): ${(range['end'] as DateTime).toIso8601String()}');
      print('  End (local): ${(range['end'] as DateTime).toLocal().toIso8601String()}');
      
      final assignments = await _supabaseService.fetchAssignmentsForOutlet(
        outletId: _selectedOutletId!,
        startDate: range['start'] as DateTime,
        endDate: range['end'] as DateTime,
      );

      print('[ShowcaseAllocationScreen] Fetched ${assignments.length} assignments');

      setState(() {
        _showcaseProducts = productsData;
        _assignments = assignments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error fetching data: $e';
        _isLoading = false;
      });
    }
  }

  Map<String, DateTime> _getBusinessDayRange(DateTime date, int startHour) {
    final year = date.year;
    final month = date.month;
    final day = date.day;
    final hour = date.hour;

    late DateTime businessDayStartLocal;
    late DateTime businessDayEndLocal;

    // Check if current hour is before or after business day start hour
    if (hour >= startHour) {
      // Current time is at or after business day start hour
      // So we're in TODAY's business day (start@hour today, end@hour tomorrow)
      businessDayStartLocal = DateTime(year, month, day, startHour, 0, 0);
      businessDayEndLocal = DateTime(year, month, day + 1, startHour, 0, 0);
    } else {
      // Current time is before business day start hour
      // So we're in YESTERDAY's business day (start@hour yesterday, end@hour today)
      businessDayStartLocal = DateTime(year, month, day - 1, startHour, 0, 0);
      businessDayEndLocal = DateTime(year, month, day, startHour, 0, 0);
    }

    // Subtract 1 millisecond from end to exclude the exact end time
    businessDayEndLocal = businessDayEndLocal.subtract(const Duration(milliseconds: 1));

    // Convert to UTC for database query
    // This matches supabase_service.dart's getProductStockAtDate() logic
    final businessDayStartUtc = businessDayStartLocal.toUtc();
    final businessDayEndUtc = businessDayEndLocal.toUtc();

    return {
      'start': businessDayStartUtc,
      'end': businessDayEndUtc,
    };
  }

  Future<void> _allocateProduct(String showcaseProductId) async {
    final quantityStr = _quantityControllers[showcaseProductId]?.text ?? '';

    if (quantityStr.isEmpty) {
      setState(() {
        _error = 'Masukkan quantity terlebih dahulu';
      });
      return;
    }

    final quantity = int.tryParse(quantityStr);
    if (quantity == null || quantity <= 0) {
      setState(() {
        _error = 'Quantity harus angka positif';
      });
      return;
    }

    if (_selectedOutletId == null) {
      setState(() {
        _error = 'Pilih outlet terlebih dahulu';
      });
      return;
    }

    try {
      setState(() {
        _isSubmitting = true;
        _error = null;
        _successMessage = null;
      });

      print('[ShowcaseAllocationScreen] Allocating product: $showcaseProductId, qty: $quantity');
      
      final result = await _supabaseService.allocateShowcaseProduct(
        showcaseProductId: showcaseProductId,
        outletId: _selectedOutletId!,
        quantity: quantity,
      );

      print('[ShowcaseAllocationScreen] Allocation result: $result');

      if (result['success'] == true) {
        print('[ShowcaseAllocationScreen] Allocation successful, refreshing data...');
        _quantityControllers[showcaseProductId]?.clear();
        setState(() {
          _successMessage = result['message'] ?? 'Alokasi berhasil';
          _isSubmitting = false;
        });
        
        // Refresh immediately
        await _fetchProductsAndAssignments();
        
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      } else {
        setState(() {
          _error = result['message'] ?? 'Error saat alokasi';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isSubmitting = false;
      });
    }
    // Always refresh after allocation attempt
    await _fetchProductsAndAssignments();
  }

  Future<void> _deleteAllocation(String allocationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Alokasi'),
        content: const Text('Yakin ingin menghapus alokasi ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _isSubmitting = true;
        _error = null;
      });

      final result = await _supabaseService.deleteShowcaseAllocation(allocationId);

      if (result['success'] == true) {
        setState(() {
          _successMessage = 'Alokasi berhasil dihapus';
          _isSubmitting = false;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      } else {
        setState(() {
          _error = result['message'] ?? 'Error saat hapus';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isSubmitting = false;
      });
    }
    // Always refresh after deletion attempt
    await _fetchProductsAndAssignments();
  }

  Future<void> _handleQRScan() async {
    if (_selectedOutletId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Pilih outlet terlebih dahulu'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const QRCameraScreen()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      await _addProductByQRCode(scannedCode);
    }
  }

  Future<void> _addProductByQRCode(String code) async {
    try {
      print('[ShowcaseAllocationScreen] Scanned QR: $code');
      
      String? searchId;
      String? productName;
      
      // Try to parse JSON from QR code first
      try {
        final jsonData = jsonDecode(code) as Map<String, dynamic>;
        
        // Try to get product_id from JSON (warehouse QR format)
        if (jsonData.containsKey('product_id')) {
          searchId = jsonData['product_id'] as String;
        }
        // Fallback: Mobile app format with "id" field
        else if (jsonData.containsKey('id')) {
          searchId = jsonData['id'] as String;
        }
        
        // Get product name for matching - try multiple field names
        productName = jsonData['product'] as String? ?? 
                      jsonData['product_name'] as String? ?? 
                      jsonData['name'] as String?;
      } catch (e) {
        // Not JSON, treat as plain code - assume it's a product ID
        searchId = code;
        print('[ShowcaseAllocationScreen] JSON parse failed, using code as product ID: $searchId');
      }

      print('[ShowcaseAllocationScreen] Available products: ${_showcaseProducts.length}');
      for (final p in _showcaseProducts) {
        print('  - ${p['product_name']} (id: ${p['id']}, product_id: ${p['product_id']})');
      }
      print('[ShowcaseAllocationScreen] Looking for product - ID: $searchId, Name: $productName');

      // Find product in showcase products
      Map<String, dynamic>? product;
      
      // Try exact ID match first (check both 'id' and 'product_id' fields)
      if (searchId != null && searchId.isNotEmpty) {
        for (final p in _showcaseProducts) {
          if (p['id'] == searchId || p['product_id'] == searchId) {
            product = p;
            print('[ShowcaseAllocationScreen] Found by exact ID match');
            break;
          }
        }
      }
      
      // If not found by ID, try product name match
      if (product == null && productName != null && productName.isNotEmpty) {
        for (final p in _showcaseProducts) {
          if ((p['product_name'] as String? ?? '').toLowerCase() == productName.toLowerCase()) {
            product = p;
            print('[ShowcaseAllocationScreen] Found by name match');
            break;
          }
        }
      }
      
      // Last resort: partial matching
      if (product == null && searchId != null) {
        for (final p in _showcaseProducts) {
          if ((p['id'] as String? ?? '').toLowerCase().contains(searchId.toLowerCase()) ||
              (p['product_name'] as String? ?? '').toLowerCase().contains(searchId.toLowerCase())) {
            product = p;
            break;
          }
        }
      }

      if (product == null) {
        if (mounted) {
          String errorMsg = '❌ Produk tidak ditemukan';
          if (searchId != null) errorMsg += ': $searchId';
          if (productName != null) errorMsg += ' ($productName)';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Check if product can be allocated
      final productId = product['id'] as String;
      final allocProductName = product['product_name'] as String? ?? 'Produk';
      final totalQuantity = product['total_quantity'] as int? ?? 0;
      final allocated = _assignments
          .where((a) => a['showcase_product_id'] == productId)
          .fold<int>(0, (sum, a) => sum + (a['quantity'] as int? ?? 0));
      final remaining = totalQuantity - allocated;

      if (remaining <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $allocProductName tidak ada sisa'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Add to temporary allocations buffer (batch processing)
      if (mounted) {
        setState(() {
          final existingIndex = _tempAllocations.indexWhere(
            (a) => a['showcase_product_id'] == productId,
          );
          
          if (existingIndex >= 0) {
            // Product already in buffer, increment quantity
            _tempAllocations[existingIndex]['quantity'] = 
              (_tempAllocations[existingIndex]['quantity'] as int) + 1;
          } else {
            // Add new product to buffer
            _tempAllocations.add({
              'showcase_product_id': productId,
              'product_name': allocProductName,
              'quantity': 1,
            });
          }
        });

        // Save to persistent storage
        await _saveTempAllocations();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $allocProductName ditambahkan (Queue: ${_tempAllocations.length})'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showTempAllocationsDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Review Alokasi Batch'),
            content: SingleChildScrollView(
              child: _tempAllocations.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Tidak ada produk yang ditambahkan'),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int index = 0; index < _tempAllocations.length; index++)
                          _buildAllocationListItem(index, setDialogState),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, true);
                            },
                            child: const Text('Lanjut Batch Submit'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context, false);
                            },
                            child: const Text('Batal'),
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );

    if (result == true) {
      await _batchSubmitAllocations();
    }
  }

  Widget _buildAllocationListItem(int index, StateSetter setDialogState) {
    final allocation = _tempAllocations[index];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    allocation['product_name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                    onPressed: () {
                      setDialogState(() {
                        _tempAllocations.removeAt(index);
                      });
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    icon: const Icon(Icons.remove, size: 16),
                    onPressed: () {
                      setDialogState(() {
                        final currentQty = _tempAllocations[index]['quantity'] as int;
                        if (currentQty > 1) {
                          _tempAllocations[index]['quantity'] = currentQty - 1;
                        }
                      });
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
                Text(
                  'Qty: ${_tempAllocations[index]['quantity']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: () {
                      setDialogState(() {
                        _tempAllocations[index]['quantity'] =
                            (_tempAllocations[index]['quantity'] as int) + 1;
                      });
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _batchSubmitAllocations() async {
    try {
      setState(() {
        _isSubmitting = true;
        _error = null;
        _successMessage = null;
      });

      // Make a copy of the buffer to avoid modification issues
      final allocationsToProcess = List<Map<String, dynamic>>.from(_tempAllocations);
      int successCount = 0;
      int failCount = 0;

      // Process each allocation in the buffer
      for (final allocation in allocationsToProcess) {
        try {
          final showcaseProductId = allocation['showcase_product_id'] as String;
          final quantity = allocation['quantity'] as int;

          print('[ShowcaseAllocationScreen] Batch allocating: $showcaseProductId, qty: $quantity');

          final result = await _supabaseService.allocateShowcaseProduct(
            showcaseProductId: showcaseProductId,
            outletId: _selectedOutletId!,
            quantity: quantity,
          );

          if (result['success'] == true) {
            successCount++;
          } else {
            failCount++;
            print('[ShowcaseAllocationScreen] Allocation failed: ${result['message']}');
          }
        } catch (e) {
          failCount++;
          print('[ShowcaseAllocationScreen] Error allocating item: $e');
        }
      }

      // Clear the buffer after processing
      if (mounted) {
        setState(() {
          _tempAllocations.clear();
          _isSubmitting = false;
          
          if (failCount == 0) {
            _successMessage = '✓ $successCount alokasi berhasil diproses';
          } else {
            _successMessage = '✓ $successCount berhasil, $failCount gagal';
          }
        });
        
        // Clear persistent storage
        await _saveTempAllocations();
      }

      // Refresh data in background without blocking UI
      Future.microtask(() async {
        try {
          await _fetchProductsAndAssignments();
        } catch (e) {
          print('[ShowcaseAllocationScreen] Error refreshing data: $e');
        }
      });

      // Clear success message after delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final productId = product['id'] as String;
    final productName = product['product_name'] as String? ?? 'Unknown';
    final totalQuantity = product['total_quantity'] as int? ?? 0;

    final allocated = _assignments
        .where((a) => a['showcase_product_id'] == productId)
        .fold<int>(0, (sum, a) => sum + (a['quantity'] as int? ?? 0));
    final remaining = totalQuantity - allocated;
    final canAllocate = remaining > 0;

    if (!_quantityControllers.containsKey(productId)) {
      _quantityControllers[productId] = TextEditingController();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.altSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canAllocate
              ? Colors.grey.withValues(alpha: 0.5)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            productName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total:', style: Theme.of(context).textTheme.bodySmall),
              Text(totalQuantity.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dialokasikan:',
                  style: Theme.of(context).textTheme.bodySmall),
              Text(allocated.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sisa:', style: Theme.of(context).textTheme.bodySmall),
              Text(remaining.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: canAllocate ? Colors.green : Colors.red)),
            ],
          ),
          const SizedBox(height: 12),
          if (canAllocate)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityControllers[productId],
                    decoration: InputDecoration(
                      hintText: 'Quantity',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _allocateProduct(productId),
                  child: const Text('Alokasi'),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Produk sudah habis',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showTabs = _selectedOutletId != null;

    return Scaffold(
      body: _isLoading && _outlets.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alokasi Produk Showcase',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kelola alokasi produk dari showcase ke outlet',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_outlets.isNotEmpty)
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Pilih Outlet',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            value: _selectedOutletId,
                            hint: const Text('Pilih outlet...'),
                            items: _outlets.map((outlet) {
                              return DropdownMenuItem<String>(
                                value: outlet['id'] as String,
                                child:
                                    Text(outlet['name'] as String? ?? 'Unknown'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedOutletId = value;
                                _successMessage = null;
                                _error = null;
                              });
                              
                              // Save outlet selection
                              if (value != null) {
                                _saveSelectedOutlet(value);
                              }
                              
                              // Load business day start hour from selected outlet
                              if (value != null) {
                                final selectedOutlet = _outlets.firstWhere(
                                  (outlet) => outlet['id'] == value,
                                  orElse: () => {},
                                );
                                if (selectedOutlet.containsKey('business_day_start_hour')) {
                                  setState(() {
                                    _businessDayStartHour = selectedOutlet['business_day_start_hour'] as int;
                                  });
                                  print('[ShowcaseAllocationScreen] Loaded business day start hour: $_businessDayStartHour from outlet');
                                }
                              }
                              
                              _fetchProductsAndAssignments();
                            },
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.altSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Tidak ada outlet tersedia',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Pending allocations indicator
                  if (_tempAllocations.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                                      'Alokasi Pending: ${_tempAllocations.length} produk',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (_tempAllocationsTimestamp != null)
                                      Text(
                                        'Sejak ${DateFormat('HH:mm').format(_tempAllocationsTimestamp!)}',
                                        style: TextStyle(
                                          color: Colors.blue.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _tempAllocations.clear();
                                    _tempAllocationsTimestamp = null;
                                  });
                                  _saveTempAllocations();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Pending allocations dihapus'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                tooltip: 'Clear pending',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _tempAllocations.map((alloc) {
                              return Chip(
                                label: Text(
                                  '${alloc['product_name']} (${alloc['quantity']})',
                                ),
                                backgroundColor: Colors.blue.shade100,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _showTempAllocationsDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                              child: const Text('Review & Submit'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (showTabs)
                    Expanded(
                      child: DefaultTabController(
                        length: 2,
                        initialIndex: _currentTabIndex,
                        child: Column(
                          children: [
                            TabBar(
                              onTap: (index) {
                                setState(() {
                                  _currentTabIndex = index;
                                });
                              },
                              tabs: const [
                                Tab(text: 'Alokasi Produk'),
                                Tab(text: 'Daftar Alokasi'),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                children: [
                                  SingleChildScrollView(
                                    padding: EdgeInsets.only(
                                      left: 16,
                                      right: 16,
                                      top: 16,
                                      bottom: MediaQuery.of(context)
                                              .padding
                                              .bottom +
                                          16,
                                    ),
                                    child: _buildAllocationCard(),
                                  ),
                                  SingleChildScrollView(
                                    padding: EdgeInsets.only(
                                      left: 16,
                                      right: 16,
                                      top: 16,
                                      bottom: MediaQuery.of(context)
                                              .padding
                                              .bottom +
                                          16,
                                    ),
                                    child:
                                        _buildAllocationListCard(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Pilih outlet di atas untuk memulai alokasi produk',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: _currentTabIndex == 0 && _selectedOutletId != null
          ? FloatingActionButton(
              onPressed: _handleQRScan,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
            )
          : null,
    );
  }

  Widget _buildAllocationCard() {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alokasi Produk',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Date Picker
            GestureDetector(
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
                  await _fetchProductsAndAssignments();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.altSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, dd MMM yyyy', 'id_ID')
                            .format(_selectedDate),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_showcaseProducts.isNotEmpty)
              Column(
                children: [
                  for (final product in _showcaseProducts) ...[
                    _buildProductCard(context, product),
                    const SizedBox(height: 12),
                  ]
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.altSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Tidak ada produk tersedia',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationListCard() {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daftar Alokasi',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Date Picker
            GestureDetector(
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
                  await _fetchProductsAndAssignments();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.altSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, dd MMM yyyy', 'id_ID')
                            .format(_selectedDate),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Summary Statistics Cards
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.background,
              child: Row(
                children: [
                  Expanded(
                    child: _buildAllocationStatCard(
                      label: 'Total Dialokasikan',
                      value: '${_assignments.length}',
                      icon: Icons.inventory_2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildAllocationStatCard(
                      label: 'Sisa Tersedia',
                      value: '${_showcaseProducts.length - _assignments.length}',
                      icon: Icons.coffee,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildAllocationStatCard(
                      label: 'Total Produk',
                      value: '${_showcaseProducts.length}',
                      icon: Icons.dashboard,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_assignments.length} produk dialokasikan',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            if (_assignments.isNotEmpty)
              Column(
                children: [
                  for (final assignment in _assignments)
                    _buildAssignmentItem(context, assignment),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.altSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Belum ada alokasi',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentItem(
      BuildContext context, Map<String, dynamic> assignment) {
    final productName = assignment['product_name'] as String? ?? 'Unknown';
    final quantity = assignment['quantity'] as int? ?? 0;
    final id = assignment['id'] as String? ?? '';
    final createdAtStr = assignment['created_at'] as String? ?? '';
    
    // Parse and format the created_at timestamp
    String formattedTime = '';
    if (createdAtStr.isNotEmpty) {
      try {
        var dateTime = DateTime.parse(createdAtStr);
        
        // If string doesn't have timezone info, treat it as UTC
        // (Supabase stores it as UTC even without Z suffix)
        if (!createdAtStr.contains('Z') && 
            !createdAtStr.contains('+') && 
            !createdAtStr.contains(RegExp(r'-\d{2}:\d{2}$'))) {
          // Reconstruct as UTC datetime
          dateTime = DateTime.utc(
            dateTime.year, 
            dateTime.month, 
            dateTime.day, 
            dateTime.hour, 
            dateTime.minute, 
            dateTime.second, 
            dateTime.millisecond,
            dateTime.microsecond,
          );
        }
        
        final localDateTime = dateTime.toLocal();
        formattedTime = '${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}:${localDateTime.second.toString().padLeft(2, '0')}';
      } catch (e) {
        formattedTime = createdAtStr;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.altSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Qty: $quantity',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Waktu: $formattedTime',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _deleteAllocation(id),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationStatCard({
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
}
