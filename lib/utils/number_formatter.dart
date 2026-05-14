/// Utility class untuk memformat angka dengan separator ribuan
class NumberFormatter {
  /// Format angka dengan separator ribuan (e.g., 1.000.000)
  /// 
  /// Contoh:
  /// - 1000 -> "1.000"
  /// - 1000000 -> "1.000.000"
  /// - 50000 -> "50.000"
  static String formatCurrency(double value) {
    final intValue = value.toInt();
    return intValue.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
  }

  /// Format harga lengkap dengan "Rp" prefix
  /// 
  /// Contoh:
  /// - 1000 -> "Rp1.000"
  /// - 1000000 -> "Rp1.000.000"
  static String formatRupiah(double value) {
    return 'Rp${formatCurrency(value)}';
  }

  /// Format harga dengan separator (untuk text yang sudah ada "Rp" prefix)
  /// Gunakan ini untuk compatibility dengan kode yang sudah ada
  /// 
  /// Contoh:
  /// - 1000 -> "1.000"
  /// - 50000 -> "50.000"
  static String formatPrice(double value) {
    return formatCurrency(value);
  }
}
