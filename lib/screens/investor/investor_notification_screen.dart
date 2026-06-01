import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';

class InvestorNotificationScreen extends StatefulWidget {
  const InvestorNotificationScreen({super.key});

  @override
  State<InvestorNotificationScreen> createState() =>
      _InvestorNotificationScreenState();
}

class _InvestorNotificationScreenState
    extends State<InvestorNotificationScreen> {
  final _supabaseService = SupabaseService();
  String _selectedTab = 'transactions'; // transactions, announcements, chat

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

  void _showAnnouncementDetail(Map<String, dynamic> announcement) {
    final title = announcement['title']?.toString() ?? 'Pengumuman';
    final content = announcement['description']?.toString() ?? '';
    final createdAt = announcement['created_at']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 40,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                createdAt,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notifikasi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Tab buttons - inline row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _PillButton(
                      active: _selectedTab == 'transactions',
                      label: '💳 Transaksi',
                      onTap: () => setState(() => _selectedTab = 'transactions'),
                    ),
                    const SizedBox(width: 8),
                    _PillButton(
                      active: _selectedTab == 'announcements',
                      label: '📢 Pengumuman',
                      onTap: () => setState(() => _selectedTab = 'announcements'),
                    ),
                    const SizedBox(width: 8),
                    _PillButton(
                      active: _selectedTab == 'chat',
                      label: '💬 Chat',
                      onTap: () => setState(() => _selectedTab = 'chat'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Content based on selected tab
              if (_selectedTab == 'transactions') ...[
                _buildTransactionsContent(),
              ] else if (_selectedTab == 'announcements') ...[
                _buildAnnouncementsContent(),
              ] else if (_selectedTab == 'chat') ...[
                _buildChatContent(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsContent() {
    return FutureBuilder<String?>(
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
    );
  }

  Widget _buildAnnouncementsContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _supabaseService.getAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _InfoBox(
            title: 'Error',
            value: 'Gagal memuat pengumuman: ${snapshot.error}',
          );
        }

        final announcements = snapshot.data ?? [];
        if (announcements.isEmpty) {
          return const _InfoBox(
            title: 'Kosong',
            value: 'Tidak ada pengumuman saat ini.',
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
            children: announcements.asMap().entries.map((entry) {
              final index = entry.key;
              final announcement = entry.value;

              final title = announcement['title']?.toString() ?? 'Pengumuman';
              final content = announcement['description']?.toString() ?? '';
              final createdAt = announcement['created_at']?.toString() ?? '';

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < announcements.length - 1 ? 12 : 0,
                ),
                child: InkWell(
                  onTap: () {
                    _showAnnouncementDetail(announcement);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        content,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              createdAt,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              _showAnnouncementDetail(announcement);
                            },
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text('Detail'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 0,
                              ),
                              minimumSize: const Size(0, 0),
                            ),
                          ),
                        ],
                      ),
                      if (index < announcements.length - 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Divider(
                            height: 1,
                            color: AppColors.altSurface,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildChatContent() {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId == null) {
      return const _InfoBox(
        title: 'Error',
        value: 'User tidak ditemukan. Silakan login kembali.',
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _supabaseService.getPrivateMessagesWithSenderInfo(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _InfoBox(
            title: 'Error',
            value: 'Gagal memuat chat: ${snapshot.error}',
          );
        }

        final messages = snapshot.data ?? [];
        if (messages.isEmpty) {
          return const _InfoBox(
            title: 'Kosong',
            value: 'Belum ada chat pribadi.',
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
            children: messages.asMap().entries.map((entry) {
              final index = entry.key;
              final message = entry.value;

              final senderName = message['sender_name']?.toString() ?? 'Unknown';
              final content = message['message']?.toString() ?? '';
              final createdAt = message['created_at']?.toString() ?? '';

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < messages.length - 1 ? 12 : 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '👤 $senderName',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      createdAt,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    if (index < messages.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Divider(
                          height: 1,
                          color: AppColors.altSurface,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
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
