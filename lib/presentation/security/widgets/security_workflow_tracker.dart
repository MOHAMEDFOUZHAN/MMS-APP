import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class SecurityWorkflowTracker extends StatelessWidget {
  final int activeStep; // 1 to 7

  const SecurityWorkflowTracker({super.key, required this.activeStep});

  static const List<Map<String, String>> _steps = [
    {'num': '01', 'label': 'SCAN'},
    {'num': '02', 'label': 'CHECKING'},
    {'num': '03', 'label': 'FINDINGS'},
    {'num': '04', 'label': 'APPROVE'},
    {'num': '05', 'label': 'APPLY'},
    {'num': '06', 'label': 'VERIFY'},
    {'num': '07', 'label': 'REPORT'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_steps.length, (index) {
          final stepNum = index + 1;
          final isPast = stepNum < activeStep;
          final isCurrent = stepNum == activeStep;
          final step = _steps[index];

          final color = isCurrent
              ? AppColors.primaryLight
              : isPast
                  ? AppColors.success
                  : AppColors.textMuted.withValues(alpha: 0.6);

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.primary.withValues(alpha: 0.25)
                      : isPast
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.surface.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrent
                        ? AppColors.primaryLight.withValues(alpha: 0.8)
                        : isPast
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.glassBorder,
                    width: isCurrent ? 1.5 : 1,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPast)
                      const Padding(
                        padding: EdgeInsets.only(right: 5),
                        child: Icon(Icons.check_circle_rounded, size: 13, color: AppColors.success),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Text(
                          step['num']!,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    Text(
                      step['label']!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                        color: isCurrent ? AppColors.textPrimary : color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < _steps.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: isPast ? AppColors.success.withValues(alpha: 0.6) : AppColors.textMuted.withValues(alpha: 0.4),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}
