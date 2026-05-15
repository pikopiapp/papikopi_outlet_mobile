import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../theme/thema.dart';
import '../widgets/header.dart';
import '../models/outlet.dart';

class InvestorScreen extends StatefulWidget {
  const InvestorScreen({super.key});

  @override
  State<InvestorScreen> createState() => _InvestorScreenState();
}

class _InvestorScreenState extends State<InvestorScreen> {
  final _supabaseService = SupabaseService();
  int _selectedIndex = 0;

  late final Future<void> _supabaseInitFuture;

  // 0: Profile, 1: Revenue, 2: Report Outlet, 3: Notifikasi
  final List<Widget> _screens = const [
    _InvestorProfilePlaceholder(),
    _InvestorRevenuePlaceholder(),
    _InvestorReportOutletPlaceholder(),
    _InvestorNotificationPlaceholder(),
  ];

  @override
  void initState() {
    super.initState();
    // Extra guard: pastikan Supabase sudah siap sebelum screen mulai query
    _supabaseInitFuture = _supabaseService.initialize();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleLogout() async {
    await _supabaseService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _handleProfile() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  void _handleSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings investor masih placeholder')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PapikopiAppBar(
        onLogout: _handleLogout,
        onProfile: _handleProfile,
        onSettings: _handleSettings,
      ),
      body: FutureBuilder<void>(
        future: _supabaseInitFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: _InfoBox(
                title: 'Error Supabase',
                value: 'Gagal menginisialisasi koneksi database.',
              ),
            );
          }

          return _screens[_selectedIndex];
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Revenue',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Report Outlet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_active),
            label: 'Notifikasi',
          ),
        ],
      ),
    );
  }
}

class _InvestorProfilePlaceholder extends StatefulWidget {
  const _InvestorProfilePlaceholder();

  @override
  State<_InvestorProfilePlaceholder> createState() => _InvestorProfilePlaceholderState();
}

class _InvestorProfilePlaceholderState extends State<_InvestorProfilePlaceholder> {
  final _supabaseService = SupabaseService();

  Future<List<Map<String, dynamic>>> _resolveInvestorOutlets() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) {
      print('👤 _resolveInvestorOutlets user=null');
      return [];
    }

    print('👤 _resolveInvestorOutlets using user.id=${user.id}');
    // Fetch investor assignments with outlet details
    return _supabaseService.getInvestorAssignments(investorId: user.id);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Investor',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Nama: ${user?.name ?? "-"}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Email: ${user?.email ?? "-"}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            const Text(
              'Outlet yang diinvestasikan',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _resolveInvestorOutlets(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 56,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snap.hasError) {
                  return _InfoBox(
                    title: "Error",
                    value: "Gagal memuat outlet investor: ${snap.error}",
                  );
                }

                final rows = snap.data ?? [];
                if (rows.isEmpty) {
                  return _InfoBox(
                    title: "Outlet investor",
                    value: "Belum ada outlet yang diinvestasikan untuk user.id=${user?.id ?? '-'}",
                  );
                }

                final shown = rows.take(5).toList();
                final overflow = rows.length > shown.length;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.altSurface),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...shown.map((r) {
                        final outletName = (r['outlet_name'] as String?) ?? '-';
                        final outletId = (r['outlet_id'] as String?) ?? '-';
                        final outletType = (r['outlet_type'] as String?) ?? 'unknown';
                        final investmentAmount =
                            (r['investment_amount'] as num?)?.toDouble() ?? 0.0;
                        final marginPercentage =
                            (r['margin_percentage'] as num?)?.toDouble() ?? 0.0;
                        final status = (r['status'] as String?) ?? 'unknown';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• $outletName',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '  Type: $outletType | Status: $status',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '  Investment: Rp${investmentAmount.toStringAsFixed(0)} | Margin: ${marginPercentage.toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      if (overflow)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '+ ${rows.length - shown.length} more outlets',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueAccent),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Fitur profile investor (edit data, preferensi, dsb) akan ditambahkan di sini.',
            ),
          ],
        ),
      ),
    );
  }
}

class _InvestorRevenuePlaceholder extends StatefulWidget {
  const _InvestorRevenuePlaceholder();

  @override
  State<_InvestorRevenuePlaceholder> createState() => _InvestorRevenuePlaceholderState();
}

class _InvestorRevenuePlaceholderState extends State<_InvestorRevenuePlaceholder> {
  final _supabaseService = SupabaseService();
  String _period = 'daily';

  Future<String?> _resolveInvestorOutletId() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return null;

    final outlets = await _supabaseService.getActiveInvestorOutlets(investorId: user.id);
    // fallback jika investor_assignments kosong
    if (outlets.isEmpty) {
      return user.outletId.isNotEmpty ? user.outletId : null;
    }

    // Ambil outlet pertama dulu
    return outlets.first.id;
  }

  Future<Map<String, dynamic>> _fetchRevenue(String outletId) async {
    return _supabaseService.getRevenueData(
      outletId: outletId,
      selectedDate: DateTime.now(),
    );
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
              'Revenue Investor',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Pilih periode:'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _PillButton(
                  active: _period == 'daily',
                  label: 'Harian (Daily)',
                  onTap: () => setState(() => _period = 'daily'),
                ),
                _PillButton(
                  active: _period == 'weekly',
                  label: 'Mingguan (Weekly)',
                  onTap: () => setState(() => _period = 'weekly'),
                ),
                _PillButton(
                  active: _period == 'monthly',
                  label: 'Bulanan (Monthly)',
                  onTap: () => setState(() => _period = 'monthly'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FutureBuilder<String?>(
              future: _resolveInvestorOutletId(),
              builder: (context, outletSnap) {
                if (outletSnap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final outletId = outletSnap.data;
                if (outletId == null || outletId.isEmpty) {
                  return const _InfoBox(
                    title: 'Outlet investor',
                    value: 'Belum ada data outlet active untuk investor.',
                  );
                }

                return FutureBuilder<Map<String, dynamic>>(
                  future: _fetchRevenue(outletId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 140,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return _InfoBox(
                        title: 'Error',
                        value: 'Gagal memuat revenue: ${snapshot.error}',
                      );
                    }

                    final data = snapshot.data ?? {};
                    final periodData =
                        (data[_period] as Map<String, dynamic>?) ?? {};

                    final amount =
                        (periodData['amount'] as num?)?.toDouble() ?? 0.0;
                    final count =
                        (periodData['count'] as num?)?.toInt() ?? 0;
                    final cash = (periodData['cash'] as num?)?.toDouble() ?? 0.0;
                    final qris = (periodData['qris'] as num?)?.toDouble() ?? 0.0;

                    return _RevenueCard(
                      periodLabel: _period == 'daily'
                          ? 'Harian'
                          : _period == 'weekly'
                              ? 'Mingguan'
                              : 'Bulanan',
                      amount: amount,
                      count: count,
                      cash: cash,
                      qris: qris,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InvestorReportOutletPlaceholder extends StatefulWidget {
  const _InvestorReportOutletPlaceholder();

  @override
  State<_InvestorReportOutletPlaceholder> createState() =>
      _InvestorReportOutletPlaceholderState();
}

class _InvestorReportOutletPlaceholderState
    extends State<_InvestorReportOutletPlaceholder> {
  final _supabaseService = SupabaseService();

  late Future<List<Map<String, dynamic>>> _futureOutlets;

  @override
  void initState() {
    super.initState();
    _futureOutlets = _supabaseService.getOutlets();
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
              'Report Outlet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ringkasan performa per outlet (placeholder: daftar outlet).',
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureOutlets,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return _InfoBox(
                    title: 'Error',
                    value: 'Gagal memuat outlets: ${snapshot.error}',
                  );
                }

                final outlets = snapshot.data ?? [];
                if (outlets.isEmpty) {
                  return const Text('Tidak ada data outlet.');
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.altSurface),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...outlets.map((o) {
                        final id = o['id']?.toString() ?? '';
                        final name = o['name']?.toString() ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            '• $name ($id)',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InvestorNotificationPlaceholder extends StatefulWidget {
  const _InvestorNotificationPlaceholder();

  @override
  State<_InvestorNotificationPlaceholder> createState() =>
      _InvestorNotificationPlaceholderState();
}

class _InvestorNotificationPlaceholderState
    extends State<_InvestorNotificationPlaceholder> {
  final _supabaseService = SupabaseService();

  Future<String?> _resolveInvestorOutletId() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return null;

    final outlets = await _supabaseService.getActiveInvestorOutlets(
      investorId: user.id,
    );
    if (outlets.isEmpty) return null;

    return outlets.first.id;
  }

  Future<List<Map<String, dynamic>>> _fetchNotifications(String outletId) {
    return _supabaseService.getRecentTransactions(
      outletId: outletId,
      limit: 5,
    );
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
              'Notifikasi Transaksi',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Notifikasi transaksi terbaru dari database.',
            ),
            const SizedBox(height: 24),
            FutureBuilder<String?>(
              future: _resolveInvestorOutletId(),
              builder: (context, outletSnap) {
                final outletId = outletSnap.data;
                if (outletSnap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (outletId == null || outletId.isEmpty) {
                  return const _InfoBox(
                    title: 'Outlet investor',
                    value: 'Belum ada data outlet active untuk investor.',
                  );
                }

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchNotifications(outletId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                          height: 160,
                          child: Center(child: CircularProgressIndicator()));
                    }
                    if (snapshot.hasError) {
                      return _InfoBox(
                        title: 'Error',
                        value: 'Gagal memuat notifikasi: ${snapshot.error}',
                      );
                    }

                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const _InfoBox(
                        title: 'Kosong',
                        value: 'Belum ada transaksi terbaru.',
                      );
                    }

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.altSurface),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: items.map((t) {
                          final id = t['id']?.toString() ?? '';
                          final total =
                              (t['total_amount'] as num?)?.toDouble() ?? 0.0;
                          final payment = t['payment_method']?.toString() ?? '';
                          final createdAt = t['created_at']?.toString() ?? '';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• Transaksi #$id',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '  Total: Rp${total.toStringAsFixed(0)} | ${payment.toUpperCase()}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '  Waktu: $createdAt',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(0.14) : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primary.withOpacity(0.55) : AppColors.altSurface,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final String periodLabel;
  final double amount;
  final int count;
  final double cash;
  final double qris;

  const _RevenueCard({
    required this.periodLabel,
    required this.amount,
    required this.count,
    required this.cash,
    required this.qris,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.altSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$periodLabel Revenue',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total: Rp${amount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Jumlah transaksi: $count',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Cash: Rp${cash.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'QRIS: Rp${qris.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String value;

  const _InfoBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.altSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(value),
        ],
      ),
    );
  }
}
