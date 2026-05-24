import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/supabase_service.dart';
import '../theme/thema.dart';

class MoveStockDialog extends StatefulWidget {
  final String fromOutletId;
  final List<OutletStock> availableStock;
  final VoidCallback onMoveSuccess;

  const MoveStockDialog({
    required this.fromOutletId,
    required this.availableStock,
    required this.onMoveSuccess,
    super.key,
  });

  @override
  State<MoveStockDialog> createState() => _MoveStockDialogState();
}

class _MoveStockDialogState extends State<MoveStockDialog> {
  final supabaseService = SupabaseService();
  String? _selectedDestOutletId;
  final _moveItems = <Map<String, dynamic>>[];
  bool _isLoading = false;
  List<dynamic> _outlets = [];

  @override
  void initState() {
    super.initState();
    _loadOutlets();
  }

  void _loadOutlets() async {
    try {
      final response = await supabaseService.client
          .from('outlets')
          .select();
      setState(() {
        _outlets = response;
      });
    } catch (e) {
      // Error loading outlets silently
    }
  }

  void _addMoveItem(String ingredientId, String ingredientName) {
    final existingIndex = _moveItems.indexWhere(
      (item) => item['ingredient_id'] == ingredientId,
    );

    if (existingIndex >= 0) {
      setState(() {
        _moveItems[existingIndex]['quantity'] += 1;
      });
    } else {
      setState(() {
        _moveItems.add({
          'ingredient_id': ingredientId,
          'ingredient_name': ingredientName,
          'quantity': 1.0,
        });
      });
    }
  }

  void _removeMoveItem(int index) {
    setState(() {
      _moveItems.removeAt(index);
    });
  }

  void _updateItemQuantity(int index, double quantity) {
    setState(() {
      _moveItems[index]['quantity'] = quantity;
    });
  }

  Future<void> _submitMove() async {
    if (_selectedDestOutletId == null || _moveItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih outlet tujuan dan produk')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final moveId = await supabaseService.createStockTransfer(
        fromOutletId: widget.fromOutletId,
        toOutletId: _selectedDestOutletId!,
        items: _moveItems,
      );

      if (moveId != null) {
        if (mounted) {
          Navigator.pop(context);
          widget.onMoveSuccess();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pindah stok berhasil dibuat')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pindah Stok'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Destination outlet selector
                const Text(
                  'Outlet Tujuan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Pilih outlet tujuan'),
                  value: _selectedDestOutletId,
                  items: _outlets
                      .where((outlet) => outlet['id'] != widget.fromOutletId)
                      .map<DropdownMenuItem<String>>((outlet) {
                        return DropdownMenuItem<String>(
                          value: outlet['id'],
                          child: Text(outlet['name'] ?? 'Unknown Outlet'),
                        );
                      })
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedDestOutletId = value);
                  },
                ),
                const SizedBox(height: 24),

                // Available products
                const Text(
                  'Pilih Produk untuk Dipindahkan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.availableStock.length,
                    itemBuilder: (context, index) {
                      final stock = widget.availableStock[index];
                      return ListTile(
                        title: Text(stock.ingredientName),
                        subtitle: Text('Stok tersedia: ${stock.quantity}'),
                        trailing: ElevatedButton.icon(
                          onPressed: stock.quantity > 0
                              ? () => _addMoveItem(
                                    stock.ingredientId,
                                    stock.ingredientName,
                                  )
                              : null,
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Selected items
                if (_moveItems.isNotEmpty) ...[
                  const Text(
                    'Produk yang Akan Dipindahkan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _moveItems.length,
                    itemBuilder: (context, index) {
                      final item = _moveItems[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['ingredient_name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.all(8),
                                  border: OutlineInputBorder(),
                                  hintText: 'Qty',
                                ),
                                controller: TextEditingController(
                                  text: item['quantity'].toString(),
                                ),
                                onChanged: (value) {
                                  final qty = double.tryParse(value) ?? 1;
                                  _updateItemQuantity(index, qty);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeMoveItem(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitMove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Kirim Pindah Stok'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
