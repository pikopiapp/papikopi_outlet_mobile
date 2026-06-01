# Investor Screen Structure

## Overview
Halaman Investor telah direfactor menjadi struktur modular yang lebih terorganisir dengan sistem kalkulasi profit investor terintegrasi.

## Folder Structure
```
lib/screens/investor/
├── investor_screen.dart              # Main container screen dengan navigation
├── investor_profile_screen.dart       # Profile & outlet investment overview
├── investor_revenue_screen.dart       # Revenue analytics & breakdown
├── investor_report_outlet_screen.dart # Outlet summary report
├── investor_notification_screen.dart  # Transactions, announcements, chat
├── README.md                          # Dokumentasi struktur
└── INTEGRATION_SUMMARY.md             # Dokumentasi integrasi profit calculator
```

## File Descriptions

### investor_screen.dart
Container utama yang mengelola:
- Bottom navigation bar dengan 3 tabs + message icon
- Navigation antara sub-screens
- Supabase initialization
- AppBar dengan logout & settings

Tabs (Bottom Navigation):
1. Home (Profile)
2. Revenue
3. Report Outlet

Message/Notification Screen:
- Accessed via mail icon button in appbar
- Shows transactions, announcements, and chat

### investor_profile_screen.dart
Menampilkan:
- Greeting untuk investor
- Summary cards (Total investasi, Rata-rata profit, Jumlah outlet)
- List outlet yang diinvestasikan dengan detail
- **NEW**: Profit breakdown per outlet (expandable card)
- Tombol seed test data untuk development

Data Source: Outlet investment data from Supabase
Profit Calculation: Estimated based on investment amount

### investor_revenue_screen.dart
Menampilkan:
- Period selector (Daily, Weekly, Monthly)
- Summary cards (Total revenue, Investor share, Transaction count)
- Per-outlet revenue breakdown dengan margin details
- **NEW**: Profit breakdown per outlet dengan detail biaya (expandable card)

Data Source: Real revenue data from database
Profit Calculation: Based on actual revenue amounts with estimated HPP (30%)

### investor_report_outlet_screen.dart
Menampilkan:
- Summary cards (Total outlet, Active outlet, Total investment)
- List outlet dengan investment & margin info
- **NEW**: Profit breakdown per outlet (expandable card)

Data Source: Outlet master data
Profit Calculation: Estimated based on investment amount (higher multiplier for mature outlets)

### investor_notification_screen.dart
Menampilkan:
- Tab Transaksi: Recent transactions from invested outlets
- Tab Pengumuman: System announcements with detail modal
- Tab Chat: Private messages with sender info

## Profit Calculation System

Setiap outlet card sekarang menampilkan profit breakdown expandable card yang menunjukkan:

```
Profit Breakdown Details:
├── Penjualan (Sales Amount)
├── HPP (Cost of Goods)
├── Bonus Barista
├── Uang Makan (Meal Allowance)
├── Profit Bersih (Net Profit)
├── Profit Investor (Investor's share)
├── Profit Outlet (Outlet's share)
└── Percentage Summary (Margin, HPP %, Expenses %)
```

### Calculation Formula
```
Net Profit = Total Sales - (HPP + Bonus Barista + Meal Allowance)
Investor Profit = Net Profit × (Investor Percentage / 100)
Outlet Profit = Net Profit - Investor Profit
```

### Data Accuracy by Screen
| Screen | Data Type | Accuracy |
|--------|-----------|----------|
| Revenue | Actual revenue | High (real data) |
| Profile | Estimated sales | Medium (estimated) |
| Report | Estimated sales | Medium (estimated) |

For actual profit calculations, the system uses estimated HPP (30-75% of sales depending on outlet) until real HPP data is available from ingredients table.

### Future Improvements
- Integrate real HPP data from `products_ingredients` table
- Use actual bonus calculations from `bonus_calculator.dart`
- Add meal allowance from employee records
- Historical profit tracking and trends
- Status badge untuk outlet (active/inactive)

### investor_notification_screen.dart
Menampilkan 3 tabs:
1. **Transaksi** - Recent transactions dari outlet
2. **Pengumuman** - System announcements dengan detail modal
3. **Chat** - Private messages dengan sender info

## Key Components

### Reusable Widgets
- `_PillButton` - Custom tab/filter button
- `_InfoBox` - Information display box
- `_ErrorBox` - Error display box (di investor_screen)

## Import Changes
Semua imports telah diupdate dari relative paths:
- `../` → `../../` (dari investor folder ke lib)
- New imports untuk sub-screens di investor_screen.dart

## Development Notes
- Setiap screen adalah StatefulWidget untuk state management
- FutureBuilder digunakan untuk async data fetching
- Share common utility functions di masing-masing screen
- Format currency dan UI styling sudah konsisten
