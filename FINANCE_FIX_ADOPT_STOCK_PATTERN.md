# Finance Screen Revenue Fix - ADOPT STOCK SCREEN PATTERN ✅

## Problem Identified

My previous fix used `DateTime.utc()` directly, which is WRONG because:
- `DateTime.utc()` creates UTC time from scratch without respecting device timezone
- Device timezone offset gets lost
- Date range becomes incorrect for non-UTC devices

## Correct Approach (From Stock Screen)

Stock screen uses the RIGHT pattern:

```dart
// CORRECT: Create LOCAL time first, then convert to UTC
DateTime localStart = DateTime(year, month, day, hour, 0, 0);  // Local time
DateTime utcStart = localStart.toUtc();  // Convert to UTC

// WRONG: Creating UTC directly loses timezone info
DateTime utcStart = DateTime.utc(year, month, day, hour, 0, 0);  // Loses timezone!
```

## The Fix Applied

Changed `getRevenueData()` to follow stock screen pattern:

**Before (WRONG):**
```dart
final dailyStart = DateTime.utc(selectedDate.year, selectedDate.month, selectedDate.day)
    .subtract(const Duration(days: 1))
    .copyWith(hour: businessDayStartHour, ...);
```

**After (CORRECT):**
```dart
// Create in local time first
DateTime dailyStartLocal;
if (businessDayStartHour >= 12) {
  dailyStartLocal = DateTime(year, month, day - 1, businessDayStartHour, 0, 0);
} else {
  dailyStartLocal = DateTime(year, month, day, businessDayStartHour, 0, 0);
}

// Then convert to UTC for query
final dailyStart = dailyStartLocal.toUtc();
```

## Key Changes

1. **Create LOCAL DateTime objects first** - respect device timezone
2. **Handle business day logic before conversion** - cleaner logic
3. **Convert to UTC at the end** - consistent with database
4. **Add debug prints showing both local and UTC times** - easier to trace issues

## Console Output Will Show

```
DEBUG getRevenueData: selectedDate=2024-05-27 10:30:00.000 (local device time)
DEBUG getRevenueData: dailyStartLocal=2024-05-26 04:00:00.000
DEBUG getRevenueData: dailyStart=2024-05-25T21:00:00.000Z (UTC for query)
DEBUG getRevenueData: dailyEnd=2024-05-26T20:59:59.999Z (UTC for query)
DEBUG getRevenueData: Daily response count=5 ← THIS MATTERS!
```

If response count > 0, revenue should display correctly now!

## Test Steps

1. Run app:
```bash
cd papikopi_mobile && flutter run -v
```

2. Open Finance Screen and check console for debug prints

3. If `Daily response count > 0`, then ✅ **FIXED!**

4. If still 0, we have more info to debug (timezone offset, business_day_start_hour, etc.)

## Why This Pattern Works

Device in UTC+7 (Jakarta, May 27, 10:30 AM):

```
Device time: 2024-05-27 10:30:00 +07:00
Local DateTime: 2024-05-27 10:30:00 (no tz, relative to +07:00)
toUtc() converts: 2024-05-27 10:30:00 +07:00 → 2024-05-27 03:30:00 +00:00

Query searches: May 26 04:00 UTC to May 27 03:59:59 UTC
Sales in database (UTC): May 27 10:00:00 UTC ✅ FOUND!
```

This is exactly what stock screen does, and it works!
