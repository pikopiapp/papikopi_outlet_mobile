import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/thema.dart';
import '../../services/supabase_service.dart';

class ExpenseManagementScreen extends StatefulWidget {
  const ExpenseManagementScreen({super.key});

  @override
  State<ExpenseManagementScreen> createState() => _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends State<ExpenseManagementScreen> {
  late SupabaseService supabaseService;
  late DateTime selectedDate;
  bool isLoading = true;

  double totalExpense = 0;
  List<Map<String, dynamic>> expenses = [];

  final List<String> expenseCategories = [
    'Bahan Baku',
    'Listrik & Utilitas',
    'Service & Maintenance',
    'Supplies & Perlengkapan',
    'Lainnya',
  ];

  final Map<String, IconData> categoryIcons = {
    'Bahan Baku': Icons.shopping_bag,
    'Listrik & Utilitas': Icons.electrical_services,
    'Service & Maintenance': Icons.handyman,
    'Supplies & Perlengkapan': Icons.inventory_2,
    'Lainnya': Icons.more_horiz,
  };

  final Map<String, Color> categoryColors = {
    'Bahan Baku': Color(0xFF8B4513),
    'Listrik & Utilitas': Color(0xFFFFA500),
    'Service & Maintenance': Color(0xFF4169E1),
    'Supplies & Perlengkapan': Color(0xFF28A745),
    'Lainnya': Color(0xFF6C757D),
  };

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    supabaseService = SupabaseService();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => isLoading = true);
    try {
      final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await supabaseService.client
          .from('expenses')
          .select()
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .order('created_at', ascending: false);

      double total = 0;
      for (var expense in response) {
        total += (expense['amount'] as num?)?.toDouble() ?? 0;
      }

      setState(() {
        expenses = List<Map<String, dynamic>>.from(response);
        totalExpense = total;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      _loadExpenses();
    }
  }

  void _showAddExpenseDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: Colors.orange),
                title: const Text('Pencatatan General Expense'),
                subtitle: const Text('Pengeluaran umum: listrik, supplies, dll'),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: this.context,
                    isScrollControlled: true,
                    builder: (_) => _AddExpenseBottomSheet(
                      supabaseService: supabaseService,
                      selectedDate: selectedDate,
                      categories: expenseCategories,
                      onAdded: _loadExpenses,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.shopping_cart_outlined, color: Colors.blue),
                title: const Text('Pencatatan Inventory Purchasing'),
                subtitle: const Text('Belanja bahan baku, stok, dll (via web)'),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: this.context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Arahkan ke Web'),
                      content: const Text('Pencatatan pembelian bahan baku & stok dilakukan di dashboard web (menu Inventory).'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Tutup'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditExpenseDialog(Map<String, dynamic> expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditExpenseBottomSheet(
        supabaseService: supabaseService,
        expense: expense,
        categories: expenseCategories,
        onUpdated: _loadExpenses,
      ),
    );
  }

  void _deleteExpense(String expenseId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pengeluaran?'),
        content: const Text('Apakah Anda yakin ingin menghapus pengeluaran ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await supabaseService.client
                    .from('expenses')
                    .delete()
                    .eq('id', expenseId);
                _loadExpenses();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pengeluaran berhasil dihapus')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');
    final dayFormat = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');
    final isToday = DateTime.now().day == selectedDate.day &&
        DateTime.now().month == selectedDate.month &&
        DateTime.now().year == selectedDate.year;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pencatatan Pengeluaran'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadExpenses,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: media.padding.bottom + 100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date picker
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.altSurface),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isToday ? 'Hari Ini' : dayFormat.format(selectedDate),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                if (isToday)
                                  Text(
                                    dateFormat.format(selectedDate),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.expand_more,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Total expense card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.red.shade600,
                            Colors.red.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isToday ? 'Total Pengeluaran Hari Ini' : 'Total Pengeluaran ${dateFormat.format(selectedDate)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.trending_down,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currencyFormat.format(totalExpense),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${expenses.length} item pengeluaran',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Expenses list
                    expenses.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.altSurface),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 48,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isToday ? 'Belum ada pengeluaran hari ini' : 'Belum ada pengeluaran pada tanggal tersebut',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: List.generate(expenses.length, (index) {
                              final expense = expenses[index];
                              final category = expense['category'];
                              final amount = (expense['amount'] as num?)?.toDouble() ?? 0;
                              final timestamp = DateTime.parse(expense['created_at']);
                              final timeString = DateFormat('HH:mm', 'id_ID').format(timestamp);

                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index < expenses.length - 1 ? 12 : 0,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Color(0xFFE8E8E8)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: (categoryColors[category] ?? AppColors.primary)
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          categoryIcons[category] ?? Icons.receipt,
                                          color: categoryColors[category] ?? AppColors.primary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              category,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Color(0xFF1F1F1F),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              expense['description'] ?? '-',
                                              style: const TextStyle(
                                                color: Color(0xFF999999),
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              timeString,
                                              style: const TextStyle(
                                                color: Color(0xFFCCCCCC),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '- ${currencyFormat.format(amount)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.red,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          PopupMenuButton(
                                            itemBuilder: (_) => [
                                              PopupMenuItem(
                                                child: const Text('Edit'),
                                                onTap: () => Future.delayed(
                                                  const Duration(milliseconds: 200),
                                                  () => _showEditExpenseDialog(expense),
                                                ),
                                              ),
                                              PopupMenuItem(
                                                child: const Text(
                                                  'Hapus',
                                                  style: TextStyle(color: Colors.red),
                                                ),
                                                onTap: () => Future.delayed(
                                                  const Duration(milliseconds: 200),
                                                  () => _deleteExpense(expense['id']),
                                                ),
                                              ),
                                            ],
                                            child: const Icon(
                                              Icons.more_vert,
                                              size: 20,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddExpenseBottomSheet extends StatefulWidget {
  final SupabaseService supabaseService;
  final DateTime selectedDate;
  final List<String> categories;
  final VoidCallback onAdded;

  const _AddExpenseBottomSheet({
    required this.supabaseService,
    required this.selectedDate,
    required this.categories,
    required this.onAdded,
  });

  @override
  State<_AddExpenseBottomSheet> createState() => _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends State<_AddExpenseBottomSheet> {
  late String selectedCategory;
  late TextEditingController descriptionController;
  late TextEditingController amountController;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.categories.first;
    descriptionController = TextEditingController();
    amountController = TextEditingController();
  }

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> _addExpense() async {
    if (amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan jumlah pengeluaran')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      await widget.supabaseService.client.from('expenses').insert({
        'category': selectedCategory,
        'description': descriptionController.text,
        'amount': double.parse(amountController.text),
        'created_at': widget.selectedDate.toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengeluaran berhasil ditambahkan')),
        );
        widget.onAdded();
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tambah Pengeluaran',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Kategori',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.altSurface),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedCategory,
              underline: const SizedBox(),
              items: widget.categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedCategory = value);
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Deskripsi',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionController,
            decoration: InputDecoration(
              hintText: 'Misal: Beli biji kopi, Service AC, dll',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Text(
            'Jumlah (Rp)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '0',
              prefixText: 'Rp ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : _addExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Simpan Pengeluaran'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Batal',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditExpenseBottomSheet extends StatefulWidget {
  final SupabaseService supabaseService;
  final Map<String, dynamic> expense;
  final List<String> categories;
  final VoidCallback onUpdated;

  const _EditExpenseBottomSheet({
    required this.supabaseService,
    required this.expense,
    required this.categories,
    required this.onUpdated,
  });

  @override
  State<_EditExpenseBottomSheet> createState() => _EditExpenseBottomSheetState();
}

class _EditExpenseBottomSheetState extends State<_EditExpenseBottomSheet> {
  late String selectedCategory;
  late TextEditingController descriptionController;
  late TextEditingController amountController;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.expense['category'];
    descriptionController = TextEditingController(text: widget.expense['description'] ?? '');
    amountController = TextEditingController(text: widget.expense['amount'].toString());
  }

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> _updateExpense() async {
    if (amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan jumlah pengeluaran')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      await widget.supabaseService.client
          .from('expenses')
          .update({
            'category': selectedCategory,
            'description': descriptionController.text,
            'amount': double.parse(amountController.text),
          })
          .eq('id', widget.expense['id']);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengeluaran berhasil diperbarui')),
        );
        widget.onUpdated();
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Pengeluaran',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Kategori',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.altSurface),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedCategory,
              underline: const SizedBox(),
              items: widget.categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedCategory = value);
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Deskripsi',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionController,
            decoration: InputDecoration(
              hintText: 'Misal: Beli biji kopi, Service AC, dll',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Text(
            'Jumlah (Rp)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '0',
              prefixText: 'Rp ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : _updateExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Simpan Perubahan'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Batal',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
