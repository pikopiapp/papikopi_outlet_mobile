import 'package:flutter/material.dart';
import '../utils/bonus_calculator.dart';
import '../utils/holiday_detector.dart';
import 'package:intl/intl.dart';

class DailyBonusCard extends StatelessWidget {
  final double omset;
  final bool isLoading;
  final DateTime? selectedDate;

  const DailyBonusCard({
    super.key,
    this.omset = 0,
    this.isLoading = false,
    this.selectedDate,
  });

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(amount.toInt());
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade500, Colors.green.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 60,
          child: Shimmer.fromColors(
            baseColor: Colors.white10,
            highlightColor: Colors.white30,
            child: Container(
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    if (omset == 0) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade300, Colors.grey.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bonus Hari Ini',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rp 0',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Belum ada penjualan',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    // Determine if today/selected date is a holiday
    final dateToCheck = selectedDate ?? DateTime.now();
    final isHolidayDate = isHoliday(dateToCheck);
    
    // Calculate bonus and wage components using the top-level functions
    final bonusData = calculateBonus(omset, isHoliday: isHolidayDate);
    final totalBonus = bonusData.totalBonus;
    final breakdown = bonusData.breakdown;
    
    // Calculate meal allowance using the same function
    final mealAllowance = calculateMealAllowance(omset);
    final totalWage = totalBonus + mealAllowance;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade500, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '💰 Upah Harian',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isHolidayDate)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🎉 ${getHolidayDescription(selectedDate ?? DateTime.now())}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Rp ${_formatCurrency(totalWage)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bonus (Bertahap):',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Rp ${_formatCurrency(totalBonus)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Uang Makan:',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Rp ${_formatCurrency(mealAllowance)}',
                      style: TextStyle(
                        color: Colors.amber.shade200,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(
                  color: Colors.white.withOpacity(0.2),
                  height: 1,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Omset Hari Ini:',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      'Rp ${_formatCurrency(omset)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Metode:',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      'Progressive ${breakdown.length} Tier',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  omset >= 300000 
                    ? '🔹 Omset ≥ Rp 300rb → Uang Makan Rp 34rb'
                    : '🔹 Omset < Rp 300rb → Uang Makan Rp 25rb',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (isHolidayDate) ...[
                  const SizedBox(height: 6),
                  Text(
                    '🎉 Bonus Hari Libur: Semua Tier 20%',
                    style: TextStyle(
                      color: Colors.orange.shade300,
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Compact version for quick summary
class BonusSummaryCompactCard extends StatelessWidget {
  final double omset;

  const BonusSummaryCompactCard({
    super.key,
    this.omset = 0,
  });

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(amount.toInt());
  }

  @override
  Widget build(BuildContext context) {
    final bonus = omset > 0 ? calculateBonus(omset).totalBonus : 0.0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: Colors.green.shade50,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bonus Otomatis',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rp ${_formatCurrency(bonus)}',
            style: TextStyle(
              color: Colors.green.shade600,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Shimmer effect helper
class Shimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const Shimmer.fromColors({
    super.key,
    required this.child,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.6 + (_controller.value * 0.4),
          child: widget.child,
        );
      },
    );
  }
}
