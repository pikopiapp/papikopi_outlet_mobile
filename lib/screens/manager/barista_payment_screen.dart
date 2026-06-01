import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';
import '../../utils/holiday_detector.dart';

// Helper function to format Rupiah
String formatRupiah(num? amount) {
  if (amount == null) return '0';
  final formatter = NumberFormat('#,###', 'id_ID');
  return formatter.format(amount.toInt());
}

class BaristaPaymentScreen extends StatefulWidget {
  const BaristaPaymentScreen({super.key});

  @override
  State<BaristaPaymentScreen> createState() => _BaristaPaymentScreenState();
}

class _BaristaPaymentScreenState extends State<BaristaPaymentScreen> {
  late DateTime _selectedDate;
  late SupabaseService _supabaseService;
  bool _isLoading = true;
  List<Map<String, dynamic>> _baristaPayments = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _supabaseService = SupabaseService();
    _loadBaristaPayments();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadBaristaPayments();
    }
  }

  Future<void> _loadBaristaPayments() async {
    setState(() => _isLoading = true);
    try {
      print('DEBUG _loadBaristaPayments - Loading for date: $_selectedDate');
      final payments = await _supabaseService.getAllBaristaPayments(
        selectedDate: _selectedDate,
      );
      
      print('DEBUG _loadBaristaPayments - Received payments: ${payments.length}');
      
      if (mounted) {
        setState(() {
          _baristaPayments = payments;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('DEBUG _loadBaristaPayments - Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showPaymentDialog(Map<String, dynamic> baristaData) {
    final baristaName = baristaData['name'] as String;
    final outletName = baristaData['outlet'] as String;
    final baristaId = baristaData['baristaId'] as String;
    final cashAmount = (baristaData['cashAmount'] as num?)?.toDouble() ?? 0.0;
    final qrisAmount = (baristaData['qrisAmount'] as num?)?.toDouble() ?? 0.0;
    final salesAmount = cashAmount + qrisAmount;
    final bonusData = baristaData['bonus'] as Map<String, dynamic>;
    final totalBonus = (bonusData['total'] as num).toDouble();
    final mealAllowance = (baristaData['mealAllowance'] as num).toDouble();
    final paymentStatus = baristaData['paymentStatus'] as String;
    
    // Calculate settlement
    final depositAmount = cashAmount - totalBonus - mealAllowance;
    final settlementType = depositAmount >= 0 ? 'deposit' : 'shortfall';
    final settlementAmount = depositAmount.abs();
    
    // Check if holiday
    final isHolidayDate = isHoliday(_selectedDate);
    final holidayDescription = isHolidayDate ? getHolidayDescription(_selectedDate) : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _supabaseService.getBaristaPaymentHistory(
            baristaId: baristaId,
            limit: 30,
          ),
          builder: (context, snapshot) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Barista Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            baristaName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            outletName,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Holiday Bonus Indicator
                    if (isHolidayDate)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Text('🎉', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bonus $holidayDescription: +20%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isHolidayDate) const SizedBox(height: 16),

                    // Omset Breakdown Section
                    Text(
                      'Omset:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBonusLine(
                            'Penjualan',
                            'Rp ${NumberFormat('#,##0', 'id_ID').format(salesAmount.toInt())}',
                            Colors.black,
                          ),
                          const SizedBox(height: 6),
                          _buildBonusLine(
                            '  ├─ Cash',
                            'Rp ${NumberFormat('#,##0', 'id_ID').format(cashAmount.toInt())}',
                            Colors.black87,
                          ),
                          const SizedBox(height: 4),
                          _buildBonusLine(
                            '  └─ QRIS',
                            'Rp ${NumberFormat('#,##0', 'id_ID').format(qrisAmount.toInt())}',
                            Colors.black87,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rincian Setoran Section
                    Text(
                      'Rincian Setoran:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: settlementType == 'deposit'
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: settlementType == 'deposit' ? Colors.green : Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBonusLine(
                            'CASH Diterima',
                            'Rp ${NumberFormat('#,##0', 'id_ID').format(cashAmount.toInt())}',
                            Colors.black,
                          ),
                          const SizedBox(height: 8),
                          _buildBonusLine(
                            '- Bonus (Bertahap)',
                            '-Rp ${NumberFormat('#,##0', 'id_ID').format(totalBonus.toInt())}',
                            Colors.red,
                          ),
                          const SizedBox(height: 4),
                          _buildBonusLine(
                            '- Uang Makan',
                            '-Rp ${NumberFormat('#,##0', 'id_ID').format(mealAllowance.toInt())}',
                            Colors.red,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: AppColors.altSurface, width: 1),
                              ),
                            ),
                            child: _buildBonusLine(
                              settlementType == 'deposit'
                                  ? '= Setoran ke Papikopi'
                                  : '= Kekurangan (dari Papikopi)',
                              'Rp ${NumberFormat('#,##0', 'id_ID').format(settlementAmount.toInt())}',
                              settlementType == 'deposit' ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Info formula
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
                      ),
                      child: Text(
                        'Rumus: Setoran = CASH - Bonus - Uang Makan\nQRIS langsung ke rekening toko',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: Colors.blue.shade700,
                              height: 1.3,
                            ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Status Section
                    Text(
                      '📊 Status Pembayaran',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),

                    // Status Badge
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: paymentStatus.toLowerCase() == 'approved'
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        border: Border.all(
                          color: paymentStatus.toLowerCase() == 'approved'
                              ? Colors.green
                              : Colors.orange,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            paymentStatus.toLowerCase() == 'approved'
                                ? Icons.check_circle
                                : Icons.schedule,
                            color: paymentStatus.toLowerCase() == 'approved'
                                ? Colors.green
                                : Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                paymentStatus.toLowerCase() == 'approved'
                                    ? 'Sudah Dibayar'
                                    : 'Menunggu Pembayaran',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: paymentStatus.toLowerCase() == 'approved'
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                              Text(
                                'Tanggal: ${DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // History Section
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) ...[
                      Text(
                        '📋 Riwayat Pembayaran',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final payment = snapshot.data![index];
                            final paymentDate = payment['date'] as String;
                            final bonus = (payment['bonus'] as num).toDouble();
                            final mealAllow = (payment['mealAllowance'] as num).toDouble();
                            final total = (payment['totalWage'] as num).toDouble();
                            final status = payment['status'] as String;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        paymentDate,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Bonus: Rp ${formatRupiah(bonus)} | Makan: Rp ${formatRupiah(mealAllow)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Rp ${formatRupiah(total)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: status.toLowerCase() == 'approved'
                                              ? Colors.green.shade100
                                              : Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          status.toLowerCase() == 'approved'
                                              ? 'Dibayar'
                                              : 'Pending',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: status.toLowerCase() == 'approved'
                                                ? Colors.green.shade700
                                                : Colors.orange.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Action Buttons
                    if (paymentStatus.toLowerCase() == 'pending')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _processPayment(baristaData);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Bayar Sekarang'),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade200,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Sudah Dibayar'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Tutup'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBonusLine(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
        ),
      ],
    );
  }

  Future<void> _processPayment(Map<String, dynamic> baristaData) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final baristaId = baristaData['baristaId'] as String;
      final success = await _supabaseService.approveBaristaPayment(
        baristaId: baristaId,
        date: _selectedDate,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Pembayaran berhasil diproses'),
              backgroundColor: Colors.green,
            ),
          );
          _loadBaristaPayments();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Gagal memproses pembayaran'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPaymentCard(Map<String, dynamic> baristaData) {
    final baristaName = baristaData['name'] as String;
    final outletName = baristaData['outlet'] as String;
    final totalWage = (baristaData['totalWage'] as num).toDouble();
    final paymentStatus = baristaData['paymentStatus'] as String;

    final statusColor = paymentStatus.toLowerCase() == 'approved'
        ? Colors.green
        : Colors.orange;
    final statusIcon = paymentStatus.toLowerCase() == 'approved'
        ? Icons.check_circle
        : Icons.schedule;

    return GestureDetector(
      onTap: () => _showPaymentDialog(baristaData),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.altSurface),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baristaName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    outletName,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rp ${formatRupiah(totalWage)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        color: statusColor,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        paymentStatus.toLowerCase() == 'approved'
                            ? 'Dibayar'
                            : 'Pending',
                        style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
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
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');
    final isToday = DateTime.now().day == _selectedDate.day &&
        DateTime.now().month == _selectedDate.month &&
        DateTime.now().year == _selectedDate.year;

    // Calculate summary
    int pendingCount = 0;
    double pendingAmount = 0.0;
    int approvedCount = 0;
    double approvedAmount = 0.0;

    for (final payment in _baristaPayments) {
      final totalWage = (payment['totalWage'] as num).toDouble();
      final status = payment['paymentStatus'] as String;

      if (status.toLowerCase() == 'approved') {
        approvedCount++;
        approvedAmount += totalWage;
      } else if (status.toLowerCase() == 'pending') {
        pendingCount++;
        pendingAmount += totalWage;
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Pembayaran Bonus Barista'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBaristaPayments,
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
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pembayaran Bonus',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Semua Barista',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
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
                                      isToday ? 'Hari Ini' : dateFormat.format(_selectedDate),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
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
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              border: Border.all(color: Colors.orange.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pending',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  pendingCount.toString(),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rp ${formatRupiah(pendingAmount)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              border: Border.all(color: Colors.green.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dibayar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  approvedCount.toString(),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rp ${formatRupiah(approvedAmount)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // List Title
                    const Text(
                      'Daftar Pembayaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Payment List
                    if (_baristaPayments.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 48,
                                color: AppColors.textSecondary.withOpacity(0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Belum ada data pembayaran',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _baristaPayments
                            .map((payment) => _buildPaymentCard(payment))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
