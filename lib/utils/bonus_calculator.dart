/// Progressive Bonus Calculator
/// Calculates bonus based on tiered/graduated rates (like progressive tax)
/// 
///Tier Structure:
/// | Tahap   | Omset Minimal | Bonus |
/// |--------|--------------|-------|
/// | Tahap 1| 0            | 10%   |
/// | Tahap 2| 200.000      | 12%   |
/// | Tahap 3| 350.000      | 15%   |
/// | Tahap 4| 500.000      | 20%   |
/// 
/// Example: omset = 450.000
/// - Tier 1: 200.000 × 10% = 20.000
/// - Tier 2: 150.000 × 12% = 18.000
/// - Tier 3: 100.000 × 15% = 15.000
/// Total = 53.000

import 'dart:math';

/// Bonus tier configuration
class BonusTier {
  final double min;
  final double? max;
  final double percentage;

  const BonusTier({
    required this.min,
    this.max,
    required this.percentage,
  });

  /// Default tier structure from specification
  static const List<BonusTier> defaultTiers = [
    BonusTier(min: 0, max: 200000, percentage: 10),
    BonusTier(min: 200000, max: 350000, percentage: 12),
    BonusTier(min: 350000, max: 500000, percentage: 15),
    BonusTier(min: 500000, max: null, percentage: 20),
  ];

  /// Holiday tier structure (all tiers get 20%)
  /// Used for weekend and national holidays
  static const List<BonusTier> holidayTiers = [
    BonusTier(min: 0, max: 200000, percentage: 20),
    BonusTier(min: 200000, max: 350000, percentage: 20),
    BonusTier(min: 350000, max: 500000, percentage: 20),
    BonusTier(min: 500000, max: null, percentage: 20),
  ];

  Map<String, dynamic> toJson() {
    return {
      'min': min,
      'max': max,
      'percentage': percentage,
    };
  }

  factory BonusTier.fromJson(Map<String, dynamic> json) {
    return BonusTier(
      min: (json['min'] as num).toDouble(),
      max: json['max'] != null ? (json['max'] as num).toDouble() : null,
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

/// Result of bonus calculation
class BonusCalculationResult {
  final double omset;
  final double totalBonus;
  final List<TierBreakdown> breakdown;
  final double effectivePercentage;
  final bool isSpecial;

  const BonusCalculationResult({
    required this.omset,
    required this.totalBonus,
    required this.breakdown,
    required this.effectivePercentage,
    this.isSpecial = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'omset': omset,
      'total_bonus': totalBonus,
      'breakdown': breakdown.map((t) => t.toJson()).toList(),
      'effective_percentage': effectivePercentage,
      'is_special': isSpecial,
    };
  }
}

/// Breakdown per tier
class TierBreakdown {
  final int tierNumber;
  final String label;
  final double fromAmount;
  final double toAmount;
  final double amount;
  final double percentage;
  final double bonus;

  const TierBreakdown({
    required this.tierNumber,
    required this.label,
    required this.fromAmount,
    required this.toAmount,
    required this.amount,
    required this.percentage,
    required this.bonus,
  });

  Map<String, dynamic> toJson() {
    return {
      'tier_number': tierNumber,
      'label': label,
      'from_amount': fromAmount,
      'to_amount': toAmount,
      'amount': amount,
      'percentage': percentage,
      'bonus': bonus,
    };
  }
}

/// Meal allowance configuration
class MealAllowance {
  final double belowThreshold;  // Amount for omset < 300rb
  final double aboveThreshold;  // Amount for omset >= 300rb
  final double threshold;       // Threshold amount (300rb)

  const MealAllowance({
    required this.belowThreshold,
    required this.aboveThreshold,
    required this.threshold,
  });

  /// Default meal allowance
  /// Omset < 300rb: Rp 25,000
  /// Omset >= 300rb: Rp 34,000
  static const MealAllowance defaultAllowance = MealAllowance(
    belowThreshold: 25000,
    aboveThreshold: 34000,
    threshold: 300000,
  );
}

/// Daily wage result (Bonus + Meal Allowance)
class DailyWageResult {
  final double omset;
  final double bonus;
  final double mealAllowance;
  final double totalWage;
  final List<TierBreakdown>? breakdown;
  final bool? isHoliday;

  const DailyWageResult({
    required this.omset,
    required this.bonus,
    required this.mealAllowance,
    required this.totalWage,
    this.breakdown,
    this.isHoliday,
  });

  Map<String, dynamic> toJson() {
    return {
      'omset': omset,
      'bonus': bonus,
      'meal_allowance': mealAllowance,
      'total_wage': totalWage,
      'breakdown': breakdown?.map((t) => t.toJson()).toList(),
      'is_holiday': isHoliday,
    };
  }
}

/// Calculate progressive bonus
/// 
/// [omset] - Total omset/sales amount
/// [isHoliday] - If true, apply 20% to all tiers (weekend or national holiday)
/// [customTiers] - Optional custom tier configuration
BonusCalculationResult calculateBonus(
  double omset, {
  bool isHoliday = false,
  List<BonusTier>? customTiers,
}) {
  final tiers = customTiers ?? (isHoliday ? BonusTier.holidayTiers : BonusTier.defaultTiers);

  // Validate input
  if (omset < 0) {
    return BonusCalculationResult(
      omset: 0,
      totalBonus: 0,
      breakdown: [],
      effectivePercentage: 0,
      isSpecial: false,
    );
  }

  // Progressive tiered calculation
  final breakdown = <TierBreakdown>[];
  double totalBonus = 0;

for (int i = 0; i < tiers.length; i++) {
    final tier = tiers[i];
    final tierNum = i + 1;
    
    // Calculate amount in this tier
    double amountInTier;
    double fromAmount;
    double toAmount;

    if (i == 0) {
      // Tier 1: 0 to first max
      amountInTier = min(omset, tier.max ?? 200000.0);
      fromAmount = 0;
      toAmount = tier.max ?? 200000.0;
    } else {
      // Other tiers
      final prevMax = tiers[i - 1].max ?? 0.0;
      final tierMax = tier.max ?? (omset + 1);
      final double range = tierMax - prevMax;
      
      if (omset <= prevMax) {
        // No amount in this tier
        continue;
      }
      
      amountInTier = min(omset - prevMax, range);
      fromAmount = prevMax;
      toAmount = prevMax + amountInTier;
    }

    if (amountInTier > 0) {
      final bonus = amountInTier * (tier.percentage / 100);
      totalBonus += bonus;

      breakdown.add(TierBreakdown(
        tierNumber: tierNum,
        label: isHoliday ? 'Tahap $tierNum (Hari Libur)' : 'Tahap $tierNum',
        fromAmount: fromAmount,
        toAmount: toAmount,
        amount: amountInTier,
        percentage: tier.percentage,
        bonus: bonus,
      ));
    }
  }

// Calculate effective percentage
  final double effectivePercentage = omset > 0 ? (totalBonus / omset) * 100 : 0.0;

  return BonusCalculationResult(
    omset: omset,
    totalBonus: totalBonus,
    breakdown: breakdown,
    effectivePercentage: effectivePercentage,
    isSpecial: isHoliday,
  );
}

/// Quick calculation - just returns total bonus amount
double quickCalculateBonus(double omset, {bool isHoliday = false}) {
  return calculateBonus(omset, isHoliday: isHoliday).totalBonus;
}

/// Validate bonus tiers configuration
bool validateBonusTiers(List<BonusTier> tiers) {
  if (tiers.isEmpty) return false;
  
  // Check tiers are in order and consecutive
  double expectedMin = 0.0;
  for (final tier in tiers) {
    if (tier.min != expectedMin) return false;
    if (tier.max != null && tier.max! <= tier.min) return false;
    expectedMin = tier.max ?? (expectedMin + 1.0);
  }
  
  return true;
}

/// Get tier labels for display
List<String> getTierLabels(List<BonusTier> tiers) {
  return tiers.map((tier) {
    final minStr = _formatNumber(tier.min);
    final maxStr = tier.max != null ? _formatNumber(tier.max!) : '∞';
    return '${tier.percentage.toStringAsFixed(0)}% ($minStr - $maxStr)';
  }).toList();
}

String _formatNumber(double num) {
  if (num >= 1000000) {
    return '${(num / 1000000).toStringAsFixed(1)}jt';
  } else if (num >= 1000) {
    return '${(num / 1000).toStringAsFixed(0)}rb';
  }
  return num.toStringAsFixed(0);
}

/// Calculate bonus from JSON/API response
/// Parses tiers from database and calculates bonus
BonusCalculationResult calculateBonusFromJson(
  double omset,
  List<Map<String, dynamic>> tiersJson, {
  bool isHoliday = false,
}) {
  final tiers = tiersJson.map((t) => BonusTier.fromJson(t)).toList();
  return calculateBonus(omset, isHoliday: isHoliday, customTiers: tiers);
}

/// Calculate meal allowance (uang makan)
/// 
/// [omset] - Total omset/sales amount
/// [allowanceConfig] - Meal allowance configuration (default: MealAllowance.defaultAllowance)
/// Returns meal allowance amount
double calculateMealAllowance(
  double omset, {
  MealAllowance allowanceConfig = MealAllowance.defaultAllowance,
}) {
  // If omset is 0, no meal allowance
  if (omset == 0) {
    return 0.0;
  }
  
  return omset >= allowanceConfig.threshold
      ? allowanceConfig.aboveThreshold
      : allowanceConfig.belowThreshold;
}

/// Calculate daily wage (Upah Harian = Bonus + Uang Makan)
/// 
/// [omset] - Total omset/sales amount
/// [isHoliday] - If true, apply holiday bonus (20% for all tiers)
/// [includeBreakdown] - If true, include bonus breakdown in result
/// Returns DailyWageResult with bonus, meal allowance, and total wage
DailyWageResult calculateDailyWage(
  double omset, {
  bool isHoliday = false,
  bool includeBreakdown = true,
}) {
  final bonusResult = calculateBonus(omset, isHoliday: isHoliday);
  final mealAllowance = calculateMealAllowance(omset);

  return DailyWageResult(
    omset: omset,
    bonus: bonusResult.totalBonus,
    mealAllowance: mealAllowance,
    totalWage: bonusResult.totalBonus + mealAllowance,
    breakdown: includeBreakdown ? bonusResult.breakdown : null,
    isHoliday: isHoliday,
  );
}
