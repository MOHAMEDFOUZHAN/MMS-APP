import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/owner_dashboard_model.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../providers/owner_providers.dart';
import '../reports/reorder_report.dart';
import 'reports/owner_expiring_report_screen.dart';

class OwnerAlertsScreen extends ConsumerStatefulWidget {
  const OwnerAlertsScreen({super.key});

  @override
  ConsumerState<OwnerAlertsScreen> createState() => _OwnerAlertsScreenState();
}

class _OwnerAlertsScreenState extends ConsumerState<OwnerAlertsScreen> {
  String _selectedSeverity = 'ALL';

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(ownerDashboardSummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Text(
          'Executive Alert Center',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Alerts',
            onPressed: () => ref.invalidate(ownerDashboardSummaryProvider),
          ),
        ],
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            // Severity Selector Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF111827),
                border: Border(bottom: BorderSide(color: Color(0xFF1F2937))),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSeverityFilterChip('ALL', 'All Alerts'),
                    const SizedBox(width: 8),
                    _buildSeverityFilterChip('CRITICAL', 'Critical'),
                    const SizedBox(width: 8),
                    _buildSeverityFilterChip('WARNING', 'Warning'),
                    const SizedBox(width: 8),
                    _buildSeverityFilterChip('INFO', 'Info'),
                  ],
                ),
              ),
            ),

            // Alerts Content
            Expanded(
              child: summaryAsync.when(
                loading: () => const LoadingSkeletonList(count: 6),
                error: (e, _) => Center(
                  child: Text('Error loading alerts: $e', style: const TextStyle(color: AppColors.danger)),
                ),
                data: (summary) {
                  final allAlerts = summary.alerts;
                  final filtered = allAlerts.where((a) {
                    if (_selectedSeverity != 'ALL' && a.severity != _selectedSeverity) {
                      return false;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'All Systems Normal',
                      message: 'No active critical alerts or warnings at this time.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final alert = filtered[i];
                      return _buildAlertCard(context, alert);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityFilterChip(String severity, String label) {
    final isSelected = _selectedSeverity == severity;
    Color color = Colors.white;
    if (severity == 'CRITICAL') color = AppColors.danger;
    if (severity == 'WARNING') color = const Color(0xFFF59E0B);
    if (severity == 'INFO') color = const Color(0xFF06B6D4);

    return InkWell(
      onTap: () => setState(() => _selectedSeverity = severity),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF374151),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? color : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, OwnerAlertItem alert) {
    Color sevColor = const Color(0xFF06B6D4);
    IconData sevIcon = Icons.info_outline_rounded;
    if (alert.severity == 'CRITICAL') {
      sevColor = AppColors.danger;
      sevIcon = Icons.error_outline_rounded;
    } else if (alert.severity == 'WARNING') {
      sevColor = const Color(0xFFF59E0B);
      sevIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sevColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: sevColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(sevIcon, color: sevColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: sevColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        alert.severity,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: sevColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFD1D5DB),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton(
                    onPressed: () {
                      if (alert.referenceType == 'material') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReorderReport()),
                        );
                      } else if (alert.referenceType == 'batch') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OwnerExpiringReportScreen()),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Details',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sevColor),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, size: 14, color: sevColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
