import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/responsive/responsive_breakpoints.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/dashboard_summary_model.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../dispatch/add_dispatch_screen.dart';
import '../invoices/add_invoice_screen.dart';
import '../invoices/ocr_scan_screen.dart';
import '../invoices/without_invoice_screen.dart';
import '../providers/app_providers.dart';
import '../transfers/add_transfer_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final isTablet = ResponsiveBreakpoints.isTabletOrLarger(context);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        ref.invalidate(dashboardSummaryProvider);
      },
      child: summaryAsync.when(
        loading: () => const LoadingSkeletonList(count: 5),
        error: (err, stack) => Center(
          child: EmptyStateWidget(
            icon: Icons.error_outline_rounded,
            title: 'Failed to load Dashboard',
            message: err.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(dashboardSummaryProvider),
          ),
        ),
        data: (summary) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Actions Carousel / Row
                _buildQuickActions(context),
                const SizedBox(height: 20),

                // KPI Section (Responsive Grid for Tablet, Carousel/Grid for Mobile)
                Text(
                  'Key Performance Indicators',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildKpiSection(context, summary, isTablet),
                const SizedBox(height: 24),

                // Charts & Analytics Section
                if (isTablet)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _buildCategoryBreakdownCard(summary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: _buildTopMaterialsCard(summary),
                      ),
                    ],
                  )
                else ...[
                  _buildCategoryBreakdownCard(summary),
                  const SizedBox(height: 20),
                  _buildTopMaterialsCard(summary),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildQuickActionBtn(
            context,
            icon: Icons.receipt_long_rounded,
            label: '+ Add Invoice',
            color: AppColors.primary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddInvoiceScreen())),
          ),
          const SizedBox(width: 10),
          _buildQuickActionBtn(
            context,
            icon: Icons.local_shipping_rounded,
            label: 'FIFO Dispatch',
            color: AppColors.secondary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDispatchScreen())),
          ),
          const SizedBox(width: 10),
          _buildQuickActionBtn(
            context,
            icon: Icons.swap_horiz_rounded,
            label: 'Transfer Out',
            color: AppColors.accent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransferScreen())),
          ),
          const SizedBox(width: 10),
          _buildQuickActionBtn(
            context,
            icon: Icons.document_scanner_rounded,
            label: 'Scan OCR',
            color: AppColors.warning,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OcrScanScreen())),
          ),
          const SizedBox(width: 10),
          _buildQuickActionBtn(
            context,
            icon: Icons.flash_on_rounded,
            label: 'Fast Import',
            color: AppColors.success,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WithoutInvoiceScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiSection(BuildContext context, DashboardSummaryModel summary, bool isTablet) {
    final kpis = [
      _KpiItem(
        title: 'Total Materials',
        value: summary.totalMaterials.toString(),
        subtitle: 'Tracked inventory items',
        icon: Icons.inventory_2_rounded,
        color: AppColors.primary,
      ),
      _KpiItem(
        title: 'Reorder Needed',
        value: summary.reorderItems.toString(),
        subtitle: 'At or below threshold',
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
      ),
      _KpiItem(
        title: 'Expiring in 30d',
        value: summary.expiringSoon.toString(),
        subtitle: 'Urgent usage recommended',
        icon: Icons.timer_outlined,
        color: const Color(0xFFF97316),
      ),
      _KpiItem(
        title: 'Out of Stock',
        value: summary.outOfStock.toString(),
        subtitle: 'Zero availability lots',
        icon: Icons.highlight_off_rounded,
        color: AppColors.danger,
      ),
      _KpiItem(
        title: 'Pending Invoices',
        value: summary.pendingInvoices.toString(),
        subtitle: 'Awaiting vendor payment',
        icon: Icons.pending_actions_rounded,
        color: AppColors.accent,
      ),
      _KpiItem(
        title: 'Storage Batches',
        value: summary.activeBatches.toString(),
        subtitle: 'Available for dispatch',
        icon: Icons.layers_rounded,
        color: AppColors.primaryLight,
      ),
      _KpiItem(
        title: "Today's Invoices",
        value: QuantityFormatter.formatCurrency(summary.todayPurchaseValue),
        subtitle: 'New inward invoice value',
        icon: Icons.payments_rounded,
        color: AppColors.success,
      ),
    ];

    if (isTablet) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2.1,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: kpis.length,
        itemBuilder: (context, i) => _buildKpiCard(kpis[i]),
      );
    } else {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.45,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: kpis.length,
        itemBuilder: (context, i) => _buildKpiCard(kpis[i]),
      );
    }
  }

  Widget _buildKpiCard(_KpiItem item) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      accentColor: item.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 14, color: item.color),
              ),
            ],
          ),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownCard(DashboardSummaryModel summary) {
    final list = summary.categoryBreakdown;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stock by Category',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              NeonPill(
                label: '${list.length} Categories',
                color: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text('No categories with stock found', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else ...[
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (list.map((e) => e.totalQuantity).reduce((a, b) => a > b ? a : b) * 1.25),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.surface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final cat = list[group.x.toInt()];
                        return BarTooltipItem(
                          '${cat.category}\n',
                          const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                          children: [
                            TextSpan(
                              text: '${QuantityFormatter.formatClean(rod.toY)} items',
                              style: const TextStyle(color: AppColors.accent, fontSize: 11),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (val, meta) => Text(
                          val.toInt().toString(),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < list.length) {
                            final name = list[idx].category;
                            final shortName = name.length > 5 ? '${name.substring(0, 4)}..' : name;
                            return Text(
                              shortName,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (val) => FlLine(color: AppColors.glassBorder, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: list.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: item.totalQuantity,
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 14,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Category detail list
            ...list.take(4).map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          c.category,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ),
                      Text(
                        '${QuantityFormatter.formatClean(c.totalQuantity)} (${c.itemCount} items)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildTopMaterialsCard(DashboardSummaryModel summary) {
    final list = summary.topMaterials;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Stocked Materials',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Icon(Icons.star_rounded, size: 18, color: AppColors.warning),
            ],
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('No materials found', style: TextStyle(color: AppColors.textMuted))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 14),
              itemBuilder: (context, i) {
                final item = list[i];
                return Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          Text(
                            item.materialCode,
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      QuantityFormatter.formatDualUnit(item.quantity, item.unit),
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _KpiItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  _KpiItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
