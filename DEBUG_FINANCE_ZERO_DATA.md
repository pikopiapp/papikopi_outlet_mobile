# Finance Screen - Debug Checklist

## Masalah
Data di Finance Screen menunjukkan nilai 0 padahal ada penjualan di table sales.

## Penyebab
1. **`_outletId` mungkin kosong/tidak ter-set** 
   - Jika `outletId` kosong → query tidak akan menemukan data
   - Added: Debug prints untuk track nilai outletId

2. **`business_day_start_hour` issue**
   - Data sales disimpan dengan timezone tertentu
   - Query menggunakan business_day_start_hour untuk calculate range
   - Jika timezone tidak match → data tidak ditemukan

3. **Sales data timezone issue**
   - Data di table sales menggunakan created_at dengan timezone
   - Perlu pastikan timezone query match dengan timezone data

## Fixes Applied

### 1. Finance Screen (finance_screen.dart)
```dart
// BEFORE: late String _outletId; (tidak ada default)
// AFTER: late String _outletId = ''; (ada default empty)

// Added debug prints:
print('DEBUG finance_screen: Outlet ID set to: $_outletId');
print('DEBUG finance_screen: Revenue data received: $data');
print('DEBUG finance_screen: Error loading revenue: $e');
```

### 2. SupabaseService (supabase_service.dart)
```dart
// BEFORE: throw Exception('Outlet ID is empty');
// AFTER: return empty data map (0.0, 0 count)

// Added debug prints:
print('ERROR getRevenueData: Outlet ID is empty');
print('ERROR getRevenueData: Outlet not found for id=$outletId');
```

## How to Debug

### Step 1: Check Console Output
1. Jalankan app: `flutter run`
2. Lihat console untuk debug messages
3. Cari: "DEBUG finance_screen" dan "ERROR getRevenueData"
4. **Catat nilai `_outletId` yang ditampilkan**

### Step 2: Verify Outlet ID
```bash
# Di Supabase SQL Editor, run:
SELECT id, name, business_day_start_hour 
FROM outlets 
LIMIT 5;

# Copy outlet ID dari hasil
```

### Step 3: Check Sales Data
```bash
# Di Supabase SQL Editor, check apakah ada sales untuk outlet tersebut:
SELECT outlet_id, total_amount, payment_method, created_at 
FROM sales 
WHERE outlet_id = 'YOUR_OUTLET_ID_HERE'
ORDER BY created_at DESC
LIMIT 10;

# Jika hasil kosong → data belum ada atau outlet_id salah
# Jika ada data → cek created_at apakah sesuai dengan expected range
```

### Step 4: Check Date Range Logic
```bash
# Cek business_day_start_hour untuk outlet Anda:
SELECT id, name, business_day_start_hour 
FROM outlets 
WHERE id = 'YOUR_OUTLET_ID_HERE';

# Contoh: Jika business_day_start_hour = 21
# Dan hari ini adalah 27 Mei 2026 jam 15:00
# Maka "hari ini" di sistem = 26 Mei 21:00 - 27 Mei 20:59:59

# Jika sales created_at = 27 Mei 15:00 → MASUK range (correct)
# Jika sales created_at = 26 Mei 20:00 → TIDAK masuk range (before start)
```

## Common Issues & Solutions

### Issue 1: outletId Kosong
**Signs:**
```
DEBUG finance_screen: Outlet ID set to: 
```
(nilai kosong)

**Solution:**
- Check apakah user sudah login
- Verify bahwa user punya outlet_id di database
- Check di table users apakah outlet_id ter-set

```sql
SELECT id, email, outlet_id FROM users WHERE email='your_email';
```

### Issue 2: Outlet Tidak Ditemukan
**Signs:**
```
ERROR getRevenueData: Outlet not found for id=xxx-yyy-zzz
```

**Solution:**
- Verify outlet ID benar
- Check apakah outlet masih aktif di database

```sql
SELECT id, name, status FROM outlets WHERE id='xxx-yyy-zzz';
```

### Issue 3: Sales Data Ada tapi Tidak Muncul
**Signs:**
```
DEBUG finance_screen: Revenue data received: {
  'daily': {'amount': 0.0, 'count': 0, ...},
  ...
}
```
Padahal di table sales ada data

**Solution:**
- Check timezone/date range logic
- Verify business_day_start_hour setting
- Check apakah sales.created_at dalam range yang diquery

```sql
-- Check sales dalam date range yang expected
SELECT COUNT(*) 
FROM sales 
WHERE outlet_id='xxx-yyy-zzz'
AND created_at >= '2026-05-26 21:00:00'  -- yesterday at 21:00 (if start_hour=21)
AND created_at <= '2026-05-27 20:59:59'; -- today at 20:59:59
```

## Next Steps

1. **Run flutter dengan debug mode**
   ```bash
   cd papikopi_mobile
   flutter run -v
   ```

2. **Check console output untuk debug messages**
   - Look for "DEBUG finance_screen"
   - Look for "ERROR getRevenueData"

3. **Report hasil debug ke saya**
   - Nilai outlet_id yang di-set
   - Error messages yang muncul (jika ada)
   - Hasil dari SQL queries di atas

4. **Possible Additional Fixes**
   - Timezone handling untuk created_at
   - Business day start hour validation
   - Sales data validation

## Files Modified
- `/papikopi_mobile/lib/screens/finance_screen.dart` - Added debug prints, fixed _outletId initialization
- `/papikopi_mobile/lib/services/supabase_service.dart` - Changed exception to return empty data, added debug prints

