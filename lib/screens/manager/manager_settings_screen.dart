import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';
import '../../widgets/header.dart';

class ManagerSettingsScreen extends StatelessWidget {
  const ManagerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService();

    return Scaffold(
      appBar: PapikopiAppBar(
        onLogout: () async {
          await supabaseService.signOut();
          if (!context.mounted) return;
          Navigator.of(context).pushReplacementNamed('/login');
        },
        onProfile: () {
          Navigator.of(context).pop();
        },
        onSettings: null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings Manager',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ini halaman Settings khusus untuk manager. Nanti bisa diisi: pengaturan outlet, pengaturan role, dsb.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
