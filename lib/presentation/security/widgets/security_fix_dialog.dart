import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/security/security_finding_model.dart';

class SecurityFixApprovalDialog extends StatelessWidget {
  final SecurityFinding finding;
  final VoidCallback onApproveAndApply;

  const SecurityFixApprovalDialog({
    super.key,
    required this.finding,
    required this.onApproveAndApply,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.glassBorder),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined, color: AppColors.primaryLight, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approve & Apply Security Fix',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  finding.id,
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(color: AppColors.glassBorder, height: 16),

            // WHAT WILL CHANGE
            _buildSection(
              title: 'WHAT WILL CHANGE',
              content: finding.recommendedFix,
              icon: Icons.change_circle_outlined,
              accentColor: AppColors.primaryLight,
            ),
            const SizedBox(height: 12),

            // WHY
            _buildSection(
              title: 'WHY IT IS REQUIRED',
              content: finding.whyItMatters,
              icon: Icons.info_outline_rounded,
              accentColor: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),

            // AFFECTED TABLES / FUNCTIONS
            _buildSection(
              title: 'AFFECTED OBJECTS',
              content: finding.affectedComponent,
              icon: Icons.storage_rounded,
              accentColor: AppColors.accent,
              isMono: true,
            ),
            const SizedBox(height: 12),

            // POSSIBLE IMPACT
            _buildSection(
              title: 'POSSIBLE OPERATIONAL IMPACT',
              content: finding.fixType == FixType.safeAutoFix
                  ? 'Zero downtime. Low risk. Existing business transactions continue operating smoothly.'
                  : 'Requires PostgreSQL permissions update. Unauthorized anonymous client write requests will be strictly rejected.',
              icon: Icons.warning_amber_rounded,
              accentColor: AppColors.warning,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textMuted,
            side: const BorderSide(color: AppColors.glassBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            onApproveAndApply();
          },
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: const Text('Approve & Apply'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required IconData icon,
    required Color accentColor,
    bool isMono = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: accentColor),
            const SizedBox(width: 5),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: accentColor,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Text(
            content,
            style: isMono
                ? GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textPrimary)
                : const TextStyle(fontSize: 11, color: AppColors.textPrimary, height: 1.3),
          ),
        ),
      ],
    );
  }
}
