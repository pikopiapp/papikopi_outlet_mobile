/// Business Day Helper Functions
/// Handles date calculations based on outlet's business_day_start_hour setting

/// Calculate which business day a given DateTime belongs to
/// 
/// Example:
/// - DateTime: 2026-05-10 03:00, startHour: 4 => 2026-05-09 (previous day)
/// - DateTime: 2026-05-10 05:00, startHour: 4 => 2026-05-10 (current day)
DateTime getBusinessDayDate(DateTime timestamp, int businessDayStartHour) {
  if (timestamp.hour < businessDayStartHour) {
    // Before business day start, so it belongs to previous day's business day
    return DateTime(timestamp.year, timestamp.month, timestamp.day - 1);
  }
  // On or after business day start, so it belongs to this day's business day
  return DateTime(timestamp.year, timestamp.month, timestamp.day);
}

/// Get business day start time (full timestamp at start hour)
/// 
/// Example: 
/// - Date: 2026-05-10, startHour: 4 => 2026-05-10 04:00:00
DateTime getBusinessDayStart(DateTime date, int businessDayStartHour) {
  return DateTime(date.year, date.month, date.day, businessDayStartHour, 0, 0);
}

/// Get business day end time (23:59:59 of next day - 1 millisecond)
/// 
/// Example:
/// - Date: 2026-05-10, startHour: 4 => 2026-05-11 03:59:59.999
DateTime getBusinessDayEnd(DateTime date, int businessDayStartHour) {
  final nextDay = DateTime(date.year, date.month, date.day)
      .add(const Duration(days: 1));
  final nextDayStart = DateTime(nextDay.year, nextDay.month, nextDay.day, 
      businessDayStartHour, 0, 0);
  return nextDayStart.subtract(const Duration(milliseconds: 1));
}

/// Get business day range (start and end timestamps)
/// 
/// Returns: {start: start_timestamp, end: end_timestamp}
/// 
/// Example:
/// - Date: 2026-05-10, startHour: 4
/// - start: 2026-05-10 04:00:00
/// - end: 2026-05-11 03:59:59.999
Map<String, DateTime> getBusinessDayRange(DateTime date, int businessDayStartHour) {
  final start = getBusinessDayStart(date, businessDayStartHour);
  final end = getBusinessDayEnd(date, businessDayStartHour);
  return {'start': start, 'end': end};
}

/// Check if timestamp is within a business day
bool isInBusinessDay(DateTime timestamp, DateTime businessDay, int businessDayStartHour) {
  final range = getBusinessDayRange(businessDay, businessDayStartHour);
  return timestamp.isAfter(range['start']!) && 
         timestamp.isBefore(range['end']!.add(const Duration(milliseconds: 1)));
}

/// Format business day for display
/// 
/// Example: 2026-05-10 => "10 May 2026"
String formatBusinessDay(DateTime date) {
  final months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return '${date.day} ${months[date.month]} ${date.year}';
}

/// Get business day start hour description
/// 
/// Example: 4 => "04:00 Pagi (Termasuk Penjualan Shift Malam)"
String getBusinessDayDescription(int hour) {
  if (hour == 0) {
    return '00:00 (Tengah Malam - Hari Kalender)';
  }
  if (hour == 4) {
    return '04:00 Pagi (Termasuk Penjualan Shift Malam)';
  }

  final hourStr = hour.toString().padLeft(2, '0');
  final ampm = hour >= 12 ? 'Sore' : 'Pagi';
  final displayHour = hour > 12 ? hour - 12 : hour;

  return '$hourStr:00 ($displayHour:00 $ampm)';
}
