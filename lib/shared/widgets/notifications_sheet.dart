import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/app_update_service.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../data/models/notification_model.dart';
import '../../presentation/providers/app_providers.dart';

class NotificationsSheet extends ConsumerStatefulWidget {
  final Function(String referenceType, String referenceId)? onNavigateToReference;
  final bool isDialog;

  const NotificationsSheet({
    super.key,
    this.onNavigateToReference,
    this.isDialog = false,
  });

  static Future<void> show(
    BuildContext context, {
    Function(String referenceType, String referenceId)? onNavigateToReference,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 650) {
      return showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.fromLTRB(20, 65, 20, 20),
          alignment: Alignment.topRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: NotificationsSheet(
                onNavigateToReference: onNavigateToReference,
                isDialog: true,
              ),
            ),
          ),
        ),
      );
    }

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
        maxHeight: widget.isDialog ? 620 : MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: const Color(0xF50A0F1D),
        borderRadius: widget.isDialog
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.glassBorder, width: 1.5),
        boxShadow: const [
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
          // Drag handle for sheet or Close button for dialog
          if (!widget.isDialog)
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
          if (!widget.isDialog) const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: AppColors.primaryLight, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Notifications & Alerts',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.textSecondary),
                    tooltip: 'Recalculate Alerts',
                    splashRadius: 18,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () async {
                      await ref.read(notificationsRepositoryProvider).recalculateAlerts();
                      ref.invalidate(notificationsListProvider);
                      ref.invalidate(unreadNotificationsCountProvider);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.done_all_rounded, size: 18, color: AppColors.primaryLight),
                    tooltip: 'Mark All Read',
                    splashRadius: 18,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () async {
                      await ref.read(notificationsRepositoryProvider).markAllAsRead();
                      ref.invalidate(notificationsListProvider);
                      ref.invalidate(unreadNotificationsCountProvider);
                    },
                  ),
                  if (widget.isDialog)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                      tooltip: 'Close Panel',
                      splashRadius: 18,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => Navigator.pop(context),
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

          // Genuine Application Update Announcement Banner (Requirement 8)
          ValueListenableBuilder<AppVersionInfo?>(
            valueListenable: AppUpdateService.instance.updateAvailableNotifier,
            builder: (context, updateInfo, _) {
              if (updateInfo == null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.system_update_rounded, color: AppColors.primaryLight, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'A new application update is available.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'v${updateInfo.versionName}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            updateInfo.releaseNotes.isNotEmpty
                                ? updateInfo.releaseNotes
                                : 'A new authorized version of Benchmark MMS is ready for installation.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryLight,
                                side: const BorderSide(color: AppColors.primaryLight, width: 0.8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              icon: const Icon(Icons.download_rounded, size: 13),
                              label: const Text('View Update', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                Navigator.pop(context);
                                AppUpdateService.instance.showUpdateDialog(context, updateInfo);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

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
