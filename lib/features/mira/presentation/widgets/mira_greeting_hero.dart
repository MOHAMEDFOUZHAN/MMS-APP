import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Quick Action Chip model for MIRA
class MiraQuickAction {
  final String label;
  final IconData icon;
  final String query;

  const MiraQuickAction({
    required this.label,
    required this.icon,
    required this.query,
  });
}

/// Premium Greeting & Quick Actions Hero Area
class MiraGreetingHero extends StatelessWidget {
  final String? userName;
  final ValueChanged<String> onSelectAction;

  const MiraGreetingHero({
    super.key,
    this.userName,
    required this.onSelectAction,
  });

  static const List<MiraQuickAction> _quickActions = [
    MiraQuickAction(
      label: 'Check Stock',
      icon: Icons.inventory_2_outlined,
      query: 'Check current stock levels for all raw materials',
    ),
    MiraQuickAction(
      label: 'Storage',
      icon: Icons.grid_view_outlined,
      query: 'Show material storage locations and shelf mappings',
    ),
    MiraQuickAction(
      label: "Today's Dispatch",
      icon: Icons.local_shipping_outlined,
      query: "What are today's scheduled dispatches and shipments?",
    ),
    MiraQuickAction(
      label: 'Low Stock',
      icon: Icons.warning_amber_rounded,
      query: 'Which materials are currently running low or below reorder level?',
    ),
    MiraQuickAction(
      label: 'Expiring Soon',
      icon: Icons.hourglass_top_rounded,
      query: 'What materials or batches are expiring soon?',
    ),
    MiraQuickAction(
      label: 'Reports',
      icon: Icons.analytics_outlined,
      query: 'Summarize inventory movement and material usage for today',
    ),
  ];

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;

    final validName = userName?.trim();
    final hasName = validName != null && validName.isNotEmpty;
    final timeGreeting = _getTimeGreeting();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Personalized Salutation (if user authenticated)
        if (hasName) ...[
          Text(
            '$timeGreeting, $validName.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 18 : 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: const Color(0xFFC4B5FD), // Soft Lavender
              shadows: [
                Shadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],

        // Hero Greeting: "How may I help you today?"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'How may I\nhelp you today?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 34 : 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.18,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                  blurRadius: 18,
                  offset: const Offset(0, 2),
                ),
                Shadow(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.25),
                  blurRadius: 28,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Intelligent Subtitle Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1E0B4B).withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 13, color: Color(0xFF22D3EE)),
              const SizedBox(width: 6),
              Text(
                'MMS Inventory Intelligence',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: const Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Quick Actions Horizontal Scroller
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: _quickActions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final action = _quickActions[index];
              return _buildQuickActionChip(action);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionChip(MiraQuickAction action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onSelectAction(action.query);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x33170A3D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                action.icon,
                size: 14,
                color: const Color(0xFF22D3EE),
              ),
              const SizedBox(width: 7),
              Text(
                action.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF1F5F9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
