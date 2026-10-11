import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/responsive/responsive_breakpoints.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/connection_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/pending_operations_service.dart';
import '../../core/services/realtime_sync_service.dart';
import '../../core/theme/glass_widgets.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/connection_status_indicator.dart';
import '../../shared/widgets/notification_bell_icon.dart';
import '../adjustments/stock_adjustment_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../dispatch/dispatch_screen.dart';
import '../invoices/invoice_list_screen.dart';
import '../materials/materials_master_screen.dart';
import '../materials/materials_screen.dart';
import '../providers/app_providers.dart';
import '../reports/mur_report.dart';
import '../reports/reports_hub_screen.dart';
import '../settings/settings_screen.dart';
import '../storage/storage_screen.dart';
import '../transfers/transfers_screen.dart';
import '../vendors/vendors_screen.dart';
import '../warehouse/category_locations_screen.dart';
import '../../features/mira/presentation/pages/mira_page.dart';
import '../security/security_center_screen.dart';
import '../../shared/widgets/maple_pro_footer.dart';

// ─── Primary navigation items (bottom bar / rail) ────────────────────────────
class _PrimaryNavItem {
  final int screenIndex;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Color accent;

  const _PrimaryNavItem({
    required this.screenIndex,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.accent = AppColors.primaryLight,
  });
}

// ─── Restricted Tea navigation items (3 modules only) ───────────────────────
const List<_PrimaryNavItem> _teaNav = [
  _PrimaryNavItem(
    screenIndex: 0,
    label: 'Transfers',
    icon: Icons.swap_horiz_rounded,
    selectedIcon: Icons.swap_horiz_rounded,
    accent: AppColors.accent,
  ),
  _PrimaryNavItem(
    screenIndex: 1,
    label: 'Storage',
    icon: Icons.layers_outlined,
    selectedIcon: Icons.layers_rounded,
    accent: AppColors.primaryLight,
  ),
  _PrimaryNavItem(
    screenIndex: 2,
    label: 'Dispatch',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping_rounded,
    accent: AppColors.secondary,
  ),
];

const List<_PrimaryNavItem> _primaryNav = [
  _PrimaryNavItem(
    screenIndex: 0,
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    accent: AppColors.primaryLight,
  ),
  _PrimaryNavItem(
    screenIndex: 3,
    label: 'Materials',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    accent: AppColors.primaryLight,
  ),
  _PrimaryNavItem(
    screenIndex: 1,
    label: 'Invoices',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    accent: AppColors.primary,
  ),
  _PrimaryNavItem(
    screenIndex: 2,
    label: 'Transfers',
    icon: Icons.swap_horiz_rounded,
    selectedIcon: Icons.swap_horiz_rounded,
    accent: AppColors.accent,
  ),
  _PrimaryNavItem(
    screenIndex: 5,
    label: 'Storage',
    icon: Icons.layers_outlined,
    selectedIcon: Icons.layers_rounded,
    accent: AppColors.primaryLight,
  ),
  _PrimaryNavItem(
    screenIndex: 7,
    label: 'Dispatch',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping_rounded,
    accent: AppColors.secondary,
  ),
];

// ─── Secondary navigation items (More menu) ───────────────────────────────────
class _SecondaryNavItem {
  final int? screenIndex; // null = open as push route
  final String label;
  final IconData icon;
  final Color accent;
  final bool isMira;

  const _SecondaryNavItem({
    this.screenIndex,
    required this.label,
    required this.icon,
    this.accent = AppColors.primaryLight,
    this.isMira = false,
  });
}

const List<_SecondaryNavItem> _secondaryNav = [
  _SecondaryNavItem(
    label: 'MIRA AI',
    icon: Icons.auto_awesome,
    accent: Color(0xFF06B6D4),
    isMira: true,
  ),
  _SecondaryNavItem(
    screenIndex: 4,
    label: 'Materials Master',
    icon: Icons.dataset_outlined,
    accent: AppColors.primary,
  ),
  _SecondaryNavItem(
    screenIndex: 6,
    label: 'Vendors',
    icon: Icons.storefront_outlined,
    accent: AppColors.secondary,
  ),
  _SecondaryNavItem(
    screenIndex: 8,
    label: 'Stock Adjustment',
    icon: Icons.tune_rounded,
    accent: AppColors.warning,
  ),
  _SecondaryNavItem(
    screenIndex: 9,
    label: 'Shelf Mapping',
    icon: Icons.grid_view_outlined,
    accent: Color(0xFF8B5CF6),
  ),
  _SecondaryNavItem(
    screenIndex: 10,
    label: 'MUR Report',
    icon: Icons.analytics_outlined,
    accent: Color(0xFF8B5CF6),
  ),
  _SecondaryNavItem(
    screenIndex: 11,
    label: 'Reports Hub',
    icon: Icons.assessment_outlined,
    accent: AppColors.success,
  ),
  _SecondaryNavItem(
    screenIndex: null,
    label: 'Security Center',
    icon: Icons.shield_outlined,
    accent: Color(0xFF10B981),
  ),
  _SecondaryNavItem(
    screenIndex: null,
    label: 'Settings',
    icon: Icons.settings_outlined,
    accent: AppColors.textSecondary,
  ),
];

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  int _teaCurrentIndex = 0; // 0: Transfers, 1: Storage, 2: Dispatch

  // Dedicated 3 screens for Tea department
  late final List<Widget> _teaScreens = const [
    TransfersScreen(isEmbedded: true), // 0: Transfers
    StorageScreen(),                   // 1: Storage
    DispatchScreen(),                  // 2: Dispatch
  ];

  // 12 screens in exact order matching screen indices
  late final List<Widget> _screens = const [
    DashboardScreen(),       // 0
    InvoiceListScreen(),     // 1
    TransfersScreen(isEmbedded: true), // 2
    MaterialsScreen(),       // 3
    MaterialsMasterScreen(isEmbedded: true), // 4
    StorageScreen(),         // 5
    VendorsScreen(isEmbedded: true), // 6
    DispatchScreen(),        // 7
    StockAdjustmentScreen(isEmbedded: true), // 8
    CategoryLocationsScreen(isEmbedded: true), // 9
    MurReport(isEmbedded: true), // 10
    ReportsHubScreen(isEmbedded: true), // 11
  ];

  StreamSubscription<NotificationPayload>? _notificationSub;
  Timer? _otaTimer;

  @override
  void initState() {
    super.initState();
    _notificationSub = NotificationService.instance.onNotificationSelected.listen((payload) {
      if (mounted) {
        _handleNotificationNavigation(payload.refType, payload.refId);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 1. Independent OTA Update Check
      _otaTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) {
          AppUpdateService.instance.checkAndPromptUpdate(context: context);
        }
      });

      // 2. Background Sync and Alerts
      try {
        ref.read(realtimeSyncServiceProvider);
        ref.read(pendingOperationsProvider.notifier).processPendingQueue();
        ref.read(notificationsRepositoryProvider).recalculateAlerts();
      } catch (e) {
        debugPrint('HomeShell init error: $e');
      }
    });
  }

  @override
  void dispose() {
    _otaTimer?.cancel();
    _notificationSub?.cancel();
    super.dispose();
  }

  void _handleNotificationNavigation(String refType, String refId) {
    final isTeaUser = ref.read(isTeaUserProvider);
    switch (refType.toLowerCase()) {
      case 'material':
        if (isTeaUser) return;
        ref.read(materialsFilterProvider.notifier).update(
              (state) => state.copyWith(search: refId),
            );
        setState(() => _currentIndex = 3);
        break;
      case 'invoice':
        if (isTeaUser) return;
        setState(() => _currentIndex = 1);
        break;
      case 'transfer':
        if (isTeaUser) {
          setState(() => _teaCurrentIndex = 0);
        } else {
          setState(() => _currentIndex = 2);
        }
        break;
      case 'batch':
      case 'storage':
        if (isTeaUser) {
          setState(() => _teaCurrentIndex = 1);
        } else {
          setState(() => _currentIndex = 5);
        }
        break;
      case 'dispatch':
        if (isTeaUser) {
          setState(() => _teaCurrentIndex = 2);
        } else {
          setState(() => _currentIndex = 7);
        }
        break;
      case 'update':
        AppUpdateService.instance.showUpdateDialog(context);
        break;
      default:
        break;
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to log out from Benchmark MMS?',
      confirmText: 'Sign Out',
      cancelText: 'Cancel',
      isDestructive: true,
    );
    if (confirmed) {
      ref.read(authNotifierProvider.notifier).signOut();
    }
  }

  void _refreshAllData() {
    ref.read(connectionServiceProvider.notifier).checkConnectivity();
    ref.read(pendingOperationsProvider.notifier).processPendingQueue();
    ref.read(notificationsRepositoryProvider).recalculateAlerts();
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(materialsListProvider);
    ref.invalidate(activeBatchesProvider);
    ref.invalidate(inwardHistoryProvider);
    ref.invalidate(dispatchesListProvider);
    ref.invalidate(transfersListProvider);
    ref.invalidate(invoicesListProvider);
    ref.invalidate(vendorsListProvider);
    ref.invalidate(stockAdjustmentsListProvider);
    ref.invalidate(categoryLocationsProvider);
    ref.invalidate(notificationsListProvider);
    ref.invalidate(unreadNotificationsCountProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Syncing with PostgreSQL Realtime...'),
        duration: Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MoreMenuSheet(
        currentIndex: _currentIndex,
        onSelect: (item) {
          if (item.isMira) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MiraPage()));
          } else if (item.label == 'Security Center') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityCenterScreen()));
          } else if (item.screenIndex == null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          } else {
            setState(() => _currentIndex = item.screenIndex!);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTeaUser = ref.watch(isTeaUserProvider);
    final isTablet = ResponsiveBreakpoints.isTabletOrLarger(context);

    // Dedicated 3-module terminal for Tea department (Transfers, Storage, Dispatch)
    if (isTeaUser) {
      if (isTablet) {
        return _buildTeaTabletLayout(context);
      }
      return _buildTeaMobileLayout(context);
    }

    if (isTablet) {
      return _buildTabletLayout(context);
    }
    return _buildMobileLayout(context);
  }

  // ─── TEA TABLET LAYOUT: 3 Modules in Navigation Rail ────────────────────────
  Widget _buildTeaTabletLayout(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(isTablet: true, isTeaUser: true),
      body: AmbientBackground(
        child: Row(
          children: [
            _buildTeaCompactRail(),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.glassBorder),
            Expanded(
              child: IndexedStack(
                index: _teaCurrentIndex,
                children: _teaScreens,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeaCompactRail() {
    return Container(
      width: 78,
      color: const Color(0xF00A0F1D),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.eco_rounded, size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text(
                    'TEA',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (int i = 0; i < _teaNav.length; i++)
                    _buildTeaRailItem(_teaNav[i], isSelected: _teaCurrentIndex == i, index: i),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeaRailItem(_PrimaryNavItem item, {required bool isSelected, required int index}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => _teaCurrentIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? item.accent.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: item.accent.withValues(alpha: 0.4), width: 1) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isSelected ? item.selectedIcon : item.icon, size: 22, color: isSelected ? item.accent : AppColors.textMuted),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? item.accent : AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TABLET LAYOUT: Compact NavigationRail + content ───────────────────────
  Widget _buildTabletLayout(BuildContext context) {
    final primaryIndex = _primaryNav.indexWhere((n) => n.screenIndex == _currentIndex);

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(isTablet: true),
      body: AmbientBackground(
        child: Row(
          children: [
            // Compact Navigation Rail
            _buildCompactRail(primaryIndex),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.glassBorder),
            // Main Content
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactRail(int primaryIndex) {
    return Container(
      width: 72,
      color: const Color(0xF00A0F1D),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Primary nav items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (int i = 0; i < _primaryNav.length; i++)
                    _buildRailItem(_primaryNav[i], isSelected: primaryIndex == i, index: i),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Divider(color: AppColors.glassBorder, height: 1),
                  ),
                  // More button
                  _buildRailMoreButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRailItem(_PrimaryNavItem nav, {required bool isSelected, required int index}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Tooltip(
        message: nav.label,
        preferBelow: false,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = nav.screenIndex),
          borderRadius: BorderRadius.circular(12),
          splashColor: nav.accent.withValues(alpha: 0.2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 54,
            decoration: BoxDecoration(
              color: isSelected ? nav.accent.withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? nav.accent.withValues(alpha: 0.5) : Colors.transparent,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: nav.accent.withValues(alpha: 0.25), blurRadius: 12)]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? nav.selectedIcon : nav.icon,
                  size: 22,
                  color: isSelected ? nav.accent : AppColors.textSecondary,
                ),
                const SizedBox(height: 3),
                Text(
                  nav.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? nav.accent : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRailMoreButton() {
    final isSecondary = _secondaryNav.any((n) => n.screenIndex == _currentIndex);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Tooltip(
        message: 'More Modules',
        preferBelow: false,
        child: InkWell(
          onTap: _openMoreMenu,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 54,
            decoration: BoxDecoration(
              color: isSecondary
                  ? AppColors.primaryLight.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSecondary
                    ? AppColors.primaryLight.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSecondary ? Icons.apps_rounded : Icons.apps_outlined,
                  size: 22,
                  color: isSecondary ? AppColors.primaryLight : AppColors.textSecondary,
                ),
                const SizedBox(height: 3),
                Text(
                  'More',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: isSecondary ? FontWeight.w700 : FontWeight.w500,
                    color: isSecondary ? AppColors.primaryLight : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── TEA PHONE-ONLY LAYOUT: Transfers, Storage, Dispatch ONLY ───────────────
  Widget _buildTeaMobileLayout(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(isTablet: false, isTeaUser: true),
      body: AmbientBackground(
        child: IndexedStack(
          index: _teaCurrentIndex,
          children: _teaScreens,
        ),
      ),
      bottomNavigationBar: _buildTeaBottomNav(),
    );
  }

  Widget _buildTeaBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF2020617),
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  for (int i = 0; i < _teaNav.length; i++)
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _teaCurrentIndex = i),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          decoration: BoxDecoration(
                            color: _teaCurrentIndex == i ? _teaNav[i].accent.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _teaCurrentIndex == i ? _teaNav[i].selectedIcon : _teaNav[i].icon,
                                size: 20,
                                color: _teaCurrentIndex == i ? _teaNav[i].accent : AppColors.textMuted,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _teaNav[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: _teaCurrentIndex == i ? FontWeight.w700 : FontWeight.w500,
                                  color: _teaCurrentIndex == i ? _teaNav[i].accent : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              const MapleProFooter(compact: true, padding: EdgeInsets.symmetric(vertical: 2)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── STANDARD MOBILE LAYOUT: Bottom navigation bar ──────────────────────────
  Widget _buildMobileLayout(BuildContext context) {
    final primaryIndex = _primaryNav.indexWhere((n) => n.screenIndex == _currentIndex);
    final bottomIndex = primaryIndex >= 0 ? primaryIndex : _primaryNav.length;

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(isTablet: false, isTeaUser: false),
      body: AmbientBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: _buildBottomNav(bottomIndex),
    );
  }

  Widget _buildBottomNav(int bottomIndex) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF2020617),
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  for (int i = 0; i < _primaryNav.length; i++)
                    Expanded(child: _buildBottomNavItem(_primaryNav[i], isSelected: bottomIndex == i, index: i)),
                  Expanded(child: _buildBottomMoreItem(bottomIndex == _primaryNav.length)),
                ],
              ),
              const SizedBox(height: 2),
              const MapleProFooter(compact: true, padding: EdgeInsets.symmetric(vertical: 2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(_PrimaryNavItem nav, {required bool isSelected, required int index}) {
    return InkWell(
      onTap: () => setState(() => _currentIndex = nav.screenIndex),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? nav.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? nav.selectedIcon : nav.icon,
              size: 22,
              color: isSelected ? nav.accent : AppColors.textMuted,
            ),
            const SizedBox(height: 2),
            Text(
              nav.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? nav.accent : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomMoreItem(bool isSelected) {
    return InkWell(
      onTap: _openMoreMenu,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.apps_rounded : Icons.apps_outlined,
              size: 22,
              color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
            ),
            const SizedBox(height: 2),
            Text(
              'More',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── APP BAR ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar({required bool isTablet, bool isTeaUser = false}) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xE60A0F1D),
          border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isNarrow = width < 480;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: isNarrow ? 28 : 32,
                      height: isNarrow ? 28 : 32,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                    ),
                    SizedBox(width: isNarrow ? 8 : 10),
                    // Title and status
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              FactoryConstants.appName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: isNarrow ? 14 : 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          SizedBox(width: isNarrow ? 6 : 8),
                          ConnectionStatusIndicator(compact: isNarrow),
                          if (isTeaUser) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.eco_rounded, size: 10, color: Color(0xFF10B981)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'TEA',
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Current screen badge (tablet/desktop only)
                    if (isTablet && width >= 680) ...[
                      _buildCurrentScreenBadge(isTeaUser: isTeaUser),
                      const SizedBox(width: 4),
                    ],
                    // MIRA AI Assistant Quick Launch (Hidden for Tea user)
                    if (!isTeaUser)
                      IconButton(
                        icon: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF06B6D4), Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF06B6D4).withValues(alpha: 0.45),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.auto_awesome, size: 15, color: Colors.white),
                        ),
                        tooltip: 'MIRA AI Brain',
                        splashRadius: 22,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MiraPage()),
                        ),
                      ),
                    NotificationBellIcon(onNavigateToReference: _handleNotificationNavigation),
                    if (!isNarrow && !isTeaUser)
                      IconButton(
                        icon: const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF10B981)),
                        tooltip: 'Security Center',
                        splashRadius: 20,
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityCenterScreen())),
                      ),
                    if (!isNarrow && !isTeaUser)
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 20, color: AppColors.textSecondary),
                        tooltip: 'Settings',
                        splashRadius: 20,
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primaryLight),
                      tooltip: 'Sync Realtime Data',
                      splashRadius: 20,
                      onPressed: _refreshAllData,
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, size: 20, color: AppColors.danger),
                      tooltip: 'Sign Out',
                      splashRadius: 20,
                      onPressed: _confirmLogout,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentScreenBadge({bool isTeaUser = false}) {
    if (isTeaUser) {
      final safeIdx = _teaCurrentIndex.clamp(0, _teaNav.length - 1);
      final item = _teaNav[safeIdx];
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: item.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: item.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.selectedIcon, size: 12, color: item.accent),
            const SizedBox(width: 4),
            Text(
              item.label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: item.accent,
              ),
            ),
          ],
        ),
      );
    }
    final primary = _primaryNav.firstWhere(
      (n) => n.screenIndex == _currentIndex,
      orElse: () => const _PrimaryNavItem(screenIndex: -1, label: '', icon: Icons.apps_outlined, selectedIcon: Icons.apps_rounded),
    );
    final secondary = _secondaryNav.firstWhere(
      (n) => n.screenIndex == _currentIndex,
      orElse: () => const _SecondaryNavItem(label: '', icon: Icons.apps_outlined),
    );
    final label = primary.label.isNotEmpty ? primary.label : secondary.label;
    final icon = primary.label.isNotEmpty ? primary.selectedIcon : secondary.icon;
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primaryLight),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── More Menu Bottom Sheet ───────────────────────────────────────────────────
class _MoreMenuSheet extends StatelessWidget {
  final int currentIndex;
  final void Function(_SecondaryNavItem item) onSelect;

  const _MoreMenuSheet({required this.currentIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF50A0F1D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.apps_rounded, size: 18, color: AppColors.primaryLight),
                  const SizedBox(width: 8),
                  Text(
                    'All Modules',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.glassBorder),
            // Grid of secondary nav items
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.15,
                ),
                itemCount: _secondaryNav.length,
                itemBuilder: (context, i) {
                  final item = _secondaryNav[i];
                  final isSelected = item.screenIndex == currentIndex;
                  return _buildMenuGridItem(context, item, isSelected);
                },
              ),
            ),
            const MapleProFooter(compact: true, padding: EdgeInsets.only(bottom: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGridItem(BuildContext context, _SecondaryNavItem item, bool isSelected) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onSelect(item);
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? item.accent.withValues(alpha: 0.2)
              : const Color(0x221E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? item.accent.withValues(alpha: 0.5)
                : AppColors.glassBorder,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: item.accent.withValues(alpha: 0.2), blurRadius: 10)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 26,
              color: isSelected ? item.accent : AppColors.textSecondary,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? item.accent : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
