import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';
import '../../widgets/header.dart';
import 'manager_profile_screen.dart';
import 'manager_settings_screen.dart';

class ManagerShellScreen extends StatefulWidget {
  const ManagerShellScreen({super.key});

  @override
  State<ManagerShellScreen> createState() => _ManagerShellScreenState();
}

class _ManagerShellScreenState extends State<ManagerShellScreen> {
  final _supabaseService = SupabaseService();

  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    _ManagerDashboardPlaceholder(),
    ManagerProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleLogout() async {
    await _supabaseService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _handleProfile() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  void _handleSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ManagerSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 0
          ? PapikopiAppBar(
              onLogout: _handleLogout,
              onProfile: _handleProfile,
              onSettings: _handleSettings,
            )
          : null,
      body: _screens[_selectedIndex],
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
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ManagerDashboardPlaceholder extends StatelessWidget {
  const _ManagerDashboardPlaceholder();

  void _showNotImplemented(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text(
          'Fitur ini masih placeholder. Nanti akan dihubungkan ke halaman/logic manager yang sebenarnya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
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
              'Manager Dashboard',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pilih menu fitur manager berikut:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _FeatureTile(
                  icon: Icons.inventory_2_outlined,
                  label: 'Manage Stok',
                  onTap: () => _showNotImplemented(context, 'Manage Stok'),
                ),
                _FeatureTile(
                  icon: Icons.store_outlined,
                  label: 'Alokasi Outlet',
                  onTap: () => _showNotImplemented(context, 'Alokasi Outlet'),
                ),
                _FeatureTile(
                  icon: Icons.autorenew_outlined,
                  label: 'Returns',
                  onTap: () => _showNotImplemented(context, 'Returns'),
                ),
                _FeatureTile(
                  icon: Icons.location_on_outlined,
                  label: 'Manage Outlet',
                  onTap: () => _showNotImplemented(context, 'Manage Outlet'),
                ),
                _FeatureTile(
                  icon: Icons.payment_outlined,
                  label: 'Manage Pembayaran',
                  onTap: () => _showNotImplemented(context, 'Manage Pembayaran'),
                ),
                _FeatureTile(
                  icon: Icons.more_horiz,
                  label: 'Lainnya',
                  onTap: () => _showNotImplemented(context, 'Lainnya'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.altSurface),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
