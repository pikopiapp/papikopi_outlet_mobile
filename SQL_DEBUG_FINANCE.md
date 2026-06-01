# SQL Debug Queries for Finance Screen Zero Revenue Issue

Run these queries in Supabase SQL Editor to verify data exists.

## 1. Check Outlet Details and Business Day Start Hour
```sql
SELECT id, name, business_day_start_hour, timezone, created_at
FROM outlets
WHERE id = 'YOUR_OUTLET_ID_HERE'
LIMIT 1;
```

**Expected Result:** Should show your outlet with business_day_start_hour (default 4) and timezone if set.

---

## 2. Check Today's Sales (Exact Date Range Query)
Replace `YOUR_OUTLET_ID_HERE` and adjust `TODAY_DATE` as needed:

```sql
-- This mimics EXACTLY what getRevenueData() does
SELECT 
  id,
  outlet_id,
  payment_method,
  total_amount,
  created_at,
  created_at AT TIME ZONE 'Asia/Jakarta' as created_at_jakarta,
  DATE(created_at AT TIME ZONE 'Asia/Jakarta') as sale_date
FROM sales
WHERE outlet_id = 'YOUR_OUTLET_ID_HERE'
  AND DATE(created_at AT TIME ZONE 'Asia/Jakarta') = CURRENT_DATE
ORDER BY created_at DESC
LIMIT 20;
```

**Expected Result:** Shows all sales from today (in Asia/Jakarta timezone).

---

## 3. Check Last 30 Days Sales
```sql
SELECT 
  DATE(created_at AT TIME ZONE 'Asia/Jakarta') as sale_date,
  COUNT(*) as sale_count,
  SUM(total_amount) as total_revenue,
  payment_method
FROM sales
WHERE outlet_id = 'YOUR_OUTLET_ID_HERE'
  AND created_at AT TIME ZONE 'Asia/Jakarta' >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at AT TIME ZONE 'Asia/Jakarta'), payment_method
ORDER BY sale_date DESC;
```

**Expected Result:** Shows revenue breakdown by date for last 30 days.

---

## 4. Check Business Day Range (if business_day_start_hour != 4)
```sql
-- For business_day_start_hour = 21 example:
-- "Today" = May 27 at 00:00 to 20:59:59 UTC?
-- Or May 26 21:00 UTC to May 27 20:59:59 UTC?

SELECT 
  created_at,
  created_at AT TIME ZONE 'UTC' as created_at_utc,
  created_at AT TIME ZONE 'Asia/Jakarta' as created_at_jakarta,
  EXTRACT(HOUR FROM created_at) as hour_utc,
  EXTRACT(HOUR FROM created_at AT TIME ZONE 'Asia/Jakarta') as hour_jakarta
FROM sales
WHERE outlet_id = 'YOUR_OUTLET_ID_HERE'
ORDER BY created_at DESC
LIMIT 30;
```

**Purpose:** Check timezone alignment between stored created_at and display timezone.

---

## 5. Check if Sales Table Has Any Data
```sql
SELECT COUNT(*) as total_sales
FROM sales;

SELECT DISTINCT outlet_id
FROM sales
LIMIT 10;
```

**Expected Result:** Should show total sales count and list of outlets with sales.

---

## Critical Issues to Check

### Issue A: Timezone Mismatch
- **Problem:** `created_at` stored as UTC, but query assumes local timezone
- **Check:** Compare UTC vs Asia/Jakarta times in query #4 results
- **Fix:** May need to convert query to use proper timezone

### Issue B: Business Day Start Hour Logic
- **Problem:** If start_hour=21, the date range calculation might be wrong
- **Example Issue:**
  - May 27 selected → Query searches May 26 21:00 to May 27 20:59:59
  - But if user is in timezone ahead of UTC (like Asia/Jakarta +7), the times might be off

### Issue C: Date Format Mismatch  
- **Problem:** Flutter DateTime might be in different timezone than database
- **Check:** Run query #4 and look at created_at values
- **Fix:** May need to use UTC explicitly or adjust timezone

---

## Common Solutions

### Solution 1: Force UTC Timezone
If created_at is stored in UTC, query should be:
```sql
WHERE outlet_id = 'YOUR_OUTLET_ID'
  AND created_at >= '2024-05-27T00:00:00Z'
  AND created_at < '2024-05-28T00:00:00Z'
```

### Solution 2: Use Asia/Jakarta Timezone
```sql
WHERE outlet_id = 'YOUR_OUTLET_ID'
  AND created_at AT TIME ZONE 'Asia/Jakarta' >= '2024-05-27 00:00:00'
  AND created_at AT TIME ZONE 'Asia/Jakarta' < '2024-05-28 00:00:00'
```

### Solution 3: Show Raw DateTime from App
Modify getRevenueData() to print exact ISO strings being used in query.
Already added in latest debug version - check console for:
```
DEBUG getRevenueData: dailyStart=... (ISO8601)
DEBUG getRevenueData: dailyEndTime=... (ISO8601)
```

---

## What the Console Debug Prints Will Tell You

From `flutter run -v` console, look for:
```
DEBUG finance_screen: Outlet ID set to: <OUTLET_ID>
DEBUG getRevenueData: businessDayStartHour=<NUMBER>
DEBUG getRevenueData: dailyStart=<ISO_TIME> 
DEBUG getRevenueData: dailyEndTime=<ISO_TIME>
DEBUG getRevenueData: Daily response count=<NUMBER>
```

If `Daily response count=0` and you know sales exist, then:
1. The date range is wrong
2. The outlet_id is wrong
3. The timezone is wrong

---

## Step-by-Step Debugging

1. **Run app:** `cd papikopi_mobile && flutter run -v`
2. **Open Finance Screen** and watch console for DEBUG messages
3. **Copy the datetime values** from console (dailyStart, dailyEndTime)
4. **Run Query #2** above with those exact same datetime ranges
5. **Compare results:**
   - If SQL returns data but app shows 0 → rendering issue
   - If SQL returns 0 data → date range wrong
   - If app doesn't show debug prints → outlet_id not set

---

## Last Resort: Manual Date Range Check

If all else fails, run this to see actual sales data and timestamp:
```sql
SELECT 
  id,
  outlet_id,
  total_amount,
  payment_method,
  created_at::text as created_at_text,
  EXTRACT(YEAR FROM created_at) as year,
  EXTRACT(MONTH FROM created_at) as month,
  EXTRACT(DAY FROM created_at) as day,
  EXTRACT(HOUR FROM created_at) as hour,
  EXTRACT(MINUTE FROM created_at) as minute,
  EXTRACT(SECOND FROM created_at) as second
FROM sales
WHERE outlet_id = 'YOUR_OUTLET_ID_HERE'
ORDER BY created_at DESC
LIMIT 20;
```

This will show exact breakdown of timestamps so you can manually check if they fall within the query range.
