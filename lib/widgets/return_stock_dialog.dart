import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/supabase_service.dart';
import '../theme/thema.dart';

class ReturnStockDialog extends StatefulWidget {
  final String outletId;
  final List<OutletStock> availableStock;
  final VoidCallback onReturnSuccess;

  const ReturnStockDialog({
    required this.outletId,
    required this.availableStock,
    required this.onReturnSuccess,
    super.key,
  });

  @override
  State<ReturnStockDialog> createState() => _ReturnStockDialogState();
}

class _ReturnStockDialogState extends State<ReturnStockDialog> {
  final supabaseService = SupabaseService();
  String? _selectedIngredientId;
  String? _selectedIngredientName;
  String _selectedReason = 'damage';
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  final List<String> _returnReasons = [
    'damage',
    'expired',
    'excess',
    'quality_issue',
    'other',
  ];

  final Map<String, String> _reasonLabels = {
    'damage': 'Rusak',
    'expired': 'Kadaluarsa',
    'excess': 'Stok Berlebih',
    'quality_issue': 'Masalah Kualitas',
    'other': 'Lainnya',
  };

  Future<void> _submitReturn() async {
    if (_selectedIngredientId == null ||
        _quantityController.text.isEmpty ||
        _quantityController.text == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih produk dan masukkan jumlah')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final quantity = double.parse(_quantityController.text);
      final returnId = await supabaseService.createStockReturn(
        outletId: widget.outletId,
        ingredientId: _selectedIngredientId!,
        quantity: quantity,
        reason: _selectedReason,
      );

      if (returnId != null) {
        if (mounted) {
          Navigator.pop(context);
          widget.onReturnSuccess();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pengembalian stok berhasil dibuat')),
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
          title: const Text('Pengembalian Stok'),
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
                // Product selector
                const Text(
                  'Pilih Produk',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Pilih produk yang dikembalikan'),
                  value: _selectedIngredientId,
                  items: widget.availableStock
                      .map<DropdownMenuItem<String>>((stock) {
                        return DropdownMenuItem<String>(
                          value: stock.ingredientId,
                          child: Text(
                            '${stock.ingredientName} (Stok: ${stock.quantity.toStringAsFixed(1)})',
                          ),
                        );
                      })
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedIngredientId = value;
                      _selectedIngredientName = widget.availableStock
                          .firstWhere((s) => s.ingredientId == value)
                          .ingredientName;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Quantity
                const Text(
                  'Jumlah Pengembalian',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: 'Masukkan jumlah',
                    suffixText: _selectedIngredientName != null ? 'unit' : null,
                  ),
                ),
                const SizedBox(height: 24),

                // Reason
                const Text(
                  'Alasan Pengembalian',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedReason,
                  items: _returnReasons
                      .map<DropdownMenuItem<String>>((reason) {
                        return DropdownMenuItem<String>(
                          value: reason,
                          child: Text(_reasonLabels[reason] ?? reason),
                        );
                      })
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedReason = value ?? 'damage');
                  },
                ),
                const SizedBox(height: 24),

                // Notes
                const Text(
                  'Catatan Tambahan (Opsional)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Tambahkan catatan jika ada',
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitReturn,
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
                        : const Text('Buat Pengembalian'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
