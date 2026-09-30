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
        if (count > 0)
          Positioned(
            top: 8,
            right: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.8),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
