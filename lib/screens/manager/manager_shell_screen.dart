import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';
import '../../widgets/header.dart';
import 'manager_profile_screen.dart';
import 'manager_settings_screen.dart';
import 'manager_dashboard_screen.dart';

class ManagerShellScreen extends StatefulWidget {
  const ManagerShellScreen({super.key});

  @override
  State<ManagerShellScreen> createState() => _ManagerShellScreenState();
}

class _ManagerShellScreenState extends State<ManagerShellScreen> {
  final _supabaseService = SupabaseService();

  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    ManagerDashboardScreen(),
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
