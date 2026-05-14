# 🗂️ PapiKopi Mobile App - File Index & Architecture

## 📊 Project Overview

```
┌─────────────────────────────────────────────────────────────┐
│  PAPIKOPI MOBILE APP - FLUTTER POS SYSTEM                  │
│  Version 1.0.0 | Status: Ready for Development             │
│  Total Files: 17 Dart files | Total Lines: ~1,500+         │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Complete File Structure

### 1. Entry Point
```
lib/
├── main.dart (94 lines)
│   └── App initialization, MultiProvider setup, routing
│       Dependencies: provider, auth_provider, cart_provider, product_provider
│       Routes: /login, /pos, /leaderboard
```

### 2. Models (lib/models/) - Data Structures
```
lib/models/
├── user.dart (40 lines)
│   └── User model with ID, email, name, role, outlet_id
│       Methods: fromJson(), toJson()
│
├── product.dart (70 lines)
│   ├── Product model (id, categoryId, name, price, hpp, margin%)
│   └── Category model (id, name, description)
│       Methods: margin calculation, marginPercent calculation
│
├── sale.dart (90 lines)
│   ├── Sale model (id, outletId, baristaId, payment method, totals)
│   └── SaleItem model (productId, quantity, price, hpp)
│       Methods: profit calculation, subtotal calculation
│
├── outlet.dart (45 lines)
│   └── Outlet model (id, name, type, location, contact info)
│       Types: CART, SHOP, KIOSK
│
└── cart_item.dart (35 lines)
    └── CartItem model for shopping cart
        Methods: subtotal, profit, quantity management
```

### 3. Services (lib/services/) - Business Logic
```
lib/services/
├── supabase_service.dart (220 lines) ★ CRITICAL
│   ├── Singleton instance
│   ├── Authentication Methods:
│   │   ├── signUp(email, password, name)
│   │   ├── signIn(email, password)
│   │   ├── signOut()
│   │   └── getCurrentUser()
│   ├── Product Methods:
│   │   ├── getProducts()
│   │   ├── getProductsByCategory(categoryId)
│   │   └── getCategories()
│   ├── Sales Methods:
│   │   ├── createSale(...) → Returns saleId
│   │   └── getSales(outletId?, baristaId?)
│   ├── Outlet Methods:
│   │   └── getOutlet(outletId)
│   └── Leaderboard Methods:
│       └── getLeaderboard(outletId, startDate, endDate)
│
└── auth_service.dart (50 lines)
    ├── Local session management
    ├── Methods:
    │   ├── initialize()
    │   ├── saveUser(user)
    │   ├── getSavedUser() → User?
    │   ├── clearUser()
    │   └── isLoggedIn() → bool
    └── Uses: SharedPreferences for persistence
```

### 4. State Management (lib/providers/) - Provider Pattern
```
lib/providers/
├── auth_provider.dart (65 lines)
│   ├── Properties:
│   │   ├── _currentUser: User?
│   │   ├── _isLoading: bool
│   │   └── _error: String?
│   ├── Getters:
│   │   ├── currentUser, isLoading, error
│   │   └── isAuthenticated
│   └── Methods:
│       ├── initialize() → Future<void>
│       ├── signIn(email, password) → Future<void>
│       └── signOut() → Future<void>
│   Dependencies: AuthService, SupabaseService
│
├── cart_provider.dart (75 lines)
│   ├── Properties:
│   │   └── _items: List<CartItem>
│   ├── Getters:
│   │   ├── items, totalAmount, totalHpp
│   │   ├── totalProfit, itemCount, totalQuantity
│   └── Methods:
│       ├── addItem(product, quantity)
│       ├── removeItem(productId)
│       ├── updateQuantity(productId, qty)
│       ├── clear()
│       └── getItem(productId) → CartItem?
│   Features: Automatic quantity aggregation, profit calculation
│
└── product_provider.dart (70 lines)
    ├── Properties:
    │   ├── _products: List<Product>
    │   ├── _categories: List<Category>
    │   ├── _currentOutlet: Outlet?
    │   ├── _isLoading: bool
    │   └── _error: String?
    ├── Methods:
    │   ├── loadProducts() → Future<void>
    │   ├── loadCategories() → Future<void>
    │   ├── loadOutlet(outletId) → Future<void>
    │   └── getProductsByCategory(categoryId) → List<Product>
    └── Getters: products, categories, currentOutlet, isLoading, error
```

### 5. Screens (lib/screens/) - UI Pages
```
lib/screens/
├── login_screen.dart (170 lines)
│   ├── Layout: Column with form fields
│   ├── Components:
│   │   ├── Email input field
│   │   ├── Password input field (with visibility toggle)
│   │   └── Login button (with loading state)
│   ├── Features:
│   │   ├── Form validation
│   │   ├── Error display (SnackBar)
│   │   ├── Loading indicator
│   │   └── Auto-navigation on success
│   ├── Uses: AuthProvider, context.read<AuthProvider>()
│   └── Navigation: Redirects to '/pos' on successful login
│
├── pos_screen.dart (180 lines) ★ MAIN SCREEN
│   ├── Layout: Row (left 3/4 products, right 1/4 cart)
│   ├── Left Panel:
│   │   ├── Category filter buttons (scrollable)
│   │   └── ProductGrid (dynamic)
│   ├── Right Panel:
│   │   └── CartSummary widget
│   ├── Features:
│   │   ├── Real-time category filtering
│   │   ├── Product selection
│   │   ├── Cart management
│   │   └── Checkout modal
│   ├── AppBar:
│   │   ├── POS title
│   │   └── PopupMenu (Leaderboard, Logout)
│   └── Uses: ProductProvider, CartProvider, context
│
└── leaderboard_screen.dart (130 lines)
    ├── Layout: ListView of ranked baristas
    ├── Components:
    │   ├── Rank badge (1-3 highlighted)
    │   ├── Name & transaction count
    │   └── Revenue & profit display
    ├── Features:
    │   ├── Daily rankings
    │   ├── Top 3 color coding
    │   ├── Profit highlighting
    │   └── Auto-refresh on load
    ├── Data Flow:
    │   ├── Fetch on init
    │   ├── Group by day
    │   └── Sort by revenue
    └── Uses: SupabaseService, AuthProvider
```

### 6. Widgets (lib/widgets/) - Reusable Components
```
lib/widgets/
├── product_grid.dart (100 lines)
│   ├── StatelessWidget: ProductGrid
│   │   ├── Props: products[], isLoading
│   │   └── GridView with 2 columns
│   │
│   └── StatelessWidget: ProductCard
│       ├── Props: product
│       ├── Layout: Icon over name & price
│       ├── Features:
│       │   ├── Tap to add to cart
│       │   ├── Margin % display
│       │   └── Success SnackBar
│       └── Uses: context.read<CartProvider>()
│
├── cart_summary.dart (200 lines)
│   ├── StatelessWidget: CartSummary
│   │   ├── Header: "Keranjang" (amber)
│   │   ├── Body: CartItemWidget list
│   │   ├── Footer: Summary & buttons
│   │   ├── Calculations:
│   │   │   ├── Total items
│   │   │   ├── Total price
│   │   │   ├── Total HPP
│   │   │   └── Total profit
│   │   ├── Buttons:
│   │   │   ├── Checkout (main)
│   │   │   └── Clear (secondary)
│   │   └── Uses: Consumer<CartProvider>
│   │
│   └── StatelessWidget: CartItemWidget
│       ├── Props: item, onRemove, onQuantityChanged
│       ├── Layout: Row with product info & qty controls
│       ├── Features:
│       │   ├── + / - buttons
│       │   ├── Quantity display
│       │   ├── Remove button
│       │   └── Subtotal calculation
│       └── Callbacks for parent updates
│
└── checkout_modal.dart (220 lines)
    ├── StatefulWidget: CheckoutModal
    ├── Properties:
    │   ├── _selectedPaymentMethod: CASH/QRIS
    │   └── _isProcessing: bool
    ├── Layout:
    │   ├── Order summary card
    │   ├── Payment method selector (RadioButtons)
    │   ├── Action buttons (Cancel/Checkout)
    │   └── Loading state overlay
    ├── Features:
    │   ├── Real-time order summary
    │   ├── Payment method selection
    │   ├── Submit to backend
    │   ├── Error handling
    │   └── Cart auto-clear on success
    ├── Process:
    │   ├── Gather cart items
    │   ├── Calculate totals
    │   ├── Call SupabaseService.createSale()
    │   ├── Clear cart on success
    │   └── Show success message
    └── Uses: Provider, SupabaseService
```

### 7. Utils (lib/utils/) - Placeholder for Utilities
```
lib/utils/
└── (future utilities like formatters, helpers)
```

## 🔄 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    USER INTERACTION                          │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
    ┌────▼────┐            ┌────▼──────┐
    │LoginUI  │            │  POS UI   │
    │    │    │            │     │     │
    └────┼────┘            └─────┼─────┘
         │                       │
         │                  ┌────┴──────────┐
         │                  │               │
    ┌────▼────────┐   ┌─────▼──────┐  ┌────▼──────┐
    │AuthProvider │   │CartProvider│  │ProductProv│
    │    │        │   │     │      │  │    │      │
    └────┼────────┘   └─────┼──────┘  └────┼──────┘
         │                  │              │
         │            ┌─────┴──────────┐   │
         │            │                │   │
    ┌────▼─────────────▼──────┐   ┌────▼──────────┐
    │    AuthService          │   │SupabaseService│
    │(LocalStorage)           │   │  (Backend API)│
    │                         │   │               │
    │saveUser()               │   │getProducts()  │
    │getSavedUser()           │   │createSale()   │
    │isLoggedIn()             │   │getLeaderboard│
    │                         │   │signIn()       │
    └────────┬────────────────┘   └────┬──────────┘
             │                         │
         [Storage]               [Supabase]
      SharedPreferences          PostgreSQL
                                  + Auth
```

## 🎯 Feature Implementation Map

```
LOGIN FLOW
└── LoginScreen
    ├── Inputs: email, password
    ├── AuthProvider.signIn()
    │   ├── SupabaseService.signIn()
    │   ├── AuthService.saveUser()
    │   └── notifyListeners()
    └── Navigate to /pos

POS FLOW
└── POSScreen
    ├── ProductProvider.loadProducts()
    ├── ProductProvider.loadCategories()
    ├── Category Filter
    │   └── ProductGrid (filtered products)
    │       ├── ProductCard
    │       └── CartProvider.addItem()
    │           └── CartSummary updates
    └── Checkout
        ├── ShowModal: CheckoutModal
        ├── SelectPaymentMethod
        ├── SupabaseService.createSale()
        ├── CartProvider.clear()
        └── Show success

LEADERBOARD FLOW
└── LeaderboardScreen
    ├── SupabaseService.getLeaderboard()
    └── Display rankings with highlights
```

## 🔌 Integration Points

### Supabase Tables Used
```
✓ auth.users             - Authentication
✓ public.users           - User profiles
✓ public.products        - Product catalog
✓ public.categories      - Product categories
✓ public.sales           - Sales transactions
✓ public.sale_items      - Transaction items
✓ public.outlets         - Outlet information
✓ RPC: get_barista_leaderboard - Leaderboard
```

### External Dependencies
```
✓ provider               - State management
✓ supabase_flutter      - Backend API
✓ shared_preferences    - Local storage
✓ http                  - Network requests
✓ intl                  - Internationalization
✓ google_fonts          - Typography
✓ qr_flutter            - QR codes (future)
✓ connectivity_plus     - Network status (future)
```

## 📊 Statistics

| Metric | Count |
|--------|-------|
| **Total Dart Files** | 17 |
| **Main Entry Point** | main.dart |
| **Models** | 5 |
| **Services** | 2 |
| **Providers** | 3 |
| **Screens** | 3 |
| **Widgets** | 4 |
| **Total Lines (approx)** | 1,500+ |
| **Dependencies** | 10 |
| **Routes** | 3 |

## 🚀 Execution Flow

```
1. App Start
   ↓
2. main() - WidgetsFlutterBinding.ensureInitialized()
   ↓
3. SupabaseService.initialize()
   ↓
4. AuthService.initialize()
   ↓
5. runApp() - MaterialApp with MultiProvider
   ↓
6. _InitialScreen - Check auth state
   ↓
7. Route to /login or /pos
   ↓
8. User interaction → Provider updates
   ↓
9. UI re-renders via Consumer/Consumer widgets
   ↓
10. API calls via SupabaseService
   ↓
11. Data updates stored & displayed
```

## 📝 File Dependencies

```
main.dart
├── providers/auth_provider.dart
├── providers/cart_provider.dart
├── providers/product_provider.dart
├── screens/login_screen.dart
├── screens/pos_screen.dart
├── screens/leaderboard_screen.dart
├── services/supabase_service.dart
└── services/auth_service.dart

login_screen.dart
├── providers/auth_provider.dart
└── services/auth_service.dart

pos_screen.dart
├── providers/auth_provider.dart
├── providers/cart_provider.dart
├── providers/product_provider.dart
├── screens/leaderboard_screen.dart
├── widgets/product_grid.dart
└── widgets/cart_summary.dart

product_grid.dart
├── models/product.dart
└── providers/cart_provider.dart

cart_summary.dart
├── providers/cart_provider.dart
├── widgets/checkout_modal.dart
└── services/supabase_service.dart

checkout_modal.dart
├── providers/auth_provider.dart
├── providers/cart_provider.dart
└── services/supabase_service.dart

leaderboard_screen.dart
├── providers/auth_provider.dart
└── services/supabase_service.dart

*_provider.dart (all)
├── models/*.dart
└── services/supabase_service.dart
```

## ✅ Ready to Use

This mobile app is production-ready for:
- [x] Development & testing
- [x] Feature expansion
- [x] Integration testing
- [x] Performance optimization
- [x] User acceptance testing

---

**Last Updated**: April 2026
**Version**: 1.0.0
**Status**: Ready for Development ✨
