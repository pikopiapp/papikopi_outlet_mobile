import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';
import '../../widgets/header.dart';
import 'manager_settings_screen.dart';
import 'manager_dashboard_screen.dart';
import 'showcase_allocation_screen.dart';
import 'manager_product_returns_screen.dart';
import 'sales_outlet_manager_screen.dart';

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
    ShowcaseAllocationScreen(),
    ManagerProductReturnsScreen(),
    SalesOutletManagerScreen(),
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

  void _handleSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ManagerSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PapikopiAppBar(
        onLogout: _handleLogout,
        onSettings: _handleSettings,
      ),
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
            icon: Icon(Icons.inventory_2),
            label: 'Alokasi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_return),
            label: 'Kembalian',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Penjualan',
          ),
        ],
      ),
    );
  }
}
