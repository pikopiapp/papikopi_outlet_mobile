import 'package:flutter/material.dart';
import '../../../theme/thema.dart';

/// Helper waktu untuk halaman investor.
///
/// Semua jendela waktu dihitung sebagai UTC murni (DB menyimpan UTC,
/// jam buka bisnis 04:00 WIB = 21:00 UTC hari sebelumnya).
class InvestorPeriod {
  /// Tanggal "hari bisnis" saat ini (jika sekarang < 04:00 WIB,
  /// berarti masih hari bisnis kemarin).
  static DateTime businessDayNow() {
    final nowWib = DateTime.now().toUtc().add(const Duration(hours: 7));
    if (nowWib.hour < 4) {
      return nowWib.subtract(const Duration(days: 1));
    }
    return nowWib;
  }

  /// Jendela UTC untuk satu hari bisnis WIB [day]:
  /// 04:00 WIB s/d 03:59 WIB keesokan hari.
  static ({DateTime start, DateTime end}) businessDayUtc(DateTime day) {
    final start = DateTime.utc(
      day.year,
      day.month,
      day.day,
      4,
      0,
      0,
    ).subtract(const Duration(hours: 7));
    final end = DateTime.utc(
      day.year,
      day.month,
      day.day + 1,
      4,
      0,
      0,
    ).subtract(const Duration(hours: 7));
    return (start: start, end: end);
  }

  /// Jendela UTC untuk bulan kalender (versi hari bisnis):
  /// dari 04:00 WIB tanggal 1 s/d 03:59 WIB awal bulan berikutnya.
  static ({DateTime start, DateTime end}) businessMonthUtc(DateTime day) {
    final start = DateTime.utc(
      day.year,
      day.month,
      1,
      4,
      0,
      0,
    ).subtract(const Duration(hours: 7));
    final end = DateTime.utc(
      day.year,
      day.month + 1,
      1,
      4,
      0,
      0,
    ).subtract(const Duration(hours: 7));
    return (start: start, end: end);
  }

  /// Jendela UTC untuk bulan kalender WIB, dari tengah malam tanggal 1
  /// hingga tengah malam tanggal 1 bulan berikutnya.
  static ({DateTime start, DateTime end}) calendarMonthUtc(DateTime day) {
    final start = DateTime.utc(
      day.year,
      day.month,
      1,
    ).subtract(const Duration(hours: 7));
    final end = DateTime.utc(
      day.year,
      day.month + 1,
      1,
    ).subtract(const Duration(hours: 7));
    return (start: start, end: end);
  }

  /// UTC window for an inclusive WIB calendar-date range.
  static ({DateTime start, DateTime end}) calendarDateRangeUtc(
    DateTime startDate,
    DateTime endDate,
  ) {
    final start = DateTime.utc(
      startDate.year,
      startDate.month,
      startDate.day,
    ).subtract(const Duration(hours: 7));
    final endExclusive = DateTime.utc(
      endDate.year,
      endDate.month,
      endDate.day + 1,
    ).subtract(const Duration(hours: 7));
    return (
      start: start,
      end: endExclusive.subtract(const Duration(microseconds: 1)),
    );
  }

  /// Jendela UTC untuk N hari bisnis terakhir (inklusif, berakhir hari ini).
  static ({DateTime start, DateTime end}) lastNDaysUtc(DateTime day, int n) {
    final win = businessDayUtc(day);
    final startDay = day.subtract(Duration(days: n - 1));
    final start = DateTime.utc(
      startDay.year,
      startDay.month,
      startDay.day,
      4,
      0,
      0,
    ).subtract(const Duration(hours: 7));
    return (start: start, end: win.end);
  }

  /// Weekend (Sabtu/Minggu) menurut kalender WIB.
  static bool isWeekend(DateTime day) {
    final wib = day.toUtc().add(const Duration(hours: 7));
    return wib.weekday == DateTime.saturday || wib.weekday == DateTime.sunday;
  }

  /// Tampilkan waktu UTC sebagai jam WIB "HH:MM".
  static String formatTimeWib(DateTime utc) {
    final wib = utc.toUtc().add(const Duration(hours: 7));
    return '${wib.hour.toString().padLeft(2, '0')}:'
        '${wib.minute.toString().padLeft(2, '0')}';
  }

  /// Tampilkan waktu UTC sebagai label tanggal WIB, mis. "Senin, 31/08/2026".
  /// Hari bisnis ini ditandai "Hari ini", kemarin "Kemarin".
  static String formatDateWib(DateTime utc) {
    final wib = utc.toUtc().add(const Duration(hours: 7));
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final today = businessDayNow();
    final label =
        '${days[wib.weekday - 1]}, ${wib.day} ${months[wib.month - 1]} ${wib.year}';
    if (wib.year == today.year &&
        wib.month == today.month &&
        wib.day == today.day) {
      return 'Hari ini — $label';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (wib.year == yesterday.year &&
        wib.month == yesterday.month &&
        wib.day == yesterday.day) {
      return 'Kemarin — $label';
    }
    return label;
  }

  /// Format "Rp 1.234.567".
  static String rupiah(num amount) {
    final s = amount.round().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'Rp $s';
  }
}

/// Model ringkas assignment gerobak investor untuk dropdown.
class InvestorGerobak {
  final String outletId;
  final String name;
  final double marginPercentage;
  final String? startDate;
  final String status;

  const InvestorGerobak({
    required this.outletId,
    required this.name,
    required this.marginPercentage,
    required this.startDate,
    required this.status,
  });

  factory InvestorGerobak.fromAssignment(Map<String, dynamic> a) {
    String name = (a['outlet_name'] as String?) ?? '';
    if (name.isEmpty) {
      final outlet = a['outlets'];
      if (outlet is Map<String, dynamic>) {
        name = (outlet['name'] as String?) ?? '';
      }
    }
    return InvestorGerobak(
      outletId: (a['outlet_id'] as String?) ?? '',
      name: name.isEmpty ? 'Outlet' : name,
      marginPercentage: (a['margin_percentage'] as num?)?.toDouble() ?? 0.0,
      startDate: a['start_date'] as String?,
      status: (a['status'] as String?) ?? '',
    );
  }

  bool get isActive => status.toLowerCase() == 'active';
}

/// Card ringkasan ala mockup investor (Profit Bulan Ini, dll).
class InvestorSummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color circleColor;
  final Color bgColor;
  final Color valueColor;
  final String title;
  final String value;

  /// null = tampilkan tanpa panah; true = panah naik; false = panah turun.
  final bool? trendUp;
  final VoidCallback? onDetail;

  const InvestorSummaryCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.circleColor,
    required this.bgColor,
    required this.valueColor,
    required this.title,
    required this.value,
    this.trendUp,
    this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (trendUp != null) ...[
                      Icon(
                        trendUp! ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        color: trendUp!
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                        size: 24,
                      ),
                      const SizedBox(width: 2),
                    ],
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: valueColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onDetail,
            style: OutlinedButton.styleFrom(
              foregroundColor: valueColor,
              side: BorderSide(color: valueColor, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Detil'),
          ),
        ],
      ),
    );
  }
}
