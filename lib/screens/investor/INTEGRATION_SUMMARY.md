# Profit Calculator Integration Summary

## Completed Integration Tasks

### 1. **investor_revenue_screen.dart** ✅
- **Location**: Per-outlet revenue cards (ListView.builder starting at line 301)
- **What was added**: `ProfitBreakdownCard` widget below existing revenue details
- **Calculation Logic**:
  ```dart
  ProfitMarginCalculator.calculateFromAggregatedData(
    totalSales: amount,           // Revenue amount for the period
    totalHpp: amount * 0.3,        // Estimated HPP (30% of sales)
    totalOmset: amount,
    investorPercentage: margin,    // From outlet's margin_percentage
    isHoliday: false,
  )
  ```
- **Display**: ExpansionTile showing detailed profit breakdown with cost breakdown and investor/outlet profit split
- **Data Source**: Uses period-based revenue data (daily/weekly/monthly selector)

### 2. **investor_profile_screen.dart** ✅
- **Location**: Outlet investment cards (ListView.builder starting at line 248)
- **What was added**: `ProfitBreakdownCard` widget below investment details
- **Calculation Logic**:
  ```dart
  ProfitMarginCalculator.calculateFromAggregatedData(
    totalSales: investmentAmount * 2.0,    // Estimated sales based on investment
    totalHpp: investmentAmount * 0.6,      // Estimated HPP (60% of investment)
    totalOmset: investmentAmount * 2.0,
    investorPercentage: marginPercentage,  // From outlet's margin_percentage
    isHoliday: false,
  )
  ```
- **Display**: Expandable profit detail card showing HPP, bonus, meal allowance, and profit split
- **Use Case**: Investment portfolio overview with estimated profit potential

### 3. **investor_report_outlet_screen.dart** ✅
- **Location**: Outlet report cards (ListView.builder starting at line 236)
- **What was added**: `ProfitBreakdownCard` widget below investment details
- **Calculation Logic**:
  ```dart
  ProfitMarginCalculator.calculateFromAggregatedData(
    totalSales: investmentAmount * 2.5,    // Estimated sales
    totalHpp: investmentAmount * 0.75,     // Estimated HPP (75% of investment)
    totalOmset: investmentAmount * 2.5,
    investorPercentage: marginPercentage,  // From outlet's margin_percentage
    isHoliday: false,
  )
  ```
- **Display**: Expandable profit detail card with comprehensive breakdown
- **Use Case**: Detailed outlet performance reporting

## Data Flow Architecture

```
Per-Outlet Card Data (from Supabase)
├── outlet_name
├── outlet_type
├── investment_amount / revenue amount
├── margin_percentage
└── status

         ↓

ProfitMarginCalculator.calculateFromAggregatedData()
├── Input: totalSales, totalHpp, investorPercentage
├── Process: Calculate net profit → investor profit split
└── Output: ProfitCalculationResult object

         ↓

ProfitBreakdownCard (Display Widget)
├── ExpansionTile Header (compact view)
└── Content: Detailed breakdown + percentages + profit split
```

## Widget Integration Points

### All Three Screens Use:
1. **Import**: `profit_margin_calculator.dart` and `profit_breakdown_widget.dart`
2. **Widget**: `ProfitBreakdownCard`
3. **Method**: `ProfitMarginCalculator.calculateFromAggregatedData()`

### Display Hierarchy in Each Card:
```
Card (outlet/revenue data)
├── Header row (outlet name, status)
├── Divider
├── Investment/Revenue details (Row of 3-4 columns)
├── SizedBox (12pt spacing)
└── ProfitBreakdownCard (NEW)
    ├── ExpansionTile header (profit summary)
    ├── Sales amount
    ├── HPP cost
    ├── Bonus Barista
    ├── Meal Allowance
    ├── Net Profit (total)
    ├── Investor Profit (% split)
    ├── Outlet Profit (% split)
    └── 3-box percentage summary (Margin, HPP, Expenses)
```

## Estimation Parameters Used

| Screen | Total Sales | HPP | Rationale |
|--------|------------|-----|-----------|
| Revenue | actual amount | amount × 0.3 | Revenue data is actual, HPP estimated at 30% |
| Profile | investment × 2.0 | investment × 0.6 | Using investment as baseline for estimation |
| Report | investment × 2.5 | investment × 0.75 | Higher sales multiplier for mature outlets |

## Testing Recommendations

1. **Expand/Collapse**: Click on each outlet card to expand profit breakdown
2. **Verify Calculations**: Check that profit math is correct:
   - Net Profit = Sales - (HPP + Bonus + Meal)
   - Investor Share = Net Profit × (margin% / 100)
   - Outlet Share = Net Profit - Investor Share
3. **Visual Consistency**: Ensure cards display correctly across screen sizes
4. **Data Accuracy**: Validate against actual sales/revenue data when available

## Future Enhancements

- Replace estimated HPP with actual data from `products_ingredients` table
- Add actual bonus calculation using `bonus_calculator.dart`
- Implement real meal allowance data
- Add date range filtering for historical profit analysis
- Export profit reports to PDF/CSV
- Add profit trend charts and comparisons
