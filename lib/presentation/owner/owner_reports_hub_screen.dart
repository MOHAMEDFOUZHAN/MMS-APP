import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'reports/tea_department_report_screen.dart';
import 'reports/chocolate_department_report_screen.dart';
import 'reports/overall_executive_report_screen.dart';

class OwnerReportsHubScreen extends StatelessWidget {
  final bool isEmbedded;
  const OwnerReportsHubScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    final coreReports = [
      _ReportCardDef(
        id: 'R01',
        title: 'Material Directory / Wall Chart',
        icon: Icons.view_list_rounded,
        accent: const Color(0xFF6366F1),
        screenBuilder: () => const MaterialDirectoryReport(),
      ),
      _ReportCardDef(
        id: 'R02',
        title: 'Daily Stock Ledger',
        icon: Icons.calendar_view_day_rounded,
        accent: const Color(0xFF06B6D4),
        screenBuilder: () => const DailyStockLedgerReport(),
      ),
      _ReportCardDef(
        id: 'R03',
        title: 'Transfers by Department',
        icon: Icons.pie_chart_outline_rounded,
        accent: const Color(0xFF10B981),
        screenBuilder: () => const DepartmentConsumptionReport(),
      ),
      _ReportCardDef(
        id: 'R04',
        title: 'Reorder Warning Report',
        icon: Icons.warning_amber_rounded,
        accent: const Color(0xFFF59E0B),
        screenBuilder: () => const ReorderReport(),
      ),
      _ReportCardDef(
        id: 'R05',
        title: 'Stock Availability & Dispatch Summary',
        icon: Icons.layers_rounded,
        accent: const Color(0xFF3B82F6),
        screenBuilder: () => const StorageReport(),
      ),
      _ReportCardDef(
        id: 'R06',
        title: 'Out of Stock Report',
        icon: Icons.remove_circle_outline_rounded,
        accent: const Color(0xFFEF4444),
        screenBuilder: () => const OutOfStockReport(),
      ),
      _ReportCardDef(
        id: 'R07',
        title: 'Expiring Items Monitor',
        icon: Icons.timer_outlined,
        accent: const Color(0xFFF97316),
        screenBuilder: () => const OwnerExpiringReportScreen(),
      ),
      _ReportCardDef(
        id: 'R08',
        title: 'Material Utilization Report (MUR)',
        icon: Icons.analytics_rounded,
        accent: const Color(0xFF8B5CF6),
        screenBuilder: () => const MurReport(),
      ),
    ];

    final operationalReports = [
      _ReportCardDef(
        id: 'R09',
        title: 'Purchase Invoices Register',
        icon: Icons.receipt_long_rounded,
        accent: const Color(0xFF6366F1),
        screenBuilder: () => const InvoiceListScreen(),
      ),
      _ReportCardDef(
        id: 'R10',
        title: 'Finished Goods Dispatch Register',
        icon: Icons.local_shipping_rounded,
        accent: const Color(0xFF06B6D4),
        screenBuilder: () => const DispatchScreen(),
      ),
      _ReportCardDef(
        id: 'R11',
        title: 'Internal Transfers & Returns',
        icon: Icons.swap_horiz_rounded,
        accent: const Color(0xFF10B981),
        screenBuilder: () => const TransfersScreen(),
      ),
      _ReportCardDef(
        id: 'R12',
        title: 'Stock Adjustments Audit',
        icon: Icons.tune_rounded,
        accent: const Color(0xFFEC4899),
        screenBuilder: () => const StockAdjustmentScreen(),
      ),
      _ReportCardDef(
        id: 'R13',
        title: 'Approved Vendors Directory',
        icon: Icons.storefront_rounded,
        accent: const Color(0xFF8B5CF6),
        screenBuilder: () => const VendorsScreen(),
      ),
    ];

    final executiveDeptReports = [
      _ReportCardDef(
        id: 'D01',
        title: 'Tea Department Report',
        icon: Icons.eco_rounded,
        accent: const Color(0xFF10B981),
        screenBuilder: () => const TeaDepartmentReportScreen(),
      ),
      _ReportCardDef(
        id: 'D02',
        title: 'Chocolate Department Report',
        icon: Icons.document_scanner_rounded,
        accent: const Color(0xFFF59E0B),
        screenBuilder: () => const ChocolateDepartmentReportScreen(),
      ),
      _ReportCardDef(
        id: 'D03',
        title: 'Overall Admin Operations Report',
        icon: Icons.corporate_fare_rounded,
        accent: const Color(0xFF6366F1),
        screenBuilder: () => const OverallExecutiveReportScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: isEmbedded
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF111827),
              title: Text(
                'Management Reports Hub',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
      body: AmbientBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1024;
            final isTablet = constraints.maxWidth >= 640 && constraints.maxWidth < 1024;
            final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
            final cardExtent = 70.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compact Header Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF374151)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assessment_rounded,
                            color: Color(0xFFF59E0B),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Executive Reports Repository',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Section 0: Executive Department & Admin Reports
                  _buildSectionHeader('EXECUTIVE DEPARTMENT & ADMIN REPORTS (3)', const Color(0xFF10B981)),
                  const SizedBox(height: 10),
                  _buildGrid(context, executiveDeptReports, crossAxisCount, cardExtent),
                  const SizedBox(height: 20),

                  // Section 1: Core Inventory Reports
                  _buildSectionHeader('CORE INVENTORY REPORTS (8)', const Color(0xFFF59E0B)),
                  const SizedBox(height: 10),
                  _buildGrid(context, coreReports, crossAxisCount, cardExtent),
                  const SizedBox(height: 20),

                  // Section 2: Operational Registers
                  _buildSectionHeader('OPERATIONAL REGISTERS & LOGS', const Color(0xFF6366F1)),
                  const SizedBox(height: 10),
                  _buildGrid(context, operationalReports, crossAxisCount, cardExtent),
                  const SizedBox(height: 16),
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
        Container(width: 4, height: 14, color: color),
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
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => r.screenBuilder()));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: r.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(r.icon, color: r.accent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                      const SizedBox(height: 2),
                      Text(
                        r.title,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_ios_rounded, size: 13, color: r.accent.withValues(alpha: 0.7)),
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
  final IconData icon;
  final Color accent;
  final Widget Function() screenBuilder;

  _ReportCardDef({
    required this.id,
    required this.title,
    required this.icon,
    required this.accent,
    required this.screenBuilder,
  });
}
