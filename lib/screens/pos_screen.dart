import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../utils/product_image_helper.dart';
import '../utils/number_formatter.dart';
import '../widgets/cart_summary.dart';
import '../widgets/checkout_modal.dart';
import '../widgets/header.dart';
import '../theme/thema.dart';
import 'profile_screen.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen>
    with TickerProviderStateMixin {
  String? _selectedCategoryId;
  late TabController _tabController;
  late AnimationController _refreshAnimationController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    
    // Initialize refresh animation controller
    _refreshAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final product = context.read<ProductProvider>();
      final auth = context.read<AuthProvider>();

      product.loadCategories();

      if (auth.currentUser != null) {
        product.loadOutlet(auth.currentUser!.outletId);
        product.loadProductsWithStock(auth.currentUser!.outletId);
      } else {
        product.loadProducts();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshAnimationController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    print('🔄 Refreshing POS screen data...');
    
    // Prevent multiple simultaneous refreshes
    if (_isRefreshing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ Refresh sedang berjalan, tunggu sebentar...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    setState(() {
      _isRefreshing = true;
    });
    
    // Start animation loop
    _refreshAnimationController.repeat();
    
    try {
      final product = context.read<ProductProvider>();
      final auth = context.read<AuthProvider>();

      // Reload data
      product.loadCategories();

      if (auth.currentUser != null) {
        product.loadOutlet(auth.currentUser!.outletId);
        product.loadProductsWithStock(auth.currentUser!.outletId);
      } else {
        product.loadProducts();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data berhasil diperbarui'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error refreshing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal memperbarui data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      // Stop animation
      _refreshAnimationController.stop();
      
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PapikopiAppBar(
        onLogout: _handleLogout,
        onProfile: _handleProfile,
        onSettings: _handleSettings,
        onRefresh: _refreshData,
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: AppColors.background,
            child: Consumer<CartProvider>(
              builder: (context, cart, _) {
                return TabBar(
                  controller: _tabController,
                  tabs: [
                    const Tab(
                      icon: Icon(Icons.shopping_cart_outlined),
                      text: 'Pemesanan',
                    ),
                    Tab(
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.list_alt_outlined),
                          if (cart.totalQuantity > 0)
                            Positioned(
                              right: -8,
                              top: -8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  '${cart.totalQuantity}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      text: 'Keranjang',
                    ),
                    const Tab(
                      icon: Icon(Icons.payment),
                      text: 'Checkout',
                    ),
                  ],
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                );
              },
            ),
          ),
          // Content
          Expanded(
child: TabBarView(
              controller: _tabController,
              children: [
                _buildPOSTab(),
                _buildCartTab(),
                CheckoutModal(tabController: _tabController),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== POS TAB ====================
  Widget _buildPOSTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;

        return isTablet ? _buildTabletPOS() : _buildMobilePOS();
      },
    );
  }

  Widget _buildMobilePOS() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildProductList()),
      ],
    );
  }

  Widget _buildTabletPOS() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildHeader(isTablet: true),
              Expanded(child: _buildProductList()),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.altSurface),
              ),
            ),
            child: _buildCartSummaryPreview(),
          ),
        ),
      ],
    );
  }

  // ==================== CART TAB ====================
  Widget _buildCartTab() {
    return const CartSummary();
  }

  Widget _buildCartSummaryPreview() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 48,
                  color: AppColors.altSurface,
                ),
                const SizedBox(height: 12),
                Text(
                  'Keranjang kosong',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                border: Border(
                  bottom: BorderSide(color: AppColors.altSurface),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ringkasan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${cart.totalQuantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: cart.items.length,
                itemBuilder: (context, index) {
                  final item = cart.items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${item.quantity}x ${NumberFormatter.formatRupiah(item.product.price)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          NumberFormatter.formatRupiah(item.subtotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  top: BorderSide(color: AppColors.altSurface),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(
                        NumberFormatter.formatRupiah(cart.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () => _tabController.animateTo(1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        'Lihat Keranjang',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

// ==================== APPBAR ====================
  // ==================== HEADER ====================
  Widget _buildHeader({bool isTablet = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pilih Produk',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildCategoryChips(isTablet),
        ],
      ),
    );
  }

  // ==================== CATEGORY ====================
  Widget _buildCategoryChips(bool isTablet) {
    return Consumer<ProductProvider>(
      builder: (_, product, __) {
        if (product.categories.isEmpty) return const SizedBox();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildChip(
                label: 'Semua',
                selected: _selectedCategoryId == null,
                onTap: () => setState(() => _selectedCategoryId = null),
              ),
              const SizedBox(width: 6),
              ...product.categories.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildChip(
                      label: c.name,
                      selected: _selectedCategoryId == c.id,
                      onTap: () =>
                          setState(() => _selectedCategoryId = c.id),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => onTap(),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.altSurface,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontSize: 11,
      ),
    );
  }

// ==================== PRODUCTS ====================
  Widget _buildProductList() {
    return Consumer<ProductProvider>(
      builder: (_, product, __) {
        var products = _selectedCategoryId == null
            ? product.products
            : product.getProductsByCategory(_selectedCategoryId!);

        if (product.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (products.isEmpty) {
          return Center(
            child: Text(
              'Tidak ada produk',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        // Sort: products with stock > 0 first, then by stock descending
        products = [...products]..sort((a, b) {
          if (a.stock > 0 && b.stock <= 0) return -1;
          if (a.stock <= 0 && b.stock > 0) return 1;
          return b.stock.compareTo(a.stock);
        });

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final productItem = products[index];
            final isOutOfStock = productItem.stock <= 0;
            
            return InkWell(
              onTap: isOutOfStock ? null : () {
                context.read<CartProvider>().addItem(productItem);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${productItem.name} ditambahkan'),
                    duration: const Duration(milliseconds: 400),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isOutOfStock 
                      ? AppColors.textSecondary.withValues(alpha: 0.3) 
                      : AppColors.altSurface,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isOutOfStock 
                    ? AppColors.surface.withValues(alpha: 0.5) 
                    : AppColors.surface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: _buildProductImage(productItem, isOutOfStock),
                      ),
                    ),
                    // Product Info
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Name
                          Text(
                            productItem.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: isOutOfStock 
                                ? AppColors.textSecondary 
                                : AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          // Price
                          Text(
                            NumberFormatter.formatRupiah(productItem.price),
                            style: TextStyle(
                              color: isOutOfStock 
                                ? AppColors.textSecondary 
                                : AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Stock Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, 
                              vertical: 2
                            ),
                            decoration: BoxDecoration(
                              color: isOutOfStock 
                                ? AppColors.error.withValues(alpha: 0.15) 
                                : AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isOutOfStock ? 'Habis' : 'Stok: ${productItem.stock}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isOutOfStock 
                                  ? AppColors.error 
                                  : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper to build product image
  Widget _buildProductImage(Product product, bool isOutOfStock) {
    // Get image path from product name using helper
    final imagePath = product.imageUrl ?? ProductImageHelper.getProductImagePath(product.name);

    // Try to load image from assets
    if (imagePath != null && imagePath.isNotEmpty) {
      return Stack(
        children: [
          Image.asset(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildFallbackImage(product);
            },
          ),
          if (isOutOfStock)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Icon(
                  Icons.block,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
            ),
        ],
      );
    }

    return _buildFallbackImage(product, isOutOfStock);
  }

  // Fallback image with icon
  Widget _buildFallbackImage(Product product, [bool isOutOfStock = false]) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.coffee,
          size: 48,
          color: isOutOfStock 
            ? AppColors.textSecondary.withValues(alpha: 0.3)
            : AppColors.primary.withValues(alpha: 0.3),
        ),
        if (isOutOfStock)
          Icon(
            Icons.block,
            color: AppColors.error,
            size: 32,
          ),
      ],
    );
  }

  // ==================== LOGOUT ====================
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final auth = context.read<AuthProvider>();
              await auth.signOut();

              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _handleProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  void _handleSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Setting - Coming Soon')),
    );
  }
}