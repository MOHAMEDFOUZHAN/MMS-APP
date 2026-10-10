import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/glass_widgets.dart';
import '../adjustments/stock_adjustment_screen.dart';
import '../dispatch/dispatch_screen.dart';
import '../invoices/invoice_list_screen.dart';
import '../reports/daily_stock_ledger_report.dart';
import '../reports/department_consumption_report.dart';
import '../reports/material_directory_report.dart';
import '../reports/mur_report.dart';
import '../reports/out_of_stock_report.dart';
import '../reports/reorder_report.dart';
import '../reports/storage_report.dart';
import '../transfers/transfers_screen.dart';
import '../vendors/vendors_screen.dart';
import 'reports/owner_expiring_report_screen.dart';

class OwnerReportsHubScreen extends StatelessWidget {
  final bool isEmbedded;
  const OwnerReportsHubScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    final coreReports = [
      _ReportCardDef(
        id: 'R01',
        title: 'Material Directory / Wall Chart',
        subtitle: 'Comprehensive material master with category grouping, physical shelf location, UOM and reorder thresholds.',
        icon: Icons.view_list_rounded,
        accent: const Color(0xFF6366F1),
        screenBuilder: () => const MaterialDirectoryReport(),
      ),
      _ReportCardDef(
        id: 'R02',
        title: 'Daily Stock Ledger',
        subtitle: 'Daily inventory ledger detailing opening stock, inward purchases, transfers out, returns in, and closing stock.',
        icon: Icons.calendar_view_day_rounded,
        accent: const Color(0xFF06B6D4),
        screenBuilder: () => const DailyStockLedgerReport(),
      ),
      _ReportCardDef(
        id: 'R03',
        title: 'Transfers by Department',
        subtitle: 'Department-wise material issues vs returns with net consumption calculations and date filtering.',
        icon: Icons.pie_chart_outline_rounded,
        accent: const Color(0xFF10B981),
        screenBuilder: () => const DepartmentConsumptionReport(),
      ),
      _ReportCardDef(
        id: 'R04',
        title: 'Reorder Warning Report',
        subtitle: 'Critical replenishment alerts for materials at or below minimum stock threshold, sorted by deficit risk.',
        icon: Icons.warning_amber_rounded,
        accent: const Color(0xFFF59E0B),
        screenBuilder: () => const ReorderReport(),
      ),
      _ReportCardDef(
        id: 'R05',
        title: 'Stock Availability & Dispatch Summary',
        subtitle: 'Storage register tracking batch-by-batch received stock, stock out, and available balance (Active & All History).',
        icon: Icons.layers_rounded,
        accent: const Color(0xFF3B82F6),
        screenBuilder: () => const StorageReport(),
      ),
      _ReportCardDef(
        id: 'R06',
        title: 'Out of Stock Report',
        subtitle: 'Depleted materials with zero inventory requiring immediate vendor procurement.',
        icon: Icons.remove_circle_outline_rounded,
        accent: const Color(0xFFEF4444),
        screenBuilder: () => const OutOfStockReport(),
      ),
      _ReportCardDef(
        id: 'R07',
        title: 'Expiring Items Monitor',
        subtitle: 'Separated monitoring for Invoice Materials and Storage Products using independent configurable expiry thresholds.',
        icon: Icons.timer_outlined,
        accent: const Color(0xFFF97316),
        screenBuilder: () => const OwnerExpiringReportScreen(),
      ),
      _ReportCardDef(
        id: 'R08',
        title: 'Material Utilization Report (MUR)',
        subtitle: 'Historical backtracking math across purchases, issues, and returns with periodic utilization percentage.',
        icon: Icons.analytics_rounded,
        accent: const Color(0xFF8B5CF6),
        screenBuilder: () => const MurReport(),
      ),
    ];

    final operationalReports = [
      _ReportCardDef(
        id: 'R09',
        title: 'Purchase Invoices Register',
        subtitle: 'Authoritative tax invoice records, vendor GST reconciliations, payment status, and totals.',
        icon: Icons.receipt_long_rounded,
        accent: const Color(0xFF6366F1),
        screenBuilder: () => const InvoiceListScreen(),
      ),
      _ReportCardDef(
        id: 'R10',
        title: 'Finished Goods Dispatch Register',
        subtitle: 'FIFO finished product dispatches with allocation batches, customer destination, and return records.',
        icon: Icons.local_shipping_rounded,
        accent: const Color(0xFF06B6D4),
        screenBuilder: () => const DispatchScreen(),
      ),
      _ReportCardDef(
        id: 'R11',
        title: 'Internal Transfers & Returns',
        subtitle: 'Internal factory lot outward movements and return unit logging by person and department.',
        icon: Icons.swap_horiz_rounded,
        accent: const Color(0xFF10B981),
        screenBuilder: () => const TransfersScreen(),
      ),
      _ReportCardDef(
        id: 'R12',
        title: 'Stock Adjustments Audit',
        subtitle: 'Authorized manual inventory adjustments with operational reasons, before/after levels, and author info.',
        icon: Icons.tune_rounded,
        accent: const Color(0xFFEC4899),
        screenBuilder: () => const StockAdjustmentScreen(),
      ),
      _ReportCardDef(
        id: 'R13',
        title: 'Approved Vendors Directory',
        subtitle: 'Master directory of material suppliers with GSTIN numbers, contact details, and supplying products.',
        icon: Icons.storefront_rounded,
        accent: const Color(0xFF8B5CF6),
        screenBuilder: () => const VendorsScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: isEmbedded
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF111827),
              title: Text(
                'Owner Reports Hub',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
      body: AmbientBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1024;
            final isTablet = constraints.maxWidth >= 640 && constraints.maxWidth < 1024;
            final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
            final cardExtent = constraints.maxWidth < 360 ? 164.0 : 152.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Header
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF374151)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assessment_rounded,
                            color: Color(0xFFF59E0B),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Executive Reports Repository',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Comprehensive operational and analytical reports with PDF download, print, and sharing support.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 1: Core Inventory Reports (All 8 Core Reports)
                  _buildSectionHeader('CORE INVENTORY REPORTS (8)', const Color(0xFFF59E0B)),
                  const SizedBox(height: 12),
                  _buildGrid(context, coreReports, crossAxisCount, cardExtent),
                  const SizedBox(height: 32),

                  // Section 2: Operational Registers
                  _buildSectionHeader('OPERATIONAL REGISTERS & LOGS', const Color(0xFF6366F1)),
                  const SizedBox(height: 12),
                  _buildGrid(context, operationalReports, crossAxisCount, cardExtent),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
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

  Widget _buildGrid(BuildContext context, List<_ReportCardDef> reports, int crossAxisCount, double cardExtent) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: cardExtent,
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final r = reports[index];
        return _buildReportCard(context, r);
      },
    );
  }

  Widget _buildReportCard(BuildContext context, _ReportCardDef r) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => r.screenBuilder()));
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: r.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(r.icon, color: r.accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.id,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: r.accent,
                            ),
                          ),
                          Text(
                            r.title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    r.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'OPEN REPORT',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: r.accent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: r.accent),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportCardDef {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget Function() screenBuilder;

  _ReportCardDef({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.screenBuilder,
  });
}
