# Profit Margin Calculator Documentation

## Overview
Utility untuk menghitung dan menampilkan profit investor dengan breakdown komponen cost.

## Files Created

### 1. `lib/utils/profit_margin_calculator.dart`
**Classes:**
- `ProfitCalculationResult` - Model hasil perhitungan
- `ProfitMarginCalculator` - Utility class untuk calculation
- `CurrencyFormatter` - Helper formatting currency
- `ProfitBreakdown` - Breakdown untuk detail view

**Models:**
```dart
ProfitCalculationResult {
  totalSales         // Total penjualan
  totalHpp           // Total HPP
  bonusBarista       // Total bonus barista
  mealAllowance      // Total uang makan
  totalExpenses      // bonus + meal allowance
  netProfit          // sales - (hpp + expenses)
  investorPercentage // % profit investor (dari outlet setting)
  investorProfit     // net profit x investor %
  outletProfit       // net profit x (100 - investor %)
  
  // Computed properties
  marginPercentage       // net profit / sales %
  hppPercentage         // hpp / sales %
  expensesPercentage    // expenses / sales %
  investorProfitPercentage // investor profit / sales %
}
```

### 2. `lib/widgets/profit_breakdown_widget.dart`
**Widgets:**
- `ProfitBreakdownCard` - Expandable card dengan detail breakdown
- `ProfitSummaryCard` - Summary card untuk dashboard
- `_DetailRow` - Helper widget untuk menampilkan row detail
- `_PercentageBox` - Helper widget untuk menampilkan percentage box

## Usage Examples

### Calculate from Single Transaction
```dart
final result = ProfitMarginCalculator.calculateFromTransaction(
  saleAmount: 500000,
  hpp: 200000,
  omset: 500000,
  investorPercentage: 20,
  isHoliday: false,
);
// result.investorProfit → profit untuk investor
// result.outletProfit → profit untuk outlet
```

### Calculate from Aggregated Data
```dart
final result = ProfitMarginCalculator.calculateFromAggregatedData(
  totalSales: 5000000,
  totalHpp: 2000000,
  totalOmset: 5000000,
  investorPercentage: 20,
  isHoliday: false,
);
```

### Display in UI
```dart
// Show detailed breakdown
ProfitBreakdownCard(
  result: profitResult,
  outletName: 'Outlet A',
)

// Show summary
ProfitSummaryCard(
  totalProfit: profitResult.netProfit,
  investorProfit: profitResult.investorProfit,
  totalSales: profitResult.totalSales,
  title: 'Profit Summary',
)
```

### Format Currency
```dart
CurrencyFormatter.format(500000)          // Rp 500.000
CurrencyFormatter.formatShort(5000000)    // 5.0 jt
CurrencyFormatter.formatPercentage(15.5)  // 15.50%
```

## Calculation Formula

```
Profit Bersih = Sales - (HPP + Bonus Barista + Uang Makan)

Profit Investor = Profit Bersih × (Investor % / 100)
Profit Outlet = Profit Bersih × ((100 - Investor %) / 100)

Margin % = (Profit Bersih / Sales) × 100
HPP % = (Total HPP / Sales) × 100
Expenses % = (Bonus + Uang Makan) / Sales × 100
```

## Integration Points

### For Investor Revenue Screen
- Add import untuk `profit_margin_calculator`
- Call `ProfitMarginCalculator.calculateFromAggregatedData()` dengan data outlet
- Display `ProfitBreakdownCard` atau `ProfitSummaryCard`

### For Investor Report Screen
- Show profit breakdown per outlet
- Compare investor share vs outlet share

### For Dashboard
- Use `ProfitSummaryCard` untuk quick overview
- Show total investor profit across outlets

## Data Requirements

To calculate profit, you need:
1. **Sales Data** - total amount dari tabel sales
2. **HPP Data** - dari tabel sales (sudah ada di backend)
3. **Omset** - untuk menghitung bonus barista & meal allowance
4. **Investor %** - dari investor_assignments table (margin_percentage)
5. **isHoliday** - untuk bonus calculation

## Notes
- Bonus dan meal allowance di-calculate menggunakan `bonus_calculator.dart`
- Format currency menggunakan locale Indonesia (id_ID)
- Semua nilai dalam Rupiah
