import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/glass_widgets.dart';
import '../invoices/add_invoice_screen.dart';
import '../invoices/invoice_list_screen.dart';
import '../providers/app_providers.dart';
import '../transfers/add_transfer_screen.dart';
import '../transfers/transfers_screen.dart';

/// Unified Hub for [Invoice & Transfer]
/// Groups Invoice operations (create invoice, code/desc search, auto-fill, totals, storage updates)
/// and Department Transfers (code/desc search, auto-fill, outward, returns, stock validation, history)
/// under the EXACT same main section.
class InvoiceTransferHubScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const InvoiceTransferHubScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<InvoiceTransferHubScreen> createState() => _InvoiceTransferHubScreenState();
}

class _InvoiceTransferHubScreenState extends ConsumerState<InvoiceTransferHubScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesListProvider(null));
    final transfersAsync = ref.watch(transfersListProvider(null));

    final totalInvoices = invoicesAsync.asData?.value.length ?? 0;
    final totalInvoiceValue = invoicesAsync.asData?.value.fold(0.0, (sum, inv) => sum + inv.finalTotal) ?? 0.0;
    final totalTransfers = transfersAsync.asData?.value.length ?? 0;

    return Scaffold(
      body: AmbientBackground(
        child: Column(
          children: [
            // Top Section Header & KPI Strip
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              decoration: BoxDecoration(
                color: const Color(0xE60A0F1D),
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: AppColors.accent, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'INVOICE & TRANSFER',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Inward Purchase Invoices & Department Transfers',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Contextual Primary Action Button
                      if (_tabController.index == 0)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const AddInvoiceScreen()));
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New Invoice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransferScreen()));
                          },
                          icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                          label: const Text('New Transfer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Quick Operational Metric Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildMetricPill(
                          icon: Icons.receipt_outlined,
                          label: 'Invoices Recorded',
                          value: '$totalInvoices',
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(width: 8),
                        _buildMetricPill(
                          icon: Icons.currency_rupee_rounded,
                          label: 'Purchases Total',
                          value: '₹${totalInvoiceValue.toStringAsFixed(2)}',
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        _buildMetricPill(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Dept Transfers',
                          value: '$totalTransfers',
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        _buildMetricPill(
                          icon: Icons.cloud_done_rounded,
                          label: 'Database',
                          value: 'Supabase Cloud',
                          color: const Color(0xFF3ECF8E),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Main Segmented Tabs: Invoice vs Transfer
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.accent,
                    indicatorWeight: 3,
                    labelColor: AppColors.accent,
                    unselectedLabelColor: AppColors.textMuted,
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.receipt_long_rounded, size: 18),
                        text: 'Invoices & Inward',
                      ),
                      Tab(
                        icon: Icon(Icons.swap_horiz_rounded, size: 18),
                        text: 'Department Transfers & Returns',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Views for Invoice and Transfer
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  InvoiceListScreen(),
                  TransfersScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
