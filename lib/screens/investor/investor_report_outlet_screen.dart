import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/thema.dart';
import 'shared/investor_data_mixin.dart';
import 'shared/investor_period_helper.dart';

class InvestorReportOutletScreen extends StatefulWidget {
  const InvestorReportOutletScreen({super.key});

  @override
  State<InvestorReportOutletScreen> createState() =>
      _InvestorReportOutletScreenState();
}

class _InvestorReportOutletScreenState extends State<InvestorReportOutletScreen>
    with InvestorDataMixin {
  List<Map<String, dynamic>> _assignments = [];
  List<InvestorGerobak> _gerobakList = [];
  InvestorGerobak? _selected;
  late DateTimeRange _selectedRange;
  Map<String, dynamic> _summary = {};
  Map<String, double> _baristaCosts = {};
  bool _loading = true;
  bool _reportLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final nowWib = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateTime(nowWib.year, nowWib.month, nowWib.day);
    _selectedRange = DateTimeRange(
      start: DateTime(today.year, today.month, 1),
      end: today,
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final assignments = await resolveInvestorOutlets();
      final gerobakList = assignments
          .map(InvestorGerobak.fromAssignment)
          .where((gerobak) => gerobak.outletId.isNotEmpty)
          .toList();
      InvestorGerobak? selected;
      for (final gerobak in gerobakList) {
        if (gerobak.isActive) {
          selected = gerobak;
          break;
        }
      }
      selected ??= gerobakList.isEmpty ? null : gerobakList.first;

      if (!mounted) return;
      setState(() {
        _assignments = assignments;
        _gerobakList = gerobakList;
        _selected = selected;
      });

      if (selected != null) await _loadReport(selected, _selectedRange);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Gagal memuat laporan investor: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadReport(
    InvestorGerobak gerobak,
    DateTimeRange selectedRange,
  ) async {
    setState(() {
      _reportLoading = true;
      _errorMessage = null;
    });
    try {
      final dateWindow = InvestorPeriod.calendarDateRangeUtc(
        selectedRange.start,
        selectedRange.end,
      );
      final nowUtc = DateTime.now().toUtc();
      final nowWib = nowUtc.add(const Duration(hours: 7));
      final isTodaySelected =
          selectedRange.end.year == nowWib.year &&
          selectedRange.end.month == nowWib.month &&
          selectedRange.end.day == nowWib.day;
      final hppEndDate = isTodaySelected ? nowUtc : dateWindow.end;
      final calendarEndDate = DateTime(
        selectedRange.end.year,
        selectedRange.end.month,
        selectedRange.end.day,
      );

      final summary = await supabaseService.getHppSummary(
        outletId: gerobak.outletId,
        startDate: dateWindow.start,
        endDate: hppEndDate,
        assignmentStartDate: gerobak.startDate,
      );
      final baristaCosts = await supabaseService.getInvestorBaristaCostSummary(
        outletId: gerobak.outletId,
        startBusinessDate: DateTime(
          selectedRange.start.year,
          selectedRange.start.month,
          selectedRange.start.day,
        ),
        endBusinessDate: calendarEndDate,
        assignmentStartDate: gerobak.startDate,
        calendarDays: true,
      );

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _baristaCosts = baristaCosts;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Gagal memuat laporan investor: $error');
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  Future<void> _selectGerobak(InvestorGerobak? gerobak) async {
    if (gerobak == null) return;
    setState(() => _selected = gerobak);
    await _loadReport(gerobak, _selectedRange);
  }

  Future<void> _selectDateRange() async {
    final nowWib = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateTime(nowWib.year, nowWib.month, nowWib.day);
    final initialStart = _selectedRange.start.isAfter(today)
        ? today
        : _selectedRange.start;
    final initialEnd = _selectedRange.end.isAfter(today)
        ? today
        : _selectedRange.end;
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: initialStart,
        end: initialEnd.isBefore(initialStart) ? initialStart : initialEnd,
      ),
      firstDate: DateTime(2015),
      lastDate: today,
      helpText: 'Pilih rentang laporan',
      saveText: 'Terapkan',
      cancelText: 'Batal',
    );
    if (selected == null) return;

    final range = DateTimeRange(
      start: DateTime(
        selected.start.year,
        selected.start.month,
        selected.start.day,
      ),
      end: DateTime(selected.end.year, selected.end.month, selected.end.day),
    );
    setState(() => _selectedRange = range);
    final gerobak = _selected;
    if (gerobak != null) await _loadReport(gerobak, range);
  }

  double _amount(Map<String, dynamic> values, String key) =>
      (values[key] as num?)?.toDouble() ?? 0;

  String _dateLabel(DateTime date) {
    const names = [
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
    return '${date.day} ${names[date.month - 1]} ${date.year}';
  }

  String _dateRangeLabel(DateTimeRange range) {
    return '${_dateLabel(range.start)} – ${_dateLabel(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final investorName =
        context.watch<AuthProvider>().currentUser?.name ?? 'Investor';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Laporan Investor',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Laporan kemitraan Papikopi berdasarkan rentang tanggal.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _buildGerobakPicker(),
          const SizedBox(height: 12),
          _buildPeriodPicker(),
          const SizedBox(height: 16),
          if (_errorMessage != null) ...[
            _buildError(),
            const SizedBox(height: 16),
          ],
          if (_selected == null)
            const _ReportMessage(
              icon: Icons.storefront_outlined,
              message: 'Belum ada gerobak yang diinvestasikan.',
            )
          else
            _buildMonthlyReport(investorName),
          const SizedBox(height: 24),
          _buildPortfolioSummary(),
        ],
      ),
    );
  }

  Widget _buildGerobakPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.altSurface),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<InvestorGerobak>(
          value: _selected,
          isExpanded: true,
          hint: const Text('Pilih gerobak'),
          items: _gerobakList
              .map(
                (gerobak) =>
                    DropdownMenuItem(value: gerobak, child: Text(gerobak.name)),
              )
              .toList(),
          onChanged: _selectGerobak,
        ),
      ),
    );
  }

  Widget _buildPeriodPicker() {
    return OutlinedButton.icon(
      onPressed: _selectDateRange,
      icon: const Icon(Icons.date_range_outlined),
      label: Text(
        _dateRangeLabel(_selectedRange),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildMonthlyReport(String investorName) {
    if (_reportLoading) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final gerobak = _selected!;
    final sales = _amount(_summary, 'totalSales');
    final grossProfit = _amount(_summary, 'totalProfit');
    final bonus = _baristaCosts['bonus'] ?? 0;
    final mealAllowance = _baristaCosts['mealAllowance'] ?? 0;
    final mealAllowance25Count = (_baristaCosts['mealAllowance25Count'] ?? 0)
        .toInt();
    final mealAllowance34Count = (_baristaCosts['mealAllowance34Count'] ?? 0)
        .toInt();
    final netProfit = grossProfit - bonus - mealAllowance;
    final investorShare = netProfit * gerobak.marginPercentage / 100;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.altSurface),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LAPORAN KEMITRAAN PAPIKOPI',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateRangeLabel(_selectedRange).toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _ReportMetaRow(label: 'Gerobak', value: gerobak.name),
                const SizedBox(height: 6),
                _ReportMetaRow(label: 'Mitra', value: investorName),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingRowColor: WidgetStatePropertyAll(
                AppColors.primary.withValues(alpha: 0.06),
              ),
              columns: [
                const DataColumn(label: Text('Periode')),
                const DataColumn(label: Text('Omset'), numeric: true),
                const DataColumn(label: Text('Laba kotor'), numeric: true),
                const DataColumn(
                  label: Text('Bonus + operasional'),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    '${gerobak.marginPercentage.toStringAsFixed(0)}%',
                  ),
                  numeric: true,
                ),
              ],
              rows: [
                DataRow(
                  cells: [
                    DataCell(Text(_dateRangeLabel(_selectedRange))),
                    DataCell(Text(InvestorPeriod.rupiah(sales))),
                    DataCell(Text(InvestorPeriod.rupiah(grossProfit))),
                    DataCell(
                      Text(InvestorPeriod.rupiah(bonus + mealAllowance)),
                    ),
                    DataCell(Text(InvestorPeriod.rupiah(investorShare))),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ReportAmountRow(label: 'Omset', amount: sales),
                _ReportAmountRow(label: 'Laba kotor', amount: grossProfit),
                _ReportAmountRow(label: 'Bonus barista', amount: bonus),
                _ReportAmountRow(
                  label: 'Operasional barista (uang makan)',
                  amount: mealAllowance,
                ),
                _ReportCountRow(
                  label: 'Count uang makan Rp25.000',
                  count: mealAllowance25Count,
                ),
                _ReportCountRow(
                  label: 'Count uang makan Rp34.000',
                  count: mealAllowance34Count,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _ReportAmountRow(
                  label: 'Laba bersih',
                  amount: netProfit,
                  emphasized: true,
                ),
                const SizedBox(height: 4),
                _ReportAmountRow(
                  label:
                      'Bagian investor (${gerobak.marginPercentage.toStringAsFixed(0)}%)',
                  amount: investorShare,
                  emphasized: true,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioSummary() {
    if (_assignments.isEmpty) return const SizedBox.shrink();

    final activeOutlets = _assignments
        .where((outlet) => (outlet['status'] as String?) == 'active')
        .length;
    final totalInvestment = _assignments.fold<double>(
      0,
      (total, outlet) =>
          total + ((outlet['investment_amount'] as num?)?.toDouble() ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Portofolio investasi',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PortfolioMetric(
                label: 'Total gerobak',
                value: '${_assignments.length}',
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PortfolioMetric(
                label: 'Gerobak aktif',
                value: '$activeOutlets',
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _PortfolioMetric(
          label: 'Total investasi',
          value: InvestorPeriod.rupiah(totalInvestment),
          color: AppColors.accent,
        ),
        const SizedBox(height: 12),
        for (final outlet in _assignments) _buildOutletCard(outlet),
      ],
    );
  }

  Widget _buildOutletCard(Map<String, dynamic> outlet) {
    final name =
        (outlet['outlet_name'] as String?) ??
        ((outlet['outlets'] as Map<String, dynamic>?)?['name'] as String?) ??
        'Gerobak';
    final amount = (outlet['investment_amount'] as num?)?.toDouble() ?? 0;
    final margin = (outlet['margin_percentage'] as num?)?.toDouble() ?? 0;
    final isActive = (outlet['status'] as String?) == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surface,
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${InvestorPeriod.rupiah(amount)}  •  Margin ${margin.toStringAsFixed(1)}%',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.altSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isActive ? 'AKTIF' : 'NONAKTIF',
            style: TextStyle(
              color: isActive ? AppColors.success : AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFF991B1B)),
            ),
          ),
          IconButton(
            tooltip: 'Coba lagi',
            onPressed: _selected == null
                ? _load
                : () => _loadReport(_selected!, _selectedRange),
            icon: const Icon(Icons.refresh, color: Color(0xFF991B1B)),
          ),
        ],
      ),
    );
  }
}

class _ReportMessage extends StatelessWidget {
  const _ReportMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ReportMetaRow extends StatelessWidget {
  const _ReportMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const Text(':  '),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportAmountRow extends StatelessWidget {
  const _ReportAmountRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
    this.color,
  });

  final String label;
  final double amount;
  final bool emphasized;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? AppColors.textPrimary;
    final style = TextStyle(
      color: textColor,
      fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(InvestorPeriod.rupiah(amount), style: style),
        ],
      ),
    );
  }
}

class _ReportCountRow extends StatelessWidget {
  const _ReportCountRow({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$count hari',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioMetric extends StatelessWidget {
  const _PortfolioMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
