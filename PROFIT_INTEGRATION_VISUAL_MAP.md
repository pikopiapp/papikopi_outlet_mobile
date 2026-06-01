# Investor Screens - Profit Calculator Integration Visual Map

## Application Flow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         INVESTOR_SCREEN                         │
│                  (Main Navigation Container)                    │
└──────────────────────┬──────────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┬──────────────┐
        │              │              │              │
   ┌────▼─────┐  ┌────▼─────┐  ┌────▼─────┐  ┌────▼─────┐
   │  Profile  │  │ Revenue  │  │  Report  │  │   Message │
   │  Screen   │  │  Screen  │  │  Outlet  │  │  Screen  │
   └───────────┘  └─────────┘  └─────────┘  └──────────┘
        │             │             │             │
     [TAB-1]       [TAB-2]      [TAB-3]      [APPBAR-ICON]
```

## Per-Screen Profit Integration Points

### Screen 1: investor_profile_screen.dart
```
┌─────────────────────────────────────────────┐
│ Outlet Investment Card                      │
├─────────────────────────────────────────────┤
│ Outlet Name            [Status Badge]       │
│ Outlet Type                                 │
├─────────────────────────────────────────────┤
│ Investasi: Rp 50M  │  Profit: 15%          │
│                                             │
│ ╔═════════════════════════════════════════╗ │
│ ║ ▼ Profit Detail - Outlet ABC            ║ │
│ ║   Investor Profit: Rp 2.5M              ║ │ ◄── ProfitBreakdownCard
│ ╠═════════════════════════════════════════╣ │     (Expandable)
│ ║ Penjualan           Rp 50M              ║ │
│ ║ HPP                 Rp 15M              ║ │
│ ║ Bonus Barista       Rp 2.5M             ║ │
│ ║ Uang Makan          Rp 1.2M             ║ │
│ ║ ─────────────────────────────           ║ │
│ ║ Profit Bersih       Rp 31.3M            ║ │
│ ║ ─────────────────────────────           ║ │
│ ║ Profit Investor     Rp 4.7M  (15%)      ║ │
│ ║ Profit Outlet       Rp 26.6M (85%)      ║ │
│ ║ ─────────────────────────────           ║ │
│ ║ Margin:62.6% │ HPP:30% │ Exp:7.4%      ║ │
│ ╚═════════════════════════════════════════╝ │
└─────────────────────────────────────────────┘
```

### Screen 2: investor_revenue_screen.dart
```
┌─────────────────────────────────────────────┐
│ Per-Outlet Revenue Card                     │
├─────────────────────────────────────────────┤
│ Outlet DEF                                  │
│ Period: Daily ▼  Selector with monthly stats│
├─────────────────────────────────────────────┤
│ Revenue:Rp 10M │ Investor Share:Rp 1.5M    │
│ Margin:15% │ Transaksi:45                  │
│                                             │
│ ╔═════════════════════════════════════════╗ │
│ ║ ▼ Profit Detail - Outlet DEF            ║ │
│ ║   Investor Profit: Rp 1.5M              ║ │ ◄── ProfitBreakdownCard
│ ╠═════════════════════════════════════════╣ │     (Expandable)
│ ║ [Detailed profit breakdown]             ║ │
│ ╚═════════════════════════════════════════╝ │
└─────────────────────────────────────────────┘
```

### Screen 3: investor_report_outlet_screen.dart
```
┌─────────────────────────────────────────────┐
│ Outlet Report Card                          │
├─────────────────────────────────────────────┤
│ Outlet GHI      [Status: ACTIVE]            │
│ Kiosk                                       │
├─────────────────────────────────────────────┤
│ Investasi:Rp 30M │ Margin Profit:20%       │
│                                             │
│ ╔═════════════════════════════════════════╗ │
│ ║ ▼ Profit Detail - Outlet GHI            ║ │
│ ║   Investor Profit: Rp 3M                ║ │ ◄── ProfitBreakdownCard
│ ╠═════════════════════════════════════════╣ │     (Expandable)
│ ║ [Detailed profit breakdown]             ║ │
│ ╚═════════════════════════════════════════╝ │
└─────────────────────────────────────────────┘
```

## Data Flow Diagram

```
┌──────────────────────────────────────────────────────────┐
│                   SUPABASE DATABASE                       │
│  ┌─────────────┐  ┌─────────────┐  ┌────────────────┐  │
│  │  Outlets    │  │ Investments │  │ Revenue Data   │  │
│  │  (Name,Type)│  │ (Amount %)  │  │ (Sales, HPP)   │  │
│  └─────────────┘  └─────────────┘  └────────────────┘  │
└──────────────────────┬───────────────────────────────────┘
                       │
              ┌────────▼────────┐
              │ INVESTOR SCREENS│
              │  (Profile,      │
              │   Revenue,      │
              │   Report)       │
              └────────┬────────┘
                       │
        ┌──────────────▼────────────────┐
        │ FOR EACH OUTLET:              │
        │ ┌──────────────────────────┐  │
        │ │ Extract outlet data:     │  │
        │ │ • name, type, status     │  │
        │ │ • investment amount OR   │  │
        │ │ • revenue amount         │  │
        │ │ • margin percentage      │  │
        │ └──────────────────────────┘  │
        └──────────────┬─────────────────┘
                       │
        ┌──────────────▼──────────────────────────────┐
        │ ProfitMarginCalculator                     │
        │ .calculateFromAggregatedData(...)          │
        │ ├─ Input: sales, hpp, margin               │
        │ ├─ Formula: profit = sales - (hpp+bonus+meal)
        │ ├─ Split: investor × margin%              │
        │ └─ Output: ProfitCalculationResult         │
        └──────────────┬──────────────────────────────┘
                       │
        ┌──────────────▼──────────────────────────┐
        │ ProfitBreakdownCard Widget              │
        │ ┌──────────────────────────────────┐   │
        │ │ Compact Header (Click to expand) │   │
        │ └──────────────────────────────────┘   │
        │ ┌──────────────────────────────────┐   │
        │ │ Expanded Detail View              │   │
        │ │ ├─ Sales breakdown               │   │
        │ │ ├─ Cost breakdown (HPP, bonus)  │   │
        │ │ ├─ Net Profit calculation        │   │
        │ │ ├─ Investor/Outlet split        │   │
        │ │ └─ Percentage summary boxes     │   │
        │ └──────────────────────────────────┘   │
        └────────────────────────────────────────┘
```

## Widget Component Hierarchy

```
investor_profile_screen.dart
├── FutureBuilder (async data loading)
│   └── ListView.builder (iterate outlets)
│       └── Card
│           └── Column
│               ├── Header Row
│               │   ├── Outlet Name + Type
│               │   └── Status Badge
│               ├── Divider
│               ├── Investment Details Row
│               │   ├── Investment Amount
│               │   └── Margin %
│               └── ProfitBreakdownCard ✨ NEW
│                   ├── ExpansionTile
│                   │   ├── Title: "Profit Detail - [Name]"
│                   │   └── Trailing: Investor Profit
│                   └── Children (when expanded)
│                       ├── Sales Container
│                       │   └── DetailRows
│                       ├── Costs Container
│                       │   └── DetailRows
│                       ├── Net Profit Container
│                       │   └── Investor/Outlet Split
│                       └── Percentage Summary
│                           └── 3 PercentageBoxes
```

## Color Coding System

```
REVENUE/SALES:          Blue (#2196F3)
┌─────────────────┐
│ Penjualan       │
│ Rp 50 Juta      │
└─────────────────┘

COSTS/EXPENSES:         Red (#F44336)
┌─────────────────┐
│ HPP             │
│ Rp 15 Juta      │
│ Bonus Barista   │
│ Rp 2.5 Juta     │
└─────────────────┘

NET PROFIT/INVESTOR:    Green (#4CAF50)
┌─────────────────┐
│ Profit Bersih   │
│ Rp 31.3 Juta    │
│ Profit Investor │
│ Rp 4.7 Juta     │
└─────────────────┘

OUTLET PROFIT:          Amber (#FFC107)
┌─────────────────┐
│ Profit Outlet   │
│ Rp 26.6 Juta    │
└─────────────────┘
```

## Calculation Pipeline Example

```
INPUT: Outlet ABC Revenue Card
├─ outletName: "Outlet ABC"
├─ amount: 50,000,000  (Rp 50M)
└─ margin: 15

          ↓

STEP 1: Calculate HPP (estimated)
├─ totalHpp = 50,000,000 × 0.3 = 15,000,000

          ↓

STEP 2: Calculate Net Profit
├─ bonusBarista ≈ 2,500,000
├─ mealAllowance ≈ 1,200,000
├─ netProfit = 50M - (15M + 2.5M + 1.2M) = 31.3M

          ↓

STEP 3: Split Profit
├─ investorProfit = 31.3M × (15/100) = 4.7M
├─ outletProfit = 31.3M - 4.7M = 26.6M

          ↓

OUTPUT: ProfitCalculationResult
├─ totalSales: 50,000,000
├─ totalHpp: 15,000,000
├─ bonusBarista: 2,500,000
├─ mealAllowance: 1,200,000
├─ netProfit: 31,300,000
├─ investorProfit: 4,700,000
├─ outletProfit: 26,600,000
├─ marginPercentage: 62.6%
├─ hppPercentage: 30.0%
├─ expensesPercentage: 7.4%
└─ investorProfitPercentage: 15.0%

          ↓

DISPLAY: ProfitBreakdownCard (Expandable)
┌─────────────────────────────┐
│ ▼ Profit Detail - Outlet ABC │
│   Investor Profit: Rp 4.7M   │
├─────────────────────────────┤
│ Penjualan       Rp 50M       │
│ HPP             Rp 15M       │
│ Bonus Barista   Rp 2.5M      │
│ Uang Makan      Rp 1.2M      │
│ ─────────────────────────    │
│ Profit Bersih   Rp 31.3M     │
│ Profit Investor Rp 4.7M (15%)│
│ Profit Outlet   Rp 26.6M (85%)
│ ─────────────────────────    │
│ M: 62.6% │ HPP: 30% │ Exp:7.4%
└─────────────────────────────┘
```

## File Dependencies

```
investor_profile_screen.dart
├─ imports: profit_margin_calculator.dart
├─ imports: profit_breakdown_widget.dart
├─ uses: ProfitMarginCalculator class
├─ displays: ProfitBreakdownCard widget
└─ triggered: In ListView.builder for each outlet

investor_revenue_screen.dart
├─ imports: profit_margin_calculator.dart
├─ imports: profit_breakdown_widget.dart
├─ uses: ProfitMarginCalculator class
├─ displays: ProfitBreakdownCard widget
└─ triggered: In ListView.builder for each outlet

investor_report_outlet_screen.dart
├─ imports: profit_margin_calculator.dart
├─ imports: profit_breakdown_widget.dart
├─ uses: ProfitMarginCalculator class
├─ displays: ProfitBreakdownCard widget
└─ triggered: In ListView.builder for each outlet

profit_breakdown_widget.dart
├─ imports: profit_margin_calculator.dart
├─ uses: ProfitCalculationResult model
├─ uses: CurrencyFormatter utility
└─ displays: Detailed profit breakdown

profit_margin_calculator.dart
├─ classes: ProfitCalculationResult
├─ classes: ProfitMarginCalculator
├─ classes: ProfitBreakdown
├─ classes: CurrencyFormatter
└─ exports: All calculation logic
```

## Testing Checklist

```
Visual Elements:
☐ Cards render correctly on all screen sizes
☐ Expansion tiles expand/collapse smoothly
☐ Colors are correct (blue, red, green, amber)
☐ Text is readable and well-formatted
☐ Gradients display correctly

Calculations:
☐ Net Profit = Sales - (HPP + Bonus + Meal) ✓
☐ Investor % = Investor Share / Net Profit × 100 ✓
☐ Outlet % = 100 - Investor % ✓
☐ Margins calculated correctly ✓
☐ Currency formatting shows Rp prefix ✓

Interactions:
☐ Click outlet card → expands profit detail
☐ Click again → collapses profit detail
☐ Smooth animation on expand/collapse
☐ All tabs navigate correctly
☐ Message icon opens notification screen

Compilation:
☐ All imports resolve correctly ✓
☐ No compilation errors ✓
☐ No unused imports warnings
☐ Type checking passes ✓
```

---

**Status**: ✅ INTEGRATION COMPLETE - ALL VISUAL COMPONENTS READY
