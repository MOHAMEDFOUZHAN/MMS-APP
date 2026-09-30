import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/glass_widgets.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String? customLabel;

  const StatusBadge({
    super.key,
    required this.status,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label = customLabel ?? status;

    switch (status.toLowerCase()) {
      case 'in_stock':
      case 'instock':
      case 'paid':
      case 'active':
        color = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
      case 'reorder':
      case 'warning':
      case 'partially paid':
        color = AppColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
      case 'out_of_stock':
      case 'depleted':
      case 'cancelled':
      case 'danger':
        color = AppColors.danger;
        icon = Icons.cancel_outlined;
        break;
      case 'expiring':
      case 'expiring_soon':
        color = const Color(0xFFF97316); // Orange
        icon = Icons.schedule_outlined;
        break;
      case 'pending':
      default:
        color = AppColors.accent;
        icon = Icons.hourglass_empty_rounded;
        break;
    }

    return NeonPill(
      label: label.toUpperCase(),
      color: color,
      icon: icon,
    );
  }
}
