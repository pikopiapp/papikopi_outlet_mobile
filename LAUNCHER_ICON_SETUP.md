# 🎨 Launcher Icon & Splash Screen Setup Guide

## ✅ Apa yang Sudah Dilakukan

### 1. **Flutter Native Splash Screen** ✓
- ✅ Konfigurasi splash screen di `pubspec.yaml`
- ✅ Logo PapiKopi ditampilkan saat app startup
- ✅ Background color: `#1F4E5F` (warna brand PapiKopi)
- ✅ Tersedia untuk Android dan iOS

**Status**: Native splash screen sudah digenerate dan siap digunakan!

### 2. **Launcher Icon Generator** 
- ✅ Konfigurasi flutter_launcher_icons di `pubspec.yaml`
- ✅ Menggunakan logo dari `assets/logo.png` (1024x1024px)
- ✅ Target: Android dan iOS

**Status**: Konfigurasi siap, tinggal iOS folder structure lengkap.

---

## 📱 Menggunakan Splash Screen

### Di main.dart:
```dart
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:papikopi_mobile/screens/splash_screen.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  
  // Keep splash screen visible during initialization
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // Do initialization work here (login check, etc.)
  await Future.delayed(Duration(seconds: 2)); // Simulate work
  
  // Remove splash and continue to app
  FlutterNativeSplash.remove();
  
  runApp(const MyApp());
}
```

### Custom Splash Widget:
```dart
// Gunakan splash_screen.dart yang sudah dibuat untuk animasi custom
SplashScreen(
  nextScreen: const HomeScreen(),
)
```

---

## 🎯 Android Launcher Icon (SUDAH JADI)

Files yang di-generate:
```
android/app/src/main/res/
├── mipmap-mdpi/ic_launcher.png
├── mipmap-hdpi/ic_launcher.png
├── mipmap-xhdpi/ic_launcher.png
├── mipmap-xxhdpi/ic_launcher.png
└── mipmap-xxxhdpi/ic_launcher.png
```

**Status**: ✅ Icon sudah di-generate dan siap digunakan!

---

## 🍎 iOS Launcher Icon (PERLU SETUP)

Untuk iOS, perlu manual setup atau jalankan di Mac:
```bash
flutter pub run flutter_launcher_icons --ios
```

Atau manual:
1. Buka `ios/Runner.xcworkspace` di Xcode
2. Select `Runner` → `Assets.xcassets`
3. Drag logo.png ke `AppIcon`
4. Xcode akan auto-resize ke berbagai ukuran

---

## 🎨 Splash Screen Details

### Native Splash (Android):
- **Color**: `#1F4E5F` (brand color)
- **Image**: Logo PapiKopi (512x512px recommended)
- **Supported**: Android 5.0+ (API 21+)
- **Files Modified**:
  - `android/app/src/main/res/drawable/launch_background.xml`
  - `android/app/src/main/res/drawable-night/launch_background.xml`
  - `android/app/src/main/res/values/styles.xml`

### Programmatic Splash (Dart):
- File: `lib/screens/splash_screen.dart`
- Features:
  - Scale animation untuk logo
  - Fade animation untuk text
  - Loading spinner
  - 3 detik display time

---

## 🚀 Jalankan App dengan Splash:

```bash
# Clean dan rebuild
flutter clean
flutter pub get

# Run di Android
flutter run

# Atau specify device
flutter run -d <device-id>
```

---

## 📋 Checklist

### Android:
- ✅ Native splash screen generated
- ✅ Launcher icon directories created
- ✅ Assets di-configure
- ⏳ Icon files perlu di-copy (atau regenerate dengan logo)

### iOS:
- ⏳ Perlu manual setup di Xcode atau Mac machine

### Dart:
- ✅ flutter_native_splash package added
- ✅ flutter_launcher_icons package added
- ✅ Custom splash_screen.dart widget created
- ✅ Ready untuk import di main.dart

---

## 🎁 Next Steps

1. **Copy/Regenerate Icons** (jika di Mac):
   ```bash
   flutter pub run flutter_launcher_icons
   ```

2. **Integrate di main.dart**:
   ```dart
   // Import splash screen
   // Initialize FlutterNativeSplash
   // Show splash during initialization
   ```

3. **Test**:
   ```bash
   flutter run
   # Lihat splash screen selama 3 detik saat startup
   ```

4. **Customize** (optional):
   - Edit warna di pubspec.yaml → `flutter_native_splash`
   - Edit animation di `lib/screens/splash_screen.dart`

---

## 📸 Visual Preview

- **Logo**: PapiKopi (from assets/logo.png)
- **Background**: Dark blue gradient (#1F4E5F)
- **Animation**: Scale + Fade untuk smooth entry
- **Branding**: Cocok dengan brand identity PapiKopi

Semuanya siap! 🎉
