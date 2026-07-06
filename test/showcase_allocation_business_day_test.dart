import 'package:flutter_test/flutter_test.dart';
import 'package:papikopi/helpers/business_day_helper.dart';

void main() {
  group('business day range selection', () {
    test('uses the selected calendar day for a date-only picker value', () {
      final result = buildBusinessDayRangeForSelection(
        DateTime(2026, 7, 5),
        4,
      );

      expect(result['start'], DateTime(2026, 7, 5, 4, 0, 0));
      expect(result['end'], DateTime(2026, 7, 6, 3, 59, 59, 999));
    });
  });
}
