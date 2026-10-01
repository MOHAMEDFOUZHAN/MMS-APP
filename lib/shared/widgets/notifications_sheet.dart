import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/notification_model.dart';
import '../../presentation/providers/app_providers.dart';

class NotificationsSheet extends ConsumerStatefulWidget {
  final Function(String referenceType, String referenceId)? onNavigateToReference;

  const NotificationsSheet({
    super.key,
    this.onNavigateToReference,
  });

  static Future<void> show(
    BuildContext context, {
    Function(String referenceType, String referenceId)? onNavigateToReference,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => NotificationsSheet(onNavigateToReference: onNavigateToReference),
    );
  }

  @override
  ConsumerState<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends ConsumerState<NotificationsSheet> {
  String _selectedFilter = 'all'; // 'all', 'unread', 'critical'

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificationsListProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
              Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: AppColors.primaryLight, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Notifications & Alerts',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_active_outlined, size: 20, color: AppColors.primaryLight),
                    tooltip: 'Send Test Push Notification',
                    onPressed: () async {
                      await NotificationService.instance.showNotification(
                        id: 9999,
                        title: '🔔 Benchmark MMS Notification Test',
                        body: 'Push notifications are active and operating normally! Stock, expiry, and invoice alerts will appear here.',
                        payload: 'system:test',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Test notification sent to status bar!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textSecondary),
                    tooltip: 'Recalculate Alerts',
                    onPressed: () async {
                      await ref.read(notificationsRepositoryProvider).recalculateAlerts();
                      ref.invalidate(notificationsListProvider);
                      ref.invalidate(unreadNotificationsCountProvider);
                    },
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await ref.read(notificationsRepositoryProvider).markAllAsRead();
                      ref.invalidate(notificationsListProvider);
                      ref.invalidate(unreadNotificationsCountProvider);
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 16, color: AppColors.primaryLight),
                    label: Text(
                      'Mark all read',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All Alerts'),
                const SizedBox(width: 8),
                _buildFilterChip('unread', 'Unread'),
                const SizedBox(width: 8),
                _buildFilterChip('critical', 'Critical (Out of Stock / Expired)'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content
          Expanded(
            child: notifsAsync.when(
              data: (list) {
                final filtered = list.where((n) {
                  if (_selectedFilter == 'unread') return !n.isRead;
                  if (_selectedFilter == 'critical') return n.isCritical;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.success),
                        const SizedBox(height: 12),
                        Text(
                          'No Active Alerts',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Inventory levels and shelf-life are healthy.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildNotificationCard(context, ref, item);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => Center(
                child: Text('Error: $err', style: const TextStyle(color: AppColors.danger)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = key),
      selectedColor: AppColors.primary.withValues(alpha: 0.25),
      backgroundColor: AppColors.surface,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primaryLight : AppColors.glassBorder,
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, WidgetRef ref, NotificationModel item) {
    Color sevColor;
    IconData sevIcon;

    switch (item.severity.toUpperCase()) {
      case 'CRITICAL':
        sevColor = AppColors.danger;
        sevIcon = Icons.error_outline_rounded;
        break;
      case 'WARNING':
        sevColor = AppColors.warning;
        sevIcon = Icons.warning_amber_rounded;
        break;
      default:
        sevColor = AppColors.primaryLight;
        sevIcon = Icons.info_outline_rounded;
    }

    return InkWell(
      onTap: () async {
        if (!item.isRead) {
          await ref.read(notificationsRepositoryProvider).markAsRead(item.id);
          ref.invalidate(notificationsListProvider);
          ref.invalidate(unreadNotificationsCountProvider);
        }

        if (item.referenceType != null && item.referenceId != null) {
          if (!context.mounted) return;
          Navigator.pop(context);
          widget.onNavigateToReference?.call(item.referenceType!, item.referenceId!);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead
              ? AppColors.surface.withValues(alpha: 0.3)
              : sevColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isRead ? AppColors.glassBorder : sevColor.withValues(alpha: 0.4),
            width: item.isRead ? 1 : 1.5,
          ),
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w700,
                            color: item.isRead ? AppColors.textPrimary : Colors.white,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sevColor,
                            boxShadow: [
                              BoxShadow(color: sevColor.withValues(alpha: 0.8), blurRadius: 6),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        QuantityFormatter.formatDateTime(item.createdAt),
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                      ),
                      if (item.referenceType != null)
                        Text(
                          'View ${item.referenceType} →',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryLight,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
