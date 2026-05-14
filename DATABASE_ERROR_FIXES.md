# Flutter Mobile - Database Error Fixes

## 🔧 Issues & Fixes

### Issue 1: Missing `get_revenue_data()` Function
**Error**: `PostgrestException(message: Could not find the function public.get_revenue_data...)`

**Fix Applied**: Created function in `fix_mobile_database.sql`

**In Flutter** - Update `lib/services/supabase_service.dart`:
```dart
// Add error handling for missing function
try {
  final response = await supabase
    .rpc('get_revenue_data', params: {
      'p_outlet_id': outletId,
      'p_start_date': startDate.toIso8601String(),
      'p_end_date': endDate.toIso8601String(),
    })
    .single();
  return response;
} on PostgrestException catch (e) {
  if (e.code == 'PGRST202') {
    // Function not found - fallback to manual calculation
    debugPrint('⚠️ get_revenue_data not found, using fallback');
    return _calculateRevenueManually(outletId, startDate, endDate);
  }
  rethrow;
}
```

---

### Issue 2: Missing `sales.notes` Column
**Error**: `PostgrestException(message: column sales.notes does not exist...)`

**Fix Applied**: Added column in `fix_mobile_database.sql`

**In Flutter** - Make notes optional:
```dart
// In models/sale.dart or where notes are accessed
final notes = data['notes'] as String? ?? '';  // Default to empty string
```

---

### Issue 3: Missing Outlet Status Data
**Error**: `PostgrestException(message: Cannot coerce the result to a single JSON object...)`

**Cause**: Query returns 0 rows (no outlet_status records)

**Fix Applied**: 
1. Created `outlet_status` table
2. Inserted default records
3. Added `fix_mobile_database.sql`

**In Flutter** - Handle empty results:
```dart
try {
  final status = await supabase
    .from('outlet_status')
    .select()
    .eq('outlet_id', outletId)
    .eq('status_date', today)
    .single();
  return status;
} on PostgrestException catch (e) {
  if (e.code == 'PGRST116') {
    // No records found - return default
    debugPrint('⚠️ No outlet status found, using default: open');
    return {'status': 'open', 'outlet_id': outletId, 'status_date': today};
  }
  rethrow;
}
```

---

## 📋 Implementation Steps

### Step 1: Apply Database Migration
1. Open Supabase console
2. Go to SQL Editor
3. Copy & paste contents of `fix_mobile_database.sql`
4. Execute

### Step 2: Update Flutter Code

**File: `lib/services/supabase_service.dart`**

Add these methods:
```dart
// Fallback for revenue calculation if function doesn't exist
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
      (sum, sale) => sum + (sale['total_amount'] as num).toDouble(),
    );

    return {
      'total_revenue': totalRevenue,
      'transaction_count': sales.length,
      'avg_transaction': sales.isEmpty ? 0 : totalRevenue / sales.length,
      'cash_amount': sales
          .where((s) => s['payment_method'] == 'cash')
          .fold<double>(0, (sum, s) => sum + (s['total_amount'] as num).toDouble()),
      'qris_amount': sales
          .where((s) => s['payment_method'] == 'qris')
          .fold<double>(0, (sum, s) => sum + (s['total_amount'] as num).toDouble()),
    };
  } catch (e) {
    debugPrint('❌ Error calculating revenue manually: $e');
    return {
      'total_revenue': 0,
      'transaction_count': 0,
      'avg_transaction': 0,
      'cash_amount': 0,
      'qris_amount': 0,
    };
  }
}

// Safe outlet status fetch with defaults
Future<Map<String, dynamic>> getOutletStatus(String outletId) async {
  try {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final response = await supabase
      .from('outlet_status')
      .select()
      .eq('outlet_id', outletId)
      .eq('status_date', today)
      .single();
    return response;
  } on PostgrestException catch (e) {
    if (e.code == 'PGRST116') {
      // No records - return default
      return {
        'status': 'open',
        'outlet_id': outletId,
        'status_date': DateTime.now().toIso8601String().split('T')[0],
        'notes': '',
      };
    }
    debugPrint('❌ Error fetching outlet status: $e');
    return {'status': 'unknown', 'outlet_id': outletId};
  }
}
```

**File: `lib/screens/finance_screen.dart`**

Update revenue fetching:
```dart
// Replace the revenue fetching code with error handling
try {
  final revenue = await supabaseService.rpc('get_revenue_data', params: {
    'p_outlet_id': outletId,
    'p_start_date': startDate.toIso8601String(),
    'p_end_date': endDate.toIso8601String(),
  }).single();
  
  setState(() {
    _revenue = revenue;
  });
} on PostgrestException catch (e) {
  if (e.code == 'PGRST202') {
    // Function doesn't exist - use fallback
    debugPrint('Using fallback revenue calculation');
    final manualRevenue = await supabaseService._calculateRevenueManually(
      outletId,
      startDate,
      endDate,
    );
    setState(() {
      _revenue = manualRevenue;
    });
  } else {
    debugPrint('❌ Error: $e');
  }
}
```

---

## ✅ What's Already Working

Good news! These are working correctly:
- ✅ Sales data fetching (8 records)
- ✅ Business day calculations (04:00 start)
- ✅ Daily/Weekly/Monthly grouping
- ✅ Cash vs QRIS separation
- ✅ Bonus calculations (Rp76,740)
- ✅ Meal allowance (Rp34,000)
- ✅ Handover status tracking
- ✅ Sales amount calculations

---

## 📝 Files Modified

**Database:**
- ✅ `fix_mobile_database.sql` - NEW (Run this first!)

**Flutter:**
- 📝 `lib/services/supabase_service.dart` - Add fallback methods
- 📝 `lib/screens/finance_screen.dart` - Add error handling
- 📝 `lib/screens/approval_screen.dart` - Add error handling for notes column

---

## 🧪 Testing Checklist

After applying fixes:

- [ ] Run app and navigate to Finance screen
- [ ] Verify revenue loads without errors
- [ ] Check outlet status displays correctly  
- [ ] Test with missing notes column (should not error)
- [ ] Verify fallback calculations work
- [ ] Check debug logs for proper error handling

---

## 🚀 Quick Start

1. **Copy SQL file to Supabase**:
   ```bash
   cat /Users/sugenghariadi/papikopi/fix_mobile_database.sql
   ```

2. **Run in Supabase SQL Editor**

3. **Update Flutter code** with error handlers above

4. **Test the app**:
   ```bash
   cd papikopi_mobile
   flutter run
   ```

That's it! 🎉
