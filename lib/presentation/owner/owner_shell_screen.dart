import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/app_update_service.dart';
import '../providers/owner_providers.dart';
import '../security/security_center_screen.dart';
import 'owner_activity_screen.dart';
import 'owner_alerts_screen.dart';
import 'owner_analytics_screen.dart';
import 'owner_dashboard_screen.dart';
import 'owner_login_screen.dart';
import 'owner_reports_hub_screen.dart';
import 'owner_settings_screen.dart';

class OwnerShellScreen extends ConsumerStatefulWidget {
  const OwnerShellScreen({super.key});

  @override
  ConsumerState<OwnerShellScreen> createState() => _OwnerShellScreenState();
}

class _OwnerShellScreenState extends ConsumerState<OwnerShellScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(ownerRepositoryProvider).verifyOwnerAccess();
        if (mounted) {
          AppUpdateService.instance.checkAndPromptUpdate(context: context);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('ACCESS DENIED: Authorized executive owner access only.'),
                ),
              ],
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OwnerLoginScreen()),
          (route) => false,
        );
      }
    });
  }

  final List<_OwnerNavItem> _navItems = const [
    _OwnerNavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      accent: Color(0xFFF59E0B),
    ),
    _OwnerNavItem(
      label: 'Analytics',
      icon: Icons.trending_up_rounded,
      selectedIcon: Icons.trending_up_rounded,
      accent: Color(0xFF06B6D4),
    ),
    _OwnerNavItem(
      label: 'Reports',
      icon: Icons.assessment_outlined,
      selectedIcon: Icons.assessment_rounded,
      accent: Color(0xFF6366F1),
    ),
    _OwnerNavItem(
      label: 'Activity',
      icon: Icons.history_rounded,
      selectedIcon: Icons.history_rounded,
      accent: Color(0xFF10B981),
    ),
    _OwnerNavItem(
      label: 'Alerts',
      icon: Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_active_rounded,
      accent: AppColors.danger,
    ),
    _OwnerNavItem(
      label: 'Security',
      icon: Icons.shield_outlined,
      selectedIcon: Icons.shield_rounded,
      accent: Color(0xFF38BDF8),
    ),
    _OwnerNavItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      accent: Color(0xFF9CA3AF),
    ),
  ];

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return const OwnerDashboardScreen();
      case 1:
        return const OwnerAnalyticsScreen();
      case 2:
        return const OwnerReportsHubScreen(isEmbedded: true);
      case 3:
        return const OwnerActivityScreen();
      case 4:
        return const OwnerAlertsScreen();
      case 5:
        return const SecurityCenterScreen();
      case 6:
        return const OwnerSettingsScreen();
      default:
        return const OwnerDashboardScreen();
    }
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF1F2937)),
      ),
      builder: (ctx) {
        final email = ref.read(ownerAuthNotifierProvider).userEmail ?? 'owner';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Executive Identity Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF374151)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, size: 20, color: Color(0xFFF59E0B)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              email,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Verified Executive Owner • Active Session',
                              style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // More Menu Items
                _buildMoreMenuItem(
                  icon: Icons.history_rounded,
                  label: 'Activity & Audit Trail',
                  accent: const Color(0xFF10B981),
                  isSelected: _currentIndex == 3,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _currentIndex = 3);
                  },
                ),
                _buildMoreMenuItem(
                  icon: Icons.shield_rounded,
                  label: 'Security Center',
                  accent: const Color(0xFF38BDF8),
                  isSelected: _currentIndex == 5,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _currentIndex = 5);
                  },
                ),
                _buildMoreMenuItem(
                  icon: Icons.settings_rounded,
                  label: 'Owner Settings',
                  accent: const Color(0xFF9CA3AF),
                  isSelected: _currentIndex == 6,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _currentIndex = 6);
                  },
                ),
                _buildMoreMenuItem(
                  icon: Icons.account_circle_outlined,
                  label: 'Executive Profile & Account',
                  accent: const Color(0xFFF59E0B),
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showProfileDialog(context);
                  },
                ),
                const Divider(color: Color(0xFF1F2937), height: 16),
                _buildMoreMenuItem(
                  icon: Icons.power_settings_new_rounded,
                  label: 'End Session (Sign Out)',
                  accent: AppColors.danger,
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleLogout(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoreMenuItem({
    required IconData icon,
    required String label,
    required Color accent,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: accent.withValues(alpha: 0.5)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: accent),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? accent : Colors.white,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    final ownerAuth = ref.read(ownerAuthNotifierProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF374151)),
        ),
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: Color(0xFFF59E0B), size: 20),
            const SizedBox(width: 8),
            Text(
              'Executive Profile',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileRow('Account Identifier', ownerAuth.userEmail ?? 'owner'),
            const SizedBox(height: 10),
            _buildProfileRow('Role', 'OWNER (Full Executive Privileges)'),
            const SizedBox(height: 10),
            _buildProfileRow('Server Authentication', 'Supabase Server Auth Verified'),
            const SizedBox(height: 10),
            _buildProfileRow('Permissions', 'ALL (owner.*, reports.*, rpc.*)'),
            const SizedBox(height: 10),
            _buildProfileRow('Session Status', 'Authenticated & Encrypted'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFFF59E0B))),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF374151)),
        ),
        title: Text(
          'Owner Portal Sign Out',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to end your executive owner session?',
          style: TextStyle(fontSize: 13, color: Color(0xFFD1D5DB)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SIGN OUT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(ownerAuthNotifierProvider.notifier).signOutOwner();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OwnerLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerAuth = ref.watch(ownerAuthNotifierProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;
        final isCompact = constraints.maxWidth < 600;

        return Scaffold(
          backgroundColor: const Color(0xFF030712),
          appBar: AppBar(
            backgroundColor: const Color(0xFF111827),
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.admin_panel_settings_rounded, size: 14, color: Color(0xFFF59E0B)),
                      if (!isCompact) ...[
                        const SizedBox(width: 6),
                        Text(
                          'EXECUTIVE PORTAL',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: isCompact ? 8 : 12),
                Expanded(
                  child: Text(
                    _navItems[_currentIndex].label,
                    style: GoogleFonts.inter(
                      fontSize: isCompact ? 14 : 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              // Owner Identity Pill
              InkWell(
                onTap: () => _showProfileDialog(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF374151)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      if (!isCompact) ...[
                        const SizedBox(width: 6),
                        Text(
                          ownerAuth.userEmail ?? 'owner',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE5E7EB)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Logout Button
              IconButton(
                icon: const Icon(Icons.power_settings_new_rounded, color: AppColors.danger, size: 20),
                tooltip: 'Owner Logout',
                onPressed: () => _handleLogout(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: isWide
              ? Row(
                  children: [
                    NavigationRail(
                      backgroundColor: const Color(0xFF111827),
                      selectedIndex: _currentIndex,
                      onDestinationSelected: (val) {
                        setState(() => _currentIndex = val);
                      },
                      labelType: NavigationRailLabelType.all,
                      indicatorColor: _navItems[_currentIndex].accent.withValues(alpha: 0.2),
                      selectedLabelTextStyle: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _navItems[_currentIndex].accent,
                      ),
                      unselectedLabelTextStyle: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                      destinations: _navItems.map((item) {
                        return NavigationRailDestination(
                          icon: Icon(item.icon, color: const Color(0xFF9CA3AF), size: 20),
                          selectedIcon: Icon(item.selectedIcon, color: item.accent, size: 22),
                          label: Text(item.label),
                        );
                      }).toList(),
                    ),
                    const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF1F2937)),
                    Expanded(child: _buildCurrentPage()),
                  ],
                )
              : _buildCurrentPage(),
          bottomNavigationBar: isWide
              ? null
              : Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF111827),
                    border: Border(top: BorderSide(color: Color(0xFF1F2937))),
                  ),
                  child: BottomNavigationBar(
                    currentIndex: () {
                      // Map current index to 5 mobile tabs:
                      // 0: Dashboard
                      // 1: Analytics
                      // 2: Reports
                      // 4: Alerts
                      // 3, 5, 6: More
                      if (_currentIndex == 0) return 0;
                      if (_currentIndex == 1) return 1;
                      if (_currentIndex == 2) return 2;
                      if (_currentIndex == 4) return 3;
                      return 4; // More
                    }(),
                    onTap: (val) {
                      if (val == 0) setState(() => _currentIndex = 0);
                      if (val == 1) setState(() => _currentIndex = 1);
                      if (val == 2) setState(() => _currentIndex = 2);
                      if (val == 3) setState(() => _currentIndex = 4); // Alerts
                      if (val == 4) {
                        _showMoreMenu(context);
                      }
                    },
                    backgroundColor: const Color(0xFF111827),
                    type: BottomNavigationBarType.fixed,
                    selectedItemColor: const Color(0xFFF59E0B),
                    unselectedItemColor: const Color(0xFF9CA3AF),
                    selectedFontSize: 11,
                    unselectedFontSize: 10,
                    items: [
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.dashboard_outlined, size: 20),
                        activeIcon: Icon(Icons.dashboard_rounded, size: 22),
                        label: 'Dashboard',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.trending_up_rounded, size: 20),
                        activeIcon: Icon(Icons.trending_up_rounded, size: 22),
                        label: 'Analytics',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.assessment_outlined, size: 20),
                        activeIcon: Icon(Icons.assessment_rounded, size: 22),
                        label: 'Reports',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.notifications_none_rounded, size: 20),
                        activeIcon: Icon(Icons.notifications_active_rounded, size: 22),
                        label: 'Alerts',
                      ),
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.menu_rounded, size: 20),
                        activeIcon: Icon(Icons.menu_open_rounded, size: 22, color: const Color(0xFFF59E0B)),
                        label: () {
                          if (_currentIndex == 3) return 'Activity';
                          if (_currentIndex == 5) return 'Security';
                          if (_currentIndex == 6) return 'Settings';
                          return 'More';
                        }(),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _OwnerNavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Color accent;

  const _OwnerNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.accent,
  });
}
