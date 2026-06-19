import '../services/supabase_service.dart';

// Weekend helper
bool _isWeekend(DateTime date) =>
    date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

/// Holiday detection that relies only on the Supabase `custom_holidays` cache.
///
/// Synchronous helpers use the in-memory cache loaded by `SupabaseService`.

bool isHoliday(DateTime date) {
  // Weekend always considered a holiday
  if (_isWeekend(date)) return true;
  return SupabaseService().isHolidaySync(date);
}

String getHolidayDescription(DateTime date) {
  final desc = SupabaseService().getCustomHolidayDescriptionSync(date);
  if (desc != null && desc.isNotEmpty) return desc;
  if (date.weekday == DateTime.saturday) return 'Hari Sabtu';
  if (date.weekday == DateTime.sunday) return 'Hari Minggu';
  return '';
}

/// Async: get custom holidays map from DB (refresh optional)
Future<Map<String, String>> getCustomHolidaysFromDb({
  bool refresh = false,
}) async {
  try {
    final svc = SupabaseService();
    return await svc.getCustomHolidays(refresh: refresh);
  } catch (e) {
    return {};
  }
}
