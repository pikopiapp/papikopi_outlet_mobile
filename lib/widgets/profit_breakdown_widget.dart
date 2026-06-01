import 'package:flutter/material.dart';
import '../../utils/profit_margin_calculator.dart';

/// Widget untuk menampilkan breakdown profit investor
class ProfitBreakdownCard extends StatelessWidget {
  final ProfitCalculationResult result;
  final String outletName;

  const ProfitBreakdownCard({
    required this.result,
    required this.outletName,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profit Detail - $outletName',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.formatShort(result.investorProfit),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Penjualan',
                        value: result.totalSales,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                        label: 'HPP',
                        value: -result.totalHpp,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                        label: 'Bonus Barista',
                        value: -result.bonusBarista,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                        label: 'Uang Makan',
                        value: -result.mealAllowance,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Net Profit
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Profit Bersih',
                        value: result.netProfit,
                        color: Colors.green,
                        isTotal: true,
                      ),
                      const SizedBox(height: 12),
                      Divider(color: Colors.green.shade200),
                      const SizedBox(height: 12),
                      _DetailRow(
                        label: 'Profit Investor (${result.investorPercentage.toStringAsFixed(0)}%)',
                        value: result.investorProfit,
                        color: Colors.green,
                        isInvestor: true,
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                        label: 'Profit Outlet (${(100 - result.investorPercentage).toStringAsFixed(0)}%)',
                        value: result.outletProfit,
                        color: Colors.amber,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Percentage Summary
                Row(
                  children: [
                    Expanded(
                      child: _PercentageBox(
                        label: 'Margin',
                        percentage: '${result.marginPercentage.toStringAsFixed(2)}%',
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PercentageBox(
                        label: 'HPP',
                        percentage: '${result.hppPercentage.toStringAsFixed(2)}%',
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PercentageBox(
                        label: 'Expenses',
                        percentage: '${result.expensesPercentage.toStringAsFixed(2)}%',
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget untuk menampilkan satu detail row
class _DetailRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isTotal;
  final bool isInvestor;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.color,
    this.isTotal = false,
    this.isInvestor = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 13 : 12,
            fontWeight: isTotal || isInvestor ? FontWeight.bold : FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        Text(
          CurrencyFormatter.format(value),
          style: TextStyle(
            fontSize: isTotal ? 13 : 12,
            fontWeight: isTotal || isInvestor ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Widget untuk menampilkan percentage box
class _PercentageBox extends StatelessWidget {
  final String label;
  final String percentage;
  final Color color;

  const _PercentageBox({
    required this.label,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            percentage,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget summary profit untuk dashboard
class ProfitSummaryCard extends StatelessWidget {
  final double totalProfit;
  final double investorProfit;
  final double totalSales;
  final String title;

  const ProfitSummaryCard({
    required this.totalProfit,
    required this.investorProfit,
    required this.totalSales,
    required this.title,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final profitPercentage = totalSales > 0 ? (totalProfit / totalSales * 100) : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade50,
              Colors.green.shade100,
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profit Bersih',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(totalProfit),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Investor Share',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(investorProfit),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Margin: ${profitPercentage.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  'Sales: ${CurrencyFormatter.formatShort(totalSales)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
