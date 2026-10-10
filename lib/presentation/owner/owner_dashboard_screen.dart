import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/owner_dashboard_model.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../materials/materials_screen.dart';
import '../reports/material_directory_report.dart';
import '../reports/out_of_stock_report.dart';
import '../reports/reorder_report.dart';
import '../reports/storage_report.dart';
import '../providers/owner_providers.dart';
import 'reports/owner_expiring_report_screen.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(ownerDashboardSummaryProvider);
    final dateFilter = ref.watch(ownerDateFilterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: AmbientBackground(
        child: RefreshIndicator(
          color: const Color(0xFFF59E0B),
          backgroundColor: const Color(0xFF1F2937),
          onRefresh: () async {
            ref.invalidate(ownerDashboardSummaryProvider);
          },
          child: summaryAsync.when(
            loading: () => const LoadingSkeletonList(count: 8),
            error: (err, stack) => Center(
              child: EmptyStateWidget(
                icon: Icons.error_outline_rounded,
                title: 'Failed to load Executive Dashboard',
                message: err.toString(),
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(ownerDashboardSummaryProvider),
              ),
            ),
            data: (summary) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header & Global Date Filter Bar ──────────────────────
                    _buildDateFilterBar(context, ref, dateFilter),
                    const SizedBox(height: 16),

                    // ── Section 5: Top 12 KPIs Carousel / Grid ───────────────
                    _buildSectionHeader('TOP EXECUTIVE KEY PERFORMANCE INDICATORS', const Color(0xFFF59E0B)),
                    const SizedBox(height: 10),
                    _buildTopKpis(context, summary.kpi),
                    const SizedBox(height: 24),

                    // ── Section 6: Today's Business Snapshot ─────────────────
                    _buildSectionHeader("TODAY'S BUSINESS SNAPSHOT", const Color(0xFF06B6D4)),
                    const SizedBox(height: 10),
                    _buildTodaySnapshot(summary.today),
                    const SizedBox(height: 24),

                    // ── Section 7: Inventory Health (Tap -> Opens Reports) ───
                    _buildSectionHeader('INVENTORY HEALTH & STATUS', const Color(0xFF10B981)),
                    const SizedBox(height: 10),
                    _buildInventoryHealth(context, summary.health),
                    const SizedBox(height: 24),

                    // ── Two Column: Storage Overview & Material Overview ────
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 840;
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildStorageOverview(context, summary.storage)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildMaterialOverview(context, summary.materials)),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _buildStorageOverview(context, summary.storage),
                            const SizedBox(height: 16),
                            _buildMaterialOverview(context, summary.materials),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Two Column: Invoices Overview & Dispatches Overview ──
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 840;
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildInvoiceOverview(summary.invoices)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildDispatchOverview(summary.dispatches)),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _buildInvoiceOverview(summary.invoices),
                            const SizedBox(height: 16),
                            _buildDispatchOverview(summary.dispatches),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Transfers Overview & Net Consumption ─────────────────
                    _buildTransferOverview(summary.transfers),
                    const SizedBox(height: 24),

                    // ── Expiry Monitor (Invoice Materials vs Storage) ────────
                    _buildExpiryMonitorSection(context, summary.expiryMonitor),
                    const SizedBox(height: 24),

                    // ── Alert Center & Recent Activity ───────────────────────
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 840;
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: _buildAlertCenter(context, summary.alerts)),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: _buildRecentActivity(summary.recentActivity)),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _buildAlertCenter(context, summary.alerts),
                            const SizedBox(height: 16),
                            _buildRecentActivity(summary.recentActivity),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Date Filter Bar ────────────────────────────────────────────────────────
  Widget _buildDateFilterBar(BuildContext context, WidgetRef ref, OwnerDateFilter current) {
    final filters = [
      OwnerDateFilterType.allTime,
      OwnerDateFilterType.today,
      OwnerDateFilterType.yesterday,
      OwnerDateFilterType.last7Days,
      OwnerDateFilterType.last30Days,
      OwnerDateFilterType.thisMonth,
      OwnerDateFilterType.lastMonth,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, size: 16, color: Color(0xFFF59E0B)),
            const SizedBox(width: 10),
            Text(
              'DATE FILTER:',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(width: 10),
            ...filters.map((f) {
              final isSel = current.type == f;
              final label = OwnerDateFilter(type: f).label;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () {
                    ref.read(ownerDateFilterProvider.notifier).state = OwnerDateFilter(type: f);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSel ? const Color(0xFFF59E0B) : const Color(0xFF374151),
                      ),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Section 5: Top 12 KPIs ─────────────────────────────────────────────────
  Widget _buildTopKpis(BuildContext context, OwnerKpiData kpi) {
    final kpis = [
      _KpiItem('TOTAL MATERIALS', kpi.totalMaterials.toString(), 'Catalog Master', Icons.inventory_2_outlined, const Color(0xFF6366F1)),
      _KpiItem('STORAGE PRODUCTS', kpi.activeStorageProducts.toString(), 'Active Catalog', Icons.category_outlined, const Color(0xFF3B82F6)),
      _KpiItem('STORAGE STOCK', QuantityFormatter.formatClean(kpi.totalStorageStock), 'Finished Goods', Icons.layers_outlined, const Color(0xFF06B6D4)),
      _KpiItem('TOTAL PURCHASES', '₹${QuantityFormatter.formatClean(kpi.totalPurchasesVal)}', '${kpi.totalPurchasesCnt} Invoices', Icons.receipt_long_outlined, const Color(0xFF10B981)),
      _KpiItem('TOTAL DISPATCHED', QuantityFormatter.formatClean(kpi.totalDispatchedQty), '${kpi.totalDispatchedCnt} Outward', Icons.local_shipping_outlined, const Color(0xFF8B5CF6)),
      _KpiItem('TOTAL TRANSFERRED', QuantityFormatter.formatClean(kpi.totalTransferredNet), 'Net Consumption', Icons.swap_horiz_rounded, const Color(0xFFF59E0B)),
      _KpiItem('OUT OF STOCK', kpi.outOfStockCnt.toString(), 'Depleted Items', Icons.remove_circle_outline_rounded, AppColors.danger),
      _KpiItem('LOW STOCK / REORDER', kpi.lowStockCnt.toString(), 'At/Below Min', Icons.warning_amber_rounded, const Color(0xFFF97316)),
      _KpiItem('EXPIRING SOON', kpi.expiringSoonCnt.toString(), 'In Alert Window', Icons.timer_outlined, const Color(0xFFEAB308)),
      _KpiItem('PENDING INVOICES', kpi.pendingInvoicesCnt.toString(), '₹${QuantityFormatter.formatClean(kpi.pendingInvoicesVal)}', Icons.pending_actions_rounded, const Color(0xFFEC4899)),
      _KpiItem('TOTAL VENDORS', kpi.totalVendorsCnt.toString(), 'Suppliers', Icons.storefront_outlined, const Color(0xFF14B8A6)),
      _KpiItem('ACTIVE BATCHES', kpi.activeBatchesCnt.toString(), 'In Stock Batches', Icons.view_in_ar_rounded, const Color(0xFF38BDF8)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossCount;
        final double extent;

        if (width < 340) {
          crossCount = 1;
          extent = 88;
        } else if (width < 600) {
          crossCount = 2;
          extent = 90;
        } else if (width < 900) {
          crossCount = 3;
          extent = 92;
        } else if (width < 1200) {
          crossCount = 4;
          extent = 96;
        } else {
          crossCount = 6;
          extent = 96;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: extent,
          ),
          itemCount: kpis.length,
          itemBuilder: (context, i) => _buildKpiCard(kpis[i]),
        );
      },
    );
  }

  Widget _buildKpiCard(_KpiItem kpi) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  kpi.title,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: const Color(0xFF9CA3AF),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(kpi.icon, size: 14, color: kpi.accent),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              kpi.value,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            kpi.subtitle,
            style: TextStyle(fontSize: 9.5, color: kpi.accent, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Section 6: Today's Business Snapshot ───────────────────────────────────
  Widget _buildTodaySnapshot(OwnerTodaySnapshot today) {
    final items = [
      _TodayItem("Today's Purchases", '₹${QuantityFormatter.formatClean(today.todayPurchasesVal)}', '${today.todayPurchasesCnt} Invoices', Icons.shopping_cart_outlined, const Color(0xFF10B981)),
      _TodayItem("Today's Stock In", QuantityFormatter.formatClean(today.todayStockInQty), '${today.todayNewBatchesCnt} Batches', Icons.archive_outlined, const Color(0xFF06B6D4)),
      _TodayItem("Today's Dispatch", QuantityFormatter.formatClean(today.todayDispatchQty), '${today.todayDispatchCnt} Orders', Icons.unarchive_outlined, const Color(0xFF8B5CF6)),
      _TodayItem("Today's Transfer Out", QuantityFormatter.formatClean(today.todayTransferOut), 'Outward', Icons.arrow_forward_rounded, const Color(0xFFF59E0B)),
      _TodayItem("Today's Returns", QuantityFormatter.formatClean(today.todayTransferRet), 'Inward Returns', Icons.arrow_back_rounded, const Color(0xFF38BDF8)),
      _TodayItem("Today's Closing Stock", QuantityFormatter.formatClean(today.todayClosingStock), 'Total In Hand', Icons.all_inbox_rounded, const Color(0xFF6366F1)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final int crossCount;
          final double extent;

          if (width < 340) {
            crossCount = 1;
            extent = 70;
          } else if (width < 600) {
            crossCount = 2;
            extent = 78;
          } else if (width < 900) {
            crossCount = 3;
            extent = 82;
          } else {
            crossCount = 6;
            extent = 82;
          }

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: extent,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF374151).withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      it.title,
                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        it.value,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    Text(
                      it.subtitle,
                      style: TextStyle(fontSize: 9.5, color: it.accent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Section 7: Inventory Health (Tap -> Opens Reports) ─────────────────────
  Widget _buildInventoryHealth(BuildContext context, OwnerHealthData health) {
    final healthCards = [
      _HealthCard('Healthy Stock', health.healthyStock.toString(), AppColors.success, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialDirectoryReport()));
      }),
      _HealthCard('Low Stock', health.lowStock.toString(), const Color(0xFFF59E0B), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ReorderReport()));
      }),
      _HealthCard('Out of Stock', health.outOfStock.toString(), AppColors.danger, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OutOfStockReport()));
      }),
      _HealthCard('Expiring Soon', health.expiringSoon.toString(), const Color(0xFFF97316), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerExpiringReportScreen()));
      }),
      _HealthCard('Expired Items', health.expired.toString(), const Color(0xFFDC2626), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerExpiringReportScreen()));
      }),
      _HealthCard('Active Batches', health.activeBatches.toString(), const Color(0xFF06B6D4), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageReport()));
      }),
      _HealthCard('Depleted Batches', health.depletedBatches.toString(), const Color(0xFF6B7280), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageReport()));
      }),
    ];

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'HEALTH OVERVIEW (TAP CARD TO OPEN REPORT)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: const Color(0xFF9CA3AF),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF9CA3AF)),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: healthCards.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: c.onTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 136,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.accent.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.title,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFD1D5DB)),
                            maxLines: 1,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c.count,
                            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: c.accent),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('View Report', style: TextStyle(fontSize: 10, color: c.accent, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 2),
                                Icon(Icons.arrow_forward_rounded, size: 10, color: c.accent),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 8: Storage Overview ────────────────────────────────────────────
  Widget _buildStorageOverview(BuildContext context, OwnerStorageData storage) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'FINISHED PRODUCT STORAGE',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: const Color(0xFF3B82F6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageReport()));
                },
                child: const Text('View Storage', style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildMiniMetricsGrid(
            _buildMiniMetric('Total Stock', QuantityFormatter.formatClean(storage.totalStorageStock), const Color(0xFF3B82F6)),
            _buildMiniMetric('Active Batches', storage.activeBatches.toString(), const Color(0xFF06B6D4)),
            _buildMiniMetric('Depleted', storage.depletedBatches.toString(), const Color(0xFF9CA3AF)),
            _buildMiniMetric("Today's In", QuantityFormatter.formatClean(storage.todayStockIn), AppColors.success),
          ),
          const SizedBox(height: 16),
          const Text('Top Products in Storage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          if (storage.topProducts.isEmpty)
            const Text('No products currently stored', style: TextStyle(color: AppColors.textMuted, fontSize: 11))
          else
            ...storage.topProducts.take(3).map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${p['material_code']} (${p['description'] ?? ''})',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFD1D5DB)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${QuantityFormatter.formatClean((p['total_available'] as num?)?.toDouble() ?? 0.0)} ${p['uom'] ?? 'kg'}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ── Section 9: Material Overview ───────────────────────────────────────────
  Widget _buildMaterialOverview(BuildContext context, OwnerMaterialsData materials) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'RAW MATERIAL INVENTORY',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: const Color(0xFF6366F1),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialsScreen()));
                },
                child: const Text('View Materials', style: TextStyle(fontSize: 11, color: Color(0xFF6366F1))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildMiniMetricsGrid(
            _buildMiniMetric('Materials', materials.totalMaterials.toString(), const Color(0xFF6366F1)),
            _buildMiniMetric('Total Qty', QuantityFormatter.formatClean(materials.totalQuantity), Colors.white),
            _buildMiniMetric('Low Stock', materials.lowStock.toString(), const Color(0xFFF59E0B)),
            _buildMiniMetric('Out of Stock', materials.outOfStock.toString(), AppColors.danger),
          ),
          const SizedBox(height: 16),
          const Text('Highest Stock Raw Materials', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          if (materials.highestStock.isEmpty)
            const Text('No materials in stock', style: TextStyle(color: AppColors.textMuted, fontSize: 11))
          else
            ...materials.highestStock.take(3).map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${m['material_code']} (${m['description'] ?? ''})',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFD1D5DB)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${QuantityFormatter.formatClean((m['quantity'] as num?)?.toDouble() ?? 0.0)} ${m['unit'] ?? 'kg'}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ── Section 10: Invoice Overview ───────────────────────────────────────────
  Widget _buildInvoiceOverview(OwnerInvoicesData invoices) {
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
            'INVOICE & PROCUREMENT OVERVIEW',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 12),
          _buildMiniMetricsGrid(
            _buildMiniMetric("Today's", '₹${QuantityFormatter.formatClean(invoices.todayInvoicesVal)}', const Color(0xFF10B981)),
            _buildMiniMetric("This Week", '₹${QuantityFormatter.formatClean(invoices.weekInvoicesVal)}', Colors.white),
            _buildMiniMetric("This Month", '₹${QuantityFormatter.formatClean(invoices.monthInvoicesVal)}', const Color(0xFF06B6D4)),
            _buildMiniMetric('Pending', invoices.pendingInvoicesCnt.toString(), const Color(0xFFEC4899)),
          ),
          const SizedBox(height: 16),
          const Text('Recent Invoices Received', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          if (invoices.recentPurchases.isEmpty)
            const Text('No recent invoices', style: TextStyle(color: AppColors.textMuted, fontSize: 11))
          else
            ...invoices.recentPurchases.take(3).map((inv) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${inv['invoice_no']} • ${inv['vendor'] ?? ''}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFD1D5DB)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹${QuantityFormatter.formatClean((inv['final_total'] as num?)?.toDouble() ?? 0.0)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ── Section 11: Dispatch Overview ──────────────────────────────────────────
  Widget _buildDispatchOverview(OwnerDispatchesData dispatches) {
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
            'FINISHED GOODS DISPATCH SUMMARY',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 12),
          _buildMiniMetricsGrid(
            _buildMiniMetric("Today's", QuantityFormatter.formatClean(dispatches.todayDispatchQty), const Color(0xFF8B5CF6)),
            _buildMiniMetric("This Week", QuantityFormatter.formatClean(dispatches.weekDispatchQty), Colors.white),
            _buildMiniMetric("This Month", QuantityFormatter.formatClean(dispatches.monthDispatchQty), const Color(0xFF38BDF8)),
            _buildMiniMetric('Returns', QuantityFormatter.formatClean(dispatches.returns), const Color(0xFFF59E0B)),
          ),
          const SizedBox(height: 16),
          const Text('Top Dispatched Products', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          if (dispatches.topDispatchedProducts.isEmpty)
            const Text('No dispatches recorded', style: TextStyle(color: AppColors.textMuted, fontSize: 11))
          else
            ...dispatches.topDispatchedProducts.take(3).map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${d['product'] ?? d['material_code']}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFD1D5DB)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${QuantityFormatter.formatClean((d['total_dispatched'] as num?)?.toDouble() ?? 0.0)} ${d['units'] ?? ''}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ── Section 12: Transfers Overview ─────────────────────────────────────────
  Widget _buildTransferOverview(OwnerTransfersData transfers) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'INTERNAL TRANSFERS & RETURNS (NET CONSUMPTION = RETURN - OUTWARD)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: const Color(0xFFF59E0B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Net: ${QuantityFormatter.formatClean(transfers.netConsumed)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMiniMetricsGrid(
            _buildMiniMetric("Today's Out", QuantityFormatter.formatClean(transfers.todayTransfersOut), const Color(0xFFF59E0B)),
            _buildMiniMetric("Today's Ret", QuantityFormatter.formatClean(transfers.todayTransfersRet), const Color(0xFF06B6D4)),
            _buildMiniMetric("Total Outward", QuantityFormatter.formatClean(transfers.totalTransfersOut), Colors.white),
            _buildMiniMetric("Total Returns", QuantityFormatter.formatClean(transfers.totalTransfersRet), AppColors.success),
          ),
        ],
      ),
    );
  }

  // ── Section 14: Expiry Monitor ─────────────────────────────────────────────
  Widget _buildExpiryMonitorSection(BuildContext context, OwnerExpiryMonitor expiry) {
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
              final isNarrow = constraints.maxWidth < 450;
              final headerInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXPIRY MONITOR (INDEPENDENT THRESHOLDS)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: const Color(0xFFF97316),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Invoice Threshold: ${expiry.invoiceThresholdDays}d | Storage Threshold: ${expiry.storageThresholdDays}d',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              );
              final viewAllBtn = TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerExpiringReportScreen()));
                },
                child: const Text('View All Expiries', style: TextStyle(fontSize: 11, color: Color(0xFFF97316))),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerInfo,
                    Align(
                      alignment: Alignment.centerLeft,
                      child: viewAllBtn,
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: headerInfo),
                  const SizedBox(width: 8),
                  viewAllBtn,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              final invItems = expiry.invoiceMaterials.take(3).toList();
              final storItems = expiry.storageProducts.take(3).toList();

              Widget invCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Invoice Raw Materials', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                  const SizedBox(height: 6),
                  if (invItems.isEmpty)
                    const Text('No raw materials expiring soon', style: TextStyle(color: AppColors.textMuted, fontSize: 11))
                  else
                    ...invItems.map((m) => _buildMiniExpiryRow(
                          code: m['material_code']?.toString() ?? '',
                          desc: m['description']?.toString() ?? '',
                          days: (m['days_remaining'] as num?)?.toInt() ?? 0,
                          qty: (m['quantity'] as num?)?.toDouble() ?? 0.0,
                          unit: m['unit']?.toString() ?? 'kg',
                        )),
                ],
              );

              Widget storCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Storage Finished Goods', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                  const SizedBox(height: 6),
                  if (storItems.isEmpty)
                    const Text('No finished batches expiring soon', style: TextStyle(color: AppColors.textMuted, fontSize: 11))
                  else
                    ...storItems.map((b) => _buildMiniExpiryRow(
                          code: 'Batch ${b['batch_no']}',
                          desc: b['description']?.toString() ?? '',
                          days: (b['days_remaining'] as num?)?.toInt() ?? 0,
                          qty: (b['available_quantity'] as num?)?.toDouble() ?? 0.0,
                          unit: b['uom']?.toString() ?? 'kg',
                        )),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: invCol),
                    const SizedBox(width: 16),
                    Expanded(child: storCol),
                  ],
                );
              }
              return Column(
                children: [
                  invCol,
                  const SizedBox(height: 12),
                  storCol,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniExpiryRow({
    required String code,
    required String desc,
    required int days,
    required double qty,
    required String unit,
  }) {
    final isExp = days < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '$code ($desc)',
              style: const TextStyle(fontSize: 11, color: Color(0xFFD1D5DB)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isExp ? 'EXPIRED (${-days}d ago)' : '$days days left',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isExp ? AppColors.danger : const Color(0xFFF97316),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 15: Alert Center ───────────────────────────────────────────────
  Widget _buildAlertCenter(BuildContext context, List<OwnerAlertItem> alerts) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'EXECUTIVE ALERT CENTER',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.danger,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.notifications_active_outlined, size: 16, color: AppColors.danger),
            ],
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('All inventory and operational systems healthy.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          else
            ...alerts.take(4).map((a) {
              Color c = const Color(0xFF06B6D4);
              if (a.severity == 'CRITICAL') c = AppColors.danger;
              if (a.severity == 'WARNING') c = const Color(0xFFF59E0B);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            a.message,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Section 16: Recent Activity ────────────────────────────────────────────
  Widget _buildRecentActivity(List<OwnerActivityItem> activity) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'RECENT DAILY ACTIVITY',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.history_rounded, size: 16, color: Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 12),
          if (activity.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No daily activity recorded today.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          else
            ...activity.take(4).map((act) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      act.timeAmPm,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${act.operation} on ${act.module}: ${act.recordId}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFD1D5DB)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMetricsGrid(Widget m1, Widget m2, Widget m3, Widget m4) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 460) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: m1),
                  const SizedBox(width: 8),
                  Expanded(child: m2),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: m3),
                  const SizedBox(width: 8),
                  Expanded(child: m4),
                ],
              ),
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: m1),
            const SizedBox(width: 8),
            Expanded(child: m2),
            const SizedBox(width: 8),
            Expanded(child: m3),
            const SizedBox(width: 8),
            Expanded(child: m4),
          ],
        );
      },
    );
  }
}

class _KpiItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  _KpiItem(this.title, this.value, this.subtitle, this.icon, this.accent);
}

class _TodayItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  _TodayItem(this.title, this.value, this.subtitle, this.icon, this.accent);
}

class _HealthCard {
  final String title;
  final String count;
  final Color accent;
  final VoidCallback onTap;

  _HealthCard(this.title, this.count, this.accent, this.onTap);
}
