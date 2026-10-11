import '../../core/services/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../presentation/providers/app_providers.dart';
import 'notifications_sheet.dart';

class NotificationBellIcon extends ConsumerWidget {
  final Function(String referenceType, String referenceId)? onNavigateToReference;

  const NotificationBellIcon({
    super.key,
    this.onNavigateToReference,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadNotificationsCountProvider);
    final count = unreadCountAsync.value ?? 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, size: 22, color: AppColors.textPrimary),
          tooltip: 'Notifications & Alerts',
          onPressed: () {
            NotificationsSheet.show(
              context,
              onNavigateToReference: onNavigateToReference,
            );
          },
        ),
        ValueListenableBuilder(
          valueListenable: AppUpdateService.instance.updateAvailableNotifier,
          builder: (context, update, _) {
            if (count > 0) {
              return Positioned(
                top: 4,
                right: 4,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0A0F1D), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.danger.withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                  ),
                ),
              );
            }
            if (update != null) {
              return Positioned(
                top: 6,
                right: 6,
                child: IgnorePointer(
                  child: Container(
                    key: const ValueKey('app_update_indicator_dot'),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0A0F1D), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.8),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
