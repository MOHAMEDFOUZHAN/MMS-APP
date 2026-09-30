import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/responsive/responsive_breakpoints.dart';
import '../../core/services/connection_service.dart';
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

enum NavSection {
  main('MAIN'),
  transactions('TRANSACTIONS'),
  materials('MATERIALS'),
  operations('OPERATIONS'),
  reporting('REPORTING');

  final String title;
  const NavSection(this.title);
}

class NavItemDef {
  final int index;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final NavSection section;
  final Color accentColor;

  const NavItemDef({
    required this.index,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.section,
    this.accentColor = AppColors.primaryLight,
  });
}

const List<NavItemDef> _navItems = [
  // 1. Dashboard (MAIN)
  NavItemDef(
    index: 0,
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    section: NavSection.main,
    accentColor: AppColors.primaryLight,
  ),
  // 2. Invoices (TRANSACTIONS)
  NavItemDef(
    index: 1,
    label: 'Invoices',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    section: NavSection.transactions,
    accentColor: AppColors.primary,
  ),
  // 3. Transfers (TRANSACTIONS)
  NavItemDef(
    index: 2,
    label: 'Transfers',
    icon: Icons.swap_horiz_rounded,
    selectedIcon: Icons.swap_horiz_rounded,
    section: NavSection.transactions,
    accentColor: AppColors.accent,
  ),
  // 4. Materials (MATERIALS)
  NavItemDef(
    index: 3,
    label: 'Materials',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    section: NavSection.materials,
    accentColor: AppColors.primaryLight,
  ),
  // 5. Materials Master (MATERIALS)
  NavItemDef(
    index: 4,
    label: 'Materials Master',
    icon: Icons.dataset_outlined,
    selectedIcon: Icons.dataset_rounded,
    section: NavSection.materials,
    accentColor: AppColors.primary,
  ),
  // 6. Storage (MATERIALS)
  NavItemDef(
    index: 5,
    label: 'Storage',
    icon: Icons.layers_outlined,
    selectedIcon: Icons.layers_rounded,
    section: NavSection.materials,
    accentColor: AppColors.primaryLight,
  ),
  // 7. Vendors (OPERATIONS)
  NavItemDef(
    index: 6,
    label: 'Vendors',
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront_rounded,
    section: NavSection.operations,
    accentColor: AppColors.secondary,
  ),
  // 8. Dispatch (OPERATIONS)
  NavItemDef(
    index: 7,
    label: 'Dispatch',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping_rounded,
    section: NavSection.operations,
    accentColor: AppColors.secondary,
  ),
  // 9. Stock Adjustment (OPERATIONS)
  NavItemDef(
    index: 8,
    label: 'Stock Adjustment',
    icon: Icons.tune_rounded,
    selectedIcon: Icons.tune_rounded,
    section: NavSection.operations,
    accentColor: AppColors.warning,
  ),
  // 10. Shelf Mapping (OPERATIONS)
  NavItemDef(
    index: 9,
    label: 'Shelf Mapping',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
    section: NavSection.operations,
    accentColor: Color(0xFF8B5CF6),
  ),
  // 11. MUR (REPORTING)
  NavItemDef(
    index: 10,
    label: 'MUR',
    icon: Icons.analytics_outlined,
    selectedIcon: Icons.analytics_rounded,
    section: NavSection.reporting,
    accentColor: Color(0xFF8B5CF6),
  ),
  // 12. Reports (REPORTING)
  NavItemDef(
    index: 11,
    label: 'Reports',
    icon: Icons.assessment_outlined,
    selectedIcon: Icons.assessment_rounded,
    section: NavSection.reporting,
    accentColor: AppColors.success,
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

  // Exact 12 screens matching navigation item definitions
  late final List<Widget> _screens = const [
    DashboardScreen(),
    InvoiceListScreen(),
    TransfersScreen(isEmbedded: true),
    MaterialsScreen(),
    MaterialsMasterScreen(isEmbedded: true),
    StorageScreen(),
    VendorsScreen(isEmbedded: true),
    DispatchScreen(),
    StockAdjustmentScreen(isEmbedded: true),
    CategoryLocationsScreen(isEmbedded: true),
    MurReport(isEmbedded: true),
    ReportsHubScreen(isEmbedded: true),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(realtimeSyncServiceProvider);
        ref.read(pendingOperationsProvider.notifier).processPendingQueue();
        ref.read(notificationsRepositoryProvider).recalculateAlerts();
      } catch (e) {
        debugPrint('HomeShell init error: $e');
      }
    });
  }

  void _handleNotificationNavigation(String refType, String refId) {
    switch (refType.toLowerCase()) {
      case 'material':
        ref.read(materialsFilterProvider.notifier).update(
              (state) => state.copyWith(search: refId),
            );
        setState(() => _currentIndex = 3); // Materials screen
        break;
      case 'invoice':
        setState(() => _currentIndex = 1); // Invoices screen
        break;
      case 'transfer':
        setState(() => _currentIndex = 2); // Transfers screen
        break;
      case 'batch':
      case 'storage':
        setState(() => _currentIndex = 5); // Storage screen
        break;
      case 'dispatch':
        setState(() => _currentIndex = 7); // Dispatch screen
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

  @override
  Widget build(BuildContext context) {
    final isTabletOrDesktop = ResponsiveBreakpoints.isTabletOrLarger(context);

    if (isTabletOrDesktop) {
      return _buildDesktopLayout(context);
    } else {
      return _buildMobileLayout(context);
    }
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(context, isTablet: true),
      body: AmbientBackground(
        child: Row(
          children: [
            _buildSidebar(context, isDrawer: false),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.glassBorder),
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

  Widget _buildMobileLayout(BuildContext context) {
    // Bottom bar handles direct access to the top 4 modules, plus 'All Modules' for drawer
    final bottomNavIndex = _currentIndex < 4 ? _currentIndex : 4;

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(context, isTablet: false),
      drawer: Drawer(
        backgroundColor: const Color(0xF20A0F1D),
        child: _buildSidebar(context, isDrawer: true),
      ),
      body: AmbientBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xF2020617),
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: NavigationBar(
          selectedIndex: bottomNavIndex,
          onDestinationSelected: (idx) {
            if (idx == 4) {
              _scaffoldKey.currentState?.openDrawer();
            } else {
              setState(() => _currentIndex = idx);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Invoices',
            ),
            NavigationDestination(
              icon: Icon(Icons.swap_horiz_rounded),
              selectedIcon: Icon(Icons.swap_horiz_rounded),
              label: 'Transfers',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Materials',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_rounded),
              selectedIcon: Icon(Icons.menu_open_rounded),
              label: 'All Modules',
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, {required bool isTablet}) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(62),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!isTablet) ...[
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 22),
                    tooltip: 'All Modules',
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 4),
                ],
                Container(
                  width: 34,
                  height: 34,
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
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        FactoryConstants.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const ConnectionStatusIndicator(),
                    ],
                  ),
                ),
                NotificationBellIcon(onNavigateToReference: _handleNotificationNavigation),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primaryLight),
                  tooltip: 'Sync Realtime Data',
                  onPressed: _refreshAllData,
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 20, color: AppColors.danger),
                  tooltip: 'Sign Out',
                  onPressed: _confirmLogout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, {required bool isDrawer}) {
    return Container(
      width: isDrawer ? 280 : 230,
      decoration: BoxDecoration(
        color: const Color(0xF20A0F1D),
        boxShadow: isDrawer
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(4, 0),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'BENCHMARK MMS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'FACTORY PORTAL',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.glassBorder),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  for (final section in NavSection.values) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 14, top: 12, bottom: 4),
                      child: Text(
                        section.title,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted.withValues(alpha: 0.65),
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    for (final item in _navItems.where((i) => i.section == section))
                      _buildNavItem(item, isDrawer: isDrawer),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.glassBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.8),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Online • Sync Live',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 18, color: AppColors.textMuted),
                    tooltip: 'Settings',
                    onPressed: () {
                      if (isDrawer) Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(NavItemDef item, {required bool isDrawer}) {
    final isSelected = _currentIndex == item.index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () {
          if (isDrawer) Navigator.pop(context);
          setState(() => _currentIndex = item.index);
        },
        borderRadius: BorderRadius.circular(10),
        splashColor: item.accentColor.withValues(alpha: 0.15),
        highlightColor: item.accentColor.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? item.accentColor.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? item.accentColor.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: item.accentColor.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                child: Center(
                  child: Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    size: 19,
                    color: isSelected ? item.accentColor : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  width: 3.5,
                  height: 16,
                  decoration: BoxDecoration(
                    color: item.accentColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: item.accentColor.withValues(alpha: 0.8),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
