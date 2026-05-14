# 📱 PapiKopi Mobile App - Setup Guide

## ✅ Setup Checklist

### Phase 1: Project Structure ✓ COMPLETE

- [x] Flutter project initialized
- [x] Folder structure created (models, services, screens, widgets, providers, utils)
- [x] All dependencies added to pubspec.yaml
- [x] `flutter pub get` completed successfully

### Phase 2: Core Models ✓ COMPLETE

- [x] User model created
- [x] Product & Category models created
- [x] Sale & SaleItem models created
- [x] Outlet model created
- [x] CartItem model created

### Phase 3: Services ✓ COMPLETE

- [x] SupabaseService created with API integration
  - [x] Authentication methods (signUp, signIn, signOut)
  - [x] Product methods (getProducts, getProductsByCategory)
  - [x] Category methods (getCategories)
  - [x] Sales methods (createSale, getSales)
  - [x] Outlet methods (getOutlet)
  - [x] Leaderboard methods (getLeaderboard)
  
- [x] AuthService created for local session management
  - [x] User persistence with SharedPreferences
  - [x] Session checking

### Phase 4: State Management (Provider) ✓ COMPLETE

- [x] AuthProvider
  - [x] User authentication logic
  - [x] Login/Logout flow
  - [x] Session persistence
  
- [x] CartProvider
  - [x] Add/Remove items
  - [x] Update quantities
  - [x] Calculate totals
  - [x] Profit calculation
  
- [x] ProductProvider
  - [x] Load products list
  - [x] Load categories
  - [x] Filter by category
  - [x] Load outlet info

### Phase 5: Screens ✓ COMPLETE

- [x] **LoginScreen**
  - [x] Email/Password input
  - [x] Form validation
  - [x] Loading state
  - [x] Error handling
  - [x] Navigation to POS on success
  
- [x] **POSScreen**
  - [x] Product grid with categories
  - [x] Category filters
  - [x] Product cards with pricing
  - [x] Cart summary on right panel
  - [x] Checkout button
  - [x] Menu with Leaderboard & Logout
  
- [x] **LeaderboardScreen**
  - [x] Barista rankings
  - [x] Revenue display
  - [x] Profit display
  - [x] Transaction count
  - [x] Top 3 highlighting

### Phase 6: Widgets ✓ COMPLETE

- [x] **ProductGrid**
  - [x] Grid layout
  - [x] Product cards
  - [x] Add to cart on tap
  
- [x] **CartSummary**
  - [x] Items list
  - [x] Quantity controls
  - [x] Total calculations
  - [x] Checkout button
  - [x] Clear cart button
  
- [x] **CheckoutModal**
  - [x] Order summary
  - [x] Payment method selection
  - [x] Confirm button
  - [x] Processing state

### Phase 7: App Setup ✓ COMPLETE

- [x] main.dart updated
  - [x] MultiProvider setup
  - [x] Route configuration
  - [x] App theme configuration
  - [x] Initial screen logic
  - [x] Service initialization

## 🔧 Configuration Required

### 1. Supabase Credentials
Edit `lib/services/supabase_service.dart`:

```dart
// TODO: Update with your Supabase credentials
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

Get these from:
1. Go to your Supabase project dashboard
2. Settings → API
3. Copy Project URL and Anon Key

### 2. Database Setup
Ensure backend database is running with:
- [x] Users table (with auth integration)
- [x] Products table
- [x] Categories table
- [x] Sales table
- [x] Sale items table
- [x] Outlets table
- [x] RLS policies configured

Refer to: `/papikopi/database_schema.sql`

### 3. Authentication
- Users must be created in Supabase Auth
- Default role: 'barista'
- User profile created automatically in users table

## 🚀 First Run

### Prerequisites Checklist
- [ ] Flutter SDK installed (`flutter --version`)
- [ ] Android Studio / Xcode configured
- [ ] Virtual device or physical device connected
- [ ] Supabase credentials configured
- [ ] Dependencies installed (`flutter pub get`)

### Run Steps
```bash
# Navigate to mobile app
cd papikopi_mobile

# Get dependencies
flutter pub get

# List available devices
flutter devices

# Run on device/emulator
flutter run -d <device_id>

# Or run on default device
flutter run
```

### Expected Behavior
1. App starts with splash screen
2. Redirects to login or POS based on session
3. Login page shows email/password fields
4. On successful login → Navigates to POS screen
5. POS shows products in categories
6. Can add to cart, checkout, view leaderboard

## 📊 Feature Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| **Authentication** | ✅ Complete | Email/Password login |
| **Product Display** | ✅ Complete | Grid with categories |
| **Shopping Cart** | ✅ Complete | Add/Remove/Update qty |
| **Checkout** | ✅ Complete | CASH/QRIS methods |
| **Leaderboard** | ✅ Complete | Daily rankings |
| **Settings** | ⏳ Planned | Profile, preferences |
| **Offline Mode** | ⏳ Planned | Local data sync |
| **Notifications** | ⏳ Planned | Firebase push |
| **Analytics** | ⏳ Planned | User behavior tracking |

## 📱 Testing Flow

### Test Login
```
Email: barista@papikopi.test
Password: password123
Expected: Redirect to POS screen
```

### Test POS
1. Add 2-3 products to cart
2. Verify total amount calculated
3. Check profit calculation
4. Click checkout
5. Select payment method
6. Confirm transaction
7. Cart clears on success

### Test Leaderboard
1. From POS menu, click "Leaderboard"
2. View barista rankings
3. Check revenue & profit display
4. Verify top 3 highlighting

## 🐛 Common Issues & Solutions

### Issue: "Target of URI doesn't exist"
**Solution**: Run `flutter pub get` again
```bash
flutter pub get
flutter clean
flutter pub get
```

### Issue: Supabase connection error
**Solution**: 
- Check credentials in `supabase_service.dart`
- Verify Supabase project is active
- Check internet connection

### Issue: Hot reload not working
**Solution**: Use hot restart
- Press 'R' in terminal instead of 'r'

### Issue: Build fails on specific platform
**Solution**:
```bash
flutter clean
flutter pub get
flutter run
```

## 📚 Documentation Structure

```
/papikopi/
├── README.md                    # Main project guide
├── CHECKLIST.md                 # Overall progress
├── SETUP_SUMMARY.md             # Quick reference
├── database_schema.sql          # DB migrations
├── coffee-outlet-system-spec.md # System specification
└── papikopi_mobile/
    ├── MOBILE_APP_README.md     # This detailed guide
    ├── MOBILE_SETUP.md          # Setup checklist (you are here)
    └── ...
```

## 🔄 Next Steps

### Immediate
1. [ ] Configure Supabase credentials
2. [ ] Run app on device/emulator
3. [ ] Test login flow
4. [ ] Test POS functionality

### Short Term (Phase 2)
1. [ ] Add product images
2. [ ] Implement offline cache
3. [ ] Add receipt printing
4. [ ] Implement daily reporting

### Medium Term (Phase 3)
1. [ ] Push notifications
2. [ ] Advanced analytics
3. [ ] Inventory management
4. [ ] Staff management

### Long Term
1. [ ] Mobile app store deployment
2. [ ] Multi-language support
3. [ ] Advanced reporting features
4. [ ] Integration with accounting system

## 📞 Need Help?

### Resources
1. **Flutter Docs**: https://flutter.dev/docs
2. **Provider Package**: https://pub.dev/packages/provider
3. **Supabase Docs**: https://supabase.com/docs
4. **Dart Docs**: https://dart.dev/guides

### Project Files
- Check `/papikopi/CLAUDE.md` for AI Assistant notes
- Review `/papikopi/AGENTS.md` for agent configuration
- Check `/papikopi/README.md` for full system documentation

## ✨ Project Status

**Mobile App Phase**: READY FOR DEVELOPMENT ✅

- Architecture: Complete
- Scaffolding: Complete
- Core Features: Complete
- Services: Complete
- UI Screens: Complete
- Ready for: Testing & Refinement

---

**Setup Date**: April 2026
**Mobile App Version**: 1.0.0 (Ready)
**Status**: Development Ready ✨
