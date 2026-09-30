import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/glass_widgets.dart';
import 'daily_stock_ledger_report.dart';
import 'department_consumption_report.dart';
import 'expiring_report.dart';
import 'material_directory_report.dart';
import 'mur_report.dart';
import 'out_of_stock_report.dart';
import 'reorder_report.dart';
import 'storage_report.dart';

class ReportsHubScreen extends StatelessWidget {
  final bool isEmbedded;
  const ReportsHubScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    final reports = [
      _ReportDef(
        title: 'Material Directory / Wall Chart',
        subtitle: 'Comprehensive material codes, descriptions, UOM & shelf mapping',
        icon: Icons.view_list_rounded,
        color: AppColors.primary,
        screen: const MaterialDirectoryReport(),
      ),
      _ReportDef(
        title: 'Daily Stock Ledger',
        subtitle: 'Opening, Inward, Transfers, Returns & Dispatches per material',
        icon: Icons.calendar_view_day_rounded,
        color: AppColors.accent,
        screen: const DailyStockLedgerReport(),
      ),
      _ReportDef(
        title: 'Material Utilization Report (MUR)',
        subtitle: 'Historical backtracking math across purchases, issues & returns',
        icon: Icons.analytics_rounded,
        color: const Color(0xFF8B5CF6),
        screen: const MurReport(),
      ),
      _ReportDef(
        title: 'Department Consumption',
        subtitle: 'Outward issues vs returns broken down by factory department',
        icon: Icons.pie_chart_outline_rounded,
        color: AppColors.secondary,
        screen: const DepartmentConsumptionReport(),
      ),
      _ReportDef(
        title: 'Reorder Level Report',
        subtitle: 'Materials at or below minimum threshold requiring replenishment',
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        screen: const ReorderReport(),
      ),
      _ReportDef(
        title: 'Active Storage Register',
        subtitle: 'Batch-by-batch received vs available storage quantities',
        icon: Icons.layers_rounded,
        color: AppColors.primaryLight,
        screen: const StorageReport(),
      ),
      _ReportDef(
        title: 'Out of Stock Report',
        subtitle: 'Depleted lots with zero current inventory',
        icon: Icons.remove_circle_outline_rounded,
        color: AppColors.danger,
        screen: const OutOfStockReport(),
      ),
      _ReportDef(
        title: 'Expiring Items Report',
        subtitle: 'Items approaching shelf-life expiration within 30 days',
        icon: Icons.timer_outlined,
        color: const Color(0xFFF97316),
        screen: const ExpiringReport(),
      ),
    ];

    return Scaffold(
      appBar: isEmbedded ? null : AppBar(title: const Text('Reports Hub')),
      body: AmbientBackground(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final r = reports[i];
            return GlassCard(
              padding: const EdgeInsets.all(16),
              accentColor: r.color,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => r.screen));
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: r.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(r.icon, color: r.color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          r.subtitle,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReportDef {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget screen;

  _ReportDef({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.screen,
  });
}
