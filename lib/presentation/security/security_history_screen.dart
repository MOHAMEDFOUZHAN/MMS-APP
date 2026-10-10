import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/security/security_finding_model.dart';
import '../../core/theme/glass_widgets.dart';
import '../providers/security_providers.dart';
import 'widgets/security_finding_card.dart';
import 'widgets/security_detail_sheet.dart';

class SecurityHistoryScreen extends ConsumerWidget {
  const SecurityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(securityHistoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Audit History'),
      ),
      body: AmbientBackground(
        child: historyAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryLight),
          ),
          error: (err, _) => Center(
            child: Text(
              'Failed to load audit history: $err',
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
          data: (reports) {
            if (reports.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.history_rounded, size: 40, color: AppColors.primaryLight),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Audit History Recorded Yet',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Run a security audit from the Security Center to record your first report.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final report = reports[index];
                return _buildHistoryCard(context, ref, report);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, WidgetRef ref, SecurityAuditReport report) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final dateStr = dateFormat.format(report.timestamp);
    final timeStr = timeFormat.format(report.timestamp);

    return GlassCard(
      accentColor: report.statusColor,
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => _openReportDetailsDialog(context, ref, report),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_note_rounded, size: 16, color: AppColors.primaryLight),
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: report.statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: report.statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    report.statusLabel,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: report.statusColor),
                  ),
                ),
              ],
            ),
            const Divider(color: AppColors.glassBorder, height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Security Score', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${report.securityScore}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: report.securityScore >= 80
                                ? AppColors.success
                                : report.securityScore >= 60
                                    ? AppColors.warning
                                    : AppColors.danger,
                          ),
                        ),
                        Text(
                          ' / 100',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildCountPill('Crit', report.criticalCount, const Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    _buildCountPill('High', report.highCount, const Color(0xFFF97316)),
                    const SizedBox(width: 6),
                    _buildCountPill('Med', report.mediumCount, const Color(0xFFFBBF24)),
                    const SizedBox(width: 6),
                    _buildCountPill('Low', report.lowCount, const Color(0xFF38BDF8)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Tap to view ${report.findings.length} findings →',
                  style: const TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountPill(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: count > 0 ? 0.15 : 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: count > 0 ? 0.5 : 0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
          Text(
            count.toString(),
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  void _openReportDetailsDialog(BuildContext context, WidgetRef ref, SecurityAuditReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audit Report: ${report.id}',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${report.findings.length} findings • Score: ${report.securityScore}/100',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.glassBorder, height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: report.findings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final f = report.findings[i];
                  return SecurityFindingCard(
                    finding: f,
                    onViewDetails: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SecurityDetailSheet(
                          finding: f,
                          onProceedToFix: () {},
                        ),
                      );
                    },
                    onApplyFix: () {},
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
