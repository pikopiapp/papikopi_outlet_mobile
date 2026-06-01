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
  
  // Track expanded sections for each barista
  final Map<String, bool> _expandedSections = {}; // baristaId -> isExpanded
  
  // Track bonus tier info expansion
  bool _isBonusTierInfoExpanded = false;

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

  /// Calculate bonus and meal allowance using same logic as sales_outlet_manager
  Map<String, dynamic> _calculateBonusAndMeal(double cashAmount, double qrisAmount, int freeCount) {
    double omset = cashAmount + qrisAmount; // Total omset (excluding free)
    double mealAllowance = omset >= 300000 ? 34000 : 25000;
    double bonusAmount = 0.0;
    
    // Check if selected date is a holiday or weekend
    final bool isHolidayDate = isHoliday(_selectedDate);
    
    if (isHolidayDate) {
      // Holiday calculation: 20% for all tiers
      bonusAmount = omset * 0.20;
    } else {
      // Regular tiered calculation
      if (omset <= 200000) {
        bonusAmount = omset * 0.10;
      } else if (omset <= 350000) {
        bonusAmount = (200000 * 0.10) + ((omset - 200000) * 0.12);
      } else if (omset <= 500000) {
        bonusAmount = (200000 * 0.10) + (150000 * 0.12) + ((omset - 350000) * 0.15);
      } else {
        bonusAmount = (200000 * 0.10) + (150000 * 0.12) + (150000 * 0.15) + ((omset - 500000) * 0.20);
      }
    }

    // Calculate final settlement using finance_screen formula:
    // Setoran = CASH - Bonus - Uang Makan
    double depositAmount = cashAmount - bonusAmount - mealAllowance;
    
    // Determine settlement type and amount
    String settlementType = 'deposit'; // 'deposit' (positive), 'shortfall' (negative)
    double settlementAmount = depositAmount;
    
    if (depositAmount < 0) {
      settlementType = 'shortfall';
      settlementAmount = depositAmount.abs(); // Make positive for display
    }

    return {
      'omset': omset,
      'cashAmount': cashAmount,
      'qrisAmount': qrisAmount,
      'freeCount': freeCount,
      'bonus': bonusAmount,
      'mealAllowance': mealAllowance,
      'depositAmount': depositAmount,
      'settlementType': settlementType, // 'deposit' or 'shortfall'
      'settlementAmount': settlementAmount,
      'isHolidayDate': isHolidayDate,
    };
  }

  Widget _buildBonusTierInfo() {
    final bool isHolidayDate = isHoliday(_selectedDate);
    final String holidayDescription = isHolidayDate ? getHolidayDescription(_selectedDate) : '';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHolidayDate ? Colors.purple.withValues(alpha: 0.05) : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHolidayDate ? Colors.purple : AppColors.altSurface,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle Header
          GestureDetector(
            onTap: () => setState(() => _isBonusTierInfoExpanded = !_isBonusTierInfoExpanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isHolidayDate ? 'Sistem Bonus (Hari Libur)' : 'Sistem Bonus Bertingkat',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isHolidayDate ? Colors.purple : AppColors.primary,
                        ),
                  ),
                ),
                Icon(
                  _isBonusTierInfoExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
          ),
          
          // Expandable Content
          if (_isBonusTierInfoExpanded) ...[
            const SizedBox(height: 12),
            if (isHolidayDate) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bonus $holidayDescription: Semua Tier 20%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (isHolidayDate)
              _buildBonusLine('Semua omset', '20%', Colors.purple)
            else ...[
              _buildBonusLine('Rp 0 - 200.000', '10%', Colors.black87),
              const SizedBox(height: 4),
              _buildBonusLine('Rp 200.000 - 350.000', '12%', Colors.black87),
              const SizedBox(height: 4),
              _buildBonusLine('Rp 350.000 - 500.000', '15%', Colors.black87),
              const SizedBox(height: 4),
              _buildBonusLine('> Rp 500.000', '20%', Colors.black87),
            ],
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Uang Makan:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
            ),
            const SizedBox(height: 4),
            _buildBonusLine('< Rp 300.000', 'Rp 25.000', Colors.black87),
            const SizedBox(height: 4),
            _buildBonusLine('≥ Rp 300.000', 'Rp 34.000', Colors.black87),
          ],
        ],
      ),
    );
  }

  // Helper methods for status display to match finance_screen.dart logic
  Color _getStatusColor(String? dbStatus) {
    switch (dbStatus?.toLowerCase()) {
      case 'verified by barista':
        return Colors.blue; // Sudah diverifikasi barista
      case 'approved':
        return Colors.green; // Sudah disetujui manager
      case 'completed':
        return Colors.green; // Selesai
      case 'rejected':
        return Colors.red; // Ditolak
      case 'pending':
      default:
        return Colors.grey; // Pending
    }
  }

  IconData _getStatusIcon(String? dbStatus) {
    switch (dbStatus?.toLowerCase()) {
      case 'verified by barista':
        return Icons.verified; // Verified icon
      case 'approved':
        return Icons.check_circle; // Check circle
      case 'completed':
        return Icons.done_all; // Done all
      case 'rejected':
        return Icons.cancel; // Cancel/X icon
      case 'pending':
      default:
        return Icons.schedule; // Clock/schedule icon
    }
  }

  String _getStatusText(String? dbStatus) {
    switch (dbStatus?.toLowerCase()) {
      case 'verified by barista':
        return 'SUDAH DIVERIFIKASI BARISTA';
      case 'approved':
        return 'SUDAH DISETUJUI MANAGER';
      case 'completed':
        return 'SELESAI';
      case 'rejected':
        return 'DITOLAK';
      case 'pending':
      default:
        return 'PENDING';
    }
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
                        const SizedBox(width: 12),
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

                    // Bonus Tier Info
                    _buildBonusTierInfo(),
                    const SizedBox(height: 24),

                    // List Title
                    const Text(
                      'Daftar Pembayaran Barista',
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
                        children: _baristaPayments.map((baristaData) {
                          final baristaName = baristaData['name'] as String;
                          final cashAmount = (baristaData['cashAmount'] as num?)?.toDouble() ?? 0.0;
                          final qrisAmount = (baristaData['qrisAmount'] as num?)?.toDouble() ?? 0.0;
                          final freeCount = (baristaData['freeCount'] as int?) ?? 0;
                          final handoverStatus = baristaData['handoverStatus'] as String? ?? 'pending';
                          final shortfallReceiptRecorded = (baristaData['shortfallReceiptRecorded'] as bool?) ?? false;
                          final statusType = baristaData['statusType'] as String? ?? 'none'; // From database: 'shortfall', 'deposit', or 'none'
                          final kekuranganUpah = (baristaData['kekuranganUpah'] as num?)?.toDouble() ?? 0.0;
                          
                          print('DEBUG barista_payment_screen - $baristaName: statusType=$statusType, handoverStatus=$handoverStatus, shortfallReceiptRecorded=$shortfallReceiptRecorded, kekuranganUpah=$kekuranganUpah');
                          
                          print('DEBUG barista_payment_screen - ${baristaData['name']} | shortfallReceiptRecorded=$shortfallReceiptRecorded, statusType=$statusType');
                          
                          // Calculate bonus and settlement using same logic as sales_outlet_manager
                          final Map<String, dynamic> bonusCalc = _calculateBonusAndMeal(cashAmount, qrisAmount, freeCount);
                          final double omset = bonusCalc['omset'] as double;
                          final double bonus = bonusCalc['bonus'] as double;
                          final double mealAllowance = bonusCalc['mealAllowance'] as double;
                          final String calculatedSettlementType = bonusCalc['settlementType'] as String; // Calculated from sales data
                          final double settlementAmount = bonusCalc['settlementAmount'] as double;
                          final bool isHolidayDate = bonusCalc['isHolidayDate'] as bool;
                          
                          // Use statusType from database if available, otherwise use calculated
                          final String settlementType = statusType != 'none' ? statusType : calculatedSettlementType;
                          
                          print('DEBUG barista_payment_screen - settlementType: DB=$statusType, calculated=$calculatedSettlementType, final=$settlementType');
                          if (settlementType == 'shortfall') {
                            print('DEBUG barista_payment_screen - SHORTFALL: kekuranganUpah=$kekuranganUpah, handoverStatus=$handoverStatus');
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.altSurface),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Barista Info
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColors.primary,
                                      child: Text(
                                        baristaName.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            baristaName,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Text(
                                            baristaData['outlet'] as String? ?? 'Outlet',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: AppColors.textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  ],
                                ),
                                // Status badges - di bawah barista info
                                const SizedBox(height: 12),
                                // Status badge untuk setoran normal (deposit > 0) - adopt dari finance_screen
                                if (settlementType == 'deposit')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(handoverStatus).withOpacity(0.15),
                                      border: Border.all(color: _getStatusColor(handoverStatus), width: 1.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getStatusIcon(handoverStatus),
                                          size: 14,
                                          color: _getStatusColor(handoverStatus),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _getStatusText(handoverStatus),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _getStatusColor(handoverStatus),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Status badges untuk kekurangan upah (shortfall > 0) - adopt dari finance_screen
                                if (settlementType == 'shortfall')
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Badge 1: Status approval dari database
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(handoverStatus).withOpacity(0.15),
                                          border: Border.all(color: _getStatusColor(handoverStatus), width: 1.5),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getStatusIcon(handoverStatus),
                                              size: 14,
                                              color: _getStatusColor(handoverStatus),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _getStatusText(handoverStatus),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: _getStatusColor(handoverStatus),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Badge 2: Receipt recorded indicator (adopt dari finance_screen)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: shortfallReceiptRecorded ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                                          border: Border.all(
                                            color: shortfallReceiptRecorded ? Colors.green : Colors.orange,
                                            width: 1.5,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              shortfallReceiptRecorded ? Icons.check_circle : Icons.pending_actions,
                                              size: 14,
                                              color: shortfallReceiptRecorded ? Colors.green : Colors.orange,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              shortfallReceiptRecorded ? 'SUDAH DICATAT' : 'MENUNGGU DICATAT',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: shortfallReceiptRecorded ? Colors.green : Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                
                                // Toggle Button for Details
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _expandedSections[baristaData['baristaId'] as String] = 
                                          !(_expandedSections[baristaData['baristaId'] as String] ?? false);
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Detail Perhitungan',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                      ),
                                      Icon(
                                        (_expandedSections[baristaData['baristaId'] as String] ?? false)
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Expandable Sections
                                if (_expandedSections[baristaData['baristaId'] as String] ?? false) ...[
                                  const SizedBox(height: 12),
                                  
                                  // Omset Breakdown
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Omset:',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        _buildBonusLine(
                                          'Penjualan',
                                          'Rp ${NumberFormat('#,##0', 'id_ID').format(omset.toInt())}',
                                          Colors.black,
                                        ),
                                        const SizedBox(height: 4),
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
                                        if (freeCount > 0) ...[
                                          const SizedBox(height: 4),
                                          _buildBonusLine(
                                            '  └─ Gratis',
                                            '${freeCount}x',
                                            Colors.black87,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Holiday Bonus Indicator
                                  if (isHolidayDate)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withOpacity(0.1),
                                        border: Border.all(color: Colors.purple, width: 1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text('🎉', style: TextStyle(fontSize: 14)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Bonus Hari Libur: 20%',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.purple,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (isHolidayDate) const SizedBox(height: 12),
                                  
                                  // Settlement Calculation
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: settlementType == 'deposit'
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
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
                                          '-Rp ${NumberFormat('#,##0', 'id_ID').format(bonus.toInt())}',
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
                                              top: BorderSide(color: Colors.grey.shade300),
                                            ),
                                          ),
                                          child: _buildBonusLine(
                                            settlementType == 'deposit' ? 'Setoran' : 'Kekurangan Upah',
                                            settlementType == 'deposit'
                                                ? 'Rp ${NumberFormat('#,##0', 'id_ID').format(settlementAmount.toInt())}'
                                                : '-Rp ${NumberFormat('#,##0', 'id_ID').format(settlementAmount.toInt())}',
                                            settlementType == 'deposit' ? Colors.green : Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Shortfall Receipt Status Indicator
                                  if (settlementType == 'shortfall')
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: shortfallReceiptRecorded ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: shortfallReceiptRecorded ? Colors.green : Colors.orange,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            shortfallReceiptRecorded ? Icons.check_circle : Icons.schedule,
                                            color: shortfallReceiptRecorded ? Colors.green : Colors.orange,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              shortfallReceiptRecorded
                                                  ? '✓ Tanda terima kekurangan sudah dicatat oleh barista'
                                                  : '⏳ Menunggu barista mencatat tanda terima kekurangan',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: shortfallReceiptRecorded ? Colors.green.shade700 : Colors.orange.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 1),
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
                                ],
                                
                                // Action Button - hanya tampil untuk deposit cases (bukan shortfall)
                                if (settlementType == 'deposit')
                                  ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: handoverStatus.toLowerCase() == 'pending' ? null : () => _processPayment(baristaData),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: handoverStatus.toLowerCase() == 'pending' ? Colors.grey : Colors.green,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        icon: const Icon(Icons.check_circle, size: 18),
                                        label: const Text('Approve', style: TextStyle(fontSize: 13)),
                                      ),
                                    ),
                                  ],
                                
                                // Action Button - untuk shortfall cases
                                if (settlementType == 'shortfall')
                                  ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: (handoverStatus.toLowerCase() == 'pending' || !shortfallReceiptRecorded) ? null : () => _processPayment(baristaData),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: (handoverStatus.toLowerCase() == 'pending' || !shortfallReceiptRecorded) ? Colors.grey : Colors.purple,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        icon: const Icon(Icons.check_circle, size: 18),
                                        label: const Text('Bayar', style: TextStyle(fontSize: 13)),
                                      ),
                                    ),
                                  ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
