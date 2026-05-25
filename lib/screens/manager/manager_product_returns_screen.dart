import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';
import '../qr_camera_screen.dart';

class ManagerProductReturnsScreen extends StatefulWidget {
  const ManagerProductReturnsScreen({super.key});

  @override
  State<ManagerProductReturnsScreen> createState() =>
      _ManagerProductReturnsScreenState();
}

class _ManagerProductReturnsScreenState
    extends State<ManagerProductReturnsScreen> {
  final _supabaseService = SupabaseService();

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _returns = [];
  List<Map<String, dynamic>> _allocations = [];
  Map<String, int> _soldMap = {}; // product_id -> total_quantity_sold

  String? _selectedOutletId;
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  String? _successMessage;
  int _currentTabIndex = 0;
  
  // Temporary buffer for scanned returns (before batch submit)
  List<Map<String, dynamic>> _tempReturns = [];
  DateTime? _tempReturnsTimestamp;
  static const String _tempDataStorageKey = 'returns_temp_data';
  static const String _selectedOutletStorageKey = 'returns_selected_outlet';
  static const int _clearAfterHours = 8;

  late final Map<String, TextEditingController> _quantityControllers;

  @override
  void initState() {
    super.initState();
    _quantityControllers = {};
    _loadTempReturns();
  }

  Future<void> _loadTempReturns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_tempDataStorageKey);
      
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final savedTime = DateTime.parse(data['timestamp'] as String);
        final hoursDiff = DateTime.now().difference(savedTime).inHours;
        
        // Auto-clear if older than threshold
        if (hoursDiff > _clearAfterHours) {
          print('[ManagerProductReturnsScreen] Temp data expired, clearing...');
          await prefs.remove(_tempDataStorageKey);
          return;
        }
        
        setState(() {
          _tempReturns = List<Map<String, dynamic>>.from(
            data['returns'] as List? ?? [],
          );
          _tempReturnsTimestamp = savedTime;
        });
        
        print('[ManagerProductReturnsScreen] Loaded ${_tempReturns.length} temp returns from storage');
      }
    } catch (e) {
      print('[ManagerProductReturnsScreen] Error loading temp data: $e');
    }
    
    // Then fetch outlets
    _fetchOutlets();
  }

  Future<void> _saveTempReturns() async {
    try {
      if (_tempReturns.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tempDataStorageKey);
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now();
      final data = {
        'returns': _tempReturns,
        'timestamp': timestamp.toIso8601String(),
      };
      
      await prefs.setString(_tempDataStorageKey, jsonEncode(data));
      setState(() {
        _tempReturnsTimestamp = timestamp;
      });
      
      print('[ManagerProductReturnsScreen] Saved temp returns to storage');
    } catch (e) {
      print('[ManagerProductReturnsScreen] Error saving temp data: $e');
    }
  }

  Future<void> _loadSelectedOutlet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOutletId = prefs.getString(_selectedOutletStorageKey);
      
      if (savedOutletId != null && _outlets.any((o) => o['id'] == savedOutletId)) {
        setState(() {
          _selectedOutletId = savedOutletId;
        });
        print('[ManagerProductReturnsScreen] Loaded selected outlet: $savedOutletId');
      }
    } catch (e) {
      print('[ManagerProductReturnsScreen] Error loading selected outlet: $e');
    }
  }

  Future<void> _saveSelectedOutlet(String? outletId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (outletId != null) {
        await prefs.setString(_selectedOutletStorageKey, outletId);
        print('[ManagerProductReturnsScreen] Saved selected outlet: $outletId');
      }
    } catch (e) {
      print('[ManagerProductReturnsScreen] Error saving selected outlet: $e');
    }
  }

  Future<void> _fetchOutlets() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final outletsData = await _supabaseService.fetchOutlets();
      print('[ManagerProductReturnsScreen] Fetched ${outletsData.length} outlets');
      for (final outlet in outletsData) {
        print('  - ${outlet['name']} (id: ${outlet['id']})');
      }

      setState(() {
        _outlets = outletsData;
        _isLoading = false;
      });
      
      // Load saved outlet selection after outlets are available
      await _loadSelectedOutlet();
    } catch (e) {
      print('[ManagerProductReturnsScreen] Error fetching outlets: $e');
      setState(() {
        _error = 'Error fetching outlets: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchProductsAndReturns() async {
    if (_selectedOutletId == null) {
      setState(() {
        _products = [];
        _returns = [];
        _allocations = [];
        _soldMap = {};
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch allocations FOR THIS OUTLET (what was allocated to it)
      // Convert local date to UTC range for database query
      final startOfDayUTC = DateTime.utc(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDayUTC = startOfDayUTC.add(const Duration(days: 1));
      
      final allocationsData = await _supabaseService.fetchAssignmentsForOutlet(
        outletId: _selectedOutletId!,
        startDate: startOfDayUTC,
        endDate: endOfDayUTC,
      );

      // Fetch sales FOR THIS OUTLET on this date
      final salesList = await _supabaseService.getSales(
        outletId: _selectedOutletId!,
      );
      // Convert sales to map of product_id -> sold_quantity and filter by date
      final startDate = DateTime.utc(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endDate = startDate.add(const Duration(days: 1));
      final soldMap = <String, int>{};
      for (final sale in salesList) {
        if (sale.createdAt.isAfter(startDate) && sale.createdAt.isBefore(endDate)) {
          for (final item in sale.items) {
            soldMap[item.productId] = (soldMap[item.productId] ?? 0) + item.quantity;
          }
        }
      }

      // Fetch returns FROM THIS OUTLET (what was returned)
      final returnsData = await _supabaseService.fetchProductReturnsForOutlet(
        outletId: _selectedOutletId!,
        startDate: startDate,
        endDate: endDate,
      );

      print('[ManagerProductReturnsScreen] Fetched ${allocationsData.length} allocations for outlet');
      print('[ManagerProductReturnsScreen] Fetched ${soldMap.length} products sold from outlet');
      print('[ManagerProductReturnsScreen] Fetched ${returnsData.length} returns from outlet');

      // Get unique product IDs from allocations (only show products allocated to this outlet)
      final allocatedProductIds = allocationsData
          .map((a) => a['showcase_product_id'] as String?)
          .whereType<String>()
          .toSet();

      // Get all showcase products
      final allProducts = await _supabaseService.fetchShowcaseProducts();

      // Filter to only show products allocated to this outlet
      final allocatedProducts = allProducts
          .where((p) => allocatedProductIds.contains(p['id']))
          .toList();

      setState(() {
        _allocations = allocationsData;
        _products = allocatedProducts;
        _returns = returnsData;
        _isLoading = false;
      });

      // Store sold map for later calculation
      _soldMap = soldMap;
    } catch (e) {
      setState(() {
        _error = 'Error fetching data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _returnProduct(String productId, String productName, String showcaseProductId) async {
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

    // Show dialog to select return reason
    String? selectedReason;
    const returnReasons = [
      'Tidak terjual',
      'Expired',
      'Rusak/Penyok',
      'Rasa tidak sesuai',
      'Kemasan bermasalah',
      'Stock excess',
      'Lainnya'
    ];

    if (mounted) {
      selectedReason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Alasan Pengembalian $productName'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final reason in returnReasons)
                  ListTile(
                    title: Text(reason),
                    onTap: () => Navigator.pop(context, reason),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (selectedReason == null) {
      setState(() {
        _error = 'Pilih alasan pengembalian';
      });
      return;
    }

    try {
      setState(() {
        _isSubmitting = true;
        _error = null;
        _successMessage = null;
      });

      print('[ManagerProductReturnsScreen] Returning product: $productId, qty: $quantity, reason: $selectedReason');

      final result = await _supabaseService.recordProductReturn(
        productId: productId,
        outletId: _selectedOutletId!,
        quantity: quantity,
        returnReason: selectedReason,
      );

      print('[ManagerProductReturnsScreen] Return result: $result');

      if (result['success'] == true) {
        print('[ManagerProductReturnsScreen] Return successful, refreshing data...');
        _quantityControllers[showcaseProductId]?.clear();
        setState(() {
          _successMessage = result['message'] ?? 'Pengembalian berhasil';
          _isSubmitting = false;
        });

        // Refresh immediately
        await _fetchProductsAndReturns();

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      } else {
        setState(() {
          _error = result['message'] ?? 'Error saat pengembalian';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _deleteReturn(String returnId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pengembalian'),
        content: const Text('Yakin ingin menghapus pengembalian ini?'),
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
      await _supabaseService.deleteProductReturn(returnId);
      await _fetchProductsAndReturns();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error menghapus: $e';
        });
      }
    }
  }

  Future<void> _handleQRScan() async {
    if (_selectedOutletId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih outlet terlebih dahulu'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const QRCameraScreen(),
      ),
    );

    if (scannedCode != null && mounted) {
      await _addProductByQRCode(scannedCode);
    }
  }

  Future<void> _addProductByQRCode(String code) async {
    try {
      print('[ManagerProductReturnsScreen] Scanned QR: $code');
      print('[ManagerProductReturnsScreen] Available products: ${_products.length}');
      for (final p in _products) {
        print('  Product: ${p.toString()}');
      }

      String? productId;
      String? productName;

      // Try parsing as JSON first
      try {
        final jsonData = jsonDecode(code) as Map<String, dynamic>;
        productId = jsonData['product_id']?.toString() ?? jsonData['id']?.toString();
        productName = jsonData['name']?.toString() ?? jsonData['product_name']?.toString() ?? jsonData['product']?.toString();
      } catch (e) {
        // If JSON parsing fails, treat the code as a product ID
        productId = code;
        print('[ManagerProductReturnsScreen] JSON parse failed, using code as product ID: $productId');
      }

      print('[ManagerProductReturnsScreen] Looking for product - ID: $productId, Name: $productName');

      if (productId == null || productId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Format QR tidak valid'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Find product by ID
      Map<String, dynamic>? foundProduct;

      // 1. Exact match by ID (try both 'id' and 'product_id' fields)
      foundProduct = _products.firstWhere(
        (p) => p['id'].toString() == productId || p['product_id']?.toString() == productId,
        orElse: () => {},
      );
      if (foundProduct.isEmpty && productName != null) {
        // 2. Match by name
        foundProduct = _products.firstWhere(
          (p) => (p['name'] as String?)?.toLowerCase() == productName?.toLowerCase(),
          orElse: () => {},
        );
      }
      if (foundProduct.isEmpty) {
        // 3. Partial match by name
        foundProduct = _products.firstWhere(
          (p) => (p['name'] as String?)?.toLowerCase().contains(productName?.toLowerCase() ?? '') ?? false,
          orElse: () => {},
        );
      }

      if (foundProduct.isEmpty) {
        print('[ManagerProductReturnsScreen] Product not found with ID: $productId, Name: $productName');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Produk tidak ditemukan: $productId'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      print('[ManagerProductReturnsScreen] Found product: ${foundProduct['name']} (id: ${foundProduct['id']}, product_id: ${foundProduct['product_id']})');

      final showcaseProductId = foundProduct['id']?.toString() ?? '';
      final actualProductId = foundProduct['product_id']?.toString() ?? '';
      final displayProductName = foundProduct['product_name']?.toString() ?? 'Produk';

      // Calculate returnable quantity same as in form
      // Total allocated to this outlet
      final allocatedToOutlet = _allocations
          .where((a) => a['showcase_product_id'] == showcaseProductId)
          .fold<int>(0, (sum, a) => sum + (a['quantity'] as int? ?? 0));

      // Total sold from this outlet
      final soldFromOutlet = _soldMap[actualProductId] ?? 0;

      // Get returned quantity from this outlet
      final returnedFromOutlet = _returns
          .where((r) => r['product_id'] == actualProductId)
          .fold<int>(0, (sum, r) => sum + (r['quantity'] as int? ?? 0));

      final returnableQty = allocatedToOutlet - soldFromOutlet - returnedFromOutlet;

      print('[ManagerProductReturnsScreen] Quantity calculation:');
      print('  - Allocated: $allocatedToOutlet');
      print('  - Sold: $soldFromOutlet');
      print('  - Returned: $returnedFromOutlet');
      print('  - Returnable: $returnableQty');

      if (returnableQty <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$displayProductName tidak ada sisa untuk dikembalikan'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Add to temporary buffer (instead of auto-submit)
      setState(() {
        // Check if product already exists in temp buffer
        final existingIndex = _tempReturns.indexWhere(
          (r) => r['actual_product_id'] == actualProductId,
        );
        
        if (existingIndex >= 0) {
          // Increment quantity
          _tempReturns[existingIndex]['quantity'] = 
            (_tempReturns[existingIndex]['quantity'] as int) + 1;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$displayProductName: ${_tempReturns[existingIndex]['quantity']} unit'),
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          // Add new entry
          _tempReturns.add({
            'showcase_product_id': showcaseProductId,
            'actual_product_id': actualProductId,
            'product_name': displayProductName,
            'quantity': 1,
            'reason': null,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$displayProductName ditambahkan (1 unit)'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      });
      
      // Save to persistent storage
      await _saveTempReturns();

      print('[ManagerProductReturnsScreen] Added to temp buffer: $displayProductName (qty: 1)');
    } catch (e) {
      print('[ManagerProductReturnsScreen] Error in QR handling: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _showTempReturnsDialog() async {
    if (_tempReturns.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada data pengembalian'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Show dialog with temp returns
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ringkasan Pengembalian'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total ${_tempReturns.length} produk',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < _tempReturns.length; i++)
                  _buildReturnListItem(i, setDialogState),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Lanjut Batch Submit'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      await _batchSubmitReturns();
    }
  }

  Widget _buildReturnListItem(int i, StateSetter setDialogState) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.altSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary, width: 0.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _tempReturns[i]['product_name'] ?? 'Produk',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                    onPressed: () {
                      setDialogState(() {
                        _tempReturns.removeAt(i);
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
                    onPressed: (_tempReturns[i]['quantity'] as int) <= 1
                        ? null
                        : () {
                      setDialogState(() {
                        _tempReturns[i]['quantity'] =
                            (_tempReturns[i]['quantity'] as int) - 1;
                      });
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
                Text(
                  'Qty: ${_tempReturns[i]['quantity']}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: () {
                      setDialogState(() {
                        _tempReturns[i]['quantity'] =
                            (_tempReturns[i]['quantity'] as int) + 1;
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

  Future<void> _batchSubmitReturns() async {
    const returnReasons = [
      'Tidak terjual',
      'Expired',
      'Rusak/Penyok',
      'Rasa tidak sesuai',
      'Kemasan bermasalah',
      'Stock excess',
      'Lainnya'
    ];

    for (int i = 0; i < _tempReturns.length; i++) {
      final item = _tempReturns[i];
      
      // Show reason dialog for each product
      String? selectedReason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Alasan: ${item['product_name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final reason in returnReasons)
                  ListTile(
                    title: Text(reason),
                    onTap: () => Navigator.pop(context, reason),
                  ),
              ],
            ),
          ),
        ),
      );

      if (selectedReason == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Batch submit dibatalkan'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return; // Cancel batch submit
      }

      // Submit this return
      _quantityControllers[item['showcase_product_id']] = TextEditingController(
        text: (item['quantity'] as int).toString(),
      );

      await _returnProduct(
        item['actual_product_id'] as String,
        item['product_name'] as String,
        item['showcase_product_id'] as String,
      );
    }

    // Clear temp buffer after batch submit
    setState(() {
      _tempReturns.clear();
      _tempReturnsTimestamp = null;
    });
    
    // Clear persistent storage
    await _saveTempReturns();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengembalian berhasil diproses'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header dengan outlet selector
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kembalian Produk',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_outlets.isNotEmpty)
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
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
                            
                            _fetchProductsAndReturns();
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
                // Error message
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                // Success message
                if (_successMessage != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                // Temp returns buffer indicator
                if (_tempReturns.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                      ],
                    ),
                  ),
                // Pending returns indicator
                if (_tempReturns.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade300),
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
                                    'Pengembalian Pending: ${_tempReturns.length} produk',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (_tempReturnsTimestamp != null)
                                    Text(
                                      'Sejak ${DateFormat('HH:mm').format(_tempReturnsTimestamp!)}',
                                      style: TextStyle(
                                        color: Colors.green.shade600,
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
                                  _tempReturns.clear();
                                  _tempReturnsTimestamp = null;
                                });
                                _saveTempReturns();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Pending returns dihapus'),
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
                          children: _tempReturns.map((ret) {
                            return Chip(
                              label: Text(
                                '${ret['product_name']} (${ret['quantity']})',
                              ),
                              backgroundColor: Colors.green.shade100,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _showTempReturnsDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('Review & Submit'),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                // Tabs and content
                if (_selectedOutletId != null)
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
                              Tab(text: 'Pengembalian Produk'),
                              Tab(text: 'Daftar Pengembalian'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              physics: const NeverScrollableScrollPhysics(),
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
                                  child: _buildReturnCard(),
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
                                  child: _buildReturnListCard(),
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
                          'Pilih outlet di atas untuk memulai pengembalian produk',
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
      floatingActionButton: _currentTabIndex == 0 && _selectedOutletId != null
          ? FloatingActionButton(
              onPressed: _handleQRScan,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
              tooltip: 'Scan QR Code',
            )
          : null,
    );
  }

  Widget _buildReturnCard() {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengembalian Produk',
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
                  await _fetchProductsAndReturns();
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
            if (_products.isNotEmpty)
              Column(
                children: [
                  for (final product in _products) ...[
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

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final showcaseProductId = product['id'] as String? ?? '';
    final actualProductId = product['product_id'] as String? ?? '';
    final productName = product['product_name'] as String? ?? 'Unknown';

    // Total allocated TO THIS OUTLET (what was given to this outlet)
    final allocatedToOutlet = _allocations
        .where((a) => a['showcase_product_id'] == showcaseProductId)
        .fold<int>(0, (sum, a) => sum + (a['quantity'] as int? ?? 0));

    // Total sold FROM THIS OUTLET
    final soldFromOutlet = _soldMap[actualProductId] ?? 0;

    // Get returned quantity FROM THIS OUTLET (what was returned)
    final returnedFromOutlet = _returns
        .where((r) => r['product_id'] == actualProductId)
        .fold<int>(0, (sum, r) => sum + (r['quantity'] as int? ?? 0));

    final remaining = allocatedToOutlet - soldFromOutlet - returnedFromOutlet;
    final canReturn = remaining > 0;

    _quantityControllers.putIfAbsent(showcaseProductId, () => TextEditingController());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.altSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canReturn
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
              Text('Total Alokasi:', style: Theme.of(context).textTheme.bodySmall),
              Text(allocatedToOutlet.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Terjual:', style: Theme.of(context).textTheme.bodySmall),
              Text(soldFromOutlet.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dikembalikan:',
                  style: Theme.of(context).textTheme.bodySmall),
              Text(returnedFromOutlet.toString(),
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
                      color: canReturn ? Colors.green : Colors.red)),
            ],
          ),
          const SizedBox(height: 12),
          if (canReturn)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityControllers[showcaseProductId],
                    decoration: InputDecoration(
                      hintText: 'Qty kembalian',
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _returnProduct(actualProductId, productName, showcaseProductId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.textSecondary,
                  ),
                  child: const Text(
                    'Kembalikan',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  'Tidak ada produk untuk dikembalikan',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReturnListCard() {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daftar Pengembalian',
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
                  await _fetchProductsAndReturns();
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
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildReturnStatCard(
                          label: 'Total Alokasi',
                          value: '${_getTotalAllocated()}',
                          icon: Icons.inventory_2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildReturnStatCard(
                          label: 'Terjual',
                          value: '${_getTotalSold()}',
                          icon: Icons.shopping_cart,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildReturnStatCard(
                          label: 'Dikembalikan',
                          value: '${_getTotalReturned()}',
                          icon: Icons.assignment_return,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReturnStatCard(
                          label: 'Sisa Tersedia',
                          value: '${_getTotalAllocated() - _getTotalSold() - _getTotalReturned()}',
                          icon: Icons.coffee,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_returns.length} pengembalian tercatat',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            // Per-product summary
            if (_returns.isNotEmpty) ...[
              Text(
                'Per Produk',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              _buildProductSummary(),
              const SizedBox(height: 16),
              Text(
                'Detail Pengembalian',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  for (final return_ in _returns)
                    _buildReturnItem(context, return_),
                ],
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.altSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Belum ada pengembalian',
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

  Widget _buildReturnItem(
      BuildContext context, Map<String, dynamic> return_) {
    final productName = return_['product_name'] as String? ?? 'Unknown';
    final quantity = return_['quantity'] as int? ?? 0;
    
    // Handle id which could be String or int
    final idValue = return_['id'];
    final id = idValue is String ? idValue : (idValue is int ? idValue.toString() : '');
    
    // Handle return_date which could be String or int
    String returnDateStr = '';
    final returnDateValue = return_['return_date'];
    if (returnDateValue is String) {
      returnDateStr = returnDateValue;
    } else if (returnDateValue is int) {
      returnDateStr = DateTime.fromMillisecondsSinceEpoch(returnDateValue).toIso8601String();
    }

    // Parse and format the return_date
    String formattedDate = '';
    if (returnDateStr.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(returnDateStr);
        final formatter = DateFormat('dd/MM/yyyy');
        formattedDate = formatter.format(dateTime);
      } catch (e) {
        formattedDate = returnDateStr;
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
                  'Tanggal: $formattedDate',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _deleteReturn(id),
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

  int _getTotalAllocated() {
    return _allocations.fold<int>(0, (sum, a) => sum + (a['quantity'] as int? ?? 0));
  }

  int _getTotalSold() {
    return _soldMap.values.fold<int>(0, (sum, qty) => sum + qty);
  }

  int _getTotalReturned() {
    return _returns.fold<int>(0, (sum, r) => sum + (r['quantity'] as int? ?? 0));
  }

  Widget _buildProductSummary() {
    // Group returns by product
    final Map<String, int> productReturns = {};
    for (final return_ in _returns) {
      final productName = return_['product_name'] as String? ?? 'Unknown';
      final quantity = return_['quantity'] as int? ?? 0;
      productReturns[productName] = (productReturns[productName] ?? 0) + quantity;
    }

    return Column(
      children: [
        for (final entry in productReturns.entries)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.altSurface),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Qty: ${entry.value}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildReturnStatCard({
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
