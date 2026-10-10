import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/security/security_finding_model.dart';
import '../../core/theme/glass_widgets.dart';
import '../providers/security_providers.dart';
import 'security_history_screen.dart';
import 'widgets/security_detail_sheet.dart';
import 'widgets/security_finding_card.dart';
import 'widgets/security_fix_dialog.dart';
import 'widgets/security_workflow_tracker.dart';

class SecurityCenterScreen extends ConsumerStatefulWidget {
  const SecurityCenterScreen({super.key});

  @override
  ConsumerState<SecurityCenterScreen> createState() => _SecurityCenterScreenState();
}

class _SecurityCenterScreenState extends ConsumerState<SecurityCenterScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final auditState = ref.watch(securityAuditStateProvider);
    final report = auditState.currentReport;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.primaryLight),
            tooltip: 'View Security History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SecurityHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: AmbientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Control Center Card ──
              _buildHeaderControlCard(auditState),
              const SizedBox(height: 16),

              // ── Visual 7-Step Workflow Tracker ──
              SecurityWorkflowTracker(activeStep: auditState.activeWorkflowStep),
              const SizedBox(height: 16),

              // ── Scanning State Indicator ──
              if (auditState.isScanning) ...[
                _buildScanningStateCard(auditState.scanningStage),
                const SizedBox(height: 16),
              ],

              // ── Security Score & Findings Breakdown ──
              if (report != null && !auditState.isScanning) ...[
                _buildScoreOverviewCard(report),
                const SizedBox(height: 16),
                _buildFilterChips(report),
                const SizedBox(height: 14),
                _buildFindingsList(report),
              ] else if (!auditState.isScanning) ...[
                _buildInitialEmptyState(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Header Control Center Card ──
  Widget _buildHeaderControlCard(SecurityAuditState state) {
    final report = state.currentReport;
    final statusLabel = report?.statusLabel ?? 'Not Scanned';
    final statusColor = report?.statusColor ?? AppColors.textMuted;

    return GlassCard(
      accentColor: statusColor,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5)),
                      ),
                      child: const Icon(Icons.shield_outlined, color: AppColors.primaryLight, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SECURITY CENTER',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Supabase Security Audit',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Primary and Secondary Action Buttons
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              final auditButton = GlassButton(
                text: state.isScanning ? 'Auditing System...' : 'RUN SECURITY AUDIT',
                icon: state.isScanning ? null : Icons.security_rounded,
                isLoading: state.isScanning,
                color: AppColors.primary,
                height: 46,
                onPressed: state.isScanning
                    ? null
                    : () => ref.read(securityAuditStateProvider.notifier).runCompleteAudit(),
              );
              final historyButton = GlassButton(
                text: 'VIEW SECURITY HISTORY',
                icon: Icons.history_rounded,
                isOutlined: true,
                height: 46,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SecurityHistoryScreen()),
                  );
                },
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    auditButton,
                    const SizedBox(height: 10),
                    historyButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 6, child: auditButton),
                  const SizedBox(width: 10),
                  Expanded(flex: 4, child: historyButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Scanning State Progress Card ──
  Widget _buildScanningStateCard(String stage) {
    return GlassCard(
      accentColor: AppColors.primaryLight,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primaryLight),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RUNNING SECURITY AUDIT PROBES',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryLight,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stage.isNotEmpty ? stage : 'Inspecting RLS, storage, functions, and credentials...',
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Score Overview Card ──
  Widget _buildScoreOverviewCard(SecurityAuditReport report) {
    final score = report.securityScore;
    final scoreColor = score >= 80
        ? const Color(0xFF10B981)
        : score >= 60
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SECURITY SCORE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$score',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        ' / 100',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  '${report.totalChecks} Checks Executed',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100.0,
              minHeight: 8,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            ),
          ),
          const SizedBox(height: 16),

          // Severity Counts Breakdown
          Row(
            children: [
              Expanded(child: _buildSeverityCounter('CRITICAL', report.criticalCount, const Color(0xFFEF4444))),
              const SizedBox(width: 8),
              Expanded(child: _buildSeverityCounter('HIGH', report.highCount, const Color(0xFFF97316))),
              const SizedBox(width: 8),
              Expanded(child: _buildSeverityCounter('MEDIUM', report.mediumCount, const Color(0xFFFBBF24))),
              const SizedBox(width: 8),
              Expanded(child: _buildSeverityCounter('LOW', report.lowCount, const Color(0xFF38BDF8))),
            ],
          ),
          const SizedBox(height: 14),

          // Summary Note
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primaryLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.summary,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityCounter(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: count > 0 ? 0.15 : 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: count > 0 ? 0.6 : 0.2)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count.toString(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter Chips ──
  Widget _buildFilterChips(SecurityAuditReport report) {
    final filters = [
      {'name': 'All', 'count': report.findings.length},
      {'name': 'Critical', 'count': report.criticalCount},
      {'name': 'High', 'count': report.highCount},
      {'name': 'Medium', 'count': report.mediumCount},
      {'name': 'Low', 'count': report.lowCount},
      {'name': 'Fixed', 'count': report.fixedCount},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['name'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                '${f['name']} (${f['count']})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: isSelected ? AppColors.primaryLight : AppColors.glassBorder,
              ),
              onSelected: (_) => setState(() => _selectedFilter = f['name'] as String),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Findings List ──
  Widget _buildFindingsList(SecurityAuditReport report) {
    List<SecurityFinding> filtered = report.findings;

    if (_selectedFilter == 'Critical') {
      filtered = filtered.where((f) => f.severity == SecuritySeverity.critical && !f.isFixed).toList();
    } else if (_selectedFilter == 'High') {
      filtered = filtered.where((f) => f.severity == SecuritySeverity.high && !f.isFixed).toList();
    } else if (_selectedFilter == 'Medium') {
      filtered = filtered.where((f) => f.severity == SecuritySeverity.medium && !f.isFixed).toList();
    } else if (_selectedFilter == 'Low') {
      filtered = filtered.where((f) => f.severity == SecuritySeverity.low && !f.isFixed).toList();
    } else if (_selectedFilter == 'Fixed') {
      filtered = filtered.where((f) => f.isFixed).toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 36, color: AppColors.success),
              const SizedBox(height: 10),
              Text(
                'No findings under "$_selectedFilter"',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final finding = filtered[i];
        return SecurityFindingCard(
          finding: finding,
          onViewDetails: () => _openFindingDetail(finding),
          onApplyFix: () => _openFixApprovalDialog(finding),
        );
      },
    );
  }

  // ── Initial Empty State ──
  Widget _buildInitialEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.security_rounded, size: 54, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 20),
            Text(
              'Benchmark MMS Security Audit',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Run an automated security audit to analyze PostgreSQL RLS, function search_path, storage bucket privacy, and credential configurations.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 24),
            GlassButton(
              text: 'START SYSTEM SECURITY AUDIT',
              icon: Icons.play_arrow_rounded,
              color: AppColors.primary,
              height: 48,
              onPressed: () => ref.read(securityAuditStateProvider.notifier).runCompleteAudit(),
            ),
          ],
        ),
      ),
    );
  }

  void _openFindingDetail(SecurityFinding finding) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SecurityDetailSheet(
        finding: finding,
        onProceedToFix: () => _openFixApprovalDialog(finding),
      ),
    );
  }

  void _openFixApprovalDialog(SecurityFinding finding) {
    showDialog(
      context: context,
      builder: (_) => SecurityFixApprovalDialog(
        finding: finding,
        onApproveAndApply: () async {
          final isVerified =
              await ref.read(securityAuditStateProvider.notifier).applyApprovedFix(finding);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isVerified
                    ? 'Fix for ${finding.id} applied and verified successfully!'
                    : 'Fix applied. Re-verification indicated additional manual configuration is needed.',
              ),
              backgroundColor: isVerified ? AppColors.success : AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }
}
