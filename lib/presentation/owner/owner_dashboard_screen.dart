import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/responsive/responsive_breakpoints.dart';
import '../../shared/widgets/maple_pro_footer.dart';
import '../providers/owner_providers.dart';
import 'widgets/owner_report_components.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  final ValueChanged<int>? onSelectSection;

  const OwnerDashboardScreen({
    super.key,
    this.onSelectSection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTablet = ResponsiveBreakpoints.isTabletOrLarger(context);
    final adminStockAsync = ref.watch(ownerAdminLiveStockProvider(null));
    final teaMaterialsAsync = ref.watch(ownerTeaLiveMaterialsProvider((search: null, category: null)));
    final chocMaterialsAsync = ref.watch(ownerChocolateLiveMaterialsProvider((search: null, category: null)));
    final outOfStockAsync = ref.watch(ownerOutOfStockReportProvider((department: 'ALL', search: null)));
    final reorderAsync = ref.watch(ownerReorderReportProvider((department: 'ALL', search: null, status: 'REORDER_REQUIRED')));

    // Calculate enterprise totals from authoritative live stock
    int totalMaterialsCount = 0;
    double adminHeldStock = 0.0;
    adminStockAsync.whenData((items) {
      totalMaterialsCount = items.length;
      for (final item in items) {
        adminHeldStock += item.adminStock;
      }
    });

    int teaActiveCount = teaMaterialsAsync.valueOrNull?.length ?? 0;
    int chocActiveCount = chocMaterialsAsync.valueOrNull?.length ?? 0;
    int outOfStockCount = outOfStockAsync.valueOrNull?.length ?? 0;
    int reorderAlertsCount = reorderAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFF59E0B),
          backgroundColor: const Color(0xFF1E293B),
          onRefresh: () async {
            ref.invalidate(ownerAdminLiveStockProvider);
            ref.invalidate(ownerTeaLiveMaterialsProvider);
            ref.invalidate(ownerChocolateLiveMaterialsProvider);
            ref.invalidate(ownerOutOfStockReportProvider);
            ref.invalidate(ownerReorderReportProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Executive Welcome & Quick Info
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shield_outlined, size: 14, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 6),
                                Text(
                                  'EXECUTIVE MANAGEMENT PORTAL',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFF59E0B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF10B981)),
                                const SizedBox(width: 4),
                                Text(
                                  'READ-ONLY AUDIT',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Operations & Inventory Center',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 22 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select an operations center below to monitor live stock, review transactions, and audit business activity without navigating operational screens.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick High-Level Pulse Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OwnerKpiChip(
                            label: 'MASTER MATERIALS',
                            value: '$totalMaterialsCount',
                            subtitle: 'Catalogued Items',
                            icon: Icons.inventory_2_rounded,
                            accentColor: const Color(0xFF06B6D4),
                          ),
                          OwnerKpiChip(
                            label: 'ADMIN WAREHOUSE STOCK',
                            value: QuantityFormatter.formatClean(adminHeldStock),
                            subtitle: 'Current Available',
                            icon: Icons.warehouse_rounded,
                            accentColor: const Color(0xFF10B981),
                          ),
                          OwnerKpiChip(
                            label: 'OUT OF STOCK ITEMS',
                            value: '$outOfStockCount',
                            subtitle: 'Zero Balance Materials',
                            icon: Icons.warning_amber_rounded,
                            accentColor: const Color(0xFFEF4444),
                          ),
                          OwnerKpiChip(
                            label: 'REORDER ALERTS',
                            value: '$reorderAlertsCount',
                            subtitle: 'Need Replenishment',
                            icon: Icons.notification_important_rounded,
                            accentColor: const Color(0xFFF59E0B),
                          ),
                          OwnerKpiChip(
                            label: 'TEA ACTIVE MATERIALS',
                            value: '$teaActiveCount',
                            subtitle: 'Transferred to Tea',
                            icon: Icons.eco_rounded,
                            accentColor: const Color(0xFF10B981),
                          ),
                          OwnerKpiChip(
                            label: 'CHOCOLATE ACTIVE MATERIALS',
                            value: '$chocActiveCount',
                            subtitle: 'Transferred to Choc',
                            icon: Icons.cookie_rounded,
                            accentColor: const Color(0xFFD97706),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section Title
                Row(
                  children: [
                    const Icon(Icons.dashboard_customize_rounded, size: 18, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Text(
                      'BUSINESS REPORTING SECTIONS',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFCBD5E1),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ════════════════════════════════════════════════════════════
                // FIVE MAIN SECTION BUTTONS
                // 1. Admin
                // 2. Tea Section
                // 3. Chocolate Section
                // 4. Out of Stock
                // 5. Reorder Report
                // ════════════════════════════════════════════════════════════
                if (isTablet) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildAdminSectionButton(context)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTeaSectionButton(context)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildChocolateSectionButton(context)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildOutOfStockSectionButton(context)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildReorderSectionButton(context)),
                    ],
                  ),
                ] else
                  Column(
                    children: [
                      _buildAdminSectionButton(context),
                      const SizedBox(height: 14),
                      _buildTeaSectionButton(context),
                      const SizedBox(height: 14),
                      _buildChocolateSectionButton(context),
                      const SizedBox(height: 14),
                      _buildOutOfStockSectionButton(context),
                      const SizedBox(height: 14),
                      _buildReorderSectionButton(context),
                    ],
                  ),

                const SizedBox(height: 32),
                const MapleProFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. ADMIN BUTTON CARD
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildAdminSectionButton(BuildContext context) {
    const accentColor = Color(0xFFF59E0B);

    return InkWell(
      onTap: () {
        if (onSelectSection != null) {
          onSelectSection!(0);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, size: 28, color: accentColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Admin',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Live Stock, Invoices & Transfers',
                        style: GoogleFonts.inter(fontSize: 12, color: accentColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Monitor current available stock held in Admin warehouse vs transferred stock, audit today\'s inward supplier invoices, and track outbound material transfers.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), height: 1.4),
            ),
            const SizedBox(height: 16),

            // Report badges
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildBadge('Live Stock (3-way breakdown)', accentColor),
                _buildBadge('Today\'s Invoices & Items', accentColor),
                _buildBadge('Department Transfers', accentColor),
              ],
            ),
            const SizedBox(height: 18),

            // Prominent button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Open Admin Reports',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: accentColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. TEA SECTION BUTTON CARD
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildTeaSectionButton(BuildContext context) {
    const accentColor = Color(0xFF10B981);

    return InkWell(
      onTap: () {
        if (onSelectSection != null) {
          onSelectSection!(1);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.eco_rounded, size: 28, color: accentColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2. Tea Section',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Usage, Storage & Dispatches',
                        style: GoogleFonts.inter(fontSize: 12, color: accentColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Track materials genuinely transferred to Tea, inspect real-time available balances, audit daily production consumption, review finished Tea storage, and monitor dispatches.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), height: 1.4),
            ),
            const SizedBox(height: 16),

            // Report badges
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildBadge('Tea Live Material', accentColor),
                _buildBadge('Consumption Report', accentColor),
                _buildBadge('Storage Live Stock', accentColor),
                _buildBadge('Tea Dispatch Report', accentColor),
              ],
            ),
            const SizedBox(height: 18),

            // Prominent button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Open Tea Reports',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: accentColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. CHOCOLATE SECTION BUTTON CARD
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildChocolateSectionButton(BuildContext context) {
    const accentColor = Color(0xFFD97706);

    return InkWell(
      onTap: () {
        if (onSelectSection != null) {
          onSelectSection!(2);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cookie_rounded, size: 28, color: accentColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '3. Chocolate Section',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Materials, OCR, Rack & Consign',
                        style: GoogleFonts.inter(fontSize: 12, color: accentColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Inspect raw materials transferred to Chocolate, review confirmed on-device OCR weighing logs, audit finished goods stored in physical Rack locations, and track consignments.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), height: 1.4),
            ),
            const SizedBox(height: 16),

            // Report badges
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildBadge('Chocolate Live Material', accentColor),
                _buildBadge('Confirmed OCR Report', accentColor),
                _buildBadge('Chocolate Rack Report', accentColor),
                _buildBadge('Consignment Report', accentColor),
              ],
            ),
            const SizedBox(height: 18),

            // Prominent button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Open Chocolate Reports',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: accentColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 4. OUT OF STOCK BUTTON CARD
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildOutOfStockSectionButton(BuildContext context) {
    const accentColor = Color(0xFFEF4444);

    return InkWell(
      onTap: () {
        if (onSelectSection != null) {
          onSelectSection!(3);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, size: 28, color: accentColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '4. Out of Stock',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Out of Stock & Availability',
                        style: GoogleFonts.inter(fontSize: 12, color: accentColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Audit materials with zero available stock. Clearly distinguishes items out of stock across the entire business from those out of stock in one location but available in another.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), height: 1.4),
            ),
            const SizedBox(height: 16),

            // Report badges
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildBadge('Business-Wide Out of Stock', accentColor),
                _buildBadge('Location vs Business Stock', accentColor),
                _buildBadge('Department Stock Breakdown', accentColor),
              ],
            ),
            const SizedBox(height: 18),

            // Prominent button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Open Out of Stock Report',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: accentColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 5. REORDER REPORT BUTTON CARD
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildReorderSectionButton(BuildContext context) {
    const accentColor = Color(0xFFF59E0B);

    return InkWell(
      onTap: () {
        if (onSelectSection != null) {
          onSelectSection!(4);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shopping_cart_checkout_rounded, size: 28, color: accentColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '5. Reorder Report',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Replenishment & Thresholds',
                        style: GoogleFonts.inter(fontSize: 12, color: accentColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Identify materials requiring reorder based on configured reorder thresholds. Shows current stock, minimum levels, and suggested replenishment quantities.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), height: 1.4),
            ),
            const SizedBox(height: 16),

            // Report badges
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildBadge('Reorder Alerts', accentColor),
                _buildBadge('Threshold Status', accentColor),
                _buildBadge('Suggested Replenishment', accentColor),
              ],
            ),
            const SizedBox(height: 18),

            // Prominent button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Open Reorder Report',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: accentColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFE2E8F0)),
      ),
    );
  }
}
