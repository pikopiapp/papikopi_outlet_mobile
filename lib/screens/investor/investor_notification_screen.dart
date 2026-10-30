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
  // This screen used to render three hardcoded items, including "Profit bulan Juni
  // 2026 telah dibagikan" and an Rp 150.000 transaction. Nothing in the database
  // backed them, so investors were shown fabricated financial events. Until real
  // notifications exist, say so instead of inventing them.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PapikopiAppBar(titleText: 'Notifikasi'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                'Belum ada notifikasi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pemberitahuan pembagian profit akan muncul di sini.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
