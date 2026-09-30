import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/services/connection_service.dart';
import '../../core/services/pending_operations_service.dart';

class PendingOperationsSheet extends ConsumerWidget {
  const PendingOperationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const PendingOperationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingList = ref.watch(pendingOperationsProvider);
    final conn = ref.watch(connectionServiceProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Color(0xF50A0F1D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline & Pending Sync Queue',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pendingList.length} operation${pendingList.length == 1 ? '' : 's'} waiting to sync with Supabase',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (pendingList.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(pendingOperationsProvider.notifier).retryAll();
                  },
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Sync All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Current Connection Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _getConnectionBannerBg(conn.state),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _getConnectionBannerBorder(conn.state)),
            ),
            child: Row(
              children: [
                Icon(_getConnectionIcon(conn.state), size: 18, color: _getConnectionColor(conn.state)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    conn.message,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getConnectionColor(conn.state),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(connectionServiceProvider.notifier).checkConnectivity(),
                  child: const Text('Check', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pending List or Empty State
          Expanded(
            child: pendingList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_done_rounded, size: 48, color: AppColors.success),
                        const SizedBox(height: 12),
                        Text(
                          'All Transactions Synchronized',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No pending offline operations stored on this device.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: pendingList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final op = pendingList[index];
                      return _buildOperationCard(context, ref, op);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationCard(BuildContext context, WidgetRef ref, PendingOperation op) {
    Color statusColor;
    switch (op.status) {
      case 'syncing':
        statusColor = AppColors.primary;
        break;
      case 'error':
        statusColor = AppColors.danger;
        break;
      default:
        statusColor = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      op.operationType.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      op.status.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                QuantityFormatter.formatDateTime(op.createdAt),
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Idempotency Key: ${op.idempotencyKey}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          if (op.lastError != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Error: ${op.lastError}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.danger),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Retries: ${op.retryCount}',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  ref.read(pendingOperationsProvider.notifier).removeOperation(op.localOperationId);
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.textMuted),
                label: const Text('Cancel', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(pendingOperationsProvider.notifier).retryOperation(op.localOperationId);
                },
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getConnectionColor(AppConnectionState state) {
    switch (state) {
      case AppConnectionState.online:
        return AppColors.success;
      case AppConnectionState.offline:
        return AppColors.danger;
      case AppConnectionState.reconnecting:
        return AppColors.warning;
      case AppConnectionState.syncing:
        return AppColors.primary;
      case AppConnectionState.syncError:
        return AppColors.warning;
    }
  }

  Color _getConnectionBannerBg(AppConnectionState state) {
    return _getConnectionColor(state).withValues(alpha: 0.1);
  }

  Color _getConnectionBannerBorder(AppConnectionState state) {
    return _getConnectionColor(state).withValues(alpha: 0.3);
  }

  IconData _getConnectionIcon(AppConnectionState state) {
    switch (state) {
      case AppConnectionState.online:
        return Icons.wifi_rounded;
      case AppConnectionState.offline:
        return Icons.wifi_off_rounded;
      case AppConnectionState.reconnecting:
        return Icons.wifi_protected_setup_rounded;
      case AppConnectionState.syncing:
        return Icons.sync_rounded;
      case AppConnectionState.syncError:
        return Icons.warning_amber_rounded;
    }
  }
}
