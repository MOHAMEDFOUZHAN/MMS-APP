import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/security/security_finding_model.dart';
import '../../../core/theme/glass_widgets.dart';

class SecurityFindingCard extends StatelessWidget {
  final SecurityFinding finding;
  final VoidCallback onViewDetails;
  final VoidCallback onApplyFix;

  const SecurityFindingCard({
    super.key,
    required this.finding,
    required this.onViewDetails,
    required this.onApplyFix,
  });

  @override
  Widget build(BuildContext context) {
    final sevColor = finding.severityColor;

    return GlassCard(
      accentColor: finding.isFixed ? AppColors.success : sevColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Severity Pill, Category Chip, and ID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sevColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: sevColor.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      finding.severityLabel,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: sevColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(finding.categoryIcon, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          finding.categoryLabel,
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (finding.isFixed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        finding.fixVerificationStatus ?? 'FIX VERIFIED',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  finding.id,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            finding.title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Affected Component
          Row(
            children: [
              const Text(
                'Affected: ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
              Expanded(
                child: Text(
                  finding.affectedComponent,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppColors.primaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Why It Matters
          Text(
            finding.whyItMatters,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Action Buttons: View Details, Review SQL / Apply Fix
          Row(
            children: [
              Expanded(
                flex: 4,
                child: OutlinedButton.icon(
                  onPressed: onViewDetails,
                  icon: const Icon(Icons.info_outline_rounded, size: 15),
                  label: const Text('View Details', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.glassBorder),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!finding.isFixed)
                Expanded(
                  flex: 6,
                  child: ElevatedButton.icon(
                    onPressed: onApplyFix,
                    icon: Icon(
                      finding.fixType == FixType.reviewSql ? Icons.code_rounded : Icons.healing_rounded,
                      size: 15,
                    ),
                    label: Text(
                      finding.fixType == FixType.reviewSql ? 'Review SQL Fix' : 'Apply Safe Fix',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: finding.fixType == FixType.reviewSql
                          ? const Color(0xFF6366F1)
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
