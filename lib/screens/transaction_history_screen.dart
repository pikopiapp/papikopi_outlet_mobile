import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../services/supabase_service.dart';
import '../theme/thema.dart';
import '../utils/number_formatter.dart';
import '../models/sale.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with AutomaticKeepAliveClientMixin {
  final SupabaseService _supabase = SupabaseService();
  List<Sale> _transactions = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      // Load sales for current outlet only (not filtered by barista)
      // This ensures all sales from the outlet are visible regardless of who made them
      final sales = await _supabase.getSales(
        outletId: auth.currentUser!.outletId,
      );

      print('📋 Loaded ${sales.length} transactions for outlet ${auth.currentUser!.outletId}');
      for (var sale in sales) {
        print('   - Sale #${sale.id.substring(0, 8)}: ${sale.items.length} items');
        // Special tracking for transaction #540ef8d3
        if (sale.id.startsWith('540ef8d3')) {
          print('   ⭐ Found target transaction #540ef8d3:');
          print('      Total Amount: ${sale.totalAmount}');
          print('      Items: ${sale.items.length}');
          print('      Is Edited: ${sale.isEdited}');
        }
        for (var item in sale.items) {
          print('     • ${item.productName} (ID: ${item.productId}) x${item.quantity}');
        }
      }

      print('🔄 Calling setState to update _transactions list...');
      setState(() {
        _transactions = sales;
        _isLoading = false;
      });
      print('✅ setState completed, CardList should rebuild now');
    } catch (e) {
      print('❌ Error loading transactions: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    print('🎨 TransactionHistoryScreen.build() called with ${_transactions.length} transactions');
    // Special tracking for target transaction
    final targetTx = _transactions.where((t) => t.id.startsWith('540ef8d3')).firstOrNull;
    if (targetTx != null) {
      print('   ⭐ Target transaction #540ef8d3 in build(): amount=${targetTx.totalAmount}, items=${targetTx.items.length}');
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Riwayat Pesanan'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada pesanan',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _transactions.length,
                  addAutomaticKeepAlives: false, // Disable keep alive to force rebuild
                  addRepaintBoundaries: false, // Disable repaint boundaries for full rebuild
                  itemBuilder: (context, index) {
                    final transaction = _transactions[index];
                    final itemCountStr = transaction.items.length.toString();
                    print('🔄 Building TransactionCard ${index+1}/${_transactions.length} for ${transaction.id.substring(0, 8)}: amount=${transaction.totalAmount}, items=$itemCountStr, isEdited=${transaction.isEdited}');
                    // Special tracking for target transaction
                    if (transaction.id.startsWith('540ef8d3')) {
                      print('   ⭐ Building target card #540ef8d3 with items=$itemCountStr, totalAmount=${transaction.totalAmount}');
                    }
                    return TransactionCard(
                      key: ValueKey('${transaction.id}-${transaction.totalAmount}-${itemCountStr}-${transaction.isEdited}'), // Include all data in key
                      transaction: transaction,
                      onTap: () => _showTransactionDetail(transaction),
                    );
                  },
                ),
    );
  }

  void _showTransactionDetail(Sale transaction) {
    showDialog(
      context: context,
      builder: (context) => _TransactionEditDialog(
        transaction: transaction,
        onSave: (editedTransaction) async {
          // Update transaction in database
          print('💾 Starting transaction update...');
          await _updateTransaction(editedTransaction);
          print('✅ Transaction update completed');
          
          // Close dialog only after update is done
          if (mounted && Navigator.canPop(context)) {
            print('🚪 Closing dialog...');
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Future<void> _updateTransaction(Sale transaction) async {
    try {
      // Find original transaction in list for comparison
      final originalTx = _transactions.firstWhere(
        (t) => t.id == transaction.id,
        orElse: () => transaction,
      );
      
      print('🔧 Updating transaction ${transaction.id}');
      print('   BEFORE UPDATE:');
      print('     Amount: ${originalTx.totalAmount}');
      print('     Items: ${originalTx.items.length}');
      print('     Is Edited: ${originalTx.isEdited}');
      print('   AFTER UPDATE (new values):');
      print('     Amount: ${transaction.totalAmount}');
      print('     Items: ${transaction.items.length}');
      print('     Is Edited: ${transaction.isEdited}');
      
      // Update sales table with new payment method and edit tracking
      final updatedData = {
        'is_edited': true,
        'edited_at': DateTime.now().toIso8601String(),
        'payment_method': transaction.paymentMethod,
        'total_amount': transaction.totalAmount,
        'hpp_total': transaction.totalHpp,
        'profit': transaction.profit,
      };

      print('   Payment method: ${transaction.paymentMethod}');
      print('   Total HPP: ${transaction.totalHpp}');
      print('   Profit: ${transaction.profit}');
      print('   Items count: ${transaction.items.length}');

      await _supabase.client
          .from('sales')
          .update(updatedData)
          .eq('id', transaction.id);

      // Update sale items - update each existing item with new values
      print('🔧 Updating ${transaction.items.length} items in sale_items table');
      for (var item in transaction.items) {
        final itemSubtotal = item.quantity * item.unitPrice;
        final itemTotalHpp = item.quantity * item.hpp;
        
        // 🆕 Check if this is a new item (id is empty string or doesn't exist in original)
        final isNewItem = item.id.isEmpty || !_transactions.any((t) => 
          t.id == transaction.id && t.items.any((i) => i.id == item.id)
        );
        
        if (isNewItem) {
          // 🆕 INSERT new item
          print('   - Inserting NEW item:');
          print('     Product ID: ${item.productId}');
          print('     Quantity: ${item.quantity}');
          print('     Price: ${item.unitPrice}');
          print('     Subtotal: $itemSubtotal');
          print('     Total HPP: $itemTotalHpp');
          
          try {
            await _supabase.client
                .from('sale_items')
                .insert({
                  'sale_id': item.saleId,
                  'product_id': item.productId,
                  'quantity': item.quantity,
                  'price': item.unitPrice,
                  'hpp': item.hpp,
                  'created_at': DateTime.now().toIso8601String(),
                });
            print('     ✅ Inserted successfully');
          } catch (e) {
            print('   ⚠️ Error inserting new item: $e');
          }
        } else {
          // Update existing item
          print('   - Updating existing item ${item.id}:');
          print('     Product ID: ${item.productId}');
          print('     Quantity: ${item.quantity}');
          print('     Price: ${item.unitPrice}');
          print('     Subtotal: $itemSubtotal');
          print('     Total HPP: $itemTotalHpp');
          
          try {
            // Update sale_items with the columns that exist in the table:
            // id, sale_id, product_id, quantity, price, hpp, created_at
            await _supabase.client
                .from('sale_items')
                .update({
                  'product_id': item.productId,
                  'quantity': item.quantity,
                  'price': item.unitPrice,
                  'hpp': item.hpp,
                })
                .eq('id', item.id);
            
            print('     ✅ Updated successfully');
          } catch (e) {
            print('   ⚠️ Error updating item ${item.id}: $e');
          }
        }
      }

      print('✅ All items updated in sale_items table');

      // Add delay to ensure all updates are committed to database
      print('⏳ Waiting for database sync (1 second)...');
      await Future.delayed(const Duration(seconds: 1));

      // Reload transactions
      print('🔄 Reloading transaction list...');
      await _loadTransactions();
      print('✅ Transaction list reloaded successfully');
      
      // Verify updated transaction is in the list
      final updatedTx = _transactions.firstWhere(
        (t) => t.id == transaction.id,
        orElse: () => transaction,
      );
      print('   📊 VERIFICATION - Updated transaction in CardList:');
      print('      Amount: ${updatedTx.totalAmount}');
      print('      Items: ${updatedTx.items.length}');
      print('      Is Edited: ${updatedTx.isEdited}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Pesanan berhasil diperbarui')),
        );
      }
    } catch (e) {
      print('❌ Error updating transaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class TransactionCard extends StatelessWidget {
  final Sale transaction;
  final VoidCallback onTap;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = transaction.items.length;
    print('📊 TransactionCard.build() - ID: ${transaction.id.substring(0, 8)}, Amount: ${transaction.totalAmount}, Items: $itemCount, IsEdited: ${transaction.isEdited}');
    
    // Debug: print all items in this transaction
    if (itemCount > 0) {
      for (var i = 0; i < itemCount; i++) {
        final item = transaction.items[i];
        print('   Item $i: ${item.productName} (ID: ${item.productId}) x${item.quantity}');
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.receipt_long,
            color: AppColors.primary,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Pesanan #${transaction.id.substring(0, 8)}...',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            // 🔧 NEW: Show edited badge
            if (transaction.isEdited)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Edited',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              DateFormat('dd MMM yyyy HH:mm', 'id_ID')
                  .format(transaction.createdAt.add(const Duration(hours: 7))),
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '$itemCount item • ${transaction.paymentMethod}',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        trailing: SizedBox(
          width: 120,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      NumberFormatter.formatRupiah(transaction.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                    // 🔧 NEW: Show edited date if edited
                    if (transaction.isEdited && transaction.editedAt != null)
                      Text(
                        DateFormat('dd MMM', 'id_ID').format(transaction.editedAt!.add(const Duration(hours: 7))),
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 🔧 NEW: Edit button
              Icon(
                Icons.edit,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}

// 🔧 NEW: Edit dialog for transaction
class _TransactionEditDialog extends StatefulWidget {
  final Sale transaction;
  final Function(Sale) onSave;

  const _TransactionEditDialog({
    required this.transaction,
    required this.onSave,
  });

  @override
  State<_TransactionEditDialog> createState() => _TransactionEditDialogState();
}

class _TransactionEditDialogState extends State<_TransactionEditDialog> {
  late String _paymentMethod;
  late Map<String, int> _itemQuantitiesByProduct; // Track quantity changes by product name
  late Map<String, String> _itemProductNamesByProduct; // Track product name changes by product name
  late Map<String, List<String>> _itemIdsByProduct; // Track which item IDs belong to each product
  late Map<String, double> _itemUnitPriceByProduct; // Track unit prices by product name
  late Map<String, double> _itemHppByProduct; // Track HPP by product name
  
  // 🆕 Track newly added items (not from original transaction)
  late List<({String productId, String productName, int quantity, double unitPrice, double hpp})> _newItems;

  @override
  void initState() {
    super.initState();
    // 🔧 Validate payment method from database
    const validMethods = ['CASH', 'QRIS'];
    _paymentMethod = validMethods.contains(widget.transaction.paymentMethod)
        ? widget.transaction.paymentMethod
        : 'CASH'; // Default to CASH if invalid
    
    // Initialize by product name (aggregated)
    _itemQuantitiesByProduct = {};
    _itemProductNamesByProduct = {};
    _itemIdsByProduct = {};
    _itemUnitPriceByProduct = {};
    _itemHppByProduct = {};
    _newItems = []; // 🆕 Initialize new items list
    
    print('🔧 Transaction items count: ${widget.transaction.items.length}');
    for (var item in widget.transaction.items) {
      print('   - Item: ${item.productName} x${item.quantity}');
      final key = item.productName;
      _itemQuantitiesByProduct.putIfAbsent(key, () => 0);
      _itemQuantitiesByProduct[key] = _itemQuantitiesByProduct[key]! + item.quantity;
      _itemProductNamesByProduct[key] = item.productName;
      _itemUnitPriceByProduct[key] = item.unitPrice;
      _itemHppByProduct[key] = item.hpp;
      
      if (!_itemIdsByProduct.containsKey(key)) {
        _itemIdsByProduct[key] = [];
      }
      _itemIdsByProduct[key]!.add(item.id);
    }
    print('🔧 Initialized aggregated items: $_itemQuantitiesByProduct');
  }

  // 🔧 NEW: Aggregate items by product name
  List<({String productName, int quantity, double unitPrice})> get aggregatedItems {
    // Return aggregated items with updated prices based on current product selection
    final result = <({String productName, int quantity, double unitPrice})>[];
    _itemProductNamesByProduct.forEach((originalProductName, currentProductName) {
      final quantity = _itemQuantitiesByProduct[originalProductName] ?? 1;
      final unitPrice = _itemUnitPriceByProduct[originalProductName] ?? 0.0;
      result.add((
        productName: currentProductName, // Use current product name (may have changed)
        quantity: quantity,
        unitPrice: unitPrice, // Use stored price
      ));
    });
    return result;
  }

  void _updateProductPrice(String originalProductName, String newProductName) {
    // Get productProvider to lookup new product
    try {
      final productProvider = context.read<ProductProvider>();
      try {
        final newProduct = productProvider.products.firstWhere(
          (p) => p.name == newProductName,
        );
        _itemUnitPriceByProduct[originalProductName] = newProduct.price.toDouble();
        _itemHppByProduct[originalProductName] = (newProduct.hpp ?? 0).toDouble();
        print('✅ Updated price for $originalProductName -> $newProductName: Rp ${newProduct.price}');
      } catch (e) {
        print('⚠️ Could not find new product price for $newProductName: $e');
      }
    } catch (e) {
      print('⚠️ ProductProvider not available: $e');
    }
  }

  // 🆕 Add new product to transaction
  void _showAddProductDialog() {
    final productProvider = context.read<ProductProvider>();
    String? selectedProductId;
    int quantity = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Tambah Product'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih Product',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButton<String>(
                      value: selectedProductId,
                      isExpanded: true,
                      underline: const SizedBox(),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      hint: const Text('Pilih product...'),
                      items: productProvider.products.map((product) {
                        return DropdownMenuItem(
                          value: product.id,
                          child: Text(product.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedProductId = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Jumlah',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          iconSize: 18,
                          onPressed: quantity > 1
                              ? () => setState(() => quantity--)
                              : null,
                        ),
                        Expanded(
                          child: TextField(
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            controller: TextEditingController(text: quantity.toString())
                              ..selection = TextSelection.fromPosition(
                                TextPosition(offset: quantity.toString().length),
                              ),
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                setState(() => quantity = int.tryParse(value) ?? 1);
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          iconSize: 18,
                          onPressed: () => setState(() => quantity++),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: selectedProductId != null
                    ? () {
                        final product = productProvider.products
                            .firstWhere((p) => p.id == selectedProductId);
                        this.setState(() {
                          _newItems.add((
                            productId: product.id,
                            productName: product.name,
                            quantity: quantity,
                            unitPrice: product.price.toDouble(),
                            hpp: (product.hpp ?? 0).toDouble(),
                          ));
                        });
                        Navigator.pop(context);
                        print('✅ Added new product: ${product.name} x$quantity');
                      }
                    : null,
                child: const Text('Tambah'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: Text('Edit Pesanan #${widget.transaction.id.substring(0, 8)}...'),
          centerTitle: true,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Info (read-only)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tanggal Pesanan',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy HH:mm', 'id_ID')
                          .format(widget.transaction.createdAt.add(const Duration(hours: 7))),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Method
              Text(
                'Metode Pembayaran',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _paymentMethod,
                  isExpanded: true,
                  underline: const SizedBox(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('Tunai')),
                    DropdownMenuItem(value: 'QRIS', child: Text('QRIS')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _paymentMethod = value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Item Pesanan',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // 🆕 Add Product button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Tambah', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _showAddProductDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (aggregatedItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Tidak ada item',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                ...aggregatedItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  // For render, use the original product name as key to lookup quantities
                  final originalProductName = _itemProductNamesByProduct.keys.elementAt(index);
                  final quantity = _itemQuantitiesByProduct[originalProductName] ?? item.quantity;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🔧 Product dropdown
                          Consumer<ProductProvider>(
                            builder: (context, productProvider, _) {
                              final products = productProvider.products;
                              var currentProductName = _itemProductNamesByProduct[originalProductName] ?? item.productName;
                              
                              // 🔧 If current product is invalid, use first product
                              if (!products.any((p) => p.name == currentProductName) && products.isNotEmpty) {
                                currentProductName = products.first.name;
                                _itemProductNamesByProduct[originalProductName] = currentProductName;
                              }
                              
                              print('🔧 Dropdown for product $originalProductName (index $index):');
                              print('   current: $currentProductName');
                              
                              // Create dropdown items from products
                              final dropdownItems = <DropdownMenuItem<String>>[];
                              
                              // Add all products
                              for (var p in products) {
                                dropdownItems.add(
                                  DropdownMenuItem(
                                    value: p.name,
                                    child: Text(p.name),
                                  ),
                                );
                              }
                              
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: DropdownButton<String>(
                                  value: currentProductName,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  items: dropdownItems,
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _itemProductNamesByProduct[originalProductName] = value;
                                        _updateProductPrice(originalProductName, value); // Update price
                                      });
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      NumberFormatter.formatRupiah(item.unitPrice),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Total: ${NumberFormatter.formatRupiah(item.unitPrice * quantity)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Quantity editor
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      iconSize: 18,
                                      onPressed: (quantity > 1)
                                          ? () {
                                              setState(() =>
                                                  _itemQuantitiesByProduct[originalProductName] =
                                                      quantity - 1);
                                            }
                                          : null,
                                    ),
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        '$quantity',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      iconSize: 18,
                                    onPressed: () {
                                      setState(() => _itemQuantitiesByProduct[item.productName] =
                                          _itemQuantitiesByProduct[item.productName]! + 1);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              // 🆕 Render newly added items
              ..._newItems.asMap().entries.map((entry) {
                final index = entry.key;
                final newItem = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.orange[50],
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
                                    newItem.productName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    NumberFormatter.formatRupiah(newItem.unitPrice),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                              onPressed: () {
                                setState(() => _newItems.removeAt(index));
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Total: ${NumberFormatter.formatRupiah(newItem.unitPrice * newItem.quantity)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    iconSize: 18,
                                    onPressed: newItem.quantity > 1
                                        ? () {
                                            setState(() {
                                              _newItems[index] = (
                                                productId: newItem.productId,
                                                productName: newItem.productName,
                                                quantity: newItem.quantity - 1,
                                                unitPrice: newItem.unitPrice,
                                                hpp: newItem.hpp,
                                              );
                                            });
                                          }
                                        : null,
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      '${newItem.quantity}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    iconSize: 18,
                                    onPressed: () {
                                      setState(() {
                                        _newItems[index] = (
                                          productId: newItem.productId,
                                          productName: newItem.productName,
                                          quantity: newItem.quantity + 1,
                                          unitPrice: newItem.unitPrice,
                                          hpp: newItem.hpp,
                                        );
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Item Baru',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Get product provider to lookup product IDs
                    final productProvider = context.read<ProductProvider>();
                    
                    // Create updated items with new quantities and product names
                    final updatedItems = <SaleItem>[];
                    _itemQuantitiesByProduct.forEach((originalProductName, newQuantity) {
                      final originalItemIds = _itemIdsByProduct[originalProductName] ?? [];
                      if (originalItemIds.isEmpty) {
                        print('⚠️ No items found for product $originalProductName');
                        return;
                      }
                      
                      final originalItem = widget.transaction.items.firstWhere(
                        (item) => originalItemIds.contains(item.id),
                        orElse: () => widget.transaction.items.first,
                      );
                      
                      // Get the new product name (might have changed via dropdown)
                      final newProductName = _itemProductNamesByProduct[originalProductName] ?? originalProductName;
                      var newUnitPrice = _itemUnitPriceByProduct[originalProductName] ?? originalItem.unitPrice;
                      var newHpp = _itemHppByProduct[originalProductName] ?? originalItem.hpp;
                      var newProductId = originalItem.productId;
                      
                      if (newProductName != originalItem.productName) {
                        // Product name changed, need to find new product ID
                        try {
                          final newProduct = productProvider.products.firstWhere(
                            (p) => p.name == newProductName,
                          );
                          newProductId = newProduct.id;
                          print('✅ Product changed from ${originalItem.productName} to $newProductName');
                          print('   New price: Rp ${newUnitPrice.toInt()}');
                          print('   New HPP: Rp ${newHpp.toInt()}');
                        } catch (e) {
                          print('⚠️ Could not find product ID for $newProductName, keeping original');
                        }
                      }
                      
                      print('🔄 Item ${originalItem.id}:');
                      print('   Original: ${originalItem.productName} (ID: ${originalItem.productId}) @ Rp ${originalItem.unitPrice.toInt()}');
                      print('   New: $newProductName (ID: $newProductId) @ Rp ${newUnitPrice.toInt()}');
                      print('   Quantity: $newQuantity');
                      
                      // Create new item with updated quantity and product info
                      updatedItems.add(SaleItem(
                        id: originalItem.id,
                        saleId: originalItem.saleId,
                        productId: newProductId,
                        productName: newProductName,
                        quantity: newQuantity,
                        unitPrice: newUnitPrice,
                        hpp: newHpp,
                        createdAt: originalItem.createdAt,
                      ));
                    });

                    // 🆕 Add newly added items
                    for (var newItem in _newItems) {
                      updatedItems.add(SaleItem(
                        id: '', // New item, will be generated by database
                        saleId: widget.transaction.id,
                        productId: newItem.productId,
                        productName: newItem.productName,
                        quantity: newItem.quantity,
                        unitPrice: newItem.unitPrice,
                        hpp: newItem.hpp,
                        createdAt: DateTime.now(),
                      ));
                      print('🆕 Added new item: ${newItem.productName} x${newItem.quantity}');
                    }

                    // Calculate new totals
                    final newTotalAmount = updatedItems.fold(0.0, (sum, item) => sum + item.subtotal);
                    final newTotalHpp = updatedItems.fold(0.0, (sum, item) => sum + item.totalHpp);
                    final newProfit = newTotalAmount - newTotalHpp;
                    
                    print('💾 Saving updated sale:');
                    print('   Total Amount: $newTotalAmount');
                    print('   Total HPP: $newTotalHpp');
                    print('   Profit: $newProfit');
                    
                    // Create updated sale
                    final updatedSale = Sale(
                      id: widget.transaction.id,
                      outletId: widget.transaction.outletId,
                      baristaId: widget.transaction.baristaId,
                      paymentMethod: _paymentMethod,
                      totalAmount: newTotalAmount,
                      totalHpp: newTotalHpp,
                      totalBonus: widget.transaction.totalBonus,
                      profit: newProfit,
                      items: updatedItems,
                      createdAt: widget.transaction.createdAt,
                      isEdited: true,
                      editedAt: DateTime.now(),
                    );
                    widget.onSave(updatedSale);
                  },
                  child: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

