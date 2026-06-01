import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../services/supabase_service.dart';
import '../theme/thema.dart';
import '../utils/number_formatter.dart';

class CheckoutModal extends StatefulWidget {
  final TabController? tabController;

  const CheckoutModal({super.key, this.tabController});

  @override
  State<CheckoutModal> createState() => _CheckoutModalState();
}

class _CheckoutModalState extends State<CheckoutModal> {
  String _selectedPaymentMethod = 'CASH';
  String _gratiReason = '';
  bool _isProcessing = false;
  bool _showWarning = false;
  String _warningMessage = '';

  // Get the tabController from widget prop or try to find from context
  TabController? get tabController {
    return widget.tabController ?? DefaultTabController.maybeOf(context);
  }

  Future<void> _showGratisReasonDialog() async {
    final List<String> reasons = ['Preman', 'Sample', 'Rusak/Expired', 'Permintaan Manager', 'Lainnya'];
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alasan Gratis'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons
                .map((reason) => RadioListTile<String>(
                      title: Text(reason),
                      value: reason,
                      groupValue: _gratiReason,
                      onChanged: (value) {
                        setState(() => _gratiReason = value ?? '');
                        Navigator.pop(context);
                      },
                      contentPadding: EdgeInsets.zero,
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkMonthlyGratisLimit() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final supabaseService = SupabaseService();
      
      if (authProvider.currentUser == null) return;

      // Get current month's transactions
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      
      final result = await supabaseService.getMonthlyGratisStats(
        outletId: authProvider.currentUser!.outletId,
        monthStart: monthStart,
      );
      
      final totalTransactions = result['total'] as int;
      final gratisCount = result['gratis_count'] as int;
      
      if (totalTransactions == 0) {
        setState(() {
          _showWarning = false;
          _warningMessage = '';
        });
        return;
      }
      
      final gratisPercentage = (gratisCount / totalTransactions) * 100;
      
      if (gratisPercentage >= 3.0) {
        setState(() {
          _showWarning = true;
          _warningMessage = '⚠️ Limit gratis 3% sudah tercapai! (${gratisPercentage.toStringAsFixed(1)}% dari $totalTransactions transaksi)';
        });
      } else {
        setState(() {
          _showWarning = false;
          _warningMessage = 'Gratis: ${gratisPercentage.toStringAsFixed(1)}% dari 3% limit';
        });
      }
    } catch (e) {
    }
  }


  Future<void> _handleCheckout() async {
    final cartProvider = context.read<CartProvider>();
    final authProvider = context.read<AuthProvider>();
    final supabaseService = SupabaseService();

    // Validation
    if (cartProvider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang kosong')),
      );
      return;
    }

    // Validate Gratis has reason selected
    if (_selectedPaymentMethod == 'GRATIS' && _gratiReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih alasan untuk transaksi gratis')),
      );
      return;
    }

    // Check gratis limit if gratis
    if (_selectedPaymentMethod == 'GRATIS') {
      if (_showWarning) {
        // Hard block: Show error dialog - cannot proceed
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('❌ Limit Gratis Tercapai'),
              content: Text(_warningMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return; // Stop checkout
      }
    }

    if (authProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User tidak ditemukan')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Check if Supabase is initialized
      if (!supabaseService.isInitialized) {
        throw Exception('Sistem belum terhubung ke server');
      }
      
      // Calculate totals
      double totalAmount = _selectedPaymentMethod == 'GRATIS' 
          ? 0 
          : cartProvider.totalAmount;
      final totalHpp = cartProvider.totalHpp;
      final totalBonus = _selectedPaymentMethod == 'GRATIS'
          ? 0.0
          : (totalAmount * 0.05); // 5% bonus
      final profit = totalAmount - totalHpp;

      // Prepare sale items
      final items = cartProvider.items
          .map((item) => {
                'product_id': item.product.id,
                'product_name': item.product.name,
                'quantity': item.quantity,
                'unit_price': item.product.price,
                'hpp': item.product.hpp ?? 0,
              })
          .toList();

      // Create sale in POS system
      if (_selectedPaymentMethod == 'GRATIS') {
      }
      
      final saleId = await supabaseService.createSale(
        outletId: authProvider.currentUser!.outletId,
        baristaId: authProvider.currentUser!.id,
        paymentMethod: _selectedPaymentMethod,
        totalAmount: totalAmount,
        totalHpp: totalHpp,
        totalBonus: totalBonus,
        profit: profit,
        items: items,
      );

      // Record sales to warehouse system (sales_records table)
      // This tracks batch sales for inventory management
      
      try {
        // Get available batches for this outlet
        final batches = await supabaseService.getAvailableBatches(
          authProvider.currentUser!.outletId,
        );
        
        if (batches.isEmpty) {
        } else {
          
          // Record sales for each product in cart to matching batch
          for (final cartItem in cartProvider.items) {
            // Find batch with matching product
            Map<String, dynamic>? matchingBatch;
            for (final batch in batches) {
              if (batch['product_id'] == cartItem.product.id && 
                  batch['quantity'] >= cartItem.quantity) {
                matchingBatch = batch;
                break;
              }
            }
            
            if (matchingBatch != null) {
              
              // Build notes with gratis reason if applicable
              String notes = 'Penjualan dari POS - ${cartItem.product.name} - Payment: $_selectedPaymentMethod';
              if (_selectedPaymentMethod == 'GRATIS') {
                notes += ' - Alasan: $_gratiReason';
              }
              
              await supabaseService.recordSaleToWarehouse(
                batchId: matchingBatch['id'] as String,
                outletId: authProvider.currentUser!.outletId,
                quantitySold: cartItem.quantity,
                saleDate: DateTime.now(),
                notes: notes,
              );
              
              // Update batch quantity (reduce stock)
              await supabaseService.updateBatchQuantity(
                batchId: matchingBatch['id'] as String,
                quantitySold: cartItem.quantity,
              );
              
            } else {
            }
          }
          
        }
      } catch (e) {
        // Don't fail checkout if warehouse recording fails - it's a secondary system
      }

      if (mounted) {
        // 🔧 Refresh product stock after sale
        try {
          final productProvider = context.read<ProductProvider>();
          await productProvider.loadProductsWithStock(
            authProvider.currentUser!.outletId,
          );
        } catch (e) {
        }

        // Clear cart
        cartProvider.clear();

        // Show success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Transaksi berhasil')),
        );

        // Add small delay to ensure data is persisted before refresh
        await Future.delayed(const Duration(milliseconds: 500));

        // Close dialog and navigate to ordering tab
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
          // Go to ordering tab (index 0) to start new order
          tabController?.animateTo(0);
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        setState(() => _isProcessing = false);
      }
    } finally {
      if (mounted) {
        // Make sure to reset processing state if not already done in catch
        if (_isProcessing) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Consumer<CartProvider>(
        builder: (context, cartProvider, _) {
          return SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  const Text(
                    'Konfirmasi Checkout',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Order Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.altSurface),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ringkasan Pesanan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Item:'),
                            Text('${cartProvider.totalQuantity}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Harga:'),
                            Text(
                              NumberFormatter.formatRupiah(cartProvider.totalAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        // HPP and Profit are hidden for outlet staff but still calculated and stored
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Payment Method
                  const Text(
                    'Metode Pembayaran',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Cash'),
                              value: 'CASH',
                              groupValue: _selectedPaymentMethod,
                              onChanged: _isProcessing
                                  ? null
                                  : (value) {
                                      setState(() => _selectedPaymentMethod = value ?? 'CASH');
                                    },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('QRIS'),
                              value: 'QRIS',
                              groupValue: _selectedPaymentMethod,
                              onChanged: _isProcessing
                                  ? null
                                  : (value) {
                                      setState(() => _selectedPaymentMethod = value ?? 'CASH');
                                    },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      // Gratis button - only for barista
                      if (context.read<AuthProvider>().currentUser?.role == 'barista')
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              RadioListTile<String>(
                                title: Row(
                                  children: [
                                    const Text('Gratis'),
                                    if (_selectedPaymentMethod == 'GRATIS')
                                      Text(
                                        ' - ${_gratiReason.isNotEmpty ? _gratiReason : "(Pilih alasan)"}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                                value: 'GRATIS',
                                groupValue: _selectedPaymentMethod,
                                onChanged: _isProcessing
                                    ? null
                                    : (value) async {
                                        if (value != null) {
                                          setState(() => _selectedPaymentMethod = value);
                                          await _checkMonthlyGratisLimit();
                                          await _showGratisReasonDialog();
                                        }
                                      },
                                contentPadding: EdgeInsets.zero,
                              ),
                              // Warning message
                              if (_selectedPaymentMethod == 'GRATIS' && _warningMessage.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, top: 4),
                                  child: Text(
                                    _warningMessage,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _showWarning ? Colors.red[400] : Colors.green[400],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isProcessing
                              ? null
                              : () {
                                  Navigator.pop(context);
                                },
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _handleCheckout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Checkout',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
