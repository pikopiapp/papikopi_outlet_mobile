# Investor Screen Structure

## Overview
Halaman Investor telah direfactor menjadi struktur modular yang lebih terorganisir dengan sistem kalkulasi profit investor terintegrasi.

## Folder Structure
```
lib/screens/investor/
├── investor_screen.dart               # Main container screen dengan navigation
├── investor_home_screen.dart          # Profit bulanan/harian + detil profit
├── investor_transactions_screen.dart  # Riwayat transaksi gerobak
├── investor_report_outlet_screen.dart # Outlet summary report
├── investor_withdrawal_screen.dart    # Pengajuan penarikan
├── investor_profile_screen.dart       # Profile & outlet investment overview
├── investor_notification_screen.dart  # Transactions, announcements, chat
├── investor_settings_screen.dart
├── shared/                            # Widget, mixin, helper periode bersama
├── README.md                          # Dokumentasi struktur
└── INTEGRATION_SUMMARY.md             # Dokumentasi integrasi profit calculator
```

## File Descriptions

### investor_screen.dart
Container utama yang mengelola:
- Bottom navigation bar dengan 4 tabs + message icon
- Navigation antara sub-screens
- Supabase initialization
- AppBar dengan logout & settings

Tabs (Bottom Navigation):
1. Home (Profit)
2. Transaksi
3. Report Outlet
4. Penarikan

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

### investor_home_screen.dart
Tombol **Detil** pada ringkasan profit bulanan dan harian membuka rincian:
- Omset dan laba dari ringkasan penjualan pada periode tersebut
- Bonus barista dan uang makan dari data serah terima kas outlet
- Profit share sesuai persentase investor

### investor_report_outlet_screen.dart
Menampilkan:
- Summary cards (Total outlet, Active outlet, Total investment)
- List outlet dengan investment & margin info
- **NEW**: Profit breakdown per outlet (expandable card)

Data Source: `getHppSummary` per outlet (HPP, bonus barista, uang makan) untuk rentang hari bisnis yang dipilih

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

### Data Source
Home dan Report Outlet memakai `getHppSummary` (HPP, bonus barista, uang makan asli dari database) dengan batas hari bisnis 04:00 WIB dari `shared/investor_period_helper.dart`.

### Future Improvements
- Historical profit tracking and trends
- Status badge untuk outlet (active/inactive)

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
