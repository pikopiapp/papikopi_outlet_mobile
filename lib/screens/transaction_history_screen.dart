import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../services/supabase_service.dart';
import '../theme/thema.dart';
import '../utils/number_formatter.dart';
import '../models/sale.dart';
import '../widgets/screen_skeleton.dart';


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

      setState(() {
        _transactions = sales;
        _isLoading = false;
      });
    } catch (e) {
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
          ? const ScreenSkeleton(lineCount: 8, showTitle: false)
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
                    // Special tracking for target transaction
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
          await _updateTransaction(editedTransaction);
          
          // Close dialog only after update is done
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Future<void> _updateTransaction(Sale transaction) async {
    try {
      // Update sales table with new payment method and edit tracking
      final updatedData = {
        'is_edited': true,
        'edited_at': DateTime.now().toIso8601String(),
        'payment_method': transaction.paymentMethod,
        'total_amount': transaction.totalAmount,
        'hpp_total': transaction.totalHpp,
        'profit': transaction.profit,
      };

      await _supabase.client
          .from('sales')
          .update(updatedData)
          .eq('id', transaction.id);

      // Update sale items - update each existing item with new values
      for (var item in transaction.items) {
        final itemSubtotal = item.quantity * item.unitPrice;
        final itemTotalHpp = item.quantity * item.hpp;
        
        // 🆕 Check if this is a new item (id is empty string or doesn't exist in original)
        final isNewItem = item.id.isEmpty || !_transactions.any((t) => 
          t.id == transaction.id && t.items.any((i) => i.id == item.id)
        );
        
        if (isNewItem) {
          // 🆕 INSERT new item
          
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
          } catch (e) {
          }
        } else {
          // Update existing item
          
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
          } catch (e) {
          }
        }
      }

      // Add delay to ensure all updates are committed to database
      await Future.delayed(const Duration(seconds: 1));

      // Reload transactions
      await _loadTransactions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Pesanan berhasil diperbarui')),
        );
      }
    } catch (e) {
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
    const validMethods = ['CASH', 'QRIS', 'GRATIS'];
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
    
    for (var item in widget.transaction.items) {
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
      } catch (e) {
      }
    } catch (e) {
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
                    DropdownMenuItem(value: 'GRATIS', child: Text('Gratis')),
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
                        } catch (e) {
                        }
                      }

                      
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
                    }

                    // Calculate new totals
                    final newTotalAmount = updatedItems.fold(0.0, (sum, item) => sum + item.subtotal);
                    final newTotalHpp = updatedItems.fold(0.0, (sum, item) => sum + item.totalHpp);
                    final newProfit = newTotalAmount - newTotalHpp;
                    
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

