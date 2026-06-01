# Supabase Integration - Visual Architecture

## 1. Database Query Architecture

```
┌───────────────────────────────────────────────────┐
│           SUPABASE DATABASE                       │
│  ╔─────────────────────────────────────────────╗ │
│  ║ SALES TABLE                                 ║ │
│  ║ ┌─────────────────────────────────────────┐ ║ │
│  ║ │ id              │ UUID                  │ ║ │
│  ║ │ outlet_id       │ FK to outlets         │ ║ │
│  ║ │ total_amount    │ Revenue (Rp)          │ ║ │
│  ║ │ hpp_total       │ Cost (Rp) ✨ REAL    │ ║ │
│  ║ │ bonus_amount    │ Bonus (Rp)            │ ║ │
│  ║ │ created_at      │ Timestamp [Indexed]   │ ║ │
│  ║ │ payment_method  │ cash|qris             │ ║ │
│  ║ └─────────────────────────────────────────┘ ║ │
│  ╚─────────────────────────────────────────────╚ │
│                                                   │
│  ╔─────────────────────────────────────────────╗ │
│  ║ INVESTOR_ASSIGNMENTS TABLE                  ║ │
│  ║ ┌─────────────────────────────────────────┐ ║ │
│  ║ │ investor_id       │ FK to users         │ ║ │
│  ║ │ outlet_id         │ FK to outlets       │ ║ │
│  ║ │ investment_amount │ Amount (Rp)        │ ║ │
│  ║ │ margin_percentage │ Investor % (0-100) │ ║ │
│  ║ └─────────────────────────────────────────┘ ║ │
│  ╚─────────────────────────────────────────────╚ │
└───────────────────────────────────────────────────┘
```

## 2. Query Flow Diagram

```
START: User Opens Investor Screen
    │
    ├─→ [Query 1] Get Investor Outlets
    │   SELECT * FROM investor_assignments
    │   WHERE investor_id = current_user.id
    │   └─→ Returns: List of outlet_id, investment, margin%
    │
    └─→ [Query 2] For Each Outlet:
        │
        ├─→ Fetch Revenue Data (existing)
        │   SELECT SUM(total_amount) FROM sales
        │   WHERE outlet_id = ? 
        │   AND created_at IN [date_range]
        │   └─→ Returns: Daily/weekly/monthly revenue
        │
        └─→ Fetch HPP Summary (NEW) ✨
            SELECT 
              SUM(total_amount) as totalSales,
              SUM(hpp_total) as totalHpp,      ← REAL DATA
              SUM(bonus_amount) as totalBonus,
              COUNT(*) as transactionCount
            FROM sales
            WHERE outlet_id = ? 
            AND created_at IN [date_range]
            └─→ Returns: Aggregated cost data

COMBINE: Outlet data + HPP data → Display in UI
```

## 3. Data Transformation Pipeline

```
┌─────────────────────────────────────────────────────┐
│ 1. SUPABASE QUERY RESULT                            │
├─────────────────────────────────────────────────────┤
│ {                                                    │
│   "totalSales": 5000000,        // Rp 5 juta        │
│   "totalHpp": 1500000,          // Rp 1.5 juta      │
│   "totalBonus": 250000,         // Rp 250k          │
│   "transactionCount": 45        // 45 transactions  │
│ }                                                    │
└─────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│ 2. PASS TO PROFIT CALCULATOR                        │
├─────────────────────────────────────────────────────┤
│ ProfitMarginCalculator.calculateFromAggregatedData( │
│   totalSales: 5000000,                              │
│   totalHpp: 1500000,            ✨ REAL DATA       │
│   totalOmset: 5000000,                              │
│   investorPercentage: 15,       // 15% margin      │
│   isHoliday: false                                  │
│ )                                                   │
└─────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│ 3. CALCULATION ENGINE                               │
├─────────────────────────────────────────────────────┤
│ Step 1: Calculate expenses                          │
│  ├─ bonusBarista = 250000  (from DB)                │
│  ├─ mealAllowance = 34000  (omset ≥ 300k)          │
│  └─ totalExpenses = 284000                          │
│                                                      │
│ Step 2: Calculate net profit                        │
│  ├─ netProfit = 5M - (1.5M + 0.284M)               │
│  └─ netProfit = 3.216M                              │
│                                                      │
│ Step 3: Split profit                                │
│  ├─ investorProfit = 3.216M × 15% = 482,400        │
│  ├─ outletProfit = 3.216M × 85% = 2,733,600        │
│  └─ investorPercentage = 15%                        │
│                                                      │
│ Step 4: Calculate percentages                       │
│  ├─ marginPercentage = 3.216M / 5M = 64.32%        │
│  ├─ hppPercentage = 1.5M / 5M = 30%                │
│  └─ expensesPercentage = 0.284M / 5M = 5.68%       │
└─────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│ 4. RESULT OBJECT                                    │
├─────────────────────────────────────────────────────┤
│ ProfitCalculationResult {                           │
│   totalSales: 5000000,                              │
│   totalHpp: 1500000,              ✨ REAL          │
│   bonusBarista: 250000,                             │
│   mealAllowance: 34000,                             │
│   totalExpenses: 284000,                            │
│   netProfit: 3216000,                               │
│   investorPercentage: 15,                           │
│   investorProfit: 482400,                           │
│   outletProfit: 2733600,                            │
│   marginPercentage: 64.32,                          │
│   hppPercentage: 30,                                │
│   expensesPercentage: 5.68,                         │
│   investorProfitPercentage: 15                      │
│ }                                                    │
└─────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│ 5. DISPLAY IN UI                                    │
├─────────────────────────────────────────────────────┤
│ ProfitBreakdownCard                                 │
│ ┌─────────────────────────────────────────────────┐ │
│ │ ▼ Profit Detail - Outlet ABC                    │ │
│ │   Investor Profit: Rp 482,400                   │ │
│ ├─────────────────────────────────────────────────┤ │
│ │ Penjualan           Rp 5,000,000               │ │
│ │ HPP                 Rp 1,500,000   ✨ REAL     │ │
│ │ Bonus Barista       Rp 250,000                 │ │
│ │ Uang Makan          Rp 34,000                  │ │
│ │ ─────────────────────────────────              │ │
│ │ Profit Bersih       Rp 3,216,000               │ │
│ │ Profit Investor     Rp 482,400 (15%)           │ │
│ │ Profit Outlet       Rp 2,733,600 (85%)         │ │
│ │ ─────────────────────────────────              │ │
│ │ Margin: 64.32% │ HPP: 30% │ Exp: 5.68%       │ │
│ └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

## 4. Screen Integration Pattern

```
┌──────────────────────────────────────────────────────┐
│ INVESTOR SCREENS ARCHITECTURE                        │
├──────────────────────────────────────────────────────┤
│                                                       │
│  ┌────────────────────────────────────────────────┐  │
│  │ investor_revenue_screen.dart                   │  │
│  ├────────────────────────────────────────────────┤  │
│  │ Methods:                                       │  │
│  │  ├─ _resolveInvestorOutlets()                 │  │
│  │  ├─ _fetchRevenueForOutlet()                  │  │
│  │  └─ _fetchHppForOutlet() ✨ NEW              │  │
│  │                                                │  │
│  │ Data Flow:                                     │  │
│  │  1. Load outlets                               │  │
│  │  2. For each outlet:                           │  │
│  │     ├─ Fetch revenue (daily/weekly/monthly)   │  │
│  │     └─ Fetch HPP for same period              │  │
│  │  3. Combine data                               │  │
│  │  4. Calculate profit with REAL HPP            │  │
│  │  5. Display in cards                           │  │
│  └────────────────────────────────────────────────┘  │
│                                                       │
│  ┌────────────────────────────────────────────────┐  │
│  │ investor_profile_screen.dart                   │  │
│  ├────────────────────────────────────────────────┤  │
│  │ Methods:                                       │  │
│  │  ├─ _resolveInvestorOutlets()                 │  │
│  │  └─ _fetchMonthlyHppForOutlet() ✨ NEW       │  │
│  │                                                │  │
│  │ Data Flow:                                     │  │
│  │  1. Load outlets                               │  │
│  │  2. For each outlet:                           │  │
│  │     └─ Fetch monthly HPP summary               │  │
│  │  3. Enrich outlet data                         │  │
│  │  4. Display with real profit                   │  │
│  └────────────────────────────────────────────────┘  │
│                                                       │
│  ┌────────────────────────────────────────────────┐  │
│  │ investor_report_outlet_screen.dart             │  │
│  ├────────────────────────────────────────────────┤  │
│  │ Methods:                                       │  │
│  │  ├─ _resolveInvestorOutlets()                 │  │
│  │  └─ _fetchMonthlyHppForOutlet() ✨ NEW       │  │
│  │                                                │  │
│  │ Data Flow:                                     │  │
│  │  1. Load outlets                               │  │
│  │  2. For each outlet:                           │  │
│  │     └─ Fetch monthly HPP                       │  │
│  │  3. Enrich outlet data                         │  │
│  │  4. Display detailed report                    │  │
│  └────────────────────────────────────────────────┘  │
│                                                       │
└──────────────────────────────────────────────────────┘
          │                    │                    │
          └────────┬───────────┴────────┬───────────┘
                   │                    │
                   ▼                    ▼
            ┌─────────────────────────────────┐
            │ profit_breakdown_widget.dart    │
            │ ├─ ProfitBreakdownCard         │
            │ └─ Displays real profit data   │
            └─────────────────────────────────┘
```

## 5. Date Range Calculation

```
DAILY PERIOD
└─ Calculate: Yesterday 21:00 to Today 20:59
   ├─ Start Date = TODAY - 1 day at 21:00
   ├─ End Date = TODAY at 20:59
   └─ Query: WHERE created_at BETWEEN start AND end
   
   Example (May 26):
   ├─ Start: May 25 21:00
   ├─ End: May 26 20:59
   └─ Result: Today's business day sales

WEEKLY PERIOD
└─ Calculate: Last 7 days from today
   ├─ Start Date = TODAY - 7 days
   ├─ End Date = TODAY
   └─ Query: WHERE created_at BETWEEN start AND end
   
   Example (May 26):
   ├─ Start: May 19 00:00
   ├─ End: May 26 23:59
   └─ Result: 7 days of sales

MONTHLY PERIOD
└─ Calculate: 1st of month to today
   ├─ Start Date = 1st of MONTH
   ├─ End Date = TODAY
   └─ Query: WHERE created_at BETWEEN start AND end
   
   Example (May 26):
   ├─ Start: May 1 00:00
   ├─ End: May 26 23:59
   └─ Result: May month-to-date
```

## 6. Async Data Loading Timeline

```
Time ──────────────────────────────────────────────────────>

T0:  User opens screen
     │
     ├─> FutureBuilder starts
     │   └─> _resolveInvestorOutlets() begins
     │       └─> Query: Get investor outlets (~50ms)
     │           └─> Returns: [outlet1, outlet2, ...]
     │
     ├─> Display: Loading spinner
     │
T1:  Outlets loaded (~100ms)
     │
     ├─> For each outlet, parallel fetch:
     │   ├─> _fetchRevenueForOutlet()
     │   │   └─> Query: SUM(total_amount) for period
     │   │
     │   └─> _fetchHppForOutlet() ✨
     │       └─> Query: SUM(hpp_total) for period
     │
     ├─> Display: Still loading...
     │
T2:  All data loaded (~400-500ms total)
     │
     ├─> Combine outlet + revenue + hpp data
     ├─> Calculate profit for each outlet
     └─> Display: ProfitBreakdownCard with REAL data

T3:  User changes period (daily→weekly)
     │
     ├─> FutureBuilder triggers new future
     ├─> Recalculate date ranges
     ├─> Fetch new HPP for new period
     ├─> Display: Shows old data while loading
     └─> Update: New data shows in ~200ms
```

## 7. Error Handling Flow

```
┌─────────────────────────────────────────────┐
│ SUPABASE QUERY EXECUTION                    │
└──────────────────────┬──────────────────────┘
                       │
              ┌────────┴────────┐
              │                 │
              ▼                 ▼
        ✅ SUCCESS         ❌ ERROR
        │                  │
        ├─ Return data     ├─ Log error
        │                  ├─ Return {}
        │                  └─ Trigger fallback
        │
        ▼
  ┌──────────────────┐
  │ USE REAL DATA    │
  │ totalHpp = from  │
  │ database         │
  └──────────────────┘

        OR

  ┌──────────────────┐
  │ USE FALLBACK     │
  │ totalHpp =       │
  │ estimate or 0    │
  └──────────────────┘
```

## 8. Profit Calculation Verification

```
INPUT (From Database)
├─ total_amount = Rp 500,000
├─ hpp_total = Rp 150,000
├─ bonus_amount = Rp 25,000
└─ margin_percentage = 15%

CALCULATION STEPS
├─ Step 1: bonusBarista = 25,000 (from DB)
├─ Step 2: mealAllowance = 34,000 (or 25,000)
├─ Step 3: netProfit = 500k - (150k + 25k + 34k) = 291k
├─ Step 4: investorProfit = 291k × 15% = 43,650
├─ Step 5: outletProfit = 291k × 85% = 247,350
├─ Step 6: margins calculated
└─ Step 7: Result formatted

OUTPUT (For Display)
├─ Sales: Rp 500,000
├─ HPP: Rp 150,000           ✨ REAL
├─ Bonus: Rp 25,000
├─ Meal: Rp 34,000
├─ Net Profit: Rp 291,000
├─ Investor: Rp 43,650 (15%)
├─ Outlet: Rp 247,350 (85%)
└─ Margin: 58.2%

VERIFICATION
├─ Net = 500k - (150k + 25k + 34k) ✓ = 291k
├─ Inv = 291k × 0.15 ✓ = 43,650
├─ Out = 291k × 0.85 ✓ = 247,350
└─ Sum = 43,650 + 247,350 ✓ = 291k
```

---

This architecture ensures real data flows from Supabase through calculation engines to UI display with proper error handling at each step.
