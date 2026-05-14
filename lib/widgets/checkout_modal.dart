import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/supabase_service.dart';
import '../theme/thema.dart';

class CheckoutModal extends StatefulWidget {
  final TabController? tabController;

  const CheckoutModal({super.key, this.tabController});

  @override
  State<CheckoutModal> createState() => _CheckoutModalState();
}

class _CheckoutModalState extends State<CheckoutModal> {
  String _selectedPaymentMethod = 'CASH';
  bool _isProcessing = false;

  // Get the tabController from widget prop or try to find from context
  TabController? get tabController {
    return widget.tabController ?? DefaultTabController.maybeOf(context);
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
      final totalAmount = cartProvider.totalAmount;
      final totalHpp = cartProvider.totalHpp;
      final totalBonus = (totalAmount * 0.05).toDouble(); // 5% bonus
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
      print('💳 Creating sale in POS system...');
      print('   Outlet: ${authProvider.currentUser!.outletId}');
      print('   Barista: ${authProvider.currentUser!.id}');
      print('   Payment: $_selectedPaymentMethod');
      print('   Amount: $totalAmount');
      print('   Items: ${items.length}');
      
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
      print('✅ Sale created successfully with ID: $saleId');
      print('   Check database: SELECT * FROM sales WHERE id = $saleId');

      // Record sales to warehouse system (sales_records table)
      // This tracks batch sales for inventory management
      print('📊 Recording sales to warehouse system...');
      
      try {
        // Get available batches for this outlet
        final batches = await supabaseService.getAvailableBatches(
          authProvider.currentUser!.outletId,
        );
        
        if (batches.isEmpty) {
          print('⚠️ Warning: No batches found for outlet, skipping warehouse recording');
        } else {
          print('📦 Found ${batches.length} available batches');
          
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
              print('🛒 Recording ${cartItem.quantity} units of ${cartItem.product.name} from batch ${matchingBatch['batch_code']}');
              
              await supabaseService.recordSaleToWarehouse(
                batchId: matchingBatch['id'] as String,
                outletId: authProvider.currentUser!.outletId,
                quantitySold: cartItem.quantity,
                saleDate: DateTime.now(),
                notes: 'Penjualan dari POS - ${cartItem.product.name} - Payment: $_selectedPaymentMethod',
              );
              
              // Update batch quantity (reduce stock)
              await supabaseService.updateBatchQuantity(
                batchId: matchingBatch['id'] as String,
                quantitySold: cartItem.quantity,
              );
              
              print('✅ Recorded sale for ${cartItem.product.name}');
            } else {
              print('⚠️ Warning: No matching batch found for ${cartItem.product.name}');
            }
          }
          
          print('✅ All sales recorded to warehouse system');
        }
      } catch (e) {
        print('⚠️ Warning: Failed to record to warehouse: $e');
        // Don't fail checkout if warehouse recording fails - it's a secondary system
      }

      if (mounted) {
        // Clear cart
        cartProvider.clear();

// Show success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil')),
        );

// Navigate back to first tab
        if (tabController != null) {
          tabController!.animateTo(0); // Go back to first tab (Pemesanan)
        } else {
          // Try Navigator if TabController not available
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ Checkout error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
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
                            'Rp${cartProvider.totalAmount.toStringAsFixed(0)}',
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
                                setState(() =>
_selectedPaymentMethod = value ?? 'CASH');
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
                                setState(() =>
                                    _selectedPaymentMethod = value ?? 'CASH');
                              },
                        contentPadding: EdgeInsets.zero,
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
                            : () => tabController?.animateTo(1),
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
    );
  }
}
