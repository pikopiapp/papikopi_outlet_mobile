# 🛠️ Flutter Code Changes for Robust Error Handling

## Overview

After the database migrations are applied, update these Flutter files to add proper error handling and graceful fallbacks.

---

## File 1: `lib/services/supabase_service.dart`

### Add these new methods:

```dart
// Fallback revenue calculation if get_revenue_data function doesn't exist
Future<Map<String, dynamic>> _calculateRevenueManually(
  String outletId,
  DateTime startDate,
  DateTime endDate,
) async {
  try {
    final sales = await supabase
      .from('sales')
      .select()
      .eq('outlet_id', outletId)
      .gte('created_at', startDate.toIso8601String())
      .lte('created_at', endDate.toIso8601String());

    final totalRevenue = sales.fold<double>(
      0,
      (sum, sale) => sum + ((sale['total_amount'] ?? 0) as num).toDouble(),
    );

    final cashAmount = sales
      .where((s) => s['payment_method'] == 'cash')
      .fold<double>(0, (sum, s) => sum + ((s['total_amount'] ?? 0) as num).toDouble());

    final qrisAmount = sales
      .where((s) => s['payment_method'] == 'qris')
      .fold<double>(0, (sum, s) => sum + ((s['total_amount'] ?? 0) as num).toDouble());

    return {
      'total_revenue': totalRevenue,
      'transaction_count': sales.length,
      'avg_transaction': sales.isEmpty ? 0 : totalRevenue / sales.length,
      'cash_amount': cashAmount,
      'qris_amount': qrisAmount,
    };
  } catch (e) {
    debugPrint('❌ Error in manual revenue calculation: $e');
    return {
      'total_revenue': 0.0,
      'transaction_count': 0,
      'avg_transaction': 0.0,
      'cash_amount': 0.0,
      'qris_amount': 0.0,
    };
  }
}

// Safe fetch for outlet status with default values
Future<Map<String, dynamic>> getOutletStatusSafe(String outletId) async {
  try {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final response = await supabase
      .from('outlet_status')
      .select()
      .eq('outlet_id', outletId)
      .eq('status_date', today)
      .single();
    return response as Map<String, dynamic>;
  } on PostgrestException catch (e) {
    if (e.code == 'PGRST116') {
      // No records found - return sensible defaults
      debugPrint('⚠️ No outlet status found, using defaults');
      return {
        'status': 'open',
        'outlet_id': outletId,
        'status_date': DateTime.now().toIso8601String().split('T')[0],
        'notes': '',
      };
    }
    debugPrint('❌ Outlet status fetch error: ${e.message}');
    return {'status': 'unknown', 'outlet_id': outletId, 'notes': ''};
  } catch (e) {
    debugPrint('❌ Unexpected error fetching outlet status: $e');
    return {'status': 'unknown', 'outlet_id': outletId, 'notes': ''};
  }
}

// Safe revenue fetching with fallback
Future<Map<String, dynamic>> getRevenueSafe(
  String outletId,
  DateTime startDate,
  DateTime endDate,
) async {
  try {
    // Try to use the database function first
    final response = await supabase.rpc(
      'get_revenue_data',
      params: {
        'p_outlet_id': outletId,
        'p_start_date': startDate.toIso8601String(),
        'p_end_date': endDate.toIso8601String(),
      },
    ).single() as Map<String, dynamic>;

    return response;
  } on PostgrestException catch (e) {
    if (e.code == 'PGRST202') {
      // Function doesn't exist - use manual calculation
      debugPrint('⚠️ get_revenue_data not found, using manual calculation');
      return await _calculateRevenueManually(outletId, startDate, endDate);
    }
    debugPrint('❌ Revenue fetch error: ${e.message}');
    return await _calculateRevenueManually(outletId, startDate, endDate);
  } catch (e) {
    debugPrint('❌ Unexpected error fetching revenue: $e');
    return await _calculateRevenueManually(outletId, startDate, endDate);
  }
}
```

---

## File 2: `lib/screens/finance_screen.dart`

### Replace the revenue loading section:

**OLD CODE:**
```dart
// This might fail if get_revenue_data doesn't exist
final revenue = await supabase
  .rpc('get_revenue_data', params: {
    'p_outlet_id': outletId,
    'p_start_date': startDate.toIso8601String(),
    'p_end_date': endDate.toIso8601String(),
  })
  .single();
```

**NEW CODE:**
```dart
// Safe loading with fallback
try {
  final revenue = await _supabaseService.getRevenueSafe(
    outletId,
    startDate,
    endDate,
  );
  
  if (mounted) {
    setState(() {
      _revenue = revenue;
      _isLoading = false;
      _error = null;
    });
  }
} catch (e) {
  debugPrint('❌ Failed to load revenue: $e');
  if (mounted) {
    setState(() {
      _isLoading = false;
      _error = 'Gagal memuat data pendapatan';
      _revenue = {
        'total_revenue': 0.0,
        'transaction_count': 0,
        'avg_transaction': 0.0,
        'cash_amount': 0.0,
        'qris_amount': 0.0,
      };
    });
  }
}
```

---

## File 3: `lib/screens/approval_screen.dart`

### Update outlet status loading:

**NEW CODE:**
```dart
// Safe outlet status fetch
Future<void> _loadOutletStatus() async {
  try {
    final status = await _supabaseService.getOutletStatusSafe(
      _currentOutletId ?? '',
    );
    
    if (mounted) {
      setState(() {
        _outletStatus = status['status'] ?? 'unknown';
        _outletStatusNotes = status['notes'] ?? '';
        _statusError = null;
      });
    }
  } catch (e) {
    debugPrint('❌ Error loading outlet status: $e');
    if (mounted) {
      setState(() {
        _outletStatus = 'unknown';
        _statusError = 'Gagal memuat status outlet';
      });
    }
  }
}
```

---

## File 4: `lib/screens/pos_screen.dart`

### Update sales creation to handle notes field:

**NEW CODE:**
```dart
// When saving a sale, safely handle the notes field
final saleData = {
  'outlet_id': _currentOutletId,
  'total_amount': cartTotal,
  'payment_method': selectedPaymentMethod,
  'notes': _notesController.text.isNotEmpty 
    ? _notesController.text 
    : null,  // Allow null if no notes provided
  'items': jsonEncode(cartItems),
  'created_at': DateTime.now().toIso8601String(),
};

try {
  final response = await supabase
    .from('sales')
    .insert([saleData])
    .select();
    
  debugPrint('✅ Sale saved successfully: ${response.first['id']}');
} on PostgrestException catch (e) {
  if (e.code == 'COLUMN_DOES_NOT_EXIST') {
    // Field doesn't exist yet - save without it
    debugPrint('⚠️ Notes field not available, saving without notes');
    final saleDataWithoutNotes = {...saleData}..remove('notes');
    
    final response = await supabase
      .from('sales')
      .insert([saleDataWithoutNotes])
      .select();
  } else {
    debugPrint('❌ Error saving sale: $e');
    rethrow;
  }
} catch (e) {
  debugPrint('❌ Unexpected error saving sale: $e');
  rethrow;
}
```

---

## File 5: `lib/widgets/daily_bonus_card.dart`

### No database changes needed, but fix the `withOpacity()` deprecation:

```dart
// OLD (Deprecated):
color: Colors.green.withOpacity(0.1)

// NEW (Using withValues):
color: Colors.green.withValues(alpha: 0.1)

// Or alternatively:
color: Colors.green.withAlpha((0.1 * 255).toInt())
```

---

## Implementation Priority

### Phase 1: Critical (Database-dependent)
1. ✅ Execute `fix_mobile_database.sql` on Supabase
2. ✅ Add fallback methods to `supabase_service.dart`
3. ✅ Update `finance_screen.dart` with error handling

### Phase 2: Important (Quality)
4. Update `approval_screen.dart` for outlet status
5. Update `pos_screen.dart` for notes field
6. Fix `withOpacity()` in `daily_bonus_card.dart`

### Phase 3: Polish
7. Run `flutter analyze` - check for remaining issues
8. Run `flutter test` - ensure tests pass
9. Manual testing on device/simulator

---

## Testing After Changes

### Test 1: Finance Screen Loads
```bash
flutter run
# Navigate to Finance tab
# Should see: ✅ Revenue data loads, no errors, fallback works if function missing
```

### Test 2: Approval Screen Loads
```bash
# Navigate to Approval/Handover screen
# Should see: ✅ Outlet status displays, no PGRST116 errors
```

### Test 3: POS Sales with Notes
```bash
# Create a sale with notes
# Should see: ✅ Sale saves, notes stored (or gracefully ignored if field missing)
```

### Test 4: No Deprecation Warnings
```bash
flutter analyze
# Should see: ✅ No deprecation warnings for withOpacity()
```

---

## Success Indicators

After applying all changes:

- ✅ No `PostgrestException` errors in logs
- ✅ Finance screen loads revenue correctly
- ✅ Approval screen shows outlet status
- ✅ POS can record sales with optional notes
- ✅ No deprecation warnings from `flutter analyze`
- ✅ All screens have proper error fallbacks
- ✅ App gracefully handles missing database fields
- ✅ User sees appropriate error messages in UI when failures occur

---

## Rollback Plan

If any changes break functionality:

1. Remove the safe methods and revert to original code
2. The database migrations (`fix_mobile_database.sql`) are non-destructive and can stay
3. Git history preserves original code for quick rollback

```bash
git log --oneline --all  # Find the commit before changes
git checkout <commit> -- lib/screens/finance_screen.dart  # Revert one file
git checkout <commit> -- lib/services/supabase_service.dart  # Revert another
```

---

## Code Review Checklist

Before committing these changes:

- [ ] All new methods have proper error handling
- [ ] `debugPrint()` used instead of `print()`
- [ ] `mounted` check performed before `setState()`
- [ ] No hardcoded error messages (use i18n)
- [ ] Fallback values are sensible defaults
- [ ] Code is properly formatted with `dartfmt`
- [ ] No new dependencies added
- [ ] Backward compatible if database is missing objects
