import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/thema.dart';
import 'shared/investor_data_mixin.dart';
import 'shared/investor_period_helper.dart';

/// Home investor sesuai mockup:
/// - Sapaan + "Pilih Gerobak"
/// - Profit Bulan Ini, Profit Hari Ini, Transaksi Hari Ini (+ tombol Detil)
class InvestorHomeScreen extends StatefulWidget {
  const InvestorHomeScreen({super.key, this.onNavigate});

  final Function(int)? onNavigate;

  @override
  State<InvestorHomeScreen> createState() => _InvestorHomeScreenState();
}

class _InvestorHomeScreenState extends State<InvestorHomeScreen>
    with InvestorDataMixin {
  List<InvestorGerobak> _gerobakList = [];
  InvestorGerobak? _selected;
  bool _loading = true;
  String? _errorMessage;
  late DateTime _selectedMonth;

  double _profitMonth = 0;
  double _profitToday = 0;
  double _salesToday = 0;
  Map<String, dynamic> _summaryToday = {};
  Map<String, dynamic> _summaryMonth = {};
  Map<String, double> _baristaCostsToday = {};
  Map<String, double> _baristaCostsMonth = {};

  @override
  void initState() {
    super.initState();
    final nowJakarta = DateTime.now().toUtc().add(const Duration(hours: 7));
    _selectedMonth = DateTime(nowJakarta.year, nowJakarta.month);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final assignments = await resolveInvestorOutlets();
      final gerobak = assignments
          .map(InvestorGerobak.fromAssignment)
          .where((g) => g.outletId.isNotEmpty)
          .toList();

      InvestorGerobak? selected;
      for (final outlet in gerobak) {
        if (outlet.isActive) {
          selected = outlet;
          break;
        }
      }
      selected ??= gerobak.isEmpty ? null : gerobak.first;

      if (!mounted) return;
      setState(() {
        _gerobakList = gerobak;
        _selected = selected;
        _errorMessage = null;
      });

      if (selected != null) {
        await _loadSummary(selected, _selectedMonth);
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat ringkasan investor: $error';
        _loading = false;
      });
    }
  }

  Future<void> _loadSummary(
    InvestorGerobak gerobak,
    DateTime selectedMonth,
  ) async {
    final nowUtc = DateTime.now().toUtc();
    final nowJakarta = nowUtc.add(const Duration(hours: 7));
    final today = DateTime(nowJakarta.year, nowJakarta.month, nowJakarta.day);
    final dayWin = InvestorPeriod.calendarDateRangeUtc(today, today);
    final monthStartUtc = DateTime.utc(
      selectedMonth.year,
      selectedMonth.month,
      1,
    ).subtract(const Duration(hours: 7));
    final nextMonthStartUtc = DateTime.utc(
      selectedMonth.year,
      selectedMonth.month + 1,
      1,
    ).subtract(const Duration(hours: 7));
    final isCurrentMonth =
        selectedMonth.year == nowJakarta.year &&
        selectedMonth.month == nowJakarta.month;
    final monthEndUtc = isCurrentMonth
        ? nowUtc
        : nextMonthStartUtc.subtract(const Duration(microseconds: 1));
    final monthEndDay = isCurrentMonth
        ? today
        : DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    final hppDay = await supabaseService.getHppSummary(
      outletId: gerobak.outletId,
      startDate: dayWin.start,
      endDate: nowUtc,
      assignmentStartDate: gerobak.startDate,
    );
    final hppMonth = await supabaseService.getHppSummary(
      outletId: gerobak.outletId,
      startDate: monthStartUtc,
      endDate: monthEndUtc,
      assignmentStartDate: gerobak.startDate,
    );

    final baristaCostsToday = await supabaseService
        .getInvestorBaristaCostSummary(
          outletId: gerobak.outletId,
          startBusinessDate: today,
          endBusinessDate: today,
          assignmentStartDate: gerobak.startDate,
          calendarDays: true,
        );
    final baristaCostsMonth = await supabaseService
        .getInvestorBaristaCostSummary(
          outletId: gerobak.outletId,
          startBusinessDate: DateTime(selectedMonth.year, selectedMonth.month),
          endBusinessDate: monthEndDay,
          assignmentStartDate: gerobak.startDate,
          calendarDays: true,
        );

    final salesToday = (hppDay['totalSales'] as num?)?.toDouble() ?? 0.0;
    final profitToday = _investorProfit(
      hppDay,
      baristaCostsToday,
      gerobak.marginPercentage,
    );
    final profitMonth = _investorProfit(
      hppMonth,
      baristaCostsMonth,
      gerobak.marginPercentage,
    );

    if (!mounted) return;
    setState(() {
      _salesToday = salesToday;
      _profitToday = profitToday;
      _profitMonth = profitMonth;
      _summaryToday = hppDay;
      _summaryMonth = hppMonth;
      _baristaCostsToday = baristaCostsToday;
      _baristaCostsMonth = baristaCostsMonth;
    });
  }

  double _investorProfit(
    Map<String, dynamic> hpp,
    Map<String, double> baristaCosts,
    double margin,
  ) {
    final grossProfit = (hpp['totalProfit'] as num?)?.toDouble() ?? 0.0;
    final bonus = baristaCosts['bonus'] ?? 0.0;
    final mealAllowance = baristaCosts['mealAllowance'] ?? 0.0;
    final netProfit = grossProfit - bonus - mealAllowance;
    return netProfit * (margin / 100);
  }

  void _showProfitDetails({required bool monthly}) {
    final outlet = _selected;
    if (outlet == null) return;

    final nowJakarta = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateTime(nowJakarta.year, nowJakarta.month, nowJakarta.day);
    final periodLabel = monthly
        ? _monthLabel(_selectedMonth)
        : '${today.day} ${_monthLabel(today).split(' ').first} ${today.year}';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Detil Bagian Investor $periodLabel'),
        content: SizedBox(
          width: 360,
          child: _buildProfitDetails(
            context,
            outlet,
            monthly ? _summaryMonth : _summaryToday,
            monthly ? _baristaCostsMonth : _baristaCostsToday,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitDetails(
    BuildContext context,
    InvestorGerobak outlet,
    Map<String, dynamic> summary,
    Map<String, double> baristaCosts,
  ) {
    final sales = (summary['totalSales'] as num?)?.toDouble() ?? 0.0;
    final grossProfit = (summary['totalProfit'] as num?)?.toDouble() ?? 0.0;
    final bonus = baristaCosts['bonus'] ?? 0.0;
    final mealAllowance = baristaCosts['mealAllowance'] ?? 0.0;
    final netProfit = grossProfit - bonus - mealAllowance;
    final investorShare = netProfit * outlet.marginPercentage / 100;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(outlet.name, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 16),
        _ProfitDetailRow(label: 'Omset', amount: sales),
        _ProfitDetailRow(label: 'Laba kotor', amount: grossProfit),
        _ProfitDetailRow(label: 'Bonus Barista', amount: bonus),
        _ProfitDetailRow(
          label: 'Operasional Barista (Uang Makan)',
          amount: mealAllowance,
        ),
        _ProfitDetailRow(
          label: 'Laba bersih',
          amount: netProfit,
          emphasized: true,
        ),
        const Divider(height: 24),
        _ProfitDetailRow(
          label:
              'Bagian investor (${outlet.marginPercentage.toStringAsFixed(0)}%)',
          amount: investorShare,
          emphasized: true,
        ),
      ],
    );
  }

  Future<void> _onSelectGerobak(InvestorGerobak? g) async {
    if (g == null) return;
    setState(() {
      _selected = g;
      _errorMessage = null;
      _loading = true;
    });
    try {
      await _loadSummary(g, _selectedMonth);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat ringkasan investor: $error';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectMonth() async {
    final nowJakarta = DateTime.now().toUtc().add(const Duration(hours: 7));
    final currentYear = nowJakarta.year;
    var dialogYear = _selectedMonth.year;
    var dialogMonth = _selectedMonth.month;

    final selected = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pilih Bulan'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: dialogYear,
                  isExpanded: true,
                  items: [
                    for (var year = currentYear; year >= 2015; year--)
                      DropdownMenuItem(value: year, child: Text('$year')),
                  ],
                  onChanged: (year) {
                    if (year != null) {
                      setDialogState(() => dialogYear = year);
                    }
                  },
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var month = 1; month <= 12; month++)
                      _MonthChoice(
                        month: month,
                        selected:
                            dialogYear == _selectedMonth.year &&
                            month == dialogMonth,
                        enabled:
                            dialogYear < currentYear ||
                            month <= nowJakarta.month,
                        onTap: () {
                          setDialogState(() => dialogMonth = month);
                          Navigator.of(
                            dialogContext,
                          ).pop(DateTime(dialogYear, month));
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );
    if (selected == null ||
        (selected.year == _selectedMonth.year &&
            selected.month == _selectedMonth.month)) {
      return;
    }

    setState(() {
      _selectedMonth = selected;
      _errorMessage = null;
      _loading = true;
    });
    try {
      final outlet = _selected;
      if (outlet != null) await _loadSummary(outlet, selected);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat ringkasan investor: $error';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.currentUser?.name ?? 'Investor';

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selamat Datang, $userName! 👋',
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pantau performa investasi Anda',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _buildGerobakPicker(),
          const SizedBox(height: 10),
          _buildMonthPicker(),
          const SizedBox(height: 20),
          if (_errorMessage != null) ...[
            _buildLoadError(),
            const SizedBox(height: 16),
          ],
          InvestorSummaryCard(
            icon: Icons.show_chart,
            iconColor: const Color(0xFF2563EB),
            circleColor: const Color(0xFFDBEAFE),
            bgColor: const Color(0xFFEFF4FB),
            valueColor: const Color(0xFF2563EB),
            title: 'Bagian Investor ${_monthLabel(_selectedMonth)}',
            value: InvestorPeriod.rupiah(_profitMonth),
            trendUp: _profitMonth > 0
                ? true
                : (_profitMonth < 0 ? false : null),
            onDetail: () => _showProfitDetails(monthly: true),
          ),
          const SizedBox(height: 16),
          InvestorSummaryCard(
            icon: Icons.trending_down,
            iconColor: _profitToday < 0
                ? const Color(0xFFDC2626)
                : const Color(0xFF16A34A),
            circleColor: _profitToday < 0
                ? const Color(0xFFFEE2E2)
                : const Color(0xFFDCFCE7),
            bgColor: _profitToday < 0
                ? const Color(0xFFFDF0EF)
                : const Color(0xFFF0F9F1),
            valueColor: _profitToday < 0
                ? const Color(0xFFDC2626)
                : const Color(0xFF16A34A),
            title: 'Bagian Investor Hari Ini',
            value: InvestorPeriod.rupiah(_profitToday),
            trendUp: _profitToday > 0
                ? true
                : (_profitToday < 0 ? false : null),
            onDetail: () => _showProfitDetails(monthly: false),
          ),
          const SizedBox(height: 16),
          InvestorSummaryCard(
            icon: Icons.payments_outlined,
            iconColor: const Color(0xFF16A34A),
            circleColor: const Color(0xFFDCFCE7),
            bgColor: const Color(0xFFF1F7F2),
            valueColor: const Color(0xFF16A34A),
            title: 'Transaksi Hari Ini',
            value: InvestorPeriod.rupiah(_salesToday),
            trendUp: null,
            onDetail: () => widget.onNavigate?.call(1),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _errorMessage!,
            style: const TextStyle(color: Color(0xFF991B1B)),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthPicker() {
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        onPressed: _selectMonth,
        icon: const Icon(Icons.calendar_month_outlined, size: 18),
        label: Text(_monthLabel(_selectedMonth)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        ),
      ),
    );
  }

  String _monthLabel(DateTime month) {
    const names = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${names[month.month - 1]} ${month.year}';
  }

  Widget _buildGerobakPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront, color: AppColors.primary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pilih Gerobak',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<InvestorGerobak>(
                    value: _selected,
                    isDense: true,
                    isExpanded: true,
                    hint: const Text('Pilih Gerobak'),
                    items: _gerobakList
                        .map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Text(
                              g.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (g) => _onSelectGerobak(g),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthChoice extends StatelessWidget {
  const _MonthChoice({
    required this.month,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int month;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const labels = [
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
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          labels[month - 1],
          style: TextStyle(
            color: !enabled
                ? Colors.grey.shade400
                : selected
                ? Colors.white
                : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ProfitDetailRow extends StatelessWidget {
  const _ProfitDetailRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
      color: emphasized ? AppColors.success : AppColors.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textStyle)),
          const SizedBox(width: 12),
          Text(InvestorPeriod.rupiah(amount), style: textStyle),
        ],
      ),
    );
  }
}
