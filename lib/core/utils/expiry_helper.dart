import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum ExpiryState {
  none,
  normal,
  expiringSoon,
  expired,
}

class ExpiryInfo {
  final ExpiryState state;
  final int? daysRemaining;
  final String statusLabel;
  final String daysLabel;
  final bool hasAlert;
  final bool isExpired;
  final Color badgeColor;
  final Color textColor;

  const ExpiryInfo({
    required this.state,
    required this.daysRemaining,
    required this.statusLabel,
    required this.daysLabel,
    required this.hasAlert,
    required this.isExpired,
    required this.badgeColor,
    required this.textColor,
  });

  Color get accentColor => textColor;
}

class ExpiryHelper {
  /// Build a Glass + Neon badge for an ExpiryInfo
  static Widget buildBadge(ExpiryInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: info.badgeColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: info.textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        info.statusLabel,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: info.textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
  /// Calculate expiry state and labels based on threshold days
  static ExpiryInfo calculate({
    required DateTime? expiryDate,
    required int alertDaysThreshold,
    DateTime? relativeTo,
  }) {
    if (expiryDate == null) {
      return const ExpiryInfo(
        state: ExpiryState.none,
        daysRemaining: null,
        statusLabel: 'NO EXPIRY',
        daysLabel: 'No Expiry Set',
        hasAlert: false,
        isExpired: false,
        badgeColor: AppColors.glassBorder,
        textColor: AppColors.textMuted,
      );
    }

    final now = relativeTo ?? DateTime.now();
    final expMidnight = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final nowMidnight = DateTime(now.year, now.month, now.day);
    final days = expMidnight.difference(nowMidnight).inDays;

    if (days < 0) {
      return ExpiryInfo(
        state: ExpiryState.expired,
        daysRemaining: days,
        statusLabel: 'EXPIRED',
        daysLabel: '$days days',
        hasAlert: true,
        isExpired: true,
        badgeColor: AppColors.danger.withValues(alpha: 0.2),
        textColor: AppColors.danger,
      );
    }

    final isWithinThreshold = days <= alertDaysThreshold;

    if (days == 0) {
      return ExpiryInfo(
        state: isWithinThreshold ? ExpiryState.expiringSoon : ExpiryState.normal,
        daysRemaining: 0,
        statusLabel: isWithinThreshold ? 'EXPIRING TODAY' : 'NORMAL',
        daysLabel: 'Expiring today',
        hasAlert: isWithinThreshold,
        isExpired: false,
        badgeColor: isWithinThreshold
            ? AppColors.warning.withValues(alpha: 0.2)
            : AppColors.success.withValues(alpha: 0.15),
        textColor: isWithinThreshold ? AppColors.warning : AppColors.success,
      );
    }

    if (days == 1) {
      return ExpiryInfo(
        state: isWithinThreshold ? ExpiryState.expiringSoon : ExpiryState.normal,
        daysRemaining: 1,
        statusLabel: isWithinThreshold ? 'EXPIRING SOON' : 'NORMAL',
        daysLabel: '1 day remaining',
        hasAlert: isWithinThreshold,
        isExpired: false,
        badgeColor: isWithinThreshold
            ? AppColors.warning.withValues(alpha: 0.2)
            : AppColors.success.withValues(alpha: 0.15),
        textColor: isWithinThreshold ? AppColors.warning : AppColors.success,
      );
    }

    // days > 1
    if (isWithinThreshold) {
      return ExpiryInfo(
        state: ExpiryState.expiringSoon,
        daysRemaining: days,
        statusLabel: 'EXPIRING SOON',
        daysLabel: '$days days remaining',
        hasAlert: true,
        isExpired: false,
        badgeColor: AppColors.warning.withValues(alpha: 0.2),
        textColor: AppColors.warning,
      );
    } else {
      return ExpiryInfo(
        state: ExpiryState.normal,
        daysRemaining: days,
        statusLabel: 'NORMAL',
        daysLabel: '$days days remaining',
        hasAlert: false,
        isExpired: false,
        badgeColor: AppColors.success.withValues(alpha: 0.15),
        textColor: AppColors.success,
      );
    }
  }
}
