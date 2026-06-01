import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';

class InvestorWithdrawalScreen extends StatefulWidget {
  const InvestorWithdrawalScreen({super.key});

  @override
  State<InvestorWithdrawalScreen> createState() =>
      _InvestorWithdrawalScreenState();
}

class _InvestorWithdrawalScreenState extends State<InvestorWithdrawalScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _supabaseService = SupabaseService();
  String _selectedMethod = 'bank'; // 'bank' or 'ewallet'
  String _selectedBank = 'bca';
  final _amountController = TextEditingController();
  final _accountNameController = TextEditingController();

  final List<Map<String, String>> _banks = [
    {'code': 'bca', 'name': 'BCA', 'icon': '🏦'},
    {'code': 'mandiri', 'name': 'Mandiri', 'icon': '🏦'},
    {'code': 'bni', 'name': 'BNI', 'icon': '🏦'},
    {'code': 'cimb', 'name': 'CIMB Niaga', 'icon': '🏦'},
  ];

  final List<Map<String, String>> _ewallets = [
    {'code': 'gopay', 'name': 'GoPay', 'icon': '📱'},
    {'code': 'ovo', 'name': 'OVO', 'icon': '📱'},
    {'code': 'dana', 'name': 'DANA', 'icon': '📱'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match.group(1)}.',
        );
  }

  Future<Map<String, dynamic>> _getWithdrawalSummary() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return {};

    try {
      // Get investor's available balance and pending withdrawals
      final result = await _supabaseService.getWithdrawalSummary(
        investorId: user.id,
      );
      return result;
    } catch (e) {
      return {
        'available': 0.0,
        'pending': 0.0,
        'thisMonth': 0.0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> _getWithdrawalHistory() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return [];

    try {
      final history = await _supabaseService.getWithdrawalHistory(
        investorId: user.id,
      );
      return history;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _getPendingWithdrawal() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return null;

    try {
      final pending = await _supabaseService.getPendingWithdrawal(
        investorId: user.id,
      );
      return pending;
    } catch (e) {
      return null;
    }
  }

  Future<void> _submitWithdrawalRequest() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    final amount = double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0.0;
    
    if (amount < 100000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal penarikan Rp 100.000')),
      );
      return;
    }

    if (_accountNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama penerima harus diisi')),
      );
      return;
    }

    try {
      await _supabaseService.submitWithdrawalRequest(
        investorId: user.id,
        amount: amount,
        method: _selectedMethod,
        methodType: _selectedBank,
        accountIdentifier: _selectedMethod == 'bank'
            ? _amountController.text // placeholder - should be account number
            : _amountController.text, // placeholder - should be phone
        accountName: _accountNameController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request penarikan berhasil! Menunggu verifikasi admin.'),
          backgroundColor: Colors.green,
        ),
      );

      _amountController.clear();
      _accountNameController.clear();
      setState(() => _selectedMethod = 'bank');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Penarikan Dana',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Balance Display Card
            FutureBuilder<double>(
              future: () async {
                final authProvider = context.read<AuthProvider>();
                final user = authProvider.currentUser;
                if (user == null) return 0.0;
                return _supabaseService.getInvestorBalance(investorId: user.id);
              }(),
              builder: (context, snapshot) {
                final balance = snapshot.data ?? 0.0;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saldo Tersedia',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rp ${_formatCurrency(balance)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (balance < 100000) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Saldo kurang (min: Rp 100.000)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            // Summary Cards
            FutureBuilder<Map<String, dynamic>>(
              future: _getWithdrawalSummary(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 100);
                }

                final data = snapshot.data ?? {};
                final available = _formatCurrency(data['available'] ?? 0.0);
                final pending = _formatCurrency(data['pending'] ?? 0.0);
                final thisMonth = _formatCurrency(data['thisMonth'] ?? 0.0);

                return Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Saldo Tarik',
                        value: 'Rp $available',
                        bgColor: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Pending',
                        value: 'Rp $pending',
                        bgColor: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Bulan Ini',
                        value: 'Rp $thisMonth',
                        bgColor: Colors.green,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // Tab Bar
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.altSurface),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'Buat Request'),
                  Tab(text: 'Status'),
                  Tab(text: 'History'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Request
                  _buildRequestTab(),
                  // Tab 2: Status
                  _buildStatusTab(),
                  // Tab 3: History
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amount Input
          const Text(
            'Nominal Penarikan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Rp 100.000',
              prefixText: 'Rp ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Min: Rp 100.000 | Fee: Rp 5.000',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          // Method Selection
          const Text(
            'Metode Penarikan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MethodButton(
                  label: 'Bank Transfer',
                  icon: '🏦',
                  selected: _selectedMethod == 'bank',
                  onTap: () => setState(() => _selectedMethod = 'bank'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MethodButton(
                  label: 'E-Wallet',
                  icon: '📱',
                  selected: _selectedMethod == 'ewallet',
                  onTap: () => setState(() => _selectedMethod = 'ewallet'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bank/E-wallet Selection
          if (_selectedMethod == 'bank') ...[
            const Text(
              'Pilih Bank',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _banks.map((bank) {
                final selected = _selectedBank == bank['code'];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedBank = bank['code'] ?? ''),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected ? AppColors.primary : Colors.grey[300]!,
                        width: selected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: selected
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(bank['icon'] ?? '', style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          bank['name'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected ? AppColors.primary : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nomor Rekening',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: '123456789012',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ] else ...[
            const Text(
              'Pilih E-Wallet',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ewallets.map((wallet) {
                final selected = _selectedBank == wallet['code'];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedBank = wallet['code'] ?? ''),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected ? AppColors.primary : Colors.grey[300]!,
                        width: selected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: selected
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(wallet['icon'] ?? '', style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          wallet['name'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected ? AppColors.primary : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nomor Ponsel',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: '08123456789',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Atas Nama
          const Text(
            'Atas Nama',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _accountNameController,
            decoration: InputDecoration(
              hintText: 'Nama sesuai rekening/akun',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitWithdrawalRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Ajukan Penarikan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab() {
    return SingleChildScrollView(
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _getPendingWithdrawal(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inbox, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Tidak ada penarikan yang sedang diproses',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final amount = _formatCurrency(data['amount'] as double? ?? 0.0);
          final status = data['status'] as String? ?? 'pending';
          final method = _getMethodDisplay(data['method'] as String?, data['method_type'] as String?);
          final account = data['account_identifier'] as String? ?? 'N/A';
          final accountName = data['account_name'] as String? ?? 'N/A';
          final fee = _formatCurrency(data['fee'] as double? ?? 5000.0);
          final net = _formatCurrency(
            (data['amount'] as double? ?? 0.0) - (data['fee'] as double? ?? 5000.0),
          );

          // Calculate timeline based on status
          final timeline = [
            {'step': 'Requested', 'completed': true, 'time': _formatDate(data['created_at'] as String?)},
            {'step': 'Verified by Admin', 'completed': status != 'pending', 'time': status != 'pending' ? _formatDate(data['updated_at'] as String?) : 'Menunggu verifikasi'},
            {'step': 'Processing', 'completed': status == 'processing' || status == 'completed', 'time': status == 'processing' || status == 'completed' ? 'Sedang diproses' : 'Menunggu'},
            {'step': 'Completed', 'completed': status == 'completed', 'time': status == 'completed' ? _formatDate(data['updated_at'] as String?) : 'Est. 1-2 hari kerja'},
          ];

          final statusColor = status == 'pending'
              ? Colors.orange
              : status == 'verified'
              ? Colors.blue
              : status == 'processing'
              ? Colors.orange
              : Colors.green;

          return Column(
            children: [
              // Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.altSurface),
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [statusColor.withOpacity(0.05), statusColor.withOpacity(0.1)],
                  ),
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
                            const Text(
                              'Request Penarikan',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rp $amount',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getStatusDisplay(status),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Timeline
                    _buildTimeline(timeline),
                    const SizedBox(height: 16),
                    // Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow('Metode:', method),
                          const SizedBox(height: 8),
                          _infoRow('Rekening/Nomor:', account),
                          const SizedBox(height: 8),
                          _infoRow('Atas Nama:', accountName),
                          const SizedBox(height: 8),
                          _infoRow('Fee:', 'Rp $fee'),
                          const SizedBox(height: 8),
                          _infoRow('Net:', 'Rp $net'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeline(List<Map<String, dynamic>> steps) {
    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isCompleted = step['completed'] as bool;
        final isLast = index == steps.length - 1;

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.green : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: isCompleted
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : const SizedBox(),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        color: isCompleted ? Colors.green : Colors.grey[300],
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step['step'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCompleted ? Colors.green : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step['time'] as String,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getWithdrawalHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum ada riwayat penarikan',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final withdrawals = snapshot.data ?? [];
          return Column(
            children: withdrawals
                .map((withdrawal) {
                  final status = withdrawal['status'] as String? ?? 'pending';
                  final statusColor = status == 'completed' ? Colors.green : Colors.red;
                  final amount = _formatCurrency(withdrawal['amount'] as double? ?? 0.0);
                  final method = _getMethodDisplay(
                    withdrawal['method'] as String?,
                    withdrawal['method_type'] as String?,
                  );
                  final icon = status == 'completed' ? '✓' : '✗';
                  final date = _formatDate(withdrawal['created_at'] as String?);

                  return _historyItem(
                    date: date,
                    amount: 'Rp $amount',
                    status: _getStatusDisplay(status),
                    statusColor: statusColor,
                    method: method,
                    icon: icon,
                  );
                })
                .toList(),
          );
        },
      ),
    );
  }

  Widget _historyItem({
    required String date,
    required String amount,
    required String status,
    required Color statusColor,
    required String method,
    required String icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.altSurface),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  method,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                icon,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day} ${_getMonthName(date.month)} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _getMethodDisplay(String? method, String? methodType) {
    if (method == 'bank_transfer') {
      const bankNames = {
        'bca': 'BCA Transfer',
        'mandiri': 'Mandiri Transfer',
        'bni': 'BNI Transfer',
        'cimb': 'CIMB Transfer',
      };
      return bankNames[methodType] ?? 'Bank Transfer';
    } else if (method == 'e_wallet') {
      const walletNames = {
        'gopay': 'GoPay',
        'ovo': 'OVO',
        'dana': 'DANA',
      };
      return walletNames[methodType] ?? 'E-Wallet';
    }
    return 'Unknown';
  }

  String _getStatusDisplay(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'verified':
        return 'Verified';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color bgColor;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            colors: [bgColor.withOpacity(0.1), bgColor.withOpacity(0.2)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: bgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodButton extends StatelessWidget {
  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  const _MethodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected ? AppColors.primary.withOpacity(0.1) : Colors.white,
        ),
        child: Center(
          child: Column(
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? AppColors.primary : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
