import 'package:flutter_test/flutter_test.dart';
import 'package:papikopi/services/supabase_service.dart';
import 'package:papikopi/utils/timezone_formatter.dart';

void main() {
  group('SupabaseService business-day resolution', () {
    final service = SupabaseService();

    test('counts returns for the selected business day after timezone skew', () {
      final result = SupabaseService.mapReturnedQuantitiesForBusinessDay(
        rows: [
          {'product_id': 'prod-1', 'return_date': DateTime(2026, 7, 5, 22, 30)},
          {'product_id': 'prod-1', 'return_date': DateTime(2026, 7, 6, 21, 15)},
          {'product_id': 'prod-2', 'return_date': DateTime(2026, 7, 6, 20, 59)},
          {'product_id': 'prod-2', 'return_date': DateTime(2026, 7, 7, 0, 15)},
        ],
        businessDayDate: DateTime(2026, 7, 6),
        businessDayStartHour: 21,
      );

      expect(result['prod-1'], 1);
      expect(result['prod-2'], 1);
    });

    test('builds the current business-day range for allocation validation', () {
      final result = SupabaseService.buildBusinessDayRange(
        DateTime(2026, 7, 6, 0, 0),
        4,
      );

      expect(result['start'], DateTime.utc(2026, 7, 5, 4, 0, 0));
      expect(result['end'], DateTime.utc(2026, 7, 6, 3, 59, 59, 999));
    });

    test('uses the previous day when the current time is before the business-day start hour', () {
      final result = service.resolveBusinessDayDate(
        DateTime(2026, 7, 6, 10, 30),
        businessDayStartHour: 4,
        now: DateTime(2026, 7, 6, 3, 0),
      );

      expect(result, DateTime(2026, 7, 5));
    });

    test('keeps a date-only picker value unchanged', () {
      final result = service.resolveBusinessDayDate(
        DateTime(2026, 7, 6),
        businessDayStartHour: 4,
        now: DateTime(2026, 7, 6, 3, 0),
      );

      expect(result, DateTime(2026, 7, 6));
    });

    test('normalizes checkout dates through the shared POS helper', () {
      final result = service.resolveBusinessDayDateForCheckout(
        DateTime(2026, 7, 6, 3, 30),
        businessDayStartHour: 4,
        now: DateTime(2026, 7, 6, 3, 30),
      );

      expect(result, DateTime(2026, 7, 5, 4, 0, 0));
    });

    test('uses the current time for checkout timestamps', () {
      final now = DateTime.parse('2026-07-15T10:42:00+07:00');
      final result = service.resolveCheckoutTimestamp(now: now);

      expect(result, DateTime.parse('2026-07-15T03:42:00Z'));
    });

    test('parses timezone-naive timestamps as UTC for consistent display', () {
      final result = parseTimestampAssumeUTC('2026-07-15T10:42:00');

      expect(result, DateTime.utc(2026, 7, 15, 10, 42));
    });

    test('formats timestamps in Jakarta time for mobile history screens', () {
      final result = formatTimestampForJakartaDisplay(
        DateTime.utc(2026, 7, 15, 3, 42),
      );

      expect(result, '10:42');
    });

    test('coerces malformed timestamp fragments into a valid UTC instant', () {
      final result = parseTimestampAssumeUTC('2026-07-15T05:52:03\$1Z');

      expect(result, DateTime.utc(2026, 7, 15, 5, 52, 3));
    });

  });
}
