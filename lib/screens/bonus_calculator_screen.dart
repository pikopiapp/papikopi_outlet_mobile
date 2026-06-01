import 'package:flutter/material.dart';
import '../widgets/bonus_calculator_widget.dart';
import '../theme/thema.dart';

class BonusCalculatorScreen extends StatelessWidget {
  const BonusCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Kalkulator Bonus'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade600, Colors.green.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🧮 Calculator Bonus',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Hitung bonus penjualan berdasarkan metode berjenjang (progressive). Semakin besar omset, semakin banyak layer bonus yang didapat.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tier Structure Reference
            const Text(
              '📋 Struktur Tier Bonus',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _buildTierCard('Tier 1', '10%', '0 - 200rb'),
                _buildTierCard('Tier 2', '12%', '200rb - 350rb'),
                _buildTierCard('Tier 3', '15%', '350rb - 500rb'),
                _buildTierCard('Tier 4', '20%', '500rb+'),
              ],
            ),
            const SizedBox(height: 24),

            // Bonus Calculator Widget
            const BonusCalculatorWidget(showBreakdown: true),

            const SizedBox(height: 24),

            // Test Card untuk menunjukkan contoh bonus
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📌 Contoh Perhitungan Bonus',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Omset: Rp 450.000',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '- Tier 1 (Rp 0-200rb × 10%) = Rp 20.000',
                    style: TextStyle(fontSize: 11),
                  ),
                  const Text(
                    '- Tier 2 (Rp 200-350rb × 12%) = Rp 18.000',
                    style: TextStyle(fontSize: 11),
                  ),
                  const Text(
                    '- Tier 3 (Rp 350-450rb × 15%) = Rp 15.000',
                    style: TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Total Bonus = Rp 53.000',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard(String tier, String percentage, String range) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tier,
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            percentage,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            range,
            style: TextStyle(
              fontSize: 11,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
