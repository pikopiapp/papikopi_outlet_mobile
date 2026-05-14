# PapiKopi Mobile App - Flutter POS Application

## 📱 Aplikasi Mobile PapiKopi

Aplikasi mobile **Point of Sale (POS)** berbasis Flutter untuk barista di outlet kopi PapiKopi. Dirancang untuk mengelola penjualan dengan cepat dan stabil, dengan dukungan offline.

## 🎯 Fitur Utama

### 1. **Autentikasi**
- Login dengan email dan password
- Persistent session dengan SharedPreferences
- Proteksi role-based (barista only)

### 2. **Sistem POS**
- Tampilan produk berdasarkan kategori
- Keranjang belanja interaktif
- Kalkulasi harga real-time
- HPP (Harga Pokok Penjualan) tracking
- Perhitungan profit otomatis

### 3. **Checkout & Pembayaran**
- Metode pembayaran: CASH dan QRIS
- Konfirmasi transaksi
- Integrasi dengan database backend

### 4. **Leaderboard**
- Ranking barista berdasarkan revenue
- Profit tracking
- Jumlah transaksi
- Tampilan real-time

## 📂 Struktur Proyek

```
papikopi_mobile/
├── lib/
│   ├── main.dart                 # Entry point aplikasi
│   ├── models/                   # Data models
│   │   ├── user.dart            # Model User
│   │   ├── product.dart         # Model Product & Category
│   │   ├── sale.dart            # Model Sale & SaleItem
│   │   ├── outlet.dart          # Model Outlet
│   │   └── cart_item.dart       # Model CartItem
│   ├── services/                # Services & API
│   │   ├── supabase_service.dart # Supabase client & API calls
│   │   └── auth_service.dart    # Local auth management
│   ├── providers/               # State management (Provider)
│   │   ├── auth_provider.dart   # Auth state
│   │   ├── cart_provider.dart   # Cart state
│   │   └── product_provider.dart # Products state
│   ├── screens/                 # UI Screens
│   │   ├── login_screen.dart    # Login page
│   │   ├── pos_screen.dart      # POS/Penjualan page
│   │   └── leaderboard_screen.dart # Leaderboard page
│   ├── widgets/                 # Reusable widgets
│   │   ├── product_grid.dart    # Product display grid
│   │   ├── cart_summary.dart    # Cart summary widget
│   │   └── checkout_modal.dart  # Checkout dialog
│   └── utils/                   # Utility functions
├── android/                     # Android native code
├── ios/                         # iOS native code
├── pubspec.yaml                 # Dependencies & config
└── README.md                    # This file
```

## 📦 Dependencies

```yaml
# Core
flutter: sdk
provider: ^6.1.0                 # State Management

# Backend
supabase_flutter: ^1.10.0        # Supabase client
http: ^1.1.0                     # HTTP requests

# UI & Utilities
cupertino_icons: ^1.0.8
google_fonts: ^6.2.0
intl: ^0.19.0                    # Internationalization

# Data & Storage
shared_preferences: ^2.2.0       # Local storage

# QR Code (untuk future feature)
qr_flutter: ^4.1.0

# Connectivity (untuk offline support)
connectivity_plus: ^5.0.0
```

## 🚀 Memulai

### Prerequisites
- Flutter SDK ^3.8.1
- Dart 3.8.1+
- Supabase account & credentials

### Setup

1. **Install dependencies**
   ```bash
   cd papikopi_mobile
   flutter pub get
   ```

2. **Configure Supabase**
   Buka file `lib/services/supabase_service.dart` dan update:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```

3. **Run aplikasi**
   ```bash
   # Android
   flutter run -d android
   
   # iOS
   flutter run -d ios
   
   # Web (development)
   flutter run -d web
   ```

## 🏗️ Arsitektur

### State Management (Provider)
Menggunakan `provider` package untuk state management:

- **AuthProvider**: Manage login, logout, user session
- **CartProvider**: Manage shopping cart state
- **ProductProvider**: Manage product list & categories

### Services
- **SupabaseService**: API calls ke database
- **AuthService**: Local session management

### Models
- **User**: User profile & role
- **Product**: Product data & pricing
- **Sale & SaleItem**: Transaction data
- **CartItem**: Cart item untuk checkout
- **Outlet**: Outlet information

## 📋 User Flow

```
┌─────────────┐
│  Start App  │
└──────┬──────┘
       │
       ▼
  ┌─────────────┐
  │ Check Token │
  └──────┬──────┘
         │
    ┌────┴────┐
    │          │
    ▼          ▼
  Login    POS Home
    │          │
    │          ├─→ Product Selection
    │          │    ├─→ By Category
    │          │    └─→ Add to Cart
    │          │
    │          ├─→ Cart Management
    │          │    ├─→ Update Qty
    │          │    └─→ Remove Item
    │          │
    │          ├─→ Checkout
    │          │    ├─→ Select Payment
    │          │    └─→ Confirm & Submit
    │          │
    │          └─→ Leaderboard
    │               └─→ View Rankings
    │
    └─→ Logout
```

## 🔧 Fitur Detailed

### Login Screen
- Email & password input
- Password visibility toggle
- Loading state
- Error handling
- Persistent login

### POS Screen
- **Header**: Toolbar dengan menu & logout
- **Left Panel** (3/4 width):
  - Category filter buttons
  - Product grid
  - Dynamic product loading

- **Right Panel** (1/4 width):
  - Cart items list
  - Quantity controls
  - Total calculation
  - Profit display
  - Checkout button

### Checkout Modal
- Order summary
- Payment method selection (CASH/QRIS)
- Confirmation button
- Cancel button
- Processing state

### Leaderboard Screen
- Ranking dengan top 3 highlight
- Barista name & transaction count
- Revenue & profit display
- Daily data
- Pull-to-refresh support

## 💾 Data Models

### User
```dart
- id: String
- email: String
- name: String
- role: String (barista/manager/admin)
- outletId: String
- createdAt: DateTime
```

### Product
```dart
- id: String
- categoryId: String
- name: String
- price: double
- hpp: double (cost)
- marginPercent: double (calculated)
- isActive: bool
```

### Sale
```dart
- id: String
- outletId: String
- baristaId: String
- paymentMethod: String (CASH/QRIS)
- totalAmount: double
- totalHpp: double
- totalBonus: double
- profit: double
- items: List<SaleItem>
```

## 🔐 Security

- Supabase RLS (Row Level Security) untuk data protection
- Role-based access control
- Session persistence
- Secure password handling via Supabase Auth

## 🧪 Testing

### Manual Testing
```bash
# Device/Emulator preparation
flutter devices

# Run dengan specific device
flutter run -d <device_id>

# Run dengan debug info
flutter run -v

# Hot reload
Press 'r' in terminal

# Hot restart
Press 'R' in terminal
```

### Test Scenarios
1. **Login Flow**
   - Valid credentials → Redirect to POS
   - Invalid credentials → Show error
   - Session persistence → Auto-login

2. **POS Flow**
   - Add products to cart
   - Update quantities
   - Remove items
   - Clear cart
   - Checkout with CASH/QRIS

3. **Leaderboard**
   - Display top performers
   - Show rankings
   - Display metrics

## 🐛 Troubleshooting

### Packages not found
```bash
flutter pub get
flutter clean
flutter pub get
```

### Build issues
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### Supabase connection error
- Verify URL dan API key di `supabase_service.dart`
- Check internet connection
- Check Supabase project status

### Hot reload not working
- Do hot restart: `Press 'R'`
- Or rebuild: `flutter run`

## 📝 Development Notes

### Best Practices
1. **State Management**: Use Provider untuk semua state
2. **Error Handling**: Always wrap API calls dengan try-catch
3. **UI**: Build reusable widgets di `widgets/` folder
4. **Async**: Gunakan FutureBuilder dan Consumer untuk async UI

### Code Style
- Follow Flutter/Dart conventions
- Use meaningful names
- Document complex logic
- Keep widgets small & focused

## 🔄 API Integration

### Key Endpoints (via Supabase RPC)
- `create_sale`: Create new transaction
- `get_barista_leaderboard`: Get rankings
- `get_products`: Fetch product list
- `get_categories`: Fetch categories

### Error Handling
Semua API calls menggunakan try-catch untuk handling errors:
```dart
try {
  final result = await supabaseService.callFunction();
} catch (e) {
  showErrorSnackbar(e.toString());
}
```

## 📱 Platform-Specific Notes

### Android
- Min SDK: 21
- Target SDK: Latest

### iOS
- Min iOS: 11.0
- Uses Swift

### Web
- Supported for development
- Not recommended for production barista app

## 🚀 Deployment

### Android
```bash
flutter build apk
# atau untuk release
flutter build appbundle
```

### iOS
```bash
flutter build ios
# Buka di Xcode untuk signing & deployment
```

## 📞 Support

Untuk issues atau questions:
1. Check documentation di folder root `/papikopi/`
2. Review CHECKLIST.md untuk project status
3. Check SETUP_SUMMARY.md untuk quick reference

## 📄 License

Private project untuk PapiKopi

---

**Last Updated**: April 2026
**Version**: 1.0.0
**Status**: Ready for Development ✅
