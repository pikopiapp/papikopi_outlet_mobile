import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'pos_screen.dart';
import 'finance_screen.dart';
import 'stock_screen.dart';
import 'manager_screen.dart';
import '../theme/thema.dart';
import '../providers/auth_provider.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _selectedIndex = 0;
  late String _userRole;
  late List<Widget> _screens;
  late List<BottomNavigationBarItem> _navItems;

  @override
  void initState() {
    super.initState();
    _initializeScreens();
  }

  void _initializeScreens() {
    final authProvider = context.read<AuthProvider>();
    _userRole = authProvider.currentUser?.role ?? 'barista';
    
    if (_userRole == 'manager') {
      // Manager screens
      _screens = [
        const HomeScreen(),
        const ManagerScreen(),
        const StockScreen(),
        const FinanceScreen(),
      ];
      _navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: 'Manager',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2),
          label: 'Stok',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.wallet),
          label: 'Dompet',
        ),
      ];
    } else {
      // Barista/Regular user screens
      _screens = [
        const HomeScreen(),
        const POSScreen(),
        const StockScreen(),
        const FinanceScreen(),
      ];
      _navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart),
          label: 'Pemesanan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2),
          label: 'Stok',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.wallet),
          label: 'Dompet',
        ),
      ];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: _navItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
