import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/glass_widgets.dart';
import '../dispatch/add_dispatch_screen.dart';
import '../dispatch/dispatch_screen.dart';
import '../providers/app_providers.dart';
import '../storage/storage_screen.dart';

/// Unified Hub for [Storage & Dispatch]
/// Groups Storage (available stock, batches, received qty, available qty, batch dates, FIFO stock, location info)
/// and Dispatch (code/desc search, auto-fill, qty, FIFO batch consumption, dispatch-batch relationships)
/// under the EXACT same main section.
class StorageDispatchHubScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const StorageDispatchHubScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<StorageDispatchHubScreen> createState() => _StorageDispatchHubScreenState();
}

class _StorageDispatchHubScreenState extends ConsumerState<StorageDispatchHubScreen> with SingleTickerProviderStateMixin {
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
    final activeBatchesAsync = ref.watch(activeBatchesProvider(null));
    final dispatchesAsync = ref.watch(dispatchesListProvider(null));

    final activeBatchesCount = activeBatchesAsync.asData?.value.length ?? 0;
    final totalAvailableStock = activeBatchesAsync.asData?.value.fold(0.0, (sum, b) => sum + b.availableQuantity) ?? 0.0;
    final totalDispatchesCount = dispatchesAsync.asData?.value.length ?? 0;

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
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.warehouse_rounded, color: AppColors.primaryLight, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STORAGE & DISPATCH',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Warehouse Inventory, FIFO Batches & Outward Dispatch',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_tabController.index == 1)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDispatchScreen()));
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Record Dispatch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
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
                          icon: Icons.layers_outlined,
                          label: 'Active Batches',
                          value: '$activeBatchesCount',
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(width: 8),
                        _buildMetricPill(
                          icon: Icons.scale_rounded,
                          label: 'Available Stock',
                          value: '${totalAvailableStock.toStringAsFixed(1)} units',
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        _buildMetricPill(
                          icon: Icons.local_shipping_outlined,
                          label: 'Total Dispatches',
                          value: '$totalDispatchesCount',
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        _buildMetricPill(
                          icon: Icons.sync_rounded,
                          label: 'Stock Mode',
                          value: 'FIFO Active',
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Main Segmented Tabs: Storage vs Dispatch
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primaryLight,
                    indicatorWeight: 3,
                    labelColor: AppColors.primaryLight,
                    unselectedLabelColor: AppColors.textMuted,
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.layers_rounded, size: 18),
                        text: 'Storage & Batches',
                      ),
                      Tab(
                        icon: Icon(Icons.local_shipping_rounded, size: 18),
                        text: 'Outward Dispatch (FIFO)',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Views for Storage and Dispatch
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  StorageScreen(),
                  DispatchScreen(),
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
