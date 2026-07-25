import 'package:flutter/material.dart';

import '../../theme/thema.dart';
import 'shared/investor_widgets.dart';
import 'shared/investor_data_mixin.dart';

class InvestorReportOutletScreen extends StatefulWidget {
  const InvestorReportOutletScreen({super.key});

  @override
  State<InvestorReportOutletScreen> createState() =>
      _InvestorReportOutletScreenState();
}

class _InvestorReportOutletScreenState extends State<InvestorReportOutletScreen>
    with InvestorDataMixin {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      Icons.analytics_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Report Outlet',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Ringkasan outlet yang diinvestasikan.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: resolveInvestorOutlets(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return InfoBox(
                      title: 'Error',
                      value: 'Gagal memuat outlets investor: ${snapshot.error}',
                    );
                  }

                  final outlets = snapshot.data ?? [];
                  if (outlets.isEmpty) {
                    return const InfoBox(
                      title: 'Outlet investor',
                      value: 'Belum ada outlet yang diinvestasikan.',
                    );
                  }

                  // Calculate summary
                  int totalOutlets = outlets.length;
                  int activeOutlets = outlets
                      .where((o) => (o['status'] as String?) == 'active')
                      .length;
                  double totalInvestment = 0;
                  for (final o in outlets) {
                    final amount =
                        (o['investment_amount'] as num?)?.toDouble() ?? 0.0;
                    totalInvestment += amount;
                  }

                  return Column(
                    children: [
                      // Mixed Layout: 2-col + full width for odd number of cards
                      Column(
                        children: [
                          // Row 1: Card 1 + Card 2 (2 columns)
                          Row(
                            children: [
                              Expanded(
                                child: SummaryCard(
                                  label: 'Total Outlet',
                                  value: '$totalOutlets',
                                  bgColor: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SummaryCard(
                                  label: 'Outlet Aktif',
                                  value: '$activeOutlets',
                                  bgColor: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Row 2: Card 3 (full width)
                          SummaryCard(
                            label: 'Total Investasi',
                            value: 'Rp${formatCurrency(totalInvestment)}',
                            bgColor: Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Outlet List
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: outlets.length,
                        itemBuilder: (context, index) {
                          final outlet = outlets[index];
                          final outletName =
                              (outlet['outlet_name'] as String?) ?? '-';
                          final outletType =
                              (outlet['outlet_type'] as String?) ?? 'unknown';
                          final investmentAmount =
                              (outlet['investment_amount'] as num?)
                                  ?.toDouble() ??
                              0.0;
                          final marginPercentage =
                              (outlet['margin_percentage'] as num?)
                                  ?.toDouble() ??
                              0.0;
                          final status =
                              (outlet['status'] as String?) ?? 'unknown';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                outletName,
                                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                outletType.replaceAll('_', ' ').toUpperCase(),
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: AppColors.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: status == 'active'
                                                ? AppColors.success.withValues(alpha: 0.15)
                                                : AppColors.accent.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: status == 'active'
                                                  ? AppColors.success.withValues(alpha: 0.4)
                                                  : AppColors.accent.withValues(alpha: 0.4),
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: status == 'active'
                                                  ? AppColors.hijau
                                                  : AppColors.accentDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Container(height: 1, color: AppColors.altSurface),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Modal Investasi',
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: AppColors.textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                'Rp${formatCurrency(investmentAmount)}',
                                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Margin Profit',
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: AppColors.textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                '${marginPercentage.toStringAsFixed(1)}%',
                                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}