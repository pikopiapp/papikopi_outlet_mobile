import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../theme/thema.dart';
import '../widgets/header.dart';

String formatRupiah(num? amount) {
  if (amount == null) return 'Rp 0';
  final formatter = NumberFormat('#,###', 'id_ID');
  return formatter.format(amount.toInt());
}

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _refreshAnimationController;
  List<Map<String, dynamic>> _pendingHandovers = [];
  List<Map<String, dynamic>> _historyHandovers = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _outletId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize refresh animation controller
    _refreshAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _initializeOutletId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeOutletId() async {
    final supabaseService = SupabaseService();
    final user = supabaseService.getCurrentUser();
    
    if (user != null) {
      setState(() => _outletId = user.outletId);
      _loadHandovers();
    }
  }

  Future<void> _loadHandovers() async {
    setState(() => _isLoading = true);
    final supabaseService = SupabaseService();

    if (_outletId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final pending = await supabaseService.getPendingCashDepositHandovers(
        outletId: _outletId!,
      );

      // Get approved/rejected handovers for history
      final allHandovers = await supabaseService.getCashDepositHandoverHistory(
        outletId: _outletId!,
        baristaId: '', // Get all from outlet
      );

      setState(() {
        _pendingHandovers = pending;
        _historyHandovers = allHandovers
            .where((h) => h['status'] != 'pending')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    
    // Prevent multiple simultaneous refreshes
    if (_isRefreshing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ Refresh sedang berjalan, tunggu sebentar...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    setState(() {
      _isRefreshing = true;
    });
    
    // Start animation loop
    _refreshAnimationController.repeat();
    
    try {
      await _loadHandovers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data berhasil diperbarui'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal memperbarui data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      // Stop animation
      _refreshAnimationController.stop();
      
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _approveHandover(String handoverId) async {
    final supabaseService = SupabaseService();
    final currentUser = supabaseService.getCurrentUser();

    if (currentUser == null) {
      _showErrorSnackBar('User tidak valid');
      return;
    }

    // Show confirmation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Approval'),
        content: const Text('Approve serah terima ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                final success = await supabaseService.approveCashDepositHandover(
                  handoverId: handoverId,
                  approverId: currentUser.id,
                );

                if (mounted) {
                  Navigator.pop(context);

                  if (success) {
                    _showSuccessSnackBar('✅ Serah terima diapprove');
                    _loadHandovers();
                  } else {
                    _showErrorSnackBar('Gagal approve');
                  }
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  _showErrorSnackBar('Error: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Future<void> _recordShortfallCompensation(String handoverId, double kekuranganUpah) async {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Catat Tanda Terima - Kekurangan Upah'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kekurangan Upah',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Rp ${formatRupiah(kekuranganUpah)}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manajemen Papi Kopi memberikan kompensasi kekurangan upah kepada karyawan',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Catatan (opsional)...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                final supabaseService = SupabaseService();
                final currentUser = supabaseService.getCurrentUser();
                
                if (currentUser == null) {
                  _showErrorSnackBar('User tidak ditemukan');
                  return;
                }

                final success = await supabaseService.approveCashDepositHandover(
                  handoverId: handoverId,
                  approverId: currentUser.id,
                );

                if (mounted) {
                  Navigator.pop(context);

                  if (success) {
                    _showSuccessSnackBar('✅ Kekurangan upah dicatat & disetujui');
                    _loadHandovers();
                  } else {
                    _showErrorSnackBar('Gagal mencatat tanda terima');
                  }
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  _showErrorSnackBar('Error: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Catat Tanda Terima'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectHandover(String handoverId) async {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Serah Terima'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Alasan penolakan...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isEmpty) {
                _showErrorSnackBar('Alasan harus diisi');
                return;
              }

              Navigator.pop(context);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                final supabaseService = SupabaseService();
                final success = await supabaseService.rejectCashDepositHandover(
                  handoverId: handoverId,
                  rejectionReason: reasonController.text,
                );

                if (mounted) {
                  Navigator.pop(context);

                  if (success) {
                    _showSuccessSnackBar('❌ Serah terima ditolak');
                    _loadHandovers();
                  } else {
                    _showErrorSnackBar('Gagal reject');
                  }
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  _showErrorSnackBar('Error: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PapikopiAppBar(onRefresh: _refreshData),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Menunggu (${_pendingHandovers.length})'),
              Tab(text: 'Riwayat (${_historyHandovers.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingHandovers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.done_all,
              size: 64,
              color: Colors.green.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Semua serah terima sudah diproses',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingHandovers.length,
      itemBuilder: (context, index) {
        final handover = _pendingHandovers[index];
        final baristaName =
            handover['users'] != null ? handover['users']['full_name'] : 'Unknown';
        final date = handover['date'] ?? '';
        final depositAmount = (handover['deposit_amount'] as num?)?.toDouble() ?? 0;
        final cashAmount = (handover['cash_amount'] as num?)?.toDouble() ?? 0;
        final bonus = (handover['bonus'] as num?)?.toDouble() ?? 0;
        final mealAllowance =
            (handover['meal_allowance'] as num?)?.toDouble() ?? 0;
        final kekuranganUpah = (handover['kekurangan_upah'] as num?)?.toDouble() ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.orange.shade300, width: 2),
            borderRadius: BorderRadius.circular(12),
            color: Colors.orange.shade50,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        baristaName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        date,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Menunggu',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Pembayaran CASH',
                      'Rp ${formatRupiah(cashAmount)}',
                      Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Bonus',
                      '-Rp ${formatRupiah(bonus)}',
                      Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Uang Makan',
                      '-Rp ${formatRupiah(mealAllowance)}',
                      Colors.amber,
                    ),
                    if (kekuranganUpah > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _buildDetailRow(
                          '⚠️ Kekurangan Upah',
                          'Rp ${formatRupiah(kekuranganUpah)}',
                          Colors.orange,
                          isBold: true,
                        ),
                      ),
                    ],
                    const Divider(),
                    _buildDetailRow(
                      'Total Disetor',
                      'Rp ${formatRupiah(depositAmount)}',
                      Colors.green,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (kekuranganUpah > 0)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.orange.shade50,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚠️ Kekurangan yang Harus Diterima',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rp ${formatRupiah(kekuranganUpah)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Manajemen Papi Kopi memberikan kompensasi kekurangan upah kepada karyawan',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (kekuranganUpah > 0)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _recordShortfallCompensation(
                          handover['id'],
                          kekuranganUpah,
                        ),
                        icon: const Icon(Icons.receipt),
                        label: const Text('Catat Tanda Terima'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _rejectHandover(handover['id']),
                      icon: const Icon(Icons.close),
                      label: const Text('Tolak'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveHandover(handover['id']),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyHandovers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.blue.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada riwayat approval',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHandovers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historyHandovers.length,
        itemBuilder: (context, index) {
          final handover = _historyHandovers[index];
          final baristaName =
              handover['users'] != null ? handover['users']['full_name'] : 'Unknown';
          final date = handover['date'] ?? '';
          final status = handover['status'] ?? 'unknown';
          final depositAmount = (handover['deposit_amount'] as num?)?.toDouble() ?? 0;
          final approvedAt = handover['approved_at'];
          final rejectionReason = handover['rejection_reason'];

          Color statusColor = Colors.grey;
          String statusText = status.toUpperCase();

          if (status == 'approved') {
            statusColor = Colors.green;
            statusText = '✅ DIAPPROVE';
          } else if (status == 'rejected') {
            statusColor = Colors.red;
            statusText = '❌ DITOLAK';
          } else if (status == 'completed') {
            statusColor = Colors.blue;
            statusText = '🎯 SELESAI';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
              borderRadius: BorderRadius.circular(12),
              color: statusColor.withOpacity(0.05),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          baristaName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          date,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        'Total Disetor',
                        'Rp ${formatRupiah(depositAmount)}',
                        Colors.green,
                        isBold: true,
                      ),
                      if (approvedAt != null) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Approval Date',
                          _formatDate(approvedAt),
                          Colors.blue,
                        ),
                      ],
                      if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Alasan Penolakan:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rejectionReason,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildDetailRow(
    String label,
    String amount,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? Colors.black : Colors.grey.shade700,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
