/// Holiday detection utility
/// Detects weekends (Sabtu/Minggu) and Indonesian national holidays

/// Indonesian national holidays for 2025-2026
/// Format: [month, day]
const List<List<int>> indonesianHolidays2025 = [
  // 2025
  [1, 1],   // Tahun Baru (New Year)
  [2, 19],  // Isra dan Mi'raj
  [3, 31],  // Hari Raya Idul Fitri (estimated)
  [4, 1],   // Hari Raya Idul Fitri (estimated)
  [4, 2],   // Hari Raya Idul Fitri (estimated)
  [4, 3],   // Hari Raya Idul Fitri (estimated)
  [4, 14],  // Hari Raya Idul Adha (estimated)
  [5, 1],   // Hari Buruh
  [5, 14],  // Kenaikan Isa Almasih
  [5, 19],  // Hari Vesak
  [6, 1],   // Lebaran (Tahun Baru Hijriah)
  [6, 17],  // Hari Lahir Pancasila
  [8, 17],  // Hari Kemerdekaan
  [9, 16],  // Maulid Nabi Muhammad
  [12, 25], // Hari Raya Kristen
  [12, 26], // Hari Libur Bersama
];

const List<List<int>> indonesianHolidays2026 = [
  // 2026
  [1, 1],   // Tahun Baru (New Year)
  [2, 8],   // Isra dan Mi'raj
  [3, 20],  // Hari Raya Idul Fitri (estimated)
  [3, 21],  // Hari Raya Idul Fitri (estimated)
  [3, 22],  // Hari Raya Idul Fitri (estimated)
  [3, 23],  // Hari Raya Idul Fitri (estimated)
  [4, 3],   // Hari Raya Idul Adha (estimated)
  [4, 23],  // Tahun Baru Hijriah
  [5, 1],   // Hari Buruh
  [5, 14],  // Kenaikan Isa Almasih
  [5, 4],   // Hari Vesak
  [6, 1],   // Pancasila Day (optional)
  [6, 17],  // Hari Lahir Pancasila
  [8, 17],  // Hari Kemerdekaan
  [9, 5],   // Maulid Nabi Muhammad
  [12, 25], // Hari Raya Kristen
  [12, 26], // Hari Libur Bersama
];

/// Check if a date is a weekend (Saturday or Sunday)
bool isWeekend(DateTime date) {
  return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
}

/// Check if a date is an Indonesian national holiday
bool isIndonesianHoliday(DateTime date) {
  final holidays = date.year == 2025 ? indonesianHolidays2025 : indonesianHolidays2026;
  
  for (final holiday in holidays) {
    if (date.month == holiday[0] && date.day == holiday[1]) {
      return true;
    }
  }
  return false;
}

/// Check if a date is a holiday (weekend or national holiday)
bool isHoliday(DateTime date) {
  return isWeekend(date) || isIndonesianHoliday(date);
}

/// Get holiday description
String getHolidayDescription(DateTime date) {
  if (date.weekday == DateTime.saturday) {
    return 'Hari Sabtu';
  }
  if (date.weekday == DateTime.sunday) {
    return 'Hari Minggu';
  }
  
  // Check for specific holidays
  if (date.month == 1 && date.day == 1) return 'Tahun Baru';
  if (date.month == 5 && date.day == 1) return 'Hari Buruh';
  if (date.month == 8 && date.day == 17) return 'Hari Kemerdekaan';
  if (date.month == 12 && date.day == 25) return 'Natal';
  if (date.month == 6 && date.day == 17) return 'Hari Lahir Pancasila';
  
  return 'Hari Libur Nasional';
}
