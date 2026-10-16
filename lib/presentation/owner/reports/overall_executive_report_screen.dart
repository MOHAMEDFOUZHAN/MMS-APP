import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/formatters/quantity_formatter.dart';
import '../../../core/theme/glass_widgets.dart';
import '../../providers/owner_providers.dart';
import '../../providers/tea_consumption_providers.dart';

class OverallExecutiveReportScreen extends ConsumerWidget {
  const OverallExecutiveReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerDashboardAsync = ref.watch(ownerDashboardSummaryProvider);
    final teaSummaryAsync = ref.watch(teaDepartmentSummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.corporate_fare_rounded, color: Color(0xFF6366F1), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Enterprise Overall Operations Report',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: AmbientBackground(
        child: ownerDashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading dashboard: $e', style: const TextStyle(color: AppColors.danger))),
          data: (summary) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. High-Level Executive KPI Cards
                  Text(
                    'FACTORY-WIDE CORE METRICS',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      final cardWidth = isWide ? (constraints.maxWidth - 16) / 3 : constraints.maxWidth;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _executiveKpiCard('Total Raw Materials', '${summary.kpi.totalMaterials} Items', 'Valuation: ₹${QuantityFormatter.formatClean(summary.invoices.totalPurchaseVal)}', const Color(0xFF6366F1), cardWidth),
                          _executiveKpiCard('Finished Goods in Storage', '${QuantityFormatter.formatClean(summary.kpi.totalStorageStock)} units', '${summary.kpi.activeBatchesCnt} Active Batches', const Color(0xFF06B6D4), cardWidth),
                          _executiveKpiCard('Total Dispatches', '${QuantityFormatter.formatClean(summary.dispatches.totalDispatchQty)} units', '${summary.dispatches.monthDispatchCnt} Consignments this month', const Color(0xFF10B981), cardWidth),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // 2. Departmental Breakdown Section
                  Text(
                    'DEPARTMENTAL ACTIVITY COMPARISON',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 10),

                  // Tea Department Overview
                  teaSummaryAsync.maybeWhen(
                    data: (tea) => _departmentCard(
                      title: 'TEA DEPARTMENT',
                      badgeColor: const Color(0xFF10B981),
                      icon: Icons.eco_rounded,
                      rows: [
                        _metricRow('Raw Materials Transferred In', '${QuantityFormatter.formatClean(tea.totalTransferredIn)} kg'),
                        _metricRow('Materials Taken for Work', '${QuantityFormatter.formatClean(tea.totalTaken)} kg'),
                        _metricRow('Evening Balances Returned', '${QuantityFormatter.formatClean(tea.totalBalanceReturned)} kg'),
                        _metricRow('Net Factory Consumed', '${QuantityFormatter.formatClean(tea.totalNetConsumed)} kg', isBold: true, highlightColor: const Color(0xFF10B981)),
                        _metricRow('Current Floor Balance', '${QuantityFormatter.formatClean(tea.currentTeaStock)} kg', highlightColor: const Color(0xFF06B6D4)),
                      ],
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 12),

                  // Overall Warehouse & Transfers
                  _departmentCard(
                    title: 'CENTRAL WAREHOUSE & LOGISTICS',
                    badgeColor: const Color(0xFFF59E0B),
                    icon: Icons.warehouse_rounded,
                    rows: [
                      _metricRow('Today Inward Purchases', '₹${QuantityFormatter.formatClean(summary.today.todayPurchasesVal)}'),
                      _metricRow('Today Internal Transfers Out', '${QuantityFormatter.formatClean(summary.today.todayTransferOut)} kg'),
                      _metricRow('Today Returns from Floor', '${QuantityFormatter.formatClean(summary.today.todayTransferRet)} kg'),
                      _metricRow('Today Finished Goods Dispatched', '${QuantityFormatter.formatClean(summary.today.todayDispatchQty)} units'),
                      _metricRow('Active Storage Batches', '${summary.storage.activeBatches} active', highlightColor: const Color(0xFF06B6D4)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 3. Alerts & Inventory Health
                  Text(
                    'INVENTORY HEALTH & AUDIT',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: Column(
                      children: [
                        _metricRow('Low Stock Raw Materials', '${summary.kpi.lowStockCnt} items', highlightColor: const Color(0xFFF59E0B)),
                        const Divider(height: 16, color: Color(0xFF1F2937)),
                        _metricRow('Out of Stock Raw Materials', '${summary.kpi.outOfStockCnt} items', highlightColor: const Color(0xFFEF4444)),
                        const Divider(height: 16, color: Color(0xFF1F2937)),
                        _metricRow('Expiring Batches (Monitor)', '${summary.kpi.expiringSoonCnt} batches', highlightColor: const Color(0xFFF97316)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _executiveKpiCard(String title, String mainValue, String subValue, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Text(mainValue, style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(subValue, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _departmentCard({
    required String title,
    required Color badgeColor,
    required IconData icon,
    required List<Widget> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: badgeColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Colors.white),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFF1F2937)),
          ...rows,
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, {bool isBold = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isBold ? Colors.white : AppColors.textMuted, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: highlightColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
