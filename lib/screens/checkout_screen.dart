import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../theme/thema.dart';
import '../utils/number_formatter.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late DateTime _selectedDate;
  String _paymentMethod = 'CASH';
  Product? _selectedDrink;
  int _quantity = 0;
  final _quantityController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  double _calculateTotal() {
    if (_selectedDrink == null) return 0;
    return (_selectedDrink!.price * _quantity).toDouble();
  }

  void _addToCart() {
    if (_selectedDrink == null || _quantity == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minuman dan jumlah')),
      );
      return;
    }

    final cartProvider = context.read<CartProvider>();
    for (int i = 0; i < _quantity; i++) {
      cartProvider.addItem(_selectedDrink!);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_quantity}x ${_selectedDrink!.name} ditambahkan')),
    );

    // Reset form
    setState(() {
      _selectedDrink = null;
      _quantity = 0;
      _quantityController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 40),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Checkout',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Section
              Text(
                'Tanggal',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[600]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('MM/dd/yyyy').format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Icon(Icons.calendar_today, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Payment Method
              Text(
                'Pembayaran',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.amber[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => _paymentMethod = 'CASH'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _paymentMethod == 'CASH'
                            ? Colors.teal[600]
                            : Colors.grey[800],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Cash',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => _paymentMethod = 'QRIS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _paymentMethod == 'QRIS'
                            ? Colors.teal[600]
                            : Colors.grey[800],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'QRIS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Drink Selection
              Text(
                'Nama Minuman*',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.amber[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Consumer<ProductProvider>(
                builder: (context, productProvider, _) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[600]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<Product>(
                      value: _selectedDrink,
                      hint: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Pilih minuman'),
                      ),
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: productProvider.products
                          .map((product) => DropdownMenuItem(
                                value: product,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(product.name),
                                ),
                              ))
                          .toList(),
                      onChanged: (product) {
                        setState(() => _selectedDrink = product);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Quantity
              Text(
                'QTY*',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.amber[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[600]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: _quantity > 0
                          ? () {
                              setState(() {
                                _quantity--;
                                _quantityController.text = _quantity.toString();
                              });
                            }
                          : null,
                      color: Colors.grey[400],
                    ),
                    Expanded(
                      child: TextField(
                        controller: _quantityController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 16),
                        onChanged: (value) {
                          setState(() {
                            _quantity = int.tryParse(value) ?? 0;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        setState(() {
                          _quantity++;
                          _quantityController.text = _quantity.toString();
                        });
                      },
                      color: Colors.amber[700],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Total
              Text(
                'Total',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.amber[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[600]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: Text(
                  NumberFormatter.formatRupiah(_calculateTotal()),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color.fromARGB(255, 100, 100, 100),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[600]!),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _addToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[600],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
