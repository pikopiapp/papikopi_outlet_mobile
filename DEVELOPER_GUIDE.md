# 🎓 PapiKopi Mobile - Developer Guide

## 📖 Architecture Overview

### MVC-Like Pattern with Provider

```
User Input (UI)
     ↓
Widgets (Screens & Widgets)
     ↓
Providers (State Management)
     ↓
Services (Business Logic)
     ↓
Models (Data Objects)
     ↓
Supabase (Backend)
```

## 🏗️ Adding New Features

### 1. Adding a New Model

Create file: `lib/models/feature_name.dart`

```dart
class FeatureName {
  final String id;
  final String name;
  final DateTime createdAt;

  FeatureName({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  // JSON serialization
  factory FeatureName.fromJson(Map<String, dynamic> json) {
    return FeatureName(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
```

### 2. Adding Service Methods

Update: `lib/services/supabase_service.dart`

```dart
// In SupabaseService class
Future<List<FeatureName>> getFeatures() async {
  try {
    final response = await _client
        .from('feature_table')
        .select();

    return (response as List<dynamic>)
        .map((item) => FeatureName.fromJson(item as Map<String, dynamic>))
        .toList();
  } catch (e) {
    throw Exception('Failed to fetch features: $e');
  }
}

Future<void> createFeature({
  required String name,
}) async {
  await _client.from('feature_table').insert({
    'name': name,
  });
}
```

### 3. Adding Provider

Create file: `lib/providers/feature_provider.dart`

```dart
import 'package:flutter/material.dart';
import '../models/feature_name.dart';
import '../services/supabase_service.dart';

class FeatureProvider extends ChangeNotifier {
  final List<FeatureName> _features = [];
  bool _isLoading = false;
  String? _error;

  List<FeatureName> get features => _features;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final _supabaseService = SupabaseService();

  Future<void> loadFeatures() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final features = await _supabaseService.getFeatures();
      _features.clear();
      _features.addAll(features);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addFeature(String name) async {
    try {
      await _supabaseService.createFeature(name: name);
      await loadFeatures();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
```

### 4. Adding Provider to MultiProvider

Update: `lib/main.dart`

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => CartProvider()),
    ChangeNotifierProvider(create: (_) => ProductProvider()),
    ChangeNotifierProvider(create: (_) => FeatureProvider()), // Add this
  ],
  child: MaterialApp(
    // ...
  ),
)
```

### 5. Creating UI Screen

Create file: `lib/screens/feature_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feature_provider.dart';

class FeatureScreen extends StatefulWidget {
  const FeatureScreen({super.key});

  @override
  State<FeatureScreen> createState() => _FeatureScreenState();
}

class _FeatureScreenState extends State<FeatureScreen> {
  @override
  void initState() {
    super.initState();
    // Load data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeatureProvider>().loadFeatures();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Features'),
        backgroundColor: Colors.amber[700],
      ),
      body: Consumer<FeatureProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(child: Text('Error: ${provider.error}'));
          }

          return ListView.builder(
            itemCount: provider.features.length,
            itemBuilder: (context, index) {
              final feature = provider.features[index];
              return ListTile(
                title: Text(feature.name),
                subtitle: Text(feature.createdAt.toString()),
              );
            },
          );
        },
      ),
    );
  }
}
```

### 6. Adding Route

Update: `lib/main.dart`

```dart
routes: {
  '/login': (context) => const LoginScreen(),
  '/pos': (context) => const POSScreen(),
  '/leaderboard': (context) => const LeaderboardScreen(),
  '/feature': (context) => const FeatureScreen(), // Add this
},
```

## 🎯 Best Practices

### State Management

#### ✅ DO
```dart
// Use Consumer for widgets that depend on provider
Consumer<ProductProvider>(
  builder: (context, provider, _) {
    return Text(provider.products.length.toString());
  },
);

// Use context.read() for one-time operations
ElevatedButton(
  onPressed: () {
    context.read<CartProvider>().addItem(product);
  },
  child: const Text('Add'),
);

// Use context.watch() for reactive updates
final products = context.watch<ProductProvider>().products;
```

#### ❌ DON'T
```dart
// Don't rebuild entire widget for single value
Text(context.watch<ProductProvider>().products.length.toString());

// Don't use context.read() in build method if value changes
Widget build(BuildContext context) {
  final cart = context.read<CartProvider>(); // Will not update!
}
```

### Error Handling

```dart
try {
  final user = await supabaseService.signIn(
    email: email,
    password: password,
  );
  _currentUser = user;
} on AuthException catch (e) {
  _error = 'Auth Error: ${e.message}';
} on SocketException catch (e) {
  _error = 'Network Error: ${e.message}';
} catch (e) {
  _error = 'Unexpected Error: ${e.toString()}';
} finally {
  notifyListeners();
}
```

### Async Operations

```dart
// Use FutureBuilder for single async operation
FutureBuilder<List<Product>>(
  future: supabaseService.getProducts(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const CircularProgressIndicator();
    }
    if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    }
    return ListView(
      children: snapshot.data!.map((p) => Text(p.name)).toList(),
    );
  },
);

// Use Consumer for provider state + loading
Consumer<ProductProvider>(
  builder: (context, provider, _) {
    if (provider.isLoading) {
      return const CircularProgressIndicator();
    }
    return ListView(
      children: provider.products.map((p) => Text(p.name)).toList(),
    );
  },
);
```

### Widget Organization

```dart
// Keep widgets focused and small
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // UI implementation
      ),
    );
  }
}

// Extract complex business logic to providers
// Keep UI simple and declarative
```

## 🔌 API Integration Examples

### Simple GET Request
```dart
Future<List<Product>> getProducts() async {
  final response = await _client
      .from('products')
      .select();

  return (response as List<dynamic>)
      .map((item) => Product.fromJson(item as Map<String, dynamic>))
      .toList();
}
```

### Filtered Query
```dart
Future<List<Product>> getProductsByCategory(String categoryId) async {
  final response = await _client
      .from('products')
      .select()
      .eq('category_id', categoryId)
      .eq('is_active', true);

  return (response as List<dynamic>)
      .map((item) => Product.fromJson(item as Map<String, dynamic>))
      .toList();
}
```

### POST Request
```dart
Future<String> createSale({
  required String outletId,
  required String baristaId,
  required double totalAmount,
}) async {
  final response = await _client.from('sales').insert({
    'outlet_id': outletId,
    'barista_id': baristaId,
    'total_amount': totalAmount,
  }).select().single();

  return response['id'] as String;
}
```

### RPC Function Call
```dart
Future<List<Map<String, dynamic>>> getLeaderboard({
  required String outletId,
}) async {
  final response = await _client.rpc('get_barista_leaderboard', params: {
    'outlet_id': outletId,
  });

  return (response as List<dynamic>)
      .map((item) => item as Map<String, dynamic>)
      .toList();
}
```

## 🎨 UI Components

### Custom Button
```dart
ElevatedButton(
  onPressed: isLoading ? null : onPressed,
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.amber[700],
    disabledBackgroundColor: Colors.grey[300],
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
  child: isLoading
      ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Text('Submit'),
)
```

### Card with Shadow
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: // content
)
```

### Text Styles
```dart
// Heading
Text(
  'Title',
  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
    fontWeight: FontWeight.bold,
    color: Colors.amber[900],
  ),
);

// Body
Text(
  'Description',
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: Colors.grey[600],
  ),
);
```

## 📊 Debugging Tips

### Print Debug Info
```dart
print('DEBUG: ProductProvider - loadProducts called');
print('DEBUG: Products loaded: ${_products.length}');
print('DEBUG: Current user: ${_currentUser?.email}');
```

### Use DevTools
```bash
flutter pub global activate devtools
devtools
# Or in VS Code: F1 > Open DevTools
```

### Hot Reload Issues
```bash
# Hot reload
Press 'r' in terminal

# Hot restart
Press 'R' in terminal

# Full rebuild
flutter clean && flutter pub get && flutter run
```

## 🚀 Performance Tips

### Optimize Rebuilds
```dart
// Instead of rebuilding entire tree
// Use specific Consumer widgets
Consumer<CartProvider>(
  builder: (context, cartProvider, child) {
    return Text(cartProvider.totalAmount.toString());
  },
  child: ExpensiveWidget(), // Not rebuilt
);
```

### Lazy Loading
```dart
// Load data on demand, not upfront
FutureBuilder(
  future: _loadDataLazy(),
  builder: (context, snapshot) => snapshot.hasData 
    ? Widget() 
    : Placeholder(),
);
```

### Image Caching
```dart
// Images are cached by default
Image.network(
  'https://example.com/image.jpg',
  cacheHeight: 300,
  cacheWidth: 300,
);
```

## 📚 References

- [Flutter Documentation](https://flutter.dev/docs)
- [Provider Package](https://pub.dev/packages/provider)
- [Supabase Flutter](https://supabase.com/docs/reference/flutter)
- [Material Design](https://material.io/design)

---

**Last Updated**: April 2026
**Version**: 1.0.0
