import 'package:intl/intl.dart';
import 'bonus_calculator.dart';

/// Model untuk hasil perhitungan profit investor
class ProfitCalculationResult {
  final double totalSales;
  final double totalHpp;
  final double bonusBarista; // Total bonus untuk barista
  final double mealAllowance; // Total uang makan
  final double totalExpenses; // bonus + meal allowance
  final double netProfit; // sales - (hpp + expenses)
  final double investorPercentage; // Persentase profit investor (0-100)
  final double investorProfit; // net profit * investor %
  final double outletProfit; // net profit * (100 - investor %)

  ProfitCalculationResult({
    required this.totalSales,
    required this.totalHpp,
    required this.bonusBarista,
    required this.mealAllowance,
    required this.totalExpenses,
    required this.netProfit,
    required this.investorPercentage,
    required this.investorProfit,
    required this.outletProfit,
  });

  /// Margin percentage terhadap total sales
  double get marginPercentage => totalSales > 0 ? (netProfit / totalSales * 100) : 0;

  /// HPP percentage terhadap total sales
  double get hppPercentage => totalSales > 0 ? (totalHpp / totalSales * 100) : 0;

  /// Expenses percentage terhadap total sales
  double get expensesPercentage => totalSales > 0 ? (totalExpenses / totalSales * 100) : 0;

  /// Investor profit percentage terhadap total sales
  double get investorProfitPercentage => totalSales > 0 ? (investorProfit / totalSales * 100) : 0;
}

/// Menghitung profit investor berdasarkan data penjualan
class ProfitMarginCalculator {
  /// Hitung profit dari single transaction
  static ProfitCalculationResult calculateFromTransaction({
    required double saleAmount,
    required double hpp,
    required double omset,
    required double investorPercentage,
    required bool isHoliday,
  }) {
    // Hitung bonus barista dan uang makan
    final bonusResult = calculateBonus(omset, isHoliday: isHoliday);
    final bonusBarista = bonusResult.totalBonus;

    // Tentukan uang makan berdasarkan omset
    final mealAllowance = omset >= 300000 ? 34000.0 : 25000.0;
    final totalExpenses = bonusBarista + mealAllowance;

    // Hitung profit
    final netProfit = saleAmount - (hpp + totalExpenses);
    final investorProfit = netProfit * (investorPercentage / 100);
    final outletProfit = netProfit - investorProfit;

    return ProfitCalculationResult(
      totalSales: saleAmount,
      totalHpp: hpp,
      bonusBarista: bonusBarista,
      mealAllowance: mealAllowance,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      investorPercentage: investorPercentage,
      investorProfit: investorProfit,
      outletProfit: outletProfit,
    );
  }

  /// Hitung profit dari multiple transactions (aggregated)
  static ProfitCalculationResult calculateFromAggregatedData({
    required double totalSales,
    required double totalHpp,
    required double totalOmset,
    required double investorPercentage,
    required bool isHoliday,
  }) {
    // Hitung bonus dan expenses untuk total omset
    final bonusResult = calculateBonus(totalOmset, isHoliday: isHoliday);
    final bonusBarista = bonusResult.totalBonus;

    // Tentukan uang makan berdasarkan total omset
    final mealAllowance = totalOmset >= 300000 ? 34000.0 : 25000.0;
    final totalExpenses = bonusBarista + mealAllowance;

    // Hitung profit
    final netProfit = totalSales - (totalHpp + totalExpenses);
    final investorProfit = netProfit * (investorPercentage / 100);
    final outletProfit = netProfit - investorProfit;

    return ProfitCalculationResult(
      totalSales: totalSales,
      totalHpp: totalHpp,
      bonusBarista: bonusBarista,
      mealAllowance: mealAllowance,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      investorPercentage: investorPercentage,
      investorProfit: investorProfit,
      outletProfit: outletProfit,
    );
  }

  /// Hitung profit dari data sales list dengan HPP yang sudah terakumulasi
  static ProfitCalculationResult calculateFromSalesData({
    required List<Map<String, dynamic>> salesData,
    required double totalHpp,
    required double investorPercentage,
    required bool isHoliday,
  }) {
    // Hitung total sales dan total omset dari sales data
    double totalSales = 0;
    double totalOmset = 0;

    for (final sale in salesData) {
      final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
      totalSales += amount;
      totalOmset += amount; // Assuming omset same as sales amount
    }

    return calculateFromAggregatedData(
      totalSales: totalSales,
      totalHpp: totalHpp,
      totalOmset: totalOmset,
      investorPercentage: investorPercentage,
      isHoliday: isHoliday,
    );
  }
}

/// Helper untuk format currency dengan simbol Indonesia
class CurrencyFormatter {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String format(double amount) {
    return _currencyFormat.format(amount);
  }

  /// Format dengan shorthand (jt/rb)
  static String formatShort(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)} jt';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)} rb';
    }
    return amount.toStringAsFixed(0);
  }

  /// Format percentage
  static String formatPercentage(double percentage, {int decimals = 2}) {
    return '${percentage.toStringAsFixed(decimals)}%';
  }
}

/// Breakdown komponen profit untuk detail view
class ProfitBreakdown {
  final double sales;
  final double hpp;
  final double bonus;
  final double mealAllowance;
  final double expenses;
  final double netProfit;
  final double investorPercentage;
  final double investorProfit;
  final double outletProfit;

  ProfitBreakdown({
    required this.sales,
    required this.hpp,
    required this.bonus,
    required this.mealAllowance,
    required this.expenses,
    required this.netProfit,
    required this.investorPercentage,
    required this.investorProfit,
    required this.outletProfit,
  });

  /// Create from ProfitCalculationResult
  factory ProfitBreakdown.fromResult(ProfitCalculationResult result) {
    return ProfitBreakdown(
      sales: result.totalSales,
      hpp: result.totalHpp,
      bonus: result.bonusBarista,
      mealAllowance: result.mealAllowance,
      expenses: result.totalExpenses,
      netProfit: result.netProfit,
      investorPercentage: result.investorPercentage,
      investorProfit: result.investorProfit,
      outletProfit: result.outletProfit,
    );
  }

  /// Get items untuk list view
  List<Map<String, dynamic>> getItems() {
    return [
      {
        'label': 'Total Penjualan',
        'value': sales,
        'color': 'blue',
        'icon': '💰',
      },
      {
        'label': 'HPP (Cost of Goods)',
        'value': -hpp,
        'color': 'red',
        'icon': '📦',
      },
      {
        'label': 'Bonus Barista',
        'value': -bonus,
        'color': 'red',
        'icon': '👤',
      },
      {
        'label': 'Uang Makan',
        'value': -mealAllowance,
        'color': 'red',
        'icon': '🍜',
      },
      {
        'label': 'Profit Bersih',
        'value': netProfit,
        'color': 'green',
        'icon': '📊',
        'isSeparator': true,
      },
      {
        'label': 'Profit Investor (${investorPercentage.toStringAsFixed(0)}%)',
        'value': investorProfit,
        'color': 'green',
        'icon': '👨‍💼',
      },
      {
        'label': 'Profit Outlet (${(100 - investorPercentage).toStringAsFixed(0)}%)',
        'value': outletProfit,
        'color': 'green',
        'icon': '🏪',
      },
    ];
  }
}
