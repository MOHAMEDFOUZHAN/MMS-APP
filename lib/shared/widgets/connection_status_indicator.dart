import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/connection_service.dart';
import 'pending_operations_sheet.dart';

class ConnectionStatusIndicator extends ConsumerWidget {
  final bool compact;

  const ConnectionStatusIndicator({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(connectionServiceProvider);

    Color dotColor;
    String label;
    Widget? icon;

    switch (conn.state) {
      case AppConnectionState.online:
        dotColor = AppColors.success;
        label = conn.pendingCount > 0 ? '${conn.pendingCount} pending' : 'Online';
        break;
      case AppConnectionState.offline:
        dotColor = AppColors.danger;
        label = conn.pendingCount > 0 ? 'Offline (${conn.pendingCount})' : 'Offline';
        break;
      case AppConnectionState.reconnecting:
        dotColor = AppColors.warning;
        label = 'Reconnecting...';
        break;
      case AppConnectionState.syncing:
        dotColor = AppColors.primary;
        label = 'Syncing...';
        icon = const SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primaryLight),
        );
        break;
      case AppConnectionState.syncError:
        dotColor = AppColors.warning;
        label = 'Sync Error (${conn.pendingCount})';
        break;
    }

    return InkWell(
      onTap: () => PendingOperationsSheet.show(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: dotColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dotColor.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon,
            ] else ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.8),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: dotColor,
              ),
            ),
            if (conn.pendingCount > 0 && conn.state != AppConnectionState.syncing) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${conn.pendingCount}',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
