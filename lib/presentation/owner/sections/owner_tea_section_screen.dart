import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/formatters/app_date_formatter.dart';
import '../../../core/formatters/quantity_formatter.dart';
import '../../../core/responsive/responsive_breakpoints.dart';
import '../../../data/models/batch_model.dart';
import '../../../data/models/dispatch_model.dart';
import '../../../data/models/tea_consumption_model.dart';
import '../../../data/models/tea_material_received_model.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../providers/owner_providers.dart';
import '../widgets/owner_report_components.dart';

class OwnerTeaSectionScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final VoidCallback? onBackToDashboard;

  const OwnerTeaSectionScreen({
    super.key,
    this.initialTabIndex = 0,
    this.onBackToDashboard,
  });

  @override
  ConsumerState<OwnerTeaSectionScreen> createState() => _OwnerTeaSectionScreenState();
}

class _OwnerTeaSectionScreenState extends ConsumerState<OwnerTeaSectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Search controllers
  final TextEditingController _liveMaterialSearchCtrl = TextEditingController();
  final TextEditingController _consumptionSearchCtrl = TextEditingController();
  final TextEditingController _storageSearchCtrl = TextEditingController();
  final TextEditingController _dispatchSearchCtrl = TextEditingController();

  String _liveMaterialSearch = '';
  String _consumptionSearch = '';
  String _storageSearch = '';
  String _dispatchSearch = '';

  // Consumption Date Filter
  OwnerQuickDateFilter _consumptionDateFilter = OwnerQuickDateFilter.today;
  DateTime? _consumptionCustomFrom;
  DateTime? _consumptionCustomTo;

  // Dispatch Date Filter
  OwnerQuickDateFilter _dispatchDateFilter = OwnerQuickDateFilter.allTime;
  DateTime? _dispatchCustomFrom;
  DateTime? _dispatchCustomTo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _liveMaterialSearchCtrl.dispose();
    _consumptionSearchCtrl.dispose();
    _storageSearchCtrl.dispose();
    _dispatchSearchCtrl.dispose();
    super.dispose();
  }

  ({DateTime? from, DateTime? to}) _resolveDateRange(
    OwnerQuickDateFilter filter,
    DateTime? customFrom,
    DateTime? customTo,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case OwnerQuickDateFilter.today:
        return (from: today, to: today);
      case OwnerQuickDateFilter.last7Days:
        return (from: today.subtract(const Duration(days: 7)), to: today);
      case OwnerQuickDateFilter.thisMonth:
        return (from: DateTime(now.year, now.month, 1), to: today);
      case OwnerQuickDateFilter.allTime:
        return (from: null, to: null);
      case OwnerQuickDateFilter.custom:
        return (from: customFrom, to: customTo);
    }
  }

  Future<void> _pickCustomDateRange({required bool isConsumption}) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF10B981),
              surface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isConsumption) {
          _consumptionDateFilter = OwnerQuickDateFilter.custom;
          _consumptionCustomFrom = picked.start;
          _consumptionCustomTo = picked.end;
        } else {
          _dispatchDateFilter = OwnerQuickDateFilter.custom;
          _dispatchCustomFrom = picked.start;
          _dispatchCustomTo = picked.end;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveBreakpoints.isTabletOrLarger(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section Header & Tab Bar
            _buildTopSectionBar(isTablet),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLiveMaterialTab(isTablet),
                  _buildConsumptionTab(isTablet),
                  _buildStorageTab(isTablet),
                  _buildDispatchTab(isTablet),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSectionBar(bool isTablet) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        border: Border(bottom: BorderSide(color: Color(0xFF1F2937))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.onBackToDashboard != null)
                InkWell(
                  onTap: widget.onBackToDashboard,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF374151)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Text(
                          'Portal Hub',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.eco_rounded, size: 20, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tea Section Reporting',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 17 : 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Live Materials • Daily Consumption • Storage Stock • Dispatch Records (Read-Only)',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Exactly 4 Tabs: Tea Live Material, Consumption, Storage, Dispatch
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: const Color(0xFF10B981),
            indicatorWeight: 3,
            labelColor: const Color(0xFF10B981),
            unselectedLabelColor: const Color(0xFF94A3B8),
            labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(
                icon: Icon(Icons.inventory_2_outlined, size: 18),
                text: 'Tea Live Material',
              ),
              Tab(
                icon: Icon(Icons.restaurant_outlined, size: 18),
                text: 'Consumption Report',
              ),
              Tab(
                icon: Icon(Icons.layers_outlined, size: 18),
                text: 'Storage Live Stock',
              ),
              Tab(
                icon: Icon(Icons.local_shipping_outlined, size: 18),
                text: 'Dispatch Report',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 1: TEA LIVE MATERIAL (Only genuinely transferred to Tea)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildLiveMaterialTab(bool isTablet) {
    final liveMaterialsAsync = ref.watch(
      ownerTeaLiveMaterialsProvider((search: _liveMaterialSearch, category: null)),
    );

    return liveMaterialsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
      error: (err, _) => Center(
        child: EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load Tea Live Materials',
          message: err.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(ownerTeaLiveMaterialsProvider),
        ),
      ),
      data: (materials) {
        double totalReceived = 0.0;
        double totalConsumed = 0.0;
        double totalReturned = 0.0;
        double totalBalance = 0.0;

        for (final m in materials) {
          totalReceived += m.totalReceived;
          totalConsumed += m.totalConsumed;
          totalReturned += m.totalReturned;
          totalBalance += m.currentBalance;
        }

        return RefreshIndicator(
          color: const Color(0xFF10B981),
          backgroundColor: const Color(0xFF1E293B),
          onRefresh: () async {
            ref.invalidate(ownerTeaLiveMaterialsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Summary Figures
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OwnerKpiChip(
                      label: 'ACTIVE TEA MATERIALS',
                      value: '${materials.length}',
                      subtitle: 'Transferred from Admin',
                      icon: Icons.category_rounded,
                      accentColor: const Color(0xFF06B6D4),
                    ),
                    OwnerKpiChip(
                      label: 'TOTAL RECEIVED',
                      value: QuantityFormatter.formatClean(totalReceived),
                      subtitle: 'From Admin Warehouse',
                      icon: Icons.move_to_inbox_rounded,
                      accentColor: const Color(0xFF38BDF8),
                    ),
                    OwnerKpiChip(
                      label: 'TOTAL CONSUMED',
                      value: QuantityFormatter.formatClean(totalConsumed),
                      subtitle: 'Production Usage',
                      icon: Icons.outdoor_grill_rounded,
                      accentColor: const Color(0xFFF59E0B),
                    ),
                    OwnerKpiChip(
                      label: 'TOTAL RETURNED',
                      value: QuantityFormatter.formatClean(totalReturned),
                      subtitle: 'Physically Returned to Admin',
                      icon: Icons.assignment_return_rounded,
                      accentColor: const Color(0xFF64748B),
                    ),
                    OwnerKpiChip(
                      label: 'CURRENT TEA BALANCE',
                      value: QuantityFormatter.formatClean(totalBalance),
                      subtitle: 'Available for Production',
                      icon: Icons.balance_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Formula Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Available Tea Balance = Valid Quantity Received − Quantity Consumed − Confirmed Quantity Returned',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Search Bar
                OwnerSearchBar(
                  controller: _liveMaterialSearchCtrl,
                  hintText: 'Search tea material code or name...',
                  onChanged: (val) {
                    setState(() => _liveMaterialSearch = val.trim());
                  },
                ),
                const SizedBox(height: 14),

                // Materials List
                if (materials.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.eco_outlined,
                    title: 'No materials found in Tea department',
                    message: 'Only materials genuinely transferred from Admin to Tea appear in this report.',
                  )
                else
                  ...materials.map((m) => _buildTeaLiveMaterialCard(m)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeaLiveMaterialCard(TeaMaterialReceivedModel m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: m.hasStock ? const Color(0xFF1F2937) : const Color(0xFF374151).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  m.materialCode,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  m.category,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: m.hasStock
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  m.hasStock ? 'IN STOCK' : 'OUT OF STOCK',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: m.hasStock ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Text(
            m.description,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),

          // Ledger Stats Grid
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                _statColumn('Received', '${QuantityFormatter.formatClean(m.totalReceived)} ${m.unit}', const Color(0xFF38BDF8)),
                Container(width: 1, height: 28, color: const Color(0xFF334155)),
                _statColumn('Consumed', '${QuantityFormatter.formatClean(m.totalConsumed)} ${m.unit}', const Color(0xFFF59E0B)),
                Container(width: 1, height: 28, color: const Color(0xFF334155)),
                _statColumn('Returned', '${QuantityFormatter.formatClean(m.totalReturned)} ${m.unit}', const Color(0xFF94A3B8)),
                Container(width: 1, height: 28, color: const Color(0xFF334155)),
                _statColumn('Balance', '${QuantityFormatter.formatClean(m.currentBalance)} ${m.unit}', const Color(0xFF10B981), isBold: true),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (m.latestTransactionAt != null)
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  'Latest Activity: ${AppDateFormatter.format(m.latestTransactionAt)} ${AppDateFormatter.formatTime(m.latestTransactionAt)}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value, Color color, {bool isBold = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 2: TEA CONSUMPTION REPORT
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildConsumptionTab(bool isTablet) {
    final range = _resolveDateRange(_consumptionDateFilter, _consumptionCustomFrom, _consumptionCustomTo);
    final consumptionAsync = ref.watch(
      ownerTeaConsumptionReportProvider((fromDate: range.from, toDate: range.to, search: _consumptionSearch)),
    );

    return consumptionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
      error: (err, _) => Center(
        child: EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load Tea Consumption Report',
          message: err.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(ownerTeaConsumptionReportProvider),
        ),
      ),
      data: (entries) {
        double totalTaken = 0.0;
        double totalReturned = 0.0;
        double totalConsumed = 0.0;

        for (final e in entries) {
          totalTaken += e.takenQty;
          totalReturned += e.balanceQty;
          totalConsumed += e.consumedQty;
        }

        return RefreshIndicator(
          color: const Color(0xFF10B981),
          backgroundColor: const Color(0xFF1E293B),
          onRefresh: () async {
            ref.invalidate(ownerTeaConsumptionReportProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Figures
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OwnerKpiChip(
                      label: 'TOTAL CONSUMED',
                      value: QuantityFormatter.formatClean(totalConsumed),
                      subtitle: 'Net Material Consumed',
                      icon: Icons.outdoor_grill_rounded,
                      accentColor: const Color(0xFFF59E0B),
                    ),
                    OwnerKpiChip(
                      label: 'TAKEN FOR WORK',
                      value: QuantityFormatter.formatClean(totalTaken),
                      subtitle: 'Drawn from Tea Store',
                      icon: Icons.call_missed_outgoing_rounded,
                      accentColor: const Color(0xFF06B6D4),
                    ),
                    OwnerKpiChip(
                      label: 'RETURNED (NIGHT BAL)',
                      value: QuantityFormatter.formatClean(totalReturned),
                      subtitle: 'Unused Material Returned',
                      icon: Icons.assignment_return_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                    OwnerKpiChip(
                      label: 'ENTRIES LOGGED',
                      value: '${entries.length}',
                      subtitle: 'Consumption Logs',
                      icon: Icons.list_alt_rounded,
                      accentColor: const Color(0xFF8B5CF6),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date Filter Chips
                OwnerDateFilterChips(
                  selected: _consumptionDateFilter,
                  onSelected: (filter) {
                    setState(() => _consumptionDateFilter = filter);
                  },
                  onPickCustom: () => _pickCustomDateRange(isConsumption: true),
                  customFrom: _consumptionCustomFrom,
                  customTo: _consumptionCustomTo,
                ),
                const SizedBox(height: 12),

                // Search Bar
                OwnerSearchBar(
                  controller: _consumptionSearchCtrl,
                  hintText: 'Search material code, description, operator...',
                  onChanged: (val) {
                    setState(() => _consumptionSearch = val.trim());
                  },
                ),
                const SizedBox(height: 14),

                // Entries List
                if (entries.isEmpty)
                  EmptyStateWidget(
                    icon: Icons.restaurant_outlined,
                    title: _consumptionDateFilter == OwnerQuickDateFilter.today
                        ? 'No consumption recorded today'
                        : 'No consumption records found for this period',
                    message: 'Daily Tea material consumption entries will appear here.',
                  )
                else
                  ...entries.map((e) => _buildConsumptionCard(e)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConsumptionCard(TeaConsumptionModel e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppDateFormatter.format(e.date)} ${AppDateFormatter.formatTime(e.effectiveDateTime)}',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              if (e.operatorName.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF374151)),
                  ),
                  child: Text(
                    'Op: ${e.operatorName}',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  e.materialCode,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.description,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              Text(
                '${QuantityFormatter.formatClean(e.consumedQty)} ${e.unit}',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Preserving distinction: Taken vs Returned vs Consumed
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Text(
                  'Taken: ${QuantityFormatter.formatClean(e.takenQty)} ${e.unit}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF06B6D4)),
                ),
                const SizedBox(width: 12),
                Text(
                  'Returned: ${QuantityFormatter.formatClean(e.balanceQty)} ${e.unit}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981)),
                ),
                const Spacer(),
                Text(
                  'Net Consumed: ${QuantityFormatter.formatClean(e.consumedQty)} ${e.unit}',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 3: TEA STORAGE LIVE STOCK REPORT
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildStorageTab(bool isTablet) {
    final storageAsync = ref.watch(ownerTeaStorageReportProvider(_storageSearch));

    return storageAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
      error: (err, _) => Center(
        child: EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load Tea Storage Report',
          message: err.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(ownerTeaStorageReportProvider),
        ),
      ),
      data: (batches) {
        double totalAvailable = 0.0;
        int activeCount = 0;
        int depletedCount = 0;

        for (final b in batches) {
          totalAvailable += b.availableQuantity;
          if (b.availableQuantity > 0.0001) {
            activeCount++;
          } else {
            depletedCount++;
          }
        }

        return RefreshIndicator(
          color: const Color(0xFF10B981),
          backgroundColor: const Color(0xFF1E293B),
          onRefresh: () async {
            ref.invalidate(ownerTeaStorageReportProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Figures
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OwnerKpiChip(
                      label: 'TOTAL STORAGE BATCHES',
                      value: '${batches.length}',
                      subtitle: 'Registered Tea Batches',
                      icon: Icons.layers_rounded,
                      accentColor: const Color(0xFF06B6D4),
                    ),
                    OwnerKpiChip(
                      label: 'CURRENT STORAGE STOCK',
                      value: QuantityFormatter.formatClean(totalAvailable),
                      subtitle: 'Available Finished Goods',
                      icon: Icons.warehouse_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                    OwnerKpiChip(
                      label: 'ACTIVE / OUT OF STOCK',
                      value: '$activeCount / $depletedCount',
                      subtitle: 'Batch Inventory Status',
                      icon: Icons.pie_chart_rounded,
                      accentColor: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar
                OwnerSearchBar(
                  controller: _storageSearchCtrl,
                  hintText: 'Search product name, batch number...',
                  onChanged: (val) {
                    setState(() => _storageSearch = val.trim());
                  },
                ),
                const SizedBox(height: 14),

                // Batches List
                if (batches.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.layers_outlined,
                    title: 'No Tea storage records registered',
                    message: 'Finished goods storage batches registered for Tea department will appear here.',
                  )
                else
                  ...batches.map((b) => _buildStorageBatchCard(b)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStorageBatchCard(BatchModel b) {
    final hasStock = b.availableQuantity > 0.0001;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasStock ? const Color(0xFF1F2937) : const Color(0xFF374151).withValues(alpha: 0.5),
        ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'BATCH #${b.batchNo}',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                    ),
                  ),
                  if (b.grade.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      b.grade,
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasStock
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasStock ? 'IN STORAGE' : 'OUT OF STOCK',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: hasStock ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Text(
                  b.description.isNotEmpty ? b.description : b.materialCode,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              Text(
                '${QuantityFormatter.formatClean(b.availableQuantity)} ${b.uom}',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: hasStock ? const Color(0xFF10B981) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Updated: ${AppDateFormatter.format(b.effectiveDateTime)} ${AppDateFormatter.formatTime(b.effectiveDateTime)}',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
              ),
              Text(
                'Received: ${QuantityFormatter.formatClean(b.receivedQuantity)} ${b.uom}',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 4: TEA DISPATCH REPORT
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildDispatchTab(bool isTablet) {
    final range = _resolveDateRange(_dispatchDateFilter, _dispatchCustomFrom, _dispatchCustomTo);
    final dispatchAsync = ref.watch(
      ownerTeaDispatchesReportProvider((fromDate: range.from, toDate: range.to, search: _dispatchSearch)),
    );

    return dispatchAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
      error: (err, _) => Center(
        child: EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load Tea Dispatch Report',
          message: err.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(ownerTeaDispatchesReportProvider),
        ),
      ),
      data: (dispatches) {
        double totalQty = 0.0;
        double netQty = 0.0;

        for (final d in dispatches) {
          totalQty += d.quantity;
          netQty += d.netQuantity;
        }

        return RefreshIndicator(
          color: const Color(0xFF10B981),
          backgroundColor: const Color(0xFF1E293B),
          onRefresh: () async {
            ref.invalidate(ownerTeaDispatchesReportProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Figures
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OwnerKpiChip(
                      label: 'TOTAL DISPATCHES',
                      value: '${dispatches.length}',
                      subtitle: 'Dispatches Recorded',
                      icon: Icons.local_shipping_rounded,
                      accentColor: const Color(0xFF06B6D4),
                    ),
                    OwnerKpiChip(
                      label: 'TOTAL DISPATCHED QTY',
                      value: QuantityFormatter.formatClean(totalQty),
                      subtitle: 'Gross Dispatched',
                      icon: Icons.outbox_rounded,
                      accentColor: const Color(0xFF38BDF8),
                    ),
                    OwnerKpiChip(
                      label: 'NET DISPATCHED',
                      value: QuantityFormatter.formatClean(netQty),
                      subtitle: 'Net of Any Returns',
                      icon: Icons.done_all_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date Filter Chips
                OwnerDateFilterChips(
                  selected: _dispatchDateFilter,
                  onSelected: (filter) {
                    setState(() => _dispatchDateFilter = filter);
                  },
                  onPickCustom: () => _pickCustomDateRange(isConsumption: false),
                  customFrom: _dispatchCustomFrom,
                  customTo: _dispatchCustomTo,
                ),
                const SizedBox(height: 12),

                // Search Bar
                OwnerSearchBar(
                  controller: _dispatchSearchCtrl,
                  hintText: 'Search product, code, destination...',
                  onChanged: (val) {
                    setState(() => _dispatchSearch = val.trim());
                  },
                ),
                const SizedBox(height: 14),

                // Dispatches List
                if (dispatches.isEmpty)
                  EmptyStateWidget(
                    icon: Icons.local_shipping_outlined,
                    title: _dispatchDateFilter == OwnerQuickDateFilter.today
                        ? 'No Tea dispatches recorded today'
                        : 'No Tea dispatches recorded for this period',
                    message: 'Finished goods outward dispatches from Tea storage will appear here.',
                  )
                else
                  ...dispatches.map((d) => _buildDispatchCard(d)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDispatchCard(DispatchModel d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppDateFormatter.format(d.date)} ${AppDateFormatter.formatTime(d.effectiveDateTime)}',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'DISPATCHED',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Text(
                  d.product.isNotEmpty ? d.product : d.materialCode,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              Text(
                '${QuantityFormatter.formatClean(d.quantity)} ${d.units}',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 4),
                  Text(
                    d.location.isNotEmpty ? d.location : 'Destination Unspecified',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              if (d.returnQuantity > 0.0001)
                Text(
                  'Net: ${QuantityFormatter.formatClean(d.netQuantity)} ${d.units}',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
