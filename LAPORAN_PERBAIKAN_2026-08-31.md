# LAPORAN PERBAIKAN — PapiKopi Mobile
**Tanggal:** 31 Agustus 2026
**Lingkup:** Investor screens (Home & Transaksi), bottom nav, limit transaksi GRATIS per cup
**Hasil:** APK release ter-build & ter-install di perangkat `90fcdb0b`

---

## 1. Ringkasan Eksekutif

Sesi ini merombak halaman investor (Home dan tab Transaksi baru), memperbaiki
navigasi bottom bar, merapikan tata letak sesuai mockup, menambahkan separator
tanggal pada laporan transaksi, serta mengubah dasar perhitungan limit
transaksi GRATIS dari basis jumlah transaksi menjadi basis **cup (item)**.

Semua perubahan tervalidasi `flutter analyze` (bersih, hanya info pre-existing)
dan di-deploy sebagai APK release ke perangkat pengguna.

---

## 2. Perubahan per Berkas

### 2.1 `lib/screens/investor/shared/investor_period_helper.dart` (BARU)
- **`InvestorPeriod`** — helper waktu UTC murni, konsisten dengan hari bisnis
  04:00 WIB (= 21:00 UTC hari sebelumnya):
  - `businessDayNow()` — hari bisnis saat ini
  - `businessDayUtc(day)` — jendela 1 hari bisnis (04:00–03:59 WIB)
  - `businessMonthUtc(day)` — jendela bulan kalender versi hari bisnis
  - `lastNDaysUtc(day, n)` — N hari bisnis terakhir (untuk "7 hari")
  - `isWeekend()`, `formatTimeWib()`, `rupiah()` (format `Rp 1.234.567`)
  - `formatDateWib()` — label tanggal Indonesia, mis. "Senin, 31 Agu 2026",
    dengan penanda "Hari ini —" / "Kemarin —"
- **`InvestorGerobak`** — model gerobak investor dari assignment map
  (menangani `outlet_name` maupun nested `outlets.name`)
- **`InvestorSummaryCard`** — widget kartu ringkasan; **direvisi** menjadi
  layout kompak satu baris: ikon lingkaran 52px kiri → judul + nilai →
  tombol Detil di kanan; panah tren hanya tampil bila nilai ≠ 0

### 2.2 `lib/screens/investor/investor_home_screen.dart` (DITULIS ULANG)
- Sapaan "Selamat Datang, {nama}! 👋" + subtitle (font 21px, line-height 1.25
  agar nama panjang tidak jatuh baris sendiri)
- Card **Pilih Gerobak**: label statis di atas dropdown, dropdown hanya
  menampilkan nama gerobak (menghilangkan panah ganda & label dobel)
- Tiga kartu ringkasan sesuai mockup 1:
  1. **Profit Bulan Ini** (biru) — Detil → Report Outlet
  2. **Profit Hari Ini** (hijau/merah sesuai tanda) — Detil → Report Outlet
  3. **Transaksi Hari Ini** (hijau) — Detil → Transaksi

### 2.3 `lib/screens/investor/investor_transactions_screen.dart` (BARU)
- **Laporan Transaksi** sesuai mockup 2: judul, card picker gerobak
  (full-width, konsisten dengan Home), picker periode
  (Hari ini / Kemarin / 7 Hari terakhir / Bulan ini)
- Tabel **JAM | MENU | QTY | PEMBAYARAN | JUMLAH**:
  - JAM = jam WIB dari `formatTimeWib`
  - PEMBAYARAN = chip QRIS (biru) / Cash (hijau) / GRATIS (oranye)
  - flex kolom disesuaikan (PEMBAYARAN flex 4) + font header 11px agar
    tidak patah baris; chip dipadatkan agar "GRATIS" tidak wrap
- **Separator tanggal**: baris pita biru muda setiap ganti hari (WIB) —
  efektif untuk periode 7 hari / sebulan; label ramah
  "Hari ini — Senin, 31 Agu 2026"
- **Fix bug revenue**: item pada transaksi GRATIS kini bernilai **Rp 0**
  (sebelumnya harga item tetap terhitung → inflasi pendapatan)
- Perbaikan struktur: build method part 2, label periode "Kemarin" yang
  semula ekspresi rusak (`today.month - 0 == 0 ? ... _dayBefore ...`)
  diganti perhitungan mundur 1 hari yang benar

### 2.4 `lib/screens/investor/investor_screen.dart`
- Bottom nav menjadi: **Home | Transaksi | Report Outlet | Penarikan**
- Tab 1 diganti `InvestorRevenueScreen` → `InvestorTransactionsScreen`
- `InvestorHomeScreen` menerima `onNavigate` (kontrak index: 1 = Transaksi,
  2 = Report Outlet) — **diverifikasi ketiga tombol Detil mengarah benar**

### 2.5 `lib/services/supabase_service.dart`
- **`getMonthlyGratisStats()`** dirombak ke basis CUP:
  - Query `sales` + embedded `sale_items(quantity)` untuk bulan berjalan
  - Mengembalikan `total_cups` (seluruh cup terjual) dan `gratis_cups`
    (cup dari transaksi GRATIS, dihitung dari quantity)
  - Bug fix: `monthEnd` sebelumnya jam 00:00 hari terakhir sehingga
    transaksi hari terakhir bulan tidak ikut terhitung → kini 23:59:59

### 2.6 `lib/widgets/checkout_modal.dart` (pembatasan di POS)
- Limit GRATIS kini berbasis cup: blokir bila
  `(gratis_cups + cup di keranjang) / total_cups × 100 ≥ 3%`
- **Proyeksi keranjang**: cup di keranjang ikut dihitung saat memilih GRATIS
  → menutup celah menumpuk banyak cup dalam 1 transaksi gratis
- Pesan baru: *"Gratis: 12/480 cup (2.5% dari 3% limit)"* /
  *"⚠️ Limit gratis 3% sudah tercapai! (15 dari 480 cup = 3.1%)"*

### 2.7 `lib/screens/barista/transaction_history_screen.dart`
- Cek limit saat edit transaksi ikut diubah ke basis cup (tanpa proyeksi
  keranjang), format pesan sama dengan checkout modal

- Profit investor = (sales − HPP − bonus barista [nilai DB bila > 0, else
  `ProfitMarginCalculator`]) × margin% investor
- Perbaikan bug: method `_investorProfit` sebelumnya terpotong struktur

---

## 3. Aturan Limit GRATIS (Keadaan Akhir)

| Aspek | Nilai |
|---|---|
| Basis | **Cup / item** (bukan jumlah transaksi, bukan omzet) |
| Batas | **3%** dari total cup terjual per outlet |
| Periode | Bulan kalender berjalan (tgl 1 00:00 — akhir bulan 23:59, waktu lokal) |
| Proyeksi checkout | Ya — cup di keranjang ditambahkan ke gratis_cups sebelum cek |
| Blokir | Hard block: dialog, checkout GRATIS ditolak |
| Contoh | 20 cup gratis dari 1.200 total = 1,7% → lolos; 38 dari 1.200 = 3,2% → diblokir |

**Keterbatasan yang diketahui (belum diubah, disepakati selesai):**
- Tanpa floor/minimum: di awal bulan dengan penjualan sangat kecil
  (mis. total 10 cup), 1 cup gratis pun terhitung 10% → diblokir.
  1 cup baru lolos setelah total ≥ 34 cup.
- Periode masih kalender lokal, belum hari bisnis 04:00 WIB
  (inkonsisten dengan laporan investor).
- Persen 3% hardcoded di dua tempat (checkout modal & transaction history).

---

## 4. Validasi & Deployment

- `flutter analyze lib/screens/investor` → bersih (2 info pre-existing di
  `investor_screen.dart`: use_build_context_synchronously)
- `flutter analyze` pada service/checkout/transaction-history → tanpa error baru
- `flutter build apk --release` → **app-release.apk (79,5 MB)** sukses
- `adb install -r` → Success di perangkat `90fcdb0b`, aplikasi diluncurkan
- Total 5 siklus build+install selama sesi

## 5. Saran Tindak Lanjut (opsional)

1. Tambah floor minimum cup gratis (mis. 3 cup) untuk mengatasi kasus awal bulan.
2. Seragamkan periode limit ke hari bisnis 04:00 WIB (`InvestorPeriod`).
3. Pindahkan konstanta 3% ke konfigurasi/tabel settings agar bisa diubah
   tanpa build ulang.
4. Hapus `investor_revenue_screen.dart` yang sudah tidak dirujuk nav.
5. Gunakan `InvestorPeriod` juga pada caller `getHppSummary` lain bila masih
   memakai batas kalender.

  (body `netProfit` dan `_onSelectGerobak` terorphan di luar class) — dirapikan
