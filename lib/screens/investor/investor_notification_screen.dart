import 'package:flutter/material.dart';

import '../../theme/thema.dart';
import '../../widgets/header.dart';

class InvestorNotificationScreen extends StatefulWidget {
  const InvestorNotificationScreen({super.key});

  @override
  State<InvestorNotificationScreen> createState() =>
      _InvestorNotificationScreenState();
}

class _InvestorNotificationScreenState extends State<InvestorNotificationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PapikopiAppBar(
        titleText: 'Notifikasi',
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification item cards
              _buildNotificationItem(
                icon: Icons.payments_rounded,
                title: 'Transaksi Baru',
                subtitle: 'Outlet Papi Kopi Sawangan telah melakukan transaksi sebesar Rp 150.000',
                time: '2 jam yang lalu',
                isRead: false,
              ),
              const SizedBox(height: 10),
              _buildNotificationItem(
                icon: Icons.trending_up_rounded,
                title: 'Profit Dibagikan',
                subtitle: 'Profit bulan Juni 2026 telah dibagikan ke akun Anda.',
                time: '1 hari yang lalu',
                isRead: false,
              ),
              const SizedBox(height: 10),
              _buildNotificationItem(
                icon: Icons.new_releases_rounded,
                title: 'Pembaruan Sistem',
                subtitle: 'Aplikasi telah diperbarui dengan fitur terbaru.',
                time: '3 hari yang lalu',
                isRead: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required bool isRead,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead ? AppColors.surface : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead
              ? AppColors.altSurface
              : AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isRead
                  ? AppColors.altSurface
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isRead ? AppColors.textSecondary : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}