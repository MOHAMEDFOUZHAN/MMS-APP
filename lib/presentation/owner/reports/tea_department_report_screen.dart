import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/formatters/app_date_formatter.dart';
import '../../../core/formatters/quantity_formatter.dart';
import '../../../core/theme/glass_widgets.dart';
import '../../../data/models/tea_consumption_model.dart';
import '../../../data/repositories/tea_consumption_repository.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/global_search_filter_bar.dart';
import '../../providers/tea_consumption_providers.dart';

class TeaDepartmentReportScreen extends ConsumerStatefulWidget {
  const TeaDepartmentReportScreen({super.key});

  @override
  ConsumerState<TeaDepartmentReportScreen> createState() => _TeaDepartmentReportScreenState();
}

class _TeaDepartmentReportScreenState extends ConsumerState<TeaDepartmentReportScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _search = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = TeaConsumptionFilter(
      search: _search.isNotEmpty ? _search : null,
      fromDate: _fromDate,
      toDate: _toDate,
    );

    final summaryAsync = ref.watch(teaDepartmentSummaryProvider);
    final materialsAsync = ref.watch(teaTransferredMaterialsProvider);
    final consumptionAsync = ref.watch(teaConsumptionListProvider(filter));

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.eco_rounded, color: Color(0xFF10B981), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Tea Department Executive Report',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Material Movements & Balances'),
            Tab(text: 'Consumption & Night Reconciliations'),
          ],
        ),
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            // KPI Summary Header
            summaryAsync.maybeWhen(
              data: (summary) => _buildKpiRow(summary),
              orElse: () => const SizedBox.shrink(),
            ),

            // Search & Filter
            GlobalSearchFilterBar(
              hintText: 'Filter by Code or Description...',
              initialSearch: _search,
              initialFromDate: _fromDate,
              initialToDate: _toDate,
              onSearchChanged: (val) => setState(() => _search = val),
              onApply: (search, from, to) => setState(() {
                _search = search;
                _fromDate = from;
                _toDate = to;
              }),
              onClear: () => setState(() {
                _search = '';
                _fromDate = null;
                _toDate = null;
              }),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Material Balances
                  materialsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.danger))),
                    data: (materials) {
                      final filtered = materials.where((m) {
                        if (_search.isEmpty) return true;
                        final q = _search.toLowerCase();
                        return m.code.toLowerCase().contains(q) || m.description.toLowerCase().contains(q);
                      }).toList();

                      if (filtered.isEmpty) {
                        return const EmptyStateWidget(
                          icon: Icons.inventory_2_outlined,
                          title: 'No Materials Found',
                          message: 'No raw material transfers match your query.',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final mat = filtered[i];
                          return _buildMaterialRowCard(mat);
                        },
                      );
                    },
                  ),

                  // Tab 2: Consumption Ledger
                  consumptionAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.danger))),
                    data: (entries) {
                      if (entries.isEmpty) {
                        return const EmptyStateWidget(
                          icon: Icons.history_rounded,
                          title: 'No Consumption Records',
                          message: 'No material usage or night reconciliations recorded for this period.',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final entry = entries[i];
                          return _buildConsumptionRowCard(entry);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(TeaDepartmentSummary summary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _kpiBox('Transferred to Tea', '${QuantityFormatter.formatClean(summary.totalTransferredIn)} kg', const Color(0xFF06B6D4), isWide ? (constraints.maxWidth - 24) / 4 : (constraints.maxWidth - 8) / 2),
              _kpiBox('Taken for Work', '${QuantityFormatter.formatClean(summary.totalTaken)} kg', const Color(0xFFF59E0B), isWide ? (constraints.maxWidth - 24) / 4 : (constraints.maxWidth - 8) / 2),
              _kpiBox('Night Balance Returned', '${QuantityFormatter.formatClean(summary.totalBalanceReturned)} kg', const Color(0xFF8B5CF6), isWide ? (constraints.maxWidth - 24) / 4 : (constraints.maxWidth - 8) / 2),
              _kpiBox('Net Factory Consumed', '${QuantityFormatter.formatClean(summary.totalNetConsumed)} kg', const Color(0xFF10B981), isWide ? (constraints.maxWidth - 24) / 4 : (constraints.maxWidth - 8) / 2),
            ],
          );
        },
      ),
    );
  }

  Widget _kpiBox(String title, String value, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildMaterialRowCard(TeaTransferredMaterial mat) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF10B981), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mat.description, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('CODE: ${mat.code}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Live Floor Balance', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
              Text(
                '${QuantityFormatter.formatClean(mat.currentBalance)} ${mat.units}',
                style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
              ),
              Text(
                'Transferred: ${QuantityFormatter.formatClean(mat.netTransferred)} | Consumed: ${QuantityFormatter.formatClean(mat.totalConsumed)}',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsumptionRowCard(TeaConsumptionModel item) {
    final dateStr = AppDateFormatter.format(item.date);
    final timeStr = DateFormat('hh:mm a').format(item.createdAt.toLocal());
    final isClosed = item.status == 'CLOSED' || item.balanceQty > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isClosed ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('${item.description} (${item.materialCode})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isClosed ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isClosed ? 'Reconciled' : 'Pending Balance',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isClosed ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('$dateStr at $timeStr', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textMuted)),
              if (item.operatorName.isNotEmpty) ...[
                const SizedBox(width: 10),
                const Icon(Icons.person_outline, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(item.operatorName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ],
          ),
          const Divider(height: 16, color: Color(0xFF1F2937)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Taken: ${QuantityFormatter.formatClean(item.takenQty)} ${item.unit}', style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B))),
              Text('Returned: ${QuantityFormatter.formatClean(item.balanceQty)} ${item.unit}', style: const TextStyle(fontSize: 11, color: Color(0xFF8B5CF6))),
              Text('Net Consumed: ${QuantityFormatter.formatClean(item.consumedQty)} ${item.unit}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            ],
          ),
        ],
      ),
    );
  }
}
