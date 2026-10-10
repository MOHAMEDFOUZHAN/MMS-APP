import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/owner_dashboard_model.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../providers/owner_providers.dart';

class OwnerAnalyticsScreen extends ConsumerStatefulWidget {
  const OwnerAnalyticsScreen({super.key});

  @override
  ConsumerState<OwnerAnalyticsScreen> createState() => _OwnerAnalyticsScreenState();
}

class _OwnerAnalyticsScreenState extends ConsumerState<OwnerAnalyticsScreen> {
  String _dispatchRange = '30D'; // 7D, 30D, 3M, 1Y
  String _purchaseInterval = 'Daily'; // Daily, Weekly, Monthly

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(ownerDashboardSummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Text(
          'Executive Analytics & Trends',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Analytics',
            onPressed: () => ref.invalidate(ownerDashboardSummaryProvider),
          ),
        ],
      ),
      body: AmbientBackground(
        child: summaryAsync.when(
          loading: () => const LoadingSkeletonList(count: 6),
          error: (e, _) => Center(
            child: Text('Error loading analytics: $e', style: const TextStyle(color: AppColors.danger)),
          ),
          data: (summary) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Dispatch Trend Chart (Selectable: 7D, 30D, 3M, 1Y)
                  _buildDispatchTrendCard(summary),
                  const SizedBox(height: 16),

                  // 2. Purchase Trend Chart
                  _buildPurchaseTrendCard(summary),
                  const SizedBox(height: 16),

                  // 3. Transfer Trend Chart
                  _buildTransferTrendCard(summary),
                  const SizedBox(height: 16),

                  // 4. Two-Column Distribution Charts (Category & Storage)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 768;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildCategoryDistributionCard(summary)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildStorageDistributionCard(summary)),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _buildCategoryDistributionCard(summary),
                          const SizedBox(height: 16),
                          _buildStorageDistributionCard(summary),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 5. Reorder & Expiry Risk Overview
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 768;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildReorderRiskCard(summary)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildExpiryRiskCard(summary)),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _buildReorderRiskCard(summary),
                          const SizedBox(height: 16),
                          _buildExpiryRiskCard(summary),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Dispatch Trend Chart ───────────────────────────────────────────────────
  Widget _buildDispatchTrendCard(OwnerDashboardSummary summary) {
    final trend = summary.dispatches.dispatchTrend;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;
              final headerInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DISPATCH TREND',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: const Color(0xFF06B6D4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total Finished Goods Dispatched: ${QuantityFormatter.formatClean(summary.dispatches.totalDispatchQty)} units',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              );
              final selectors = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['7D', '30D', '3M', '1Y'].map((rng) {
                    final isSel = _dispatchRange == rng;
                    return InkWell(
                      onTap: () => setState(() => _dispatchRange = rng),
                      child: Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF06B6D4).withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSel ? const Color(0xFF06B6D4) : const Color(0xFF374151),
                          ),
                        ),
                        child: Text(
                          rng,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? const Color(0xFF06B6D4) : AppColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerInfo,
                    const SizedBox(height: 10),
                    selectors,
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: headerInfo),
                  const SizedBox(width: 8),
                  selectors,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: trend.isEmpty
                ? const Center(child: Text('No dispatch activity recorded in period', style: TextStyle(color: AppColors.textMuted, fontSize: 12)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFF1F2937), strokeWidth: 1),
                      ),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: trend.asMap().entries.map((e) {
                            final q = (e.value['quantity'] as num?)?.toDouble() ?? 0.0;
                            return FlSpot(e.key.toDouble(), q);
                          }).toList(),
                          isCurved: true,
                          color: const Color(0xFF06B6D4),
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Purchase Trend Chart ───────────────────────────────────────────────────
  Widget _buildPurchaseTrendCard(OwnerDashboardSummary summary) {
    final trend = summary.invoices.purchaseTrend;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;
              final headerInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PURCHASE INWARD TREND',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total Procurement Value: ₹${summary.invoices.totalPurchaseVal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              );
              final selectors = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Daily', 'Weekly', 'Monthly'].map((interv) {
                    final isSel = _purchaseInterval == interv;
                    return InkWell(
                      onTap: () => setState(() => _purchaseInterval = interv),
                      child: Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF6366F1).withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSel ? const Color(0xFF6366F1) : const Color(0xFF374151),
                          ),
                        ),
                        child: Text(
                          interv,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? const Color(0xFF6366F1) : AppColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerInfo,
                    const SizedBox(height: 10),
                    selectors,
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: headerInfo),
                  const SizedBox(width: 8),
                  selectors,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: trend.isEmpty
                ? const Center(child: Text('No purchase invoice activity recorded in period', style: TextStyle(color: AppColors.textMuted, fontSize: 12)))
                : BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      barGroups: trend.asMap().entries.map((e) {
                        final val = (e.value['value'] as num?)?.toDouble() ?? 0.0;
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: val > 0 ? val : 1.0,
                              color: const Color(0xFF6366F1),
                              width: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Transfer Trend Chart ───────────────────────────────────────────────────
  Widget _buildTransferTrendCard(OwnerDashboardSummary summary) {
    final trend = summary.transfers.transferTrend;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INTERNAL TRANSFER & RETURN TREND',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Net Consumed (Outward - Returns): ${QuantityFormatter.formatClean(summary.transfers.netConsumed)} units',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: trend.isEmpty
                ? const Center(child: Text('No transfer movements recorded in period', style: TextStyle(color: AppColors.textMuted, fontSize: 12)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFF1F2937), strokeWidth: 1),
                      ),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: trend.asMap().entries.map((e) {
                            final out = (e.value['outward'] as num?)?.toDouble() ?? 0.0;
                            return FlSpot(e.key.toDouble(), out);
                          }).toList(),
                          isCurved: true,
                          color: const Color(0xFF10B981),
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: trend.asMap().entries.map((e) {
                            final ret = (e.value['returns'] as num?)?.toDouble() ?? 0.0;
                            return FlSpot(e.key.toDouble(), ret);
                          }).toList(),
                          isCurved: true,
                          color: const Color(0xFFF59E0B),
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Category Stock Distribution ────────────────────────────────────────────
  Widget _buildCategoryDistributionCard(OwnerDashboardSummary summary) {
    final dist = summary.materials.distribution;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RAW MATERIAL CATEGORY STOCK',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 12),
          if (dist.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No categories with stock', style: TextStyle(color: AppColors.textMuted, fontSize: 12))))
          else
            ...dist.take(5).map((d) {
              final cat = d['category']?.toString() ?? 'General';
              final qty = (d['total_quantity'] as num?)?.toDouble() ?? 0.0;
              final cnt = (d['item_count'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$cat ($cnt items)',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${QuantityFormatter.formatClean(qty)} kg',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Storage Stock Distribution ─────────────────────────────────────────────
  Widget _buildStorageDistributionCard(OwnerDashboardSummary summary) {
    final dist = summary.storage.distribution;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STORAGE FINISHED GOODS STOCK',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 12),
          if (dist.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No storage products with stock', style: TextStyle(color: AppColors.textMuted, fontSize: 12))))
          else
            ...dist.take(5).map((d) {
              final dept = d['department']?.toString() ?? 'Finished Goods';
              final qty = (d['total_quantity'] as num?)?.toDouble() ?? 0.0;
              final cnt = (d['batch_count'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$dept ($cnt batches)',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      QuantityFormatter.formatClean(qty),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Reorder Risk Card ──────────────────────────────────────────────────────
  Widget _buildReorderRiskCard(OwnerDashboardSummary summary) {
    final riskItems = summary.topLists.reorderRisk;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOP REORDER RISKS (DEFICIT)',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: const Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(height: 12),
          if (riskItems.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('No materials below reorder level', style: TextStyle(color: AppColors.textMuted, fontSize: 12)))
          else
            ...riskItems.take(5).map((it) {
              final code = it['material_code']?.toString() ?? '';
              final desc = it['description']?.toString() ?? code;
              final cur = (it['quantity'] as num?)?.toDouble() ?? 0.0;
              final reo = (it['reorder_level'] as num?)?.toDouble() ?? 0.0;
              final unit = it['unit']?.toString() ?? 'kg';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(code, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Text(
                      '${QuantityFormatter.formatClean(cur)} / $reo $unit',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Expiry Risk Card ───────────────────────────────────────────────────────
  Widget _buildExpiryRiskCard(OwnerDashboardSummary summary) {
    final expMaterials = summary.expiryMonitor.invoiceMaterials;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SHELF-LIFE EXPIRY RISKS',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 12),
          if (expMaterials.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('No upcoming shelf-life expiries in window', style: TextStyle(color: AppColors.textMuted, fontSize: 12)))
          else
            ...expMaterials.take(5).map((it) {
              final code = it['material_code']?.toString() ?? '';
              final desc = it['description']?.toString() ?? code;
              final days = (it['days_remaining'] as num?)?.toInt() ?? 0;
              final qty = (it['quantity'] as num?)?.toDouble() ?? 0.0;
              final unit = it['unit']?.toString() ?? 'kg';
              final isExp = days < 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(code, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isExp ? 'EXPIRED (${-days}d ago)' : '$days days left',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isExp ? AppColors.danger : const Color(0xFFF97316),
                          ),
                        ),
                        Text('${QuantityFormatter.formatClean(qty)} $unit', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
