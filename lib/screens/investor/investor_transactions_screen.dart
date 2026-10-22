import 'package:flutter/material.dart';

import '../../models/sale.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';
import 'shared/investor_data_mixin.dart';
import 'shared/investor_period_helper.dart';

/// Baris item transaksi untuk tabel (satu sale bisa punya beberapa item).
class _TxRow {
  final DateTime createdAt;
  final String menu;
  final int qty;
  final String payment; // CASH / QRIS / CARD / GRATIS
  final double amount;

  _TxRow({
    required this.createdAt,
    required this.menu,
    required this.qty,
    required this.payment,
    required this.amount,
  });
}

/// Laporan Transaksi investor sesuai mockup:
/// judul + pilih gerobak, pilihan periode, tabel
/// JAM / MENU / QTY / PEMBAYARAN / JUMLAH.
class InvestorTransactionsScreen extends StatefulWidget {
  const InvestorTransactionsScreen({super.key});

  @override
  State<InvestorTransactionsScreen> createState() =>
      _InvestorTransactionsScreenState();
}

class _InvestorTransactionsScreenState
    extends State<InvestorTransactionsScreen> with InvestorDataMixin {
  final SupabaseService _service = SupabaseService();

  List<InvestorGerobak> _gerobakList = [];
  InvestorGerobak? _selected;
  String _period = 'today'; // today | yesterday | week | month
  bool _loading = true;
  List<_TxRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_gerobakList.isEmpty) {
        final assignments = await resolveInvestorOutlets();
        _gerobakList = assignments
            .map(InvestorGerobak.fromAssignment)
            .where((g) => g.outletId.isNotEmpty)
            .toList();
        _selected ??= _gerobakList.isNotEmpty ? _gerobakList.first : null;
      }

      final rows = <_TxRow>[];
      if (_selected != null) {
        final sales = await _fetchSales(_selected!);
        for (final sale in sales) {
          for (final item in sale.items) {
            rows.add(
              _TxRow(
                createdAt: sale.createdAt,
                menu: item.productName,
                qty: item.quantity,
                payment: sale.paymentMethod,
                // Item GRATIS tidak menghasilkan pendapatan.
                amount: sale.paymentMethod.toUpperCase() == 'GRATIS'
                    ? 0
                    : item.unitPrice * item.quantity,
              ),
            );
          }
        }
        rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rows = [];
        _loading = false;
      });
    }
  }

  Future<List<Sale>> _fetchSales(InvestorGerobak g) async {
    final today = InvestorPeriod.businessDayNow();
    switch (_period) {
      case 'today':
        final win = InvestorPeriod.businessDayUtc(today);
        return _service.getSalesByDateRange(
          outletId: g.outletId,
          startDate: win.start,
          endDate: win.end,
        );
      case 'yesterday':
        final win = InvestorPeriod.businessDayUtc(
          today.subtract(const Duration(days: 1)),
        );
        return _service.getSalesByDateRange(
          outletId: g.outletId,
          startDate: win.start,
          endDate: win.end,
        );
      case 'week':
        final win = InvestorPeriod.lastNDaysUtc(today, 7);
        return _service.getSalesByDateRange(
          outletId: g.outletId,
          startDate: win.start,
          endDate: win.end,
        );
      case 'month':
      default:
        final win = InvestorPeriod.businessMonthUtc(today);
        return _service.getSalesByDateRange(
          outletId: g.outletId,
          startDate: win.start,
          endDate: win.end,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading && _rows.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Laporan Transaksi',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildGerobakPicker(),
                const SizedBox(height: 12),
                const Text(
                  'Pilih periode:',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPeriodPicker(),
                const SizedBox(height: 20),
                const Text(
                  'Daftar Transaksi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTable(),
              ],
            ),
          );
  }

  Widget _buildGerobakPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront, color: AppColors.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pilih Gerobak',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<InvestorGerobak>(
                    value: _selected,
                    isDense: true,
                    isExpanded: true,
                    items: _gerobakList
                        .map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Text(
                              g.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (g) {
                      if (g == null || g == _selected) return;
                      setState(() {
                        _selected = g;
                        _loading = true;
                      });
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _period,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'today', child: Text('Hari ini')),
                  DropdownMenuItem(value: 'yesterday', child: Text('Kemarin')),
                  DropdownMenuItem(
                      value: 'week', child: Text('7 Hari terakhir')),
                  DropdownMenuItem(value: 'month', child: Text('Bulan ini')),
                ],
                onChanged: (v) {
                  if (v == null || v == _period) return;
                  setState(() {
                    _period = v;
                    _loading = true;
                  });
                  _load();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    if (_rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'Tidak ada transaksi pada periode ini',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header tabel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F3F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: _HeaderText('JAM')),
                Expanded(flex: 4, child: _HeaderText('MENU')),
                Expanded(
                  flex: 2,
                  child: _HeaderText('QTY', center: true),
                ),
                Expanded(flex: 4, child: _HeaderText('PEMBAYARAN')),
                Expanded(
                  flex: 3,
                  child: _HeaderText('JUMLAH', end: true),
                ),
              ],
            ),
          ),
          ..._buildRowsWithDateSeparators(),
        ],
      ),
    );
  }

  /// Susun baris tabel, menyisipkan baris separator tanggal setiap
  /// berganti hari bisnis (WIB). Rows sudah terurut terbaru -> terlama.
  List<Widget> _buildRowsWithDateSeparators() {
    final widgets = <Widget>[];
    String? lastDate;
    for (final r in _rows) {
      final wib = r.createdAt.toUtc().add(const Duration(hours: 7));
      final dateKey =
          '${wib.year}-${wib.month.toString().padLeft(2, '0')}-${wib.day.toString().padLeft(2, '0')}';
      if (dateKey != lastDate) {
        lastDate = dateKey;
        widgets
          ..add(Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFFE8F4F8),
            child: Text(
              InvestorPeriod.formatDateWib(r.createdAt),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ))
          ..add(_buildRow(r));
      } else {
        widgets.add(_buildRow(r));
      }
    }
    return widgets;
  }

  Widget _buildRow(_TxRow r) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              InvestorPeriod.formatTimeWib(r.createdAt),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              r.menu,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${r.qty}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _PaymentChip(payment: r.payment),
          ),
          Expanded(
            flex: 3,
            child: Text(
              InvestorPeriod.rupiah(r.amount),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  final bool center;
  final bool end;

  const _HeaderText(this.text, {this.center = false, this.end = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : (end ? TextAlign.end : TextAlign.start),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String payment;

  const _PaymentChip({required this.payment});

  @override
  Widget build(BuildContext context) {
    final p = payment.toUpperCase();
    final isQris = p == 'QRIS';
    final isGratis = p == 'GRATIS';
    final label = isGratis ? 'GRATIS' : (isQris ? 'QRIS' : 'Cash');
    final color = isGratis
        ? AppColors.accent
        : isQris
            ? const Color(0xFF2563EB)
            : const Color(0xFF16A34A);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
