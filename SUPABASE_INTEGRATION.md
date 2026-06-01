# Supabase Integration - Profit Calculator Real Data

## Overview
The profit calculator is now connected to Supabase database to fetch real sales and HPP (cost of goods sold) data instead of using estimated values.

## Connected Data Sources

### 1. Sales Table
**Table**: `sales`

**Columns Used**:
- `id` - Sale transaction ID
- `total_amount` - Total revenue amount (Rp)
- `hpp_total` - Total cost of goods (Rp) ✨ REAL DATA
- `bonus_amount` - Barista bonus amount (Rp)
- `created_at` - Transaction timestamp
- `payment_method` - Payment type (cash, qris)
- `outlet_id` - Which outlet made the sale

**Example Query**:
```sql
SELECT 
  id,
  total_amount,
  hpp_total,
  bonus_amount,
  created_at
FROM sales
WHERE outlet_id = 'outlet-123'
  AND created_at >= '2026-05-01'
  AND created_at <= '2026-05-31'
ORDER BY created_at DESC
```

### 2. Investor Assignments
**Table**: `investor_assignments`

**Columns Used**:
- `investor_id` - Investor user ID
- `outlet_id` - Assigned outlet ID
- `investment_amount` - Amount invested (Rp)
- `margin_percentage` - Profit sharing percentage (%)

## New SupabaseService Methods

### getSalesWithHpp()
Fetches all sales for a period with actual HPP data.

```dart
Future<List<Map<String, dynamic>>> getSalesWithHpp({
  required String outletId,
  required DateTime startDate,
  required DateTime endDate,
}) async
```

**Returns**:
```dart
[
  {
    'id': 'sale-123',
    'total_amount': 500000,      // Actual revenue
    'hpp_total': 150000,         // Actual cost
    'bonus_amount': 25000,
    'created_at': '2026-05-26T10:30:00Z',
    'payment_method': 'cash'
  },
  // ... more sales
]
```

**Usage Example**:
```dart
final sales = await supabaseService.getSalesWithHpp(
  outletId: 'outlet-456',
  startDate: DateTime(2026, 5, 1),
  endDate: DateTime(2026, 5, 31),
);
```

### getHppSummary()
Aggregates sales data for profit calculation (most used method).

```dart
Future<Map<String, dynamic>> getHppSummary({
  required String outletId,
  required DateTime startDate,
  required DateTime endDate,
}) async
```

**Returns**:
```dart
{
  'totalSales': 5000000,    // Sum of all sales for period
  'totalHpp': 1500000,      // Sum of all HPP for period
  'totalBonus': 250000,     // Sum of all bonuses for period
  'transactionCount': 45    // Number of transactions
}
```

**Usage Example**:
```dart
final hppSummary = await supabaseService.getHppSummary(
  outletId: 'outlet-456',
  startDate: DateTime(2026, 5, 1),
  endDate: DateTime(2026, 5, 31),
);
```

## Integration in Screens

### investor_revenue_screen.dart

**What Changed**:
- Fetches HPP data for each outlet along with revenue
- Replaced estimated HPP (amount × 0.3) with actual database values
- Uses period-based date ranges (daily, weekly, monthly)

**Flow**:
```
1. User selects period (daily/weekly/monthly)
2. _fetchRevenueForOutlet() - Gets revenue data
3. _fetchHppForOutlet() - Gets actual HPP summary
4. Combine both into outlet data
5. ProfitBreakdownCard uses actual HPP
```

**Code Pattern**:
```dart
Future<Map<String, dynamic>> _fetchHppForOutlet(String outletId) async {
  // Calculate date range based on _period
  final startDate = ... // daily/weekly/monthly start
  final endDate = ...   // daily/weekly/monthly end
  
  return _supabaseService.getHppSummary(
    outletId: outletId,
    startDate: startDate,
    endDate: endDate,
  );
}

// In ListView itemBuilder:
final hpp = (item['hpp'] as Map<String, dynamic>?) ?? {};
final actualHpp = (hpp['totalHpp'] as num?)?.toDouble() ?? 0.0;
final actualSales = (hpp['totalSales'] as num?)?.toDouble() ?? amount;

ProfitBreakdownCard(
  result: ProfitMarginCalculator.calculateFromAggregatedData(
    totalSales: actualSales,
    totalHpp: actualHpp,    // ✨ REAL DATA
    totalOmset: actualSales,
    investorPercentage: margin,
    isHoliday: false,
  ),
  outletName: outletName,
)
```

### investor_profile_screen.dart

**What Changed**:
- Fetches monthly HPP data for investment overview
- Shows more accurate profit based on actual monthly performance
- Falls back to estimates if no data available

**Flow**:
```
1. Fetch all investor's outlet assignments
2. For each outlet: fetch monthly HPP summary
3. Combine outlet data with HPP data
4. Display profit breakdown with real HPP
```

**Key Method**:
```dart
Future<Map<String, dynamic>> _fetchMonthlyHppForOutlet(String outletId) async {
  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month, 1);  // First of month
  final endDate = now;                                  // Today
  
  return _supabaseService.getHppSummary(
    outletId: outletId,
    startDate: startDate,
    endDate: endDate,
  );
}
```

### investor_report_outlet_screen.dart

**What Changed**:
- Fetches monthly HPP for detailed outlet reports
- Shows actual profitability of each invested outlet
- Historical data available for analysis

**Same Pattern**:
- Enriches outlet data with HPP summary
- Uses actual values in profit calculations
- Falls back to estimates if no sales data

## Data Accuracy

### Current Data Quality

| Screen | Period | Accuracy | Data Source |
|--------|--------|----------|-------------|
| Revenue | Daily/Weekly/Monthly | ✅ High (Real) | `sales.total_amount`, `sales.hpp_total` |
| Profile | Monthly to-date | ✅ High (Real) | Same as above |
| Report | Monthly to-date | ✅ High (Real) | Same as above |

### What Happens Without Sales Data
If an outlet has no sales in the period:
- `totalSales` = 0, `totalHpp` = 0
- Profit calculation returns 0 values
- No fallback to estimates (accurate representation)

### Fallback Logic
When HPP summary returns no data:
```dart
final actualHpp = (hpp['totalHpp'] as num?)?.toDouble() ?? estimate;
final actualSales = (hpp['totalSales'] as num?)?.toDouble() ?? estimate;
```

Examples:
```dart
// Revenue screen (estimate if no data)
final actualHpp = (hpp['totalHpp'] as num?)?.toDouble() ?? 0.0;
final actualSales = (hpp['totalSales'] as num?)?.toDouble() ?? amount;

// Profile screen (estimate if no data)
final actualHpp = (hpp['totalHpp'] as num?)?.toDouble() ?? 
                  investmentAmount * 0.6;
final actualSales = (hpp['totalSales'] as num?)?.toDouble() ?? 
                    investmentAmount * 2.0;
```

## Profit Calculation Formula (Now with Real Data)

```
Net Profit = Total Sales - (HPP + Bonus Barista + Meal Allowance)
  ├─ Total Sales: Real from sales.total_amount ✨
  ├─ HPP: Real from sales.hpp_total ✨
  ├─ Bonus: Calculated using bonus_calculator.dart
  └─ Meal: Determined by omset threshold

Investor Profit = Net Profit × (Investor % / 100)
Outlet Profit = Net Profit - Investor Profit
```

## Performance Considerations

### Database Queries
- Each outlet fetches its sales summary separately
- Period-based date filtering (indexed on outlet_id, created_at)
- Minimal columns selected (id, total_amount, hpp_total, bonus_amount)
- Results cached in widget state during period selection

### Async Loading
- FutureBuilder with loading indicator
- Error handling with fallback values
- Parallel fetching using Future.wait or sequential with enrich loop

### Memory
- Sales data aggregated at database level
- No individual sale records loaded into memory
- Only summary results stored in widget state

## Testing Data

To test with real data, ensure:

1. **Sales exist in database** for the outlet:
```sql
SELECT COUNT(*) FROM sales 
WHERE outlet_id = 'your-outlet-id' 
AND created_at >= NOW() - INTERVAL '30 days'
```

2. **HPP values are populated**:
```sql
SELECT 
  outlet_id,
  COUNT(*) as sales_count,
  SUM(total_amount) as total_revenue,
  SUM(hpp_total) as total_hpp
FROM sales
WHERE outlet_id = 'your-outlet-id'
GROUP BY outlet_id
```

3. **Investor assignments exist**:
```sql
SELECT * FROM investor_assignments
WHERE investor_id = 'your-investor-id'
```

## Debugging

### Enable Logging
Check console logs to see:
- What dates are being queried
- How many sales records found
- HPP summary values

### Common Issues

**Problem**: Profit always shows 0
- **Check**: Sales data exists in period
- **Check**: hpp_total is not NULL
- **Check**: Period selector is correct

**Problem**: Shows estimates instead of real data
- **Reason**: No sales found for that outlet/period
- **Expected**: Falls back to estimate safely
- **Solution**: Ensure sales were created for outlet

**Problem**: Data not updating
- **Reason**: Widget cached old future
- **Solution**: Pull-to-refresh or period selector change triggers new fetch

## Migration from Estimates to Real Data

**Before** (Estimated HPP):
```dart
totalHpp: amount * 0.3,  // 30% guess
```

**After** (Real HPP from Database):
```dart
final actualHpp = (hpp['totalHpp'] as num?)?.toDouble() ?? 0.0;
// Real data from sales.hpp_total
```

### Fallback Behavior
- If no sales in period: shows 0 (not estimated)
- If sales exist: uses real hpp_total value
- Safe and transparent calculation

## Future Enhancements

1. **Caching**: Cache HPP summaries for faster loading
2. **Trends**: Show HPP percentage trends over time
3. **Projections**: Project profit based on average HPP
4. **Comparisons**: Compare investor margins across outlets
5. **Exports**: Export profit reports with real data breakdown
