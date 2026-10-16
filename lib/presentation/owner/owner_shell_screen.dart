import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/app_update_service.dart';
import '../providers/owner_providers.dart';
import 'owner_login_screen.dart';
import 'sections/owner_live_stock_screen.dart';
import 'sections/owner_out_of_stock_screen.dart';
import 'sections/owner_reorder_screen.dart';
import 'sections/owner_expiry_list_screen.dart';

/// Management Login Portal Shell
/// Exactly 4 Pages:
/// 1. Live Stock (all materials in one unified single page)
/// 2. Out of Stock (strictly zero-stock materials across the business)
/// 3. Reorder Level (materials needing replenishment with reorder level edit capability)
/// 4. Expiry List (materials/products with tracked expiry dates and alert settings)
class OwnerShellScreen extends ConsumerStatefulWidget {
  final int initialSection; // 0 = Live Stock, 1 = Out of Stock, 2 = Reorder Level, 3 = Expiry List

  const OwnerShellScreen({
    super.key,
    this.initialSection = 0,
  });

  @override
  ConsumerState<OwnerShellScreen> createState() => _OwnerShellScreenState();
}

class _OwnerShellScreenState extends ConsumerState<OwnerShellScreen> {
  late int _currentSection; // 0 = Live Stock, 1 = Out of Stock, 2 = Reorder Level, 3 = Expiry List

  @override
  void initState() {
    super.initState();
    _currentSection = widget.initialSection.clamp(0, 3);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!SupabaseConfig.isInitialized) return;
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
                  child: Text('ACCESS DENIED: Authorized executive management access only.'),
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

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFF59E0B), size: 20),
            const SizedBox(width: 10),
            Text(
              'Sign Out of Management Portal',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to end your management session?',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(ownerAuthNotifierProvider.notifier).signOutOwner();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OwnerLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 640;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0A0F1D),
            border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                // Logo
                Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                ),
                const SizedBox(width: 8),

                // App Title & Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Benchmark MMS',
                        style: GoogleFonts.inter(
                          fontSize: isWide ? 14 : 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Management Portal',
                        style: GoogleFonts.inter(
                          fontSize: isWide ? 10 : 9,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF59E0B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Desktop / Tablet Navigation Buttons
                if (isWide) ...[
                  _buildNavButton(
                    label: 'Live Stock',
                    icon: Icons.inventory_2_rounded,
                    isSelected: _currentSection == 0,
                    accentColor: const Color(0xFF10B981),
                    onTap: () => setState(() => _currentSection = 0),
                  ),
                  const SizedBox(width: 4),
                  _buildNavButton(
                    label: 'Out of Stock',
                    icon: Icons.remove_shopping_cart_rounded,
                    isSelected: _currentSection == 1,
                    accentColor: const Color(0xFFEF4444),
                    onTap: () => setState(() => _currentSection = 1),
                  ),
                  const SizedBox(width: 4),
                  _buildNavButton(
                    label: 'Reorder Level',
                    icon: Icons.low_priority_rounded,
                    isSelected: _currentSection == 2,
                    accentColor: const Color(0xFFF59E0B),
                    onTap: () => setState(() => _currentSection = 2),
                  ),
                  const SizedBox(width: 4),
                  _buildNavButton(
                    label: 'Expiry List',
                    icon: Icons.event_busy_rounded,
                    isSelected: _currentSection == 3,
                    accentColor: const Color(0xFFF97316),
                    onTap: () => setState(() => _currentSection = 3),
                  ),
                  const SizedBox(width: 6),
                ],

                // Management Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Management',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),

                // Sign out button
                IconButton(
                  tooltip: 'Sign Out',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFF94A3B8)),
                  onPressed: _handleSignOut,
                ),
              ],
            ),
          ),
        ),
      ),

      // IndexedStack preserves state and scroll positions of the 4 pages
      body: IndexedStack(
        index: _currentSection,
        children: const [
          OwnerLiveStockScreen(),
          OwnerOutOfStockScreen(),
          OwnerReorderScreen(),
          OwnerExpiryListScreen(),
        ],
      ),

      // Mobile Bottom Navigation Bar (Phone layout)
      bottomNavigationBar: isWide
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  backgroundColor: const Color(0xFF0F172A),
                  indicatorColor: _getTabAccentColor(_currentSection).withValues(alpha: 0.2),
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected ? Colors.white : const Color(0xFF94A3B8),
                    );
                  }),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return IconThemeData(
                      size: 22,
                      color: selected ? _getTabAccentColor(_currentSection) : const Color(0xFF94A3B8),
                    );
                  }),
                ),
                child: NavigationBar(
                  selectedIndex: _currentSection,
                  onDestinationSelected: (idx) => setState(() => _currentSection = idx),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2_rounded),
                      label: 'Live Stock',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.remove_shopping_cart_outlined),
                      selectedIcon: Icon(Icons.remove_shopping_cart_rounded),
                      label: 'Out of Stock',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.low_priority_rounded),
                      selectedIcon: Icon(Icons.low_priority_rounded),
                      label: 'Reorder Level',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.event_busy_outlined),
                      selectedIcon: Icon(Icons.event_busy_rounded),
                      label: 'Expiry List',
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Color _getTabAccentColor(int section) {
    switch (section) {
      case 0:
        return const Color(0xFF10B981);
      case 1:
        return const Color(0xFFEF4444);
      case 2:
        return const Color(0xFFF59E0B);
      case 3:
        return const Color(0xFFF97316);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Widget _buildNavButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accentColor.withValues(alpha: 0.6) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? accentColor : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
